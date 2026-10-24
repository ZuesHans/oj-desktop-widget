# Native problem companion

`oj_problem_companion.exe` is a small Win32/C++ client for the shared problem
book. It does not embed Flutter. The first version supports:

- listing and opening stored problems;
- row-level insert/update/delete operations;
- title, URL, platform, workflow status, folder, tags, note, and analysis editing;
- one-second revision polling so Flutter and the companion refresh each other;
- a loopback-only browser import service on `127.0.0.1:27122` for the pig
  Tampermonkey userscript, with no Flutter process required;
- persistent empty folders and combined folder / multi-tag any/all filtering;
- checkboxes for transactional batch move, add/remove tags, status, archive and
  restore, plus Markdown export (including notes and analysis);
- a list and editor shown side by side;
- Unicode database paths and UTF-8 problem content.

For a learner-oriented map of the modules, startup sequence, data flow, and
safe extension points, see [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Prerequisites

Flutter owns schema migrations and creates
`%APPDATA%\ZuesHans\OJ Float\problem_book.sqlite3`. If the default database
does not exist, the companion starts `oj_float.exe` in a dedicated background
migration mode and then continues automatically. Keep both executables together
when packaging them. Unknown, incomplete, or missing custom databases are still
rejected instead of being modified.

Visual Studio's **Desktop development with C++** workload is required. Build
the Flutter application or run its tests first so the repository has the same
`sqlite3.dll` used by the main client.

## Build and test

```powershell
flutter test
.\native_companion\build.ps1
```

The release files are written under `build\native_companion\Release`. Keep
`sqlite3.dll` next to `oj_problem_companion.exe` when copying the program.

To open an isolated or portable database, pass its full path:

```powershell
.\oj_problem_companion.exe --database "D:\OJ\problem_book.sqlite3"
```

Only schema version 4 databases with a completed legacy migration marker are accepted. For an existing v3 database, open the updated main client once to migrate before launching the companion. See
[`docs/problem-database.md`](../docs/problem-database.md) for the shared storage
contract.

## Browser import

While the companion is running, it accepts the bundled Tampermonkey script at
`POST http://127.0.0.1:27122/v1/problems/import`. The listener binds only to
IPv4 loopback, requires `Content-Type: application/json` and the dedicated
`X-OJ-Companion: userscript-v1` header, caps request sizes, and deliberately
does not return CORS headers. Headers are capped at 16 KiB, bodies at 64 KiB, and the complete read has a 3-second deadline; up to eight connections are handled independently. The listener rejects malformed lengths, duplicate headers, transfer encoding, incomplete bodies, invalid UTF-8 and JSON. Port conflicts are reported without disabling local editing. A `GET /v1/health` with the same dedicated header and `Content-Length: 0` identifies a ready service. Ordinary page JavaScript therefore cannot use the
endpoint. See [`browser_extension/tampermonkey/README.md`](../browser_extension/tampermonkey/README.md)
for installation.

## Application icon

The editable source asset is `resources/oj_problem_companion.png`; the Windows
resource compiler embeds `resources/oj_problem_companion.ico` into the EXE.
After replacing the PNG, regenerate the multi-size ICO with:

```powershell
.\native_companion\tools\create_windows_icon.ps1
```

## Folder and batch workflow

Create an empty folder using the name field beside **新建文件夹**. The folder
filter includes all folders and unclassified problems. Tag filters accept a
comma-separated list; **匹配全部标签** switches between any and all matches.

Check problem rows to select a batch. Choose an operation, enter its value, and
click **应用到勾选项**. Move with an empty value returns rows to unclassified;
add/remove tag values are comma-separated. Status values are `backlog`, `active`,
`review`, `mastered`, or `archived`; archive/restore operations need no value.
Save a dirty editor before applying a batch. **导出勾选项** exports Markdown.

## Single instance and tests

A Windows user and canonical database path identify an instance. Starting the same
database again restores and focuses its existing window; different databases can
run independently. Native tests exercise the actual executable's focus and
restart behavior, malformed/large/slow requests, simultaneous duplicate imports,
occupied ports, and shutdown with partial requests.

Default-database initialization waits for the Flutter migration process to exit
successfully and verifies the complete schema before opening it. A failed or
unfinished migration never opens an empty writable problem book. Existing data
from the former `com.example` directory is migrated by Flutter and retained there.
