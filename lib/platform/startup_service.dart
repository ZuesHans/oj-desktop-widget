part of '../main.dart';

abstract class StartupService {
  Future<bool> setEnabled(bool enabled);
}

class NoopStartupService implements StartupService {
  @override
  Future<bool> setEnabled(bool enabled) async => true;
}

class LaunchAtStartupService implements StartupService {
  LaunchAtStartupService() {
    launchAtStartup.setup(
      appName: 'OJ Float',
      appPath: Platform.resolvedExecutable,
      packageName: 'oj_float',
    );
  }

  @override
  Future<bool> setEnabled(bool enabled) {
    return enabled ? launchAtStartup.enable() : launchAtStartup.disable();
  }
}
