import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  test('empty state asks the user to connect an account', () {
    final viewModel = HomeSummaryViewModel.fromState(OjState.initial());

    expect(viewModel.totalSolved, 0);
    expect(viewModel.enabledAccountCount, 0);
    expect(viewModel.emptyMessage, contains('启用至少一个 OJ 账号'));
    expect(viewModel.hasAttentionItems, isTrue);
    expect(viewModel.statusCards.map((card) => card.title), contains('账号状态'));
  });

  test('success refresh summarizes totals and today delta', () {
    final state = OjState.initial().copyWith(
      config: _configWithCodeforcesAccount(),
      latest: {
        'codeforces': [
          FetchResult.success(
            ojId: 'codeforces',
            username: 'alice',
            solvedCount: 42,
            fetchedAt: DateTime.parse('2026-07-04T08:00:00'),
          ),
        ],
      },
      snapshots: [
        _snapshot('2026-07-04T08:00:00', 40),
        _snapshot('2026-07-04T20:00:00', 42),
      ],
      todaySummary: DailySummary.fromSnapshots(
        '2026-07-04',
        [
          _snapshot('2026-07-04T08:00:00', 40),
          _snapshot('2026-07-04T20:00:00', 42),
        ],
      ),
    );

    final viewModel = HomeSummaryViewModel.fromState(state);

    expect(viewModel.totalSolved, 42);
    expect(viewModel.todayDelta, 2);
    expect(viewModel.enabledAccountCount, 1);
    expect(viewModel.emptyMessage, isNull);
    expect(viewModel.statusCards.first.description, contains('新的通过记录'));
  });

  test('failure refresh is surfaced as an attention item', () {
    final state = OjState.initial().copyWith(
      config: _configWithCodeforcesAccount(),
      latest: {
        'codeforces': [
          FetchResult.failure(
            ojId: 'codeforces',
            username: 'alice',
            error: 'timeout',
            fetchedAt: DateTime.parse('2026-07-04T08:00:00'),
          ),
        ],
      },
    );

    final viewModel = HomeSummaryViewModel.fromState(state);
    final refreshCard =
        viewModel.statusCards.singleWhere((card) => card.title == '刷新状态');

    expect(viewModel.hasAttentionItems, isTrue);
    expect(refreshCard.description, contains('1 个失败'));
    expect(refreshCard.tone, HomeCardTone.warning);
  });

  test('sync disabled and failure states use human readable labels', () {
    final disabled = HomeSummaryViewModel.fromState(OjState.initial());
    expect(disabled.syncLabel, '仅保存在本地');

    final enabledState = OjState.initial().copyWith(
      config: AppConfig.defaults().copyWith(
        sync: const SyncConfig(enabled: true),
      ),
    );
    final failed = HomeSummaryViewModel.fromState(
      enabledState,
      lastSyncResult: const SyncResult(
        status: SyncStatus.failure,
        endpointLabel: 'example.com',
        message: 'HTTP 500',
      ),
    );

    expect(failed.syncLabel, contains('上次同步失败'));
    expect(
      failed.statusCards.singleWhere((card) => card.title == '同步').tone,
      HomeCardTone.warning,
    );
  });
}

AppConfig _configWithCodeforcesAccount() {
  return AppConfig.defaults().copyWith(
    accounts: {
      for (final entry in AppConfig.defaults().accounts.entries)
        entry.key: entry.key == 'codeforces'
            ? const OjAccountConfig(usernames: ['alice'], enabled: true)
            : entry.value,
    },
  );
}

SolvedSnapshot _snapshot(String fetchedAt, int solvedCount) {
  final parsed = DateTime.parse(fetchedAt);
  return SolvedSnapshot(
    date:
        '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}',
    ojId: 'codeforces',
    username: 'alice',
    solvedCount: solvedCount,
    fetchedAt: parsed,
    status: FetchStatus.success,
  );
}
