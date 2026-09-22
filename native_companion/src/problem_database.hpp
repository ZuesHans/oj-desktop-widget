#pragma once

#include "sqlite_api.hpp"

#include <cstdint>
#include <filesystem>
#include <memory>
#include <string>
#include <vector>

namespace oj_companion {

struct ProblemRecord {
  std::string id;
  std::string title;
  std::string url;
  std::string platform = "other";
  std::string workflow_status = "backlog";
  std::string tags_json = "[]";
  std::string date;
  std::string note;
  std::string analysis;
  std::string difficulty;
  std::string external_id;
  int review_stage = 0;
  std::string next_review_at;
  std::string archived_at;
  bool is_favorite = false;
  bool is_pinned = false;
  std::string last_opened_at;
  std::string created_at;
  std::string updated_at;
};

class ProblemDatabase {
 public:
  explicit ProblemDatabase(const std::filesystem::path& path,
                           bool allow_create_for_testing = false);
  ~ProblemDatabase();
  ProblemDatabase(const ProblemDatabase&) = delete;
  ProblemDatabase& operator=(const ProblemDatabase&) = delete;

  std::int64_t Revision();
  std::vector<ProblemRecord> LoadProblems();
  void Upsert(const ProblemRecord& problem);
  bool Delete(const std::string& id);

  // Used only by the native database contract test to prepare an isolated DB.
  void ExecuteForTesting(const std::string& sql);

 private:
  class Statement;

  void Execute(const std::string& sql);
  void VerifySchema();
  [[noreturn]] void ThrowDatabaseError(const std::string& operation) const;

  SqliteApi api_;
  sqlite3* database_ = nullptr;
  bool allow_create_for_testing_ = false;
};

}  // namespace oj_companion
