#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

// Default wait for commands that return immediately (shutdown.exe,
// rundll32 LockWorkStation). Kept short because the handler runs on the
// platform thread and blocks the Windows message pump while waiting.
static const DWORD kCommandTimeoutMs = 5000;

// Helper: execute a command through cmd.exe without a console window.
//
// timeoutMs == 0 means "fire and forget": the process is launched and both
// handles are closed without waiting. This is required for commands that
// legitimately do not return until the system resumes (rundll32
// SetSuspendState). Waiting on those would block the platform thread for the
// whole suspend period, and because WaitForSingleObject timeouts are counted
// in interrupt time (which does not advance during S3/S4), the remaining
// timeout would keep the message pump frozen *after* wake as well.
//
// When waiting, *exitCode receives the child process exit code and the
// function returns true. Returns false if the process could not be started,
// the wait timed out, or the exit code could not be read.
static bool ExecuteCommand(const std::wstring& cmd, DWORD timeoutMs,
                           DWORD* exitCode) {
  STARTUPINFOW si = {sizeof(si)};
  PROCESS_INFORMATION pi = {};
  std::wstring fullCmd = L"cmd.exe /c " + cmd;
  if (!CreateProcessW(nullptr, &fullCmd[0], nullptr, nullptr, FALSE,
                      CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) {
    return false;
  }

  if (timeoutMs == 0) {
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return true;
  }

  bool ok = false;
  if (WaitForSingleObject(pi.hProcess, timeoutMs) == WAIT_OBJECT_0) {
    DWORD code = 0;
    if (GetExitCodeProcess(pi.hProcess, &code)) {
      if (exitCode != nullptr) {
        *exitCode = code;
      }
      ok = true;
    }
  }
  CloseHandle(pi.hProcess);
  CloseHandle(pi.hThread);
  return ok;
}

// Native shutdown/restart via Windows API -- avoids spawning shutdown.exe
// through cmd.exe, which produced spurious non-zero exit codes (e.g. 1271)
// on some systems. InitiateSystemShutdownExW is available to standard users
// (they hold SeShutdownPrivilege by default) and returns immediately when
// the timeout is 0.
static bool NativeShutdown() {
  return InitiateSystemShutdownExW(nullptr, nullptr, 0, TRUE, FALSE,
                                   SHTDN_REASON_FLAG_PLANNED) != 0;
}

static bool NativeRestart() {
  return InitiateSystemShutdownExW(nullptr, nullptr, 0, TRUE, TRUE,
                                   SHTDN_REASON_FLAG_PLANNED) != 0;
}

// Helper: run a system command and report the real outcome back to Dart.
// Previously every handler returned Success() unconditionally, so a failed
// command (for example "shutdown /h" on a machine without hibernation
// enabled) was silently reported as executed.
static void RunSystemCommand(
    const std::wstring& cmd, DWORD timeoutMs,
    flutter::MethodResult<flutter::EncodableValue>* result) {
  DWORD exitCode = 0;
  if (!ExecuteCommand(cmd, timeoutMs, &exitCode)) {
    result->Error("CommandFailed", timeoutMs == 0
                                       ? "Could not launch command"
                                       : "Command did not finish in time");
  } else if (timeoutMs != 0 && exitCode != 0) {
    result->Error("CommandFailed",
                  "Command exit code " + std::to_string(exitCode));
  } else {
    result->Success();
  }
}

// Helper: get startup folder path
static std::wstring GetStartupFolderPath() {
  wchar_t path[MAX_PATH];
  if (SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_STARTUP, nullptr, 0, path))) {
    return std::wstring(path);
  }
  return L"";
}

// Helper: get current exe path
static std::wstring GetExePath() {
  wchar_t path[MAX_PATH];
  GetModuleFileNameW(nullptr, path, MAX_PATH);
  return std::wstring(path);
}

// Helper: get desktop folder path
static std::wstring GetDesktopFolderPath() {
  wchar_t path[MAX_PATH];
  if (SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_DESKTOPDIRECTORY, nullptr, 0, path))) {
    return std::wstring(path);
  }
  return L"";
}

// Helper: create startup shortcut
static bool CreateStartupShortcut() {
  std::wstring startupFolder = GetStartupFolderPath();
  if (startupFolder.empty()) return false;

  std::wstring shortcutPath = startupFolder + L"\\CatSleep.lnk";
  std::wstring exePath = GetExePath();

  IShellLinkW* psl = nullptr;
  HRESULT hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_ALL,
                                IID_IShellLinkW, (void**)&psl);
  if (SUCCEEDED(hr)) {
    psl->SetPath(exePath.c_str());
    psl->SetDescription(L"CatSleep Auto Start");
    IPersistFile* ppf = nullptr;
    hr = psl->QueryInterface(IID_IPersistFile, (void**)&ppf);
    if (SUCCEEDED(hr)) {
      hr = ppf->Save(shortcutPath.c_str(), TRUE);
      ppf->Release();
    }
    psl->Release();
    return SUCCEEDED(hr);
  }
  return false;
}

// Helper: create shortcut with custom icon
static bool CreateStartupShortcutWithIcon(const std::wstring& iconPath) {
  std::wstring startupFolder = GetStartupFolderPath();
  if (startupFolder.empty()) return false;

  std::wstring shortcutPath = startupFolder + L"\\CatSleep.lnk";
  std::wstring exePath = GetExePath();

  IShellLinkW* psl = nullptr;
  HRESULT hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_ALL,
                                IID_IShellLinkW, (void**)&psl);
  if (SUCCEEDED(hr)) {
    psl->SetPath(exePath.c_str());
    psl->SetDescription(L"CatSleep Auto Start");
    if (!iconPath.empty()) {
      psl->SetIconLocation(iconPath.c_str(), 0);
    }
    IPersistFile* ppf = nullptr;
    hr = psl->QueryInterface(IID_IPersistFile, (void**)&ppf);
    if (SUCCEEDED(hr)) {
      hr = ppf->Save(shortcutPath.c_str(), TRUE);
      ppf->Release();
    }
    psl->Release();
    return SUCCEEDED(hr);
  }
  return false;
}

// Helper: remove shortcut
static bool RemoveStartupShortcut() {
  std::wstring startupFolder = GetStartupFolderPath();
  if (startupFolder.empty()) return false;
  std::wstring shortcutPath = startupFolder + L"\\CatSleep.lnk";
  return DeleteFileW(shortcutPath.c_str()) != 0;
}

// Helper: check if shortcut exists
static bool HasStartupShortcut() {
  std::wstring startupFolder = GetStartupFolderPath();
  if (startupFolder.empty()) return false;
  std::wstring shortcutPath = startupFolder + L"\\CatSleep.lnk";
  return PathFileExistsW(shortcutPath.c_str()) == TRUE;
}

// Helper: create desktop shortcut
static bool CreateDesktopShortcut() {
  std::wstring desktopFolder = GetDesktopFolderPath();
  if (desktopFolder.empty()) return false;

  std::wstring shortcutPath = desktopFolder + L"\\" + L"\u732b\u732b\u7761\u89c9.lnk";
  std::wstring exePath = GetExePath();

  IShellLinkW* psl = nullptr;
  HRESULT hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_ALL,
                                IID_IShellLinkW, (void**)&psl);
  if (SUCCEEDED(hr)) {
    psl->SetPath(exePath.c_str());
    psl->SetDescription(L"CatSleep - Scheduled Shutdown");
    IPersistFile* ppf = nullptr;
    hr = psl->QueryInterface(IID_IPersistFile, (void**)&ppf);
    if (SUCCEEDED(hr)) {
      hr = ppf->Save(shortcutPath.c_str(), TRUE);
      ppf->Release();
    }
    psl->Release();
    return SUCCEEDED(hr);
  }
  return false;
}

// Helper: create desktop shortcut with custom icon
static bool CreateDesktopShortcutWithIcon(const std::wstring& iconPath) {
  std::wstring desktopFolder = GetDesktopFolderPath();
  if (desktopFolder.empty()) return false;

  std::wstring shortcutPath = desktopFolder + L"\\" + L"\u732b\u732b\u7761\u89c9.lnk";
  std::wstring exePath = GetExePath();

  IShellLinkW* psl = nullptr;
  HRESULT hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_ALL,
                                IID_IShellLinkW, (void**)&psl);
  if (SUCCEEDED(hr)) {
    psl->SetPath(exePath.c_str());
    psl->SetDescription(L"CatSleep - Scheduled Shutdown");
    if (!iconPath.empty()) {
      psl->SetIconLocation(iconPath.c_str(), 0);
    }
    IPersistFile* ppf = nullptr;
    hr = psl->QueryInterface(IID_IPersistFile, (void**)&ppf);
    if (SUCCEEDED(hr)) {
      hr = ppf->Save(shortcutPath.c_str(), TRUE);
      ppf->Release();
    }
    psl->Release();
    return SUCCEEDED(hr);
  }
  return false;
}

// Helper: remove desktop shortcut
static bool RemoveDesktopShortcut() {
  std::wstring desktopFolder = GetDesktopFolderPath();
  if (desktopFolder.empty()) return false;
  std::wstring shortcutPath = desktopFolder + L"\\" + L"\u732b\u732b\u7761\u89c9.lnk";
  return DeleteFileW(shortcutPath.c_str()) != 0;
}

// Helper: check if desktop shortcut exists
static bool HasDesktopShortcut() {
  std::wstring desktopFolder = GetDesktopFolderPath();
  if (desktopFolder.empty()) return false;
  std::wstring shortcutPath = desktopFolder + L"\\" + L"\u732b\u732b\u7761\u89c9.lnk";
  return PathFileExistsW(shortcutPath.c_str()) == TRUE;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(670, 950);
  if (!window.Create(L"CatSleep", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(false);

  // Register platform channel
  auto* flutterView = window.GetFlutterView();
  HWND hwnd = window.GetHandle();
  if (flutterView && flutterView->engine()) {
    auto messenger = flutterView->engine()->messenger();
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        messenger, "cat_sleep/windows",
        &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler(
        [hwnd](const flutter::MethodCall<flutter::EncodableValue>& call,
           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
          const auto& method = call.method_name();
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());

          if (method == "shutdown") {
            if (NativeShutdown()) {
              result->Success();
            } else {
              result->Error("CommandFailed",
                            "InitiateSystemShutdownEx failed: " +
                                std::to_string(GetLastError()));
            }
          } else if (method == "restart") {
            if (NativeRestart()) {
              result->Success();
            } else {
              result->Error("CommandFailed",
                            "InitiateSystemShutdownEx(restart) failed: " +
                                std::to_string(GetLastError()));
            }
          } else if (method == "logoff") {
            RunSystemCommand(L"shutdown.exe /l", kCommandTimeoutMs, result.get());
          } else if (method == "hibernate") {
            RunSystemCommand(L"shutdown.exe /h", kCommandTimeoutMs, result.get());
          } else if (method == "sleep") {
            // SetSuspendState does not return until the system resumes, so
            // this one is launched without waiting (timeoutMs == 0).
            RunSystemCommand(L"rundll32.exe powrprof.dll,SetSuspendState 0,1,0", 0,
                             result.get());
          } else if (method == "lock") {
            RunSystemCommand(L"rundll32.exe user32.dll,LockWorkStation",
                             kCommandTimeoutMs, result.get());
          } else if (method == "createStartupShortcut") {
            bool ok = CreateStartupShortcut();
            result->Success(flutter::EncodableValue(ok));
          } else if (method == "createStartupShortcutWithIcon") {
            if (args) {
              auto it = args->find(flutter::EncodableValue("iconPath"));
              if (it != args->end()) {
                std::string iconPathStr = std::get<std::string>(it->second);
                std::wstring iconPath(iconPathStr.begin(), iconPathStr.end());
                bool ok = CreateStartupShortcutWithIcon(iconPath);
                result->Success(flutter::EncodableValue(ok));
              } else {
                result->Success(flutter::EncodableValue(false));
              }
            } else {
              result->Success(flutter::EncodableValue(false));
            }
          } else if (method == "removeStartupShortcut") {
            bool ok = RemoveStartupShortcut();
            result->Success(flutter::EncodableValue(ok));
          } else if (method == "hasStartupShortcut") {
            bool exists = HasStartupShortcut();
            result->Success(flutter::EncodableValue(exists));
          } else if (method == "createDesktopShortcut") {
            bool ok = CreateDesktopShortcut();
            result->Success(flutter::EncodableValue(ok));
          } else if (method == "createDesktopShortcutWithIcon") {
            if (args) {
              auto it = args->find(flutter::EncodableValue("iconPath"));
              if (it != args->end()) {
                std::string iconPathStr = std::get<std::string>(it->second);
                std::wstring iconPath(iconPathStr.begin(), iconPathStr.end());
                bool ok = CreateDesktopShortcutWithIcon(iconPath);
                result->Success(flutter::EncodableValue(ok));
              } else {
                result->Success(flutter::EncodableValue(false));
              }
            } else {
              result->Success(flutter::EncodableValue(false));
            }
          } else if (method == "removeDesktopShortcut") {
            bool ok = RemoveDesktopShortcut();
            result->Success(flutter::EncodableValue(ok));
          } else if (method == "hasDesktopShortcut") {
            bool exists = HasDesktopShortcut();
            result->Success(flutter::EncodableValue(exists));
          } else if (method == "setWindowIcon") {
            if (args) {
              auto it = args->find(flutter::EncodableValue("iconPath"));
              if (it != args->end()) {
                std::string iconPathStr = std::get<std::string>(it->second);
                std::wstring iconPath(iconPathStr.begin(), iconPathStr.end());
                // Load big/small sizes (LoadImageW supports .ico containers only, not PNG)
                HICON hBig = (HICON)LoadImageW(nullptr, iconPath.c_str(), IMAGE_ICON,
                    GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON),
                    LR_LOADFROMFILE);
                HICON hSmall = (HICON)LoadImageW(nullptr, iconPath.c_str(), IMAGE_ICON,
                    GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON),
                    LR_LOADFROMFILE);
                if (hBig || hSmall) {
                  // Window icon: title bar / Alt+Tab
                  if (hBig) SendMessage(hwnd, WM_SETICON, ICON_BIG, (LPARAM)hBig);
                  if (hSmall) SendMessage(hwnd, WM_SETICON, ICON_SMALL, (LPARAM)hSmall);
                  // Class icon: Windows 11 taskbar reads the class icon
                  if (hBig) SetClassLongPtr(hwnd, GCLP_HICON, (LONG_PTR)hBig);
                  if (hSmall) SetClassLongPtr(hwnd, GCLP_HICONSM, (LONG_PTR)hSmall);
                  
                  // Force redraw to update taskbar immediately
                  RedrawWindow(hwnd, nullptr, nullptr, RDW_INVALIDATE | RDW_UPDATENOW | RDW_FRAME);
                  
                  result->Success(flutter::EncodableValue(true));
                } else {
                  result->Success(flutter::EncodableValue(false));
                }
              } else {
                result->Success(flutter::EncodableValue(false));
              }
            } else {
              result->Success(flutter::EncodableValue(false));
            }
          } else if (method == "cancelShutdown") {
            // "shutdown /a" exits with 1116 when no shutdown is in progress.
            // That is already the desired end state, so treat it as success and
            // keep cancel idempotent.
            DWORD cancelExitCode = 0;
            if (!ExecuteCommand(L"shutdown.exe /a", kCommandTimeoutMs,
                                &cancelExitCode)) {
              result->Error("CommandFailed", "Command did not finish in time");
            } else if (cancelExitCode != 0 && cancelExitCode != 1116) {
              result->Error("CommandFailed",
                            "Command exit code " + std::to_string(cancelExitCode));
            } else {
              result->Success();
            }
          } else {
            result->NotImplemented();
          }
        });
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
