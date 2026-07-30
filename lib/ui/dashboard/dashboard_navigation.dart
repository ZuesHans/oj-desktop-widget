import 'package:flutter/material.dart';

import '../../models/app_config.dart' show DashboardModule;
import '../app_theme.dart';

enum DashboardSection {
  summary,
  training,
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
  });

  final Widget header;
  final DashboardSection currentSection;
  final ValueChanged<DashboardSection> onSectionSelected;
  final Widget child;

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
    required this.currentSection,
    required this.onSectionSelected,
  });

  final DashboardSection currentSection;
  final ValueChanged<DashboardSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('dashboard-nav'),
      width: 184,
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        children: [
          const _RailHeader(),
          const SizedBox(height: 10),
          for (final section in DashboardSection.values)
            DashboardNavButton(
              section: section,
              selected: section == currentSection,
              onTap: () => onSectionSelected(section),
            ),
        ],
      ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '训练工作台',
            style: TextStyle(
              color: textPrimaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '账号、补题和复盘',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textSecondaryColor, fontSize: 12),
          ),
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
            selected ? accentColor.withValues(alpha: 0.11) : Colors.transparent,
        borderRadius: BorderRadius.circular(appRadiusControl),
        child: InkWell(
          key: ValueKey('dashboard-nav-${section.name}'),
          borderRadius: BorderRadius.circular(appRadiusControl),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(appRadiusControl),
          ),
          child: Icon(sectionIcon(section), color: accentColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sectionLabel(section),
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: 22,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(color: textSecondaryColor),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String sectionLabel(DashboardSection section) {
  return switch (section) {
    DashboardSection.summary => '总览',
    DashboardSection.training => '训练',
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
