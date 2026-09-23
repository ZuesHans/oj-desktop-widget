#include <winsock2.h>
#include <ws2tcpip.h>

#include "browser_import.hpp"

#include <objbase.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <condition_variable>
#include <cctype>
#include <iomanip>
#include <mutex>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string_view>
#include <thread>
#include <utility>

namespace oj_companion {
namespace {

constexpr std::size_t kMaximumHeaderBytes = 16 * 1024;
constexpr std::size_t kMaximumBodyBytes = 64 * 1024;
constexpr char kRequiredClientHeader[] = "userscript-v1";

std::string Trim(std::string value) {
  const auto is_space = [](unsigned char character) {
    return std::isspace(character) != 0;
  };
  value.erase(value.begin(),
              std::find_if_not(value.begin(), value.end(), is_space));
  value.erase(std::find_if_not(value.rbegin(), value.rend(), is_space).base(),
              value.end());
  return value;
}

std::string LowerAscii(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(), [](char value) {
    return static_cast<char>(
        std::tolower(static_cast<unsigned char>(value)));
  });
  return value;
}

bool StartsWith(const std::string& value, const std::string& prefix) {
  return value.size() >= prefix.size() &&
         std::equal(prefix.begin(), prefix.end(), value.begin());
}

void AppendUtf8(std::string& output, unsigned int code_point) {
  if (code_point <= 0x7F) {
    output.push_back(static_cast<char>(code_point));
  } else if (code_point <= 0x7FF) {
    output.push_back(static_cast<char>(0xC0 | (code_point >> 6)));
    output.push_back(static_cast<char>(0x80 | (code_point & 0x3F)));
  } else if (code_point <= 0xFFFF) {
    output.push_back(static_cast<char>(0xE0 | (code_point >> 12)));
    output.push_back(static_cast<char>(0x80 | ((code_point >> 6) & 0x3F)));
    output.push_back(static_cast<char>(0x80 | (code_point & 0x3F)));
  } else if (code_point <= 0x10FFFF) {
    output.push_back(static_cast<char>(0xF0 | (code_point >> 18)));
    output.push_back(static_cast<char>(0x80 | ((code_point >> 12) & 0x3F)));
    output.push_back(static_cast<char>(0x80 | ((code_point >> 6) & 0x3F)));
    output.push_back(static_cast<char>(0x80 | (code_point & 0x3F)));
  } else {
    throw std::runtime_error("JSON contains an invalid Unicode code point.");
  }
}

class JsonReader {
 public:
  explicit JsonReader(std::string_view input) : input_(input) {}

  BrowserProblemImport ParseImport() {
    BrowserProblemImport result;
    SkipWhitespace();
    Expect('{');
    SkipWhitespace();
    if (Consume('}')) {
      throw std::runtime_error("Import JSON must contain a URL.");
    }
    while (true) {
      const std::string key = ParseString();
      SkipWhitespace();
      Expect(':');
      SkipWhitespace();
      if (key == "url") {
        result.url = ParseString();
      } else if (key == "title") {
        result.title = ParseString();
      } else if (key == "platform") {
        result.platform = ParseString();
      } else if (key == "externalId") {
        result.external_id = ParseString();
      } else if (key == "tags") {
        result.tags = ParseStringArray();
      } else if (key == "difficulty") {
        result.difficulty = ParseString();
      } else {
        SkipValue();
      }
      SkipWhitespace();
      if (Consume('}')) {
        break;
      }
      Expect(',');
      SkipWhitespace();
    }
    SkipWhitespace();
    if (position_ != input_.size()) {
      throw std::runtime_error("Unexpected data after import JSON.");
    }
    return result;
  }

  std::vector<std::string> ParseArrayDocument() {
    SkipWhitespace();
    auto values = ParseStringArray();
    SkipWhitespace();
    if (position_ != input_.size()) {
      throw std::runtime_error("Unexpected data after JSON array.");
    }
    return values;
  }

 private:
  void SkipWhitespace() {
    while (position_ < input_.size() &&
           std::isspace(static_cast<unsigned char>(input_[position_])) != 0) {
      ++position_;
    }
  }

  char Take() {
    if (position_ >= input_.size()) {
      throw std::runtime_error("Unexpected end of JSON.");
    }
    return input_[position_++];
  }

  void Expect(char expected) {
    if (Take() != expected) {
      throw std::runtime_error("Invalid JSON syntax.");
    }
  }

  bool Consume(char expected) {
    if (position_ < input_.size() && input_[position_] == expected) {
      ++position_;
      return true;
    }
    return false;
  }

  unsigned int ParseHex4() {
    unsigned int value = 0;
    for (int index = 0; index < 4; ++index) {
      const char character = Take();
      value <<= 4;
      if (character >= '0' && character <= '9') {
        value += static_cast<unsigned int>(character - '0');
      } else if (character >= 'a' && character <= 'f') {
        value += static_cast<unsigned int>(character - 'a' + 10);
      } else if (character >= 'A' && character <= 'F') {
        value += static_cast<unsigned int>(character - 'A' + 10);
      } else {
        throw std::runtime_error("Invalid JSON Unicode escape.");
      }
    }
    return value;
  }

  std::string ParseString() {
    Expect('"');
    std::string output;
    while (true) {
      const char character = Take();
      if (character == '"') {
        return output;
      }
      if (static_cast<unsigned char>(character) < 0x20) {
        throw std::runtime_error("JSON strings cannot contain controls.");
      }
      if (character != '\\') {
        output.push_back(character);
        continue;
      }
      const char escaped = Take();
      switch (escaped) {
        case '"':
        case '\\':
        case '/':
          output.push_back(escaped);
          break;
        case 'b':
          output.push_back('\b');
          break;
        case 'f':
          output.push_back('\f');
          break;
        case 'n':
          output.push_back('\n');
          break;
        case 'r':
          output.push_back('\r');
          break;
        case 't':
          output.push_back('\t');
          break;
        case 'u': {
          unsigned int code_point = ParseHex4();
          if (code_point >= 0xD800 && code_point <= 0xDBFF) {
            if (Take() != '\\' || Take() != 'u') {
              throw std::runtime_error("JSON high surrogate has no pair.");
            }
            const unsigned int low = ParseHex4();
            if (low < 0xDC00 || low > 0xDFFF) {
              throw std::runtime_error("JSON surrogate pair is invalid.");
            }
            code_point = 0x10000 + ((code_point - 0xD800) << 10) +
                         (low - 0xDC00);
          } else if (code_point >= 0xDC00 && code_point <= 0xDFFF) {
            throw std::runtime_error("JSON low surrogate has no pair.");
          }
          AppendUtf8(output, code_point);
          break;
        }
        default:
          throw std::runtime_error("JSON contains an invalid escape.");
      }
    }
  }

  std::vector<std::string> ParseStringArray() {
    Expect('[');
    SkipWhitespace();
    std::vector<std::string> values;
    if (Consume(']')) {
      return values;
    }
    while (true) {
      values.push_back(ParseString());
      SkipWhitespace();
      if (Consume(']')) {
        return values;
      }
      Expect(',');
      SkipWhitespace();
    }
  }

  void SkipValue() {
    SkipWhitespace();
    if (position_ >= input_.size()) {
      throw std::runtime_error("Unexpected end of JSON value.");
    }
    if (input_[position_] == '"') {
      ParseString();
      return;
    }
    if (input_[position_] == '{') {
      ++position_;
      SkipWhitespace();
      if (Consume('}')) return;
      while (true) {
        ParseString();
        SkipWhitespace();
        Expect(':');
        SkipValue();
        SkipWhitespace();
        if (Consume('}')) return;
        Expect(',');
        SkipWhitespace();
      }
    }
    if (input_[position_] == '[') {
      ++position_;
      SkipWhitespace();
      if (Consume(']')) return;
      while (true) {
        SkipValue();
        SkipWhitespace();
        if (Consume(']')) return;
        Expect(',');
        SkipWhitespace();
      }
    }
    const std::size_t start = position_;
    while (position_ < input_.size() &&
           std::string_view(",]} \t\r\n").find(input_[position_]) ==
               std::string_view::npos) {
      ++position_;
    }
    if (position_ == start) {
      throw std::runtime_error("Invalid JSON value.");
    }
  }

  std::string_view input_;
  std::size_t position_ = 0;
};

std::string JsonEscape(const std::string& value) {
  std::ostringstream output;
  for (const unsigned char character : value) {
    switch (character) {
      case '"':
        output << "\\\"";
        break;
      case '\\':
        output << "\\\\";
        break;
      case '\b':
        output << "\\b";
        break;
      case '\f':
        output << "\\f";
        break;
      case '\n':
        output << "\\n";
        break;
      case '\r':
        output << "\\r";
        break;
      case '\t':
        output << "\\t";
        break;
      default:
        if (character < 0x20) {
          output << "\\u" << std::hex << std::setw(4) << std::setfill('0')
                 << static_cast<int>(character) << std::dec;
        } else {
          output << static_cast<char>(character);
        }
    }
  }
  return output.str();
}

std::string SerializeTags(const std::vector<std::string>& tags) {
  std::string result = "[";
  for (std::size_t index = 0; index < tags.size(); ++index) {
    if (index > 0) result += ',';
    result += '"' + JsonEscape(tags[index]) + '"';
  }
  result += ']';
  return result;
}

std::vector<std::string> NormalizeTags(
    const std::vector<std::string>& values) {
  std::set<std::string> seen;
  std::vector<std::string> tags;
  for (const auto& value : values) {
    const std::string tag = Trim(value);
    if (tag.empty()) continue;
    if (tag.size() > 100) {
      throw std::runtime_error("A problem tag is too long.");
    }
    if (seen.insert(LowerAscii(tag)).second) {
      tags.push_back(tag);
      if (tags.size() == 30) break;
    }
  }
  return tags;
}

std::string UtcNowIso8601() {
  SYSTEMTIME time{};
  GetSystemTime(&time);
  std::ostringstream result;
  result << std::setfill('0') << std::setw(4) << time.wYear << '-'
         << std::setw(2) << time.wMonth << '-' << std::setw(2) << time.wDay
         << 'T' << std::setw(2) << time.wHour << ':' << std::setw(2)
         << time.wMinute << ':' << std::setw(2) << time.wSecond << '.'
         << std::setw(3) << time.wMilliseconds << 'Z';
  return result.str();
}

std::string Today() {
  SYSTEMTIME time{};
  GetLocalTime(&time);
  std::ostringstream result;
  result << std::setfill('0') << std::setw(4) << time.wYear << '-'
         << std::setw(2) << time.wMonth << '-' << std::setw(2) << time.wDay;
  return result.str();
}

std::string NewProblemId() {
  GUID guid{};
  if (CoCreateGuid(&guid) != S_OK) {
    throw std::runtime_error("Unable to generate a problem ID.");
  }
  std::array<wchar_t, 40> buffer{};
  StringFromGUID2(guid, buffer.data(), static_cast<int>(buffer.size()));
  std::wstring value(buffer.data());
  value.erase(std::remove(value.begin(), value.end(), L'{'), value.end());
  value.erase(std::remove(value.begin(), value.end(), L'}'), value.end());
  return "browser-" + WideToUtf8(value);
}

std::string NormalizePlatform(const std::string& raw) {
  const std::string value = LowerAscii(Trim(raw));
  static const std::set<std::string> supported = {
      "cf", "atcoder", "hd", "lg", "poj", "uva",
      "nc", "spoj", "lccn", "other"};
  return supported.count(value) == 0 ? "other" : value;
}

std::string CanonicalUrl(std::string value) {
  value = Trim(value);
  const auto fragment = value.find('#');
  if (fragment != std::string::npos) value.erase(fragment);
  while (!value.empty() && value.back() == '/') value.pop_back();
  return LowerAscii(value);
}

bool SameProblem(const ProblemRecord& problem,
                 const BrowserProblemImport& input) {
  const std::string platform = NormalizePlatform(input.platform);
  if (platform != "other" && !input.external_id.empty() &&
      LowerAscii(problem.platform) == platform &&
      LowerAscii(problem.external_id) == LowerAscii(input.external_id)) {
    return true;
  }
  return CanonicalUrl(problem.url) == CanonicalUrl(input.url);
}

std::vector<std::string> MergeTags(const std::string& existing_json,
                                   const std::vector<std::string>& incoming) {
  std::vector<std::string> combined;
  try {
    combined = JsonReader(existing_json).ParseArrayDocument();
  } catch (...) {
  }
  combined.insert(combined.end(), incoming.begin(), incoming.end());
  return NormalizeTags(combined);
}

struct HttpRequest {
  std::string method;
  std::string path;
  std::vector<std::pair<std::string, std::string>> headers;
  std::string body;

  std::string Header(const std::string& name) const {
    const std::string target = LowerAscii(name);
    for (const auto& header : headers) {
      if (header.first == target) return header.second;
    }
    return {};
  }
};

class HttpError : public std::runtime_error {
 public:
  HttpError(int status, const std::string& message)
      : std::runtime_error(message), status(status) {}
  int status;
};

HttpRequest ReceiveRequest(SOCKET socket) {
  DWORD timeout = 3000;
  setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO,
             reinterpret_cast<const char*>(&timeout), sizeof(timeout));
  std::string data;
  std::array<char, 4096> buffer{};
  std::size_t header_end = std::string::npos;
  while ((header_end = data.find("\r\n\r\n")) == std::string::npos) {
    const int received = recv(socket, buffer.data(),
                              static_cast<int>(buffer.size()), 0);
    if (received <= 0) throw HttpError(400, "Incomplete HTTP headers.");
    data.append(buffer.data(), static_cast<std::size_t>(received));
    if (data.size() > kMaximumHeaderBytes) {
      throw HttpError(431, "HTTP headers are too large.");
    }
  }

  HttpRequest request;
  std::istringstream headers(data.substr(0, header_end));
  std::string line;
  if (!std::getline(headers, line)) throw HttpError(400, "Missing request.");
  if (!line.empty() && line.back() == '\r') line.pop_back();
  std::istringstream request_line(line);
  std::string version;
  if (!(request_line >> request.method >> request.path >> version) ||
      !StartsWith(version, "HTTP/")) {
    throw HttpError(400, "Invalid HTTP request line.");
  }
  while (std::getline(headers, line)) {
    if (!line.empty() && line.back() == '\r') line.pop_back();
    const auto colon = line.find(':');
    if (colon == std::string::npos) {
      throw HttpError(400, "Invalid HTTP header.");
    }
    request.headers.emplace_back(LowerAscii(Trim(line.substr(0, colon))),
                                 Trim(line.substr(colon + 1)));
  }

  const std::string length_text = request.Header("content-length");
  if (length_text.empty()) throw HttpError(411, "Content-Length is required.");
  std::size_t content_length = 0;
  try {
    std::size_t parsed = 0;
    content_length = std::stoull(length_text, &parsed);
    if (parsed != length_text.size()) throw std::invalid_argument("trailing");
  } catch (...) {
    throw HttpError(400, "Content-Length is invalid.");
  }
  if (content_length > kMaximumBodyBytes) {
    throw HttpError(413, "Request body is too large.");
  }
  const std::size_t body_start = header_end + 4;
  while (data.size() - body_start < content_length) {
    const int received = recv(socket, buffer.data(),
                              static_cast<int>(buffer.size()), 0);
    if (received <= 0) throw HttpError(400, "Incomplete request body.");
    data.append(buffer.data(), static_cast<std::size_t>(received));
  }
  request.body = data.substr(body_start, content_length);
  return request;
}

const char* ReasonPhrase(int status) {
  switch (status) {
    case 200:
      return "OK";
    case 400:
      return "Bad Request";
    case 403:
      return "Forbidden";
    case 404:
      return "Not Found";
    case 408:
      return "Request Timeout";
    case 411:
      return "Length Required";
    case 413:
      return "Payload Too Large";
    case 415:
      return "Unsupported Media Type";
    case 431:
      return "Request Header Fields Too Large";
    default:
      return "Internal Server Error";
  }
}

void SendAll(SOCKET socket, const std::string& data) {
  std::size_t sent = 0;
  while (sent < data.size()) {
    const int result = send(socket, data.data() + sent,
                            static_cast<int>(data.size() - sent), 0);
    if (result <= 0) return;
    sent += static_cast<std::size_t>(result);
  }
}

void SendJson(SOCKET socket, int status, const std::string& body) {
  std::ostringstream response;
  response << "HTTP/1.1 " << status << ' ' << ReasonPhrase(status) << "\r\n"
           << "Content-Type: application/json; charset=utf-8\r\n"
           << "Content-Length: " << body.size() << "\r\n"
           << "Cache-Control: no-store\r\n"
           << "X-Content-Type-Options: nosniff\r\n"
           << "Connection: close\r\n\r\n"
           << body;
  SendAll(socket, response.str());
}

void HandleClient(SOCKET client, ProblemDatabase& database) {
  try {
    const HttpRequest request = ReceiveRequest(client);
    if (request.method != "POST" ||
        request.path != "/v1/problems/import") {
      throw HttpError(404, "Unknown endpoint.");
    }
    if (request.Header("x-oj-companion") != kRequiredClientHeader) {
      throw HttpError(403, "The companion userscript header is required.");
    }
    if (!StartsWith(LowerAscii(request.Header("content-type")),
                    "application/json")) {
      throw HttpError(415, "Content-Type must be application/json.");
    }
    const auto input = ParseBrowserProblemImport(request.body);
    const auto result = SaveBrowserProblemImport(database, input);
    SendJson(client, 200,
             std::string("{\"status\":\"") +
                 (result.created ? "created" : "existing") +
                 "\",\"problemId\":\"" + JsonEscape(result.problem_id) +
                 "\"}");
  } catch (const HttpError& error) {
    SendJson(client, error.status,
             "{\"error\":\"request_rejected\",\"message\":\"" +
                 JsonEscape(error.what()) + "\"}");
  } catch (const std::exception& error) {
    SendJson(client, 500,
             "{\"error\":\"import_failed\",\"message\":\"" +
                 JsonEscape(error.what()) + "\"}");
  }
  shutdown(client, SD_BOTH);
  closesocket(client);
}

}  // namespace

BrowserProblemImport ParseBrowserProblemImport(const std::string& json) {
  if (json.size() > kMaximumBodyBytes) {
    throw std::runtime_error("Import JSON is too large.");
  }
  auto result = JsonReader(json).ParseImport();
  result.url = Trim(result.url);
  result.title = Trim(result.title);
  result.platform = NormalizePlatform(result.platform);
  result.external_id = Trim(result.external_id);
  result.difficulty = Trim(result.difficulty);
  result.tags = NormalizeTags(result.tags);
  if (result.url.empty() || result.url.size() > 4096 ||
      (!StartsWith(LowerAscii(result.url), "http://") &&
       !StartsWith(LowerAscii(result.url), "https://"))) {
    throw std::runtime_error("Import URL must be a valid HTTP/HTTPS URL.");
  }
  if (result.title.size() > 500 || result.external_id.size() > 200 ||
      result.difficulty.size() > 100) {
    throw std::runtime_error("Import metadata is too long.");
  }
  return result;
}

BrowserImportResult SaveBrowserProblemImport(ProblemDatabase& database,
                                             const BrowserProblemImport& input) {
  const auto problems = database.LoadProblems();
  const auto existing = std::find_if(
      problems.begin(), problems.end(),
      [&](const ProblemRecord& problem) { return SameProblem(problem, input); });
  const std::string now = UtcNowIso8601();
  ProblemRecord problem;
  bool created = existing == problems.end();
  if (created) {
    problem.id = NewProblemId();
    problem.workflow_status = "backlog";
    problem.date = Today();
    problem.created_at = now;
  } else {
    problem = *existing;
  }
  if (!input.title.empty()) problem.title = input.title;
  if (problem.title.empty()) {
    problem.title = input.external_id.empty() ? input.url : input.external_id;
  }
  problem.url = input.url;
  problem.platform = NormalizePlatform(input.platform);
  if (!input.external_id.empty()) problem.external_id = input.external_id;
  if (!input.difficulty.empty()) problem.difficulty = input.difficulty;
  if (!input.tags.empty()) {
    problem.tags_json = SerializeTags(MergeTags(problem.tags_json, input.tags));
  }
  problem.updated_at = now;
  database.Upsert(problem);
  return {created, problem.id};
}

class BrowserImportServer::Impl {
 public:
  Impl(std::filesystem::path database_path, std::uint16_t requested_port)
      : database_path_(std::move(database_path)),
        requested_port_(requested_port) {}

  ~Impl() { Stop(); }

  void Start() {
    std::unique_lock<std::mutex> lock(state_mutex_);
    if (worker_.joinable()) return;
    stop_requested_ = false;
    startup_complete_ = false;
    startup_error_.clear();
    worker_ = std::thread([this] { Run(); });
    startup_condition_.wait(lock, [this] { return startup_complete_; });
    if (!startup_error_.empty()) {
      const std::string error = startup_error_;
      lock.unlock();
      worker_.join();
      throw std::runtime_error(error);
    }
  }

  void Stop() noexcept {
    stop_requested_ = true;
    if (worker_.joinable()) worker_.join();
  }

  bool IsRunning() const noexcept { return running_; }
  std::uint16_t Port() const noexcept { return bound_port_; }

 private:
  void FinishStartup(const std::string& error) {
    {
      std::lock_guard<std::mutex> lock(state_mutex_);
      startup_error_ = error;
      startup_complete_ = true;
    }
    startup_condition_.notify_all();
  }

  void Run() noexcept {
    WSADATA winsock{};
    SOCKET listener = INVALID_SOCKET;
    bool winsock_started = false;
    try {
      if (WSAStartup(MAKEWORD(2, 2), &winsock) != 0) {
        throw std::runtime_error("Unable to initialize Winsock.");
      }
      winsock_started = true;
      listener = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
      if (listener == INVALID_SOCKET) {
        throw std::runtime_error("Unable to create browser import socket.");
      }
      BOOL exclusive = TRUE;
      setsockopt(listener, SOL_SOCKET, SO_EXCLUSIVEADDRUSE,
                 reinterpret_cast<const char*>(&exclusive),
                 sizeof(exclusive));
      sockaddr_in address{};
      address.sin_family = AF_INET;
      address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
      address.sin_port = htons(requested_port_);
      if (bind(listener, reinterpret_cast<const sockaddr*>(&address),
               sizeof(address)) == SOCKET_ERROR ||
          listen(listener, SOMAXCONN) == SOCKET_ERROR) {
        throw std::runtime_error(
            "无法监听 127.0.0.1:27122；端口可能已被占用。");
      }
      int address_size = sizeof(address);
      if (getsockname(listener, reinterpret_cast<sockaddr*>(&address),
                      &address_size) == SOCKET_ERROR) {
        throw std::runtime_error("Unable to read browser import port.");
      }
      bound_port_ = ntohs(address.sin_port);
      ProblemDatabase database(database_path_);
      running_ = true;
      FinishStartup("");

      while (!stop_requested_) {
        fd_set readable;
        FD_ZERO(&readable);
        FD_SET(listener, &readable);
        timeval timeout{};
        timeout.tv_usec = 250000;
        const int ready = select(0, &readable, nullptr, nullptr, &timeout);
        if (ready == SOCKET_ERROR) {
          throw std::runtime_error("Browser import listener failed.");
        }
        if (ready == 0 || !FD_ISSET(listener, &readable)) continue;
        const SOCKET client = accept(listener, nullptr, nullptr);
        if (client != INVALID_SOCKET) HandleClient(client, database);
      }
    } catch (const std::exception& error) {
      if (!startup_complete_) FinishStartup(error.what());
    }
    running_ = false;
    if (listener != INVALID_SOCKET) closesocket(listener);
    if (winsock_started) WSACleanup();
  }

  std::filesystem::path database_path_;
  std::uint16_t requested_port_;
  std::atomic<bool> stop_requested_{false};
  std::atomic<bool> running_{false};
  std::atomic<std::uint16_t> bound_port_{0};
  std::thread worker_;
  mutable std::mutex state_mutex_;
  std::condition_variable startup_condition_;
  bool startup_complete_ = false;
  std::string startup_error_;
};

BrowserImportServer::BrowserImportServer(std::filesystem::path database_path,
                                         std::uint16_t port)
    : impl_(std::make_unique<Impl>(std::move(database_path), port)) {}

BrowserImportServer::~BrowserImportServer() = default;

void BrowserImportServer::Start() { impl_->Start(); }

void BrowserImportServer::Stop() noexcept { impl_->Stop(); }

bool BrowserImportServer::IsRunning() const noexcept {
  return impl_->IsRunning();
}

std::uint16_t BrowserImportServer::Port() const noexcept {
  return impl_->Port();
}

}  // namespace oj_companion
