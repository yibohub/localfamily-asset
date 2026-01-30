import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'theme.dart';
import '../screens/splash_screen.dart';
import '../screens/main/main_navigation_screen.dart';
import '../screens/auth/lock_screen.dart';
import '../screens/auth/setup_screen.dart';

/// 隐财应用程序根组件
class YincaiApp extends StatelessWidget {
  const YincaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'Yincai', // 使用英文标题避免任务栏乱码
          debugShowCheckedModeBanner: false,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          locale: const Locale('zh', 'CN'),
          home: const SplashScreen(),
        );
      },
    );
  }
}

/// 认证包装器 - 根据认证状态导航
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    switch (authProvider.status) {
      case AuthStatus.locked:
        return const LockScreen();
      case AuthStatus.unlocked:
        return const MainNavigationScreen();
      case AuthStatus.setup:
        return const SetupScreen();
    }
  }
}
