#pragma once

// What the browser process and the renderer agree on for extension action
// popups. Shared with the helper executable, so no Qt in here.
namespace ExtensionPopupProtocol
{
// extra_info key set on a popup's browser: the CefBrowser identifier (which
// is also the extension tabId) of the page the action acts on, -1 for none
inline constexpr char kTabIdKey[] = "illuminate.actionTabId";

// renderer -> browser process message; argument 0 says which
inline constexpr char kMessage[] = "illuminate.actionPopup";
inline constexpr char kResize[] = "resize"; // width, height in DIPs
inline constexpr char kClose[] = "close";

// Chrome's limits for action popups
inline constexpr int kMinWidth = 25;
inline constexpr int kMinHeight = 25;
inline constexpr int kMaxWidth = 800;
inline constexpr int kMaxHeight = 600;
}
