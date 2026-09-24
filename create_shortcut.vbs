Set ws = CreateObject("WScript.Shell")
Set sc = ws.CreateShortcut(ws.SpecialFolders("Desktop") & "\CatSleep.lnk")
sc.TargetPath = "D:\PGitCode\cat_sleep\build\windows\x64\runner\Release\cat_sleep.exe"
sc.WorkingDirectory = "D:\PGitCode\cat_sleep\build\windows\x64\runner\Release"
sc.Description = "CatSleep 定时关机"
sc.Save
WScript.Echo "Desktop shortcut created"
