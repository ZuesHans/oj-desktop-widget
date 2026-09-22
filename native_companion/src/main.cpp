#include "problem_database.hpp"

#include <commctrl.h>
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
  kNoteEdit,
  kStatusText,
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
  std::vector<std::string> tags;
  size_t index = 0;
  while (index < json.size()) {
    if (json[index++] != '"') {
      continue;
    }
    std::string value;
    while (index < json.size()) {
      const char character = json[index++];
      if (character == '"') {
        break;
      }
      if (character != '\\' || index >= json.size()) {
        value.push_back(character);
        continue;
      }
      const char escaped = json[index++];
      switch (escaped) {
        case 'n':
          value.push_back('\n');
          break;
        case 'r':
          value.push_back('\r');
          break;
        case 't':
          value.push_back('\t');
          break;
        case '"':
        case '\\':
        case '/':
          value.push_back(escaped);
          break;
        default:
          value.push_back(escaped);
      }
    }
    tags.push_back(std::move(value));
  }
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
  return path / L"com.example" / L"oj_float" / L"problem_book.sqlite3";
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
    return;
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

  constexpr int kMaximumWaitAttempts = 300;
  for (int attempt = 0; attempt < kMaximumWaitAttempts; ++attempt) {
    if (std::filesystem::exists(database_path)) {
      break;
    }
    if (WaitForSingleObject(process.hProcess, 100) == WAIT_OBJECT_0 &&
        !std::filesystem::exists(database_path)) {
      break;
    }
  }
  CloseHandle(process.hProcess);
  if (!std::filesystem::exists(database_path)) {
    throw std::runtime_error(
        "主程序未能生成题库数据库。请先手动运行一次最新版 oj_float.exe。");
  }
}

class Application {
 public:
  explicit Application(std::filesystem::path database_path)
      : database_path_(std::move(database_path)), database_(database_path_) {}

  bool Create(HINSTANCE instance, int show_command) {
    WNDCLASSEXW window_class{};
    window_class.cbSize = sizeof(window_class);
    window_class.lpfnWndProc = WindowProcedure;
    window_class.hInstance = instance;
    window_class.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    window_class.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
    window_class.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    window_class.lpszClassName = kWindowClass;
    if (RegisterClassExW(&window_class) == 0) {
      return false;
    }

    window_ = CreateWindowExW(
        0, kWindowClass, L"OJ 题库小程序", WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 980, 700, nullptr, nullptr, instance, this);
    if (window_ == nullptr) {
      return false;
    }
    ShowWindow(window_, show_command);
    UpdateWindow(window_);
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
        SetTimer(window_, kRefreshTimer, kRefreshIntervalMs, nullptr);
        return 0;
      case WM_SIZE:
        LayoutControls(LOWORD(l_parameter), HIWORD(l_parameter));
        return 0;
      case WM_GETMINMAXINFO: {
        auto* info = reinterpret_cast<MINMAXINFO*>(l_parameter);
        info->ptMinTrackSize = POINT{780, 570};
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
      case WM_DESTROY:
        KillTimer(window_, kRefreshTimer);
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
                 reinterpret_cast<WPARAM>(GetStockObject(DEFAULT_GUI_FONT)),
                 TRUE);
    return control;
  }

  void CreateControls() {
    path_text_ = CreateControl(L"STATIC", L"", SS_LEFT, kDatabasePath);
    list_ = CreateControl(WC_LISTVIEWW, L"",
                          LVS_REPORT | LVS_SINGLESEL | LVS_SHOWSELALWAYS,
                          kProblemList, WS_EX_CLIENTEDGE);
    ListView_SetExtendedListViewStyle(
        list_, LVS_EX_FULLROWSELECT | LVS_EX_DOUBLEBUFFER | LVS_EX_GRIDLINES);
    const std::array<std::pair<const wchar_t*, int>, 5> columns = {{
        {L"题目", 280},
        {L"平台", 90},
        {L"状态", 100},
        {L"标签", 220},
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
    constexpr int margin = 12;
    constexpr int gap = 8;
    constexpr int button_width = 88;
    constexpr int button_height = 30;
    constexpr int label_width = 105;
    const int content_width = std::max(1, width - margin * 2);

    MoveWindow(path_text_, margin, 10, content_width, 20, TRUE);
    int button_x = margin;
    for (HWND button : {new_button_, save_button_, delete_button_, open_button_,
                        refresh_button_}) {
      MoveWindow(button, button_x, 36, button_width, button_height, TRUE);
      button_x += button_width + gap;
    }

    const int editor_height = 206;
    const int status_height = 22;
    const int list_top = 74;
    const int list_height =
        std::max(120, height - list_top - editor_height - status_height - 18);
    MoveWindow(list_, margin, list_top, content_width, list_height, TRUE);

    int y = list_top + list_height + 10;
    const int edit_x = margin + label_width;
    const int edit_width = content_width - label_width;
    MoveWindow(title_label_, margin, y + 5, label_width - gap, 20, TRUE);
    MoveWindow(title_edit_, edit_x, y, edit_width, 26, TRUE);
    y += 34;
    MoveWindow(url_label_, margin, y + 5, label_width - gap, 20, TRUE);
    MoveWindow(url_edit_, edit_x, y, edit_width, 26, TRUE);
    y += 34;
    MoveWindow(platform_label_, margin, y + 5, 48, 20, TRUE);
    MoveWindow(platform_combo_, margin + 48, y, 115, 200, TRUE);
    MoveWindow(status_label_, margin + 175, y + 5, 42, 20, TRUE);
    MoveWindow(status_combo_, margin + 217, y, 120, 200, TRUE);
    MoveWindow(tags_label_, margin + 350, y + 5, 118, 20, TRUE);
    MoveWindow(tags_edit_, margin + 468, y,
               std::max(80, content_width - 468), 26, TRUE);
    y += 34;
    MoveWindow(note_label_, margin, y + 5, label_width - gap, 20, TRUE);
    MoveWindow(note_edit_, edit_x, y, edit_width, 58, TRUE);
    MoveWindow(status_text_, margin, height - status_height - 4, content_width,
               status_height, TRUE);
  }

  void HandleCommand(int id, int notification) {
    if (!loading_editor_ &&
        ((id == kTitleEdit || id == kUrlEdit || id == kTagsEdit ||
          id == kNoteEdit) &&
         notification == EN_CHANGE)) {
      editor_dirty_ = true;
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
        static_cast<size_t>(change->iItem) >= problems_.size()) {
      return;
    }
    LoadEditor(problems_[static_cast<size_t>(change->iItem)]);
  }

  void ReloadProblems() {
    const std::string preserved_id = selected_id_;
    const bool preserve_dirty_editor = editor_dirty_;
    problems_ = database_.LoadProblems();
    known_revision_ = database_.Revision();
    reloading_list_ = true;
    ListView_DeleteAllItems(list_);
    int selected_index = -1;
    for (size_t index = 0; index < problems_.size(); ++index) {
      const auto& problem = problems_[index];
      const auto title = Utf8ToWide(problem.title);
      LVITEMW item{};
      item.mask = LVIF_TEXT;
      item.iItem = static_cast<int>(index);
      item.pszText = const_cast<wchar_t*>(title.c_str());
      ListView_InsertItem(list_, &item);
      SetListText(static_cast<int>(index), 1, problem.platform);
      SetListText(static_cast<int>(index), 2, problem.workflow_status);
      SetListText(static_cast<int>(index), 3, JsonToTags(problem.tags_json));
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
        LoadEditor(problems_[static_cast<size_t>(selected_index)]);
      }
    } else if (!preserved_id.empty() && !preserve_dirty_editor) {
      ClearEditor();
    }
    reloading_list_ = false;
    SetStatus("已加载 " + std::to_string(problems_.size()) + " 道题；修订号 " +
              std::to_string(known_revision_));
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
    problem.note = WideToUtf8(WindowText(note_edit_));
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
    SetWindowTextW(note_edit_, L"");
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
    SetWindowTextUtf8(note_edit_, problem.note);
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
  HWND window_ = nullptr;
  HWND path_text_ = nullptr;
  HWND list_ = nullptr;
  HWND new_button_ = nullptr;
  HWND save_button_ = nullptr;
  HWND delete_button_ = nullptr;
  HWND open_button_ = nullptr;
  HWND refresh_button_ = nullptr;
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
  HWND note_label_ = nullptr;
  HWND note_edit_ = nullptr;
  HWND status_text_ = nullptr;
  std::vector<ProblemRecord> problems_;
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
    if (!selection.custom) {
      MigrateDefaultDatabase(selection.path);
    }
    Application application(selection.path);
    if (!application.Create(instance, show_command)) {
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
