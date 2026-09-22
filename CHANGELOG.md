# Changelog

## v0.2.0-beta - 2026-07-26

- Replaced compact, floating, and feature-window modes with one resizable Windows Dashboard client.
- Restored native title bar, taskbar, minimize, maximize, and close behavior with a 1120x760 default and 900x620 minimum window.
- Made close-to-tray and silent startup explicit opt-in lifecycle settings; normal close exits by default.
- Added unsaved-settings protection for navigation, native close, tray hiding, and tray exit.
- Added named-mutex single-instance behavior that restores and focuses an existing window.
- Added config v2 migration while retaining the `oj_float` data, backup, executable, and sync identities.
- Unified snapshot retention at the latest 6000 rows for load, refresh, import, export, memory, and disk.
- Migrated the obsolete floating-window tests and added client lifecycle, migration, startup, and data-boundary coverage.
- Replaced automatic review queues with user-managed schedules for any date, a shared filtered problem picker, list-based favorites, and precise task-bound timing.
- Simplified attempt records to results, assistance, mistake categories, reflections, and automatic elapsed time while preserving compatible legacy imports.
- Added a recoverable write-ahead transaction for problem and training updates so interrupted saves roll forward consistently on the next launch.
- Added opt-in local core-data backups with a user-selected directory and daily time, retaining the latest 7 backup days plus one backup from each of 4 earlier weeks.
- Added strict schema parsing, SHA-256 content verification, temporary-file flush and atomic publication, consistent snapshots across queued writes, and visible reporting for corrupt or failed backups.
- Added pre-import safety backups outside normal rotation and core-backup restore that preserves OJ snapshots, teammate fetches, refresh logs, local backup settings, and securely stored tokens.
- Migrated the problem book from `problems_v1.json` to a WAL-enabled SQLite database, with strict one-time legacy migration and the original JSON retained as a recovery source.
- Added row-level problem writes and trigger-backed change revisions so native companion edits refresh in Flutter without unrelated records being overwritten.

## v0.1.3beta - 2026-07-10

- Reworked the frontend into a clearer product structure: compact widget, large float, and full Dashboard now have distinct responsibilities.
- Added Dashboard navigation, overview layout, settings panel, reusable surface cards, and home summary view model.
- Polished the compact widget, large float, title bar, entry panels, problem book, contests, teammates, heatmap, refresh logs, and settings surfaces.
- Fixed compact widget overflow at the configured Windows floating-window height.
- Improved Nowcoder fallback behavior when OJ Hunt is unavailable, including nickname-to-user-ID resolution and clearer failure messages.
- Added a Ninja-based Windows release build script for machines where Visual Studio/MSBuild HostX86 hangs or fails.
- Added focused tests for the home summary view model, compact widget layout, and Nowcoder fallback parsing.
- Rewrote the README with current product usage, privacy notes, build instructions, and release guidance.

## v0.1.3 - 2026-06-23

- Added optional OJ Float Sync Webhook v1.
- Stored the sync token in secure storage instead of the normal config JSON.
- Added field-level privacy switches for daily stats, problem rows, notes, and solution analysis.
- Kept OJ usernames, account-level deltas, passwords, cookies, and tokens out of the sync payload.
- Sent empty arrays for disabled sync scopes so the server can clear public projections.
- Required HTTPS sync endpoints, with localhost HTTP allowed for local development.
- Added manual "Save & Sync Now" and optional auto-sync after refresh.
- Updated the website receiver/public projection contract for stable v0.1.3 use.
