import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

const supportedOjs = <OjMeta>[
  OjMeta(
    id: 'codeforces',
    name: 'Codeforces',
    hint: 'handle',
    profileBaseUrl: 'https://codeforces.com/profile/',
  ),
  OjMeta(
    id: 'leetcode',
    name: 'LeetCode',
    hint: 'username',
    profileBaseUrl: 'https://leetcode.com/',
  ),
  OjMeta(
    id: 'atcoder',
    name: 'AtCoder',
    hint: 'username',
    profileBaseUrl: 'https://atcoder.jp/users/',
  ),
  OjMeta(
    id: 'luogu',
    name: '洛谷',
    hint: '数字 UID',
    profileBaseUrl: 'https://www.luogu.com.cn/user/',
  ),
  OjMeta(
    id: 'nowcoder',
    name: '牛客',
    hint: '数字用户 ID',
    profileBaseUrl: 'https://www.nowcoder.com/users/',
  ),
];

const _compactWindowSize = Size(220, 116);
const _compactMinimumWindowSize = Size(200, 96);
const _dashboardWindowSize = Size(360, 520);
const _dashboardMinimumWindowSize = Size(320, 420);

enum AppDisplayMode { compact, dashboard }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: _compactWindowSize,
      minimumSize: _compactMinimumWindowSize,
      center: true,
      title: 'OJ Float',
      titleBarStyle: TitleBarStyle.hidden,
      alwaysOnTop: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const OjFloatApp());
}

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

class OjFloatHome extends StatefulWidget {
  const OjFloatHome({
    super.key,
    this.enablePlatformIntegration = true,
    this.autoInitializeController = true,
  });

  final bool enablePlatformIntegration;
  final bool autoInitializeController;

  @override
  State<OjFloatHome> createState() => _OjFloatHomeState();
}

class _OjFloatHomeState extends State<OjFloatHome>
    with TrayListener, WindowListener {
  late final OjController _controller;
  AppDisplayMode _mode = AppDisplayMode.compact;

  @override
  void initState() {
    super.initState();
    _controller = OjController(
      storage: LocalStore(),
      service: RefreshService(
        client: http.Client(),
        providers: {
          'codeforces': CodeforcesProvider(),
          'leetcode': LeetCodeProvider(),
          'atcoder': AtCoderProvider(),
          'luogu': LuoguProvider(),
          'nowcoder': NowcoderProvider(),
        },
      ),
    );
    if (widget.enablePlatformIntegration) {
      trayManager.addListener(this);
      windowManager.addListener(this);
      unawaited(_setupTray());
    }
    if (widget.autoInitializeController) {
      unawaited(_controller.init());
    }
  }

  Future<void> _setupTray() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }
    if (Platform.isWindows) {
      final iconFile = await _extractTrayIcon();
      await trayManager.setIcon(iconFile.path);
    }
    await trayManager.setToolTip('OJ Float');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '显示'),
          MenuItem.separator(),
          MenuItem(key: 'refresh', label: '立即刷新'),
          MenuItem(key: 'exit', label: '退出'),
        ],
      ),
    );
  }

  Future<File> _extractTrayIcon() async {
    final bytes = await rootBundle.load('assets/app_icon.ico');
    final directory = await getTemporaryDirectory();
    final iconFile =
        File('${directory.path}${Platform.pathSeparator}oj_float_app_icon.ico');
    await iconFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return iconFile;
  }

  @override
  void dispose() {
    if (widget.enablePlatformIntegration) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'refresh':
        await _controller.refresh();
        break;
      case 'exit':
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
        break;
    }
  }

  @override
  void onWindowClose() async {
    await windowManager.minimize();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_mode == AppDisplayMode.compact) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: _CompactWidget(
              state: _controller.state,
              refreshing: _controller.refreshing,
              onRefresh: _controller.refreshing ? null : _controller.refresh,
              onOpenDashboard: () => _setMode(AppDisplayMode.dashboard),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7F4),
          body: SafeArea(
            child: Column(
              children: [
                _WindowHeader(
                  refreshing: _controller.refreshing,
                  onRefresh:
                      _controller.refreshing ? null : _controller.refresh,
                  onSettings: () => _openSettings(context),
                  onCompact: () => _setMode(AppDisplayMode.compact),
                  onMinimize: () => windowManager.minimize(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    children: [
                      _SummaryPanel(state: _controller.state),
                      const SizedBox(height: 12),
                      ...supportedOjs.map(
                        (meta) => _OjTile(
                          meta: meta,
                          config: _controller.state.config.accounts[meta.id],
                          result: _controller.state.latest[meta.id],
                          today: _controller.todayDeltaFor(meta.id),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DailyPanel(state: _controller.state),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    final updated = await showDialog<AppConfig>(
      context: context,
      builder: (_) => SettingsDialog(config: _controller.state.config),
    );
    if (updated != null) {
      await _controller.saveConfig(updated);
    }
  }

  void _setMode(AppDisplayMode mode) {
    if (_mode == mode) {
      return;
    }
    setState(() => _mode = mode);
    if (widget.enablePlatformIntegration) {
      unawaited(_syncWindowMode(mode));
    }
  }

  Future<void> _syncWindowMode(AppDisplayMode mode) async {
    try {
      switch (mode) {
        case AppDisplayMode.compact:
          await windowManager.setMinimumSize(_compactMinimumWindowSize);
          await windowManager.setSize(_compactWindowSize, animate: true);
          break;
        case AppDisplayMode.dashboard:
          await windowManager.setMinimumSize(_dashboardMinimumWindowSize);
          await windowManager.setSize(_dashboardWindowSize, animate: true);
          break;
      }
    } on MissingPluginException {
      // Widget tests do not load the desktop window plugin.
    }
  }
}

class _CompactWidget extends StatelessWidget {
  const _CompactWidget({
    required this.state,
    required this.refreshing,
    required this.onRefresh,
    required this.onOpenDashboard,
  });

  final OjState state;
  final bool refreshing;
  final VoidCallback? onRefresh;
  final VoidCallback onOpenDashboard;

  @override
  Widget build(BuildContext context) {
    final totalSolved = state.latest.values.fold<int>(
      0,
      (sum, item) => sum + (item.solvedCount ?? 0),
    );
    final today = state.todaySummary.totalDelta;

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xEAF9FBF8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x66FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CompactStatLine(
                        label: 'AC',
                        value: '$totalSolved',
                        isPrimary: true,
                      ),
                      const SizedBox(height: 6),
                      _CompactStatLine(
                        label: 'Today',
                        value: '+$today',
                        isPrimary: false,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CompactIconButton(
                      key: const ValueKey('compact-refresh-button'),
                      tooltip: 'Refresh',
                      onPressed: onRefresh,
                      child: refreshing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                    ),
                    const SizedBox(height: 4),
                    _CompactIconButton(
                      key: const ValueKey('open-dashboard-button'),
                      tooltip: 'Open dashboard',
                      onPressed: onOpenDashboard,
                      child: const Icon(Icons.open_in_full, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactStatLine extends StatelessWidget {
  const _CompactStatLine({
    required this.label,
    required this.value,
    required this.isPrimary,
  });

  final String label;
  final String value;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF42655C),
              fontSize: isPrimary ? 12 : 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF10231E),
              fontSize: isPrimary ? 30 : 18,
              fontWeight: isPrimary ? FontWeight.w900 : FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 30,
        child: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          color: const Color(0xFF365F55),
          disabledColor: const Color(0x66365F55),
          onPressed: onPressed,
          icon: child,
        ),
      ),
    );
  }
}

class _WindowHeader extends StatelessWidget {
  const _WindowHeader({
    required this.refreshing,
    required this.onRefresh,
    required this.onSettings,
    required this.onCompact,
    required this.onMinimize,
  });

  final bool refreshing;
  final VoidCallback? onRefresh;
  final VoidCallback onSettings;
  final VoidCallback onCompact;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          children: [
            const Icon(Icons.bubble_chart_outlined),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'OJ Float',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            IconButton(
              tooltip: '刷新',
              onPressed: onRefresh,
              icon: refreshing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: '设置',
              onPressed: onSettings,
              icon: const Icon(Icons.tune),
            ),
            IconButton(
              key: const ValueKey('compact-mode-button'),
              tooltip: 'Compact',
              onPressed: onCompact,
              icon: const Icon(Icons.close_fullscreen),
            ),
            IconButton(
              tooltip: '最小化',
              onPressed: onMinimize,
              icon: const Icon(Icons.remove),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.state});

  final OjState state;

  @override
  Widget build(BuildContext context) {
    final totalSolved = state.latest.values.fold<int>(
      0,
      (sum, item) => sum + (item.solvedCount ?? 0),
    );
    final today = state.todaySummary.totalDelta;
    final updatedAt = state.latest.values
        .where((item) => item.fetchedAt != null)
        .map((item) => item.fetchedAt!)
        .fold<DateTime?>(null, (latest, item) {
      if (latest == null || item.isAfter(latest)) {
        return item;
      }
      return latest;
    });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E4DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('总通过', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            '$totalSolved',
            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800),
          ),
          Row(
            children: [
              _Pill(label: '今日 +$today'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  updatedAt == null ? '尚未刷新' : '更新 ${formatTime(updatedAt)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OjTile extends StatelessWidget {
  const _OjTile({
    required this.meta,
    required this.config,
    required this.result,
    required this.today,
  });

  final OjMeta meta;
  final OjAccountConfig? config;
  final FetchResult? result;
  final int today;

  @override
  Widget build(BuildContext context) {
    final enabled = config?.enabled ?? false;
    final username = config?.username.trim() ?? '';
    final solvedText = switch (result?.status) {
      FetchStatus.success => '${result!.solvedCount}',
      FetchStatus.failure => '失败',
      _ => enabled && username.isNotEmpty ? '待刷新' : '未配置',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E4DE)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: enabled
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.grey.shade200,
            child: Text(meta.name.characters.first),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meta.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  username.isEmpty ? meta.hint : username,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                if (result?.error != null)
                  Text(
                    result!.error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(solvedText,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                '今日 +$today',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyPanel extends StatelessWidget {
  const _DailyPanel({required this.state});

  final OjState state;

  @override
  Widget build(BuildContext context) {
    final summary = state.todaySummary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E4DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '每日总结',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              _Pill(label: summary.date),
            ],
          ),
          const SizedBox(height: 10),
          if (summary.deltas.isEmpty)
            Text('暂无今日快照', style: TextStyle(color: Colors.grey.shade700))
          else
            ...supportedOjs.map((meta) {
              final delta = summary.deltas[meta.id];
              if (delta == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(meta.name)),
                    Text('+$delta'),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.config});

  final AppConfig config;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late int _intervalMinutes;
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, bool> _enabled;

  @override
  void initState() {
    super.initState();
    _intervalMinutes = widget.config.refreshIntervalMinutes;
    _controllers = {
      for (final meta in supportedOjs)
        meta.id: TextEditingController(
          text: widget.config.accounts[meta.id]?.username ?? '',
        ),
    };
    _enabled = {
      for (final meta in supportedOjs)
        meta.id: widget.config.accounts[meta.id]?.enabled ?? false,
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('自动刷新间隔')),
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      initialValue: '$_intervalMinutes',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(suffixText: '分钟'),
                      onChanged: (value) {
                        _intervalMinutes = int.tryParse(value) ?? 60;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...supportedOjs.map((meta) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _enabled[meta.id] ?? false,
                        onChanged: (value) {
                          setState(() => _enabled[meta.id] = value ?? false);
                        },
                      ),
                      SizedBox(width: 88, child: Text(meta.name)),
                      Expanded(
                        child: TextField(
                          controller: _controllers[meta.id],
                          decoration: InputDecoration(
                            hintText: meta.hint,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final accounts = {
              for (final meta in supportedOjs)
                meta.id: OjAccountConfig(
                  username: _controllers[meta.id]!.text.trim(),
                  enabled: _enabled[meta.id] ?? false,
                ),
            };
            Navigator.pop(
              context,
              AppConfig(
                refreshIntervalMinutes:
                    _intervalMinutes.clamp(15, 1440).toInt(),
                accounts: accounts,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class OjController extends ChangeNotifier {
  OjController({required this.storage, required this.service});

  final LocalStore storage;
  final RefreshService service;
  OjState state = OjState.initial();
  bool refreshing = false;
  Timer? _timer;

  Future<void> init() async {
    final config = await storage.loadConfig();
    final snapshots = await storage.loadSnapshots();
    state = state.copyWith(config: config, snapshots: snapshots);
    _recomputeSummaries();
    _schedule();
    notifyListeners();
    await refresh();
  }

  Future<void> saveConfig(AppConfig config) async {
    await storage.saveConfig(config);
    state = state.copyWith(config: config);
    _schedule();
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    if (refreshing) {
      return;
    }
    refreshing = true;
    notifyListeners();
    try {
      final results = await service.refresh(state.config);
      final snapshots = [
        ...state.snapshots,
        ...results.values.map(SolvedSnapshot.fromResult),
      ];
      await storage.saveSnapshots(snapshots);
      state = state.copyWith(latest: results, snapshots: snapshots);
      _recomputeSummaries();
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  int todayDeltaFor(String ojId) => state.todaySummary.deltas[ojId] ?? 0;

  void _recomputeSummaries() {
    final today = dateKey(DateTime.now());
    state = state.copyWith(
        todaySummary: DailySummary.fromSnapshots(today, state.snapshots));
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(minutes: state.config.refreshIntervalMinutes),
      (_) => unawaited(refresh()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    service.dispose();
    super.dispose();
  }
}

class RefreshService {
  RefreshService({required this.client, required this.providers});

  final http.Client client;
  final Map<String, OjProvider> providers;

  Future<Map<String, FetchResult>> refresh(AppConfig config) async {
    final entries = config.accounts.entries.where(
      (entry) => entry.value.enabled && entry.value.username.trim().isNotEmpty,
    );
    final futures = entries.map((entry) async {
      final provider = providers[entry.key]!;
      try {
        final profile = await provider
            .fetchProfile(client, entry.value.username.trim())
            .timeout(const Duration(seconds: 18));
        return MapEntry(
          entry.key,
          FetchResult.success(
            ojId: entry.key,
            username: entry.value.username.trim(),
            solvedCount: profile.solvedCount,
            rating: profile.rating,
            profileUrl: profile.profileUrl,
            fetchedAt: DateTime.now(),
          ),
        );
      } catch (error) {
        return MapEntry(
          entry.key,
          FetchResult.failure(
            ojId: entry.key,
            username: entry.value.username.trim(),
            error: normalizeError(error),
            fetchedAt: DateTime.now(),
          ),
        );
      }
    });
    return Map.fromEntries(await Future.wait(futures));
  }

  void dispose() => client.close();
}

abstract class OjProvider {
  Future<OjProfile> fetchProfile(http.Client client, String username);
}

class CodeforcesProvider implements OjProvider {
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    final uri = Uri.https('codeforces.com', '/api/user.status', {
      'handle': username,
      'from': '1',
      'count': '100000',
    });
    final data = await readJson(client, uri);
    if (data['status'] != 'OK') {
      throw FetchException(data['comment']?.toString() ?? 'Codeforces 返回异常');
    }
    final solved = <String>{};
    for (final item in data['result'] as List<dynamic>) {
      if (item is! Map || item['verdict'] != 'OK') {
        continue;
      }
      final problem = item['problem'];
      if (problem is Map) {
        final contestId = problem['contestId'];
        final index = problem['index'];
        final name = problem['name'];
        solved.add('$contestId/$index/$name');
      }
    }
    return OjProfile(
      solvedCount: solved.length,
      profileUrl: 'https://codeforces.com/profile/$username',
    );
  }
}

class LeetCodeProvider implements OjProvider {
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    final response = await client
        .post(
          Uri.https('leetcode.com', '/graphql'),
          headers: defaultHeaders(
            referer: 'https://leetcode.com/$username/',
            contentType: 'application/json',
          ),
          body: jsonEncode({
            'query': '''
query userSessionProgress(\$username: String!) {
  matchedUser(username: \$username) {
    submitStatsGlobal {
      acSubmissionNum {
        difficulty
        count
      }
    }
  }
}
''',
            'variables': {'username': username},
          }),
        )
        .timeout(const Duration(seconds: 18));
    ensureOk(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final matchedUser = data['data']?['matchedUser'];
    if (matchedUser == null) {
      throw FetchException('LeetCode 用户不存在或不可公开访问');
    }
    final list = matchedUser['submitStatsGlobal']?['acSubmissionNum'];
    if (list is! List) {
      throw FetchException('LeetCode 返回格式变化');
    }
    final all = list.cast<Map<String, dynamic>>().firstWhere(
          (item) => item['difficulty'] == 'All',
          orElse: () => {'count': 0},
        );
    return OjProfile(
      solvedCount: all['count'] as int? ?? 0,
      profileUrl: 'https://leetcode.com/$username/',
    );
  }
}

class AtCoderProvider implements OjProvider {
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    final data = await readJson(
      client,
      Uri.https('kenkoooo.com', '/atcoder/atcoder-api/v3/user/ac_rank', {
        'user': username,
      }),
    );
    final count = data['count'];
    if (count is! int) {
      throw FetchException('AtCoder 统计接口未返回通过数');
    }
    return OjProfile(
      solvedCount: count,
      profileUrl: 'https://atcoder.jp/users/$username',
    );
  }
}

class LuoguProvider implements OjProvider {
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    if (int.tryParse(username) == null) {
      throw FetchException('洛谷第一版请填写数字 UID');
    }
    final uri = Uri.https('www.luogu.com.cn', '/user/$username');
    final response = await client.get(uri, headers: defaultHeaders()).timeout(
          const Duration(seconds: 18),
        );
    ensureOk(response);
    final body = response.body;
    final patterns = [
      RegExp(r'"passedProblemCount"\s*:\s*(\d+)'),
      RegExp(r'"acceptedProblemCount"\s*:\s*(\d+)'),
      RegExp(r'通过题目\s*</[^>]+>\s*<[^>]+>\s*(\d+)'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        return OjProfile(
          solvedCount: int.parse(match.group(1)!),
          profileUrl: uri.toString(),
        );
      }
    }
    throw FetchException('洛谷页面未找到通过题数');
  }
}

class NowcoderProvider implements OjProvider {
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    if (int.tryParse(username) == null) {
      throw FetchException('牛客第一版请填写数字用户 ID');
    }
    final uri = Uri.https('www.nowcoder.com', '/users/$username');
    final response = await client.get(uri, headers: defaultHeaders()).timeout(
          const Duration(seconds: 18),
        );
    ensureOk(response);
    final body = response.body;
    final patterns = [
      RegExp(r'"acceptedCount"\s*:\s*(\d+)'),
      RegExp(r'"acCount"\s*:\s*(\d+)'),
      RegExp(r'通过题目[^0-9]{0,80}(\d+)'),
      RegExp(r'已通过[^0-9]{0,80}(\d+)'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        return OjProfile(
          solvedCount: int.parse(match.group(1)!),
          profileUrl: uri.toString(),
        );
      }
    }
    final document = html_parser.parse(body);
    final text = document.body?.text ?? '';
    final textMatch = RegExp(r'(?:通过题目|已通过)\s*(\d+)').firstMatch(text);
    if (textMatch != null) {
      return OjProfile(
        solvedCount: int.parse(textMatch.group(1)!),
        profileUrl: uri.toString(),
      );
    }
    throw FetchException('牛客页面未找到通过题数');
  }
}

class LocalStore {
  LocalStore({Directory? supportDirectory})
      : _supportDirectory = supportDirectory;

  static const _configKey = 'app_config_v1';
  static const _snapshotsFile = 'snapshots_v1.json';

  final Directory? _supportDirectory;

  Future<AppConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null) {
      return AppConfig.defaults();
    }
    try {
      final data = jsonDecode(raw);
      if (data is! Map) {
        debugPrint('Invalid app config JSON: expected an object.');
        return AppConfig.defaults();
      }
      return AppConfig.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      debugPrint('Failed to parse app config. Using defaults.');
      return AppConfig.defaults();
    }
  }

  Future<void> saveConfig(AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }

  Future<List<SolvedSnapshot>> loadSnapshots() async {
    final file = await _snapshotFile();
    if (!await file.exists()) {
      return [];
    }
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! List) {
        debugPrint('Invalid snapshots JSON: expected a list.');
        return [];
      }
      final snapshots = <SolvedSnapshot>[];
      for (final item in data) {
        try {
          if (item is! Map) {
            debugPrint('Skipping invalid snapshot: expected an object.');
            continue;
          }
          final snapshot = SolvedSnapshot.tryFromJson(
            Map<String, dynamic>.from(item),
          );
          if (snapshot == null) {
            debugPrint('Skipping invalid snapshot entry.');
            continue;
          }
          snapshots.add(snapshot);
        } catch (_) {
          debugPrint('Skipping invalid snapshot entry.');
          continue;
        }
      }
      return snapshots;
    } catch (_) {
      debugPrint('Failed to parse snapshots. Using an empty list.');
      return [];
    }
  }

  Future<void> saveSnapshots(List<SolvedSnapshot> snapshots) async {
    final file = await _snapshotFile();
    await file.parent.create(recursive: true);
    final kept = snapshots.length > 6000
        ? snapshots.sublist(snapshots.length - 6000)
        : snapshots;
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        kept.map((item) => item.toJson()).toList(),
      ),
    );
  }

  Future<File> _snapshotFile() async {
    final directory =
        _supportDirectory ?? await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_snapshotsFile');
  }
}

class OjMeta {
  const OjMeta({
    required this.id,
    required this.name,
    required this.hint,
    required this.profileBaseUrl,
  });

  final String id;
  final String name;
  final String hint;
  final String profileBaseUrl;
}

class AppConfig {
  const AppConfig({
    required this.refreshIntervalMinutes,
    required this.accounts,
  });

  factory AppConfig.defaults() {
    return AppConfig(
      refreshIntervalMinutes: 60,
      accounts: {
        for (final meta in supportedOjs)
          meta.id: const OjAccountConfig(username: '', enabled: false),
      },
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final rawAccounts = json['accounts'];
    return AppConfig(
      refreshIntervalMinutes: _parseRefreshInterval(
        json['refreshIntervalMinutes'],
      ),
      accounts: {
        for (final meta in supportedOjs)
          meta.id: _parseAccountConfig(
            rawAccounts is Map ? rawAccounts[meta.id] : null,
          ),
      },
    );
  }

  static int _parseRefreshInterval(Object? value) {
    if (value is! int || value < 15 || value > 1440) {
      return 60;
    }
    return value;
  }

  static OjAccountConfig _parseAccountConfig(Object? value) {
    if (value is! Map) {
      return const OjAccountConfig(username: '', enabled: false);
    }
    try {
      return OjAccountConfig.fromJson(Map<String, dynamic>.from(value));
    } catch (_) {
      debugPrint('Failed to parse OJ account config. Using defaults.');
      return const OjAccountConfig(username: '', enabled: false);
    }
  }

  final int refreshIntervalMinutes;
  final Map<String, OjAccountConfig> accounts;

  Map<String, dynamic> toJson() => {
        'refreshIntervalMinutes': refreshIntervalMinutes,
        'accounts': {
          for (final entry in accounts.entries) entry.key: entry.value.toJson(),
        },
      };
}

class OjAccountConfig {
  const OjAccountConfig({required this.username, required this.enabled});

  factory OjAccountConfig.fromJson(Map<String, dynamic> json) {
    return OjAccountConfig(
      username: json['username'] is String ? json['username'] as String : '',
      enabled: json['enabled'] is bool ? json['enabled'] as bool : false,
    );
  }

  final String username;
  final bool enabled;

  Map<String, dynamic> toJson() => {
        'username': username,
        'enabled': enabled,
      };
}

class OjProfile {
  const OjProfile({
    required this.solvedCount,
    required this.profileUrl,
    this.rating,
  });

  final int solvedCount;
  final int? rating;
  final String profileUrl;
}

enum FetchStatus { idle, success, failure }

class FetchResult {
  const FetchResult({
    required this.ojId,
    required this.username,
    required this.status,
    required this.fetchedAt,
    this.solvedCount,
    this.rating,
    this.profileUrl,
    this.error,
  });

  factory FetchResult.success({
    required String ojId,
    required String username,
    required int solvedCount,
    required DateTime fetchedAt,
    int? rating,
    String? profileUrl,
  }) {
    return FetchResult(
      ojId: ojId,
      username: username,
      status: FetchStatus.success,
      solvedCount: solvedCount,
      rating: rating,
      profileUrl: profileUrl,
      fetchedAt: fetchedAt,
    );
  }

  factory FetchResult.failure({
    required String ojId,
    required String username,
    required String error,
    required DateTime fetchedAt,
  }) {
    return FetchResult(
      ojId: ojId,
      username: username,
      status: FetchStatus.failure,
      error: error,
      fetchedAt: fetchedAt,
    );
  }

  final String ojId;
  final String username;
  final FetchStatus status;
  final int? solvedCount;
  final int? rating;
  final String? profileUrl;
  final String? error;
  final DateTime? fetchedAt;
}

class SolvedSnapshot {
  const SolvedSnapshot({
    required this.date,
    required this.fetchedAt,
    required this.ojId,
    required this.username,
    required this.status,
    this.solvedCount,
    this.error,
  });

  factory SolvedSnapshot.fromResult(FetchResult result) {
    final fetchedAt = result.fetchedAt ?? DateTime.now();
    return SolvedSnapshot(
      date: dateKey(fetchedAt),
      fetchedAt: fetchedAt,
      ojId: result.ojId,
      username: result.username,
      status: result.status,
      solvedCount: result.solvedCount,
      error: result.error,
    );
  }

  factory SolvedSnapshot.fromJson(Map<String, dynamic> json) {
    final snapshot = SolvedSnapshot.tryFromJson(json);
    if (snapshot == null) {
      throw const FormatException('Invalid solved snapshot JSON.');
    }
    return snapshot;
  }

  static SolvedSnapshot? tryFromJson(Map<String, dynamic> json) {
    final date = json['date'];
    final fetchedAt = json['fetchedAt'];
    final ojId = json['ojId'];
    final username = json['username'];
    final status = json['status'];
    final solvedCount = json['solvedCount'];
    final error = json['error'];

    if (date is! String || !_isValidDateKey(date)) {
      return null;
    }
    if (fetchedAt is! String) {
      return null;
    }
    final parsedFetchedAt = DateTime.tryParse(fetchedAt);
    if (parsedFetchedAt == null) {
      return null;
    }
    if (ojId is! String || ojId.isEmpty) {
      return null;
    }
    if (status is! String) {
      return null;
    }
    final parsedStatus = _parseFetchStatus(status);
    if (parsedStatus == null) {
      return null;
    }
    if (username != null && username is! String) {
      return null;
    }
    if (solvedCount != null && solvedCount is! int) {
      return null;
    }
    if (error != null && error is! String) {
      return null;
    }

    return SolvedSnapshot(
      date: date,
      fetchedAt: parsedFetchedAt,
      ojId: ojId,
      username: username as String? ?? '',
      status: parsedStatus,
      solvedCount: solvedCount as int?,
      error: error as String?,
    );
  }

  static FetchStatus? _parseFetchStatus(String value) {
    for (final status in FetchStatus.values) {
      if (status.name == value) {
        return status;
      }
    }
    return null;
  }

  static bool _isValidDateKey(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      return false;
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day;
  }

  final String date;
  final DateTime fetchedAt;
  final String ojId;
  final String username;
  final FetchStatus status;
  final int? solvedCount;
  final String? error;

  Map<String, dynamic> toJson() => {
        'date': date,
        'fetchedAt': fetchedAt.toIso8601String(),
        'ojId': ojId,
        'username': username,
        'status': status.name,
        'solvedCount': solvedCount,
        'error': error,
      };
}

class DailySummary {
  const DailySummary({
    required this.date,
    required this.deltas,
    required this.totalDelta,
  });

  factory DailySummary.empty(String date) {
    return DailySummary(date: date, deltas: const {}, totalDelta: 0);
  }

  factory DailySummary.fromSnapshots(
      String date, List<SolvedSnapshot> snapshots) {
    final byOj = <String, List<SolvedSnapshot>>{};
    for (final snapshot in snapshots.where(
      (item) => item.date == date && item.status == FetchStatus.success,
    )) {
      byOj.putIfAbsent(snapshot.ojId, () => []).add(snapshot);
    }
    final deltas = <String, int>{};
    for (final entry in byOj.entries) {
      final ordered = [...entry.value]
        ..sort((a, b) => a.fetchedAt.compareTo(b.fetchedAt));
      final first = ordered.first.solvedCount ?? 0;
      final last = ordered.last.solvedCount ?? 0;
      deltas[entry.key] = (last - first).clamp(0, 1 << 31).toInt();
    }
    return DailySummary(
      date: date,
      deltas: deltas,
      totalDelta: deltas.values.fold(0, (sum, item) => sum + item),
    );
  }

  final String date;
  final Map<String, int> deltas;
  final int totalDelta;
}

class OjState {
  const OjState({
    required this.config,
    required this.latest,
    required this.snapshots,
    required this.todaySummary,
  });

  factory OjState.initial() {
    final today = dateKey(DateTime.now());
    return OjState(
      config: AppConfig.defaults(),
      latest: const {},
      snapshots: const [],
      todaySummary: DailySummary.empty(today),
    );
  }

  final AppConfig config;
  final Map<String, FetchResult> latest;
  final List<SolvedSnapshot> snapshots;
  final DailySummary todaySummary;

  OjState copyWith({
    AppConfig? config,
    Map<String, FetchResult>? latest,
    List<SolvedSnapshot>? snapshots,
    DailySummary? todaySummary,
  }) {
    return OjState(
      config: config ?? this.config,
      latest: latest ?? this.latest,
      snapshots: snapshots ?? this.snapshots,
      todaySummary: todaySummary ?? this.todaySummary,
    );
  }
}

class FetchException implements Exception {
  FetchException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<Map<String, dynamic>> readJson(http.Client client, Uri uri) async {
  final response = await client.get(uri, headers: defaultHeaders()).timeout(
        const Duration(seconds: 18),
      );
  ensureOk(response);
  return jsonDecode(response.body) as Map<String, dynamic>;
}

Map<String, String> defaultHeaders({String? referer, String? contentType}) {
  return {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/126.0 Safari/537.36',
    'Accept': 'application/json,text/html,application/xhtml+xml',
    if (referer != null) 'Referer': referer,
    if (contentType != null) 'Content-Type': contentType,
  };
}

void ensureOk(http.Response response) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw FetchException('HTTP ${response.statusCode}');
  }
}

String normalizeError(Object error) {
  if (error is FetchException) {
    return error.message;
  }
  if (error is TimeoutException) {
    return '请求超时';
  }
  if (error is SocketException) {
    return '网络不可用';
  }
  return error.toString();
}

String dateKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String formatTime(DateTime date) {
  final local = date.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
