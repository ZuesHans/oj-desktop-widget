import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

abstract class StartupService {
  Future<bool> setEnabled(bool enabled);
}

class NoopStartupService implements StartupService {
  @override
  Future<bool> setEnabled(bool enabled) async => true;
}

class LaunchAtStartupService implements StartupService {
  void _setup({required String appName, required List<String> args}) {
    launchAtStartup.setup(
      appName: appName,
      appPath: Platform.resolvedExecutable,
      packageName: 'oj_float',
      args: args,
    );
  }

  @override
  Future<bool> setEnabled(bool enabled) async {
    // Remove the pre-client startup entry before synchronizing the new one.
    _setup(appName: 'OJ 悬浮窗', args: const []);
    final legacyRemoved = await launchAtStartup.disable();

    _setup(appName: 'OJ Float', args: const ['--startup']);
    final updated = enabled
        ? await launchAtStartup.enable()
        : await launchAtStartup.disable();
    return legacyRemoved && updated;
  }
}
