import 'package:http/http.dart' as http;

import '../models/fetch_result.dart';

abstract class OjProvider {
  Future<OjProfile> fetchProfile(http.Client client, String username);
}

class OjDailyActivity {
  const OjDailyActivity({
    required this.acceptedCount,
    this.source = 'unknown',
  });

  final int acceptedCount;
  final String source;
}

abstract class OjDailyActivityProvider {
  Future<OjDailyActivity> fetchDailyActivity(
    http.Client client,
    String username, {
    required DateTime start,
    required DateTime end,
  });
}
