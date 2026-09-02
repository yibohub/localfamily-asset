import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 是否为桌面平台（Windows/Linux/macOS）
bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// 为导出数据选择一个可写的目标路径。
///
/// - 桌面端：弹出系统保存对话框，由用户选择位置。
/// - 移动端：FilePicker 的 saveFile 不受支持，直接落到应用文档目录，
///   文件名固定为带时间戳的备份包。
///
/// 返回 null 表示用户取消（桌面端）或获取目录失败。
Future<String?> pickExportPath() async {
  if (isDesktopPlatform) {
    return FilePicker.platform.saveFile(
      dialogTitle: '选择导出文件保存位置',
      fileName: 'localfamily_asset_backup.zip',
      type: FileType.any,
    );
  }

  try {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    return '${dir.path}/localfamily_asset_backup_$ts.zip';
  } catch (e) {
    return null;
  }
}
