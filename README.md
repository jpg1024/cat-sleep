# 猫猫睡觉 (CatSleep)

一款基于 Flutter 的 Windows 定时关机客户端，极简现代 UI 设计，支持工作日智能判断、开机自启、系统托盘常驻、动态图标切换、多任务提醒功能。

![Flutter](https://img.shields.io/badge/Flutter-3.44.5-blue)
![Platform](https://img.shields.io/badge/Platform-Windows%2010+-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## 功能特性

### 核心功能
- **7 种任务类型**：关机、重启、注销、休眠、睡眠、锁定、关闭指定程序
- **提醒任务**：支持多个定时提醒，时间到达时弹出强制对话框（即使应用最小化到托盘）
- **3 种调度方式**：指定时间 / 从现在开始（倒计时）/ 每隔设置时间（循环）
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
- **极简主界面**：状态卡片 + 任务类型网格，所有设置收纳到弹窗
- **Tab 标签页设置**：调度 / 工作日 / 提醒 / 空闲 / 系统 五个标签页
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
采用 **PowerShell Toast + Flutter Dialog 回退** 的混合方案：
1. 首先尝试通过 PowerShell 调用 Windows Toast API
2. 失败或超时时，使用 Flutter Dialog 作为回退
3. Dialog 弹出前自动调用 `windowManager.show()` + `focus()` + `setAlwaysOnTop(true)` 确保窗口显示
4. 即使应用最小化到托盘也能强制弹出对话框

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
- **操作按钮**：创建任务 / 取消任务 / 提醒任务
- **任务类型网格**：7 种类型图标卡片，点击快速切换
- **顶栏**：主题切换 + 设置入口

### 提醒任务管理
- **多任务并存**：可以创建多个提醒任务，每个任务独立计时
- **时间固定化**：创建时转换为绝对时间（秒数归零），不会因应用重启而顺延
- **过期显示**：过期的提醒任务显示删除线和灰色文字
- **时间排序**：按时间从早到晚排列
- **强制弹窗**：时间到达时自动弹出对话框，即使应用最小化到托盘也能看到
- **一次性提醒**：触发后自动从列表中删除

### 设置弹窗（Tab 标签页）
| Tab | 内容 |
|-----|------|
| 调度 | 调度方式 + 日期时间 + 频率 + 星期/日期选择 |
| 工作日 | 仅工作日开关 + 节假日日历（标注放假/调休/名称） |
| 提醒 | 提前提醒 + 密码保护 |
| 空闲 | 空闲检测 + 重复执行 |
| 系统 | 开机自启 + 更换图标 |

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
├── main.dart                      # 入口 + 托盘 + 主题
├── models/
│   ├── task_config.dart           # 任务配置模型
│   └── workday_config.dart        # 工作日配置模型
├── theme/
│   └── app_theme.dart             # 靛蓝主色调 + 白天/夜间主题
├── services/
│   ├── windows_service.dart       # Windows 原生操作封装
│   ├── storage_service.dart       # 本地持久化 + 节假日缓存
│   ├── workday_service.dart       # 工作日判断（2026官方数据）
│   ├── scheduler_service.dart     # 定时调度引擎
│   ├── startup_service.dart       # 开机自启管理
│   └── icon_service.dart          # 动态图标管理
├── screens/
│   └── home_screen.dart           # 极简主界面
└── widgets/
    ├── status_card.dart           # 渐变状态卡片
    ├── task_type_grid.dart        # 任务类型图标网格
    ├── settings_dialog.dart       # Tab 标签页设置弹窗
    ├── segmented_control.dart     # 分段选择器
    ├── holiday_calendar.dart      # 节假日日历组件
    └── icon_picker_dialog.dart    # 图标选择对话框

assets/
├── tray_icon.png                  # 当前托盘图标
└── animals/                       # 26 种动物图标

windows/runner/
├── main.cpp                       # Platform Channel（含图标快捷方式）
├── flutter_window.h               # 窗口控制
└── CMakeLists.txt                 # 构建配置
```

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
| `shutdown` | 关机 |
| `restart` | 重启 |
| `logoff` | 注销 |
| `hibernate` | 休眠 |
| `sleep` | 睡眠 |
| `lock` | 锁定 |
| `closeProgram` | 关闭程序（参数：`programName`） |
| `createStartupShortcut` | 创建自启快捷方式 |
| `createStartupShortcutWithIcon` | 创建带图标的自启快捷方式 |
| `removeStartupShortcut` | 删除自启快捷方式 |
| `hasStartupShortcut` | 检查自启状态 |
| `cancelShutdown` | 取消关机 |

## 已知限制

1. **密码保护**：UI 已预留开关，实际验证逻辑待实现
2. **空闲检测**：UI 已实现，实际系统空闲时间检测待实现

## 许可证

MIT License
