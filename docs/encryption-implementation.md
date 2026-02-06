# 数据库加密功能实现文档

## 概述

本文档记录了 LocalFamily Asset 应用从明文数据库迁移到加密数据库的完整实现过程。

## 问题描述

**初始问题**：应用中的数据库文件可以通过 Navicat Premium 直接查看，违反了"真·本地存储 + AES-256 加密"的设计原则。

**根本原因**：Flutter 端使用旧的明文 API（`init_app`），直接打开磁盘上的 SQLite 数据库文件。

## 解决方案

### V2 加密 API 架构

```
Flutter UI
    ↓
FfiBridge (V2 API)
    ↓
Rust Core (内存数据库 + 文件级加密)
    ├─ verify_password_v2: 解密到内存
    ├─ setup_password_v2: 创建加密数据库
    ├─ save_database: 加密保存到磁盘
    └─ cleanup_app: 清理并保存
```

**文件格式**：
```
┌─────────────────────────────────────────┐
│ Magic Header (8B): "LFAENC01"          │
├─────────────────────────────────────────┤
│ Version (1B): 0x01                      │
├─────────────────────────────────────────┤
│ Salt (32B)                              │
├─────────────────────────────────────────┤
│ Encrypted Payload (AES-256-GCM):        │
│   - nonce (12B)                         │
│   - ciphertext + auth_tag               │
└─────────────────────────────────────────┘
```

## 修改内容

### 1. Rust 端新增/修改

| 函数 | 状态 | 说明 |
|------|------|------|
| `init_app_v2` | 新增 | 检测加密/明文数据库 |
| `verify_password_v2` | 新增 | 解密数据库到内存 |
| `setup_password_v2` | 新增 | 创建加密数据库 |
| `save_database` | 新增 | 加密保存到磁盘 |
| `cleanup_app` | 新增 | 清理并保存 |
| `with_db_connection` | 新增 | 统一数据库访问辅助函数 |
| 23 个数据操作函数 | 修改 | 使用 `with_db_connection` 支持内存数据库 |

### 2. Flutter 端修改

**ffi_bridge.dart**：
- 新增 V2 API 绑定和公共方法
- 保留旧版 API（待清理）

**auth_provider.dart**：
| 方法 | 修改前 | 修改后 |
|------|--------|--------|
| `init()` | `initApp()` | `initAppV2()` |
| `setupPassword()` | `setupPassword()` | `setupPasswordV2()` + `saveDatabase()` |
| `unlock()` | `verifyPassword()` | `verifyPasswordV2()` |
| `changePassword()` | `verifyPassword()` | `verifyPasswordV2()` |
| `reset()` | `initApp()` | `initAppV2()` |
| `resetPassword()` | `setupPassword()` | `setupPasswordV2()` + `saveDatabase()` |

### 3. 辅助函数

**with_db_connection**：统一数据库访问接口，优先使用内存数据库（V2 模式），回退到磁盘数据库（兼容旧模式）。

```rust
fn with_db_connection<F, R>(
    state: &AppState,
    f: F,
) -> DbResult<R>
where
    F: FnOnce(&Connection) -> DbResult<R>,
{
    // 优先使用内存数据库（V2 加密模式）
    if let Some(ref conn) = state.memory_conn {
        return f(conn);
    }
    // 回退到磁盘数据库（旧模式）
    let conn = open_db(&state.db_path)?;
    f(&conn)
}
```

## 数据库迁移逻辑

`verify_password_v2` 支持三种场景：

1. **新数据库**：创建内存数据库，初始化表结构
2. **明文数据库**：加载到内存，下次保存时自动加密
3. **加密数据库**：解密到内存

## 验证结果

### 加密验证

| 项目 | 修改前 | 修改后 |
|------|--------|--------|
| 文件类型 | `SQLite 3.x database` | `data` |
| Navicat 可读 | ✅ 是 | ❌ 否 |

### 功能验证

```
✅ 添加资产：成功
✅ 添加负债：成功
✅ 数据库自动加密保存：成功
✅ 应用重启后解密加载：成功
```

## 待清理内容

### Dart 端 (ffi_bridge.dart)

可删除以下内容：

```dart
// 变量声明
late final int Function(ffi.Pointer<ffi.Char>) _initApp;
late final int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>) _setupPassword;
late final int Function(ffi.Pointer<ffi.Char>) _verifyPassword;

// 函数加载
_initApp = _dylib.lookup<...>('init_app').asFunction();
_setupPassword = _dylib.lookup<...>('setup_password').asFunction();
_verifyPassword = _dylib.lookup<...>('verify_password').asFunction();

// 公共方法
Future<bool> initApp(String dbPath) async { ... }
Future<bool> setupPassword(String password, {String? hint}) async { ... }
Future<bool> verifyPassword(String password) async { ... }
```

### Rust 端 (ffi.rs)

可删除以下函数：

- `init_app` (约第 103-117 行)
- `setup_password` (约第 120-195 行)
- `verify_password` (约第 197-312 行)

**清理原因**：
- V2 API 已完全集成
- V2 API 支持明文数据库自动迁移
- 删除后可减少代码维护负担

## 技术要点

### 密钥派生

```
用户密码/助记词
    ↓
生成 32 字节随机盐值
    ↓
Argon2id 派生 32 字节密钥
    ↓
盐值存储在 settings 表 (十六进制)
```

### 加密算法

- **算法**: AES-256-GCM
- **密钥**: Argon2id 派生
- **认证**: GCM 认证标签
- **文件级加密**: 整个数据库文件加密

### 数据生命周期

```
1. 启动: init_app_v2 → 检测数据库类型
2. 解锁: verify_password_v2 → 解密到内存
3. 操作: 内存数据库中 CRUD 操作
4. 保存: save_database → 加密写入磁盘
5. 退出: cleanup_app → 保存并清理内存
```

## 安全考虑

1. **内存安全**: 敏感数据使用后立即清零
2. **文件安全**: 整个数据库文件加密，无明文残留
3. **密钥安全**: 密钥仅在内存中存在，永不写入磁盘
4. **迁移安全**: 明文数据库自动迁移到加密格式

## 相关文件

- `rust_core/src/ffi.rs`: FFI 接口实现
- `rust_core/src/db/encrypted.rs`: 加密/解密逻辑
- `flutter_app/lib/core/ffi_bridge.dart`: FFI 桥接层
- `flutter_app/lib/providers/auth_provider.dart`: 认证状态管理

## 更新日期

2025-02-06
