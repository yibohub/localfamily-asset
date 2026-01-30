import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../core/theme.dart';
import '../main/main_navigation_screen.dart';

/// 隐财锁定屏幕
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.unlock(_passwordController.text);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } else {
      setState(() => _error = '密码错误');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 品牌 Logo 图标 - 使用品牌深海蓝
              Icon(
                Icons.lock_rounded,
                size: 80,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 24),
              // 品牌名称
              Text(
                AppTheme.appName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // 品牌标语
              Text(
                AppTheme.tagline,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '请输入密码以解锁',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
              if (authProvider.passwordHint != null) ...[
                const SizedBox(height: 16),
                Text(
                  '提示: ${authProvider.passwordHint}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 48),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: '密码',
                  errorText: _error,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                onSubmitted: (_) => _unlock(),
                autofocus: true,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _unlock,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('解锁'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
