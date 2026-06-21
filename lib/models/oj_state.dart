import '../core/time.dart';
import '../services/daily_summary_service.dart';
import 'app_config.dart';
import 'contest_record.dart';
import 'fetch_result.dart';
import 'problem_record.dart';
import 'refresh_log_entry.dart';
import 'solved_snapshot.dart';
import 'teammate.dart';

class OjState {
  const OjState({
    required this.config,
    required this.latest,
    required this.snapshots,
    required this.problems,
    required this.contests,
    required this.teammates,
    required this.refreshLogs,
    required this.todaySummary,
  });

  factory OjState.initial() {
    final today = dateKey(DateTime.now());
    return OjState(
      config: AppConfig.defaults(),
      latest: const {},
      snapshots: const [],
      problems: const [],
      contests: const [],
      teammates: const TeammateStoreData(),
      refreshLogs: const [],
      todaySummary: DailySummary.empty(today),
    );
  }

  final AppConfig config;
  final Map<String, List<FetchResult>> latest;
  final List<SolvedSnapshot> snapshots;
  final List<ProblemRecord> problems;
  final List<ContestRecord> contests;
  final TeammateStoreData teammates;
  final List<RefreshLogEntry> refreshLogs;
  final DailySummary todaySummary;

  OjState copyWith({
    AppConfig? config,
    Map<String, List<FetchResult>>? latest,
    List<SolvedSnapshot>? snapshots,
    List<ProblemRecord>? problems,
    List<ContestRecord>? contests,
    TeammateStoreData? teammates,
    List<RefreshLogEntry>? refreshLogs,
    DailySummary? todaySummary,
  }) {
    return OjState(
      config: config ?? this.config,
      latest: latest ?? this.latest,
      snapshots: snapshots ?? this.snapshots,
      problems: problems ?? this.problems,
      contests: contests ?? this.contests,
      teammates: teammates ?? this.teammates,
      refreshLogs: refreshLogs ?? this.refreshLogs,
      todaySummary: todaySummary ?? this.todaySummary,
    );
  }
}
