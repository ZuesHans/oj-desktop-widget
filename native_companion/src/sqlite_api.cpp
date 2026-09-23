#include "sqlite_api.hpp"

#include <array>
#include <sstream>

namespace oj_companion {
namespace {

std::filesystem::path ExecutableDirectory() {
  std::array<wchar_t, 32768> buffer{};
  const DWORD length = GetModuleFileNameW(
      nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
  if (length == 0 || length == buffer.size()) {
    throw std::runtime_error("Unable to locate the companion executable.");
  }
  return std::filesystem::path(std::wstring(buffer.data(), length)).parent_path();
}

template <typename Function>
Function Resolve(HMODULE module, const char* name) {
  const auto address = GetProcAddress(module, name);
  if (address == nullptr) {
    throw std::runtime_error(std::string("sqlite3.dll is missing symbol: ") +
                             name);
  }
  return reinterpret_cast<Function>(address);
}

}  // namespace

SqliteApi::SqliteApi() {
  const auto dll_path = ExecutableDirectory() / L"sqlite3.dll";
  module_ = LoadLibraryExW(dll_path.c_str(), nullptr,
                           LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR |
                               LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
  if (module_ == nullptr) {
    throw std::runtime_error(
        "oj_problem_companion.exe 旁边缺少 sqlite3.dll。");
  }

  try {
    open_v2 = Resolve<decltype(open_v2)>(module_, "sqlite3_open_v2");
    close_v2 = Resolve<decltype(close_v2)>(module_, "sqlite3_close_v2");
    errmsg = Resolve<decltype(errmsg)>(module_, "sqlite3_errmsg");
    busy_timeout =
        Resolve<decltype(busy_timeout)>(module_, "sqlite3_busy_timeout");
    exec = Resolve<decltype(exec)>(module_, "sqlite3_exec");
    free_memory = Resolve<decltype(free_memory)>(module_, "sqlite3_free");
    prepare_v2 = Resolve<decltype(prepare_v2)>(module_, "sqlite3_prepare_v2");
    step = Resolve<decltype(step)>(module_, "sqlite3_step");
    finalize = Resolve<decltype(finalize)>(module_, "sqlite3_finalize");
    reset = Resolve<decltype(reset)>(module_, "sqlite3_reset");
    clear_bindings =
        Resolve<decltype(clear_bindings)>(module_, "sqlite3_clear_bindings");
    bind_text = Resolve<decltype(bind_text)>(module_, "sqlite3_bind_text");
    bind_int = Resolve<decltype(bind_int)>(module_, "sqlite3_bind_int");
    bind_null = Resolve<decltype(bind_null)>(module_, "sqlite3_bind_null");
    column_text =
        Resolve<decltype(column_text)>(module_, "sqlite3_column_text");
    column_int = Resolve<decltype(column_int)>(module_, "sqlite3_column_int");
    column_int64 =
        Resolve<decltype(column_int64)>(module_, "sqlite3_column_int64");
    column_type =
        Resolve<decltype(column_type)>(module_, "sqlite3_column_type");
    changes = Resolve<decltype(changes)>(module_, "sqlite3_changes");
  } catch (...) {
    FreeLibrary(module_);
    module_ = nullptr;
    throw;
  }
}

SqliteApi::~SqliteApi() {
  if (module_ != nullptr) {
    FreeLibrary(module_);
  }
}

SqliteApi::Destructor SqliteApi::Transient() {
  return reinterpret_cast<Destructor>(static_cast<intptr_t>(-1));
}

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return {};
  }
  const int required = WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()),
      nullptr, 0, nullptr, nullptr);
  if (required <= 0) {
    throw std::runtime_error("Unable to encode a Windows path as UTF-8.");
  }
  std::string result(static_cast<size_t>(required), '\0');
  WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), result.data(), required,
                      nullptr, nullptr);
  return result;
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return {};
  }
  const int required = MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()),
      nullptr, 0);
  if (required <= 0) {
    return L"�";
  }
  std::wstring result(static_cast<size_t>(required), L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), result.data(), required);
  return result;
}

}  // namespace oj_companion
