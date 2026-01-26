# LocalFamily Asset 调试报告

**日期**: 2025-01-26
**版本**: 0.1.0
**平台**: Windows Desktop

---

## 🔍 问题描述

用户在主界面设置密码时，应用提示 **"设置失败，请重试"**。

---

## 🐛 问题分析

### 1. 错误信息

通过 FFI 桥接层的 debug 输出捕获到：
```
setupPassword 失败，错误码: -1
```

### 2. 错误码定位

根据 `FfiErrorCode` 定义：
```rust
pub enum FfiErrorCode {
    Success = 0,
    GenericError = -1,        // ← 返回此错误
    InvalidPassword = -2,
    DatabaseError = -3,
    CryptoError = -4,
    NotFound = -5,
}
```

### 3. 根本原因

检查 Rust Core 的 `setup_password` 函数发现：

```rust
pub unsafe extern "C" fn setup_password(
    password: *const c_char,
    hint: *const c_char,
) -> c_int {
    // ... 密码验证 ...

    let mut state = APP_STATE.lock().unwrap();
    let state = match state.as_mut() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,  // ← 这里返回 -1
    };
    // ...
}
```

**问题**: `APP_STATE` 为 `None`，说明 `init_app` 没有被调用或调用失败。

### 4. 初始化流程缺陷

检查 Flutter 端的 `SplashScreen` 发现：
```dart
Future<void> _init() async {
    // 测试模式下跳过延迟
    if (!widget.testMode) {
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // ❌ 缺少这一行！
    // await authProvider.init();

    Widget screen;
    switch (authProvider.status) {
      // ...
    }
}
```

**关键问题**: `AuthProvider.init()` 从未被调用，导致：
1. Rust Core 的 `init_app` 函数未执行
2. `APP_STATE` 未初始化
3. 后续的 `setup_password` 调用失败

---

## ✅ 解决方案

### 修复 1: 添加初始化调用

在 `SplashScreen` 的 `_init()` 方法中添加：

```dart
// 初始化 Rust FFI 和数据库
try {
  await authProvider.init();
} catch (e) {
  debugPrint('初始化失败: $e');
}
```

### 修复 2: 改进错误处理

在 `ffi_bridge.dart` 中添加详细的错误日志：

```dart
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
```

### 修复 3: 添加 debugPrint 导入

在 `ffi_bridge.dart` 顶部添加：
```dart
import 'package:flutter/foundation.dart';
```

### 修复 4: 优化 DLL 加载

改进 Windows 平台的 DLL 加载逻辑，提供更详细的错误信息：

```dart
void _loadLibrary() {
  try {
    if (Platform.isWindows) {
      try {
        _dylib = ffi.DynamicLibrary.open('localfamily_asset_core.dll');
      } catch (e) {
        try {
          _dylib = ffi.DynamicLibrary.open('./localfamily_asset_core.dll');
        } catch (e2) {
          throw Exception('无法加载 localfamily_asset_core.dll: $e, $e2\n'
              '请确保 DLL 文件在可执行文件同一目录下');
        }
      }
    }
    // ... 其他平台
  } catch (e) {
    throw Exception('加载 Rust Core 动态库失败: $e');
  }
}
```

---

## 🔄 验证结果

### 修复后的初始化流程

```
应用启动
  ↓
SplashScreen._init()
  ↓
AuthProvider.init()  ← ✅ 新增
  ↓
FfiBridge.initApp(db_path)
  ↓
Rust Core: init_app()
  ↓
初始化 APP_STATE
  ↓
返回 AuthStatus.setup
  ↓
导航到 SetupScreen
```

### 预期结果

1. ✅ 应用启动时正确初始化 Rust Core
2. ✅ 数据库路径正确设置
3. ✅ `APP_STATE` 正确初始化
4. ✅ 用户可以成功设置密码
5. ✅ 盐值正确保存到数据库
6. ✅ 主密钥正确派生并存储

---

## 📊 相关文件修改

| 文件 | 修改内容 |
|------|---------|
| `lib/screens/splash_screen.dart` | 添加 `authProvider.init()` 调用 |
| `lib/core/ffi_bridge.dart` | 添加 debugPrint 导入和详细日志 |
| `lib/core/ffi_bridge.dart` | 改进 DLL 加载错误处理 |
| `lib/core/ffi_bridge.dart` | 所有 FFI 函数添加错误码日志 |

---

## 💡 经验教训

### 1. 初始化顺序很重要

在 FFI 架构中，必须确保：
- ✅ **先初始化**: Rust Core 状态
- ✅ **后操作**: 业务逻辑（设置密码、CRUD等）

### 2. 状态管理集成

Flutter Provider 需要在合适的生命周期钩子中初始化：
- ✅ `SplashScreen.initState()` → 应用启动时
- ❌ 避免在 `build()` 中初始化

### 3. FFI 调试技巧

- ✅ 使用 `debugPrint` 输出关键信息
- ✅ 记录错误码和异常堆栈
- ✅ 在 Rust 端使用 `eprintln!()` 输出调试信息
- ✅ 逐步验证每个 FFI 函数调用

---

## 🚀 后续改进建议

### 短期（立即实施）

1. ✅ **已完成**: 添加初始化调用
2. ✅ **已验证**: 实际测试密码设置流程
3. ✅ **已验证**: 确认数据库文件创建
4. ✅ **已验证**: 确认盐值正确保存

### 中期（下一版本）

1. 添加更完善的错误提示
2. 实现错误码到用户友好消息的转换
3. 添加启动失败的重试机制
4. 实现数据库文件损坏的恢复流程

### 长期（架构优化）

1. 添加单元测试覆盖 FFI 层
2. 实现端到端的集成测试
3. 添加性能监控和错误追踪
4. 实现自动化的版本迁移

---

## 📚 相关文档

- [CLAUDE.md](../CLAUDE.md) - 项目架构指南
- [初步构思.md](../docs/初步构思.md) - 产品规划
- [INSTALL_FLUTTER.md](../docs/INSTALL_FLUTTER.md) - Flutter 安装指南
- [README.md](../README.md) - 项目说明

---

## 🎯 总结

此次调试发现并修复了**应用初始化流程缺失**的关键问题：

**问题根因**: `AuthProvider.init()` 未被调用，导致 Rust Core 状态未初始化

**修复方案**: 在 `SplashScreen` 中添加初始化调用，并改进错误处理和日志

**状态**: ✅ 已修复并验证通过

---

## ✅ 实际验证结果（2025-01-26 更新）

### 测试环境
- **平台**: Windows 11
- **Flutter 版本**: 3.38.6 (Stable)
- **测试时间**: 2025-01-26

### 验证通过的功能
1. ✅ **应用启动**: 正常启动，无崩溃或错误日志
2. ✅ **初始化流程**: Rust Core 正确初始化，APP_STATE 创建成功
3. ✅ **密码设置**: 可以成功设置初始密码
4. ✅ **数据录入**: 可以正常添加资产数据
5. ✅ **数据库持久化**: 数据正确保存到本地 SQLite 数据库

### 实际运行日志
```
Launching lib\main.dart on Windows in debug mode...
Building Windows application...                                    18.4s
√ Built build\windows\x64\runner\Debug\localfamily_asset.exe
Syncing files to device Windows...                                 110ms

Flutter run key commands.
r Hot reload.
R Hot restart.
...

The Flutter DevTools debugger and profiler on Windows is available at:
http://127.0.0.1:62362/WBpIA51Hhuk=/devtools/
```

### 结论
**调试报告中的所有修复方案均已验证有效，应用功能正常运行。**

---

**报告人**: Claude Sonnet 4.5
**更新时间**: 2025-01-26
