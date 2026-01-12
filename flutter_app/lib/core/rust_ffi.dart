import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Rust Core FFI 绑定
///
/// 连接 Flutter 与 Rust Core 的桥梁
class RustCore {
  static DynamicLibrary? _lib;
  static late final _RustCoreFunctions _functions;

  /// 初始化 Rust Core 库
  static bool initialize() {
    try {
      // 根据平台加载不同的库
      if (Platform.isAndroid || Platform.isLinux) {
        _lib = DynamicLibrary.open('librust_core.so');
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('rust_core.dll');
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.executable();
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.executable();
      } else {
        return false;
      }

      _functions = _RustCoreFunctions(_lib!);
      return true;
    } catch (e) {
      print('Failed to load Rust Core: $e');
      return false;
    }
  }

  /// 设置主密码
  static int setupPassword(String password, {String? hint}) {
    final passwordPtr = password.toNativeUtf8();
    final hintPtr = hint?.toNativeUtf8() ?? nullptr;

    try {
      return _functions.setup_password(passwordPtr, hintPtr);
    } finally {
      malloc.free(passwordPtr);
      if (hintPtr != nullptr) malloc.free(hintPtr);
    }
  }

  /// 验证密码
  static bool verifyPassword(String password) {
    final passwordPtr = password.toNativeUtf8();

    try {
      return _functions.verify_password(passwordPtr) != 0;
    } finally {
      malloc.free(passwordPtr);
    }
  }

  /// 添加资产
  static int addAsset(
    String name,
    int type,
    double amount,
    String currency,
    String? symbol,
    String? notes,
  ) {
    final namePtr = name.toNativeUtf8();
    final currencyPtr = currency.toNativeUtf8();
    final symbolPtr = symbol?.toNativeUtf8() ?? nullptr;
    final notesPtr = notes?.toNativeUtf8() ?? nullptr;

    try {
      return _functions.add_asset(
        namePtr,
        type,
        amount,
        currencyPtr,
        symbolPtr,
        notesPtr,
      );
    } finally {
      malloc.free(namePtr);
      malloc.free(currencyPtr);
      if (symbolPtr != nullptr) malloc.free(symbolPtr);
      if (notesPtr != nullptr) malloc.free(notesPtr);
    }
  }

  /// 获取所有资产
  static String getAllAssets() {
    final resultPtr = _functions.get_all_assets();

    if (resultPtr == nullptr) {
      return '[]';
    }

    final result = resultPtr.cast<Utf8>().toDartString();
    _functions.free_string(resultPtr);

    return result;
  }

  /// 更新资产
  static bool updateAsset(
    String id,
    String name,
    int type,
    double amount,
    String currency,
    String? symbol,
    String? notes,
  ) {
    final idPtr = id.toNativeUtf8();
    final namePtr = name.toNativeUtf8();
    final currencyPtr = currency.toNativeUtf8();
    final symbolPtr = symbol?.toNativeUtf8() ?? nullptr;
    final notesPtr = notes?.toNativeUtf8() ?? nullptr;

    try {
      return _functions.update_asset(
            idPtr,
            namePtr,
            type,
            amount,
            currencyPtr,
            symbolPtr,
            notesPtr,
          ) !=
          0;
    } finally {
      malloc.free(idPtr);
      malloc.free(namePtr);
      malloc.free(currencyPtr);
      if (symbolPtr != nullptr) malloc.free(symbolPtr);
      if (notesPtr != nullptr) malloc.free(notesPtr);
    }
  }

  /// 删除资产
  static bool deleteAsset(String id) {
    final idPtr = id.toNativeUtf8();

    try {
      return _functions.delete_asset(idPtr) != 0;
    } finally {
      malloc.free(idPtr);
    }
  }

  /// 导出加密数据
  static String exportData(String password, String outputPath) {
    final passwordPtr = password.toNativeUtf8();
    final pathPtr = outputPath.toNativeUtf8();

    try {
      final resultPtr = _functions.export_data(passwordPtr, pathPtr);
      final result = resultPtr.cast<Utf8>().toDartString();
      _functions.free_string(resultPtr);
      return result;
    } finally {
      malloc.free(passwordPtr);
      malloc.free(pathPtr);
    }
  }

  /// 导入加密数据
  static String importData(String password, String inputPath) {
    final passwordPtr = password.toNativeUtf8();
    final pathPtr = inputPath.toNativeUtf8();

    try {
      final resultPtr = _functions.import_data(passwordPtr, pathPtr);
      final result = resultPtr.cast<Utf8>().toDartString();
      _functions.free_string(resultPtr);
      return result;
    } finally {
      malloc.free(passwordPtr);
      malloc.free(pathPtr);
    }
  }
}

/// Rust 函数签名
class _RustCoreFunctions {
  /// 设置主密码
  final int Function(Pointer<Utf8> password, Pointer<Utf8> hint) setup_password;

  /// 验证密码
  final int Function(Pointer<Utf8> password) verify_password;

  /// 添加资产
  final int Function(
    Pointer<Utf8> name,
    int type,
    double amount,
    Pointer<Utf8> currency,
    Pointer<Utf8> symbol,
    Pointer<Utf8> notes,
  ) add_asset;

  /// 获取所有资产
  final Pointer<Char> Function() get_all_assets;

  /// 更新资产
  final int Function(
    Pointer<Utf8> id,
    Pointer<Utf8> name,
    int type,
    double amount,
    Pointer<Utf8> currency,
    Pointer<Utf8> symbol,
    Pointer<Utf8> notes,
  ) update_asset;

  /// 删除资产
  final int Function(Pointer<Utf8> id) delete_asset;

  /// 导出数据
  final Pointer<Char> Function(Pointer<Utf8> password, Pointer<Utf8> path)
      export_data;

  /// 导入数据
  final Pointer<Char> Function(Pointer<Utf8> password, Pointer<Utf8> path)
      import_data;

  /// 释放字符串
  final void Function(Pointer<Char> ptr) free_string;

  _RustCoreFunctions(DynamicLibrary lib)
      : setup_password = lib
            .lookup<
                NativeFunction<
                    Int32 Function(Pointer<Utf8>, Pointer<Utf8>)>>('setup_password')
            .asFunction(),
        verify_password = lib
            .lookup<NativeFunction<Int32 Function(Pointer<Utf8>)>>(
                'verify_password')
            .asFunction(),
        add_asset = lib
            .lookup<
                NativeFunction<
                    Int32 Function(Pointer<Utf8>, Int32, Double, Pointer<Utf8>,
                        Pointer<Utf8>, Pointer<Utf8>)>>('add_asset')
            .asFunction(),
        get_all_assets = lib
            .lookup<NativeFunction<Pointer<Char> Function()>>('get_all_assets')
            .asFunction(),
        update_asset = lib
            .lookup<
                NativeFunction<
                    Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32, Double,
                        Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)>>(
                'update_asset')
            .asFunction(),
        delete_asset = lib
            .lookup<NativeFunction<Int32 Function(Pointer<Utf8>)>>(
                'delete_asset')
            .asFunction(),
        export_data = lib
            .lookup<
                NativeFunction<
                    Pointer<Char> Function(Pointer<Utf8>, Pointer<Utf8>)>>(
                'export_data')
            .asFunction(),
        import_data = lib
            .lookup<
                NativeFunction<
                    Pointer<Char> Function(Pointer<Utf8>, Pointer<Utf8>)>>(
                'import_data')
            .asFunction(),
        free_string = lib
            .lookup<NativeFunction<Void Function(Pointer<Char>)>>('free_string')
            .asFunction();
}
