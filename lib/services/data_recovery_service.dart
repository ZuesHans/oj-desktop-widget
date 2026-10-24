import 'dart:convert';
import 'dart:io';

import '../models/app_config.dart';
import 'automatic_backup_service.dart';
import 'backup_service.dart';
import 'local_store.dart';
import 'problem_database.dart';
import 'app_data_directory.dart';

/// Restores into a sibling directory, then publishes only a verified store.
/// The entire original directory (including damaged files) is retained.
class DataRecoveryService {
  Future<Directory> restore(File backup, Directory destination) async {
    final text = await backup.readAsString();
    final core = isCoreTrainingBackupJson(text)
        ? parseCoreTrainingBackupJson(text)
        : null;
    final portable = core == null ? parsePortableBackupJson(text) : null;
    final target = destination.absolute;
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final staged = Directory('${target.path}.restoring-$suffix');
    final retained = Directory('${target.path}.before-restore-$suffix');
    await target.parent.create(recursive: true);
    await staged.create();
    var movedOriginal = false;
    try {
      if (await target.exists()) await _copyDirectory(target, staged);
      for (final name in const [
        problemDatabaseFileName,
        '$problemDatabaseFileName-wal',
        '$problemDatabaseFileName-shm',
        'problems_v1.json',
        'problems_v1.json.bak',
        'problem_training_transaction_v1.json',
        'problem_training_transaction_v1.json.bak',
        'training_v1.json',
        'training_v1.json.bak',
        'contests_v1.json',
        'contests_v1.json.bak',
      ]) {
        final file = File('${staged.path}${Platform.pathSeparator}$name');
        if (await file.exists()) await file.delete();
      }
      final store = LocalStore(supportDirectory: staged);
      await store.replaceCoreData(
        core?.problems ?? portable!.problems,
        core?.training ?? portable!.training,
        core?.contests ?? portable!.contests,
        problemFolders: core?.problemFolders ?? portable!.problemFolders,
      );
      if (portable != null) {
        await store.replaceSnapshots(portable.snapshots);
        await store.replaceTeammates(portable.teammates);
        await store.saveRefreshLogs([]);
        final preferences = File('${staged.path}/shared_preferences.json');
        Map<String, dynamic> values = {};
        if (await preferences.exists()) {
          try {
            values = Map<String, dynamic>.from(
                jsonDecode(await preferences.readAsString()) as Map);
          } on FormatException {
            // The original invalid preferences remain in the retained copy.
          } on TypeError {
            // A full backup contains its own verified application config.
          }
        }
        values['flutter.app_config_v1'] = jsonEncode(portable.config.toJson());
        await preferences.writeAsString(jsonEncode(values), flush: true);
        await File('${preferences.path}.bak')
            .writeAsString(jsonEncode(values), flush: true);
      }
      // Core backups intentionally retain settings. Reject corrupt settings
      // here so an unsuitable backup never replaces the original directory.
      final preferences = File('${staged.path}/shared_preferences.json');
      if (await preferences.exists()) {
        final values = jsonDecode(await preferences.readAsString());
        if (values is! Map) {
          throw const FormatException('配置文件损坏，请选择包含配置的完整备份。');
        }
        final configText = values['flutter.app_config_v1'];
        if (configText != null) {
          final config = jsonDecode(configText as String);
          if (config is! Map) {
            throw const FormatException('配置文件损坏，请选择完整备份。');
          }
          AppConfig.fromJson(Map<String, dynamic>.from(config));
        }
      }
      await store.loadCoreBackupSnapshot();
      await writeIdentityMarker(staged, origin: 'backup');
      if (await target.exists()) {
        await target.rename(retained.path);
        movedOriginal = true;
      }
      try {
        await staged.rename(target.path);
      } catch (_) {
        if (movedOriginal) await retained.rename(target.path);
        rethrow;
      }
      return retained;
    } finally {
      if (await staged.exists()) await staged.delete(recursive: true);
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entry in source.list(followLinks: false)) {
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final path = '${destination.path}${Platform.pathSeparator}$name';
      if (entry is File) {
        await entry.copy(path);
      } else if (entry is Directory) {
        final child = await Directory(path).create();
        await _copyDirectory(entry, child);
      } else {
        throw const FileSystemException('数据目录含有链接，请先手动备份并检查目录。');
      }
    }
  }
}
