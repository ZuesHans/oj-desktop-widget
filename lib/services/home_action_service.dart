import 'dart:async';
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

  Future<SyncResult?> saveSettings({
    required OjController controller,
    required WindowShell shell,
    required AppConfig config,
    required String syncToken,
    required bool syncNow,
    required bool enablePlatformIntegration,
  }) async {
    final previousAccounts = controller.state.config.accounts;
    Object? startupError;
    await controller.saveSyncToken(syncToken);
    try {
      await controller.saveConfig(config);
    } catch (error) {
      startupError = error;
    }
    final savedConfig = controller.state.config;

    if (enablePlatformIntegration) {
      try {
        if (savedConfig.closeToTray) {
          await shell.setTrayEnabled(true);
        } else {
          await shell.setTrayEnabled(false);
        }
        await shell.setCloseInterceptionEnabled(true);
      } catch (error) {
        await shell.setCloseInterceptionEnabled(true);
        await shell.setTrayEnabled(false);
        await shell.showAndFocus();
        await controller.saveConfig(
          savedConfig.copyWith(
            closeToTray: false,
            launchAtStartup: false,
          ),
        );
        throw FetchException('托盘初始化失败，已恢复为关闭即退出：$error');
      }
    }

    if (!_accountsEqual(previousAccounts, savedConfig.accounts)) {
      unawaited(controller.refresh());
    }
    if (startupError != null) {
      throw FetchException(normalizeError(startupError));
    }
    if (syncNow) {
      return controller.syncNow();
    }
    return null;
  }

  Future<ActionFeedback> exportData(OjState state) async {
    try {
      final result = await exportOjData(
        config: state.config,
        snapshots: state.snapshots,
        problems: state.problems,
        contests: state.contests,
        teammates: state.teammates,
        training: state.training,
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
      final successPrefix = switch (result.scope) {
        BackupImportScope.portable => AppLabels.portableImportSuccessPrefix,
        BackupImportScope.coreTraining =>
          AppLabels.coreTrainingImportSuccessPrefix,
      };
      return ActionFeedback.success(
        '$successPrefix${result.safetyBackupFile.path}',
      );
    } catch (error) {
      return ActionFeedback.failure(
        '${AppLabels.importFailed}：${normalizeError(error)}',
      );
    }
  }

  Future<void> openProblemUrl(ProblemRecord problem) async {
    final uri = Uri.tryParse(problem.url);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.trim().isEmpty) {
      throw FetchException(AppLabels.invalidProblemUrl);
    }
    final opened = await _launchProblemUrl(uri);
    if (!opened) {
      throw FetchException(AppLabels.openProblemFailed);
    }
  }
}

bool _accountsEqual(
  Map<String, OjAccountConfig> left,
  Map<String, OjAccountConfig> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    final other = right[entry.key];
    if (other == null || other.enabled != entry.value.enabled) {
      return false;
    }
    final usernames = entry.value.usernames;
    if (usernames.length != other.usernames.length) {
      return false;
    }
    for (var index = 0; index < usernames.length; index++) {
      if (usernames[index] != other.usernames[index]) {
        return false;
      }
    }
  }
  return true;
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
