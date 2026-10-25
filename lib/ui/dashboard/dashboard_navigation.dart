import 'package:flutter/material.dart';

import '../../models/app_config.dart' show DashboardModule;
import '../app_theme.dart';
import '../shared/app_page_header.dart';

enum DashboardSection {
  summary,
  training,
  todos,
  heatmap,
  problems,
  refreshLogs,
  contests,
  teammates,
  ojAccounts,
  daily,
  settings,
}

class DashboardShell extends StatelessWidget {
  const DashboardShell({
    super.key,
    required this.header,
    required this.currentSection,
    required this.onSectionSelected,
    required this.child,
    this.sections = DashboardSection.values,
  });

  final Widget header;
  final DashboardSection currentSection;
  final ValueChanged<DashboardSection> onSectionSelected;
  final Widget child;
  final List<DashboardSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('dashboard-shell'),
      backgroundColor: appSurfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            header,
            Expanded(
              child: Row(
                children: [
                  _DashboardRail(
                    sections: sections,
                    currentSection: currentSection,
                    onSectionSelected: onSectionSelected,
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: appSurfaceColor,
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardRail extends StatelessWidget {
  const _DashboardRail({
    required this.sections,
    required this.currentSection,
    required this.onSectionSelected,
  });

  final DashboardSection currentSection;
  final List<DashboardSection> sections;
  final ValueChanged<DashboardSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('dashboard-nav'),
      width: 232,
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(children: [
          const _RailHeader(),
          const SizedBox(height: 10),
          Expanded(
              child: SingleChildScrollView(
                  child: Column(children: [
            for (final section in sections)
              if (section != DashboardSection.settings)
                DashboardNavButton(
                    section: section,
                    selected: section == currentSection,
                    onTap: () => onSectionSelected(section)),
          ]))),
          if (sections.contains(DashboardSection.settings)) ...[
            const SizedBox(height: 4),
            Divider(height: 12, color: borderColor),
            DashboardNavButton(
                section: DashboardSection.settings,
                selected: currentSection == DashboardSection.settings,
                onTap: () => onSectionSelected(DashboardSection.settings)),
          ],
        ]),
      ),
    );
  }
}

DashboardSection sectionForModule(DashboardModule module) =>
    DashboardSection.values.byName(module.name);

class _RailHeader extends StatelessWidget {
  const _RailHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                border: Border.all(color: accentColor),
                borderRadius: BorderRadius.circular(appRadiusControl),
              ),
              child: Text('OJ',
                  style: TextStyle(
                      color: accentColor,
                      fontFamily: appMonoFontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text('OJ Float',
                  style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
            Text('0.3',
                style: TextStyle(
                    color: textSecondaryColor,
                    fontFamily: appMonoFontFamily,
                    fontSize: 10)),
          ]),
          const SizedBox(height: 16),
          Text('工作台',
              style: TextStyle(
                  color: textSecondaryColor,
                  fontFamily: appMonoFontFamily,
                  fontSize: 10,
                  letterSpacing: 1.1)),
        ],
      ),
    );
  }
}

class DashboardNavButton extends StatelessWidget {
  const DashboardNavButton({
    super.key,
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final DashboardSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? accentColor : textSecondaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color:
            selected ? accentColor.withValues(alpha: 0.13) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appRadiusControl),
          side: BorderSide(
            color: selected
                ? accentColor.withValues(alpha: 0.42)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          key: ValueKey('dashboard-nav-${section.name}'),
          borderRadius: BorderRadius.circular(appRadiusControl),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: selected ? accentColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(sectionIcon(section), size: 18, color: color),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    sectionLabel(section),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? textPrimaryColor : textSecondaryColor,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardSectionTitle extends StatelessWidget {
  const DashboardSectionTitle({
    super.key,
    required this.section,
    this.subtitle,
  });

  final DashboardSection section;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => AppPageHeader(
        title: section == DashboardSection.summary
            ? '今天，先把下一题做完。'
            : sectionLabel(section),
        subtitle: subtitle ??
            (section == DashboardSection.summary
                ? '看一眼进度，继续训练，留下可复盘的记录。'
                : null),
      );
}

String sectionLabel(DashboardSection section) {
  return switch (section) {
    DashboardSection.summary => '总览',
    DashboardSection.training => '训练',
    DashboardSection.todos => '待办事项',
    DashboardSection.heatmap => dashboardModuleLabel(DashboardModule.heatmap),
    DashboardSection.problems => dashboardModuleLabel(DashboardModule.problems),
    DashboardSection.refreshLogs =>
      dashboardModuleLabel(DashboardModule.refreshLogs),
    DashboardSection.contests => dashboardModuleLabel(DashboardModule.contests),
    DashboardSection.teammates =>
      dashboardModuleLabel(DashboardModule.teammates),
    DashboardSection.ojAccounts =>
      dashboardModuleLabel(DashboardModule.ojAccounts),
    DashboardSection.daily => dashboardModuleLabel(DashboardModule.daily),
    DashboardSection.settings => '设置',
  };
}

IconData sectionIcon(DashboardSection section) {
  return switch (section) {
    DashboardSection.summary => Icons.query_stats,
    DashboardSection.training => Icons.timer_outlined,
    DashboardSection.todos => Icons.checklist_outlined,
    DashboardSection.heatmap => dashboardModuleIcon(DashboardModule.heatmap),
    DashboardSection.problems => dashboardModuleIcon(DashboardModule.problems),
    DashboardSection.refreshLogs =>
      dashboardModuleIcon(DashboardModule.refreshLogs),
    DashboardSection.contests => dashboardModuleIcon(DashboardModule.contests),
    DashboardSection.teammates =>
      dashboardModuleIcon(DashboardModule.teammates),
    DashboardSection.ojAccounts =>
      dashboardModuleIcon(DashboardModule.ojAccounts),
    DashboardSection.daily => dashboardModuleIcon(DashboardModule.daily),
    DashboardSection.settings => Icons.tune,
  };
}

String dashboardModuleLabel(DashboardModule module) {
  return switch (module) {
    DashboardModule.summary => '总览',
    DashboardModule.training => '训练',
    DashboardModule.heatmap => '热力图',
    DashboardModule.problems => '补题',
    DashboardModule.refreshLogs => '刷新日志',
    DashboardModule.contests => '训练赛',
    DashboardModule.teammates => '队友',
    DashboardModule.ojAccounts => 'OJ 账号',
    DashboardModule.daily => '每日总结',
  };
}

IconData dashboardModuleIcon(DashboardModule module) {
  return switch (module) {
    DashboardModule.summary => Icons.query_stats,
    DashboardModule.training => Icons.timer_outlined,
    DashboardModule.heatmap => Icons.calendar_view_week,
    DashboardModule.problems => Icons.bookmark_border,
    DashboardModule.refreshLogs => Icons.history,
    DashboardModule.contests => Icons.emoji_events_outlined,
    DashboardModule.teammates => Icons.groups_2_outlined,
    DashboardModule.ojAccounts => Icons.account_circle_outlined,
    DashboardModule.daily => Icons.today_outlined,
  };
}
