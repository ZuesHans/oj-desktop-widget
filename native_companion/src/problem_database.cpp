#include "problem_database.hpp"

#include <algorithm>
#include <stdexcept>
#include <utility>

namespace oj_companion {
namespace {

std::string ColumnText(SqliteApi& api, sqlite3_stmt* statement, int column) {
  const auto* value = api.column_text(statement, column);
  return value == nullptr ? std::string() :
                            std::string(reinterpret_cast<const char*>(value));
}

void BindText(SqliteApi& api, sqlite3* database, sqlite3_stmt* statement,
              int index, const std::string& value) {
  const int result = api.bind_text(statement, index, value.c_str(),
                                   static_cast<int>(value.size()),
                                   SqliteApi::Transient());
  if (result != kSqliteOk) {
    throw std::runtime_error(std::string("SQLite bind failed: ") +
                             api.errmsg(database));
  }
}

void BindNullableText(SqliteApi& api, sqlite3* database,
                      sqlite3_stmt* statement, int index,
                      const std::string& value) {
  const int result = value.empty()
                         ? api.bind_null(statement, index)
                         : api.bind_text(statement, index, value.c_str(),
                                         static_cast<int>(value.size()),
                                         SqliteApi::Transient());
  if (result != kSqliteOk) {
    throw std::runtime_error(std::string("SQLite bind failed: ") +
                             api.errmsg(database));
  }
}

}  // namespace

class ProblemDatabase::Statement {
 public:
  Statement(SqliteApi& api, sqlite3* database, const char* sql)
      : api_(api), database_(database) {
    const int result =
        api_.prepare_v2(database_, sql, -1, &statement_, nullptr);
    if (result != kSqliteOk) {
      throw std::runtime_error(std::string("SQLite prepare failed: ") +
                               api_.errmsg(database_));
    }
  }

  ~Statement() {
    if (statement_ != nullptr) {
      api_.finalize(statement_);
    }
  }

  sqlite3_stmt* get() const { return statement_; }

 private:
  SqliteApi& api_;
  sqlite3* database_;
  sqlite3_stmt* statement_ = nullptr;
};

ProblemDatabase::ProblemDatabase(const std::filesystem::path& path,
                                 bool allow_create_for_testing)
    : allow_create_for_testing_(allow_create_for_testing) {
  if (!allow_create_for_testing_ && !std::filesystem::exists(path)) {
    throw std::runtime_error(
        "题库数据库不存在。请先运行一次新版主程序完成迁移。");
  }
  const std::string utf8_path = WideToUtf8(path.wstring());
  int flags = kSqliteOpenReadWrite | kSqliteOpenFullMutex;
  if (allow_create_for_testing_) {
    flags |= kSqliteOpenCreate;
  }
  const int result = api_.open_v2(utf8_path.c_str(), &database_, flags, nullptr);
  if (result != kSqliteOk) {
    const std::string detail =
        database_ == nullptr ? "unknown SQLite error" : api_.errmsg(database_);
    if (database_ != nullptr) {
      api_.close_v2(database_);
      database_ = nullptr;
    }
    throw std::runtime_error("无法打开题库数据库：" + detail);
  }
  try {
    api_.busy_timeout(database_, 5000);
    Execute("PRAGMA foreign_keys = ON");
    Execute("PRAGMA journal_mode = WAL");
    if (!allow_create_for_testing_) {
      VerifySchema();
    }
  } catch (...) {
    api_.close_v2(database_);
    database_ = nullptr;
    throw;
  }
}

ProblemDatabase::~ProblemDatabase() {
  if (database_ != nullptr) {
    api_.close_v2(database_);
  }
}

void ProblemDatabase::VerifySchema() {
  Statement statement(api_, database_, "PRAGMA user_version");
  if (api_.step(statement.get()) != kSqliteRow ||
      api_.column_int(statement.get(), 0) != 2) {
    throw std::runtime_error(
        "题库数据库版本不受支持。请先打开新版主程序完成迁移；"
        "当前小程序需要 schema v2。");
  }
  Statement revision(api_, database_,
                     "SELECT revision FROM problem_change_state "
                     "WHERE singleton = 1");
  if (api_.step(revision.get()) != kSqliteRow) {
    throw std::runtime_error(
        "题库数据库缺少变更修订记录，请使用新版主程序修复或恢复备份。");
  }
}

std::int64_t ProblemDatabase::Revision() {
  Statement statement(api_, database_,
                      "SELECT revision FROM problem_change_state "
                      "WHERE singleton = 1");
  if (api_.step(statement.get()) != kSqliteRow) {
    ThrowDatabaseError("read problem revision");
  }
  return api_.column_int64(statement.get(), 0);
}

std::vector<ProblemRecord> ProblemDatabase::LoadProblems() {
  Statement statement(api_, database_, R"sql(
    SELECT id, title, url, platform, workflow_status, tags_json, date, note,
           analysis, difficulty, external_id, review_stage, next_review_at,
           archived_at, is_favorite, is_pinned, last_opened_at, created_at,
           updated_at
    FROM problems
    ORDER BY updated_at DESC
  )sql");
  std::vector<ProblemRecord> problems;
  while (true) {
    const int result = api_.step(statement.get());
    if (result == kSqliteDone) {
      break;
    }
    if (result != kSqliteRow) {
      ThrowDatabaseError("load problems");
    }
    ProblemRecord problem;
    problem.id = ColumnText(api_, statement.get(), 0);
    problem.title = ColumnText(api_, statement.get(), 1);
    problem.url = ColumnText(api_, statement.get(), 2);
    problem.platform = ColumnText(api_, statement.get(), 3);
    problem.workflow_status = ColumnText(api_, statement.get(), 4);
    problem.tags_json = ColumnText(api_, statement.get(), 5);
    problem.date = ColumnText(api_, statement.get(), 6);
    problem.note = ColumnText(api_, statement.get(), 7);
    problem.analysis = ColumnText(api_, statement.get(), 8);
    problem.difficulty = ColumnText(api_, statement.get(), 9);
    problem.external_id = ColumnText(api_, statement.get(), 10);
    problem.review_stage = api_.column_int(statement.get(), 11);
    problem.next_review_at = ColumnText(api_, statement.get(), 12);
    problem.archived_at = ColumnText(api_, statement.get(), 13);
    problem.is_favorite = api_.column_int(statement.get(), 14) != 0;
    problem.is_pinned = api_.column_int(statement.get(), 15) != 0;
    problem.last_opened_at = ColumnText(api_, statement.get(), 16);
    problem.created_at = ColumnText(api_, statement.get(), 17);
    problem.updated_at = ColumnText(api_, statement.get(), 18);
    problems.push_back(std::move(problem));
  }
  return problems;
}

void ProblemDatabase::Upsert(const ProblemRecord& problem) {
  Execute("BEGIN IMMEDIATE");
  try {
    Statement statement(api_, database_, R"sql(
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
    )sql");
    int index = 1;
    BindText(api_, database_, statement.get(), index++, problem.id);
    BindText(api_, database_, statement.get(), index++, problem.title);
    BindText(api_, database_, statement.get(), index++, problem.url);
    BindText(api_, database_, statement.get(), index++, problem.platform);
    BindText(api_, database_, statement.get(), index++,
             problem.workflow_status);
    BindText(api_, database_, statement.get(), index++, problem.tags_json);
    BindText(api_, database_, statement.get(), index++, problem.date);
    BindText(api_, database_, statement.get(), index++, problem.note);
    BindText(api_, database_, statement.get(), index++, problem.analysis);
    BindText(api_, database_, statement.get(), index++, problem.difficulty);
    BindText(api_, database_, statement.get(), index++, problem.external_id);
    if (api_.bind_int(statement.get(), index++,
                      std::clamp(problem.review_stage, 0, 5)) != kSqliteOk) {
      ThrowDatabaseError("bind review stage");
    }
    BindNullableText(api_, database_, statement.get(), index++,
                     problem.next_review_at);
    BindNullableText(api_, database_, statement.get(), index++,
                     problem.archived_at);
    if (api_.bind_int(statement.get(), index++, problem.is_favorite ? 1 : 0) !=
            kSqliteOk ||
        api_.bind_int(statement.get(), index++, problem.is_pinned ? 1 : 0) !=
            kSqliteOk) {
      ThrowDatabaseError("bind problem flags");
    }
    BindNullableText(api_, database_, statement.get(), index++,
                     problem.last_opened_at);
    BindText(api_, database_, statement.get(), index++, problem.created_at);
    BindText(api_, database_, statement.get(), index++, problem.updated_at);
    if (api_.step(statement.get()) != kSqliteDone) {
      ThrowDatabaseError("save problem");
    }
    Execute("COMMIT");
  } catch (...) {
    try {
      Execute("ROLLBACK");
    } catch (...) {
    }
    throw;
  }
}

bool ProblemDatabase::Delete(const std::string& id) {
  Execute("BEGIN IMMEDIATE");
  try {
    Statement statement(api_, database_, "DELETE FROM problems WHERE id = ?");
    BindText(api_, database_, statement.get(), 1, id);
    if (api_.step(statement.get()) != kSqliteDone) {
      ThrowDatabaseError("delete problem");
    }
    const bool deleted = api_.changes(database_) > 0;
    Execute("COMMIT");
    return deleted;
  } catch (...) {
    try {
      Execute("ROLLBACK");
    } catch (...) {
    }
    throw;
  }
}

void ProblemDatabase::ExecuteForTesting(const std::string& sql) {
  if (!allow_create_for_testing_) {
    throw std::logic_error("Test SQL is disabled for production databases.");
  }
  Execute(sql);
}

void ProblemDatabase::Execute(const std::string& sql) {
  char* error = nullptr;
  const int result = api_.exec(database_, sql.c_str(), nullptr, nullptr, &error);
  if (result == kSqliteOk) {
    return;
  }
  const std::string detail = error == nullptr ? api_.errmsg(database_) : error;
  if (error != nullptr) {
    api_.free_memory(error);
  }
  throw std::runtime_error("SQLite command failed: " + detail);
}

void ProblemDatabase::ThrowDatabaseError(const std::string& operation) const {
  throw std::runtime_error("Unable to " + operation + ": " +
                           api_.errmsg(database_));
}

}  // namespace oj_companion
