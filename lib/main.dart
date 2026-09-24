import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'services/scheduler_service.dart';
import 'services/storage_service.dart';
import 'services/icon_service.dart';
import 'services/windows_service.dart';
import 'services/year_workday_cache_service.dart';
import 'services/log_service.dart';
import 'services/remind_task_service.dart';
import 'services/notification_service.dart';
import 'models/task_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // 初始化日志服务
  await LogService.init();
  await LogService.write('App starting...');

  // 初始化全年工作日缓存（当前年+下一年）
  final currentYear = DateTime.now().year;
  await LogService.write('Initializing workday cache for years: $currentYear, ${currentYear + 1}');
  await YearWorkdayCacheService.initializeMultiYear([currentYear, currentYear + 1]);
  await LogService.write('Workday cache initialized');

  // min window size 500x950
  const minSize = Size(500, 950);
  WindowOptions windowOptions = WindowOptions(
    size: const Size(670, 950),
    minimumSize: minSize,
    center: true,
    title: '\u732b\u732b\u7761\u89c9',
    titleBarStyle: TitleBarStyle.normal,
  );
  // init tray (use default cat icon)
  await _initTray();

  // 创建桌面快捷方式和设置窗口图标（固定使用 cat.png，需转换为 ICO）
  try {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final pngPath = '$exeDir\\data\\flutter_assets\\assets\\animals\\cat.png';
    
    if (await File(pngPath).exists()) {
      // 将 PNG 转换为 ICO
      final icoPath = await IconService.getIcoPath();
      final pngData = await File(pngPath).readAsBytes();
      final icoData = IconService.wrapPngAsIco(pngData);
      await File(icoPath).writeAsBytes(icoData);
      
      // 创建桌面快捷方式（使用 ICO）
      await WindowsService.createDesktopShortcutWithIcon(icoPath);
      
      // 设置窗口图标在窗口显示后执行
    }
  } catch (_) {}

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    
    // 设置窗口左上角图标（固定使用 cat.png 转换的 ICO）
    try {
      final icoPath = await IconService.getIcoPath();
      if (await File(icoPath).exists()) {
        await WindowsService.setWindowIcon(icoPath);
      }
    } catch (_) {}
  });

  runApp(const CatSleepApp());
}

Future<void> _initTray() async {
  // 托盘图标固定使用 cat.png（需转换为 ICO，因为 tray_manager Windows 底层使用 LoadImageW）
  try {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final pngPath = '$exeDir\\data\\flutter_assets\\assets\\animals\\cat.png';
    
    if (await File(pngPath).exists()) {
      // 将 PNG 转换为 ICO
      final icoPath = await IconService.getIcoPath();
      final pngData = await File(pngPath).readAsBytes();
      final icoData = IconService.wrapPngAsIco(pngData);
      await File(icoPath).writeAsBytes(icoData);
      
      // 使用 ICO 路径设置托盘图标
      await trayManager.setIcon(icoPath);
    } else {
      // 降级：尝试相对路径
      await trayManager.setIcon('assets/animals/cat.png');
    }
  } catch (_) {
    // 最终降级
    try {
      await trayManager.setIcon('assets/animals/cat.png');
    } catch (_) {}
  }

  // 托盘菜单使用中文
  final menu = Menu(items: [
    MenuItem(key: 'show', label: '打开主窗口'),
    MenuItem.separator(),
    MenuItem(key: 'cancel', label: '取消任务'),
    MenuItem.separator(),
    MenuItem(key: 'exit', label: '退出'),
  ]);
  await trayManager.setContextMenu(menu);
}

class CatSleepApp extends StatefulWidget {
  const CatSleepApp({super.key});

  @override
  State<CatSleepApp> createState() => _CatSleepAppState();
}

class _CatSleepAppState extends State<CatSleepApp> with TrayListener, WindowListener {
  final SchedulerService _scheduler = SchedulerService();
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    _loadThemeMode();
    // 延迟加载提醒任务，等待 build 完成以设置通知上下文
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 再延迟一帧确保 MaterialApp.build 已执行
      WidgetsBinding.instance.addPostFrameCallback((__) {
        _loadRemindTasks();
      });
    });
  }

  /// 加载所有提醒任务并启动定时器
  Future<void> _loadRemindTasks() async {
    await RemindTaskService().loadAndStartTasks();
  }

  /// 公开方法：供外部调用以重新加载提醒任务
  Future<void> reloadRemindTasks() async {
    await RemindTaskService().loadAndStartTasks();
  }

  Future<void> _loadThemeMode() async {
    final settings = await StorageService.loadSettings();
    setState(() {
      _isDarkMode = settings['isDarkMode'] ?? false;
    });
  }

  Future<void> _saveThemeMode() async {
    final settings = await StorageService.loadSettings();
    settings['isDarkMode'] = _isDarkMode;
    await StorageService.saveSettings(settings);
  }

  void _toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
    _saveThemeMode();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    _scheduler.dispose();
    super.dispose();
  }

  @override
  void onWindowMinimize() {
    windowManager.hide();
  }

  @override
  void onWindowClose() {
    windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
        break;
      case 'cancel':
        await _scheduler.cancelTask();
        await StorageService.deleteTaskConfig();
        break;
      case 'exit':
        if (_scheduler.currentConfig != null) {
          await StorageService.saveTaskConfig(_scheduler.currentConfig!);
        }
        trayManager.destroy();
        exit(0);
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setAlwaysOnTop(false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '\u732b\u732b\u7761\u89c9',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN')],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeScreen(
        scheduler: _scheduler,
        onThemeToggle: _toggleTheme,
        isDarkMode: _isDarkMode,
      ),
    );
  }
}
