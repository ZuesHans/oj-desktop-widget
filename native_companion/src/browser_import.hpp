#pragma once

#include "problem_database.hpp"

#include <cstdint>
#include <filesystem>
#include <memory>
#include <string>
#include <vector>

namespace oj_companion {

constexpr std::uint16_t kBrowserImportPort = 27122;

struct BrowserProblemImport {
  std::string url;
  std::string title;
  std::string platform;
  std::string external_id;
  std::vector<std::string> tags;
  std::string difficulty;
};

struct BrowserImportResult {
  bool created = false;
  std::string problem_id;
};

BrowserProblemImport ParseBrowserProblemImport(const std::string& json);
BrowserImportResult SaveBrowserProblemImport(ProblemDatabase& database,
                                             const BrowserProblemImport& input);

class BrowserImportServer {
 public:
  explicit BrowserImportServer(std::filesystem::path database_path,
                               std::uint16_t port = kBrowserImportPort);
  ~BrowserImportServer();
  BrowserImportServer(const BrowserImportServer&) = delete;
  BrowserImportServer& operator=(const BrowserImportServer&) = delete;

  void Start();
  void Stop() noexcept;
  bool IsRunning() const noexcept;
  std::uint16_t Port() const noexcept;

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace oj_companion
