#include "flutter_window.h"

#include <optional>
#include <string>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  quick_entry_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "oj_float/quick_entry",
      &flutter::StandardMethodCodec::GetInstance());
  quick_entry_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "register") {
          const auto* args = call.arguments();
          const auto* map = args ? std::get_if<flutter::EncodableMap>(args) : nullptr;
          if (!map) { result->Error("invalid_shortcut", "Expected shortcut map."); return; }
          const auto mod_it = map->find(flutter::EncodableValue("modifiers"));
          const auto key_it = map->find(flutter::EncodableValue("key"));
          const auto* modifiers = mod_it == map->end() ? nullptr : std::get_if<int32_t>(&mod_it->second);
          const auto* key = key_it == map->end() ? nullptr : std::get_if<int32_t>(&key_it->second);
          if (!modifiers || !key || (*modifiers & ~7) != 0 || (*modifiers & 3) == 0 ||
              !((*key >= 'A' && *key <= 'Z') || (*key >= '0' && *key <= '9'))) {
            result->Error("invalid_shortcut", "Invalid modifiers or key."); return;
          }
          if (quick_entry_hotkey_id_ && quick_entry_modifiers_ == *modifiers && quick_entry_key_ == *key) {
            result->Success(flutter::EncodableValue(true)); return;
          }
          // Reserve a new ID first: a conflict must leave the old hotkey alive.
          const int next_id = quick_entry_hotkey_id_ == 0x4F ? 0x50 : 0x4F;
          const bool registered = ::RegisterHotKey(GetHandle(), next_id,
              static_cast<UINT>(*modifiers) | MOD_NOREPEAT, static_cast<UINT>(*key)) != 0;
          if (registered) {
            if (quick_entry_hotkey_id_) ::UnregisterHotKey(GetHandle(), quick_entry_hotkey_id_);
            quick_entry_hotkey_id_ = next_id;
            quick_entry_modifiers_ = *modifiers;
            quick_entry_key_ = *key;
          }
          result->Success(flutter::EncodableValue(registered));
        } else {
          result->NotImplemented();
        }
      });

  return true;
}

void FlutterWindow::OnDestroy() {
  if (quick_entry_hotkey_id_) ::UnregisterHotKey(GetHandle(), quick_entry_hotkey_id_);
  quick_entry_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_HOTKEY && quick_entry_hotkey_id_ != 0 &&
      wparam == static_cast<WPARAM>(quick_entry_hotkey_id_) && quick_entry_channel_) {
    quick_entry_channel_->InvokeMethod("open", nullptr);
    return 0;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
