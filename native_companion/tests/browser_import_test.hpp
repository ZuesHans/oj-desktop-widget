#pragma once

#include <chrono>
#include <future>
#include <thread>

namespace {

class TestSocket {
 public:
  explicit TestSocket(std::uint16_t port) {
    WSADATA winsock{};
    if (WSAStartup(MAKEWORD(2, 2), &winsock) != 0) {
      throw std::runtime_error("Test Winsock startup failed.");
    }
    handle_ = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    DWORD timeout = 6000;
    setsockopt(handle_, SOL_SOCKET, SO_RCVTIMEO,
               reinterpret_cast<const char*>(&timeout), sizeof(timeout));
    setsockopt(handle_, SOL_SOCKET, SO_SNDTIMEO,
               reinterpret_cast<const char*>(&timeout), sizeof(timeout));
    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = htons(port);
    if (connect(handle_, reinterpret_cast<const sockaddr*>(&address),
                sizeof(address)) == SOCKET_ERROR) {
      closesocket(handle_);
      WSACleanup();
      throw std::runtime_error("Test connection failed.");
    }
  }
  ~TestSocket() { closesocket(handle_); WSACleanup(); }
  TestSocket(const TestSocket&) = delete;
  TestSocket& operator=(const TestSocket&) = delete;

  bool Send(const std::string& value) {
    std::size_t offset = 0;
    while (offset < value.size()) {
      const int sent = send(handle_, value.data() + offset,
                            static_cast<int>(value.size() - offset), 0);
      if (sent <= 0) return false;
      offset += static_cast<std::size_t>(sent);
    }
    return true;
  }
  void FinishSending() { shutdown(handle_, SD_SEND); }
  std::string Receive() {
    std::string response;
    std::array<char, 4096> buffer{};
    while (true) {
      const int received = recv(handle_, buffer.data(),
                                 static_cast<int>(buffer.size()), 0);
      if (received == SOCKET_ERROR) {
        Require(WSAGetLastError() != WSAETIMEDOUT, "test client timed out");
        break;
      }
      if (received == 0) break;
      response.append(buffer.data(), static_cast<std::size_t>(received));
    }
    return response;
  }
 private:
  SOCKET handle_ = INVALID_SOCKET;
};

std::string ImportRequest(const std::string& body,
                          const std::string& length = "",
                          const std::string& extra = "") {
  return "POST /v1/problems/import HTTP/1.1\r\nHost: 127.0.0.1\r\n"
      "X-OJ-Companion: userscript-v1\r\nContent-Type: application/json\r\n"
      "Content-Length: " + (length.empty() ? std::to_string(body.size()) : length) +
      "\r\n" + extra + "\r\n" + body;
}

std::string RawResponse(std::uint16_t port, const std::string& request) {
  TestSocket client(port);
  client.Send(request);
  client.FinishSending();
  return client.Receive();
}

void TestHttpHardening(const std::filesystem::path& path) {
  using namespace std::chrono;
  const std::string body = R"({"url":"https://example.test/http-recovery","title":"Recovery"})";
  oj_companion::BrowserImportServer server(path, 0);
  server.Start();
  const auto port = server.Port();
  oj_companion::ProblemDatabase observer(path);
  const auto initial = observer.Revision();
  const auto reject = [&](const std::string& request, int status) {
    const auto response = RawResponse(port, request);
    Require(response.find("HTTP/1.1 " + std::to_string(status) + " ") == 0,
            ("Unexpected response: " + response.substr(0, 100)).c_str());
    Require(response.find("Access-Control-Allow-Origin") == std::string::npos,
            "native service must not enable CORS");
    Require(observer.Revision() == initial, "rejected request changed the database");
  };
  reject("garbage\r\n\r\n", 400);
  reject("POST /v1/problems/import HTTP/2\r\n\r\n", 400);
  reject("POST /v1/problems/import HTTP/1.1 trailing\r\n\r\n", 400);
  reject("POST /v1/problems/import HTTP/1.1\r\nBroken\r\n\r\n", 400);
  reject("POST /v1/problems/import HTTP/1.1\r\nHost: localhost\r\n\r\n", 411);
  reject(ImportRequest(body, "-1"), 400);
  reject(ImportRequest(body, "+1"), 400);
  reject(ImportRequest(body, "1x"), 400);
  reject(ImportRequest(body, "9999999999999999999999999999999"), 400);
  reject(ImportRequest(body, "65537"), 413);
  reject(ImportRequest(body, std::to_string(body.size() + 1)), 400);
  reject(ImportRequest(body, "1"), 400);
  reject(ImportRequest(body, "", "Content-Length: 0\r\n"), 400);
  reject(ImportRequest(body, "", "Transfer-Encoding: chunked\r\n"), 400);
  reject(ImportRequest(body, "", "X-Long: " + std::string(17000, 'x') + "\r\n"), 431);
  reject(ImportRequest("{bad json}"), 400);
  reject(ImportRequest(R"({"url":"https://example.test","extra":invalid})"), 400);
  reject(ImportRequest(R"({"url":"https://example.test","extra":01})"), 400);
  reject(ImportRequest(R"({"url":"https://example.test","url":"https://other.test"})"), 400);
  reject(ImportRequest(std::string("{\"url\":\"https://example.test/\xFF\"}")), 400);
  reject(ImportRequest("{\"url\":\"https://example.test\",\"extra\":" +
      std::string(1000, '[') + "0" + std::string(1000, ']') + "}"), 400);
  auto request = ImportRequest(body);
  request.replace(0, 4, "GET");
  reject(request, 404);
  request = ImportRequest(body);
  request.replace(request.find("userscript-v1"), 13, "ordinary-page");
  reject(request, 403);
  request = ImportRequest(body);
  request.replace(request.find("application/json"), 16, "text/plain");
  reject(request, 415);
  const std::string health_request = "GET /v1/health HTTP/1.1\r\nHost: localhost\r\nX-OJ-Companion: userscript-v1\r\nContent-Length: 0\r\n\r\n";
  const auto health = RawResponse(port, health_request);
  Require(health.find("HTTP/1.1 200 OK") == 0 &&
      health.find("\"service\":\"oj-float-companion\"") != std::string::npos &&
      health.find("Access-Control-Allow-Origin") == std::string::npos,
      "health endpoint must identify a ready companion without enabling CORS");
  Require(observer.Revision() == initial, "health check must not change data");
  reject("GET /v1/health HTTP/1.1\r\nHost: localhost\r\nContent-Length: 0\r\n\r\n", 403);

  // A stalled peer cannot block a healthy import on another connection.
  TestSocket stalled(port);
  stalled.Send("POST /v1/problems/import HTTP/1.1\r\n");
  const auto started = steady_clock::now();
  const auto recovery = RawResponse(port, ImportRequest(body));
  Require(recovery.find("HTTP/1.1 200 OK") == 0,
          "healthy import failed while another client stalled");
  Require(steady_clock::now() - started < seconds(2),
          "stalled connection blocked healthy import");
  // Valid body larger than the header limit must be accepted when coalesced.
  const auto large = "{\"url\":\"https://example.test/large\",\"extra\":\"" +
      std::string(60000, 'x') + "\"}";
  Require(RawResponse(port, ImportRequest(large)).find("HTTP/1.1 200 OK") == 0,
          "large valid body was mistaken for oversized headers");

  const auto before_parallel = observer.LoadProblems().size();
  std::vector<std::future<std::string>> parallel;
  for (int index = 0; index < 6; ++index) {
    parallel.push_back(std::async(std::launch::async, [port] {
      return RawResponse(port, ImportRequest(
          R"({"url":"https://example.test/parallel","tags":["DP"]})"));
    }));
  }
  int created = 0;
  for (auto& response : parallel) {
    const auto value = response.get();
    Require(value.find("HTTP/1.1 200 OK") == 0, "parallel import failed");
    if (value.find("\"status\":\"created\"") != std::string::npos) ++created;
  }
  Require(created == 1 && observer.LoadProblems().size() == before_parallel + 1,
          "parallel imports duplicated the same problem");

  TestSocket trickle(port);
  trickle.Send("POST /v1/problems/import HTTP/1.1\r\nX-Slow: ");
  const auto slow_started = steady_clock::now();
  auto drip = std::async(std::launch::async, [&trickle] {
    for (int index = 0; index < 9; ++index) {
      std::this_thread::sleep_for(milliseconds(400));
      if (!trickle.Send("x")) break;
    }
  });
  Require(trickle.Receive().find("HTTP/1.1 408 ") == 0,
          "slow headers should exceed the total request deadline");
  Require(steady_clock::now() - slow_started < milliseconds(4500),
          "trickle traffic extended the request deadline");
  drip.get();
  Require(stalled.Receive().find("HTTP/1.1 408 ") == 0,
          "stalled headers should time out");

  oj_companion::BrowserImportServer occupied(path, port);
  bool failed = false;
  try { occupied.Start(); } catch (const std::exception& error) {
    failed = std::string(error.what()).find(std::to_string(port)) != std::string::npos;
  }
  Require(failed && !occupied.IsRunning(), "occupied port must report startup failure");
  occupied.Stop();
  Require(RawResponse(port, ImportRequest(body)).find("HTTP/1.1 200 OK") == 0,
          "rejected requests or occupied-port probe damaged the original listener");

  TestSocket partial_body(port);
  partial_body.Send(ImportRequest("{", "100"));
  const auto stopping = steady_clock::now();
  server.Stop();
  Require(!server.IsRunning() && steady_clock::now() - stopping < milliseconds(1500),
          "server shutdown waited on an incomplete request");
  server.Stop();
  std::cout << "native HTTP malformed/framing/size/slow/concurrency/port/shutdown checks passed\n";
}

}  // namespace
