/// 解析各平台默认导出目录。
///
/// 当用户尚未显式选择导出目录时使用，确保自动记录和保存开箱即可工作。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 在平台基础目录下创建的保存记录子目录。
const String _appFolderName = 'RoboMasterMonitor';

/// [_appFolderName] 下的记录子目录。
const String _recordsFolderName = 'records';

/// 解析当前平台默认导出目录，必要时创建目录，并返回绝对路径。
///
/// 各平台布局：
/// - Android：`<应用外部文件>/RoboMasterMonitor/records`
///   （应用私有外部存储，无需运行时存储权限）。
/// - Windows / Linux / macOS：`<Documents>/RoboMasterMonitor/records`。
///
/// 首选基础目录不可用时回退到应用文档目录。
Future<String> resolveDefaultExportDirectory() async {
  final base = await _resolveBaseDirectory();
  final dir = Directory(
    p.join(base.path, _appFolderName, _recordsFolderName),
  );
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir.path;
}

Future<Directory> _resolveBaseDirectory() async {
  if (Platform.isAndroid) {
    // 应用私有外部存储：文件管理器可见，应用更新后保留，且无需存储权限。
    final external = await getExternalStorageDirectory();
    if (external != null) return external;
  }
  return getApplicationDocumentsDirectory();
}
