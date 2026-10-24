#pragma once

namespace {

class TestCompanionProcess {
 public:
  explicit TestCompanionProcess(const std::filesystem::path& database) {
    std::array<wchar_t, 32768> path{};
    GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
    const auto executable = std::filesystem::path(path.data()).parent_path() /
        L"oj_problem_companion.exe";
    auto command = L"\"" + executable.wstring() + L"\" --database \"" +
        database.wstring() + L"\"";
    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESHOWWINDOW;
    startup.wShowWindow = SW_HIDE;
    Require(CreateProcessW(executable.c_str(), command.data(), nullptr, nullptr,
        FALSE, 0, nullptr, executable.parent_path().c_str(), &startup, &process_) != 0,
        "cannot launch companion fixture");
    CloseHandle(process_.hThread);
  }
  ~TestCompanionProcess() {
    if (WaitForSingleObject(process_.hProcess, 0) == WAIT_TIMEOUT) {
      if (const auto window = Window()) PostMessageW(window, WM_CLOSE, 0, 0);
      if (WaitForSingleObject(process_.hProcess, 3000) == WAIT_TIMEOUT) {
        TerminateProcess(process_.hProcess, 99);
        WaitForSingleObject(process_.hProcess, 1000);
      }
    }
    CloseHandle(process_.hProcess);
  }
  HWND Window() const {
    struct Search { DWORD pid; HWND window; } search{process_.dwProcessId, nullptr};
    EnumWindows([](HWND candidate, LPARAM value) -> BOOL {
      auto& lookup = *reinterpret_cast<Search*>(value);
      DWORD pid = 0;
      GetWindowThreadProcessId(candidate, &pid);
      wchar_t name[128]{};
      GetClassNameW(candidate, name, 128);
      if (pid == lookup.pid && std::wstring(name) == L"OjProblemCompanionWindow") {
        lookup.window = candidate;
        return FALSE;
      }
      return TRUE;
    }, reinterpret_cast<LPARAM>(&search));
    return search.window;
  }
  HWND WaitForWindow() const {
    for (int attempt = 0; attempt < 100; ++attempt) {
      if (const auto window = Window()) return window;
      if (WaitForSingleObject(process_.hProcess, 30) == WAIT_OBJECT_0) break;
    }
    throw std::runtime_error("companion fixture window did not start");
  }
  void ExpectExit(DWORD timeout) const {
    Require(WaitForSingleObject(process_.hProcess, timeout) == WAIT_OBJECT_0,
            "companion fixture did not exit promptly");
    DWORD code = 99;
    Require(GetExitCodeProcess(process_.hProcess, &code) && code == 0,
            "companion fixture exited unsuccessfully");
  }
 private:
  PROCESS_INFORMATION process_{};
};

void TestSingleInstance(const std::filesystem::path& path) {
  {
    TestCompanionProcess first(path);
    const auto window = first.WaitForWindow();
    ShowWindow(window, SW_MINIMIZE);
    {
      // Same file expressed through a different lexical path must activate it.
      TestCompanionProcess second(path.parent_path() / L"." / path.filename());
      second.ExpectExit(4000);
      Require(first.Window() == window && IsWindowVisible(window) && !IsIconic(window),
              "duplicate launch did not restore the existing companion");
      std::cout << "companion duplicate restore passed; foreground="
                << (GetForegroundWindow() == window ? "yes" : "desktop restricted") << '\n';
    }
    PostMessageW(window, WM_CLOSE, 0, 0);
    first.ExpectExit(2000);
  }
  // Guard objects must release their handles after normal shutdown.
  TestCompanionProcess restarted(path);
  const auto window = restarted.WaitForWindow();
  PostMessageW(window, WM_CLOSE, 0, 0);
  restarted.ExpectExit(2000);
  std::cout << "companion instance restart and normal exit passed\n";
}

}  // namespace
