/// FFI 桥接层 - 与 Rust Core 通信
///
/// 封装所有 C FFI 调用，提供类型安全的 Dart API
library;

import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';

/// FFI 错误码
class FfiErrorCode {
  static const int success = 0;
  static const int genericError = -1;
  static const int invalidPassword = -2;
  static const int databaseError = -3;
  static const int cryptoError = -4;
  static const int notFound = -5;
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
  late final int Function(
    ffi.Pointer<ffi.Char>,
    int,
    double,
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
  ) _updateAsset;
  late final int Function(ffi.Pointer<ffi.Char>) _deleteAsset;

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
    if (Platform.isAndroid) {
      _dylib = ffi.DynamicLibrary.open('liblocalfamily_asset_core.so');
    } else if (Platform.isIOS) {
      _dylib = ffi.DynamicLibrary.process();
    } else if (Platform.isWindows) {
      _dylib = ffi.DynamicLibrary.open('localfamily_asset_core.dll');
    } else if (Platform.isLinux) {
      _dylib = ffi.DynamicLibrary.open('liblocalfamily_asset_core.so');
    } else if (Platform.isMacOS) {
      _dylib = ffi.DynamicLibrary.open('liblocalfamily_asset_core.dylib');
    } else {
      throw UnsupportedError('不支持的平台');
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

    _addAsset = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(
          ffi.Pointer<ffi.Char>,
          ffi.Int32,
          ffi.Double,
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
        )>>('update_asset')
        .asFunction();

    _deleteAsset = _dylib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Pointer<ffi.Char>)>>('delete_asset')
        .asFunction();
  }

  /// 初始化应用
  Future<bool> initApp(String dbPath) async {
    final pathPtr = dbPath.toNativeUtf8().cast<ffi.Char>();
    try {
      final result = _initApp(pathPtr);
      return result == FfiErrorCode.success;
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
      return result == FfiErrorCode.success;
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

  /// 添加资产
  Future<bool> addAsset({
    required String name,
    required int assetType,
    required double amount,
    required String currency,
    String? symbol,
    String? notes,
  }) async {
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final currencyPtr = currency.toNativeUtf8().cast<ffi.Char>();
    final symbolPtr = symbol != null ? symbol.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final notesPtr = notes != null ? notes.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;

    try {
      final result = _addAsset(
        namePtr,
        assetType,
        amount,
        currencyPtr,
        symbolPtr,
        notesPtr,
      );
      return result == FfiErrorCode.success;
    } finally {
      malloc.free(namePtr);
      malloc.free(currencyPtr);
      if (symbolPtr != ffi.nullptr) malloc.free(symbolPtr);
      if (notesPtr != ffi.nullptr) malloc.free(notesPtr);
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
  }) async {
    final idPtr = id.toNativeUtf8().cast<ffi.Char>();
    final namePtr = name.toNativeUtf8().cast<ffi.Char>();
    final currencyPtr = currency.toNativeUtf8().cast<ffi.Char>();
    final symbolPtr = symbol != null ? symbol.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;
    final notesPtr = notes != null ? notes.toNativeUtf8().cast<ffi.Char>() : ffi.nullptr;

    try {
      final result = _updateAsset(
        idPtr,
        namePtr,
        assetType,
        amount,
        currencyPtr,
        symbolPtr,
        notesPtr,
      );
      return result == FfiErrorCode.success;
    } finally {
      malloc.free(idPtr);
      malloc.free(namePtr);
      malloc.free(currencyPtr);
      if (symbolPtr != ffi.nullptr) malloc.free(symbolPtr);
      if (notesPtr != ffi.nullptr) malloc.free(notesPtr);
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
}
