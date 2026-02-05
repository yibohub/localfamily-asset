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

  /// 重置密码（已解锁状态下使用，无需旧密码）
  ///
  /// 适用场景：
  /// - 助记词恢复后设置新密码
  /// - 设置页面中的"修改密码"功能
  Future<bool> resetPassword(String newPassword, {String? hint}) async {
    try {
      // 必须在已解锁状态下才能重置密码
      if (_status != AuthStatus.unlocked) {
        debugPrint('重置密码失败：应用未解锁');
        return false;
      }

      final success = await _ffi.setupPassword(newPassword, hint: hint);
      if (success) {
        _passwordHint = hint;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('重置密码失败: $e');
      return false;
    }
  }

  /// 重置应用（删除所有数据）
  ///
  /// 安全流程：
  /// 1. Rust 端先清空数据库中的所有数据（防止文件删除失败）
  /// 2. Rust 端清除内存中的主密钥
  /// 3. 重新初始化 Rust 端（因为 AppState 被清空）
  /// 4. Dart 端尝试删除数据库文件（锦上添花）
  /// 5. 重置应用状态
  Future<void> reset() async {
    try {
      // 步骤1-2: Rust 端清空数据并清除密钥
      final rustResetSuccess = await _ffi.resetApp();
      if (!rustResetSuccess) {
        debugPrint('警告：Rust 端重置失败，可能存在内存泄漏');
      }

      // 步骤3: 重新初始化 Rust 端（AppState 被清空后需要重新初始化）
      if (_dbPath != null) {
        await _ffi.initApp(_dbPath!);
      }

      // 步骤4: 尝试删除数据库文件（即使失败，数据也已被清空）
      if (_dbPath != null) {
        final dbFile = File(_dbPath!);
        if (await dbFile.exists()) {
          try {
            await dbFile.delete();
            debugPrint('数据库文件已删除');
          } catch (e) {
            // 文件删除失败不是致命错误，因为数据已被清空
            debugPrint('数据库文件无法删除（可能被占用），但数据已被清空');
          }
        }
      }

      // 步骤5: 重置状态
      _status = AuthStatus.setup;
      _passwordHint = null;
      notifyListeners();

      debugPrint('应用已重置');
    } catch (e) {
      debugPrint('重置应用失败: $e');
    }
  }
}
