import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../models/problem_record.dart';

const problemDatabaseFileName = 'problem_book.sqlite3';

class ProblemDatabaseSnapshot {
  const ProblemDatabaseSnapshot({
    required this.problems,
    required this.revision,
  });

  final List<ProblemRecord> problems;
  final int revision;
}

/// SQLite-backed problem storage shared by the Flutter client and the future
/// native quick-entry companion.
///
/// Connections are deliberately short-lived so another process can open the
/// same database without depending on the Flutter application's lifecycle.
class ProblemDatabase {
  ProblemDatabase(this.file);

  static const schemaVersion = 2;
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
        _upsertAll(database, legacyProblems);
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
    return loadSnapshot().problems;
  }

  ProblemDatabaseSnapshot loadSnapshot() {
    final database = _open();
    try {
      database.execute('BEGIN');
      final revision = _readRevision(database);
      final problems = _readProblems(database);
      database.execute('COMMIT');
      problems.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
      return ProblemDatabaseSnapshot(
        problems: List.unmodifiable(problems),
        revision: revision,
      );
    } catch (_) {
      _rollback(database);
      rethrow;
    } finally {
      database.close();
    }
  }

  int readRevision() {
    final database = _open();
    try {
      return _readRevision(database);
    } finally {
      database.close();
    }
  }

  void upsertProblem(ProblemRecord problem) {
    upsertProblems([problem]);
  }

  void upsertProblems(Iterable<ProblemRecord> problems) {
    final database = _open();
    try {
      database.execute('BEGIN IMMEDIATE');
      _upsertAll(database, problems);
      database.execute('COMMIT');
    } catch (_) {
      _rollback(database);
      rethrow;
    } finally {
      database.close();
    }
  }

  void deleteProblem(String id) {
    final database = _open();
    try {
      database.execute('BEGIN IMMEDIATE');
      database.execute('DELETE FROM problems WHERE id = ?', [id]);
      database.execute('COMMIT');
    } catch (_) {
      _rollback(database);
      rethrow;
    } finally {
      database.close();
    }
  }

  void replaceProblems(List<ProblemRecord> problems) {
    final database = _open();
    try {
      database.execute('BEGIN IMMEDIATE');
      database.execute('DELETE FROM problems');
      _upsertAll(database, problems);
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
      var currentVersion =
          database.select('PRAGMA user_version').single['user_version'] as int;
      if (currentVersion < 0 || currentVersion > schemaVersion) {
        throw StateError(
          'Unsupported problem database schema version: $currentVersion.',
        );
      }
      if (currentVersion <= 1) {
        database.execute('PRAGMA journal_mode = WAL');
      }
      if (currentVersion == 0) {
        _runMigration(database, () {
          _createSchemaV1(database);
          database.execute('PRAGMA user_version = 1');
        });
        currentVersion = 1;
      }
      if (currentVersion == 1) {
        _runMigration(database, () {
          _migrateSchema1To2(database);
          database.execute('PRAGMA user_version = 2');
        });
      }
      database.execute('PRAGMA synchronous = NORMAL');
      return database;
    } catch (_) {
      database.close();
      rethrow;
    }
  }

  static void _createSchemaV1(Database database) {
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

  static void _migrateSchema1To2(Database database) {
    database.execute('''
      CREATE TABLE IF NOT EXISTS problem_change_state (
        singleton INTEGER PRIMARY KEY NOT NULL CHECK (singleton = 1),
        revision INTEGER NOT NULL
      )
    ''');
    database.execute(
      'INSERT OR IGNORE INTO problem_change_state(singleton, revision) '
      'VALUES (1, 0)',
    );
    database.execute('''
      CREATE TRIGGER IF NOT EXISTS problems_revision_after_insert
      AFTER INSERT ON problems
      BEGIN
        UPDATE problem_change_state
        SET revision = revision + 1
        WHERE singleton = 1;
      END
    ''');
    database.execute('''
      CREATE TRIGGER IF NOT EXISTS problems_revision_after_update
      AFTER UPDATE ON problems
      BEGIN
        UPDATE problem_change_state
        SET revision = revision + 1
        WHERE singleton = 1;
      END
    ''');
    database.execute('''
      CREATE TRIGGER IF NOT EXISTS problems_revision_after_delete
      AFTER DELETE ON problems
      BEGIN
        UPDATE problem_change_state
        SET revision = revision + 1
        WHERE singleton = 1;
      END
    ''');
  }

  static void _upsertAll(Database database, Iterable<ProblemRecord> problems) {
    final statement = database.prepare('''
      INSERT INTO problems (
        id, title, url, platform, workflow_status, tags_json, date, note,
        analysis, difficulty, external_id, review_stage, next_review_at,
        archived_at, is_favorite, is_pinned, last_opened_at, created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        url = excluded.url,
        platform = excluded.platform,
        workflow_status = excluded.workflow_status,
        tags_json = excluded.tags_json,
        date = excluded.date,
        note = excluded.note,
        analysis = excluded.analysis,
        difficulty = excluded.difficulty,
        external_id = excluded.external_id,
        review_stage = excluded.review_stage,
        next_review_at = excluded.next_review_at,
        archived_at = excluded.archived_at,
        is_favorite = excluded.is_favorite,
        is_pinned = excluded.is_pinned,
        last_opened_at = excluded.last_opened_at,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at
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

  static List<ProblemRecord> _readProblems(Database database) {
    return database.select('SELECT * FROM problems').map((row) {
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
  }

  static int _readRevision(Database database) {
    return database
        .select(
          'SELECT revision FROM problem_change_state WHERE singleton = 1',
        )
        .single['revision'] as int;
  }

  static void _runMigration(Database database, void Function() migration) {
    database.execute('BEGIN IMMEDIATE');
    try {
      migration();
      database.execute('COMMIT');
    } catch (_) {
      _rollback(database);
      rethrow;
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
