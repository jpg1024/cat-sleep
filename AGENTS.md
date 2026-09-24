# AGENTS.md - AI Agent 协作指南

本文档为 AI 编码助手提供项目上下文和协作规范。

## 项目概述

**猫猫睡觉 (CatSleep)** 是一款 Flutter Windows 桌面定时关机客户端，核心特性：
- 7 种系统操作（关机/重启/注销/休眠/睡眠/锁定/关闭程序）
- **提醒任务**：支持多个定时提醒，时间到达时弹出强制对话框（即使应用最小化到托盘）
- 智能工作日判断（2026 官方放假安排 + 本地缓存 + 用户覆盖）
- 开机自启（startup 文件夹快捷方式，支持自定义图标）
- 系统托盘常驻 + 白天/夜间主题切换
- 动态图标选择（26 种动物图标）
- **极简现代 UI**：主界面只展示状态，所有设置收纳到 Tab 弹窗
- **强制通知方案**：PowerShell Toast + Flutter Dialog 回退，确保托盘状态下也能弹出

## 技术栈

| 层级 | 技术 | 版本 |
|------|------|------|
| 框架 | Flutter | 3.44.5 |
| 语言 | Dart | 3.12.2 |
| 原生层 | C++ (Windows API) | MSVC 2022 |
| 构建工具 | Visual Studio Build Tools | 17.x |

## 架构决策

### 极简 UI 设计
主界面只展示核心信息（状态卡片 + 任务类型网格），所有配置收纳到设置弹窗（Tab 标签页切换）。

**Why:** 用户要求现代极简风格（Raycast/Notion/Arc 参考），不接受表单堆砌。

**How to apply:** 新增功能时优先放入设置弹窗的对应 Tab，不要往主界面添加更多控件。

### 单任务模式
应用一次只管理一个定时任务。设置新任务时自动取消旧任务。

**Why:** 用户确认的设计选择，简化交互逻辑。

**How to apply:** `SchedulerService` 全局只维护一个 `Timer`，新任务调用 `startTask()` 前会先 `cancelTask()`。

### 提醒任务多任务模式
提醒任务（`TaskType.remind`）支持多个任务并存，每个任务独立计时。

**Why:** 用户需要多个独立的提醒时间点，不同于关机/重启等系统操作的单任务模式。

**How to apply:** 
- `RemindTaskService` 全局单例管理所有提醒任务的定时器列表
- 每个提醒任务创建独立的 `Timer`
- 触发后自动从列表中删除（一次性提醒）
- 时间固定化：创建时将相对时间转换为绝对时间（秒数归零），避免应用重启后顺延

### 通知方案（强制弹窗）
采用 **PowerShell Toast + Flutter Dialog 回退** 的混合方案。

**Why:** Windows Toast API 在某些情况下静默失败，需要可靠的回退机制；同时需要确保应用最小化到托盘时也能弹出对话框。

**How to apply:**
1. `NotificationService.showNotification()` 首先尝试 PowerShell Toast（5秒超时）
2. 失败或超时时调用 `_showDialog()` 回退
3. Dialog 弹出前执行：
   - `windowManager.show()` - 显示窗口
   - `windowManager.focus()` - 聚焦窗口
   - `windowManager.setAlwaysOnTop(true)` - 置顶显示
4. Dialog 设置 `barrierDismissible: false` 防止误触关闭
5. 点击"确定"后恢复窗口状态 `setAlwaysOnTop(false)`

**关键文件：**
- `lib/services/notification_service.dart` - 核心通知服务
- `lib/services/remind_task_service.dart` - 提醒任务管理
- `lib/screens/home_screen.dart` - 设置通知上下文（`NotificationService.setContext(context)`）

### 工作日三层策略
```
用户覆盖(本地JSON) → 本地节假日缓存/API → 2026年内置数据
  优先级最高            首次加载后离线可用       兜底
```

**Why:** 2026 年官方放假安排已内置，首次启动保存到本地缓存，后续无需联网。

**How to apply:** `WorkdayService.isWorkday()` 按此顺序判断。`holidays2026` 常量包含完整官方数据。

### 节假日数据本地化
内置 2026 年国务院放假安排，首次启动时保存到 `holiday_cache.json`，日历组件从缓存读取。

**Why:** 避免每次打开日历都请求 API，提升体验。

**How to apply:** `StorageService.saveHolidayCache()` / `loadHolidayCache()` 管理缓存。`WorkdayService.getMonthCalendar()` 返回带标注的日历数据。

### 动态图标
26 种动物图标存储在 `assets/animals/`，用户选择后复制到 `assets/tray_icon.png`，同时更新桌面快捷方式图标。

**Why:** 用户要求个性化图标，不修改原始文件名。

**How to apply:** `IconService.applyIcon()` 处理图标切换全流程。C++ 层 `CreateStartupShortcutWithIcon()` 支持设置快捷方式图标。

### Platform Channel 设计
通道名：`cat_sleep/windows`

所有 Windows 原生操作通过此通道调用 C++ 实现。

**How to apply:** 新增原生功能时，在 `windows/runner/main.cpp` 添加 handler，在 `lib/services/windows_service.dart` 封装 Dart 调用。

### 本地持久化
JSON 文件存储在 `path_provider` 的 `getApplicationDocumentsDirectory()/CatSleep/` 下：
- `task_config.json` - 任务配置（单任务）
- `remind_tasks.json` - 提醒任务列表（多任务）
- `workday_config.json` - 工作日覆盖数据
- `settings.json` - 应用设置（主题、图标等）
- `holiday_cache.json` - 节假日缓存

**How to apply:** 通过 `StorageService` 统一读写。

## 代码规范

### 文件命名
- Dart 文件：`snake_case.dart`
- 类名：`PascalCase`
- 常量：`camelCase`
- 枚举值：`camelCase`

### 服务层模式
所有服务类使用静态方法，无需实例化。

### UI 组件
- Material 3 风格，主色调 `#6366F1`（靛蓝 Indigo）
- 圆角 20px 卡片，无边框阴影
- 主题色通过 `Theme.of(context).colorScheme` 获取
- 支持白天/夜间模式，不硬编码颜色值
- 设置弹窗使用 Tab 标签页（5 个 Tab）

### 颜色系统
```
主色：#6366F1 (Indigo)
成功：#10B981 (Green)
警告：#F59E0B (Amber)
错误：#EF4444 (Red)

白天背景：#FAFBFC
夜间背景：#0F172A
```

## 关键文件说明

### `lib/screens/home_screen.dart`
极简主界面：状态卡片 + 操作按钮 + 任务类型网格。点击设置按钮打开 `SettingsDialog`。

### `lib/widgets/settings_dialog.dart`
Tab 标签页设置弹窗，5 个 Tab：
- **调度**：`SegmentedControl` 选择调度方式 + 日期时间 + 频率
- **工作日**：开关 + `HolidayCalendar` 日历组件
- **提醒**：提醒开关 + 密码保护
- **空闲**：空闲检测 + 重复执行
- **系统**：开机自启 + 更换图标

### `lib/widgets/status_card.dart`
渐变背景状态卡片，显示动物图标、倒计时、进度条。无任务时显示空状态。

### `lib/widgets/task_type_grid.dart`
7 种任务类型的图标卡片网格（80x80px），图标 + 文字标签，选中态主色边框。

### `lib/widgets/remind_task_manager_dialog.dart`（已集成到 home_screen.dart）
提醒任务管理弹窗：
- 顶部"新增提醒任务"按钮
- 任务列表按时间从早到晚排序
- 过期任务显示删除线和灰色文字
- 每个任务右侧删除按钮
- 空状态显示"暂无提醒任务"

### `lib/services/notification_service.dart`
通知服务（PowerShell Toast + Dialog 回退）：
- `setContext(BuildContext)` - 设置通知上下文（在 HomeScreen.initState 中调用）
- `showNotification({title, message})` - 显示通知
- `_showDialog(title, message)` - Dialog 回退（强制弹出）

### `lib/services/remind_task_service.dart`
提醒任务管理服务：
- `loadAndStartTasks()` - 加载所有提醒任务并启动定时器
- `cancelAll()` - 取消所有定时器
- 触发时自动调用 `NotificationService.showNotification()`
- 触发后自动从列表中删除

### `lib/widgets/holiday_calendar.dart`
节假日日历组件，标注放假名称（如"元旦"、"春节"）、调休上班（"班"），颜色区分日期类型，过去日期不可点击。

### `lib/services/workday_service.dart`
工作日判断服务：
- `holidays2026` - 2026 年官方放假安排常量
- `_ensureCache()` - 首次加载保存到本地
- `getMonthCalendar()` - 返回带标注的日历数据
- `getDateInfo()` - 获取日期信息（名称+类型）

### `lib/services/icon_service.dart`
图标管理服务：
- `applyIcon()` - 复制图标 + 更新托盘 + 更新快捷方式
- `initIcon()` - 启动时加载图标
- `getCurrentIcon()` - 获取当前图标名

### `windows/runner/main.cpp`
C++ 原生层：
- `ExecuteCommand()` - 执行系统命令（`CREATE_NO_WINDOW`）
- `CreateStartupShortcut()` / `CreateStartupShortcutWithIcon()` - 快捷方式管理
- `SetIconLocation()` - 设置快捷方式图标

## 常见任务

### 添加新的任务类型
1. `lib/models/task_config.dart` 的 `TaskType` 枚举添加
2. `windows/runner/main.cpp` 添加 handler
3. `lib/services/windows_service.dart` 添加封装
4. `lib/widgets/task_type_grid.dart` 添加图标

### 添加提醒任务相关功能
1. 在 `lib/models/task_config.dart` 中使用 `TaskType.remind`
2. 通过 `StorageService.loadRemindTasks()` / `saveRemindTasks()` 管理数据
3. 触发时调用 `NotificationService.showNotification(title: '猫猫睡觉提醒', message: ...)`
4. 注意：提醒任务时间需固定化（秒数归零）避免顺延

### 更新节假日数据
编辑 `lib/services/workday_service.dart` 的 `holidays2026` 常量，格式：
```dart
'2026-01-01': {'name': '元旦', 'type': 'holiday'},
'2026-01-04': {'name': '班', 'type': 'workday'},  // 调休
```

### 修改通知样式
编辑 `lib/services/notification_service.dart` 的 `_showDialog()` 方法：
- 调整 `AlertDialog` 的标题/内容字体大小
- 修改 `barrierDismissible` 控制是否允许点击外部关闭
- 调整窗口置顶逻辑（`setAlwaysOnTop`）

### 添加新的设置项
1. 在 `lib/widgets/settings_dialog.dart` 对应 Tab 中添加
2. 如需新 Tab，修改 `_tabs` 列表和 `TabBarView`
3. 在 `TaskConfig` 中添加字段并更新 JSON 序列化

### 修改 UI 主题
编辑 `lib/theme/app_theme.dart`：
- 主色调：`primaryColor`
- 功能色：`successColor` / `warningColor` / `errorColor`
- 圆角、阴影、间距等在各 Theme 中调整

## 测试建议

### 功能测试
- 设置 1 分钟后"锁定" → 验证 Timer 触发
- 设置每周工作日 23:55 → 验证工作日过滤
- 打开设置 → 工作日 Tab → 验证日历标注
- 选择动物图标 → 验证托盘和快捷方式同时更新
- 开启自启 → 检查 startup 文件夹快捷方式（含图标）
- 切换主题 → 验证白天/夜间模式
- 重启应用 → 验证配置恢复 + 图标恢复

### 编译验证
```bash
flutter build windows --release
```

## 协作约定

1. **不要修改 Platform Channel 接口**：除非同步更新 Dart 和 C++ 两侧
2. **保持单任务模式**：除提醒任务外，其他任务类型只能创建一个
3. **提醒任务多任务模式**：可以创建多个提醒任务，每个独立计时
4. **工作日优先级**：用户覆盖 > 本地缓存/API > 内置数据
5. **主题兼容**：新增 UI 元素必须同时支持白天/夜间模式
6. **本地路径**：不要硬编码绝对路径，使用 `path_provider`
7. **UI 风格**：保持极简设计，新功能优先放入设置弹窗
8. **节假日数据**：更新 `holidays2026` 常量后需清除本地缓存才能生效
9. **通知方案**：使用 PowerShell Toast + Dialog 回退，不要依赖外部 Flutter 插件
10. **强制弹窗逻辑**：Dialog 弹出前必须调用 `windowManager.show()` + `focus()` + `setAlwaysOnTop(true)`

## 相关文档

- [README.md](./README.md) - 项目介绍和使用说明
- [PLAN_20260922.md](./PLAN_20260922.md) - 实现计划
- [Flutter 官方文档](https://docs.flutter.dev/)
- [Windows API 文档](https://docs.microsoft.com/windows/win32/)
