#include "problem_database.hpp"

#include <objbase.h>
#include <windows.h>

#include <array>
#include <filesystem>
#include <iostream>
#include <stdexcept>

namespace {

std::filesystem::path TestDatabasePath() {
  std::array<wchar_t, MAX_PATH> temp_path{};
  if (GetTempPathW(static_cast<DWORD>(temp_path.size()), temp_path.data()) == 0) {
    throw std::runtime_error("Unable to locate the temporary directory.");
  }
  GUID guid{};
  CoCreateGuid(&guid);
  std::array<wchar_t, 40> guid_text{};
  StringFromGUID2(guid, guid_text.data(), static_cast<int>(guid_text.size()));
  const auto directory =
      std::filesystem::path(temp_path.data()) / (L"oj_companion_" +
                                                 std::wstring(guid_text.data()));
  std::filesystem::create_directories(directory);
  return directory / L"problem_book.sqlite3";
}

constexpr const char* kSchema = R"sql(
  CREATE TABLE problems (
    id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, url TEXT NOT NULL,
    platform TEXT NOT NULL, workflow_status TEXT NOT NULL,
    tags_json TEXT NOT NULL DEFAULT '[]', date TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '', analysis TEXT NOT NULL DEFAULT '',
    difficulty TEXT NOT NULL DEFAULT '', external_id TEXT NOT NULL DEFAULT '',
    review_stage INTEGER NOT NULL DEFAULT 0, next_review_at TEXT,
    archived_at TEXT, is_favorite INTEGER NOT NULL DEFAULT 0,
    is_pinned INTEGER NOT NULL DEFAULT 0, last_opened_at TEXT,
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL
  );
  CREATE TABLE problem_change_state (
    singleton INTEGER PRIMARY KEY NOT NULL CHECK (singleton = 1),
    revision INTEGER NOT NULL
  );
  INSERT INTO problem_change_state(singleton, revision) VALUES (1, 0);
  CREATE TRIGGER problems_revision_after_insert AFTER INSERT ON problems BEGIN
    UPDATE problem_change_state SET revision = revision + 1 WHERE singleton = 1;
  END;
  CREATE TRIGGER problems_revision_after_update AFTER UPDATE ON problems BEGIN
    UPDATE problem_change_state SET revision = revision + 1 WHERE singleton = 1;
  END;
  CREATE TRIGGER problems_revision_after_delete AFTER DELETE ON problems BEGIN
    UPDATE problem_change_state SET revision = revision + 1 WHERE singleton = 1;
  END;
  PRAGMA user_version = 2;
)sql";

void Require(bool condition, const char* message) {
  if (!condition) {
    throw std::runtime_error(message);
  }
}

}  // namespace

int main() {
  const auto path = TestDatabasePath();
  const auto directory = path.parent_path();
  try {
    {
      oj_companion::ProblemDatabase setup(path, true);
      setup.ExecuteForTesting(kSchema);
    }
    {
      oj_companion::ProblemDatabase database(path);
      oj_companion::ProblemDatabase observer(path);
      Require(database.Revision() == 0, "fresh revision should be zero");
      oj_companion::ProblemRecord problem;
      problem.id = "native-test";
      problem.title = "Two Sum";
      problem.url = "https://example.com/two-sum";
      problem.platform = "other";
      problem.workflow_status = "backlog";
      problem.tags_json = R"(["array"])";
      problem.date = "2026-09-22";
      problem.created_at = "2026-09-22T12:00:00.000Z";
      problem.updated_at = problem.created_at;
      database.Upsert(problem);
      Require(database.Revision() == 1, "insert should advance revision");
      Require(observer.Revision() == 1,
              "a second connection should observe the insert revision");
      const auto loaded = observer.LoadProblems();
      Require(loaded.size() == 1, "inserted problem should be loaded");
      Require(loaded.front().title == "Two Sum", "problem title changed");
      problem = loaded.front();
      problem.title = "Two Sum updated externally";
      observer.Upsert(problem);
      Require(database.Revision() == 2, "update should advance revision");
      Require(database.LoadProblems().front().title ==
                  "Two Sum updated externally",
              "the first connection should observe the external update");
      Require(database.Delete(problem.id), "delete should report a row");
      Require(database.Revision() == 3, "delete should advance revision");
      Require(database.LoadProblems().empty(), "deleted row should be absent");
    }
    std::filesystem::remove_all(directory);
    std::cout << "native companion database contract passed\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    std::error_code ignored;
    std::filesystem::remove_all(directory, ignored);
    return 1;
  }
}
