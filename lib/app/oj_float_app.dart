import 'package:flutter/material.dart';

import '../ui/dashboard/oj_float_home.dart';

class OjFloatApp extends StatelessWidget {
  const OjFloatApp({
    super.key,
    this.enablePlatformIntegration = true,
    this.autoInitializeController = true,
  });

  final bool enablePlatformIntegration;
  final bool autoInitializeController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OJ Float',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F7D6D),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: OjFloatHome(
        enablePlatformIntegration: enablePlatformIntegration,
        autoInitializeController: autoInitializeController,
      ),
    );
  }
}
