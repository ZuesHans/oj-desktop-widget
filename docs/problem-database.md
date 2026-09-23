# Problem database contract

The Flutter client stores the problem book in `problem_book.sqlite3` inside the
application support directory. This file is the shared persistence boundary for
the Flutter client and the native C++ quick-entry companion.

## Compatibility rules

- Check `PRAGMA user_version` before writing. The current schema version is `2`.
- Use SQLite transactions for every write.
- Keep WAL mode enabled and set a busy timeout before accessing the database.
- Do not change the schema from the companion. Schema migrations belong to the
  Flutter client release that increments `user_version`.
- Store booleans as `0` or `1`, tags as a JSON string array, and timestamps as
  ISO-8601 strings.
- Treat `id` as an opaque text primary key. New IDs should remain globally
  unique across both programs.

## Migration

On first access, the Flutter client creates schema version 1 and imports the
strictly validated contents of `problems_v1.json`. If the primary legacy file is
damaged, its atomic `.bak` is tried. The legacy files are retained after a
successful migration, but SQLite becomes the only live problem source.

The `metadata` row named `legacy_json_migrated` prevents a later edit to the old
JSON file from overwriting the SQLite data.

## Tables

`problems` contains the complete `ProblemRecord`. Frequently filtered workflow
and update columns are indexed. `metadata` stores one-time storage bookkeeping;
it is not application configuration.

`problem_change_state` contains a monotonic revision. SQLite triggers increment
it after every insert, update, or delete, including SQL committed by the native
companion. The Flutter client polls this value once per second and reloads only
when it changes. Companion code must not update the revision row directly.

Flutter uses row-level upserts and deletes during normal operation. Full-table
replacement is reserved for an explicit backup restore, so a native write is not
removed by an unrelated Flutter edit.
