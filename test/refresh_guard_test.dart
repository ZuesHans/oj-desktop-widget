import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:oj_float/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('blocks zero and decreasing solved counts while preserving snapshots',
      () async {
    final directory = await Directory.systemTemp.createTemp('refresh_guard_');
    final store = LocalStore(supportDirectory: directory);
    final controller = _controller(
      store,
      _SequenceProvider([
        const OjProfile(
          solvedCount: 670,
          profileUrl: 'https://example.test/a',
          source: 'primary',
        ),
        const OjProfile(
          solvedCount: 0,
          profileUrl: 'https://example.test/a',
          source: 'primary',
        ),
        const OjProfile(
          solvedCount: 660,
          profileUrl: 'https://example.test/a',
          source: 'primary',
        ),
        const OjProfile(
          solvedCount: 671,
          profileUrl: 'https://example.test/a',
          source: 'codeforces_user_status',
        ),
      ]),
    );

    try {
      await store.saveConfig(_config('alice'));
      await controller.init();
      expect(controller.state.snapshots.map((item) => item.solvedCount), [670]);

      await controller.refresh();
      expect(controller.state.latest['codeforces']!.single.status,
          FetchStatus.failure);
      expect(controller.state.snapshots.map((item) => item.solvedCount), [670]);
      expect(
          controller.state.refreshLogs.first.status, RefreshLogStatus.blocked);

      await controller.refresh();
      expect(controller.state.latest['codeforces']!.single.status,
          FetchStatus.failure);
      expect(controller.state.snapshots.map((item) => item.solvedCount), [670]);
      expect(
          controller.state.refreshLogs.first.status, RefreshLogStatus.blocked);

      await controller.refresh();
      expect(
        controller.state.snapshots.map((item) => item.solvedCount),
        [670, 671],
      );
      expect(controller.state.refreshLogs.first.status,
          RefreshLogStatus.fallbackSuccess);
    } finally {
      controller.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('allows zero for an account without history', () async {
    final directory = await Directory.systemTemp.createTemp('refresh_guard_');
    final store = LocalStore(supportDirectory: directory);
    final controller = _controller(
      store,
      _SequenceProvider([
        const OjProfile(
          solvedCount: 0,
          profileUrl: 'https://example.test/new',
          source: 'primary',
        ),
      ]),
    );

    try {
      await store.saveConfig(_config('newbie'));
      await controller.init();

      expect(controller.state.latest['codeforces']!.single.status,
          FetchStatus.success);
      expect(controller.state.snapshots.single.solvedCount, 0);
      expect(
          controller.state.refreshLogs.single.status, RefreshLogStatus.success);
    } finally {
      controller.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('account failure does not block another account success', () async {
    final directory = await Directory.systemTemp.createTemp('refresh_guard_');
    final store = LocalStore(supportDirectory: directory);
    final controller = OjController(
      storage: store,
      startupService: NoopStartupService(),
      service: RefreshService(
        client: http.Client(),
        providers: {
          'codeforces': _MapProvider({
            'a': const OjProfile(
              solvedCount: 10,
              profileUrl: 'https://example.test/a',
              source: 'primary',
            ),
            'b': FetchException('broken'),
          }),
        },
      ),
    );

    try {
      await store.saveConfig(_config('a', extraUsernames: const ['b']));
      await controller.init();

      final results = {
        for (final result in controller.state.latest['codeforces']!)
          result.username: result,
      };
      expect(results['a']!.status, FetchStatus.success);
      expect(results['b']!.status, FetchStatus.failure);
      expect(controller.state.snapshots, hasLength(1));
      expect(controller.state.refreshLogs, hasLength(2));
    } finally {
      controller.dispose();
      await directory.delete(recursive: true);
    }
  });
}

OjController _controller(LocalStore store, OjProvider provider) {
  return OjController(
    storage: store,
    startupService: NoopStartupService(),
    service: RefreshService(
      client: http.Client(),
      providers: {'codeforces': provider},
    ),
  );
}

AppConfig _config(String username, {List<String> extraUsernames = const []}) {
  return AppConfig(
    refreshIntervalMinutes: 60,
    accounts: {
      for (final meta in supportedOjs)
        meta.id: meta.id == 'codeforces'
            ? OjAccountConfig(
                usernames: [username, ...extraUsernames],
                enabled: true,
              )
            : const OjAccountConfig(usernames: [], enabled: false),
    },
  );
}

class _SequenceProvider implements OjProvider {
  _SequenceProvider(this.profiles);

  final List<OjProfile> profiles;
  int index = 0;

  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    return profiles[index++];
  }
}

class _MapProvider implements OjProvider {
  const _MapProvider(this.values);

  final Map<String, Object> values;

  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    final value = values[username];
    if (value is OjProfile) {
      return value;
    }
    if (value is Object) {
      throw value;
    }
    throw FetchException('missing');
  }
}
