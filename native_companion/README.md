# Native problem companion

`oj_problem_companion.exe` is a small Win32/C++ client for the shared problem
book. It does not embed Flutter. The first version supports:

- listing and opening stored problems;
- row-level insert/update/delete operations;
- title, URL, platform, workflow status, tags, and note editing;
- one-second revision polling so Flutter and the companion refresh each other;
- Unicode database paths and UTF-8 problem content.

## Prerequisites

Launch the Flutter client once before using the companion. Flutter owns schema
migrations and creates `%APPDATA%\com.example\oj_float\problem_book.sqlite3`.
The companion refuses unknown or incomplete schemas instead of modifying them.

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

Only schema version 2 databases are accepted. See
[`docs/problem-database.md`](../docs/problem-database.md) for the shared storage
contract.

