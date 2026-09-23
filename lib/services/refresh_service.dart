import 'dart:async';

import 'package:http/http.dart' as http;

import '../core/solved_totals.dart';
import '../core/time.dart';
import '../models/app_config.dart';
import '../models/fetch_result.dart';
import '../providers/oj_provider.dart';

class RefreshService {
  RefreshService({
    required this.client,
    required this.providers,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final http.Client client;
  final Map<String, OjProvider> providers;
  final DateTime Function() now;

  Future<Map<String, List<FetchResult>>> refresh(AppConfig config) async {
    final futures = <Future<MapEntry<String, FetchResult>>>[];
    for (final entry in config.accounts.entries) {
      if (!entry.value.enabled) {
        continue;
      }
      for (final username in entry.value.usernames) {
        futures.add(_refreshAccount(entry.key, username));
      }
    }
    final results = <String, List<FetchResult>>{};
    for (final entry in await Future.wait(futures)) {
      results.putIfAbsent(entry.key, () => []).add(entry.value);
    }
    return results;
  }

  Future<MapEntry<String, FetchResult>> _refreshAccount(
    String ojId,
    String username,
  ) async {
    final provider = providers[ojId]!;
    try {
      final fetchedAt = now();
      final profile = await provider
          .fetchProfile(client, username)
          .timeout(const Duration(seconds: 18));
      OjDailyActivity? activity;
      final activityProvider = provider is OjDailyActivityProvider
          ? provider as OjDailyActivityProvider
          : null;
      if (activityProvider != null) {
        final start = trainingDayStartFor(fetchedAt);
        try {
          activity = await activityProvider
              .fetchDailyActivity(
                client,
                username,
                start: start,
                end: start.add(const Duration(days: 1)),
              )
              .timeout(const Duration(seconds: 18));
        } catch (_) {
          // Profile totals remain useful when the daily submissions endpoint
          // is temporarily unavailable.
        }
      }
      return MapEntry(
        ojId,
        FetchResult.success(
          ojId: ojId,
          username: username,
          solvedCount: profile.solvedCount,
          rating: profile.rating,
          profileUrl: profile.profileUrl,
          source: profile.source,
          fetchedAt: fetchedAt,
          dailyAcceptedCount: activity?.acceptedCount,
          dailyActivityAccuracy: activity == null
              ? DailyActivityAccuracy.unknown
              : DailyActivityAccuracy.exact,
        ),
      );
    } catch (error) {
      return MapEntry(
        ojId,
        FetchResult.failure(
          ojId: ojId,
          username: username,
          error: normalizeError(error),
          fetchedAt: now(),
        ),
      );
    }
  }

  void dispose() => client.close();
}
