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

// Helper: execute a command
static bool ExecuteCommand(const std::wstring& cmd) {
  STARTUPINFOW si = {sizeof(si)};
  PROCESS_INFORMATION pi = {};
  std::wstring fullCmd = L"cmd.exe /c " + cmd;
  if (CreateProcessW(nullptr, &fullCmd[0], nullptr, nullptr, FALSE,
                     CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) {
    WaitForSingleObject(pi.hProcess, 30000);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return true;
  }
  return false;
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
            ExecuteCommand(L"shutdown.exe /s /t 0");
            result->Success();
          } else if (method == "restart") {
            ExecuteCommand(L"shutdown.exe /r /t 0");
            result->Success();
          } else if (method == "logoff") {
            ExecuteCommand(L"shutdown.exe /l");
            result->Success();
          } else if (method == "hibernate") {
            ExecuteCommand(L"shutdown.exe /h");
            result->Success();
          } else if (method == "sleep") {
            ExecuteCommand(L"rundll32.exe powrprof.dll,SetSuspendState 0,1,0");
            result->Success();
          } else if (method == "lock") {
            ExecuteCommand(L"rundll32.exe user32.dll,LockWorkStation");
            result->Success();
          } else if (method == "closeProgram") {
            if (args) {
              auto it = args->find(flutter::EncodableValue("programName"));
              if (it != args->end()) {
                std::string progName = std::get<std::string>(it->second);
                std::wstring wProgName(progName.begin(), progName.end());
                std::wstring cmd = L"taskkill /IM " + wProgName + L" /F";
                ExecuteCommand(cmd);
              }
            }
            result->Success();
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
          } else if (method == "showNotification") {
            if (args) {
              auto title_it = args->find(flutter::EncodableValue("title"));
              auto body_it = args->find(flutter::EncodableValue("body"));
              if (title_it != args->end() && body_it != args->end()) {
                std::string titleStr = std::get<std::string>(title_it->second);
                std::string bodyStr = std::get<std::string>(body_it->second);
                
                // Convert UTF-8 to wide string
                int titleLen = MultiByteToWideChar(CP_UTF8, 0, titleStr.c_str(), -1, nullptr, 0);
                std::wstring titleW(titleLen, 0);
                MultiByteToWideChar(CP_UTF8, 0, titleStr.c_str(), -1, &titleW[0], titleLen);
                
                int bodyLen = MultiByteToWideChar(CP_UTF8, 0, bodyStr.c_str(), -1, nullptr, 0);
                std::wstring bodyW(bodyLen, 0);
                MultiByteToWideChar(CP_UTF8, 0, bodyStr.c_str(), -1, &bodyW[0], bodyLen);
                
                // Use simpler PowerShell command with error handling
                std::wstring psCmd = L"powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command \""
                    L"$ErrorActionPreference = 'Stop'; "
                    L"try { "
                    L"[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null; "
                    L"$template = [Windows.UI.Notifications.ToastTemplateType]::toastText02; "
                    L"$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent($template).GetXml(); "
                    L"$xml.GetElementsByTagName('text')[0].AppendChild($xml.CreateTextNode('" + titleW + L"')); "
                    L"$xml.GetElementsByTagName('text')[1].AppendChild($xml.CreateTextNode('" + bodyW + L"')); "
                    L"$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('CatSleep'); "
                    L"$notifier.Show([Windows.UI.Notifications.ToastNotification]::CreateFromXml($xml)); "
                    L"} catch { "
                    L"Add-Type -AssemblyName System.Windows.Forms; "
                    L"[System.Windows.Forms.MessageBox]::Show('" + bodyW + L"', '" + titleW + L"'); "
                    L"}\"";
                
                ExecuteCommand(psCmd);
                result->Success();
              } else {
                result->Error("InvalidArguments", "Missing title or body");
              }
            } else {
              result->Error("InvalidArguments", "Arguments are null");
            }
          } else if (method == "cancelShutdown") {
            ExecuteCommand(L"shutdown.exe /a");
            result->Success();
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
