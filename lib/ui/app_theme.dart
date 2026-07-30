import 'package:flutter/material.dart';

import '../models/app_config.dart' show AppColorTheme;

const appWindowSize = Size(1120, 760);
const appMinimumWindowSize = Size(900, 620);

const appRadiusControl = 8.0;
const appRadiusCompact = 20.0;
const appRadiusPill = 999.0;

const appSpace1 = 4.0;
const appSpace2 = 8.0;
const appSpace3 = 12.0;
const appSpace4 = 14.0;
const appSpace5 = 18.0;
const appSpace6 = 24.0;

const appCardPadding = EdgeInsets.all(appSpace4);
const appControlPadding = EdgeInsets.symmetric(
  horizontal: appSpace3,
  vertical: 10,
);
const appPillPadding = EdgeInsets.symmetric(horizontal: appSpace2, vertical: 3);

class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.surface,
    required this.card,
    required this.cardMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.danger,
    required this.heatmapLevels,
  });

  final Brightness brightness;
  final Color surface;
  final Color card;
  final Color cardMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color danger;
  final List<Color> heatmapLevels;
}

const _classicPalette = AppPalette(
  brightness: Brightness.light,
  surface: Color(0xFFF5F7FA),
  card: Color(0xFFFFFFFF),
  cardMuted: Color(0xFFEEF3F8),
  border: Color(0xFFDDE5EE),
  textPrimary: Color(0xFF17202A),
  textSecondary: Color(0xFF607080),
  accent: Color(0xFF2563EB),
  danger: Color(0xFFD14343),
  heatmapLevels: [
    Color(0xFFEFF3EF),
    Color(0xFF9BE9A8),
    Color(0xFF40C463),
    Color(0xFF30A14E),
    Color(0xFF216E39),
  ],
);

const _oceanPalette = AppPalette(
  brightness: Brightness.light,
  surface: Color(0xFFF2F8FA),
  card: Color(0xFFFFFFFF),
  cardMuted: Color(0xFFEAF4F7),
  border: Color(0xFFD3E4E8),
  textPrimary: Color(0xFF10242B),
  textSecondary: Color(0xFF5E7077),
  accent: Color(0xFF197B8A),
  danger: Color(0xFFC43D4B),
  heatmapLevels: [
    Color(0xFFE7F1F4),
    Color(0xFFB8E3EA),
    Color(0xFF76C7D2),
    Color(0xFF369EAD),
    Color(0xFF176B78),
  ],
);

const _rosePalette = AppPalette(
  brightness: Brightness.light,
  surface: Color(0xFFFBF5F7),
  card: Color(0xFFFFFFFF),
  cardMuted: Color(0xFFF8ECEF),
  border: Color(0xFFEBD5DB),
  textPrimary: Color(0xFF2A1B20),
  textSecondary: Color(0xFF75656A),
  accent: Color(0xFFA33F62),
  danger: Color(0xFFB3261E),
  heatmapLevels: [
    Color(0xFFF5E9EE),
    Color(0xFFF4B8CB),
    Color(0xFFE6799F),
    Color(0xFFB84570),
    Color(0xFF7F284B),
  ],
);

const _darkPalette = AppPalette(
  brightness: Brightness.dark,
  surface: Color(0xFF101418),
  card: Color(0xFF181D22),
  cardMuted: Color(0xFF20262C),
  border: Color(0xFF313A42),
  textPrimary: Color(0xFFF0F5F2),
  textSecondary: Color(0xFFA7B2AD),
  accent: Color(0xFF77C69A),
  danger: Color(0xFFFF8A80),
  heatmapLevels: [
    Color(0xFF20262C),
    Color(0xFF1F4E38),
    Color(0xFF28754B),
    Color(0xFF35A866),
    Color(0xFF74D990),
  ],
);

const _candyPalette = AppPalette(
  brightness: Brightness.light,
  surface: Color(0xFFFFF7FB),
  card: Color(0xFFFFFFFF),
  cardMuted: Color(0xFFFFECF3),
  border: Color(0xFFF4C8D6),
  textPrimary: Color(0xFF23323A),
  textSecondary: Color(0xFF69767D),
  accent: Color(0xFF31A9D8),
  danger: Color(0xFFC23B61),
  heatmapLevels: [
    Color(0xFFFFEFF5),
    Color(0xFFF5A9B8),
    Color(0xFFB9ECFA),
    Color(0xFF5BCEFA),
    Color(0xFFE9789E),
  ],
);

AppPalette appPaletteFor(AppColorTheme theme) {
  return switch (theme) {
    AppColorTheme.classic => _classicPalette,
    AppColorTheme.ocean => _oceanPalette,
    AppColorTheme.rose => _rosePalette,
    AppColorTheme.dark => _darkPalette,
    AppColorTheme.candy => _candyPalette,
  };
}

var appSurfaceColor = _classicPalette.surface;
var cardColor = _classicPalette.card;
var cardMutedColor = _classicPalette.cardMuted;
var borderColor = _classicPalette.border;
var textPrimaryColor = _classicPalette.textPrimary;
var textSecondaryColor = _classicPalette.textSecondary;
var accentColor = _classicPalette.accent;
var dangerColor = _classicPalette.danger;
var heatmapLevelColors = _classicPalette.heatmapLevels;

void applyAppColorTheme(AppColorTheme theme) {
  final palette = appPaletteFor(theme);
  appSurfaceColor = palette.surface;
  cardColor = palette.card;
  cardMutedColor = palette.cardMuted;
  borderColor = palette.border;
  textPrimaryColor = palette.textPrimary;
  textSecondaryColor = palette.textSecondary;
  accentColor = palette.accent;
  dangerColor = palette.danger;
  heatmapLevelColors = palette.heatmapLevels;
}

const appSystemFontFamily = 'Microsoft YaHei UI';
const appSystemFontFallback = <String>[
  'Segoe UI Variable Text',
  'Segoe UI',
  'Microsoft YaHei',
  'SimSun',
  'Arial',
];

ThemeData buildAppTheme([AppColorTheme colorTheme = AppColorTheme.classic]) {
  applyAppColorTheme(colorTheme);
  final palette = appPaletteFor(colorTheme);
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(appRadiusControl),
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(appRadiusControl),
    borderSide: BorderSide(color: palette.border),
  );
  final colorScheme = ColorScheme.fromSeed(
    seedColor: palette.accent,
    brightness: palette.brightness,
  ).copyWith(
    surface: palette.card,
    onSurface: palette.textPrimary,
    onSurfaceVariant: palette.textSecondary,
    primary: palette.accent,
    error: palette.danger,
  );
  final base = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: appSystemFontFamily,
    fontFamilyFallback: appSystemFontFallback,
    visualDensity: VisualDensity.compact,
  );
  final textTheme = base.textTheme.apply(
    fontFamily: appSystemFontFamily,
    fontFamilyFallback: appSystemFontFallback,
    bodyColor: palette.textPrimary,
    displayColor: palette.textPrimary,
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
      backgroundColor: palette.card,
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: palette.card,
      isDense: true,
      contentPadding: appControlPadding,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: palette.accent, width: 1.3),
      ),
      labelStyle: textTheme.bodyMedium,
      hintStyle: textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: appSpace2),
      iconColor: palette.textSecondary,
      textColor: palette.textPrimary,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: palette.cardMuted,
      selectedColor: palette.accent.withValues(alpha: 0.14),
      disabledColor: palette.cardMuted,
      side: BorderSide(color: palette.border),
      labelStyle: textTheme.labelMedium?.copyWith(color: palette.textPrimary),
      secondaryLabelStyle:
          textTheme.labelMedium?.copyWith(color: palette.textPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      shape: const StadiumBorder(),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: palette.card,
      textStyle: textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appRadiusControl),
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.border),
    iconTheme: base.iconTheme.copyWith(color: palette.textPrimary),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(34, 34),
        padding: const EdgeInsets.all(6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: textTheme.labelLarge,
        shape: controlShape,
        padding: appControlPadding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: textTheme.labelLarge,
        shape: controlShape,
        padding: appControlPadding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: textTheme.labelLarge,
        shape: controlShape,
        padding: appControlPadding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        textStyle: textTheme.labelLarge,
        shape: controlShape,
        padding: appControlPadding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
  );
}

final heatmapDefaultStartDate = DateTime(2026, 6, 1);
