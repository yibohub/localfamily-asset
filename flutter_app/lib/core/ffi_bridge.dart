/// FFI 桥接层 - 与 Rust Core 通信
///
/// 封装所有 C FFI 调用，提供类型安全的 Dart API
library;

import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

/// FFI 错误码
class FfiErrorCode {
  static const int success = 0;
  static const int genericError = -1;
  static const int invalidPassword = -2;
  static const int databaseError = -3;
  static const int cryptoError = -4;
  static const int notFound = -5;
  static const int invalidParam = -6;
}

/// FFI 桥接类
class FfiBridge {
  static FfiBridge? _instance;
  late ffi.DynamicLibrary _dylib;

  // FFI 函数签名
  late final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>) _freeString;
  late final int Function(ffi.Pointer<ffi.Char>) _initApp;
  late final int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>) _setupPassword;
  late final int Function(ffi.Pointer<ffi.Char>) _verifyPassword;
  late final int Function(ffi.Pointer<ffi.Char>) _verifyWithMnemonic;
  late final ffi.Pointer<ffi.Char> Function() _getPasswordHint;
  late final ffi.Pointer<ffi.Char> Function() _generateMnemonic;
  late final int Function(ffi.Pointer<ffi.Char>) _saveMnemonic;
  late final int Function(
    ffi.Pointer<ffi.Char>,
    int,
    double,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) _addAsset;
  late final ffi.Pointer<ffi.Char> Function() _getAllAssets;
  late final int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    int,
    double,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) _updateAsset;
  late final int Function(ffi.Pointer<ffi.Char>) _deleteAsset;
  late final ffi.Pointer<ffi.Char> Function() _getAssetChanges;
  late final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>) _getAssetChangesByAssetId;
  late final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>) _exportData;
  late final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>) _importData;
  late final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>) _searchAssetsByName;
  late final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>, int) _createCustomAssetType;
  late final ffi.Pointer<ffi.Char> Function() _getCustomAssetTypes;
  late final int Function(ffi.Pointer<ffi.Char>) _deleteCustomAssetType;
  late final int Function(ffi.Pointer<ffi.Char>) _isCustomTypeInUse;
  late final int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    double,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    double,
    double,
    ffi.Pointer<ffi.Char>,
  ) _addAssetWithType;
  late final int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    double,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    double,
    double,
    ffi.Pointer<ffi.Char>,
  ) _updateAssetWithType;

  // 新增：支持扩展字段的 FFI 函数
  late final int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    double,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) _addAssetWithExtraFields;
  late final ffi.Pointer<ffi.Char> Function() _getAssetsOnly;
  late final ffi.Pointer<ffi.Char> Function() _getLiabilitiesOnly;
  late final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>) _getAssetById;
  late final int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    double,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) _updateAssetWithExtraFields;

  // 负债专用 FFI 函数
  late final ffi.Pointer<ffi.Char> Function() _getAllLiabilities;
  late final int Function(ffi.Pointer<ffi.Char>) _deleteLiability;
  late final int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    double,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) _addLiabilityWithExtraFields;
  late final int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    double,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) _updateLiabilityWithExtraFields;

  // 重置函数
  late final int Function() _resetApp;
  late final int Function(double, double) _recordNetWorthSnapshot;
  late final ffi.Pointer<ffi.Char> Function() _getNetWorthSnapshots;
  late final ffi.Pointer<ffi.Char> Function() _getInvestmentReturns;

  // 附件（加密存储）相关函数；free_string 的真实绑定（附件字符串较大必须释放）
  late final int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
  ) _addAttachment;
  late final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      _getAttachmentsByAsset;
  late final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)
      _readAttachmentData;
  late final int Function(ffi.Pointer<ffi.Char>) _deleteAttachment;
  late final void Function(ffi.Pointer<ffi.Char>) _freeStringRust;

  // V2 加密数据库相关函数
  late final int Function(ffi.Pointer<ffi.Char>) _initAppV2;
  late final int Function(ffi.Pointer<ffi.Char>) _verifyPasswordV2;
  late final int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>) _setupPasswordV2;
  late final int Function() _saveDatabase;
  late final int Function(int) _cleanupApp;

  FfiBridge._internal() {
    _loadLibrary();
    _loadFunctions();
  }

  factory FfiBridge() {
    _instance ??= FfiBridge._internal();
    return _instance!;
  }

  /// 加载动态库
  void _loadLibrary() {
    try {
      if (Platform.isAndroid) {
        _dylib = ffi.DynamicLibrary.open('liblocalfamily_asset_core.so');
      } else if (Platform.isIOS) {
        _dylib = ffi.DynamicLibrary.process();
      } else if (Platform.isWindows) {
        // Windows: 尝试多个路径查找 DLL
        try {
          // 首先尝试当前目录
          _dylib = ffi.DynamicLibrary.open('localfamily_asset_core.dll');
        } catch (e) {
          // 如果失败，尝试可执行文件目录
          try {
            _dylib = ffi.DynamicLibrary.open('./localfamily_asset_core.dll');
          } catch (e2) {
            throw Exception('无法加载 localfamily_asset_core.dll: $e, $e2\n'
                '请确保 DLL 文件在可执行文件同一目录下');
          }
        }
      } else if (Platform.isLinux) {
        _dylib = ffi.DynamicLibrary.open('liblocalfamily_asset_core.so');
      } else if (Platform.isMacOS) {
        _dylib = ffi.DynamicLibrary.open('liblocalfamily_asset_core.dylib');
      } else {
        throw UnsupportedError('不支持的平台');
      }
    } catch (e) {
      throw Exception('加载 Rust Core 动态库失败: $e');
    }
  }

  /// 加载 FFI 函数
  void _loadFunctions() {
    // free_string 在 Rust 中返回 void
    // 注意：由于 toNativeUtf8() 使用 malloc 分配内存，需要使用 malloc.free 释放
    // 而不是调用 Rust 的 free_string 函数
    _freeString = (ptr) => ptr;

    _initApp = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Pointer<ffi.Char>)>>('init_app')
        .asFunction();

    _setupPassword = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>)>>('setup_password')
        .asFunction();

    _verifyPassword = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Pointer<ffi.Char>)>>('verify_password')
        .asFunction();

    _verifyWithMnemonic = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Pointer<ffi.Char>)>>('verify_with_mnemonic')
        .asFunction();

    _getPasswordHint = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function()>>('get_password_hint')
        .asFunction();

    _generateMnemonic = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function()>>('generate_mnemonic')
        .asFunction();

    _saveMnemonic = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Pointer<ffi.Char>)>>('save_mnemonic')
        .asFunction();

    _addAsset = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(
          ffi.Pointer<ffi.Char>,
          ffi.Int32,
          ffi.Double,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
        )>>('add_asset')
        .asFunction();

    _getAllAssets = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function()>>('get_all_assets')
        .asFunction();

    _updateAsset = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Int32,
          ffi.Double,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
        )>>('update_asset')
        .asFunction();

    _deleteAsset = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Pointer<ffi.Char>)>>('delete_asset')
        .asFunction();

    _getAssetChanges = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function()>>('get_asset_changes')
        .asFunction();

    _getAssetChangesByAssetId = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)>>('get_asset_changes_by_asset_id')
        .asFunction();

    _exportData = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
        )>>('export_data')
        .asFunction();

    _importData = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
        )>>('import_data')
        .asFunction();

    _searchAssetsByName = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
        )>>('search_assets_by_name')
        .asFunction();

    _createCustomAssetType = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Int32,
        )>>('create_custom_asset_type')
        .asFunction();

    _getCustomAssetTypes = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function()>>('get_custom_asset_types')
        .asFunction();

    _deleteCustomAssetType = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Pointer<ffi.Char>)>>('delete_custom_asset_type')
        .asFunction();

    _isCustomTypeInUse = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Pointer<ffi.Char>)>>('is_custom_type_in_use')
        .asFunction();

    _addAssetWithType = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Double,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Double,
          ffi.Double,
          ffi.Pointer<ffi.Char>,
        )>>('add_asset_with_type')
        .asFunction();

    _updateAssetWithType = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Double,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Double,
          ffi.Double,
          ffi.Pointer<ffi.Char>,
        )>>('update_asset_with_type')
        .asFunction();

    // 新增：加载支持扩展字段的函数
    _addAssetWithExtraFields = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Double,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
        )>>('add_asset_with_extra_fields')
        .asFunction();

    _getAssetsOnly = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function()>>('get_assets_only')
        .asFunction();

    _getLiabilitiesOnly = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function()>>('get_liabilities_only')
        .asFunction();

    _getAssetById = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)>>('get_asset_by_id')
        .asFunction();

    _updateAssetWithExtraFields = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Double,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
        )>>('update_asset_with_extra_fields')
        .asFunction();

    // 负债专用函数
    _getAllLiabilities = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function()>>('get_all_liabilities')
        .asFunction();

    _deleteLiability = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Pointer<ffi.Char>)>>('delete_liability')
        .asFunction();

    _addLiabilityWithExtraFields = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Double,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
        )>>('add_liability_with_extra_fields')
        .asFunction();

    _updateLiabilityWithExtraFields = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Double,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>,
        )>>('update_liability_with_extra_fields')
        .asFunction();

    _resetApp = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function()>>('reset_app')
        .asFunction();

    // V2 加密数据库函数
    _initAppV2 = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Pointer<ffi.Char>)>>('init_app_v2')
        .asFunction();

    _verifyPasswordV2 = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Pointer<ffi.Char>)>>('verify_password_v2')
        .asFunction();

    _setupPasswordV2 = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>)>>('setup_password_v2')
        .asFunction();

    _saveDatabase = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function()>>('save_database')
        .asFunction();

    _cleanupApp = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Int32)>>('cleanup_app')
        .asFunction();

    // 净资产快照（财富曲线）
    _recordNetWorthSnapshot = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Double, ffi.Double)>>(
            'record_net_worth_snapshot')
        .asFunction();

    _getNetWorthSnapshots = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function()>>(
            'get_net_worth_snapshots')
        .asFunction();

    _getInvestmentReturns = _dylib
        .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function()>>(
            'get_investment_returns')
        .asFunction();

    // 附件（加密存储）函数
    _addAttachment = _dylib
        .lookup<ffi.NativeFunction<
            ffi.Int32 Function(
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>,
            )>>('add_attachment')
        .asFunction();

    _getAttachmentsByAsset = _dylib
        .lookup<ffi.NativeFunction<
            ffi.Pointer<ffi.Char> Function(
                ffi.Pointer<ffi.Char>)>>('get_attachments_by_asset')
        .asFunction();

    _readAttachmentData = _dylib
        .lookup<ffi.NativeFunction<
            ffi.Pointer<ffi.Char> Function(
                ffi.Pointer<ffi.Char>)>>('read_attachment_data')
        .asFunction();

    _deleteAttachment = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Pointer<ffi.Char>)>>(
            'delete_attachment')
        .asFunction();

    // free_string 真实绑定：Rust 端 CString::into_raw 需要用它释放；
    // 附件内容字符串可达数 MB，必须释放（其他旧接口沿用历史 no-op 行为，另行清理）
    _freeStringRust = _dylib
        .lookup<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Char>)>>(
            'free_string')
        .asFunction();
  }

  /// 初始化应用
  Future<bool> initApp(String dbPath) async {
    final pathPtr = dbPath.toNativeUtf8().cast<ffi.Char>();
    try {
      final result = _initApp(pathPtr);
      if (result != FfiErrorCode.success) {
        debugPrint('initApp 失败，错误码: $result, 路径: $dbPath');
      }
      return result == FfiErrorCode.success;
    } catch (e) {
      debugPrint('initApp 异常: $e');
      return false;
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// 设置主密码
  Future<bool> setupPassword(String password, {String? hint}) async {
    final passwordPtr = password.toNativeUtf8().cast<ffi.Char>();
    final hintPtr = hint != null ? hint.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;

    try {
      final result = _setupPassword(passwordPtr, hintPtr);
      if (result != FfiErrorCode.success) {
        debugPrint('setupPassword 失败，错误码: $result');
      }
      return result == FfiErrorCode.success;
    } catch (e) {
      debugPrint('setupPassword 异常: $e');
      return false;
    } finally {
      malloc.free(passwordPtr);
      if (hintPtr != ffi.nullptr) {
        malloc.free(hintPtr);
      }
    }
  }

  /// 验证密码
  Future<bool> verifyPassword(String password) async {
    final passwordPtr = password.toNativeUtf8().cast<ffi.Char>();
    try {
      final result = _verifyPassword(passwordPtr);
      return result == FfiErrorCode.success;
    } finally {
      malloc.free(passwordPtr);
    }
  }

  /// 使用助记词验证并恢复访问
  Future<bool> verifyWithMnemonic(String mnemonic) async {
    final mnemonicPtr = mnemonic.toNativeUtf8().cast<ffi.Char>();
    try {
      final result = _verifyWithMnemonic(mnemonicPtr);
      return result == FfiErrorCode.success;
    } finally {
      malloc.free(mnemonicPtr);
    }
  }

  /// 获取密码提示
  Future<String?> getPasswordHint() async {
    final result = _getPasswordHint();
    if (result == ffi.nullptr) {
      return null;
    }
    final hintStr = result.cast<Utf8>().toDartString();
    malloc.free(result);
    return hintStr;
  }

  /// 生成助记词
  Future<String?> generateMnemonic() async {
    final result = _generateMnemonic();
    if (result == ffi.nullptr) {
      debugPrint('generateMnemonic 失败：返回空指针');
      return null;
    }
    final mnemonic = result.cast<Utf8>().toDartString();
    malloc.free(result);
    return mnemonic;
  }

  /// 保存助记词
  Future<bool> saveMnemonic(String mnemonic) async {
    final mnemonicPtr = mnemonic.toNativeUtf8().cast<ffi.Char>();
    try {
      final result = _saveMnemonic(mnemonicPtr);
      if (result != FfiErrorCode.success) {
        debugPrint('saveMnemonic 失败，错误码: $result');
      }
      return result == FfiErrorCode.success;
    } catch (e) {
      debugPrint('saveMnemonic 异常: $e');
      return false;
    } finally {
      malloc.free(mnemonicPtr);
    }
  }

  /// 添加资产
  Future<bool> addAsset({
    required String name,
    required int assetType,
    required double amount,
    required String currency,
    String? symbol,
    String? notes,
    required String occurrenceDate,
  }) async {
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final currencyPtr = currency.toNativeUtf8().cast<ffi.Char>();
    final symbolPtr = symbol != null ? symbol.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final notesPtr = notes != null ? notes.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final occurrenceDatePtr = occurrenceDate.toNativeUtf8().cast<ffi.Char>();

    try {
      final result = _addAsset(
        namePtr,
        assetType,
        amount,
        currencyPtr,
        symbolPtr,
        notesPtr,
        occurrenceDatePtr,
      );
      return result == FfiErrorCode.success;
    } finally {
      malloc.free(namePtr);
      malloc.free(currencyPtr);
      if (symbolPtr != ffi.nullptr) malloc.free(symbolPtr);
      if (notesPtr != ffi.nullptr) malloc.free(notesPtr);
      malloc.free(occurrenceDatePtr);
    }
  }

  /// 获取所有资产
  Future<List<Map<String, dynamic>>> getAllAssets() async {
    final resultPtr = _getAllAssets();
    if (resultPtr == ffi.nullptr) {
      return [];
    }

    try {
      // 从 C 字符串指针（char*）转换为 Dart 字符串
      // 将 Pointer<Char> 转换为 Pointer<Int8> 然后使用 Utf8Decoder
      final charPtr = resultPtr.cast<ffi.Int8>();
      final length = _strlen(charPtr);
      final bytes = charPtr.cast<ffi.Uint8>().asTypedList(length);
      final jsonStr = const Utf8Decoder().convert(bytes);
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.cast<Map<String, dynamic>>();
    } finally {
      _freeString(resultPtr);
    }
  }

  /// 计算 C 字符串长度
  int _strlen(ffi.Pointer<ffi.Int8> s) {
    var len = 0;
    while (s[len] != 0) {
      len++;
    }
    return len;
  }

  /// 更新资产
  Future<bool> updateAsset({
    required String id,
    required String name,
    required int assetType,
    required double amount,
    required String currency,
    String? symbol,
    String? notes,
    String? occurrenceDate,
  }) async {
    final idPtr = id.toNativeUtf8().cast<ffi.Char>();
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final currencyPtr = currency.toNativeUtf8().cast<ffi.Char>();
    final symbolPtr = symbol != null ? symbol.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final notesPtr = notes != null ? notes.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final occurrenceDatePtr = occurrenceDate != null ? occurrenceDate.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;

    try {
      final result = _updateAsset(
        idPtr,
        namePtr,
        assetType,
        amount,
        currencyPtr,
        symbolPtr,
        notesPtr,
        occurrenceDatePtr,
      );
      return result == FfiErrorCode.success;
    } finally {
      malloc.free(idPtr);
      malloc.free(namePtr);
      malloc.free(currencyPtr);
      if (symbolPtr != ffi.nullptr) malloc.free(symbolPtr);
      if (notesPtr != ffi.nullptr) malloc.free(notesPtr);
      if (occurrenceDatePtr != ffi.nullptr) malloc.free(occurrenceDatePtr);
    }
  }

  /// 删除资产
  Future<bool> deleteAsset(String id) async {
    final idPtr = id.toNativeUtf8().cast<ffi.Char>();
    try {
      final result = _deleteAsset(idPtr);
      return result == FfiErrorCode.success;
    } finally {
      malloc.free(idPtr);
    }
  }

  /// 导出数据到加密 Zip
  ///
  /// 返回格式: {"success": true, "path": "..."} 或 {"error": "..."}
  Future<Map<String, dynamic>> exportData({
    required String password,
    required String outputPath,
  }) async {
    final passwordPtr = password.toNativeUtf8().cast<ffi.Char>();
    final pathPtr = outputPath.toNativeUtf8().cast<ffi.Char>();

    try {
      final resultPtr = _exportData(passwordPtr, pathPtr);
      if (resultPtr == ffi.nullptr) {
        return {'error': '导出失败：返回空指针'};
      }

      final charPtr = resultPtr.cast<ffi.Int8>();
      final length = _strlen(charPtr);
      final bytes = charPtr.cast<ffi.Uint8>().asTypedList(length);
      final jsonStr = const Utf8Decoder().convert(bytes);
      final result = jsonDecode(jsonStr) as Map<String, dynamic>;

      _freeString(resultPtr);
      return result;
    } catch (e) {
      debugPrint('exportData 异常: $e');
      return {'error': '导出异常: $e'};
    } finally {
      malloc.free(passwordPtr);
      malloc.free(pathPtr);
    }
  }

  /// 从加密 Zip 导入数据
  ///
  /// 返回格式: {"success": true, "imported": 1234} 或 {"error": "..."}
  Future<Map<String, dynamic>> importData({
    required String password,
    required String inputPath,
  }) async {
    final passwordPtr = password.toNativeUtf8().cast<ffi.Char>();
    final pathPtr = inputPath.toNativeUtf8().cast<ffi.Char>();

    try {
      final resultPtr = _importData(passwordPtr, pathPtr);
      if (resultPtr == ffi.nullptr) {
        return {'error': '导入失败：返回空指针'};
      }

      final charPtr = resultPtr.cast<ffi.Int8>();
      final length = _strlen(charPtr);
      final bytes = charPtr.cast<ffi.Uint8>().asTypedList(length);
      final jsonStr = const Utf8Decoder().convert(bytes);
      final result = jsonDecode(jsonStr) as Map<String, dynamic>;

      _freeString(resultPtr);
      return result;
    } catch (e) {
      debugPrint('importData 异常: $e');
      return {'error': '导入异常: $e'};
    } finally {
      malloc.free(passwordPtr);
      malloc.free(pathPtr);
    }
  }

  /// 获取所有资产变更记录（审计日志）
  Future<List<Map<String, dynamic>>> getAssetChanges() async {
    final resultPtr = _getAssetChanges();
    if (resultPtr == ffi.nullptr) {
      return [];
    }

    try {
      final charPtr = resultPtr.cast<ffi.Int8>();
      final length = _strlen(charPtr);
      final bytes = charPtr.cast<ffi.Uint8>().asTypedList(length);
      final jsonStr = const Utf8Decoder().convert(bytes);
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.cast<Map<String, dynamic>>();
    } finally {
      _freeString(resultPtr);
    }
  }

  /// 获取指定资产的变更记录
  Future<List<Map<String, dynamic>>> getAssetChangesByAssetId(String assetId) async {
    final assetIdPtr = assetId.toNativeUtf8().cast<ffi.Char>();
    try {
      final resultPtr = _getAssetChangesByAssetId(assetIdPtr);
      if (resultPtr == ffi.nullptr) {
        return [];
      }

      final charPtr = resultPtr.cast<ffi.Int8>();
      final length = _strlen(charPtr);
      final bytes = charPtr.cast<ffi.Uint8>().asTypedList(length);
      final jsonStr = const Utf8Decoder().convert(bytes);
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.cast<Map<String, dynamic>>();
    } finally {
      malloc.free(assetIdPtr);
    }
  }

  /// 按名称搜索资产
  ///
  /// [namePattern] 搜索关键词（支持模糊匹配）
  /// [typeFilter] 资产类型过滤器，为 null 时搜索所有类型
  Future<List<Map<String, dynamic>>> searchAssetsByName({
    required String namePattern,
    List<int>? typeFilter,
  }) async {
    final namePtr = namePattern.toNativeUtf8().cast<ffi.Char>();
    final typeJson = jsonEncode(typeFilter ?? []);
    final typePtr = typeJson.toNativeUtf8().cast<ffi.Char>();

    try {
      final resultPtr = _searchAssetsByName(namePtr, typePtr);
      if (resultPtr == ffi.nullptr) {
        return [];
      }

      final charPtr = resultPtr.cast<ffi.Int8>();
      final length = _strlen(charPtr);
      final bytes = charPtr.cast<ffi.Uint8>().asTypedList(length);
      final jsonStr = const Utf8Decoder().convert(bytes);
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.cast<Map<String, dynamic>>();
    } finally {
      malloc.free(namePtr);
      malloc.free(typePtr);
    }
  }

  /// 创建自定义资产类型
  ///
  /// 返回格式: {"id": "custom_xxx", "success": true} 或 {"error": "..."}
  Future<Map<String, dynamic>> createCustomAssetType({
    required String name,
    required String iconName,
    required bool isLiability,
  }) async {
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final iconNamePtr = iconName.toNativeUtf8().cast<ffi.Char>();
    final isLiabilityInt = isLiability ? 1 : 0;

    try {
      final resultPtr = _createCustomAssetType(namePtr, iconNamePtr, isLiabilityInt);
      if (resultPtr == ffi.nullptr) {
        return {'error': '创建失败：返回空指针'};
      }

      final charPtr = resultPtr.cast<ffi.Int8>();
      final length = _strlen(charPtr);
      final bytes = charPtr.cast<ffi.Uint8>().asTypedList(length);
      final jsonStr = const Utf8Decoder().convert(bytes);
      final result = jsonDecode(jsonStr) as Map<String, dynamic>;

      _freeString(resultPtr);
      return result;
    } catch (e) {
      debugPrint('createCustomAssetType 异常: $e');
      return {'error': '创建异常: $e'};
    } finally {
      malloc.free(namePtr);
      malloc.free(iconNamePtr);
    }
  }

  /// 获取所有自定义类型
  Future<List<Map<String, dynamic>>> getCustomAssetTypes() async {
    final resultPtr = _getCustomAssetTypes();
    if (resultPtr == ffi.nullptr) {
      return [];
    }

    try {
      final charPtr = resultPtr.cast<ffi.Int8>();
      final length = _strlen(charPtr);
      final bytes = charPtr.cast<ffi.Uint8>().asTypedList(length);
      final jsonStr = const Utf8Decoder().convert(bytes);
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.cast<Map<String, dynamic>>();
    } finally {
      _freeString(resultPtr);
    }
  }

  /// 删除自定义类型
  Future<bool> deleteCustomAssetType(String id) async {
    final idPtr = id.toNativeUtf8().cast<ffi.Char>();
    try {
      final result = _deleteCustomAssetType(idPtr);
      return result == FfiErrorCode.success;
    } finally {
      malloc.free(idPtr);
    }
  }

  /// 检查自定义类型是否被使用
  Future<bool> isCustomTypeInUse(String id) async {
    final idPtr = id.toNativeUtf8().cast<ffi.Char>();
    try {
      final result = _isCustomTypeInUse(idPtr);
      return result == 1;
    } finally {
      malloc.free(idPtr);
    }
  }

  /// 添加资产（使用字符串类型，支持自定义类型）
  Future<bool> addAssetWithType({
    required String name,
    required String assetType,
    required double amount,
    required String currency,
    String? symbol,
    String? notes,
    required String occurrenceDate,
    double? buyPrice,
    double? currentPrice,
    String? tagsJson,
  }) async {
    debugPrint('===== FfiBridge.addAssetWithType 开始 =====');
    debugPrint('buyPrice: $buyPrice, currentPrice: $currentPrice');

    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final typePtr = assetType.toNativeUtf8().cast<ffi.Char>();
    final currencyPtr = currency.toNativeUtf8().cast<ffi.Char>();
    final symbolPtr = symbol != null ? symbol.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final notesPtr = notes != null ? notes.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final occurrenceDatePtr = occurrenceDate.toNativeUtf8().cast<ffi.Char>();
    final tagsJsonPtr = tagsJson != null ? tagsJson.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;

    // 使用 NaN 表示 null（哨兵值方案）
    final buyPriceValue = buyPrice ?? double.nan;
    final currentPriceValue = currentPrice ?? double.nan;

    debugPrint('传递给 Rust: buyPrice=$buyPriceValue (isNaN=${buyPriceValue.isNaN}), currentPrice=$currentPriceValue (isNaN=${currentPriceValue.isNaN})');

    try {
      final result = _addAssetWithType(
        namePtr,
        typePtr,
        amount,
        currencyPtr,
        symbolPtr,
        notesPtr,
        occurrenceDatePtr,
        buyPriceValue,
        currentPriceValue,
        tagsJsonPtr,
      );
      debugPrint('Rust 返回结果: $result');
      return result == FfiErrorCode.success;
    } finally {
      malloc.free(namePtr);
      malloc.free(typePtr);
      malloc.free(currencyPtr);
      if (symbolPtr != ffi.nullptr) malloc.free(symbolPtr);
      if (notesPtr != ffi.nullptr) malloc.free(notesPtr);
      malloc.free(occurrenceDatePtr);
      if (tagsJsonPtr != ffi.nullptr) malloc.free(tagsJsonPtr);
    }
  }

  /// 更新资产（使用字符串类型，支持自定义类型）
  Future<bool> updateAssetWithType({
    required String id,
    required String name,
    required String assetType,
    required double amount,
    required String currency,
    String? symbol,
    String? notes,
    String? occurrenceDate,
    double? buyPrice,
    double? currentPrice,
    String? tagsJson,
  }) async {
    final idPtr = id.toNativeUtf8().cast<ffi.Char>();
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final typePtr = assetType.toNativeUtf8().cast<ffi.Char>();
    final currencyPtr = currency.toNativeUtf8().cast<ffi.Char>();
    final symbolPtr = symbol != null ? symbol.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final notesPtr = notes != null ? notes.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final occurrenceDatePtr = occurrenceDate != null ? occurrenceDate.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final tagsJsonPtr = tagsJson != null ? tagsJson.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;

    // 使用 NaN 表示 null（哨兵值方案）
    final buyPriceValue = buyPrice ?? double.nan;
    final currentPriceValue = currentPrice ?? double.nan;

    try {
      final result = _updateAssetWithType(
        idPtr,
        namePtr,
        typePtr,
        amount,
        currencyPtr,
        symbolPtr,
        notesPtr,
        occurrenceDatePtr,
        buyPriceValue,
        currentPriceValue,
        tagsJsonPtr,
      );
      return result == FfiErrorCode.success;
    } finally {
      malloc.free(idPtr);
      malloc.free(namePtr);
      malloc.free(typePtr);
      malloc.free(currencyPtr);
      if (symbolPtr != ffi.nullptr) malloc.free(symbolPtr);
      if (notesPtr != ffi.nullptr) malloc.free(notesPtr);
      if (occurrenceDatePtr != ffi.nullptr) malloc.free(occurrenceDatePtr);
      if (tagsJsonPtr != ffi.nullptr) malloc.free(tagsJsonPtr);
    }
  }

  // ============================================================
  // 新增方法：支持资产/负债分离和扩展字段
  // ============================================================

  /// 添加资产（支持扩展字段）
  Future<bool> addAssetWithExtraFields({
    required String name,
    required String assetType,
    required double amount,
    String currency = 'CNY',
    required String occurrenceDate,
    String? extraFieldsJson,
    String? note,
  }) async {
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final typePtr = assetType.toNativeUtf8().cast<ffi.Char>();
    final currencyPtr = currency.toNativeUtf8().cast<ffi.Char>();
    final occurrenceDatePtr = occurrenceDate.toNativeUtf8().cast<ffi.Char>();
    final extraFieldsPtr = extraFieldsJson != null ? extraFieldsJson.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final notePtr = note != null ? note.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;

    try {
      final result = _addAssetWithExtraFields(
        namePtr,
        typePtr,
        amount,
        currencyPtr,
        occurrenceDatePtr,
        extraFieldsPtr,
        notePtr,
      );
      return result == FfiErrorCode.success;
    } finally {
      malloc.free(namePtr);
      malloc.free(typePtr);
      malloc.free(currencyPtr);
      malloc.free(occurrenceDatePtr);
      if (extraFieldsPtr != ffi.nullptr) malloc.free(extraFieldsPtr);
      if (notePtr != ffi.nullptr) malloc.free(notePtr);
    }
  }

  /// 获取仅资产类型（不包括负债）
  Future<String> getAssetsOnly() async {
    final resultPtr = _getAssetsOnly();
    if (resultPtr == ffi.nullptr) {
      return '[]';
    }
    final result = resultPtr.cast<Utf8>().toDartString();
    // 注意：不需要手动释放，因为 Rust 使用的是静态返回
    return result;
  }

  /// 获取仅负债类型
  Future<String> getLiabilitiesOnly() async {
    final resultPtr = _getLiabilitiesOnly();
    if (resultPtr == ffi.nullptr) {
      return '[]';
    }
    final result = resultPtr.cast<Utf8>().toDartString();
    return result;
  }

  /// 根据 ID 获取单个资产/负债
  Future<String?> getAssetById(String id) async {
    final idPtr = id.toNativeUtf8().cast<ffi.Char>();
    try {
      final resultPtr = _getAssetById(idPtr);
      if (resultPtr == ffi.nullptr) {
        return null;
      }
      final result = resultPtr.cast<Utf8>().toDartString();
      return result;
    } finally {
      malloc.free(idPtr);
    }
  }

  /// 更新资产（支持扩展字段）
  Future<bool> updateAssetWithExtraFields({
    required String id,
    required String name,
    required String assetType,
    required double amount,
    String currency = 'CNY',
    String? occurrenceDate,
    String? extraFieldsJson,
    String? note,
  }) async {
    final idPtr = id.toNativeUtf8().cast<ffi.Char>();
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final typePtr = assetType.toNativeUtf8().cast<ffi.Char>();
    final currencyPtr = currency.toNativeUtf8().cast<ffi.Char>();
    final occurrenceDatePtr = occurrenceDate != null ? occurrenceDate.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final extraFieldsPtr = extraFieldsJson != null ? extraFieldsJson.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final notePtr = note != null ? note.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;

    try {
      final result = _updateAssetWithExtraFields(
        idPtr,
        namePtr,
        typePtr,
        amount,
        currencyPtr,
        occurrenceDatePtr,
        extraFieldsPtr,
        notePtr,
      );
      return result == FfiErrorCode.success;
    } finally {
      malloc.free(idPtr);
      malloc.free(namePtr);
      malloc.free(typePtr);
      malloc.free(currencyPtr);
      if (occurrenceDatePtr != ffi.nullptr) malloc.free(occurrenceDatePtr);
      if (extraFieldsPtr != ffi.nullptr) malloc.free(extraFieldsPtr);
      if (notePtr != ffi.nullptr) malloc.free(notePtr);
    }
  }

  // ============================================================
  // 负债专用方法
  // ============================================================

  /// 获取所有负债
  Future<List<Map<String, dynamic>>> getAllLiabilities() async {
    final resultPtr = _getAllLiabilities();
    if (resultPtr == ffi.nullptr) {
      return [];
    }

    try {
      final charPtr = resultPtr.cast<ffi.Int8>();
      final length = _strlen(charPtr);
      final bytes = charPtr.cast<ffi.Uint8>().asTypedList(length);
      final jsonStr = const Utf8Decoder().convert(bytes);
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.cast<Map<String, dynamic>>();
    } finally {
      malloc.free(resultPtr);
    }
  }

  /// 删除负债
  Future<bool> deleteLiability(String id) async {
    final idPtr = id.toNativeUtf8().cast<ffi.Char>();
    try {
      final result = _deleteLiability(idPtr);
      return result == FfiErrorCode.success;
    } finally {
      malloc.free(idPtr);
    }
  }

  /// 添加负债（支持扩展字段）
  Future<bool> addLiabilityWithExtraFields({
    required String name,
    required String liabilityType,
    required double amount,
    String currency = 'CNY',
    required String occurrenceDate,
    String? extraFieldsJson,
    String? note,
  }) async {
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final typePtr = liabilityType.toNativeUtf8().cast<ffi.Char>();
    final currencyPtr = currency.toNativeUtf8().cast<ffi.Char>();
    final occurrenceDatePtr = occurrenceDate.toNativeUtf8().cast<ffi.Char>();
    final extraFieldsPtr = extraFieldsJson != null ? extraFieldsJson.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final notePtr = note != null ? note.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;

    try {
      final result = _addLiabilityWithExtraFields(
        namePtr,
        typePtr,
        amount,
        currencyPtr,
        occurrenceDatePtr,
        extraFieldsPtr,
        notePtr,
      );
      return result == FfiErrorCode.success;
    } finally {
      malloc.free(namePtr);
      malloc.free(typePtr);
      malloc.free(currencyPtr);
      malloc.free(occurrenceDatePtr);
      if (extraFieldsPtr != ffi.nullptr) malloc.free(extraFieldsPtr);
      if (notePtr != ffi.nullptr) malloc.free(notePtr);
    }
  }

  /// 更新负债（支持扩展字段）
  Future<bool> updateLiabilityWithExtraFields({
    required String id,
    required String name,
    required String liabilityType,
    required double amount,
    String currency = 'CNY',
    String? occurrenceDate,
    String? extraFieldsJson,
    String? note,
  }) async {
    final idPtr = id.toNativeUtf8().cast<ffi.Char>();
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final typePtr = liabilityType.toNativeUtf8().cast<ffi.Char>();
    final currencyPtr = currency.toNativeUtf8().cast<ffi.Char>();
    final occurrenceDatePtr = occurrenceDate != null ? occurrenceDate.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final extraFieldsPtr = extraFieldsJson != null ? extraFieldsJson.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final notePtr = note != null ? note.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;

    try {
      final result = _updateLiabilityWithExtraFields(
        idPtr,
        namePtr,
        typePtr,
        amount,
        currencyPtr,
        occurrenceDatePtr,
        extraFieldsPtr,
        notePtr,
      );
      return result == FfiErrorCode.success;
    } finally {
      malloc.free(idPtr);
      malloc.free(namePtr);
      malloc.free(typePtr);
      malloc.free(currencyPtr);
      if (occurrenceDatePtr != ffi.nullptr) malloc.free(occurrenceDatePtr);
      if (extraFieldsPtr != ffi.nullptr) malloc.free(extraFieldsPtr);
      if (notePtr != ffi.nullptr) malloc.free(notePtr);
    }
  }

  /// 重置应用（清除所有内存中的敏感数据）
  ///
  /// 此函数会清除 Rust 端的所有状态，包括：
  /// - 主密钥 (master_key) - 用零覆盖后清除
  /// - 应用状态 (AppState)
  ///
  /// 调用此函数后，还需要删除数据库文件以完全重置应用
  Future<bool> resetApp() async {
    try {
      final result = _resetApp();
      if (result != FfiErrorCode.success) {
        debugPrint('resetApp 失败，错误码: $result');
      }
      return result == FfiErrorCode.success;
    } catch (e) {
      debugPrint('resetApp 异常: $e');
      return false;
    }
  }

  // ============================================================
  // V2 API: 文件级加密支持
  // ============================================================

  /// 初始化应用 V2（支持加密检测）
  ///
  /// 此函数会：
  /// 1. 检测数据库文件是否存在以及是否已加密
  /// 2. 如果是新数据库，返回初始化状态
  /// 3. 如果是加密数据库，需要调用 verifyPasswordV2 解锁
  /// 4. 如果是明文数据库，会自动迁移到加密格式
  Future<bool> initAppV2(String dbPath) async {
    final pathPtr = dbPath.toNativeUtf8().cast<ffi.Char>();
    try {
      final result = _initAppV2(pathPtr);
      if (result != FfiErrorCode.success) {
        debugPrint('initAppV2 失败，错误码: $result');
      }
      return result == FfiErrorCode.success;
    } catch (e) {
      debugPrint('initAppV2 异常: $e');
      return false;
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// 验证密码 V2（支持加密数据库）
  ///
  /// 此函数会：
  /// 1. 验证密码
  /// 2. 如果是加密数据库，解密到内存
  /// 3. 如果是明文数据库，加载到内存（下次保存时会自动加密）
  Future<bool> verifyPasswordV2(String password) async {
    final passwordPtr = password.toNativeUtf8().cast<ffi.Char>();
    try {
      final result = _verifyPasswordV2(passwordPtr);
      if (result != FfiErrorCode.success) {
        debugPrint('verifyPasswordV2 失败，错误码: $result');
      }
      return result == FfiErrorCode.success;
    } catch (e) {
      debugPrint('verifyPasswordV2 异常: $e');
      return false;
    } finally {
      malloc.free(passwordPtr);
    }
  }

  /// 设置主密码 V2（加密数据库模式）
  ///
  /// 此函数用于首次设置密码，会：
  /// 1. 派生密钥
  /// 2. 创建内存数据库
  /// 3. 初始化表结构
  /// 4. 保存盐值和密码提示
  ///
  /// 注意：调用此函数后，需要调用 saveDatabase() 将加密数据库保存到磁盘
  Future<bool> setupPasswordV2(String password, {String? hint}) async {
    final passwordPtr = password.toNativeUtf8().cast<ffi.Char>();
    final hintPtr = hint?.toNativeUtf8().cast<ffi.Char>() ?? ffi.nullptr;
    try {
      final result = _setupPasswordV2(passwordPtr, hintPtr);
      if (result != FfiErrorCode.success) {
        debugPrint('setupPasswordV2 失败，错误码: $result');
      }
      return result == FfiErrorCode.success;
    } catch (e) {
      debugPrint('setupPasswordV2 异常: $e');
      return false;
    } finally {
      malloc.free(passwordPtr);
      if (hint != null) {
        malloc.free(hintPtr);
      }
    }
  }

  /// 保存加密数据库到磁盘
  ///
  /// 将当前内存数据库加密后保存到磁盘
  Future<bool> saveDatabase() async {
    try {
      final result = _saveDatabase();
      if (result != FfiErrorCode.success) {
        debugPrint('saveDatabase 失败，错误码: $result');
      }
      return result == FfiErrorCode.success;
    } catch (e) {
      debugPrint('saveDatabase 异常: $e');
      return false;
    }
  }

  /// 清理应用（退出时调用）
  ///
  /// 此函数会：
  /// 1. 如果 save=true，保存加密数据库到磁盘
  /// 2. 清除内存中的敏感数据
  /// 3. 关闭内存数据库连接
  Future<bool> cleanupApp({bool save = true}) async {
    try {
      final result = _cleanupApp(save ? 1 : 0);
      if (result != FfiErrorCode.success) {
        debugPrint('cleanupApp 失败，错误码: $result');
      }
      return result == FfiErrorCode.success;
    } catch (e) {
      debugPrint('cleanupApp 异常: $e');
      return false;
    }
  }

  // ============================================================
  // 净资产快照（财富曲线）
  // ============================================================

  /// 记录/更新当日净值快照（同日覆盖）
  ///
  /// [totalAssets]/[totalLiabilities] 由调用方按 UI 显示口径计算。
  /// 注意：本方法不自动落盘，遵循即时保存策略由调用方随后调 saveDatabase。
  Future<bool> recordNetWorthSnapshot({
    required double totalAssets,
    required double totalLiabilities,
  }) async {
    try {
      final result = _recordNetWorthSnapshot(totalAssets, totalLiabilities);
      if (result != FfiErrorCode.success) {
        debugPrint('recordNetWorthSnapshot 失败，错误码: $result');
      }
      return result == FfiErrorCode.success;
    } catch (e) {
      debugPrint('recordNetWorthSnapshot 异常: $e');
      return false;
    }
  }

  /// 获取全部净值快照（按日期升序），失败返回空列表
  Future<List<NetWorthSnapshotPoint>> getNetWorthSnapshots() async {
    final resultPtr = _getNetWorthSnapshots();
    if (resultPtr == ffi.nullptr) {
      return const [];
    }
    final result = resultPtr.cast<Utf8>().toDartString();
    // 注意：不需要手动释放，因为 Rust 使用的是静态返回
    try {
      final List<dynamic> list = jsonDecode(result) as List<dynamic>;
      return list
          .map((e) => NetWorthSnapshotPoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getNetWorthSnapshots 解析失败: $e');
      return const [];
    }
  }

  /// 获取投资收益信息（含组合 XIRR 年化），失败返回 null
  Future<PortfolioReturns?> getInvestmentReturns() async {
    final resultPtr = _getInvestmentReturns();
    if (resultPtr == ffi.nullptr) {
      return null;
    }
    final result = resultPtr.cast<Utf8>().toDartString();
    // 注意：不需要手动释放，因为 Rust 使用的是静态返回
    try {
      return PortfolioReturns.fromJson(
          jsonDecode(result) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('getInvestmentReturns 解析失败: $e');
      return null;
    }
  }

  // ==================== 附件（加密存储） ====================

  /// 添加附件（Rust 端加密落盘并登记元数据），成功返回 true
  ///
  /// 单文件解密后上限 20MB（与 Rust 端 ATTACHMENT_MAX_SIZE 一致）
  Future<bool> addAttachment({
    required String assetId,
    required String fileName,
    String? mimeType,
    required Uint8List bytes,
  }) async {
    final assetIdPtr = assetId.toNativeUtf8().cast<ffi.Char>();
    final fileNamePtr = fileName.toNativeUtf8().cast<ffi.Char>();
    final mimePtr =
        (mimeType ?? '').toNativeUtf8().cast<ffi.Char>();
    final dataPtr = base64Encode(bytes).toNativeUtf8().cast<ffi.Char>();
    try {
      final result = _addAttachment(assetIdPtr, fileNamePtr, mimePtr, dataPtr);
      if (result != FfiErrorCode.success) {
        debugPrint('addAttachment 失败，错误码: $result');
      }
      return result == FfiErrorCode.success;
    } catch (e) {
      debugPrint('addAttachment 异常: $e');
      return false;
    } finally {
      malloc.free(assetIdPtr);
      malloc.free(fileNamePtr);
      malloc.free(mimePtr);
      malloc.free(dataPtr);
    }
  }

  /// 获取资产的附件列表（不含文件内容），失败返回空列表
  Future<List<AttachmentInfo>> getAttachments(String assetId) async {
    final assetIdPtr = assetId.toNativeUtf8().cast<ffi.Char>();
    ffi.Pointer<ffi.Char> resultPtr = ffi.nullptr;
    try {
      resultPtr = _getAttachmentsByAsset(assetIdPtr);
      if (resultPtr == ffi.nullptr) {
        return const [];
      }
      final result = resultPtr.cast<Utf8>().toDartString();
      try {
        final List<dynamic> list = jsonDecode(result) as List<dynamic>;
        return list
            .map((e) => AttachmentInfo.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('getAttachments 解析失败: $e');
        return const [];
      }
    } catch (e) {
      debugPrint('getAttachments 异常: $e');
      return const [];
    } finally {
      if (resultPtr != ffi.nullptr) _freeStringRust(resultPtr);
      malloc.free(assetIdPtr);
    }
  }

  /// 读取附件内容（Rust 端解密），失败返回 null
  Future<Uint8List?> readAttachmentData(String attachmentId) async {
    final idPtr = attachmentId.toNativeUtf8().cast<ffi.Char>();
    ffi.Pointer<ffi.Char> resultPtr = ffi.nullptr;
    try {
      resultPtr = _readAttachmentData(idPtr);
      if (resultPtr == ffi.nullptr) {
        return null;
      }
      final result = resultPtr.cast<Utf8>().toDartString();
      return base64Decode(result);
    } catch (e) {
      debugPrint('readAttachmentData 异常: $e');
      return null;
    } finally {
      if (resultPtr != ffi.nullptr) _freeStringRust(resultPtr);
      malloc.free(idPtr);
    }
  }

  /// 删除附件（密文文件 + 元数据），成功返回 true
  Future<bool> deleteAttachment(String attachmentId) async {
    final idPtr = attachmentId.toNativeUtf8().cast<ffi.Char>();
    try {
      final result = _deleteAttachment(idPtr);
      if (result != FfiErrorCode.success && result != FfiErrorCode.notFound) {
        debugPrint('deleteAttachment 失败，错误码: $result');
      }
      return result == FfiErrorCode.success;
    } catch (e) {
      debugPrint('deleteAttachment 异常: $e');
      return false;
    } finally {
      malloc.free(idPtr);
    }
  }
}

/// 投资收益模型（FFI JSON snake_case → Dart camelCase）
class InvestmentReturnItem {
  final String assetId;
  final String name;
  final String currency;
  final double cost;
  final double currentValue;
  final double profit;
  final double profitPercent;
  final int holdingDays;
  final double? xirr;

  const InvestmentReturnItem({
    required this.assetId,
    required this.name,
    required this.currency,
    required this.cost,
    required this.currentValue,
    required this.profit,
    required this.profitPercent,
    required this.holdingDays,
    required this.xirr,
  });

  factory InvestmentReturnItem.fromJson(Map<String, dynamic> json) {
    return InvestmentReturnItem(
      assetId: json['asset_id'] as String,
      name: json['name'] as String,
      currency: json['currency'] as String,
      cost: (json['cost'] as num).toDouble(),
      currentValue: (json['current_value'] as num).toDouble(),
      profit: (json['profit'] as num).toDouble(),
      profitPercent: (json['profit_percent'] as num).toDouble(),
      holdingDays: json['holding_days'] as int,
      xirr: json['xirr'] == null ? null : (json['xirr'] as num).toDouble(),
    );
  }
}

/// 组合投资收益汇总
class PortfolioReturns {
  final List<InvestmentReturnItem> items;
  final double totalCost;
  final double totalValue;
  final double totalProfit;
  final double? portfolioXirr;

  const PortfolioReturns({
    required this.items,
    required this.totalCost,
    required this.totalValue,
    required this.totalProfit,
    required this.portfolioXirr,
  });

  factory PortfolioReturns.fromJson(Map<String, dynamic> json) {
    return PortfolioReturns(
      items: (json['items'] as List<dynamic>)
          .map((e) =>
              InvestmentReturnItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCost: (json['total_cost'] as num).toDouble(),
      totalValue: (json['total_value'] as num).toDouble(),
      totalProfit: (json['total_profit'] as num).toDouble(),
      portfolioXirr: json['portfolio_xirr'] == null
          ? null
          : (json['portfolio_xirr'] as num).toDouble(),
    );
  }
}

/// 净资产快照数据点（FFI JSON snake_case → Dart camelCase）
class NetWorthSnapshotPoint {
  final String date; // YYYY-MM-DD
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;

  const NetWorthSnapshotPoint({
    required this.date,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
  });

  factory NetWorthSnapshotPoint.fromJson(Map<String, dynamic> json) {
    return NetWorthSnapshotPoint(
      date: json['date'] as String,
      totalAssets: (json['total_assets'] as num).toDouble(),
      totalLiabilities: (json['total_liabilities'] as num).toDouble(),
      netWorth: (json['net_worth'] as num).toDouble(),
    );
  }
}

/// 附件信息（FFI JSON snake_case → Dart camelCase，不含文件内容）
class AttachmentInfo {
  final String id;
  final String assetId;
  final String fileName;
  final int fileSize;
  final String? mimeType;
  final int createdAt; // Unix 秒

  const AttachmentInfo({
    required this.id,
    required this.assetId,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.createdAt,
  });

  factory AttachmentInfo.fromJson(Map<String, dynamic> json) {
    return AttachmentInfo(
      id: json['id'] as String,
      assetId: json['assetId'] as String,
      fileName: json['fileName'] as String,
      fileSize: json['fileSize'] as int,
      mimeType: json['mimeType'] as String?,
      createdAt: json['createdAt'] as int,
    );
  }
}
