import 'package:flutter/material.dart';

import '../../core/solved_totals.dart';
import '../../models/app_config.dart';
import '../../models/fetch_result.dart';
import '../../models/oj_meta.dart';
import '../../models/solved_snapshot.dart';
import '../../services/daily_summary_service.dart';
import '../app_theme.dart';

class OjTile extends StatelessWidget {
  const OjTile({
    super.key,
    required this.meta,
    required this.config,
    required this.results,
    required this.today,
    required this.accountActivity,
    this.snapshots = const [],
    this.refreshIntervalMinutes = 60,
  });

  final OjMeta meta;
  final OjAccountConfig? config;
  final List<FetchResult> results;
  final int today;
  final Map<String, DailyActivityValue> accountActivity;
  final List<SolvedSnapshot> snapshots;
  final int refreshIntervalMinutes;

  @override
  Widget build(BuildContext context) {
    final enabled = config?.enabled ?? false;
    final usernames = config?.usernames ?? const <String>[];
    final hasDisplayCount = results.any(hasDisplaySolvedCount);
    final displayedSolved = totalSolvedFromResults(results);
    final solvedText = hasDisplayCount
        ? '$displayedSolved'
        : results.any((result) => result.status == FetchStatus.failure)
            ? '失败'
            : enabled && usernames.isNotEmpty
                ? '等待刷新'
                : '未设置';
    final shownUsernames = {
      for (final result in results) result.username,
    };
    final pendingUsernames =
        usernames.where((username) => !shownUsernames.contains(username));
    final platformAccuracy = accountActivity.values.any(
      (value) => value.accuracy == DailyActivityAccuracy.unknown,
    )
        ? DailyActivityAccuracy.unknown
        : accountActivity.values.any(
            (value) => value.accuracy == DailyActivityAccuracy.estimated,
          )
            ? DailyActivityAccuracy.estimated
            : DailyActivityAccuracy.exact;
    final todayText = switch (platformAccuracy) {
      DailyActivityAccuracy.exact => '今日 +$today',
      DailyActivityAccuracy.estimated => '今日约 +$today',
      DailyActivityAccuracy.unknown => '今日未知',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(appRadiusCard),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: enabled
                ? Theme.of(context).colorScheme.primaryContainer
                : cardMutedColor,
            child: Text(meta.name.characters.first),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meta.name,
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontWeight: FontWeight.w500,
                    )),
                Text(
                  usernames.isEmpty ? meta.hint : usernames.join(', '),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textSecondaryColor, fontSize: 12),
                ),
                const SizedBox(height: 6),
                ...results.map(
                  (result) => _AccountResultLine(
                    result: result,
                    activity: accountActivity[result.username],
                    lastSuccess: _lastSuccess(result),
                    staleAfter: Duration(minutes: refreshIntervalMinutes * 2),
                  ),
                ),
                ...pendingUsernames.map(
                  (username) => _PendingAccountLine(username: username),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(solvedText,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w600,
                  )),
              Text(
                todayText,
                style: TextStyle(color: textSecondaryColor, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  DateTime? _lastSuccess(FetchResult result) {
    DateTime? latest =
        result.status == FetchStatus.success ? result.fetchedAt : null;
    for (final snapshot in snapshots) {
      if (snapshot.ojId == meta.id &&
          snapshot.username == result.username &&
          snapshot.status == FetchStatus.success &&
          (latest == null || snapshot.fetchedAt.isAfter(latest))) {
        latest = snapshot.fetchedAt;
      }
    }
    return latest;
  }
}

class _AccountResultLine extends StatelessWidget {
  const _AccountResultLine(
      {required this.result,
      required this.activity,
      required this.lastSuccess,
      required this.staleAfter});

  final FetchResult result;
  final DailyActivityValue? activity;
  final DateTime? lastSuccess;
  final Duration staleAfter;

  @override
  Widget build(BuildContext context) {
    final retained = retainedSolvedCountForResult(result);
    final todayText = switch (activity?.accuracy) {
      DailyActivityAccuracy.exact => '+${activity?.count ?? 0}',
      DailyActivityAccuracy.estimated => '约 +${activity?.count ?? 0}',
      DailyActivityAccuracy.unknown || null => '今日未知',
    };
    final statusText = switch (result.status) {
      FetchStatus.success => '${result.solvedCount ?? 0} ($todayText)',
      FetchStatus.failure => retained == null ? '失败' : '$retained (保留)',
      FetchStatus.idle => '等待刷新',
    };
    final color =
        result.status == FetchStatus.failure ? dangerColor : textSecondaryColor;
    final stale = lastSuccess != null &&
        (result.status == FetchStatus.failure ||
            DateTime.now().difference(lastSuccess!) > staleAfter);

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textSecondaryColor, fontSize: 12),
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (result.error != null)
            Tooltip(
                message: result.error!,
                child: Text(
                  result.error!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: dangerColor, fontSize: 12),
                )),
          Text(
              lastSuccess == null
                  ? '尚无成功记录'
                  : '上次成功 ${_timestamp(lastSuccess!)}${stale ? ' · 数据待更新' : ''}',
              style: Theme.of(context).textTheme.bodySmall),
          if (result.fetchedAt != null && result.status == FetchStatus.failure)
            Text('本次失败 ${_timestamp(result.fetchedAt!)}',
                style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

String _timestamp(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

class _PendingAccountLine extends StatelessWidget {
  const _PendingAccountLine({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textSecondaryColor, fontSize: 12),
            ),
          ),
          Text(
            '等待刷新',
            style: TextStyle(color: textSecondaryColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
