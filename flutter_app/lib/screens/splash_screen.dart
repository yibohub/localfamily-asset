import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'auth/lock_screen.dart';
import 'auth/setup_screen.dart';

/// 启动页
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
        screen = const HomeScreen();
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              '本地家庭资产管理器',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
