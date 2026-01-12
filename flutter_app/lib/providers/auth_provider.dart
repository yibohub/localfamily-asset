import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 认证状态枚举
enum AuthStatus { setup, locked, unlocked }

/// 认证状态管理
class AuthProvider with ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _keyHasSetup = 'has_setup';
  static const _keyPasswordHint = 'password_hint';

  AuthStatus _status = AuthStatus.locked;
  String? _passwordHint;

  AuthProvider() {
    _init();
  }

  AuthStatus get status => _status;
  String? get passwordHint => _passwordHint;

  /// 初始化认证状态
  Future<void> _init() async {
    final hasSetup = await _storage.read(key: _keyHasSetup);
    _passwordHint = await _storage.read(key: _keyPasswordHint);

    if (hasSetup == 'true') {
      _status = AuthStatus.locked;
    } else {
      _status = AuthStatus.setup;
    }
    notifyListeners();
  }

  /// 设置初始密码
  Future<bool> setupPassword(String password, {String? hint}) async {
    try {
      // TODO: 调用 Rust Core 设置密码
      await _storage.write(key: _keyHasSetup, value: 'true');
      if (hint != null) {
        await _storage.write(key: _keyPasswordHint, value: hint);
      }
      _status = AuthStatus.unlocked;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Setup password error: $e');
      return false;
    }
  }

  /// 解锁应用
  Future<bool> unlock(String password) async {
    try {
      // TODO: 调用 Rust Core 验证密码
      _status = AuthStatus.unlocked;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Unlock error: $e');
      return false;
    }
  }

  /// 锁定应用
  void lock() {
    _status = AuthStatus.locked;
    notifyListeners();
  }

  /// 修改密码
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      // TODO: 调用 Rust Core 修改密码
      return true;
    } catch (e) {
      debugPrint('Change password error: $e');
      return false;
    }
  }
}
