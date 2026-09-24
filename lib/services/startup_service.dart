import 'windows_service.dart';

/// 开机自启管理服务
class StartupService {
  static bool _isEnabled = false;

  /// 检查当前自启状态
  static Future<bool> checkStatus() async {
    _isEnabled = await WindowsService.hasStartupShortcut();
    return _isEnabled;
  }

  /// 是否已启用
  static bool get isEnabled => _isEnabled;

  /// 启用自启
  static Future<bool> enable() async {
    final success = await WindowsService.createStartupShortcut();
    if (success) {
      _isEnabled = true;
    }
    return success;
  }

  /// 禁用自启
  static Future<bool> disable() async {
    final success = await WindowsService.removeStartupShortcut();
    if (success) {
      _isEnabled = false;
    }
    return success;
  }

  /// 切换自启状态
  static Future<bool> toggle() async {
    if (_isEnabled) {
      return await disable();
    } else {
      return await enable();
    }
  }
}
