import 'dart:async';
import 'dart:io';

import '../models/fetch_result.dart';
import 'errors.dart';

int totalSolvedFromLatest(Map<String, List<FetchResult>> latest) {
  return latest.values.fold<int>(
    0,
    (sum, results) => sum + totalSolvedFromResults(results),
  );
}

int totalSolvedFromResults(Iterable<FetchResult> results) {
  return results.fold<int>(
    0,
    (sum, result) => sum + displaySolvedCountForResult(result),
  );
}

bool hasDisplaySolvedCount(FetchResult result) {
  return result.status == FetchStatus.success ||
      retainedSolvedCountForResult(result) != null;
}

int displaySolvedCountForResult(FetchResult result) {
  if (result.status == FetchStatus.success) {
    return result.solvedCount ?? 0;
  }
  return retainedSolvedCountForResult(result) ?? 0;
}

int? retainedSolvedCountForResult(FetchResult result) {
  if (result.status == FetchStatus.failure &&
      result.solvedCount != null &&
      result.previousSolvedCount != null) {
    return result.previousSolvedCount;
  }
  return null;
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
