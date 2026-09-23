import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../services/window_shell_service.dart';
import '../ui/app_labels.dart';
import '../ui/app_theme.dart';
import '../ui/dashboard/oj_float_home.dart';

class OjFloatApp extends StatelessWidget {
  const OjFloatApp({
    super.key,
    this.initialConfig,
    this.startHidden = false,
    this.windowShell,
    this.enablePlatformIntegration = true,
    this.autoInitializeController = true,
  });

  final AppConfig? initialConfig;
  final bool startHidden;
  final WindowShell? windowShell;
  final bool enablePlatformIntegration;
  final bool autoInitializeController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppLabels.appTitle,
      theme: buildAppTheme(initialConfig?.colorTheme ?? AppColorTheme.classic),
      home: OjFloatHome(
        initialConfig: initialConfig,
        startHidden: startHidden,
        windowShell: windowShell,
        enablePlatformIntegration: enablePlatformIntegration,
        autoInitializeController: autoInitializeController,
      ),
    );
  }
}
