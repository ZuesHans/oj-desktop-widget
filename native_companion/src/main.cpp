#include "browser_import.hpp"
#include "problem_database.hpp"
#include "resource.h"
#include "single_instance.hpp"

#include <commctrl.h>
#include <commdlg.h>
#include <uxtheme.h>
#include <fstream>
#include <set>
#include <objbase.h>
#include <shellapi.h>
#include <shlobj.h>
#include <windowsx.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <filesystem>
#include <iomanip>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

using oj_companion::ProblemDatabase;
using oj_companion::ProblemRecord;
using oj_companion::BrowserImportServer;
using oj_companion::Utf8ToWide;
using oj_companion::WideToUtf8;

constexpr wchar_t kWindowClass[] = L"OjProblemCompanionWindow";
constexpr UINT_PTR kRefreshTimer = 1;
constexpr UINT kRefreshIntervalMs = 1000;

enum ControlId {
  kDatabasePath = 100,
  kProblemList,
  kNewButton,
  kSaveButton,
  kDeleteButton,
  kOpenButton,
  kRefreshButton,
  kTitleEdit,
  kUrlEdit,
  kPlatformCombo,
  kStatusCombo,
  kTagsEdit,
  kFolderEdit,
  kFolderFilter,
  kNoteEdit,
  kStatusText,
  kFolderName, kCreateFolder, kTagFilter, kTagMatchAll,
  kBatchOperation, kBatchValue, kBatchApply, kBatchExport, kAnalysisEdit,
};

const std::array<const char*, 10> kPlatforms = {
    "cf", "atcoder", "hd",  "lg",   "poj",
    "uva", "nc",      "spoj", "lccn", "other",
};
const std::array<const char*, 5> kStatuses = {
    "backlog", "active", "review", "mastered", "archived",
};

struct DatabaseSelection {
  std::filesystem::path path;
  bool custom = false;
};

std::wstring WindowText(HWND window) {
  const int length = GetWindowTextLengthW(window);
  std::wstring value(static_cast<size_t>(length) + 1, L'\0');
  if (length > 0) {
    GetWindowTextW(window, value.data(), length + 1);
  }
  value.resize(static_cast<size_t>(length));
  return value;
}

void SetWindowTextUtf8(HWND window, const std::string& value) {
  const auto wide = Utf8ToWide(value);
  SetWindowTextW(window, wide.c_str());
}

std::string Trim(std::string value) {
  const auto first = value.find_first_not_of(" \t\r\n");
  if (first == std::string::npos) {
    return {};
  }
  const auto last = value.find_last_not_of(" \t\r\n");
  return value.substr(first, last - first + 1);
}

std::string JsonEscape(const std::string& value) {
  std::string result;
  result.reserve(value.size() + 4);
  for (const unsigned char character : value) {
    switch (character) {
      case '"':
        result += "\\\"";
        break;
      case '\\':
        result += "\\\\";
        break;
      case '\b':
        result += "\\b";
        break;
      case '\f':
        result += "\\f";
        break;
      case '\n':
        result += "\\n";
        break;
      case '\r':
        result += "\\r";
        break;
      case '\t':
        result += "\\t";
        break;
      default:
        if (character < 0x20) {
          std::ostringstream escaped;
          escaped << "\\u" << std::hex << std::setw(4) << std::setfill('0')
                  << static_cast<int>(character);
          result += escaped.str();
        } else {
          result.push_back(static_cast<char>(character));
        }
    }
  }
  return result;
}

std::string TagsToJson(const std::string& text) {
  std::vector<std::string> tags;
  size_t start = 0;
  while (start <= text.size()) {
    const size_t end = text.find(',', start);
    const std::string tag =
        Trim(text.substr(start, end == std::string::npos ? std::string::npos
                                                         : end - start));
    if (!tag.empty() && std::find(tags.begin(), tags.end(), tag) == tags.end()) {
      tags.push_back(tag);
    }
    if (end == std::string::npos) {
      break;
    }
    start = end + 1;
  }
  std::string json = "[";
  for (size_t index = 0; index < tags.size(); ++index) {
    if (index > 0) {
      json += ',';
    }
    json += '"' + JsonEscape(tags[index]) + '"';
  }
  return json + ']';
}

std::string JsonToTags(const std::string& json) {
  const auto tags = oj_companion::ParseProblemTagsJson(json);
  std::string result;
  for (size_t tag_index = 0; tag_index < tags.size(); ++tag_index) {
    if (tag_index > 0) {
      result += ", ";
    }
    result += tags[tag_index];
  }
  return result;
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
  return "native-" + WideToUtf8(value);
}

std::filesystem::path DefaultDatabasePath() {
  PWSTR roaming_path = nullptr;
  const HRESULT result = SHGetKnownFolderPath(FOLDERID_RoamingAppData, 0,
                                               nullptr, &roaming_path);
  if (FAILED(result)) {
    throw std::runtime_error("Unable to locate the roaming AppData directory.");
  }
  std::filesystem::path path(roaming_path);
  CoTaskMemFree(roaming_path);
  return path / L"ZuesHans" / L"OJ Float" / L"problem_book.sqlite3";
}

std::filesystem::path ExecutableDirectory() {
  std::array<wchar_t, 32768> buffer{};
  const DWORD length = GetModuleFileNameW(
      nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
  if (length == 0 || length == buffer.size()) {
    throw std::runtime_error("无法定位题库小程序所在目录。");
  }
  return std::filesystem::path(std::wstring(buffer.data(), length)).parent_path();
}

DatabaseSelection DatabasePathFromCommandLine() {
  int argument_count = 0;
  LPWSTR* arguments = CommandLineToArgvW(GetCommandLineW(), &argument_count);
  if (arguments == nullptr) {
    return {DefaultDatabasePath(), false};
  }
  DatabaseSelection selection{DefaultDatabasePath(), false};
  for (int index = 1; index + 1 < argument_count; ++index) {
    if (std::wstring(arguments[index]) == L"--database") {
      selection.path = arguments[index + 1];
      selection.custom = true;
      break;
    }
  }
  LocalFree(arguments);
  return selection;
}

std::filesystem::path FindFlutterClient() {
  const auto executable_directory = ExecutableDirectory();
  const auto packaged = executable_directory / L"oj_float.exe";
  if (std::filesystem::exists(packaged)) {
    return packaged;
  }
  const auto build_root = executable_directory.parent_path().parent_path();
  const auto development =
      build_root / L"windows" / L"x64" / L"runner" / L"Release" /
      L"oj_float.exe";
  return std::filesystem::exists(development) ? development
                                              : std::filesystem::path();
}

void MigrateDefaultDatabase(const std::filesystem::path& database_path) {
  if (std::filesystem::exists(database_path)) {
    try {
      oj_companion::ProblemDatabase verified(database_path);
      return;
    } catch (const std::exception&) {
      // Flutter owns schema and legacy migration. A file's existence does not
      // establish that either completed successfully.
    }
  }
  const auto flutter_client = FindFlutterClient();
  if (flutter_client.empty()) {
    throw std::runtime_error(
        "尚未生成题库数据库，也未找到 oj_float.exe。请把两个程序放在同一目录，"
        "或先运行一次新版 Flutter 主程序。");
  }

  std::wstring command = L"\"" + flutter_client.wstring() +
                         L"\" --migrate-problem-database-and-exit";
  std::vector<wchar_t> mutable_command(command.begin(), command.end());
  mutable_command.push_back(L'\0');
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESHOWWINDOW;
  startup.wShowWindow = SW_HIDE;
  PROCESS_INFORMATION process{};
  if (!CreateProcessW(flutter_client.c_str(), mutable_command.data(), nullptr,
                      nullptr, FALSE, 0, nullptr,
                      flutter_client.parent_path().c_str(), &startup,
                      &process)) {
    throw std::runtime_error("无法启动主程序执行题库迁移。");
  }
  CloseHandle(process.hThread);

  const DWORD wait_result = WaitForSingleObject(process.hProcess, 30000);
  DWORD exit_code = EXIT_FAILURE;
  const bool completed = wait_result == WAIT_OBJECT_0 &&
      GetExitCodeProcess(process.hProcess, &exit_code) && exit_code == 0;
  CloseHandle(process.hProcess);
  if (!completed) {
    throw std::runtime_error(
        wait_result == WAIT_TIMEOUT
            ? "题库迁移仍在进行，小程序不会打开中间数据。请稍后重试或打开主程序检查。"
            : "主程序未能完成题库迁移。原始数据已保留，请打开主程序修复或恢复备份。");
  }
  oj_companion::ProblemDatabase verified(database_path);
}

class Application {
 public:
  explicit Application(std::filesystem::path database_path)
      : database_path_(std::move(database_path)),
        database_(database_path_),
        browser_import_server_(database_path_) {}

  bool Create(HINSTANCE instance, int show_command,
              const oj_companion::SingleInstance& single_instance) {
    WNDCLASSEXW window_class{};
    window_class.cbSize = sizeof(window_class);
    window_class.lpfnWndProc = WindowProcedure;
    window_class.hInstance = instance;
    window_class.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    HICON application_icon = static_cast<HICON>(LoadImageW(
        instance, MAKEINTRESOURCEW(IDI_OJ_PROBLEM_COMPANION), IMAGE_ICON, 0, 0,
        LR_DEFAULTSIZE | LR_SHARED));
    if (application_icon == nullptr) {
      application_icon = LoadIconW(nullptr, IDI_APPLICATION);
    }
    window_class.hIcon = application_icon;
    window_class.hIconSm = application_icon;
    window_class.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    window_class.lpszClassName = kWindowClass;
    if (RegisterClassExW(&window_class) == 0) {
      return false;
    }

    window_ = CreateWindowExW(
        0, kWindowClass, L"OJ 题库小程序", WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 1180, 760, nullptr, nullptr, instance, this);
    if (window_ == nullptr) {
      return false;
    }
    ShowWindow(window_, show_command);
    UpdateWindow(window_);
    single_instance.Publish(window_);
    return true;
  }

 private:
  static LRESULT CALLBACK WindowProcedure(HWND window, UINT message,
                                           WPARAM w_parameter,
                                           LPARAM l_parameter) {
    Application* application = reinterpret_cast<Application*>(
        GetWindowLongPtrW(window, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
      const auto* create = reinterpret_cast<CREATESTRUCTW*>(l_parameter);
      application = static_cast<Application*>(create->lpCreateParams);
      application->window_ = window;
      SetWindowLongPtrW(window, GWLP_USERDATA,
                        reinterpret_cast<LONG_PTR>(application));
    }
    if (application == nullptr) {
      return DefWindowProcW(window, message, w_parameter, l_parameter);
    }
    try {
      return application->HandleMessage(message, w_parameter, l_parameter);
    } catch (const std::exception& error) {
      const auto wide = Utf8ToWide(error.what());
      MessageBoxW(window, wide.c_str(), L"OJ 题库小程序",
                  MB_OK | MB_ICONERROR);
      return message == WM_CREATE ? -1 : 0;
    }
  }

  LRESULT HandleMessage(UINT message, WPARAM w_parameter,
                        LPARAM l_parameter) {
    switch (message) {
      case WM_CREATE:
        CreateControls();
        ReloadProblems();
        try {
          browser_import_server_.Start();
          SetStatus("已加载 " + std::to_string(problems_.size()) +
                    " 道题；浏览器导入监听 127.0.0.1:" +
                    std::to_string(browser_import_server_.Port()));
        } catch (const std::exception& error) {
          SetStatus(std::string("浏览器导入服务未启动：") + error.what());
        }
        SetTimer(window_, kRefreshTimer, kRefreshIntervalMs, nullptr);
        return 0;
      case WM_SIZE:
        LayoutControls(LOWORD(l_parameter), HIWORD(l_parameter));
        return 0;
      case WM_GETMINMAXINFO: {
        auto* info = reinterpret_cast<MINMAXINFO*>(l_parameter);
        info->ptMinTrackSize = POINT{1000, 740};
        return 0;
      }
      case WM_TIMER:
        if (w_parameter == kRefreshTimer) {
          RefreshIfChanged();
        }
        return 0;
      case WM_COMMAND:
        HandleCommand(LOWORD(w_parameter), HIWORD(w_parameter));
        return 0;
      case WM_NOTIFY:
        HandleNotification(reinterpret_cast<NMHDR*>(l_parameter));
        return 0;
      case WM_CTLCOLORSTATIC:
      case WM_CTLCOLORBTN:
        SetTextColor(reinterpret_cast<HDC>(w_parameter), RGB(36, 58, 56));
        SetBkColor(reinterpret_cast<HDC>(w_parameter), RGB(242, 247, 245));
        return reinterpret_cast<LRESULT>(background_brush_);
      case WM_DESTROY:
        if (ui_font_) DeleteObject(ui_font_);
        if (background_brush_) DeleteObject(background_brush_);
        KillTimer(window_, kRefreshTimer);
        browser_import_server_.Stop();
        PostQuitMessage(0);
        return 0;
      default:
        return DefWindowProcW(window_, message, w_parameter, l_parameter);
    }
  }

  HWND CreateControl(const wchar_t* class_name, const wchar_t* text,
                     DWORD style, int id, DWORD extended_style = 0) {
    HWND control = CreateWindowExW(
        extended_style, class_name, text, WS_CHILD | WS_VISIBLE | style, 0, 0,
        0, 0, window_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),
        GetModuleHandleW(nullptr), nullptr);
    SendMessageW(control, WM_SETFONT,
                 reinterpret_cast<WPARAM>(ui_font_ ? ui_font_ : GetStockObject(DEFAULT_GUI_FONT)),
                 TRUE);
    return control;
  }

  void CreateControls() {
    background_brush_ = CreateSolidBrush(RGB(242, 247, 245));
    SetClassLongPtrW(window_, GCLP_HBRBACKGROUND, reinterpret_cast<LONG_PTR>(background_brush_));
    ui_font_ = CreateFontW(-16, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
      DEFAULT_PITCH, L"Microsoft YaHei UI");
    folder_name_ = CreateControl(L"EDIT", L"", ES_AUTOHSCROLL, kFolderName, WS_EX_CLIENTEDGE);
    SendMessageW(folder_name_, EM_SETCUEBANNER, TRUE, reinterpret_cast<LPARAM>(L"新文件夹名称"));
    create_folder_ = CreateControl(L"BUTTON", L"新建文件夹", BS_PUSHBUTTON, kCreateFolder);
    tag_filter_ = CreateControl(L"EDIT", L"", ES_AUTOHSCROLL, kTagFilter, WS_EX_CLIENTEDGE);
    SendMessageW(tag_filter_, EM_SETCUEBANNER, TRUE, reinterpret_cast<LPARAM>(L"筛选标签，逗号分隔"));
    tag_match_all_ = CreateControl(L"BUTTON", L"匹配全部标签", BS_AUTOCHECKBOX, kTagMatchAll);
    batch_operation_ = CreateControl(WC_COMBOBOXW, L"", CBS_DROPDOWNLIST | WS_VSCROLL, kBatchOperation, WS_EX_CLIENTEDGE);
    for (const auto* label : {L"移动到文件夹", L"添加标签", L"移除标签", L"修改状态", L"归档", L"恢复到待补"}) ComboBox_AddString(batch_operation_, label);
    ComboBox_SetCurSel(batch_operation_, 0);
    batch_value_ = CreateControl(L"EDIT", L"", ES_AUTOHSCROLL, kBatchValue, WS_EX_CLIENTEDGE);
    SendMessageW(batch_value_, EM_SETCUEBANNER, TRUE, reinterpret_cast<LPARAM>(L"文件夹 / 标签 / 状态英文名"));
    batch_apply_ = CreateControl(L"BUTTON", L"应用到勾选项", BS_PUSHBUTTON, kBatchApply);
    batch_export_ = CreateControl(L"BUTTON", L"导出勾选项", BS_PUSHBUTTON, kBatchExport);
    analysis_label_ = CreateControl(L"STATIC", L"题解", SS_LEFT, 0);
    analysis_edit_ = CreateControl(L"EDIT", L"", ES_MULTILINE | ES_AUTOVSCROLL | ES_WANTRETURN | WS_VSCROLL, kAnalysisEdit, WS_EX_CLIENTEDGE);
    folder_filter_label_ =
        CreateControl(L"STATIC", L"文件夹", SS_LEFT, 0);
    folder_filter_ = CreateControl(
        WC_COMBOBOXW, L"", CBS_DROPDOWNLIST | WS_VSCROLL, kFolderFilter,
        WS_EX_CLIENTEDGE);
    folder_label_ = CreateControl(L"STATIC", L"文件夹", SS_LEFT, 0);
    folder_edit_ = CreateControl(L"EDIT", L"", ES_AUTOHSCROLL, kFolderEdit,
                                 WS_EX_CLIENTEDGE);
    path_text_ = CreateControl(L"STATIC", L"", SS_LEFT, kDatabasePath);
    list_ = CreateControl(WC_LISTVIEWW, L"",
                          LVS_REPORT | LVS_SHOWSELALWAYS,
                          kProblemList, WS_EX_CLIENTEDGE);
    ListView_SetExtendedListViewStyle(
        list_, LVS_EX_FULLROWSELECT | LVS_EX_DOUBLEBUFFER | LVS_EX_CHECKBOXES);
    SetWindowTheme(list_, L"Explorer", nullptr);
    ListView_SetBkColor(list_, RGB(255, 255, 255));
    ListView_SetTextColor(list_, RGB(36, 58, 56));
    const std::array<std::pair<const wchar_t*, int>, 5> columns = {{
        {L"题目", 230},
        {L"平台", 65},
        {L"状态", 100},
        {L"标签 / 文件夹", 180},
        {L"更新时间", 180},
    }};
    for (size_t index = 0; index < columns.size(); ++index) {
      LVCOLUMNW column{};
      column.mask = LVCF_TEXT | LVCF_WIDTH;
      column.pszText = const_cast<wchar_t*>(columns[index].first);
      column.cx = columns[index].second;
      ListView_InsertColumn(list_, static_cast<int>(index), &column);
    }

    new_button_ = CreateControl(L"BUTTON", L"新建", BS_PUSHBUTTON, kNewButton);
    save_button_ =
        CreateControl(L"BUTTON", L"保存", BS_DEFPUSHBUTTON, kSaveButton);
    delete_button_ =
        CreateControl(L"BUTTON", L"删除", BS_PUSHBUTTON, kDeleteButton);
    open_button_ =
        CreateControl(L"BUTTON", L"打开链接", BS_PUSHBUTTON, kOpenButton);
    refresh_button_ =
        CreateControl(L"BUTTON", L"立即刷新", BS_PUSHBUTTON, kRefreshButton);

    title_label_ = CreateControl(L"STATIC", L"题目名称", SS_LEFT, 0);
    title_edit_ = CreateControl(L"EDIT", L"", ES_AUTOHSCROLL, kTitleEdit,
                                WS_EX_CLIENTEDGE);
    url_label_ = CreateControl(L"STATIC", L"题目链接", SS_LEFT, 0);
    url_edit_ = CreateControl(L"EDIT", L"", ES_AUTOHSCROLL, kUrlEdit,
                              WS_EX_CLIENTEDGE);
    platform_label_ = CreateControl(L"STATIC", L"平台", SS_LEFT, 0);
    platform_combo_ =
        CreateControl(WC_COMBOBOXW, L"", CBS_DROPDOWNLIST | WS_VSCROLL,
                      kPlatformCombo, WS_EX_CLIENTEDGE);
    for (const auto* platform : kPlatforms) {
      const auto value = Utf8ToWide(platform);
      ComboBox_AddString(platform_combo_, value.c_str());
    }
    status_label_ = CreateControl(L"STATIC", L"状态", SS_LEFT, 0);
    status_combo_ =
        CreateControl(WC_COMBOBOXW, L"", CBS_DROPDOWNLIST | WS_VSCROLL,
                      kStatusCombo, WS_EX_CLIENTEDGE);
    for (const auto* status : kStatuses) {
      const auto value = Utf8ToWide(status);
      ComboBox_AddString(status_combo_, value.c_str());
    }
    tags_label_ = CreateControl(L"STATIC", L"标签（逗号分隔）", SS_LEFT, 0);
    tags_edit_ = CreateControl(L"EDIT", L"", ES_AUTOHSCROLL, kTagsEdit,
                               WS_EX_CLIENTEDGE);
    note_label_ = CreateControl(L"STATIC", L"备注", SS_LEFT, 0);
    note_edit_ = CreateControl(
        L"EDIT", L"", ES_MULTILINE | ES_AUTOVSCROLL | ES_WANTRETURN |
                           WS_VSCROLL,
        kNoteEdit, WS_EX_CLIENTEDGE);
    status_text_ =
        CreateControl(L"STATIC", L"准备就绪", SS_LEFT, kStatusText);

    const auto path_label = L"数据库：" + database_path_.wstring();
    SetWindowTextW(path_text_, path_label.c_str());
    ClearEditor();
  }

  void LayoutControls(int width, int height) {
    constexpr int margin = 16;
    const int content_width = std::max(1, width - margin * 2);
    MoveWindow(path_text_, margin, 10, content_width, 22, TRUE);
    int x = margin;
    for (HWND button : {new_button_, save_button_, delete_button_, open_button_, refresh_button_}) {
      MoveWindow(button, x, 40, 88, 32, TRUE); x += 96;
    }
    MoveWindow(folder_name_, x + 8, 42, 170, 28, TRUE);
    MoveWindow(create_folder_, x + 186, 40, 110, 32, TRUE);
    MoveWindow(folder_filter_label_, margin, 89, 60, 22, TRUE);
    MoveWindow(folder_filter_, margin + 62, 84, 210, 250, TRUE);
    MoveWindow(tag_filter_, margin + 284, 84, 250, 28, TRUE);
    MoveWindow(tag_match_all_, margin + 548, 84, 150, 28, TRUE);
    MoveWindow(batch_operation_, margin, 128, 150, 240, TRUE);
    MoveWindow(batch_value_, margin + 160, 128, 290, 28, TRUE);
    MoveWindow(batch_apply_, margin + 462, 126, 132, 32, TRUE);
    MoveWindow(batch_export_, margin + 604, 126, 122, 32, TRUE);
    const int list_top = 174;
    const int pane_height = std::max(320, height - list_top - 44);
    const int left_width = content_width * 56 / 100;
    MoveWindow(list_, margin, list_top, left_width, pane_height, TRUE);
    const int edit_x = margin + left_width + 20;
    const int edit_width = content_width - left_width - 20;
    int y = list_top;
    auto field = [&](HWND label, HWND edit, int field_height) {
      MoveWindow(label, edit_x, y, edit_width, 22, TRUE); y += 25;
      MoveWindow(edit, edit_x, y, edit_width, field_height, TRUE); y += field_height + 12;
    };
    field(title_label_, title_edit_, 28);
    field(url_label_, url_edit_, 28);
    const int half = (edit_width - 12) / 2;
    MoveWindow(platform_label_, edit_x, y, half, 22, TRUE);
    MoveWindow(status_label_, edit_x + half + 12, y, half, 22, TRUE); y += 25;
    MoveWindow(platform_combo_, edit_x, y, half, 220, TRUE);
    MoveWindow(status_combo_, edit_x + half + 12, y, half, 220, TRUE); y += 42;
    field(tags_label_, tags_edit_, 28);
    field(folder_label_, folder_edit_, 28);
    const int note_height = std::max(44, (height - y - 118) / 2);
    field(note_label_, note_edit_, note_height);
    field(analysis_label_, analysis_edit_, std::max(44, height - y - 66));
    MoveWindow(status_text_, margin, height - 28, content_width, 24, TRUE);
  }

  void HandleCommand(int id, int notification) {
    if (!loading_editor_ &&
        ((id == kTitleEdit || id == kUrlEdit || id == kTagsEdit ||
          id == kFolderEdit ||
          id == kNoteEdit || id == kAnalysisEdit) &&
         notification == EN_CHANGE)) {
      editor_dirty_ = true;
      return;
    }
    if ((id == kTagFilter && notification == EN_CHANGE) || (id == kTagMatchAll && notification == BN_CLICKED)) {
      if (!reloading_list_) ReloadProblems();
      return;
    }
    if (id == kFolderFilter && notification == CBN_SELCHANGE) {
      if (!reloading_list_) {
        ReloadProblems();
      }
      return;
    }
    if (!loading_editor_ &&
        (id == kPlatformCombo || id == kStatusCombo) &&
        notification == CBN_SELCHANGE) {
      editor_dirty_ = true;
      return;
    }
    if (notification != BN_CLICKED) {
      return;
    }
    try {
      switch (id) {
        case kCreateFolder: {
          const auto name = Trim(WideToUtf8(WindowText(folder_name_)));
          if (name.empty()) throw std::runtime_error("请输入文件夹名称。");
          database_.CreateFolder(name);
          SetWindowTextW(folder_name_, L"");
          ReloadProblems();
          SetStatus("已创建文件夹：" + name);
          break;
        }
        case kBatchApply: ApplyBatch(); break;
        case kBatchExport: ExportSelected(); break;
        case kNewButton:
          ListView_SetItemState(list_, -1, 0, LVIS_SELECTED);
          ClearEditor();
          break;
        case kSaveButton:
          SaveEditor();
          break;
        case kDeleteButton:
          DeleteSelected();
          break;
        case kOpenButton:
          OpenSelectedUrl();
          break;
        case kRefreshButton:
          ReloadProblems();
          break;
        default:
          break;
      }
    } catch (const std::exception& error) {
      ShowError(error.what());
    }
  }

  void HandleNotification(NMHDR* header) {
    if (reloading_list_ || header->hwndFrom != list_ ||
        header->code != LVN_ITEMCHANGED) {
      return;
    }
    const auto* change = reinterpret_cast<NMLISTVIEW*>(header);
    if ((change->uNewState & LVIS_SELECTED) == 0 || change->iItem < 0 ||
        static_cast<size_t>(change->iItem) >= displayed_problems_.size()) {
      return;
    }
    if (!editor_dirty_) LoadEditor(displayed_problems_[static_cast<size_t>(change->iItem)]);
  }

  void ReloadProblems() {
    const auto checked = CheckedIds();
    const std::string preserved_id = selected_id_;
    const bool preserve_dirty_editor = editor_dirty_;
    const std::string preserved_folder_filter = FolderFilterValue();
    // Read revision first: a racing write causes another refresh instead of
    // marking an older list as current.
    known_revision_ = database_.Revision();
    problems_ = database_.LoadProblems();
    reloading_list_ = true;
    PopulateFolderFilter(preserved_folder_filter);
    ListView_DeleteAllItems(list_);
    displayed_problems_.clear();
    int selected_index = -1;
    for (const auto& problem : problems_) {
      if (!MatchesFolderFilter(problem) || !MatchesTags(problem)) {
        continue;
      }
      displayed_problems_.push_back(problem);
      const size_t index = displayed_problems_.size() - 1;
      const auto title = Utf8ToWide(problem.title);
      LVITEMW item{};
      item.mask = LVIF_TEXT;
      item.iItem = static_cast<int>(index);
      item.pszText = const_cast<wchar_t*>(title.c_str());
      ListView_InsertItem(list_, &item);
      if (std::find(checked.begin(), checked.end(), problem.id) != checked.end()) ListView_SetCheckState(list_, static_cast<int>(index), TRUE);
      SetListText(static_cast<int>(index), 1, problem.platform);
      SetListText(static_cast<int>(index), 2, problem.workflow_status);
      SetListText(
          static_cast<int>(index), 3,
          problem.folder.empty()
              ? JsonToTags(problem.tags_json)
              : "Folder: " + problem.folder + " | " +
                    JsonToTags(problem.tags_json));
      SetListText(static_cast<int>(index), 4, problem.updated_at);
      if (problem.id == preserved_id) {
        selected_index = static_cast<int>(index);
      }
    }
    if (selected_index >= 0) {
      ListView_SetItemState(list_, selected_index,
                            LVIS_SELECTED | LVIS_FOCUSED,
                            LVIS_SELECTED | LVIS_FOCUSED);
      ListView_EnsureVisible(list_, selected_index, FALSE);
      if (!preserve_dirty_editor) {
        LoadEditor(displayed_problems_[static_cast<size_t>(selected_index)]);
      }
    } else if (!preserved_id.empty() && !preserve_dirty_editor) {
      ClearEditor();
    }
    reloading_list_ = false;
    std::string status =
        "已加载 " + std::to_string(problems_.size()) + " 道题；修订号 " +
        std::to_string(known_revision_) + "；勾选题目可批量操作";
    if (browser_import_server_.IsRunning()) {
      status += "；浏览器导入 127.0.0.1:" +
                std::to_string(browser_import_server_.Port());
    }
    SetStatus(status);
  }

  void RefreshIfChanged() {
    try {
      if (database_.Revision() != known_revision_) {
        ReloadProblems();
      }
    } catch (const std::exception& error) {
      SetStatus(std::string("自动刷新失败：") + error.what());
    }
  }

  void SaveEditor() {
    const std::string title = Trim(WideToUtf8(WindowText(title_edit_)));
    const std::string url = Trim(WideToUtf8(WindowText(url_edit_)));
    if (title.empty() || url.empty()) {
      throw std::runtime_error("题目名称和链接不能为空。");
    }

    ProblemRecord problem;
    const auto existing = std::find_if(
        problems_.begin(), problems_.end(),
        [&](const ProblemRecord& item) { return item.id == selected_id_; });
    if (existing != problems_.end()) {
      problem = *existing;
    } else {
      problem.id = NewProblemId();
      problem.created_at = UtcNowIso8601();
      problem.date = Today();
    }
    problem.title = title;
    problem.url = url;
    problem.platform = ComboValue(platform_combo_, kPlatforms, "other");
    problem.workflow_status =
        ComboValue(status_combo_, kStatuses, "backlog");
    problem.tags_json = TagsToJson(WideToUtf8(WindowText(tags_edit_)));
    problem.folder = Trim(WideToUtf8(WindowText(folder_edit_)));
    problem.note = WideToUtf8(WindowText(note_edit_));
    problem.analysis = WideToUtf8(WindowText(analysis_edit_));
    problem.updated_at = UtcNowIso8601();
    if (problem.workflow_status == "archived" && problem.archived_at.empty()) {
      problem.archived_at = problem.updated_at;
    } else if (problem.workflow_status != "archived") {
      problem.archived_at.clear();
    }
    selected_id_ = problem.id;
    database_.Upsert(problem);
    editor_dirty_ = false;
    ReloadProblems();
    SetStatus("已保存：" + problem.title);
  }

  void DeleteSelected() {
    if (selected_id_.empty()) {
      throw std::runtime_error("请先选择要删除的题目。");
    }
    if (MessageBoxW(window_, L"确定永久删除这道题吗？", L"确认删除",
                    MB_ICONWARNING | MB_YESNO | MB_DEFBUTTON2) != IDYES) {
      return;
    }
    database_.Delete(selected_id_);
    selected_id_.clear();
    ClearEditor();
    ReloadProblems();
    SetStatus("题目已删除。");
  }

  void OpenSelectedUrl() {
    const std::string url = Trim(WideToUtf8(WindowText(url_edit_)));
    if (url.empty()) {
      throw std::runtime_error("当前题目没有链接。");
    }
    const auto wide_url = Utf8ToWide(url);
    const auto result = reinterpret_cast<INT_PTR>(ShellExecuteW(
        window_, L"open", wide_url.c_str(), nullptr, nullptr, SW_SHOWNORMAL));
    if (result <= 32) {
      throw std::runtime_error("无法使用默认浏览器打开题目链接。");
    }
  }

  void ClearEditor() {
    loading_editor_ = true;
    selected_id_.clear();
    SetWindowTextW(title_edit_, L"");
    SetWindowTextW(url_edit_, L"");
    SetWindowTextW(tags_edit_, L"");
    SetWindowTextW(folder_edit_, L"");
    SetWindowTextW(note_edit_, L"");
    SetWindowTextW(analysis_edit_, L"");
    ComboBox_SetCurSel(platform_combo_, static_cast<int>(kPlatforms.size() - 1));
    ComboBox_SetCurSel(status_combo_, 0);
    loading_editor_ = false;
    editor_dirty_ = false;
    SetFocus(title_edit_);
  }

  void LoadEditor(const ProblemRecord& problem) {
    loading_editor_ = true;
    selected_id_ = problem.id;
    SetWindowTextUtf8(title_edit_, problem.title);
    SetWindowTextUtf8(url_edit_, problem.url);
    SetWindowTextUtf8(tags_edit_, JsonToTags(problem.tags_json));
    SetWindowTextUtf8(folder_edit_, problem.folder);
    SetWindowTextUtf8(note_edit_, problem.note);
    SetWindowTextUtf8(analysis_edit_, problem.analysis);
    SelectCombo(platform_combo_, kPlatforms, problem.platform);
    SelectCombo(status_combo_, kStatuses, problem.workflow_status);
    loading_editor_ = false;
    editor_dirty_ = false;
    SetStatus("正在编辑：" + problem.title);
  }

  template <size_t Size>
  static std::string ComboValue(HWND combo,
                                const std::array<const char*, Size>& values,
                                const char* fallback) {
    const int index = ComboBox_GetCurSel(combo);
    return index >= 0 && static_cast<size_t>(index) < values.size()
               ? values[static_cast<size_t>(index)]
               : fallback;
  }

  template <size_t Size>
  static void SelectCombo(HWND combo,
                          const std::array<const char*, Size>& values,
                          const std::string& value) {
    const auto found = std::find_if(values.begin(), values.end(),
                                    [&](const char* item) {
                                      return value == item;
                                    });
    ComboBox_SetCurSel(combo, found == values.end()
                                 ? static_cast<int>(values.size() - 1)
                                 : static_cast<int>(found - values.begin()));
  }

  std::string FolderFilterValue() const {
    const int index = ComboBox_GetCurSel(folder_filter_);
    return index <= 0 ? std::string() : index == 1 ? "unclassified:" : "folder:" + Trim(WideToUtf8(WindowText(folder_filter_)));
  }

  bool MatchesFolderFilter(const ProblemRecord& problem) const {
    const int index = ComboBox_GetCurSel(folder_filter_);
    if (index == 1) return problem.folder.empty();
    const auto filter = FolderFilterValue();
    return index <= 0 || _wcsicmp(Utf8ToWide(problem.folder).c_str(), Utf8ToWide(filter.substr(7)).c_str()) == 0;
  }

  void PopulateFolderFilter(const std::string& selected) {
    ComboBox_ResetContent(folder_filter_);
    const auto all_folders = Utf8ToWide("全部文件夹");
    ComboBox_AddString(folder_filter_, all_folders.c_str());
    ComboBox_AddString(folder_filter_, L"未分类");
    const auto folders = database_.LoadFolders();
    int selected_index = selected == "unclassified:" ? 1 : 0;
    for (const auto& folder : folders) {
      const auto value = Utf8ToWide(folder);
      const int index = ComboBox_AddString(folder_filter_, value.c_str());
      if ("folder:" + folder == selected) {
        selected_index = index;
      }
    }
    ComboBox_SetCurSel(folder_filter_, selected_index);
  }

  bool MatchesTags(const ProblemRecord& problem) const {
    const auto query = TagsToJson(WideToUtf8(WindowText(tag_filter_)));
    const auto requested = oj_companion::ParseProblemTagsJson(query);
    if (requested.empty()) return true;
    const auto actual = oj_companion::ParseProblemTagsJson(problem.tags_json);
    int matched = 0;
    for (const auto& tag : requested) {
      if (std::any_of(actual.begin(), actual.end(), [&](const auto& item) {
        return _wcsicmp(Utf8ToWide(tag).c_str(), Utf8ToWide(item).c_str()) == 0;
      })) ++matched;
    }
    return Button_GetCheck(tag_match_all_) == BST_CHECKED ? matched == static_cast<int>(requested.size()) : matched > 0;
  }

  std::vector<std::string> CheckedIds() const {
    std::vector<std::string> ids;
    for (size_t i = 0; i < displayed_problems_.size(); ++i) {
      if (ListView_GetCheckState(list_, static_cast<int>(i))) ids.push_back(displayed_problems_[i].id);
    }
    return ids;
  }

  void ApplyBatch() {
    const auto ids = CheckedIds();
    if (ids.empty()) throw std::runtime_error("请先勾选题目。");
    if (editor_dirty_) throw std::runtime_error("请先保存当前编辑，再批量操作。");
    const int index = ComboBox_GetCurSel(batch_operation_);
    auto value = Trim(WideToUtf8(WindowText(batch_value_)));
    auto operation = oj_companion::BatchOperation::folder;
    if (index == 1 || index == 2) {
      operation = index == 1 ? oj_companion::BatchOperation::add_tags : oj_companion::BatchOperation::remove_tags;
      value = TagsToJson(value);
    } else if (index >= 3) {
      operation = oj_companion::BatchOperation::status;
      if (index == 4) value = "archived";
      if (index == 5) value = "backlog";
    }
    if (index == 4 && MessageBoxW(window_, L"归档勾选题目？之后可以恢复。", L"批量归档", MB_YESNO | MB_DEFBUTTON2) != IDYES) return;
    database_.ApplyBatch(ids, operation, value, UtcNowIso8601());
    ReloadProblems();
    SetStatus("已更新 " + std::to_string(ids.size()) + " 道题。");
  }

  void ExportSelected() {
    const auto ids = CheckedIds();
    if (ids.empty()) throw std::runtime_error("请先勾选要导出的题目。");
    std::array<wchar_t, 32768> path{};
    wcscpy_s(path.data(), path.size(), L"oj-problems.md");
    OPENFILENAMEW dialog{};
    dialog.lStructSize = sizeof(dialog); dialog.hwndOwner = window_;
    dialog.lpstrFilter = L"Markdown (*.md)\0*.md\0\0";
    dialog.lpstrFile = path.data(); dialog.nMaxFile = static_cast<DWORD>(path.size());
    dialog.lpstrDefExt = L"md"; dialog.Flags = OFN_OVERWRITEPROMPT | OFN_PATHMUSTEXIST;
    if (!GetSaveFileNameW(&dialog)) return;
    std::ofstream output(std::filesystem::path(path.data()), std::ios::binary);
    output << "# OJ 题库导出\n\n";
    for (const auto& problem : database_.LoadProblems()) {
      if (std::find(ids.begin(), ids.end(), problem.id) == ids.end()) continue;
      output << "## [" << problem.title << "](" << problem.url << ")\n\n- 平台：" << problem.platform
        << "\n- 状态：" << problem.workflow_status << "\n- 文件夹：" << problem.folder
        << "\n- 标签：" << JsonToTags(problem.tags_json) << "\n\n### 备注\n" << problem.note << "\n\n### 题解\n" << problem.analysis << "\n\n---\n";
    }
    output.flush();
    if (!output) throw std::runtime_error("导出失败，文件无法写入。");
    SetStatus("已导出 " + std::to_string(ids.size()) + " 道题。");
  }

  void SetListText(int row, int column, const std::string& value) {
    auto wide = Utf8ToWide(value);
    ListView_SetItemText(list_, row, column, wide.data());
  }

  void SetStatus(const std::string& value) {
    SetWindowTextUtf8(status_text_, value);
  }

  void ShowError(const std::string& value) {
    const auto wide = Utf8ToWide(value);
    MessageBoxW(window_, wide.c_str(), L"OJ 题库小程序", MB_OK | MB_ICONERROR);
    SetStatus("操作失败：" + value);
  }

  std::filesystem::path database_path_;
  ProblemDatabase database_;
  BrowserImportServer browser_import_server_;
  HWND window_ = nullptr;
  HWND path_text_ = nullptr;
  HWND list_ = nullptr;
  HWND new_button_ = nullptr;
  HWND save_button_ = nullptr;
  HWND delete_button_ = nullptr;
  HWND open_button_ = nullptr;
  HWND refresh_button_ = nullptr;
  HWND folder_filter_label_ = nullptr;
  HWND folder_filter_ = nullptr;
  HWND title_label_ = nullptr;
  HWND title_edit_ = nullptr;
  HWND url_label_ = nullptr;
  HWND url_edit_ = nullptr;
  HWND platform_label_ = nullptr;
  HWND platform_combo_ = nullptr;
  HWND status_label_ = nullptr;
  HWND status_combo_ = nullptr;
  HWND tags_label_ = nullptr;
  HWND tags_edit_ = nullptr;
  HWND folder_label_ = nullptr;
  HWND folder_edit_ = nullptr;
  HWND note_label_ = nullptr;
  HWND note_edit_ = nullptr;
  HWND status_text_ = nullptr;
  HFONT ui_font_ = nullptr;
  HBRUSH background_brush_ = nullptr;
  HWND folder_name_ = nullptr, create_folder_ = nullptr;
  HWND tag_filter_ = nullptr, tag_match_all_ = nullptr;
  HWND batch_operation_ = nullptr, batch_value_ = nullptr, batch_apply_ = nullptr, batch_export_ = nullptr;
  HWND analysis_label_ = nullptr, analysis_edit_ = nullptr;
  std::vector<ProblemRecord> problems_;
  std::vector<ProblemRecord> displayed_problems_;
  std::string selected_id_;
  std::int64_t known_revision_ = -1;
  bool loading_editor_ = false;
  bool editor_dirty_ = false;
  bool reloading_list_ = false;
};

}  // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int show_command) {
  INITCOMMONCONTROLSEX controls{sizeof(controls), ICC_LISTVIEW_CLASSES};
  InitCommonControlsEx(&controls);
  const HRESULT com_result = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  try {
    const auto selection = DatabasePathFromCommandLine();
    oj_companion::SingleInstance single_instance(selection.path);
    if (single_instance.IsExisting()) {
      if (!single_instance.ActivateExisting()) {
        throw std::runtime_error("已有题库正在启动或未能完成启动，请稍后重试。");
      }
      if (SUCCEEDED(com_result)) CoUninitialize();
      return 0;
    }
    if (!selection.custom) {
      MigrateDefaultDatabase(selection.path);
    }
    Application application(selection.path);
    if (!application.Create(instance, show_command, single_instance)) {
      throw std::runtime_error("Unable to create the companion window.");
    }
    MSG message{};
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {
      TranslateMessage(&message);
      DispatchMessageW(&message);
    }
    if (SUCCEEDED(com_result)) {
      CoUninitialize();
    }
    return static_cast<int>(message.wParam);
  } catch (const std::exception& error) {
    const auto wide = Utf8ToWide(error.what());
    MessageBoxW(nullptr, wide.c_str(), L"OJ 题库小程序启动失败",
                MB_OK | MB_ICONERROR);
    if (SUCCEEDED(com_result)) {
      CoUninitialize();
    }
    return 1;
  }
}
