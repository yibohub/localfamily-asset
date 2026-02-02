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
}
