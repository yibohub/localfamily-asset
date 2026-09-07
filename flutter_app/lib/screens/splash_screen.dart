import 'package:flutter/material.dart';
import 'dart:async';

import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../core/theme.dart';
import 'main/main_navigation_screen.dart';
import 'auth/lock_screen.dart';
import 'auth/setup_screen.dart';

/// 隐财启动页
///
/// 展示品牌 Logo、名称和标语
class SplashScreen extends StatefulWidget {
  /// 测试模式：跳过延迟
  final bool testMode;

  const SplashScreen({super.key, this.testMode = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 测试模式下跳过延迟
    if (!widget.testMode) {
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // 初始化 Rust FFI 和数据库
    try {
      await authProvider.init();
    } catch (e) {
      debugPrint('初始化失败: $e');
    }

    Widget screen;
    switch (authProvider.status) {
      case AuthStatus.setup:
        screen = const SetupScreen();
        break;
      case AuthStatus.locked:
        screen = const LockScreen();
        break;
      case AuthStatus.unlocked:
        screen = const MainNavigationScreen();
        break;
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => screen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A2463), // 深海蓝
              Color(0xFF061842), // 深海蓝暗变
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 品牌 Logo：盾牌 + 锁图标
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.security_rounded,
                  size: 56,
                  color: Color(0xFF0A2463), // 深海蓝
                ),
              ),
              const SizedBox(height: 32),
              // 品牌名称
              const Text(
                AppTheme.appName,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              // 品牌标语
              Text(
                AppTheme.tagline,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 64),
              // 加载指示器 - 使用翡翠绿
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF059669), // 翡翠绿
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
