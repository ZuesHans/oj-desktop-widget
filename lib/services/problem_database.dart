import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../models/problem_record.dart';

const problemDatabaseFileName = 'problem_book.sqlite3';

/// SQLite-backed problem storage shared by the Flutter client and the future
/// native quick-entry companion.
///
/// Connections are deliberately short-lived so another process can open the
/// same database without depending on the Flutter application's lifecycle.
class ProblemDatabase {
  ProblemDatabase(this.file);

  static const schemaVersion = 1;
  static const _legacyMigrationKey = 'legacy_json_migrated';

  final File file;

  bool get needsLegacyMigration {
    final database = _open();
    try {
      final rows = database.select(
        'SELECT value FROM metadata WHERE key = ?',
        [_legacyMigrationKey],
      );
      return rows.isEmpty;
    } finally {
      database.close();
    }
  }

  void migrateLegacy(List<ProblemRecord> legacyProblems) {
    final database = _open();
    try {
      database.execute('BEGIN IMMEDIATE');
      final migrated = database.select(
        'SELECT value FROM metadata WHERE key = ?',
        [_legacyMigrationKey],
      );
      if (migrated.isNotEmpty) {
        database.execute('COMMIT');
        return;
      }

      final count = database
          .select('SELECT COUNT(*) AS count FROM problems')
          .single['count'] as int;
      if (count == 0) {
        _insertAll(database, legacyProblems);
      }
      database.execute(
        'INSERT OR REPLACE INTO metadata(key, value) VALUES (?, ?)',
        [_legacyMigrationKey, DateTime.now().toUtc().toIso8601String()],
      );
      database.execute('COMMIT');
    } catch (_) {
      _rollback(database);
      rethrow;
    } finally {
      database.close();
    }
  }

  List<ProblemRecord> loadProblems() {
    final database = _open();
    try {
      final problems = database.select('SELECT * FROM problems').map((row) {
        return ProblemRecord.fromJson({
          'id': row['id'],
          'title': row['title'],
          'url': row['url'],
          'platform': row['platform'],
          'workflowStatus': row['workflow_status'],
          'tags': row['tags_json'],
          'date': row['date'],
          'note': row['note'],
          'analysis': row['analysis'],
          'difficulty': row['difficulty'],
          'externalId': row['external_id'],
          'reviewStage': row['review_stage'],
          'nextReviewAt': row['next_review_at'],
          'archivedAt': row['archived_at'],
          'isFavorite': row['is_favorite'] == 1,
          'isPinned': row['is_pinned'] == 1,
          'lastOpenedAt': row['last_opened_at'],
          'created_at': row['created_at'],
          'updated_at': row['updated_at'],
        });
      }).toList();
      problems.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
      return List.unmodifiable(problems);
    } finally {
      database.close();
    }
  }

  void replaceProblems(List<ProblemRecord> problems) {
    final database = _open();
    try {
      database.execute('BEGIN IMMEDIATE');
      database.execute('DELETE FROM problems');
      _insertAll(database, problems);
      database.execute('COMMIT');
    } catch (_) {
      _rollback(database);
      rethrow;
    } finally {
      database.close();
    }
  }

  Database _open() {
    file.parent.createSync(recursive: true);
    final database = sqlite3.open(file.path);
    try {
      database.execute('PRAGMA busy_timeout = 5000');
      database.execute('PRAGMA foreign_keys = ON');
      final currentVersion =
          database.select('PRAGMA user_version').single['user_version'] as int;
      if (currentVersion != 0 && currentVersion != schemaVersion) {
        throw StateError(
          'Unsupported problem database schema version: $currentVersion.',
        );
      }
      if (currentVersion == 0) {
        database.execute('PRAGMA journal_mode = WAL');
        _createSchema(database);
        database.execute('PRAGMA user_version = $schemaVersion');
      }
      database.execute('PRAGMA synchronous = NORMAL');
      return database;
    } catch (_) {
      database.close();
      rethrow;
    }
  }

  static void _createSchema(Database database) {
    database.execute('''
      CREATE TABLE IF NOT EXISTS metadata (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS problems (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        platform TEXT NOT NULL,
        workflow_status TEXT NOT NULL,
        tags_json TEXT NOT NULL DEFAULT '[]',
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        analysis TEXT NOT NULL DEFAULT '',
        difficulty TEXT NOT NULL DEFAULT '',
        external_id TEXT NOT NULL DEFAULT '',
        review_stage INTEGER NOT NULL DEFAULT 0,
        next_review_at TEXT,
        archived_at TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        last_opened_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    database.execute(
      'CREATE INDEX IF NOT EXISTS problems_workflow_status_idx '
      'ON problems(workflow_status)',
    );
    database.execute(
      'CREATE INDEX IF NOT EXISTS problems_updated_at_idx '
      'ON problems(updated_at)',
    );
  }

  static void _insertAll(Database database, Iterable<ProblemRecord> problems) {
    final statement = database.prepare('''
      INSERT INTO problems (
        id, title, url, platform, workflow_status, tags_json, date, note,
        analysis, difficulty, external_id, review_stage, next_review_at,
        archived_at, is_favorite, is_pinned, last_opened_at, created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      for (final problem in problems) {
        statement.execute([
          problem.id,
          problem.title,
          problem.url,
          problemPlatformValue(problem.platform),
          problem.workflowStatus.name,
          jsonEncode(problem.tags),
          problem.date,
          problem.note,
          problem.analysis,
          problem.difficulty,
          problem.externalId,
          problem.reviewStage,
          problem.nextReviewAt?.toIso8601String(),
          problem.archivedAt?.toIso8601String(),
          problem.isFavorite ? 1 : 0,
          problem.isPinned ? 1 : 0,
          problem.lastOpenedAt?.toIso8601String(),
          problem.createdAt.toIso8601String(),
          problem.updatedAt.toIso8601String(),
        ]);
      }
    } finally {
      statement.close();
    }
  }

  static void _rollback(Database database) {
    try {
      database.execute('ROLLBACK');
    } catch (_) {
      // Preserve the original database error.
    }
  }
}
