#pragma once

#include <windows.h>

#include <cstdint>
#include <filesystem>
#include <stdexcept>
#include <string>

struct sqlite3;
struct sqlite3_stmt;

namespace oj_companion {

constexpr int kSqliteOk = 0;
constexpr int kSqliteRow = 100;
constexpr int kSqliteDone = 101;
constexpr int kSqliteInteger = 1;
constexpr int kSqliteOpenReadWrite = 0x00000002;
constexpr int kSqliteOpenCreate = 0x00000004;
constexpr int kSqliteOpenFullMutex = 0x00010000;

class SqliteApi {
 public:
  using Destructor = void (*)(void*);

  SqliteApi();
  ~SqliteApi();
  SqliteApi(const SqliteApi&) = delete;
  SqliteApi& operator=(const SqliteApi&) = delete;

  int (*open_v2)(const char*, sqlite3**, int, const char*) = nullptr;
  int (*close_v2)(sqlite3*) = nullptr;
  const char* (*errmsg)(sqlite3*) = nullptr;
  int (*busy_timeout)(sqlite3*, int) = nullptr;
  int (*exec)(sqlite3*, const char*, int (*)(void*, int, char**, char**),
              void*, char**) = nullptr;
  void (*free_memory)(void*) = nullptr;
  int (*prepare_v2)(sqlite3*, const char*, int, sqlite3_stmt**,
                    const char**) = nullptr;
  int (*step)(sqlite3_stmt*) = nullptr;
  int (*finalize)(sqlite3_stmt*) = nullptr;
  int (*reset)(sqlite3_stmt*) = nullptr;
  int (*clear_bindings)(sqlite3_stmt*) = nullptr;
  int (*bind_text)(sqlite3_stmt*, int, const char*, int, Destructor) = nullptr;
  int (*bind_int)(sqlite3_stmt*, int, int) = nullptr;
  int (*bind_null)(sqlite3_stmt*, int) = nullptr;
  const unsigned char* (*column_text)(sqlite3_stmt*, int) = nullptr;
  int (*column_int)(sqlite3_stmt*, int) = nullptr;
  std::int64_t (*column_int64)(sqlite3_stmt*, int) = nullptr;
  int (*column_type)(sqlite3_stmt*, int) = nullptr;
  int (*changes)(sqlite3*) = nullptr;

  static Destructor Transient();

 private:
  HMODULE module_ = nullptr;
};

std::string WideToUtf8(const std::wstring& value);
std::wstring Utf8ToWide(const std::string& value);

}  // namespace oj_companion
