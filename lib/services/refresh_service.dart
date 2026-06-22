import 'dart:async';

import 'package:http/http.dart' as http;

import '../core/solved_totals.dart';
import '../models/app_config.dart';
import '../models/fetch_result.dart';
import '../providers/oj_provider.dart';

class RefreshService {
  RefreshService({required this.client, required this.providers});

  final http.Client client;
  final Map<String, OjProvider> providers;

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
      final profile = await provider
          .fetchProfile(client, username)
          .timeout(const Duration(seconds: 18));
      return MapEntry(
        ojId,
        FetchResult.success(
          ojId: ojId,
          username: username,
          solvedCount: profile.solvedCount,
          rating: profile.rating,
          profileUrl: profile.profileUrl,
          source: profile.source,
          fetchedAt: DateTime.now(),
        ),
      );
    } catch (error) {
      return MapEntry(
        ojId,
        FetchResult.failure(
          ojId: ojId,
          username: username,
          error: normalizeError(error),
          fetchedAt: DateTime.now(),
        ),
      );
    }
  }

  void dispose() => client.close();
}
