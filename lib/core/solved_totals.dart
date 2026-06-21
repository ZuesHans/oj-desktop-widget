part of '../main.dart';

int totalSolvedFromLatest(Map<String, List<FetchResult>> latest) {
  return latest.values.fold<int>(
    0,
    (sum, results) => sum + totalSolvedFromResults(results),
  );
}

int totalSolvedFromResults(Iterable<FetchResult> results) {
  return results
      .where((result) => result.status == FetchStatus.success)
      .fold<int>(0, (sum, result) => sum + (result.solvedCount ?? 0));
}

String normalizeError(Object error) {
  if (error is FetchException) {
    return error.message;
  }
  if (error is TimeoutException) {
    return '请求超时';
  }
  if (error is SocketException) {
    return '网络不可用';
  }
  return error.toString();
}
