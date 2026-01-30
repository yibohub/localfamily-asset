# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

**LocalFamily Asset** 是一款本地优先的家庭资产管理应用，采用 Flutter UI + Rust Core 架构。

核心特点：
- 真·本地存储：所有数据仅存储在设备本地，零数据收集
- AES-256 加密：文件级整库加密，支持 BIP39 助记词/密码恢复
- 跨平台：支持 Windows/Android/iOS/macOS/Linux

## 技术架构

```
Flutter UI (Provider 状态管理)
        ↓
   Rust FFI Bridge
        ↓
Rust Core (加密 + 存储)
  ├─ crypto: aes-256-gcm + argon2id + bip39
  ├─ db: SQLite + 文件级加密
  └─ export: 加密 Zip 导出/导入
```

**重要设计决策**：
- 避免使用 SQLCipher（GPL 许可证传染风险），改用文件级加密
- 所有加密操作在 Rust Core 层完成，Flutter 仅负责 UI
- 数据库文件启动时解密到内存，退出时加密落盘

---

## 常用开发命令

### Flutter 开发

```bash
# 进入 Flutter 应用目录
cd flutter_app

# 获取依赖（需要先配置国内镜像源）
flutter pub get

# 运行应用（Windows）
flutter run -d windows

# 构建 Windows 发布版本
flutter build windows

# 代码检查
flutter analyze

# 运行测试
flutter test                    # 单元测试 + 组件测试
flutter drive \                # 集成测试
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart
```

### Rust Core 开发

```bash
# 进入 Rust 项目目录
cd rust_core

# 开发构建（生成动态库供 Flutter FFI 调用）
cargo build

# 发布构建
cargo build --release

# 运行测试
cargo test

# 代码检查
cargo clippy
```

### 完整构建流程

**⚠️ 重要：Flutter Debug/Release 模式使用不同的 Rust 动态库**

| Flutter 模式 | Rust 构建命令 | DLL 位置 | 大小参考 | 用途 |
|------------|--------------|---------|---------|------|
| Debug | `cargo build` | `rust_core/target/debug/` | ~6MB | 开发调试 |
| Release | `cargo build --release` | `rust_core/target/release/` | ~3MB | 发布部署 |

**`pubspec.yaml` 配置**：
```yaml
assets:
  - ../rust_core/target/debug/  # Debug 模式读取此目录
```

#### 开发调试流程（Debug）

```bash
# 1. 构建 Debug 版本的 Rust Core
cd rust_core
cargo build

# 2. Flutter 自动从 target/debug/ 加载动态库
cd ../flutter_app
flutter run -d windows
```

#### 发布构建流程（Release）

```bash
# 1. 构建 Release 版本的 Rust Core
cd rust_core
cargo build --release

# 2. 将生成的动态库复制到 Flutter 资源目录
# Windows:
copy target\release\localfamily_asset_core.dll ..\flutter_app\assets\
# Linux/macOS:
cp target/release/liblocalfamily_asset_core.* ../flutter_app/assets/

# 3. 构建 Flutter 应用
cd ../flutter_app
flutter build windows
```

**⚠️ 常见错误**：修改 Rust 代码后 `flutter run` 没有更新？
- **Debug 模式**：只需要运行 `cargo build`（自动从 target/debug/ 加载）
- **Release 模式**：需要运行 `cargo build --release` 并手动复制 DLL

#### Rust 代码修改后必须执行的操作

1. 重新编译：`cd rust_core && cargo build`
2. 停止应用：关闭正在运行的 Flutter 应用
3. 复制 DLL：`cp target/debug/localfamily_asset_core.dll ../flutter_app/`
4. 重启应用：`flutter run -d windows`

**常见错误**：修改 Rust 代码后忘记复制 DLL，导致 Flutter 仍在使用旧版本。

**判断是否需要重新编译**：
| 操作 | 需重新编译 Rust |
|------|----------------|
| 修改 Dart 代码 | ❌ 否 |
| 修改 Rust 代码 | ✅ 是 |

---

## 代码架构

### 目录结构（遵循单一职责原则）

```
localfamily-asset/
├── rust_core/                    # Rust 核心层
│   ├── src/
│   │   ├── crypto/               # 加密模块
│   │   │   ├── mod.rs            # 模块导出
│   │   │   ├── aes_gcm.rs        # AES-256-GCM 加密/解密
│   │   │   ├── argon2.rs         # Argon2id 密钥派生
│   │   │   └── bip39.rs          # BIP39 助记词
│   │   ├── db/                   # 数据库模块
│   │   │   ├── mod.rs            # 模块导出
│   │   │   ├── models.rs         # 数据模型（Asset, AssetType 等）
│   │   │   ├── schema.rs         # 数据库表结构
│   │   │   └── crud.rs           # CRUD 操作
│   │   ├── export/               # 导出模块
│   │   │   ├── mod.rs
│   │   │   └── zip.rs            # 加密 Zip 导出/导入
│   │   ├── lib.rs                # 库入口，导出公共 API
│   │   └── ffi.rs                # FFI 接口（C 兼容函数）
│   └── Cargo.toml
│
├── flutter_app/                  # Flutter 应用
│   ├── integration_test/         # 集成测试
│   ├── test/                     # 单元测试 + 组件测试
│   ├── test_driver/              # 测试驱动脚本
│   ├── lib/
│   │   ├── core/                 # 核心层
│   │   │   ├── ffi_bridge.dart   # FFI 桥接层，封装所有 Rust 调用
│   │   │   ├── theme.dart        # 主题配置
│   │   │   └── app.dart          # 应用入口
│   │   ├── models/               # 数据模型（与 Rust 保持一致）
│   │   │   ├── asset.dart        # Asset 模型 + AssetType 枚举
│   │   │   └── portfolio_summary.dart
│   │   ├── providers/            # Provider 状态管理
│   │   │   ├── auth_provider.dart
│   │   │   └── asset_provider.dart
│   │   ├── screens/              # 页面
│   │   │   ├── splash_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── auth/
│   │   │   │   ├── setup_screen.dart
│   │   │   │   └── lock_screen.dart
│   │   │   ├── asset_list_screen.dart
│   │   │   ├── asset_form_screen.dart
│   │   │   └── asset_detail_screen.dart
│   │   ├── widgets/              # 通用组件
│   │   │   ├── asset_summary_card.dart
│   │   │   └── asset_list_item.dart
│   │   └── main.dart
│   └── pubspec.yaml
│
└── docs/                         # 文档
```

### FFI 接口规范

Flutter 与 Rust 的通信通过原始 C FFI 实现（未使用 flutter_rust_bridge）：

**Rust 端**（`rust_core/src/ffi.rs`）：
- 所有导出函数使用 `#[no_mangle]` 和 `extern "C"`
- 字符串使用 `*const c_char`，调用方负责释放
- 返回字符串需通过 `string_to_c_char()` 转换，调用方使用 `free_string()` 释放
- 错误通过 `FfiErrorCode` 枚举（负整数）返回

**Flutter 端**（`flutter_app/lib/core/ffi_bridge.dart`）：
- `FfiBridge` 单例负责加载动态库和函数查找
- 所有指针操作需在 `finally` 块中释放内存
- 使用 `toNativeUtf8()` 和 `malloc.free()` 管理字符串内存

**关键 FFI 函数**：
| 函数 | 作用 |
|------|------|
| `init_app(db_path)` | 初始化应用，设置数据库路径 |
| `setup_password(password, hint)` | 设置主密码，生成盐值并派生密钥 |
| `verify_password(password)` | 验证密码，成功后保存密钥到状态 |
| `add_asset(...)` / `update_asset(...)` / `delete_asset(id)` | 资产 CRUD |
| `get_all_assets()` | 返回 JSON 数组（需 free_string） |
| `export_data(password, output_path)` | 导出加密 Zip |
| `import_data(password, input_path)` | 导入加密 Zip |

---

## 数据模型

### AssetType 枚举（必须保持 Rust ↔ Dart 一致）

| 值 | Rust | Dart | 中文名称 |
|---|------|------|----------|
| 0 | `Property` | `AssetType.property` | 房产 |
| 1 | `Deposit` | `AssetType.deposit` | 存款 |
| 2 | `Stock` | `AssetType.stock` | 股票 |
| 3 | `Fund` | `AssetType.fund` | 基金 |
| 4 | `Insurance` | `AssetType.insurance` | 保单 |
| 5 | `Debt` | `AssetType.debt` | 负债 |

**重要**：修改枚举值时需同步更新：
- `rust_core/src/ffi.rs` 的 `asset_type_from_int()`
- `flutter_app/lib/models/asset.dart` 的 `AssetTypeExtension`

---

## 环境配置

### Flutter 国内镜像（中国网络环境）

项目已提供自动安装脚本 `install_flutter.ps1`：

```powershell
# 使用默认镜像（CFUG 社区镜像）
.\install_flutter.ps1

# 或指定其他镜像源
.\install_flutter.ps1 -Mirror sjtu   # 上海交大镜像
.\install_flutter.ps1 -Mirror tuna   # 清华大学 TUNA 镜像
```

手动配置环境变量：
```powershell
# 临时设置
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

# 永久设置（推荐）
[System.Environment]::SetEnvironmentVariable('PUB_HOSTED_URL', 'https://pub.flutter-io.cn', 'User')
[System.Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL', 'https://storage.flutter-io.cn', 'User')
```

---

## 加密流程

### 密钥派生
1. 用户输入密码/助记词
2. 生成 32 字节随机盐值
3. 使用 Argon2id 派生 32 字节密钥
4. 盐值以十六进制存储在 `settings` 表的 `password_salt` 键中

### 数据库加密（计划中）
- 当前 MVP 版本使用明文 SQLite（开发阶段）
- 生产版本将实现文件级加密：整个 `.db` 文件用 AES-256-GCM 加密
- 启动流程：解密文件 → 内存数据库 → 操作 → 加密落盘

---

## 许可证

GPL-3.0

**重要**：避免引入 GPL 传染的依赖：
- ❌ SQLCipher 开源版（GPL）
- ✅ 自己实现文件级加密（当前方案）
- ✅ 使用 MIT/Apache 2.0 许可证的库（aes-gcm, argon2, bip39 等）
