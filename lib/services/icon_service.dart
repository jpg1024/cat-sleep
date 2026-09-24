import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'storage_service.dart';
import 'windows_service.dart';

/// 图标管理服务
class IconService {
  static const String _defaultIcon = 'cat';

  /// 获取当前选中的图标名称
  static Future<String> getCurrentIcon() async {
    final settings = await StorageService.loadSettings();
    return settings['selectedIcon'] ?? _defaultIcon;
  }

  /// 获取持久化的 ICO 文件路径
  static Future<String> getIcoPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/CatSleep');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return '${dir.path}/tray_icon.ico';
  }

  /// 将 PNG 数据包装为 ICO 格式（Windows 10+ 支持 PNG 压缩的 ICO）
  static Uint8List wrapPngAsIco(Uint8List pngData) {
    // PNG IHDR: width(4) + height(4) at offset 16
    final width = _readUint32(pngData, 16);
    final height = _readUint32(pngData, 20);

    final icoSize = 6 + 16 + pngData.length;
    final result = Uint8List(icoSize);
    final bd = ByteData.view(result.buffer);

    // ICO Header
    bd.setUint16(0, 0, Endian.little);   // Reserved
    bd.setUint16(2, 1, Endian.little);   // Type: 1 = ICO
    bd.setUint16(4, 1, Endian.little);   // Count: 1 image

    // Directory Entry
    result[6] = (width >= 256) ? 0 : width;   // Width (0 = 256)
    result[7] = (height >= 256) ? 0 : height;  // Height
    result[8] = 0;    // Color palette
    result[9] = 0;    // Reserved
    bd.setUint16(10, 1, Endian.little);   // Color planes
    bd.setUint16(12, 32, Endian.little);  // Bits per pixel
    bd.setUint32(14, pngData.length, Endian.little);  // Image data size
    bd.setUint32(18, 22, Endian.little);  // Image data offset (6 + 16)

    // Copy PNG data
    result.setRange(22, 22 + pngData.length, pngData);
    return result;
  }

  static int _readUint32(Uint8List data, int offset) {
    return (data[offset] << 24) | (data[offset + 1] << 16) |
           (data[offset + 2] << 8) | data[offset + 3];
  }

  /// 将 PNG 文件转换为 ICO 文件
  static Future<String> _ensureIcoFile(String pngPath) async {
    final icoPath = await getIcoPath();
    try {
      final pngFile = File(pngPath);
      if (!await pngFile.exists()) return icoPath;

      final pngData = await pngFile.readAsBytes();
      final icoData = wrapPngAsIco(Uint8List.fromList(pngData));
      await File(icoPath).writeAsBytes(icoData);
    } catch (_) {}
    return icoPath;
  }

  /// 获取图标文件的绝对路径（PNG）
  static Future<String> _getAbsoluteIconPath(String relativePath) async {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final absPath = '$exeDir\\data\\flutter_assets\\$relativePath';
      if (await File(absPath).exists()) return absPath;
    } catch (_) {}

    try {
      if (await File(relativePath).exists()) {
        return File(relativePath).absolute.path;
      }
    } catch (_) {}

    return relativePath;
  }

  /// 应用图标（仅保存配置，供主界面显示使用）
  static Future<void> applyIcon(String iconName) async {
    // 仅保存配置
    final settings = await StorageService.loadSettings();
    settings['selectedIcon'] = iconName;
    await StorageService.saveSettings(settings);
  }

  /// 初始化图标（应用启动时调用）
  static Future<void> initIcon() async {
    // 无需初始化，主界面直接读取配置
    // 桌面快捷方式由 C++ 层在首次安装时创建，后续不再修改
  }

  /// 获取所有可用的图标列表
  static List<String> getAvailableIcons() {
    return [
      'albatross', 'cat', 'dog', 'eagle', 'elephant',
      'giraffe', 'grouse', 'heron', 'hippo', 'hummingbird',
      'kangaroo', 'lion', 'mandarin_duck', 'monkey', 'orangutan',
      'ostrich', 'otter', 'panda', 'parrot', 'penguin',
      'red_panda', 'seagull', 'seal', 'swan', 'tiger', 'woodpecker',
    ];
  }
}
