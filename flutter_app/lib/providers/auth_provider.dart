import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../core/ffi_bridge.dart';

/// 认证状态枚举
enum AuthStatus {
  setup,      // 首次设置密码
  locked,     // 已锁定
  unlocked    // 已解锁
}

/// 认证状态管理
class AuthProvider with ChangeNotifier {
  AuthStatus _status = AuthStatus.setup;
  String? _passwordHint;
  final FfiBridge _ffi = FfiBridge();
  String? _dbPath;

  AuthStatus get status => _status;
  String? get passwordHint => _passwordHint;
  bool get isUnlocked => _status == AuthStatus.unlocked;
  bool get isSetup => _status == AuthStatus.setup;
  bool get isLocked => _status == AuthStatus.locked;

  /// 初始化认证状态
  Future<void> init() async {
    try {
      // 获取应用数据目录
      final appDir = await getApplicationDocumentsDirectory();
      _dbPath = '${appDir.path}/localfamily_asset.db';

      // 初始化 Rust Core
      await _ffi.initApp(_dbPath!);

      // 检查数据库文件是否存在，判断是否需要设置密码
      final dbFile = File(_dbPath!);
      if (await dbFile.exists()) {
        _status = AuthStatus.locked;
      } else {
        _status = AuthStatus.setup;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('初始化认证状态失败: $e');
      _status = AuthStatus.setup;
      notifyListeners();
    }
  }

  /// 设置初始密码
  Future<bool> setupPassword(String password, {String? hint}) async {
    try {
      final success = await _ffi.setupPassword(password, hint: hint);
      if (success) {
        _passwordHint = hint;
        _status = AuthStatus.unlocked;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('设置密码失败: $e');
      return false;
    }
  }

  /// 解锁应用
  Future<bool> unlock(String password) async {
    try {
      final success = await _ffi.verifyPassword(password);
      if (success) {
        _status = AuthStatus.unlocked;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('解锁失败: $e');
      return false;
    }
  }

  /// 锁定应用
  void lock() {
    if (_status == AuthStatus.unlocked) {
      _status = AuthStatus.locked;
      notifyListeners();
    }
  }

  /// 修改密码
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      // 先验证旧密码
      final verified = await _ffi.verifyPassword(oldPassword);
      if (!verified) {
        return false;
      }

      // 设置新密码
      final success = await _ffi.setupPassword(newPassword);
      return success;
    } catch (e) {
      debugPrint('修改密码失败: $e');
      return false;
    }
  }
}
