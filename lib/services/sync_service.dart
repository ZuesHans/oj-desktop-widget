import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/solved_totals.dart';
import '../models/app_config.dart';
import '../models/fetch_result.dart';
import '../models/problem_record.dart';
import '../models/solved_snapshot.dart';
import 'daily_summary_service.dart';

class SyncResult {
  const SyncResult({
    required this.status,
    required this.endpointLabel,
    this.httpStatus,
    this.message = '',
  });

  final SyncStatus status;
  final String endpointLabel;
  final int? httpStatus;
  final String message;

  bool get ok => status == SyncStatus.success || status == SyncStatus.skipped;
}

enum SyncStatus { success, skipped, failure }

class SyncService {
  SyncService({required this.client});

  final http.Client client;

  Future<SyncResult> sync({
    required SyncConfig config,
    required String token,
    required List<SolvedSnapshot> snapshots,
    required List<ProblemRecord> problems,
    DateTime? now,
  }) async {
    if (!config.enabled) {
      return const SyncResult(
        status: SyncStatus.skipped,
        endpointLabel: '',
        message: 'Sync is disabled.',
      );
    }
    final endpoint = Uri.tryParse(config.endpointUrl.trim());
    if (endpoint == null || !_isAllowedSyncEndpoint(endpoint)) {
      return const SyncResult(
        status: SyncStatus.failure,
        endpointLabel: '',
        message: 'Sync endpoint must use HTTPS, except localhost HTTP for dev.',
      );
    }
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return SyncResult(
        status: SyncStatus.failure,
        endpointLabel: safeEndpointLabel(endpoint),
        message: 'Sync token is empty.',
      );
    }

    final body = buildOjSyncPayloadJson(
      config: config,
      snapshots: snapshots,
      problems: problems,
      now: now ?? DateTime.now(),
    );

    try {
      final response = await client
          .post(
            endpoint,
            headers: {
              'authorization': 'Bearer $normalizedToken',
              'content-type': 'application/json',
              'user-agent': 'OJ-Float-Sync/1',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 18));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return SyncResult(
          status: SyncStatus.success,
          endpointLabel: safeEndpointLabel(endpoint),
          httpStatus: response.statusCode,
        );
      }
      return SyncResult(
        status: SyncStatus.failure,
        endpointLabel: safeEndpointLabel(endpoint),
        httpStatus: response.statusCode,
        message: 'Sync endpoint returned HTTP ${response.statusCode}.',
      );
    } catch (error) {
      return SyncResult(
        status: SyncStatus.failure,
        endpointLabel: safeEndpointLabel(endpoint),
        message: normalizeError(error),
      );
    }
  }

  void dispose() => client.close();
}

String buildOjSyncPayloadJson({
  required SyncConfig config,
  required List<SolvedSnapshot> snapshots,
  required List<ProblemRecord> problems,
  required DateTime now,
}) {
  return jsonEncode(
    buildOjSyncPayload(
      config: config,
      snapshots: snapshots,
      problems: problems,
      now: now,
    ),
  );
}

Map<String, Object?> buildOjSyncPayload({
  required SyncConfig config,
  required List<SolvedSnapshot> snapshots,
  required List<ProblemRecord> problems,
  required DateTime now,
}) {
  return {
    'schemaVersion': 1,
    'app': 'oj_float',
    'syncedAt': now.toIso8601String(),
    'dailyStats':
        config.syncDailyStats ? buildOjSyncDailyStats(snapshots) : const [],
    'problems': config.syncProblems
        ? buildOjSyncProblems(problems, config: config)
        : const [],
  };
}

List<Map<String, Object?>> buildOjSyncDailyStats(
  List<SolvedSnapshot> snapshots,
) {
  final dates = {
    for (final snapshot in snapshots)
      if (snapshot.status == FetchStatus.success) snapshot.date,
  }.toList()
    ..sort();
  return [
    for (final date in dates)
      {
        'date': date,
        'totalDelta': DailySummary.fromSnapshots(date, snapshots).totalDelta,
      },
  ];
}

List<Map<String, Object?>> buildOjSyncProblems(
  List<ProblemRecord> problems, {
  required SyncConfig config,
}) {
  final sorted = [...problems]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return [
    for (final problem in sorted)
      {
        'id': problem.id,
        'title': problem.title,
        'url': problem.url,
        'platform': problemPlatformValue(problem.platform),
        'status': problem.status.name,
        'tags': problem.tags,
        'date': problem.date,
        'updated_at': problem.updatedAt.toIso8601String(),
        if (config.includeProblemNote) 'note': problem.note,
        if (config.includeProblemAnalysis) 'analysis': problem.analysis,
      },
  ];
}

String maskSyncToken(String token) {
  final value = token.trim();
  if (value.isEmpty) {
    return '';
  }
  if (value.length <= 8) {
    return '****';
  }
  return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
}

String safeEndpointLabel(Uri endpoint) {
  final port = endpoint.hasPort ? ':${endpoint.port}' : '';
  return '${endpoint.scheme}://${endpoint.host}$port';
}

bool _isAllowedSyncEndpoint(Uri endpoint) {
  if (!endpoint.hasScheme || endpoint.host.trim().isEmpty) {
    return false;
  }
  if (endpoint.scheme == 'https') {
    return true;
  }
  if (endpoint.scheme != 'http') {
    return false;
  }
  final host = endpoint.host.toLowerCase();
  return host == 'localhost' || host == '127.0.0.1' || host == '::1';
}
