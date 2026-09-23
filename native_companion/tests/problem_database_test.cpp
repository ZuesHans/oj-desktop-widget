#include <winsock2.h>

#include "browser_import.hpp"
#include "problem_database.hpp"

#include <objbase.h>
#include <windows.h>

#include <array>
#include <filesystem>
#include <iostream>
#include <sstream>
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

std::string SendImportRequest(std::uint16_t port, const std::string& body,
                              bool include_client_header = true) {
  WSADATA winsock{};
  if (WSAStartup(MAKEWORD(2, 2), &winsock) != 0) {
    throw std::runtime_error("Unable to initialize test Winsock.");
  }
  SOCKET socket_handle = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (socket_handle == INVALID_SOCKET) {
    WSACleanup();
    throw std::runtime_error("Unable to create test socket.");
  }
  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  address.sin_port = htons(port);
  if (connect(socket_handle, reinterpret_cast<const sockaddr*>(&address),
              sizeof(address)) == SOCKET_ERROR) {
    closesocket(socket_handle);
    WSACleanup();
    throw std::runtime_error("Unable to connect to browser import server.");
  }
  std::ostringstream request;
  request << "POST /v1/problems/import HTTP/1.1\r\n"
          << "Host: 127.0.0.1\r\n"
          << "Content-Type: application/json\r\n";
  if (include_client_header) {
    request << "X-OJ-Companion: userscript-v1\r\n";
  }
  request << "Content-Length: " << body.size()
          << "\r\nConnection: close\r\n\r\n"
          << body;
  const std::string bytes = request.str();
  std::size_t sent = 0;
  while (sent < bytes.size()) {
    const int result = send(socket_handle, bytes.data() + sent,
                            static_cast<int>(bytes.size() - sent), 0);
    if (result <= 0) {
      closesocket(socket_handle);
      WSACleanup();
      throw std::runtime_error("Unable to send browser import request.");
    }
    sent += static_cast<std::size_t>(result);
  }
  shutdown(socket_handle, SD_SEND);
  std::string response;
  std::array<char, 4096> buffer{};
  while (true) {
    const int received = recv(socket_handle, buffer.data(),
                              static_cast<int>(buffer.size()), 0);
    if (received <= 0) break;
    response.append(buffer.data(), static_cast<std::size_t>(received));
  }
  closesocket(socket_handle);
  WSACleanup();
  return response;
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

      const auto parsed = oj_companion::ParseBrowserProblemImport(R"json({
        "url":"https://codeforces.com/contest/1799/problem/A",
        "title":"A. Recent Actions",
        "platform":"cf",
        "externalId":"1799:A",
        "tags":["implementation","implementation"],
        "difficulty":"800"
      })json");
      Require(parsed.tags.size() == 1, "import tags should be normalized");
      const auto direct =
          oj_companion::SaveBrowserProblemImport(database, parsed);
      Require(direct.created, "first direct import should create a problem");
      Require(database.Revision() == 4,
              "direct browser import should advance revision");

      oj_companion::BrowserImportServer server(path, 0);
      server.Start();
      Require(server.IsRunning(), "browser import server should start");
      Require(server.Port() != 0, "browser import server should expose port");
      const auto merged_response = SendImportRequest(
          server.Port(), R"json({
            "url":"https://codeforces.com/problemset/problem/1799/A",
            "title":"A. Recent Actions (updated)",
            "platform":"cf",
            "externalId":"1799:A",
            "tags":["greedy"],
            "difficulty":"900"
          })json");
      Require(merged_response.find("HTTP/1.1 200 OK") != std::string::npos,
              "valid userscript request should return 200");
      Require(merged_response.find("\"status\":\"existing\"") !=
                  std::string::npos,
              "same platform problem should merge");
      const auto forbidden =
          SendImportRequest(server.Port(), R"json({"url":"https://bad"})json",
                            false);
      Require(forbidden.find("HTTP/1.1 403 Forbidden") != std::string::npos,
              "ordinary page request without client header should fail");
      server.Stop();

      const auto imported = database.LoadProblems();
      Require(imported.size() == 1,
              "browser import should not duplicate an existing problem");
      Require(imported.front().title == "A. Recent Actions (updated)",
              "browser import should merge updated title");
      Require(imported.front().difficulty == "900",
              "browser import should merge difficulty");
      Require(imported.front().tags_json.find("implementation") !=
                  std::string::npos &&
                  imported.front().tags_json.find("greedy") !=
                      std::string::npos,
              "browser import should merge tags");
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
