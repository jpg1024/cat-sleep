import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'workday_service.dart';
import 'storage_service.dart';
import 'log_service.dart';

/// 全年工作日缓存服务
/// 
/// 在应用启动时预计算全年所有日期的工作日状态，避免新建任务时重复异步IO调用。
/// 缓存结果持久化到JSON文件，通过配置哈希值检测节假日配置变化。
class YearWorkdayCacheService {
  static const String _cacheFilePrefix = 'year_workday_cache_';
  static final Map<int, Map<String, dynamic>> _cacheDataMap = {};
  
  /// 初始化指定年份的缓存（应用启动时调用）
  /// 
  /// 优先从JSON文件读取缓存，如果文件不存在、格式错误或配置已变更，则重新计算。
  static Future<void> initialize(int year) async {
    final configHash = await _computeConfigHash();
    final cacheFile = await StorageService.loadJson('$_cacheFilePrefix$year');
    
    if (cacheFile != null && 
        cacheFile['year'] == year && 
        cacheFile['configHash'] == configHash) {
      // 缓存有效，直接读取
      _cacheDataMap[year] = cacheFile;
      print('[YearWorkdayCache] Loaded from cache for year $year');
    } else {
      // 缓存失效或不存在，重新计算
      await _rebuildCache(year, configHash);
      print('[YearWorkdayCache] Rebuilt cache for year $year');
    }
  }
  
  /// 初始化多年份缓存（当前年+下一年）
  static Future<void> initializeMultiYear(List<int> years) async {
    for (final year in years) {
      await initialize(year);
    }
  }
  
  /// 确保指定年份的缓存已初始化
  /// 
  /// 当用户添加未来年份的节假日数据时调用
  static Future<void> ensureYearInitialized(int year) async {
    if (!_cacheDataMap.containsKey(year)) {
      await initialize(year);
    }
  }
  
  /// 获取指定年份的所有工作日
  static Future<Set<DateTime>> getAllWorkdays(int year) async {
    if (!_cacheDataMap.containsKey(year)) {
      await LogService.write('[YearWorkdayCache] ERROR: getAllWorkdays($year) failed, cache not initialized. Current years in cache: ${_cacheDataMap.keys.toList()}');
      throw Exception('Cache for year $year not initialized. Call initialize() first.');
    }

    return (_cacheDataMap[year]!['allWorkdays'] as List)
        .map((s) => DateTime.parse(s))
        .toSet();
  }

  /// 获取指定年份"仅在次日为工作日的当天晚上执行"的日期集合
  static Future<Set<DateTime>> getEveOnlyDates(int year) async {
    if (!_cacheDataMap.containsKey(year)) {
      await LogService.write('[YearWorkdayCache] ERROR: getEveOnlyDates($year) failed, cache not initialized. Current years in cache: ${_cacheDataMap.keys.toList()}');
      throw Exception('Cache for year $year not initialized. Call initialize() first.');
    }

    return (_cacheDataMap[year]!['eveOnlyDates'] as List)
        .map((s) => DateTime.parse(s))
        .toSet();
  }
  
  /// 使指定年份的缓存失效
  static void invalidateYear(int year) {
    _cacheDataMap.remove(year);
    print('[YearWorkdayCache] Cache invalidated for year $year');
  }
  
  /// 使所有年份的缓存失效（用户修改节假日设置时调用）
  static void invalidate() {
    _cacheDataMap.clear();
    print('[YearWorkdayCache] All caches invalidated (memory only)');
  }
  
  /// 使所有年份的缓存失效并删除JSON文件（强制重新计算）
  static Future<void> invalidateAndDeleteFiles() async {
    await LogService.write('[YearWorkdayCache] invalidateAndDeleteFiles called. Current years: ${_cacheDataMap.keys.toList()}');
    _cacheDataMap.clear();
    await LogService.write('[YearWorkdayCache] Memory cache cleared');
    
    // 删除所有年份的缓存文件
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/CatSleep');
    if (await cacheDir.exists()) {
      await for (final file in cacheDir.list()) {
        if (file.path.contains('year_workday_cache_') && file.path.endsWith('.json')) {
          try {
            await file.delete();
            await LogService.write('[YearWorkdayCache] Deleted cache file: ${file.path}');
          } catch (e) {
            await LogService.write('[YearWorkdayCache] Failed to delete ${file.path}: $e');
          }
        }
      }
    }
    
    await LogService.write('[YearWorkdayCache] All caches invalidated and files deleted');
  }
  
  /// 计算当前配置的哈希值
  /// 
  /// 当用户自定义日期、添加/移除工作日或节假日缓存发生变化时，哈希值会改变。
  static Future<String> _computeConfigHash() async {
    try {
      final config = await WorkdayService.getConfig();
      final cache = WorkdayService.holidayCache ?? {};
      
      final combined = {
        'customDates': config.customDates,
        'addedWorkdays': config.addedWorkdays,
        'removedWorkdays': config.removedWorkdays,
        'holidayCache': cache,
      };
      
      final jsonString = jsonEncode(combined);
      return md5.convert(utf8.encode(jsonString)).toString();
    } catch (e) {
      // 如果无法获取配置，返回空哈希
      return md5.convert(utf8.encode('{}')).toString();
    }
  }
  
  /// 重新构建缓存
  static Future<void> _rebuildCache(int year, String configHash) async {
    final allWorkdays = <DateTime>{};
    final eveOnlyDates = <DateTime>{};
    
    print('[YearWorkdayCache] Computing workdays for year $year...');
    
    for (int month = 1; month <= 12; month++) {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        final isWorkday = await WorkdayService.isWorkday(date);
        
        // 调试：记录10月23日的判断结果
        if (month == 10 && day == 23) {
          await LogService.write('[YearWorkdayCache] 2026-10-23 isWorkday=$isWorkday');
        }

        if (isWorkday) {
          allWorkdays.add(date);
        }

        // 检查次日是否为工作日（用于workdayEveOnly模式）
        final tomorrow = date.add(const Duration(days: 1));
        if (await WorkdayService.isWorkday(tomorrow)) {
          eveOnlyDates.add(date);
        }
      }
    }
    
    final cacheData = {
      'year': year,
      'configHash': configHash,
      'allWorkdays': allWorkdays.map((d) => _formatDate(d)).toList(),
      'eveOnlyDates': eveOnlyDates.map((d) => _formatDate(d)).toList(),
      'cachedAt': DateTime.now().toIso8601String(),
    };
    
    _cacheDataMap[year] = cacheData;
    await StorageService.saveJson('$_cacheFilePrefix$year', cacheData);
    print('[YearWorkdayCache] Cache saved for year $year: ${allWorkdays.length} workdays, ${eveOnlyDates.length} eve-only dates');
  }
  
  static String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
