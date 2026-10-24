# Problem database contract

The Flutter client stores the problem book in `problem_book.sqlite3` inside the
application support directory. This file is the shared persistence boundary for
the Flutter client and the native C++ quick-entry companion.

## Compatibility rules

- Check `PRAGMA user_version` before writing. The current schema version is `4`.
- Use SQLite transactions for every write.
- Keep WAL mode enabled and set a busy timeout before accessing the database.
- Do not change the schema from the companion. Schema migrations belong to the
  Flutter client release that increments `user_version`.
- Store booleans as `0` or `1`, tags as a JSON string array, and timestamps as
  ISO-8601 strings.
- `problems.folder` is a trimmed optional classification. Existing rows migrate
  to an empty folder and must remain usable without one.
- Treat `id` as an opaque text primary key. New IDs should remain globally
  unique across both programs.

## Migration

On first access, the Flutter client creates the current schema and imports the
strictly validated contents of `problems_v1.json`. If the primary legacy file is
damaged, its atomic `.bak` is tried. The legacy files are retained after a
successful migration, but SQLite becomes the only live problem source.

The `metadata` row named `legacy_json_migrated` prevents a later edit to the old
JSON file from overwriting the SQLite data. The companion requires this nonempty marker as well as schema v4. A file that merely exists or contains a partly initialized schema is not ready. Flutter startup validates core records before showing writable actions; migration failure leads to the recovery page.

## Tables

`problems` contains the complete `ProblemRecord`. Frequently filtered workflow
and update columns are indexed, including `folder`. `metadata` stores one-time storage bookkeeping;
it is not application configuration.

`problem_change_state` contains a monotonic revision. SQLite triggers increment
it after every insert, update, or delete, including SQL committed by the native
companion. The Flutter client polls this value once per second and reloads only
when it changes. When problem sync is enabled, an external change detected by
this poll also schedules the configured automatic sync, so rows entered in the
native companion are sent to the website without waiting for the next OJ
account refresh. Companion code must not update the revision row directly.

Flutter uses row-level upserts and deletes during normal operation. Full-table
replacement is reserved for an explicit backup restore, so a native write is not
removed by an unrelated Flutter edit.

## Folder catalog (v4)

`problem_folders(name TEXT PRIMARY KEY COLLATE NOCASE)` keeps named folders even
when no problem belongs to them. Migration from v3 seeds the catalog from trimmed
nonempty `problems.folder` values. An empty string still means unclassified.
Both clients create empty folders with an insert into this table. Duplicate
names are ignored without changing the revision. Folder insert/update/delete
triggers advance the shared revision; problem insert/folder-update triggers
register new names in the same write transaction. The catalog and problem rows
are read in one Flutter snapshot.

Flutter owns v3-to-v4 migration. Open the current main client once before using
the current companion with an existing v3 database. The companion accepts v4
only and never migrates a custom database.

Batch operations run in a single `BEGIN IMMEDIATE` transaction and modify only
the selected rows. They read current data before changing folder, tags or status,
preserving unrelated fields and concurrent edits. Any failure rolls back the
entire batch. Portable and automatic backups include `problemFolders`, including
empty folders; older backups derive their catalog from problem rows. Import,
recovery journals, and import rollback restore that metadata with the core data.
