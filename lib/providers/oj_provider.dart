import 'package:http/http.dart' as http;

import '../models/fetch_result.dart';

abstract class OjProvider {
  Future<OjProfile> fetchProfile(http.Client client, String username);
}
