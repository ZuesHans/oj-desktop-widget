import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../ui/app_theme.dart';
import '../ui/dashboard/oj_float_home.dart';

class OjFloatApp extends StatelessWidget {
  const OjFloatApp({
    super.key,
    this.initialConfig,
    this.enablePlatformIntegration = true,
    this.autoInitializeController = true,
  });

  final AppConfig? initialConfig;
  final bool enablePlatformIntegration;
  final bool autoInitializeController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OJ 悬浮窗',
      theme: buildAppTheme(initialConfig?.colorTheme ?? AppColorTheme.classic),
      home: OjFloatHome(
        initialConfig: initialConfig,
        enablePlatformIntegration: enablePlatformIntegration,
        autoInitializeController: autoInitializeController,
      ),
    );
  }
}
