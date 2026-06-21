import '../core/time.dart';
import '../services/daily_summary_service.dart';
import 'app_config.dart';
import 'fetch_result.dart';
import 'problem_record.dart';
import 'solved_snapshot.dart';

class OjState {
  const OjState({
    required this.config,
    required this.latest,
    required this.snapshots,
    required this.problems,
    required this.todaySummary,
  });

  factory OjState.initial() {
    final today = dateKey(DateTime.now());
    return OjState(
      config: AppConfig.defaults(),
      latest: const {},
      snapshots: const [],
      problems: const [],
      todaySummary: DailySummary.empty(today),
    );
  }

  final AppConfig config;
  final Map<String, List<FetchResult>> latest;
  final List<SolvedSnapshot> snapshots;
  final List<ProblemRecord> problems;
  final DailySummary todaySummary;

  OjState copyWith({
    AppConfig? config,
    Map<String, List<FetchResult>>? latest,
    List<SolvedSnapshot>? snapshots,
    List<ProblemRecord>? problems,
    DailySummary? todaySummary,
  }) {
    return OjState(
      config: config ?? this.config,
      latest: latest ?? this.latest,
      snapshots: snapshots ?? this.snapshots,
      problems: problems ?? this.problems,
      todaySummary: todaySummary ?? this.todaySummary,
    );
  }
}
