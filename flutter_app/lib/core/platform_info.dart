/// 平台判定工具
///
/// 集中管理跨平台分支判断，避免各处散落 `Platform.is*` 导致新增平台时漏改。
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// 鸿蒙（HarmonyOS NEXT / OpenHarmony，engine 报告的操作系统名为 `ohos`）。
///
/// 注意：ohos Flutter SDK（CPF-Flutter 基线）给 `dart:io` 打了补丁、提供
/// `Platform.isOhos`，但上游官方 SDK 没有这个 getter——直接引用会让
/// Windows/Linux/Android 等平台的 `flutter analyze`/构建直接编译失败。
/// 因此这里统一用 `operatingSystem` 字符串比较，两条 SDK 线下均成立。
bool get isOhosPlatform => !kIsWeb && Platform.operatingSystem == 'ohos';

/// 移动端形态（Android / iOS / 鸿蒙）。
///
/// 影响：附件拍照/相册入口、导出路径落应用文档目录（无系统保存对话框）等。
/// 桌面判定见 [file_dialogs.dart] 的 `isDesktopPlatform`（鸿蒙不在其中）。
bool get isMobileLikePlatform =>
    Platform.isAndroid || Platform.isIOS || isOhosPlatform;
