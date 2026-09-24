import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/task_config.dart';
import '../models/workday_config.dart';

/// 本地存储服务
class StorageService {
  static const String _taskFileName = 'task_config.json';
  static const String _remindTasksFileName = 'remind_tasks.json';
  static const String _workdayFileName = 'workday_config.json';
  static const String _settingsFileName = 'settings.json';
  static const String _holidayCacheFileName = 'holiday_cache.json';

  static Directory? _appDir;

  /// 获取应用数据目录
  static Future<Directory> _getAppDir() async {
    _appDir ??= await getApplicationDocumentsDirectory();
    final dir = Directory('${_appDir!.path}/CatSleep');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ========== 提醒任务列表 ==========

  static Future<List<TaskConfig>> loadRemindTasks() async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$_remindTasksFileName');
    if (!await file.exists()) return [];
    
    try {
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((json) => TaskConfig.fromJson(json)).toList();
    } catch (e) {
      print('[StorageService] Failed to load remind tasks: $e');
      return [];
    }
  }

  static Future<void> saveRemindTasks(List<TaskConfig> tasks) async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$_remindTasksFileName');
    final jsonList = tasks.map((t) => t.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  static Future<void> addRemindTask(TaskConfig task) async {
    final tasks = await loadRemindTasks();
    tasks.add(task);
    await saveRemindTasks(tasks);
  }

  static Future<void> deleteRemindTask(int index) async {
    final tasks = await loadRemindTasks();
    if (index >= 0 && index < tasks.length) {
      tasks.removeAt(index);
      await saveRemindTasks(tasks);
    }
  }

  // ========== 任务配置 ==========

  static Future<void> saveTaskConfig(TaskConfig config) async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$_taskFileName');
    await file.writeAsString(jsonEncode(config.toJson()));
  }

  static Future<TaskConfig?> loadTaskConfig() async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$_taskFileName');
    if (await file.exists()) {
      final content = await file.readAsString();
      return TaskConfig.fromJson(jsonDecode(content));
    }
    return null;
  }

  static Future<void> deleteTaskConfig() async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$_taskFileName');
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ========== 工作日配置 ==========

  static Future<void> saveWorkdayConfig(WorkdayConfig config) async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$_workdayFileName');
    await file.writeAsString(jsonEncode(config.toJson()));
  }

  static Future<WorkdayConfig> loadWorkdayConfig() async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$_workdayFileName');
    if (await file.exists()) {
      final content = await file.readAsString();
      return WorkdayConfig.fromJson(jsonDecode(content));
    }
    return WorkdayConfig();
  }

  // ========== 应用设置 ==========

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$_settingsFileName');
    await file.writeAsString(jsonEncode(settings));
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$_settingsFileName');
    if (await file.exists()) {
      final content = await file.readAsString();
      return jsonDecode(content);
    }
    return {};
  }

  // ========== 节假日缓存 ==========

  static Future<void> saveHolidayCache(Map<String, dynamic> cache) async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$_holidayCacheFileName');
    await file.writeAsString(jsonEncode(cache));
  }

  static Future<Map<String, dynamic>?> loadHolidayCache() async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$_holidayCacheFileName');
    if (await file.exists()) {
      final content = await file.readAsString();
      return jsonDecode(content);
    }
    return null;
  }

  // ========== 通用 JSON 读写（供缓存服务使用） ==========

  /// 保存任意 JSON 数据到指定文件
  static Future<void> saveJson(String fileName, Map<String, dynamic> data) async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$fileName.json');
    await file.writeAsString(jsonEncode(data));
  }

  /// 从指定文件加载 JSON 数据
  /// 
  /// 如果文件不存在或格式错误，返回 null。
  static Future<Map<String, dynamic>?> loadJson(String fileName) async {
    final dir = await _getAppDir();
    final file = File('${dir.path}/$fileName.json');
    if (!await file.exists()) return null;
    
    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      // 文件格式错误，返回 null 触发重新计算
      print('[StorageService] Failed to load $fileName.json: $e');
      return null;
    }
  }
}
