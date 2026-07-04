import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/errors.dart';
import '../core/solved_totals.dart';
import '../models/app_config.dart';
import '../models/oj_state.dart';
import '../models/problem_record.dart';
import '../ui/app_labels.dart';
import 'backup_service.dart';
import 'oj_controller.dart';
import 'sync_service.dart';
import 'window_shell_service.dart';

typedef BackupFilePicker = Future<File?> Function();
typedef ProblemUrlLauncher = Future<bool> Function(Uri uri);

class HomeActionService {
  HomeActionService({
    BackupFilePicker? pickBackupFile,
    ProblemUrlLauncher? launchProblemUrl,
  })  : _pickBackupFile = pickBackupFile ?? _defaultPickBackupFile,
        _launchProblemUrl = launchProblemUrl ?? _defaultLaunchProblemUrl;

  final BackupFilePicker _pickBackupFile;
  final ProblemUrlLauncher _launchProblemUrl;

  Future<ActionFeedback?> saveConfigFromDashboard({
    required OjController controller,
    required WindowShellService shell,
    required AppConfig config,
    required bool enablePlatformIntegration,
  }) async {
    try {
      await controller.saveConfig(config, syncAfterRefresh: false);
      if (enablePlatformIntegration) {
        await shell.applyPreferences(config);
        await shell.setupTrayMenu();
      }
      return null;
    } catch (error) {
      return ActionFeedback.failure(
        '${AppLabels.settingsSaveFailed}：${normalizeError(error)}',
      );
    }
  }

  Future<ActionFeedback> exportData(OjState state) async {
    try {
      final result = await exportOjData(
        config: state.config,
        snapshots: state.snapshots,
        problems: state.problems,
        contests: state.contests,
        teammates: state.teammates,
      );
      return ActionFeedback.success(
        '${AppLabels.exportSuccessPrefix} ${result.directory.path}',
      );
    } catch (error) {
      return ActionFeedback.failure(
        '${AppLabels.exportFailed}：${normalizeError(error)}',
      );
    }
  }

  Future<ActionFeedback?> importData(OjController controller) async {
    try {
      final backupFile = await _pickBackupFile();
      if (backupFile == null) {
        return null;
      }
      final result = await controller.importPortableBackup(backupFile);
      return ActionFeedback.success(
        '${AppLabels.importSuccessPrefix}${result.safetyBackupFile.path}',
      );
    } catch (error) {
      return ActionFeedback.failure(
        '${AppLabels.importFailed}：${normalizeError(error)}',
      );
    }
  }

  Future<ActionFeedback?> applySettingsDialogResult({
    required OjController controller,
    required WindowShellService shell,
    required SettingsActionResult result,
    required bool enablePlatformIntegration,
  }) async {
    Object? saveError;
    try {
      await controller.saveSyncToken(result.syncToken);
      await controller.saveConfig(
        result.config,
        syncAfterRefresh: !result.syncNow,
      );
    } catch (error) {
      saveError = error;
    }
    if (enablePlatformIntegration) {
      await shell.applyPreferences(result.config);
      await shell.setupTrayMenu();
    }
    if (saveError != null) {
      return ActionFeedback.failure(
        '${AppLabels.startupSettingsUpdateFailed}：${normalizeError(saveError)}',
      );
    }
    if (result.syncNow) {
      final syncResult = await controller.syncNow();
      return ActionFeedback.fromSyncResult(syncResult);
    }
    return null;
  }

  Future<void> openProblemUrl(ProblemRecord problem) async {
    final uri = Uri.tryParse(problem.url);
    if (uri == null || !uri.hasScheme) {
      throw FetchException(AppLabels.invalidProblemUrl);
    }
    final opened = await _launchProblemUrl(uri);
    if (!opened) {
      throw FetchException(AppLabels.openProblemFailed);
    }
  }
}

class ActionFeedback {
  const ActionFeedback({
    required this.message,
    required this.isSuccess,
  });

  factory ActionFeedback.success(String message) {
    return ActionFeedback(message: message, isSuccess: true);
  }

  factory ActionFeedback.failure(String message) {
    return ActionFeedback(message: message, isSuccess: false);
  }

  factory ActionFeedback.fromSyncResult(SyncResult result) {
    return ActionFeedback(
      message: AppLabels.syncResultMessage(result),
      isSuccess: result.status == SyncStatus.success,
    );
  }

  final String message;
  final bool isSuccess;
}

class SettingsActionResult {
  const SettingsActionResult({
    required this.config,
    required this.syncToken,
    required this.syncNow,
  });

  final AppConfig config;
  final String syncToken;
  final bool syncNow;
}

Future<File?> _defaultPickBackupFile() async {
  final selection = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json'],
    allowMultiple: false,
  );
  final path = selection?.files.single.path;
  return path == null ? null : File(path);
}

Future<bool> _defaultLaunchProblemUrl(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
