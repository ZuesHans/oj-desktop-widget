import 'package:flutter/material.dart';

import '../../models/app_config.dart';
import '../app_theme.dart';

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({
    super.key,
    required this.colorTheme,
    required this.appearanceMode,
    required this.compactDensity,
    required this.onThemeChanged,
    required this.onModeChanged,
    required this.onDensityChanged,
  });

  final AppColorTheme colorTheme;
  final AppAppearanceMode appearanceMode;
  final bool compactDensity;
  final ValueChanged<AppColorTheme> onThemeChanged;
  final ValueChanged<AppAppearanceMode> onModeChanged;
  final ValueChanged<bool> onDensityChanged;

  Brightness _brightness(BuildContext context, AppColorTheme theme) =>
      switch (appearanceMode) {
        AppAppearanceMode.light => Brightness.light,
        AppAppearanceMode.dark => Brightness.dark,
        AppAppearanceMode.system => theme == AppColorTheme.workbench ||
                theme == AppColorTheme.dark ||
                theme == AppColorTheme.terminalDark
            ? Brightness.dark
            : MediaQuery.platformBrightnessOf(context),
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<AppColorTheme>(
          key: const ValueKey('color-theme-field'),
          initialValue: colorTheme,
          decoration: const InputDecoration(labelText: '配色主题'),
          items: [
            for (final theme in AppColorTheme.values)
              DropdownMenuItem(value: theme, child: Text(_themeLabel(theme))),
          ],
          onChanged: (value) {
            if (value != null) onThemeChanged(value);
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 440 ? 3 : 1;
          final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final theme in const [
              AppColorTheme.sage,
              AppColorTheme.ink,
              AppColorTheme.warm
            ])
              SizedBox(
                width: width,
                child: _ThemeChoice(
                  theme: theme,
                  palette: appPaletteFor(theme,
                      brightness: _brightness(context, theme)),
                  selected: colorTheme == theme,
                  onTap: () => onThemeChanged(theme),
                ),
              ),
          ]);
        }),
        const SizedBox(height: 16),
        _ThemePreview(
          palette: appPaletteFor(colorTheme,
              brightness: _brightness(context, colorTheme)),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<AppAppearanceMode>(
          key: const ValueKey('appearance-mode-field'),
          initialValue: appearanceMode,
          decoration: const InputDecoration(labelText: '显示模式'),
          items: const [
            DropdownMenuItem(
                value: AppAppearanceMode.system, child: Text('跟随系统')),
            DropdownMenuItem(value: AppAppearanceMode.light, child: Text('浅色')),
            DropdownMenuItem(value: AppAppearanceMode.dark, child: Text('深色')),
          ],
          onChanged: (value) {
            if (value != null) onModeChanged(value);
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const ValueKey('compact-density-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('紧凑内容密度'),
          subtitle: const Text('缩小控件间距，保留清晰的文字'),
          value: compactDensity,
          onChanged: onDensityChanged,
        ),
      ],
    );
  }
}

String _themeLabel(AppColorTheme theme) => switch (theme) {
      AppColorTheme.workbench => 'Workbench · 深色工作台',
      AppColorTheme.githubLight => 'GitHub Light · 开发者浅色',
      AppColorTheme.terminalDark => 'Terminal Dark · 竞赛终端',
      AppColorTheme.classic => 'Classic · 经典蓝',
      AppColorTheme.dark => 'Dark · 原版深色',
      AppColorTheme.candy => 'Candy · 糖果粉蓝',
      AppColorTheme.ocean => 'Ocean · 海洋青',
      AppColorTheme.rose => 'Rose · 玫瑰粉',
      AppColorTheme.sage => '雾青',
      AppColorTheme.ink => '靛蓝',
      AppColorTheme.warm => '暖杏',
    };

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice(
      {required this.theme,
      required this.palette,
      required this.selected,
      required this.onTap});

  final AppColorTheme theme;
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        child: OutlinedButton(
          key: ValueKey('theme-choice-${theme.name}'),
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: palette.card,
            foregroundColor: palette.textPrimary,
            side: BorderSide(
                color: selected ? palette.accent : palette.border,
                width: selected ? 1.5 : 1),
            padding: const EdgeInsets.all(14),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              height: 46,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(5)),
              child: Row(children: [
                Container(
                    width: 14,
                    decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 7),
                Expanded(
                    child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: palette.cardMuted,
                      borderRadius: BorderRadius.circular(3)),
                  child: const SizedBox.expand(),
                )),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Text(_themeLabel(theme))),
              if (selected)
                Icon(Icons.check_circle_outline,
                    size: 16, color: palette.accent),
            ]),
          ]),
        ),
      );
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('color-theme-preview'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.border)),
        child: Row(children: [
          Icon(Icons.auto_stories_outlined, color: palette.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('我的题目与笔记',
                    style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('先预览，再保存到工作台。',
                    style:
                        TextStyle(color: palette.textSecondary, fontSize: 12)),
              ])),
          const SizedBox(width: 8),
          for (final color in palette.heatmapLevels)
            Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2))),
        ]),
      );
}
