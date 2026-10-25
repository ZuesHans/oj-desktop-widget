import 'package:flutter/material.dart';

import '../models/app_config.dart' show AppColorTheme, AppAppearanceMode;

const appWindowSize = Size(1120, 760);
const appMinimumWindowSize = Size(900, 620);

const appRadiusControl = 8.0;
const appRadiusCard = 9.0;
const appRadiusCompact = 20.0;
const appRadiusPill = 999.0;

const appSpace1 = 4.0;
const appSpace2 = 8.0;
const appSpace3 = 12.0;
const appSpace4 = 16.0;
const appSpace5 = 18.0;
const appSpace6 = 24.0;

const appCardPadding = EdgeInsets.all(20);
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
    required this.warning,
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
  final Color warning;
  final Color danger;
  final List<Color> heatmapLevels;
}

const _githubLightPalette = AppPalette(
  brightness: Brightness.light,
  surface: Color(0xFFF6F8FA),
  card: Color(0xFFFFFFFF),
  cardMuted: Color(0xFFF0F3F6),
  border: Color(0xFFD0D7DE),
  textPrimary: Color(0xFF1F2328),
  textSecondary: Color(0xFF656D76),
  accent: Color(0xFF0969DA),
  warning: Color(0xFF9A6700),
  danger: Color(0xFFCF222E),
  heatmapLevels: [
    Color(0xFFEAF2E9),
    Color(0xFFACD7A5),
    Color(0xFF6FBA65),
    Color(0xFF3B9140),
    Color(0xFF216E39)
  ],
);

const _terminalDarkPalette = AppPalette(
  brightness: Brightness.dark,
  surface: Color(0xFF0F1115),
  card: Color(0xFF171A21),
  cardMuted: Color(0xFF202630),
  border: Color(0xFF303846),
  textPrimary: Color(0xFFE6EDF3),
  textSecondary: Color(0xFF8B98A8),
  accent: Color(0xFF58A6FF),
  warning: Color(0xFFD29922),
  danger: Color(0xFFF85149),
  heatmapLevels: [
    Color(0xFF202630),
    Color(0xFF1F4E38),
    Color(0xFF28754B),
    Color(0xFF35A866),
    Color(0xFF74D990)
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
  warning: Color(0xFF9A6700),
  danger: Color(0xFFC43D4B),
  heatmapLevels: [
    Color(0xFFEAF4F7),
    Color(0xFFB5DDE2),
    Color(0xFF79BBC7),
    Color(0xFF4698AB),
    Color(0xFF197B8A)
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
  warning: Color(0xFF9A4056),
  danger: Color(0xFFB3261E),
  heatmapLevels: [
    Color(0xFFF8ECEF),
    Color(0xFFF0C7D4),
    Color(0xFFD995AE),
    Color(0xFFBE6588),
    Color(0xFFA33F62)
  ],
);

const _classicPalette = AppPalette(
  brightness: Brightness.light,
  surface: Color(0xFFF5F7FA),
  card: Color(0xFFFFFFFF),
  cardMuted: Color(0xFFEEF3F8),
  border: Color(0xFFDDE5EE),
  textPrimary: Color(0xFF17202A),
  textSecondary: Color(0xFF607080),
  accent: Color(0xFF2563EB),
  warning: Color(0xFF9A6700),
  danger: Color(0xFFD14343),
  heatmapLevels: [
    Color(0xFFEFF3EF),
    Color(0xFF9BE9A8),
    Color(0xFF40C463),
    Color(0xFF30A14E),
    Color(0xFF216E39),
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
  warning: Color(0xFFEFBB6B),
  danger: Color(0xFFFF8A80),
  heatmapLevels: [
    Color(0xFF20262C),
    Color(0xFF1F4E38),
    Color(0xFF28754B),
    Color(0xFF35A866),
    Color(0xFF74D990),
  ],
);

// The default workspace palette is intentionally quiet and high contrast:
// dark green surfaces keep the dashboard focused on progress and actions
// without the glossy gradients that made the previous preview feel generic.
const _workbenchPalette = AppPalette(
  brightness: Brightness.dark,
  surface: Color(0xFF0D1210),
  card: Color(0xFF151D19),
  cardMuted: Color(0xFF19231F),
  border: Color(0xFF2B3A33),
  textPrimary: Color(0xFFEDF5EF),
  textSecondary: Color(0xFF9EADA5),
  accent: Color(0xFF83D9A1),
  warning: Color(0xFFEFBB6B),
  danger: Color(0xFFED8178),
  heatmapLevels: [
    Color(0xFF26342C),
    Color(0xFF31563F),
    Color(0xFF4E8B61),
    Color(0xFF70BD83),
    Color(0xFF83D9A1),
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
  warning: Color(0xFFB76A2A),
  danger: Color(0xFFC23B61),
  heatmapLevels: [
    Color(0xFFFFEFF5),
    Color(0xFFF5A9B8),
    Color(0xFFB9ECFA),
    Color(0xFF5BCEFA),
    Color(0xFFE9789E),
  ],
);

AppPalette appPaletteFor(AppColorTheme theme, {Brightness? brightness}) {
  final palette = switch (theme) {
    AppColorTheme.workbench => _workbenchPalette,
    AppColorTheme.githubLight => _githubLightPalette,
    AppColorTheme.terminalDark => _terminalDarkPalette,
    AppColorTheme.classic => _classicPalette,
    AppColorTheme.dark => _darkPalette,
    AppColorTheme.candy => _candyPalette,
    AppColorTheme.ocean => _oceanPalette,
    AppColorTheme.rose => _rosePalette,
    AppColorTheme.sage ||
    AppColorTheme.ink ||
    AppColorTheme.warm =>
      _studioPalette(theme, brightness ?? Brightness.light),
  };
  if (brightness == null || brightness == palette.brightness) return palette;
  final dark = brightness == Brightness.dark;
  return AppPalette(
    brightness: brightness,
    surface: dark ? const Color(0xFF131B24) : const Color(0xFFF5F7FA),
    card: dark ? const Color(0xFF1C2835) : Colors.white,
    cardMuted: dark ? const Color(0xFF263649) : const Color(0xFFEEF3F8),
    border: dark ? const Color(0xFF384B61) : const Color(0xFFDDE5EE),
    textPrimary: dark ? const Color(0xFFE6EDF7) : const Color(0xFF203047),
    textSecondary: dark ? const Color(0xFFA6B5CC) : const Color(0xFF62718A),
    accent: Color.lerp(palette.accent, dark ? Colors.white : Colors.black,
        dark ? 0.38 : 0.28)!,
    warning: dark ? const Color(0xFFF0C674) : const Color(0xFF8A5A00),
    danger: dark ? const Color(0xFFFFA29B) : const Color(0xFFAE3D37),
    heatmapLevels:
        dark ? _darkPalette.heatmapLevels : _classicPalette.heatmapLevels,
  );
}

AppPalette _studioPalette(AppColorTheme theme, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors = switch (theme) {
    AppColorTheme.ink => dark
        ? [
            0xFF141B2B,
            0xFF1D273A,
            0xFF303F64,
            0xFF35445F,
            0xFFE1E9FA,
            0xFFA6B5CF,
            0xFFB1C3FF
          ]
        : [
            0xFFF3F5FA,
            0xFFFFFFFF,
            0xFFEAF0FE,
            0xFFDFE5F0,
            0xFF26344E,
            0xFF66748D,
            0xFF4B63A8
          ],
    AppColorTheme.warm => dark
        ? [
            0xFF211D18,
            0xFF2D271F,
            0xFF493923,
            0xFF4C4134,
            0xFFF1E4D1,
            0xFFBBAA92,
            0xFFEBC08B
          ]
        : [
            0xFFF9F5EE,
            0xFFFFFCF6,
            0xFFF4E9D8,
            0xFFE9DFCF,
            0xFF493A2B,
            0xFF7D6B56,
            0xFF94612E
          ],
    _ => dark
        ? [
            0xFF131C20,
            0xFF1B282D,
            0xFF28443A,
            0xFF344941,
            0xFFE4EFEC,
            0xFFA2B7B0,
            0xFF8BD4B8
          ]
        : [
            0xFFF3F6F6,
            0xFFFFFFFF,
            0xFFE7F3ED,
            0xFFDDE7E2,
            0xFF203532,
            0xFF60746E,
            0xFF276E59
          ],
  };
  return AppPalette(
      brightness: brightness,
      surface: Color(colors[0]),
      card: Color(colors[1]),
      cardMuted: Color(colors[2]),
      border: Color(colors[3]),
      textPrimary: Color(colors[4]),
      textSecondary: Color(colors[5]),
      accent: Color(colors[6]),
      warning: Color(dark ? 0xFFEBC08B : 0xFF94612E),
      danger: Color(dark ? 0xFFF0A29B : 0xFFAE3D37),
      heatmapLevels:
          dark ? _darkPalette.heatmapLevels : _classicPalette.heatmapLevels);
}

var appSurfaceColor = _workbenchPalette.surface;
var cardColor = _workbenchPalette.card;
var cardMutedColor = _workbenchPalette.cardMuted;
var borderColor = _workbenchPalette.border;
var textPrimaryColor = _workbenchPalette.textPrimary;
var textSecondaryColor = _workbenchPalette.textSecondary;
var accentColor = _workbenchPalette.accent;
var warningColor = _workbenchPalette.warning;
var dangerColor = _workbenchPalette.danger;
var heatmapLevelColors = _workbenchPalette.heatmapLevels;

void applyAppColorTheme(AppColorTheme theme, {Brightness? brightness}) {
  final palette = appPaletteFor(theme, brightness: brightness);
  appSurfaceColor = palette.surface;
  cardColor = palette.card;
  cardMutedColor = palette.cardMuted;
  borderColor = palette.border;
  textPrimaryColor = palette.textPrimary;
  textSecondaryColor = palette.textSecondary;
  accentColor = palette.accent;
  warningColor = palette.warning;
  dangerColor = palette.danger;
  heatmapLevelColors = palette.heatmapLevels;
}

const appSystemFontFamily = 'Segoe UI Variable Text';
// Keep numeric emphasis consistent on machines without Cascadia Code. The
// Windows UI font has the same crisp rhythm and preserves CJK fallback.
const appMonoFontFamily = appSystemFontFamily;
const appSystemFontFallback = <String>[
  'Segoe UI Variable Text',
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'SimSun',
  'Arial',
];

ThemeData buildAppTheme([
  AppColorTheme colorTheme = AppColorTheme.classic,
  AppAppearanceMode appearanceMode = AppAppearanceMode.system,
  Brightness? systemBrightness,
  bool compactDensity = false,
]) {
  final brightness = switch (appearanceMode) {
    AppAppearanceMode.system => systemBrightness,
    AppAppearanceMode.light => Brightness.light,
    AppAppearanceMode.dark => Brightness.dark,
  };
  // Preserve dark skins in system mode; explicit light/dark takes precedence.
  final effective = appearanceMode == AppAppearanceMode.system &&
          (colorTheme == AppColorTheme.workbench ||
              colorTheme == AppColorTheme.terminalDark ||
              colorTheme == AppColorTheme.dark)
      ? Brightness.dark
      : brightness;
  applyAppColorTheme(colorTheme, brightness: effective);
  final palette = appPaletteFor(colorTheme, brightness: effective);
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
    surfaceTint: Colors.transparent,
    onSurface: palette.textPrimary,
    onSurfaceVariant: palette.textSecondary,
    primary: palette.accent,
    onPrimary:
        ThemeData.estimateBrightnessForColor(palette.accent) == Brightness.light
            ? const Color(0xFF10242B)
            : Colors.white,
    outline: palette.border,
    outlineVariant: palette.border,
    error: palette.danger,
  );
  final base = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: appSystemFontFamily,
    fontFamilyFallback: appSystemFontFallback,
    visualDensity:
        compactDensity ? VisualDensity.compact : VisualDensity.standard,
  );
  final textTheme = base.textTheme
      .apply(
        fontFamily: appSystemFontFamily,
        fontFamilyFallback: appSystemFontFallback,
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      )
      .copyWith(
        headlineSmall: TextStyle(
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
            letterSpacing: -0.7),
        titleLarge: TextStyle(
            fontSize: 22,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: palette.textPrimary),
        titleMedium: TextStyle(
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: palette.textPrimary),
        bodyLarge:
            TextStyle(fontSize: 14, height: 1.6, color: palette.textPrimary),
        bodyMedium:
            TextStyle(fontSize: 14, height: 1.55, color: palette.textPrimary),
        bodySmall:
            TextStyle(fontSize: 12, height: 1.5, color: palette.textSecondary),
        labelLarge: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: palette.textPrimary),
        labelMedium: TextStyle(
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w400,
            color: palette.textPrimary),
      )
      .apply(
          fontFamily: appSystemFontFamily,
          fontFamilyFallback: appSystemFontFallback);

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
      surfaceTintColor: Colors.transparent,
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
      titleTextStyle: textTheme.bodyMedium,
      subtitleTextStyle: textTheme.bodySmall,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: palette.card,
      textStyle: textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appRadiusControl),
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.border),
    expansionTileTheme: ExpansionTileThemeData(
      shape: const Border(),
      collapsedShape: const Border(),
      textColor: palette.textPrimary,
      collapsedTextColor: palette.textPrimary,
      iconColor: palette.textSecondary,
      collapsedIconColor: palette.textSecondary,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? palette.textSecondary.withValues(alpha: 0.3)
              : states.contains(WidgetState.selected)
                  ? colorScheme.onPrimary
                  : palette.textSecondary),
      trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? palette.cardMuted
              : states.contains(WidgetState.selected)
                  ? palette.accent
                  : palette.cardMuted),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? palette.accent
              : palette.border),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelStyle: textTheme.labelLarge,
      unselectedLabelStyle: textTheme.labelLarge,
      labelColor: palette.accent,
      unselectedLabelColor: palette.textSecondary,
      dividerColor: palette.border,
      indicatorSize: TabBarIndicatorSize.label,
    ),
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
        side: BorderSide(color: palette.border),
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
