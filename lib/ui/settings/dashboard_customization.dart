import 'package:flutter/material.dart';

import '../../models/app_config.dart';
import '../dashboard/dashboard_navigation.dart';
import '../app_theme.dart';

class DashboardCustomization extends StatelessWidget {
  const DashboardCustomization({
    super.key,
    required this.enabled,
    required this.order,
    required this.wide,
    required this.onEnabledChanged,
    required this.onOrderChanged,
    required this.onWideChanged,
  });

  final List<DashboardModule> enabled;
  final List<DashboardModule> order;
  final List<DashboardModule> wide;
  final ValueChanged<List<DashboardModule>> onEnabledChanged;
  final ValueChanged<List<DashboardModule>> onOrderChanged;
  final ValueChanged<List<DashboardModule>> onWideChanged;

  void _move(int index, int delta) {
    final next = [...order];
    final item = next.removeAt(index);
    next.insert(index + delta, item);
    onOrderChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('关闭功能区会隐藏入口并停止相关后台任务，已有数据保留。'
            '训练使用题库数据时，仍会维护必要的数据同步。'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton(
            onPressed: () {
              onEnabledChanged([...defaultDashboardModules]);
              onOrderChanged([...defaultDashboardModules]);
              onWideChanged([...defaultWideDashboardModules]);
            },
            child: const Text('原版完整功能'),
          ),
          OutlinedButton(
            onPressed: () => onEnabledChanged([
              DashboardModule.summary,
              DashboardModule.training,
              DashboardModule.problems,
              DashboardModule.heatmap,
              DashboardModule.ojAccounts,
              DashboardModule.refreshLogs,
              DashboardModule.daily,
            ]),
            child: const Text('训练为主'),
          ),
          OutlinedButton(
            onPressed: () => onEnabledChanged([DashboardModule.problems]),
            child: const Text('只用题库'),
          ),
        ]),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth >= 620
              ? (constraints.maxWidth - 28) / 2
              : constraints.maxWidth;
          return Wrap(spacing: 28, runSpacing: 0, children: [
            for (var index = 0; index < order.length; index++)
              SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: borderColor))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            key: ValueKey(
                                'dashboard-module-switch-${order[index].id}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(dashboardModuleLabel(order[index])),
                            secondary: Icon(dashboardModuleIcon(order[index])),
                            subtitle: Text(_description(order[index])),
                            value: enabled.contains(order[index]),
                            onChanged: (value) => onEnabledChanged(value
                                ? [...enabled, order[index]]
                                : enabled
                                    .where((m) => m != order[index])
                                    .toList()),
                          ),
                          if (enabled.contains(order[index]))
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                IconButton(
                                  key: ValueKey(
                                      'dashboard-move-up-${order[index].id}'),
                                  tooltip:
                                      '上移${dashboardModuleLabel(order[index])}',
                                  onPressed: index == 0
                                      ? null
                                      : () => _move(index, -1),
                                  icon:
                                      const Icon(Icons.arrow_upward, size: 18),
                                ),
                                IconButton(
                                  key: ValueKey(
                                      'dashboard-move-down-${order[index].id}'),
                                  tooltip:
                                      '下移${dashboardModuleLabel(order[index])}',
                                  onPressed: index == order.length - 1
                                      ? null
                                      : () => _move(index, 1),
                                  icon: const Icon(Icons.arrow_downward,
                                      size: 18),
                                ),
                                if (order[index] != DashboardModule.summary)
                                  DropdownButton<bool>(
                                    key: ValueKey(
                                        'dashboard-width-${order[index].id}'),
                                    value: wide.contains(order[index]),
                                    items: const [
                                      DropdownMenuItem(
                                          value: false, child: Text('半行')),
                                      DropdownMenuItem(
                                          value: true, child: Text('整行')),
                                    ],
                                    onChanged: (value) => onWideChanged(
                                        value == true
                                            ? {...wide, order[index]}.toList()
                                            : wide
                                                .where((m) => m != order[index])
                                                .toList()),
                                  ),
                              ],
                            ),
                        ]),
                  )),
          ]);
        }),
        const SizedBox(height: 12),
        const Text('保存设置后生效。设置、备份与恢复始终可用。'),
      ],
    );
  }
}

String _description(DashboardModule module) => switch (module) {
      DashboardModule.summary => '累计通过数、今日进度和待处理状态',
      DashboardModule.training => '每日安排、计时、题单与训练复盘',
      DashboardModule.heatmap => '从已保存的快照查看训练节奏',
      DashboardModule.problems => '补题、错题、文件夹、标签和快速录入',
      DashboardModule.refreshLogs => '查看已保存的抓取结果和失败原因',
      DashboardModule.contests => '比赛记录、排名和复盘',
      DashboardModule.teammates => '关闭后停止队友抓取，保留观察记录',
      DashboardModule.ojAccounts => '关闭后停止自己的 OJ 账号抓取',
      DashboardModule.daily => '查看每日增量和训练总结',
    };
