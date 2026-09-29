import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 日志服务：将调试信息写入文件
class LogService {
  static String? _logPath;

  /// 初始化日志文件
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/CatSleep/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    _logPath = '${logDir.path}/debug_$timestamp.log';
    await File(_logPath!).writeAsString(
      '=== Log started at ${DateTime.now().toIso8601String()} ===\n',
    );
  }

  /// 写入日志（直接文件追加，不依赖 IOSink 避免 fire-and-forget 损坏状态）
  static Future<void> write(String message) async {
    if (_logPath == null) return;
    try {
      final timestamp = DateTime.now().toIso8601String().split('T')[1].split('.')[0];
      await File(_logPath!).writeAsString(
        '[$timestamp] $message\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // 日志写入失败不应影响业务逻辑
    }
  }

  /// 获取最新日志文件路径
  static Future<String?> getLatestLogPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/CatSleep/logs');
    if (!await logDir.exists()) return null;

    final files = await logDir.list().toList();
    if (files.isEmpty) return null;

    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files.first.path;
  }
}
