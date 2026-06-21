import 'package:flutter/material.dart';

import '../../core/solved_totals.dart';
import '../../models/app_config.dart';
import '../../models/fetch_result.dart';
import '../../models/oj_meta.dart';
import '../app_theme.dart';

class OjTile extends StatelessWidget {
  const OjTile({
    super.key,
    required this.meta,
    required this.config,
    required this.results,
    required this.today,
    required this.accountToday,
  });

  final OjMeta meta;
  final OjAccountConfig? config;
  final List<FetchResult> results;
  final int today;
  final Map<String, int> accountToday;

  @override
  Widget build(BuildContext context) {
    final enabled = config?.enabled ?? false;
    final usernames = config?.usernames ?? const <String>[];
    final hasDisplayCount = results.any(hasDisplaySolvedCount);
    final displayedSolved = totalSolvedFromResults(results);
    final solvedText = hasDisplayCount
        ? '$displayedSolved'
        : results.any((result) => result.status == FetchStatus.failure)
            ? 'Failed'
            : enabled && usernames.isNotEmpty
                ? 'Pending'
                : 'Not set';
    final shownUsernames = {
      for (final result in results) result.username,
    };
    final pendingUsernames =
        usernames.where((username) => !shownUsernames.contains(username));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
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
                    style: const TextStyle(
                      color: textPrimaryColor,
                      fontWeight: FontWeight.w700,
                    )),
                Text(
                  usernames.isEmpty ? meta.hint : usernames.join(', '),
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: textSecondaryColor, fontSize: 12),
                ),
                const SizedBox(height: 6),
                ...results.map(
                  (result) => _AccountResultLine(
                    result: result,
                    today: accountToday[result.username] ?? 0,
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
                  style: const TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  )),
              Text(
                '今日 +$today',
                style: const TextStyle(color: textSecondaryColor, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountResultLine extends StatelessWidget {
  const _AccountResultLine({required this.result, required this.today});

  final FetchResult result;
  final int today;

  @override
  Widget build(BuildContext context) {
    final retained = retainedSolvedCountForResult(result);
    final statusText = switch (result.status) {
      FetchStatus.success => '${result.solvedCount ?? 0} (+$today)',
      FetchStatus.failure => retained == null ? 'Failed' : '$retained (保留)',
      FetchStatus.idle => 'Pending',
    };
    final color =
        result.status == FetchStatus.failure ? dangerColor : textSecondaryColor;

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
                  style:
                      const TextStyle(color: textSecondaryColor, fontSize: 12),
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (result.error != null)
            Text(
              result.error!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: dangerColor, fontSize: 12),
            ),
        ],
      ),
    );
  }
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
              style: const TextStyle(color: textSecondaryColor, fontSize: 12),
            ),
          ),
          const Text(
            'Pending',
            style: TextStyle(color: textSecondaryColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
