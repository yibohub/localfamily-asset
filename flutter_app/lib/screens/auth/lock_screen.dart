import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../core/theme.dart';
import '../main/main_navigation_screen.dart';
import 'setup_screen.dart';

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
  bool _showHelp = false;

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
      setState(() {
        _error = '密码错误';
        _showHelp = true;
      });
    }
  }

  /// 显示帮助对话框
  void _showHelpDialog() {
    final authProvider = context.read<AuthProvider>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('忘记密码？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (authProvider.passwordHint != null)
              Text(
                '密码提示：${authProvider.passwordHint}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              )
            else
              const Text('您没有设置密码提示。'),
            const SizedBox(height: 16),
            const Text(
              '如果无法记起密码，可以使用助记词恢复，或重置应用（将删除所有数据）。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showResetConfirmDialog();
            },
            child: const Text(
              '重置应用',
              style: TextStyle(color: Colors.red),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 显示重置确认对话框
  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ 危险操作'),
        content: const Text(
          '重置应用将删除所有资产数据和设置，此操作不可撤销！\n\n确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _resetApp();
            },
            child: const Text('确定重置'),
          ),
        ],
      ),
    );
  }

  /// 重置应用
  Future<void> _resetApp() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.reset();

    if (!mounted) return;

    // 重置后状态变为 setup，需要手动导航到设置页面
    // 由于 LockScreen 可能不在 AuthWrapper 中，需要主动导航
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SetupScreen()),
      (route) => false,
    );
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
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showHelp)
                        IconButton(
                          icon: const Icon(Icons.help_outline),
                          onPressed: _showHelpDialog,
                          tooltip: '忘记密码？',
                        ),
                      IconButton(
                        icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ],
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
              // 帮助链接
              if (!_showHelp)
                TextButton(
                  onPressed: _showHelpDialog,
                  child: const Text('忘记密码？'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
