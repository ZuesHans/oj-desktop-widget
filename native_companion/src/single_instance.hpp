#pragma once

#include <windows.h>
#include <sddl.h>

#include <cwctype>
#include <cstdint>
#include <filesystem>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace oj_companion {

// One companion window per Windows user and canonical database path.
class SingleInstance {
 public:
  explicit SingleInstance(const std::filesystem::path& database) {
    auto path = std::filesystem::weakly_canonical(
        std::filesystem::absolute(database)).wstring();
    std::uint64_t hash = 14695981039346656037ULL;
    for (const auto value : path) {
      hash ^= static_cast<std::uint64_t>(std::towlower(value));
      hash *= 1099511628211ULL;
    }
    HANDLE token = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) {
      throw std::runtime_error("无法确定当前 Windows 用户。");
    }
    DWORD size = 0;
    GetTokenInformation(token, TokenUser, nullptr, 0, &size);
    std::vector<BYTE> data(size);
    const BOOL read = GetTokenInformation(token, TokenUser, data.data(), size, &size);
    CloseHandle(token);
    LPWSTR sid = nullptr;
    if (!read || !ConvertSidToStringSidW(
        reinterpret_cast<TOKEN_USER*>(data.data())->User.Sid, &sid)) {
      throw std::runtime_error("无法读取当前 Windows 用户标识。");
    }
    std::wostringstream name;
    name << L"Local\\OJFloat.Companion." << sid << L'.' << std::hex << hash;
    LocalFree(sid);
    identity_ = name.str();
    mutex_ = CreateMutexW(nullptr, FALSE, identity_.c_str());
    if (mutex_ == nullptr) throw std::runtime_error("无法创建题库单实例保护。");
    existing_ = GetLastError() == ERROR_ALREADY_EXISTS;
    ready_ = CreateEventW(nullptr, TRUE, FALSE, (identity_ + L".ready").c_str());
    if (ready_ == nullptr) {
      CloseHandle(mutex_);
      mutex_ = nullptr;
      throw std::runtime_error("无法创建题库启动通知。");
    }
  }

  ~SingleInstance() {
    if (!existing_ && ready_ != nullptr) SetEvent(ready_);
    if (ready_ != nullptr) CloseHandle(ready_);
    if (mutex_ != nullptr) CloseHandle(mutex_);
  }
  SingleInstance(const SingleInstance&) = delete;
  SingleInstance& operator=(const SingleInstance&) = delete;

  bool IsExisting() const { return existing_; }
  void Publish(HWND window) const {
    if (!SetPropW(window, identity_.c_str(), reinterpret_cast<HANDLE>(1))) {
      throw std::runtime_error("无法注册题库窗口标识。");
    }
    SetEvent(ready_);
  }

  bool ActivateExisting() const {
    if (WaitForSingleObject(ready_, 30000) != WAIT_OBJECT_0) return false;
    HWND window = nullptr;
    struct Search { const std::wstring* identity; HWND* window; } search{&identity_, &window};
    EnumWindows([](HWND candidate, LPARAM value) -> BOOL {
      auto& lookup = *reinterpret_cast<Search*>(value);
      if (GetPropW(candidate, lookup.identity->c_str()) != nullptr) {
        *lookup.window = candidate;
        return FALSE;
      }
      return TRUE;
    }, reinterpret_cast<LPARAM>(&search));
    if (window == nullptr) return false;
    DWORD process_id = 0;
    GetWindowThreadProcessId(window, &process_id);
    AllowSetForegroundWindow(process_id);
    ShowWindow(window, IsIconic(window) ? SW_RESTORE : SW_SHOW);
    SetForegroundWindow(window);
    return true;
  }

 private:
  std::wstring identity_;
  HANDLE mutex_ = nullptr;
  HANDLE ready_ = nullptr;
  bool existing_ = false;
};

}  // namespace oj_companion
