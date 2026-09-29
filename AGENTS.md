# AGENTS.md - AI Agent 协作指南

本文档为 AI 编码助手提供项目上下文和协作规范。

## 项目概述

**猫猫睡觉 (CatSleep)** 是一款 Flutter Windows 桌面定时关机客户端，核心特性：
- 6 种系统操作（关机/重启/注销/休眠/睡眠/锁定）+ 第 7 种任务类型「提醒」
- **提醒任务**：支持多个定时提醒，时间到达时弹出强制对话框（即使应用最小化到托盘）
- 智能工作日判断（2026 官方放假安排 + 本地缓存 + 用户覆盖）
- 开机自启（startup 文件夹快捷方式，支持自定义图标）
- 系统托盘常驻 + 白天/夜间主题切换
- 动态图标选择（26 种动物图标）
- **极简现代 UI**：主界面只展示状态，所有设置收纳到「新建任务」和「系统设置」两个独立弹窗
- **强制通知方案**：先弹出主界面，再弹出 Flutter Dialog，确保托盘状态下也能弹出（不使用 Windows Toast）
- **关闭窗口 = 收进托盘**：依赖 `windowManager.setPreventClose(true)`，否则引擎会被销毁、所有定时器静默失效

## 技术栈

| 层级 | 技术 | 版本 |
|------|------|------|
| 框架 | Flutter | 3.44.5 |
| 语言 | Dart | 3.12.2 |
| 原生层 | C++ (Windows API) | MSVC 2022 |
| 构建工具 | Visual Studio Build Tools | 17.x |

## 架构决策

### 极简 UI 设计
主界面只展示核心信息（渐变状态卡片 + 操作按钮 + 后续执行时间线），所有配置收纳到两个独立弹窗：`CreateTaskDialog`（新建任务）和 `SystemSettingsDialog`（系统设置）。

**Why:** 用户要求现代极简风格（Raycast/Notion/Arc 参考），不接受表单堆砌。2026-09-22 用户明确要求把原来的多 Tab 合并设置弹窗拆成两个独立弹窗，`lib/widgets/settings_dialog.dart` 和 `lib/widgets/task_type_grid.dart` 已不存在。

**How to apply:** 任务相关配置放进 `CreateTaskDialog`（按 `scheduleMode` 联动显示），全局/系统类配置放进 `SystemSettingsDialog`；不要往主界面添加更多控件，也不要恢复 Tab 结构。

### 单任务模式
应用一次只管理一个**系统操作**任务（关机/重启/注销/休眠/睡眠/锁定）。设置新任务时自动取消旧任务。

**Why:** 用户确认的设计选择，简化交互逻辑。注意"单任务"指**同时只有一个**，不是"只执行一次"。

**How to apply:**
- `SchedulerService` 全局只维护一个 `Timer`，`startTask()` 开头会先 `_timer?.cancel()`
- **周期任务执行后必须重排期**：`ScheduleMode.workday` 和 `ScheduleMode.specificTime`（每天/每周/每月）都是周期任务，`_executeTask()` 用 `_isRecurring(config)` 分流——周期任务走 `_reschedule(config)` 重新装 Timer，只有 `ScheduleMode.countdown` 和 `TaskType.remind` 走 `_clearTask()`。早期版本无条件清空状态，导致周期任务执行一次就消失（但 `task_config.json` 还在，重启后又"复活"一次），用户看到的现象就是"任务没有执行"
- `WindowsService.executeTask()` 必须包 try/catch：单次原生调用失败不能让周期任务连带消失
- `_calculateNextTrigger()` 的推进循环有 `_maxSearchSteps = 500` 上限，防止"每周频率但 weekDays 不含目标星期几 + workdayOnly"这类矛盾配置死循环、永久卡住 `startTask()`

### TaskConfig 是可变的，且 UI 与调度器共享同一实例
`HomeScreenState._config` 和 `SchedulerService._currentConfig` 指向**同一个 TaskConfig 对象**（`startTask(_config)` 存的是引用）。

**Why:** 早期 `_openCreateTask()` 开头执行 `setState(() => _config.scheduleMode = ScheduleMode.countdown)`，就地改掉了正在运行的任务配置。后果链：工作日 23:30 关机任务 → 用户点一次「新建任务」再取消 → 运行中的配置被静默改成 countdown → 托盘「退出」时 `saveTaskConfig(_scheduler.currentConfig!)` 把错误模式写盘 → 下次启动变成"当前时间 + 1小时30分"，用户设定的 23:30 永远不会执行。

**How to apply:**
- 给弹窗准备初始配置时永远构造**新的** `TaskConfig`（`tempConfig`），把默认值写在构造参数里，绝不 `setState` 改 `_config` 的字段
- `weekDays` 要用 `List.from(_config.weekDays)` 复制——默认值 `const [1,2,3,4,5]` 是不可变列表，`CreateTaskDialog` 里对它 `.remove()` 会抛异常
- 改完配置必须重新 `startTask()` 才生效，光 `saveTaskConfig()` 不影响已装好的 Timer

### 提醒任务多任务模式
提醒任务（`TaskType.remind`）支持多个任务并存，每个任务独立计时。

**Why:** 用户需要多个独立的提醒时间点，不同于关机/重启等系统操作的单任务模式。

**How to apply:** 
- `RemindTaskService` 全局单例管理所有提醒任务的定时器列表
- 每个提醒任务创建独立的 `Timer`
- 触发后自动从列表中删除（一次性提醒）
- 时间固定化：创建时将相对时间转换为绝对时间（秒数归零），避免应用重启后顺延

### 通知方案（强制弹窗）
采用 **先弹出主界面 → 再弹出 Flutter Dialog** 的方案，**不使用 Windows Toast**。

**Why:** Windows Toast 要求开始菜单里存在带 `System.AppUserModel.ID` 的快捷方式，本项目只创建桌面/Startup 快捷方式且从未写入 AUMID，`CreateToastNotifier('CatSleep')` 必然抛异常。更糟的是早期 PowerShell 脚本用 `catch { # Silent fail }` 吞掉异常，退出码恒为 0，Dart 侧据此判定"Toast 成功"并直接 return，**Dialog 回退永远不触发**——日志写着成功、用户什么都看不到，这个 bug 从 9/23 持续到 9/29。此外每次尝试 Toast 要空跑约 1 秒 PowerShell 冷启动，纯延迟无收益。2026-09-29 用户明确指示"砍掉 Toast 步骤"、"c++侧的死代码也删除"，Toast 相关代码（Dart + C++ `showNotification` handler）已全部移除，**不要复活**。

**How to apply:**
1. `NotificationService.showNotification()` 直接调用 `_showDialog()`，中间不加任何 Toast/PowerShell 分支
2. `_showDialog()` 第一步 `await _bringMainWindowToFront()`：
   - `if (await windowManager.isMinimized()) await windowManager.restore()` —— 只 `show()` 不够，最小化态必须先还原
   - `show()` → `focus()` → `setAlwaysOnTop(true)`
   - 轮询 `isVisible()` 最多 500ms（10 × 50ms），确认主窗口真的显示
   - 再 `Future.delayed(150ms)` 留一帧给主界面绘制
3. 第二步取 `_context`，**`context.mounted` 检查必须紧贴 `showDialog`**（中间不能再有 await，否则触发 `use_build_context_synchronously`）
4. Dialog 设置 `barrierDismissible: false` 防止误触关闭
5. 点击"确定"后恢复 `setAlwaysOnTop(false)`
6. 日志锚点按顺序核对：`Showing notification` → `Main window front: visible=true` → `Main window shown, opening Dialog`

**关键文件：**
- `lib/services/notification_service.dart` - 核心通知服务
- `lib/services/remind_task_service.dart` - 提醒任务管理
- `lib/screens/home_screen.dart` - 设置通知上下文（`NotificationService.setContext(context)`）

### 窗口关闭与定时器存活
`main()` 中 `windowManager.ensureInitialized()` 之后**必须**紧跟 `await windowManager.setPreventClose(true)`。

**Why:** window_manager 0.4.x 的 Windows 实现收到 WM_CLOSE 时只 `_EmitEvent("close")`，仅当 `IsPreventClose()` 为真才 `return -1` 阻止关闭，默认 `is_prevent_close_ = false`（`window_manager.cpp:78`）。而 `main.cpp` 又调用了 `window.SetQuitOnClose(false)`。两者叠加：点 X → WM_CLOSE 走 DefWindowProc → `DestroyWindow` → `FlutterWindow::OnDestroy()` 把 `flutter_controller_` 置空（**引擎与 Dart isolate 一起销毁**）→ 但 `quit_on_close_==false` 不 `PostQuitMessage` → **进程和托盘图标还在，所有 Timer 已死**。表现就是"提醒不弹、任务不执行"，且日志毫无痕迹。Dart 的 `onWindowClose()` 里调 `hide()` 是异步 platform channel，来不及阻止 WM_CLOSE 默认处理。

**How to apply:** 改动窗口关闭/最小化逻辑时必须确认 `setPreventClose(true)` 还在。取 `HomeScreenState` 要用 `GlobalKey<HomeScreenState>`，**不能**用 `Builder` + `context.findAncestorStateOfType<HomeScreenState>()`——HomeScreen 是 Builder 的子节点，向祖先方向查找永远返回 null（commit 8bc994c 就踩过这个坑，导致暂停/恢复倒计时全是死代码）。

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
极简主界面（`HomeScreenState` 是公开类，供 `main.dart` 用 `GlobalKey<HomeScreenState>` 取用）：状态卡片 + 操作按钮 + 后续执行时间线。顶栏设置按钮打开 `SystemSettingsDialog`，状态卡片上的入口打开 `CreateTaskDialog`。文件内还包含 `_RemindTaskManagerDialog`（提醒任务管理弹窗，未拆成独立文件）。

`_openCreateTask()` 中提醒类型走独立分支：`TaskConfig.fixedRemind(result)` → `StorageService.addRemindTask()` → `RemindTaskService().loadAndStartTasks()` → **直接 return**，不覆盖当前系统操作任务。

### `lib/widgets/create_task_dialog.dart`
新建任务弹窗（480 宽；工作日模式含日历，高度上限 `min(860, 屏幕高 × 0.92)`，其余 560）：
- 操作类型 + 调度方式：图标 + 文字下拉（`lockTaskType: true` 时隐藏操作类型，固定为提醒）
- 提醒类型只允许 `countdown` / `specificTime`，并额外显示"提醒内容"`TextFormField`（为空时禁用确定按钮）
- 倒计时：小时 / 分钟数字输入
- 指定时间：日期时间选择 + 频率（每天/每周/每月，`SegmentedControl` + `ChoiceChip`）
- 工作日：时/分下拉 + "仅在工作日前一晚执行"开关 + `HolidayCalendar`
- 执行日期标记直接读 `YearWorkdayCacheService` 缓存，打开弹窗即刻显示

### `lib/widgets/system_settings_dialog.dart`
系统设置弹窗（非 Tab 结构，单列区块）：提前提醒（分钟）、开机自启、更换图标、重建工作日缓存、节假日管理（`_HolidayManagerDialog`，按年分组、添加/删除自定义日期、底部取消/保存）。

### `lib/widgets/status_card.dart`
渐变背景状态卡片，显示动物图标、倒计时、进度条。无任务时显示空状态并提供新建任务入口。

### `lib/widgets/remind_task_manager_dialog.dart`（已集成到 home_screen.dart）
提醒任务管理弹窗：
- 顶部"新增提醒任务"按钮
- 任务列表按时间从早到晚排序
- 过期任务显示删除线和灰色文字
- 每个任务右侧删除按钮
- 空状态显示"暂无提醒任务"
- 新增/删除后都要调用 `RemindTaskService().loadAndStartTasks()` 重新装载定时器

### `lib/services/notification_service.dart`
通知服务（纯 Flutter 强制弹窗，无 Toast）：
- `setContext(BuildContext)` - 设置通知上下文（在 `HomeScreenState.initState` 中调用）
- `showNotification({title, message})` - 唯一对外入口，直接调 `_showDialog()`
- `_bringMainWindowToFront()` - 还原/显示/聚焦/置顶主窗口，并轮询 `isVisible()` 确认真的显示了
- `_showDialog(title, message)` - 强制 Dialog（`barrierDismissible: false`）

### `lib/services/remind_task_service.dart`
提醒任务管理服务（全局单例）：
- `loadAndStartTasks()` - 先 `cancelAll()` 再加载所有提醒任务并启动定时器；`targetTime == null` 或已过期的任务会**显式记日志**后跳过
- `activeTimerCount` - 已装载的定时器数量（供测试断言）
- `cancelAll()` / `dispose()` - 取消所有定时器
- `_fire(task)` - 触发时调用 `NotificationService.showNotification()`，随后从 `remind_tasks.json` 删除该任务；通知失败也会继续清理，避免残留反复触发

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
C++ 原生层（**源码必须保持纯 ASCII**，中文注释会触发 MSVC C4819 并因 warnings-as-errors 构建失败）：
- `ExecuteCommand()` - 执行系统命令（`cmd.exe /c ...` + `CREATE_NO_WINDOW`）。注意：**返回值被所有调用点丢弃**，且只反映 `CreateProcessW` 是否成功、不反映子进程退出码，因此 Dart 侧永远收到 `Success()`，无法感知命令实际失败
- `CreateStartupShortcut()` / `CreateStartupShortcutWithIcon()` - 启动文件夹快捷方式
- `CreateDesktopShortcut()` / `CreateDesktopShortcutWithIcon()` - 桌面快捷方式
- `SetIconLocation()` - 设置快捷方式图标
- 通道 handler 中已无 `showNotification` 分支（2026-09-29 移除）；`closeProgram` 分支仍在但已无 Dart 调用方，属死代码

## 常见任务

### 添加新的任务类型
1. `lib/models/task_config.dart` 的 `TaskType` 枚举添加（`label` + `method`）
2. `windows/runner/main.cpp` 添加 handler 分支
3. `lib/services/windows_service.dart` 添加封装，并在 `executeTask(method)` 的 switch 里加 case
4. `lib/widgets/create_task_dialog.dart` 的 `_getTaskIcon()` 添加图标
5. 若该类型是周期性的，确认 `SchedulerService._isRecurring()` 的判断覆盖到它

### 添加提醒任务相关功能
1. 在 `lib/models/task_config.dart` 中使用 `TaskType.remind`
2. 通过 `StorageService.loadRemindTasks()` / `saveRemindTasks()` / `addRemindTask()` 管理数据
3. **两个创建入口都必须**先 `TaskConfig.fixedRemind(result)` 把倒计时换算成绝对时间（秒归零），存盘后调用 `RemindTaskService().loadAndStartTasks()` 重新装载定时器；漏掉转换会得到 `targetTime == null` 的任务，被静默丢弃、永不触发
4. 触发时调用 `NotificationService.showNotification(title: '猫猫睡觉提醒', message: ...)`

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
- 主窗口拉起顺序在 `_bringMainWindowToFront()` 中，**不要把它挪到取用 BuildContext 之后**

### 添加新的设置项
1. 任务相关配置加到 `lib/widgets/create_task_dialog.dart`（按 `scheduleMode` 联动的 `_buildTimeConfig()`）
2. 全局/系统类配置加到 `lib/widgets/system_settings_dialog.dart` 的对应区块
3. 在 `TaskConfig` 中添加字段并同步更新 `toJson()` / `fromJson()`
4. 注意 `home_screen.dart` 的 `_openCreateTask()` 里构造 `tempConfig` 时**必须带上新字段**，否则每次打开弹窗都会被重置（`workdayEveOnly` 曾因此丢值）

### 修改 UI 主题
编辑 `lib/theme/app_theme.dart`：
- 主色调：`primaryColor`
- 功能色：`successColor` / `warningColor` / `errorColor`
- 圆角、阴影、间距等在各 Theme 中调整

## 测试建议

### 功能测试
- 设置 1 分钟后"锁定" → 验证 Timer 触发
- 设置每周工作日 23:55 → 验证工作日过滤
- 打开系统设置 → 节假日管理 → 验证日历标注
- 选择动物图标 → 验证托盘和快捷方式同时更新
- 开启自启 → 检查 startup 文件夹快捷方式（含图标）
- 切换主题 → 验证白天/夜间模式
- 重启应用 → 验证配置恢复 + 图标恢复
- **点窗口 X 收进托盘，再从托盘打开** → 验证任务倒计时仍在（`setPreventClose` 回归测试）
- **创建提醒后最小化/收进托盘** → 验证先弹主界面再弹 Dialog
- **周期任务执行一次后** → 验证主界面仍显示任务且下次执行时间已推进

### 自动化测试
```bash
flutter test                       # 单元 + widget 测试
flutter analyze                    # 静态检查
flutter build windows --release    # 编译验证（含 C++）
```
测试目录：`test/models/task_config_test.dart`（序列化 + `fixedRemind`）、`test/services/scheduler_service_test.dart`（执行日计算 + 任务执行/重排期）、`test/services/remind_task_service_test.dart`（定时器装载）、`test/widget/create_task_dialog_test.dart`（弹窗布局）。

## 协作约定

1. **不要修改 Platform Channel 接口**：除非同步更新 Dart 和 C++ 两侧
2. **保持单任务模式**：除提醒任务外，其他任务类型同时只能有一个；但周期任务（工作日/指定时间）执行后必须自动重排下一次
3. **提醒任务多任务模式**：可以创建多个提醒任务，每个独立计时
4. **工作日优先级**：用户覆盖 > 本地缓存/API > 内置数据
5. **主题兼容**：新增 UI 元素必须同时支持白天/夜间模式
6. **本地路径**：不要硬编码绝对路径，使用 `path_provider`
7. **UI 风格**：保持极简设计，任务配置放进 `CreateTaskDialog`，系统配置放进 `SystemSettingsDialog`
8. **节假日数据**：更新 `holidays2026` 常量后需清除本地缓存才能生效
9. **通知方案**：只用 `NotificationService` 的强制 Flutter Dialog，**不要重新引入 Windows Toast / PowerShell / C++ 通知通道**，也不要依赖外部 Flutter 通知插件
10. **强制弹窗顺序**：必须先 `_bringMainWindowToFront()`（`restore()` → `show()` → `focus()` → `setAlwaysOnTop(true)` → 轮询 `isVisible()`）把主界面弹出来，再 `showDialog`
11. **窗口关闭**：`main()` 里必须保留 `await windowManager.setPreventClose(true)`，删掉它会让点 X 销毁 Flutter 引擎、所有定时器静默失效
12. **不要就地修改 `TaskConfig`**：`HomeScreenState._config` 与 `SchedulerService._currentConfig` 是同一对象，改弹窗初值请构造新的 `TaskConfig`

## 相关文档

- [README.md](./README.md) - 项目介绍和使用说明
- [PLAN_20260922.md](./PLAN_20260922.md) - 实现计划
- [Flutter 官方文档](https://docs.flutter.dev/)
- [Windows API 文档](https://docs.microsoft.com/windows/win32/)
