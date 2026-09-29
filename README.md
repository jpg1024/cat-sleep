# 猫猫睡觉 (CatSleep)

一款基于 Flutter 的 Windows 定时关机客户端，极简现代 UI 设计，支持工作日智能判断、开机自启、系统托盘常驻、动态图标切换、多任务提醒功能。

![Flutter](https://img.shields.io/badge/Flutter-3.44.5-blue)
![Platform](https://img.shields.io/badge/Platform-Windows%2010+-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## 功能特性

### 核心功能
- **7 种任务类型**：关机、重启、注销、休眠、睡眠、锁定、提醒
- **提醒任务**：支持多个定时提醒，时间到达时弹出强制对话框（即使应用最小化到托盘）
- **3 种调度方式**：从现在开始（倒计时）/ 工作日 / 指定时间
- **频率控制**：每天 / 每周（可选星期几）/ 每月（可选日期）
- **动态图标**：26 种动物图标可选

### 智能工作日
- **2026 年官方放假安排**：内置国务院发布的完整节假日数据（含调休）
- **本地缓存**：节假日数据首次加载后保存到本地，无需重复请求
- **可视化日历**：标注节假日名称、调休上班日，支持手动覆盖
- **日期限制**：只能选择今天及以后的日期
- **三层判断策略**：用户覆盖 → 本地缓存/API → 内置数据

### 系统特性
- **开机自启**：在 Windows 启动文件夹创建快捷方式（支持自定义图标）
- **托盘常驻**：最小化到系统托盘，右键菜单快速操作
- **主题切换**：白天/夜间模式，靛蓝主色调（#6366F1）
- **配置持久化**：任务设置自动保存，重启后恢复
- **强制通知**：应用最小化到托盘时也能弹出提醒对话框

### UI 设计
- **极简主界面**：渐变状态卡片 + 操作按钮 + 后续执行时间线，所有配置收纳到弹窗
- **两个独立弹窗**：新建任务（操作类型 / 调度方式 / 频率 / 节假日日历）、系统设置（提前提醒 / 开机自启 / 更换图标 / 重建工作日缓存 / 节假日管理）
- **现代化视觉**：圆角 20px 卡片、渐变状态栏、微动效、大留白
- **参考风格**：Raycast / Notion / Arc Browser

## 技术架构

```
┌──────────────────────────────────────────────────┐
│              Flutter Windows App                 │
├──────────────────────────────────────────────────┤
│  UI Layer (Material 3, 极简设计)                  │
│  ├── HomeScreen (极简主界面)                      │
│  ├── StatusCard (渐变状态卡片)                    │
│  ├── TaskTypeGrid (图标+文字网格)                 │
│  ├── SettingsDialog (Tab 标签页设置弹窗)          │
│  ├── HolidayCalendar (节假日日历)                 │
│  └── SegmentedControl (分段选择器)                │
├──────────────────────────────────────────────────┤
│  Service Layer                                   │
│  ├── SchedulerService (定时调度引擎)              │
│  ├── RemindTaskService (提醒任务管理)             │
│  ├── NotificationService (通知服务 - Dialog回退)  │
│  ├── WorkdayService (工作日判断 + 2026官方数据)   │
│  ├── IconService (动态图标管理)                   │
│  ├── WindowsService (Platform Channel)           │
│  ├── StorageService (本地持久化 + 节假日缓存)     │
│  └── StartupService (开机自启)                    │
├──────────────────────────────────────────────────┤
│  Native Layer (C++ Platform Channel)             │
│  ├── 系统命令执行 (shutdown/restart/...)         │
│  └── 快捷方式管理 (支持自定义图标)                │
└──────────────────────────────────────────────────┘
```

### 技术栈
- **Flutter 3.44.5** + Dart 3.12.2
- **Windows 平台**：Visual Studio Build Tools 2022
- **依赖包**：
  - `tray_manager` - 系统托盘管理
  - `window_manager` - 窗口控制（强制弹出）
  - `http` - API 请求
  - `path_provider` - 文件路径
  - `intl` - 国际化

### 通知方案
**先弹出主界面 → 再弹出 Flutter 强制 Dialog**，不使用 Windows Toast：
1. `isMinimized()` → `restore()`，再 `show()` + `focus()` + `setAlwaysOnTop(true)` 把主窗口拉回前台
2. 轮询 `isVisible()` 最多 500ms，确认主界面真的显示出来了
3. 然后才 `showDialog(barrierDismissible: false)`，用户必须点「确定」才能关闭
4. 关闭后恢复 `setAlwaysOnTop(false)`

> 为什么不用 Toast：Windows Toast 要求开始菜单里存在带 `System.AppUserModel.ID` 的快捷方式，
> 本项目只创建桌面/启动文件夹快捷方式，Toast 必然投递失败；早期实现还会把失败静默吞掉、
> 误判为"发送成功"，导致提醒完全不弹。已于 2026-09-29 移除 Toast 及对应的 C++ 通道。

## 快速开始

### 环境要求
- Flutter SDK 3.44.5+
- Windows 10/11
- Visual Studio Build Tools 2022

### 编译运行

```bash
flutter pub get
flutter run -d windows          # 调试运行
flutter build windows --release # 发布编译
```

编译产物位于 `build/windows/x64/runner/Release/cat_sleep.exe`

## 使用说明

### 主界面
- **状态卡片**：显示当前动物图标、倒计时、进度条
- **操作按钮**：取消任务 / 提醒任务（新建任务入口在状态卡片上）
- **后续执行时间线**：有周期任务时列出最近若干次执行时间，可展开查看全部
- **顶栏**：主题切换 + 系统设置入口

### 提醒任务管理
- **多任务并存**：可以创建多个提醒任务，每个任务独立计时
- **时间固定化**：创建时转换为绝对时间（秒数归零），不会因应用重启而顺延
- **过期显示**：过期的提醒任务显示删除线和灰色文字
- **时间排序**：按时间从早到晚排列
- **强制弹窗**：时间到达时自动弹出对话框，即使应用最小化到托盘也能看到
- **一次性提醒**：触发后自动从列表中删除

### 两个弹窗
| 弹窗 | 内容 |
|------|------|
| 新建任务 `CreateTaskDialog` | 操作类型 + 调度方式（图标下拉）→ 联动时间配置：倒计时（时/分）、指定时间（日期时间 + 频率：每天/每周/每月）、工作日（时/分 + "仅在工作日前一晚执行"开关 + 节假日日历）；提醒类型额外显示"提醒内容"输入框 |
| 系统设置 `SystemSettingsDialog` | 提前提醒（分钟）、开机自启、更换图标、重建工作日缓存、节假日管理（按年分组，添加/删除自定义日期，底部取消/保存） |

### 节假日日历
- 绿色：放假（标注节日名称如"元旦"、"春节"）
- 红色：周末
- 橙色：调休上班（标注"班"）
- 紫色边框：用户手动覆盖
- 过去日期灰色不可点击

### 动态图标
- 26 种动物图标（cat, dog, panda, tiger 等）
- 选择后同时更新：托盘图标 + 桌面快捷方式图标
- 配置持久化，重启后自动恢复

## 项目结构

```
lib/
├── main.dart                      # 入口 + 托盘 + 窗口生命周期（含 setPreventClose）
├── models/
│   ├── task_config.dart           # 任务配置模型（含 fixedRemind 时间固定化工厂）
│   └── workday_config.dart        # 工作日配置模型
├── theme/
│   └── app_theme.dart             # 靛蓝主色调 + 白天/夜间主题
├── services/
│   ├── windows_service.dart       # Windows 原生操作封装（Platform Channel）
│   ├── scheduler_service.dart     # 定时调度引擎（周期任务自动重排期）
│   ├── remind_task_service.dart   # 提醒任务多定时器管理（单例）
│   ├── notification_service.dart  # 强制弹窗通知（先弹主界面再弹 Dialog）
│   ├── storage_service.dart       # 本地持久化 + 节假日缓存
│   ├── workday_service.dart       # 工作日判断（2026 官方数据）
│   ├── year_workday_cache_service.dart # 全年工作日/eve 执行日预计算缓存
│   ├── startup_service.dart       # 开机自启管理
│   ├── icon_service.dart          # 动态图标管理（PNG→ICO）
│   └── log_service.dart           # 文件日志
├── screens/
│   └── home_screen.dart           # 极简主界面 + 提醒任务管理弹窗
└── widgets/
    ├── create_task_dialog.dart    # 新建任务弹窗
    ├── system_settings_dialog.dart # 系统设置弹窗 + 节假日管理
    ├── status_card.dart           # 渐变状态卡片
    ├── holiday_calendar.dart      # 节假日日历组件
    ├── custom_date_editor.dart    # 自定义日期编辑
    ├── segmented_control.dart     # 分段选择器
    └── icon_picker_dialog.dart    # 图标选择对话框

assets/
├── tray_icon.png                  # 当前托盘图标
└── animals/                       # 26 种动物图标

windows/runner/
├── main.cpp                       # Platform Channel handler + 快捷方式/图标
├── flutter_window.cpp/.h          # Flutter 视图宿主
├── win32_window.cpp/.h            # 窗口消息处理（quit_on_close 等）
└── CMakeLists.txt                 # 构建配置
```

> `lib/widgets/notification_overlay.dart` 是早期独立通知窗口方案的残留文件，无人 import
> 且对 window_manager 0.4.3 存在编译错误，待删除。

## 2026 年放假安排（内置数据）

| 节日 | 放假日期 | 调休上班 |
|------|----------|----------|
| 元旦 | 1/1-1/3（3天） | 1/4（周日） |
| 春节 | 2/15-2/23（9天） | 2/14（周六）、2/28（周六） |
| 清明 | 4/4-4/6（3天） | 无 |
| 劳动节 | 5/1-5/5（5天） | 5/9（周六） |
| 端午 | 6/19-6/21（3天） | 无 |
| 中秋 | 9/25-9/27（3天） | 无 |
| 国庆 | 10/1-10/7（7天） | 9/20（周日）、10/10（周六） |

## Platform Channel

通道名称：`cat_sleep/windows`

| 方法 | 说明 |
|------|------|
| `shutdown` | 关机（`shutdown.exe /s /t 0`） |
| `restart` | 重启（`shutdown.exe /r /t 0`） |
| `logoff` | 注销（`shutdown.exe /l`） |
| `hibernate` | 休眠（`shutdown.exe /h`，需系统已启用休眠） |
| `sleep` | 睡眠（`rundll32.exe powrprof.dll,SetSuspendState 0,1,0`） |
| `lock` | 锁定（`rundll32.exe user32.dll,LockWorkStation`） |
| `createStartupShortcut` | 创建自启快捷方式 |
| `createStartupShortcutWithIcon` | 创建带图标的自启快捷方式（参数：`iconPath`） |
| `removeStartupShortcut` | 删除自启快捷方式 |
| `hasStartupShortcut` | 检查自启状态 |
| `createDesktopShortcut` | 创建桌面快捷方式 |
| `createDesktopShortcutWithIcon` | 创建带图标的桌面快捷方式（参数：`iconPath`） |
| `removeDesktopShortcut` | 删除桌面快捷方式 |
| `hasDesktopShortcut` | 检查桌面快捷方式是否存在 |
| `setWindowIcon` | 设置窗口/任务栏图标（参数：`iconPath`，仅支持 ICO） |
| `cancelShutdown` | 取消关机（`shutdown.exe /a`） |
| `closeProgram` | 关闭指定程序（参数：`programName`）——**C++ 侧仍存在，但已无 Dart 调用方，属死代码** |

> `showNotification` 通道已于 2026-09-29 移除，提醒统一走 Dart 侧的 `NotificationService`。

## 已知限制

1. **休眠依赖系统设置**：`shutdown /h` 要求 Windows 已启用休眠（`powercfg /a` 可查看）；未启用时命令会失败，Dart 侧会收到 `CommandFailed` 错误并记录到日志
2. **应用必须处于运行状态**：定时任务依赖进程内的 Dart Timer，应用退出（托盘菜单「退出」）后不会触发
3. **睡眠命令的调用约定**：`rundll32.exe powrprof.dll,SetSuspendState 0,1,0` 的布尔参数实际不会按预期传入（rundll32 把逗号后的内容整体作为单个字符串传给第 3 个参数）；实际行为取决于系统状态（启用休眠则休眠，否则睡眠）。本机休眠未启用，所以结果是 S3 睡眠，但这是巧合正确

## 许可证

MIT License
