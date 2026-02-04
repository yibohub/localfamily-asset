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
        // 加载密码提示
        _passwordHint = await _ffi.getPasswordHint();
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

  /// 使用助记词恢复访问
  Future<bool> recoverWithMnemonic(String mnemonic) async {
    try {
      final success = await _ffi.verifyWithMnemonic(mnemonic);
      if (success) {
        _status = AuthStatus.unlocked;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('助记词恢复失败: $e');
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

  /// 重置应用（删除所有数据）
  ///
  /// 安全流程：
  /// 1. 调用 Rust 端清除内存中的主密钥和状态
  /// 2. 删除数据库文件
  /// 3. 重置应用状态
  Future<void> reset() async {
    try {
      // 步骤1: 先清除 Rust 端的敏感数据（主密钥等）
      final rustResetSuccess = await _ffi.resetApp();
      if (!rustResetSuccess) {
        debugPrint('警告：Rust 端重置失败，可能存在内存泄漏');
      }

      // 步骤2: 删除数据库文件
      if (_dbPath != null) {
        final dbFile = File(_dbPath!);
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
      }

      // 步骤3: 重置状态
      _status = AuthStatus.setup;
      _passwordHint = null;
      notifyListeners();

      debugPrint('应用已重置，所有数据已清除');
    } catch (e) {
      debugPrint('重置应用失败: $e');
      rethrow;
    }
  }
}
