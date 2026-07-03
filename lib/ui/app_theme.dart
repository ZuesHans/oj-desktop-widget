import 'package:flutter/material.dart';

import '../models/app_config.dart';

const compactWindowSize = Size(340, 154);
const compactMinimumWindowSize = Size(300, 132);
const largeFloatWindowSize = Size(380, 540);
const largeFloatMinimumWindowSize = Size(330, 440);
const dashboardWindowSize = Size(960, 680);
const dashboardMinimumWindowSize = Size(760, 520);
const heatmapWindowSize = Size(560, 560);
const heatmapMinimumWindowSize = Size(440, 420);

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
    required this.compactSurface,
    required this.compactLabel,
    required this.compactText,
    required this.compactShadow,
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
  final Color compactSurface;
  final Color compactLabel;
  final Color compactText;
  final Color compactShadow;
  final List<Color> heatmapLevels;
}

const _classicPalette = AppPalette(
  brightness: Brightness.light,
  surface: Color(0xFFF6F7F4),
  card: Color(0xFFFFFFFF),
  cardMuted: Color(0xFFF4F6F3),
  border: Color(0xFFE1E4DE),
  textPrimary: Color(0xFF17211D),
  textSecondary: Color(0xFF64706A),
  accent: Color(0xFF2F6F4E),
  danger: Color(0xFFB3261E),
  compactSurface: Color(0xF2F9FBF8),
  compactLabel: Color(0xFF42655C),
  compactText: Color(0xFF10231E),
  compactShadow: Color(0x26000000),
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
  compactSurface: Color(0xF2F4FBFD),
  compactLabel: Color(0xFF2F7280),
  compactText: Color(0xFF0E2D35),
  compactShadow: Color(0x24072E36),
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
  compactSurface: Color(0xF2FFF7FA),
  compactLabel: Color(0xFF9B4967),
  compactText: Color(0xFF34161F),
  compactShadow: Color(0x26000000),
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
  compactSurface: Color(0xF01A2026),
  compactLabel: Color(0xFF93D7AF),
  compactText: Color(0xFFF5FFF8),
  compactShadow: Color(0x66000000),
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
  compactSurface: Color(0xF8FFFFFF),
  compactLabel: Color(0xFFE9789E),
  compactText: Color(0xFF23323A),
  compactShadow: Color(0x240A6A8C),
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
var compactSurfaceColor = _classicPalette.compactSurface;
var compactLabelColor = _classicPalette.compactLabel;
var compactTextColor = _classicPalette.compactText;
var compactShadowColor = _classicPalette.compactShadow;
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
  compactSurfaceColor = palette.compactSurface;
  compactLabelColor = palette.compactLabel;
  compactTextColor = palette.compactText;
  compactShadowColor = palette.compactShadow;
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
    borderRadius: BorderRadius.circular(8),
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: textTheme.labelLarge,
        shape: controlShape,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: textTheme.labelLarge,
        shape: controlShape,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        textStyle: textTheme.labelLarge,
        shape: controlShape,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
  );
}

final heatmapDefaultStartDate = DateTime(2026, 6, 1);
