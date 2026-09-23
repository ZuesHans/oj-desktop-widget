import 'dart:io';

/// Deletes test data while tolerating short-lived Windows file scanner locks.
Future<void> deleteTestDirectory(Directory directory) async {
  FileSystemException? lastError;
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      return;
    } on FileSystemException catch (error) {
      lastError = error;
      await Future<void>.delayed(Duration(milliseconds: 50 * (attempt + 1)));
    }
  }
  throw lastError!;
}
