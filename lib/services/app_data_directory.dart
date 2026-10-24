import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:crypto/crypto.dart';

import 'local_store.dart';
import 'problem_database.dart';

const appIdentity = 'io.github.zueshans.ojfloat';
const appIdentityMarker = 'app_data_identity_v1.json';
Future<Directory>? _resolvedDirectory;

Future<Directory> applicationDataDestination() =>
    getApplicationSupportDirectory();

Future<Directory> applicationDataDirectory() async {
  if (!Platform.isWindows) return applicationDataDestination();
  final operation = _resolvedDirectory ??= _migrateApplicationData();
  try {
    return await operation;
  } catch (_) {
    if (identical(_resolvedDirectory, operation)) _resolvedDirectory = null;
    rethrow;
  }
}

Future<Directory> _migrateApplicationData() async {
  final destination = await applicationDataDestination();
  final legacy =
      Directory('${destination.parent.parent.path}/com.example/oj_float');
  return AppDataMigration(beforeCopy: () async {
    final ready = await const MethodChannel('oj_float/quick_entry')
        .invokeMethod<bool>('canMigrateData');
    if (ready != true) {
      throw const FileSystemException('请先关闭旧版 OJ Float 和题库小程序，再重新读取数据。');
    }
  }).migrate(legacy: legacy, destination: destination);
}

/// Publishes a complete directory once; never merges two independent stores.
class AppDataMigration {
  AppDataMigration({this.beforeCopy});
  final Future<void> Function()? beforeCopy;

  Future<Directory> migrate({
    required Directory legacy,
    required Directory destination,
  }) async {
    final target = destination.absolute;
    await target.parent.create(recursive: true);
    final lock =
        await File('${target.path}.migration.lock').open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.blockingExclusive);
      final marker = File('${target.path}/$appIdentityMarker');
      if (await marker.exists()) {
        final value = jsonDecode(await marker.readAsString());
        if (value is! Map ||
            value['identity'] != appIdentity ||
            value['version'] != 1) {
          throw const FormatException('应用数据迁移标记损坏，请检查数据目录或恢复备份。');
        }
        return target;
      }
      final hasLegacy = await legacy.exists() && !await legacy.list().isEmpty;
      final hasTarget = await target.exists() && !await target.list().isEmpty;
      if (hasLegacy && hasTarget) {
        throw const FileSystemException('新旧目录均有数据，已停止自动迁移以保留两份记录。请选择有效备份恢复。');
      }
      if (!hasLegacy) {
        await target.create(recursive: true);
        if (hasTarget) await _validate(target);
        await writeIdentityMarker(target, origin: 'local');
        return target;
      }
      await beforeCopy?.call();
      final staged = Directory(
          '${target.path}.migrating-$pid-${DateTime.now().microsecondsSinceEpoch}');
      await staged.create();
      try {
        await _copyDirectory(legacy, staged);
        await _validate(staged);
        await writeIdentityMarker(staged, origin: 'legacy');
        // path_provider may have already created an empty destination.
        if (await target.exists()) await target.delete();
        await staged.rename(target.path);
      } finally {
        if (await staged.exists()) await staged.delete(recursive: true);
      }
      return target;
    } finally {
      await lock.close();
    }
  }

  Future<void> _validate(Directory directory) async {
    final store =
        LocalStore(supportDirectory: directory, useFilePreferences: true);
    await store.loadConfig();
    await store.recoverPendingProblemTrainingTransaction();
    await store.loadCoreBackupSnapshot();
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entry in source.list(followLinks: false)) {
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final target = '${destination.path}/$name';
      if (entry is Directory) {
        await _copyDirectory(entry, await Directory(target).create());
      } else if (entry is File) {
        if (name == '$problemDatabaseFileName-wal' ||
            name == '$problemDatabaseFileName-shm' ||
            name == '$problemDatabaseFileName-journal') {
          continue;
        }
        if (name == problemDatabaseFileName) {
          final database = sqlite3.open(entry.path, mode: OpenMode.readOnly);
          try {
            database.execute('PRAGMA busy_timeout = 5000');
            final check = database.select('PRAGMA quick_check');
            if (check.length != 1 || check.single.values.single != 'ok') {
              throw const FormatException('旧题库数据库损坏，请先恢复备份。');
            }
            database.execute('VACUUM INTO ?', [target]);
          } finally {
            database.close();
          }
        } else {
          final before = await entry.stat();
          await entry.copy(target);
          final after = await entry.stat();
          final sourceHash = await sha256.bind(entry.openRead()).first;
          final copiedHash = await sha256.bind(File(target).openRead()).first;
          if (before.size != after.size ||
              before.modified != after.modified ||
              sourceHash != copiedHash) {
            throw const FileSystemException('旧版正在写入数据，请关闭后重试迁移。');
          }
        }
      } else {
        throw const FileSystemException('旧数据目录含有链接，请手动检查后再迁移。');
      }
    }
  }
}

Future<void> writeIdentityMarker(Directory directory,
    {required String origin}) async {
  await File('${directory.path}/$appIdentityMarker').writeAsString(
      jsonEncode({'identity': appIdentity, 'version': 1, 'origin': origin}),
      flush: true);
}
