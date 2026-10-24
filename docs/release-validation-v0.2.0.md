# v0.2.0 release validation

Version: `0.2.0+8`. Both Windows executables take their product version from
`pubspec.yaml`. CI must pass again on the final PR revision before merging.

| Requirement | Implementation and evidence |
| --- | --- |
| Release baseline | Reviewed the former unpushed folder/schema commit `1f91c1a`; retained its folder model and sync behavior and upgraded the shared schema to v4. PR #9 brings the release onto `main`. Tag publication checks that the tag matches the manifest and uses the artifacts from the same successful CI run. |
| Upgrade and recovery | Tests cover v0.1.3 config and JSON shapes, v1/v3 database upgrade, WAL snapshots, empty folders, training/backup recovery, and one-time identity migration. Original files and secure-storage bytes remain available. Conflicting directories and invalid core data block writable startup. Repair-and-retry and full backup recovery are exercised. |
| Native companion | Native tests run the production executable for duplicate launch, minimized-window restoration and restart. Raw socket tests cover malformed framing, duplicate/large headers, body limits, wrong lengths, invalid JSON/UTF-8, slow clients, concurrent same-URL imports, occupied ports and shutdown with pending requests. Unfinished JSON migration markers are rejected. |
| Windows distribution | Package includes both EXEs, Flutter assets/plugins, SQLite and app-local VC++ CRT DLLs. Installer smoke verifies per-user installation, Start menu links, uninstall registration, a lower-version installer to current-version upgrade, payload replacement, installed Flutter headless migration and uninstall retaining every original data file byte-for-byte. The lower-version installer is a fixture using current payload; v0.1.3 itself was zip-only. |
| First use and updates | Widget tests save the first problem without OJ setup, skip the guide and reopen it. Settings identifies the companion health protocol, retains the existing browser pairing flow, and offers a manual update check. Update tests cover versions, absent stable releases, errors, response limits and trusted download URLs. |
| Workspace usability | Real Flutter screenshots and widget tests cover overview, folders/tags/batches, settings, todos, feature pages, recovery and fetch failures, light/dark modes and a 900×620 minimum window. Customization stays in Settings; existing themes, training, notes and analysis remain available. |

Local verification on Windows (2026-10-24):

- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`: no issues.
- `flutter test --coverage`: 308 passing tests, 82.2% overall line coverage;
  all configured critical coverage thresholds pass.
- Browser fixtures: 12 extractor and 8 userscript cases pass; generated script
  matches its source.
- `native_companion/build.ps1`: build and native tests pass.
- `flutter build windows --release`: pass.
- `scripts/package_windows_release.ps1 -SkipBuild`: installer, ZIP and SHA-256
  manifest generated.
- `scripts/smoke_windows_installer.ps1`: pass, including real migration exit 1
  for damaged JSON, unchanged legacy input, then exit 0 after repair.

This local run uses the development machine. A clean hosted Windows runner
repeats installation checks in CI; no separate pristine Windows VM was used
locally. The installer is currently unsigned. Public OJ connectivity continues
to depend on external platforms and is represented through visible fetch errors.

Release publication requires the final CI run, a merged PR, a matching `v0.2.0`
tag and verified release assets. Local generated binaries are not a substitute
for those checks.
