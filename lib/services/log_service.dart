import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 日志服务：将调试信息写入文件
class LogService {
  static File? _logFile;
  static IOSink? _logSink;

  /// 初始化日志文件
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/CatSleep/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    _logFile = File('${logDir.path}/debug_$timestamp.log');
    _logSink = _logFile!.openWrite(mode: FileMode.append);

    _logSink!.writeln('=== Log started at ${DateTime.now().toIso8601String()} ===');
    await _logSink!.flush();
  }

  /// 写入日志
  static Future<void> write(String message) async {
    if (_logSink == null) return;

    final timestamp = DateTime.now().toIso8601String().split('T')[1].split('.')[0];
    _logSink!.writeln('[$timestamp] $message');
    await _logSink!.flush();
  }

  /// 关闭日志文件
  static Future<void> close() async {
    if (_logSink != null) {
      await _logSink!.flush();
      await _logSink!.close();
      _logSink = null;
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
