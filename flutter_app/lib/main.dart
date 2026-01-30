library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/app.dart';
import 'providers/asset_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/custom_type_provider.dart';
import 'providers/theme_provider.dart';

/// 隐财 (Yincai) - 本地加密的家庭资产登记管理工具
///
/// 品牌标语：你的资产，只有你知道
/// 产品性质：资产登记管理工具（非理财产品）
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器（隐藏系统标题栏）
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // 隐藏系统标题栏
    windowButtonVisibility: true, // 保留最小化/最大化/关闭按钮
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 设置系统UI样式 - 使用品牌深海蓝
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFFAF9F5), // 品牌米白
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AssetProvider()),
        ChangeNotifierProvider(create: (_) => CustomTypeProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const YincaiApp(),
    ),
  );
}
