import 'package:flutter/material.dart';

const compactWindowSize = Size(220, 148);
const compactMinimumWindowSize = Size(200, 132);
const dashboardWindowSize = Size(360, 520);
const dashboardMinimumWindowSize = Size(320, 420);
const heatmapWindowSize = Size(560, 560);
const heatmapMinimumWindowSize = Size(440, 420);

const appSurfaceColor = Color(0xFFF6F7F4);
const cardColor = Color(0xFFFFFFFF);
const cardMutedColor = Color(0xFFF4F6F3);
const borderColor = Color(0xFFE1E4DE);
const textPrimaryColor = Color(0xFF17211D);
const textSecondaryColor = Color(0xFF64706A);
const accentColor = Color(0xFF2F6F4E);
const dangerColor = Color(0xFFB3261E);

const appSystemFontFamily = 'Microsoft YaHei UI';
const appSystemFontFallback = <String>[
  'Segoe UI Variable Text',
  'Segoe UI',
  'Microsoft YaHei',
  'SimSun',
  'Arial',
];

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: accentColor,
    brightness: Brightness.light,
  );
  final base = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: appSystemFontFamily,
    fontFamilyFallback: appSystemFontFallback,
  );
  final textTheme = base.textTheme.apply(
    fontFamily: appSystemFontFamily,
    fontFamilyFallback: appSystemFontFallback,
    bodyColor: textPrimaryColor,
    displayColor: textPrimaryColor,
  );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: base.primaryTextTheme.apply(
      fontFamily: appSystemFontFamily,
      fontFamilyFallback: appSystemFontFallback,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: textTheme.titleLarge,
      toolbarTextStyle: textTheme.bodyMedium,
    ),
    dialogTheme: base.dialogTheme.copyWith(
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      labelStyle: textTheme.bodyMedium,
      hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondaryColor),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: textTheme.labelLarge),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(textStyle: textTheme.labelLarge),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(textStyle: textTheme.labelLarge),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(textStyle: textTheme.labelLarge),
    ),
  );
}

final heatmapDefaultStartDate = DateTime(2026, 6, 1);
const heatmapLevelColors = <Color>[
  Color(0xFFEFF3EF),
  Color(0xFF9BE9A8),
  Color(0xFF40C463),
  Color(0xFF30A14E),
  Color(0xFF216E39),
];
