# LocalFamily Asset

> 真·本地优先的家庭资产管理应用 - AES-256 加密 + 零数据收集 + 完全开源

## 核心特点

| 特性 | 说明 |
|------|------|
| **真·本地存储** | 所有数据仅存储在设备本地，无云端同步 |
| **零数据收集** | 不联网、无追踪、无第三方 SDK |
| **AES-256 加密** | 文件级整库加密，支持密码和 BIP39 助记词恢复 |
| **跨平台支持** | Windows / Android / iOS / macOS / Linux |
| **完全开源** | GPL-3.0 许可证，代码可审计 |

## 技术架构

```
Flutter UI (Provider 状态管理)
        ↓
   Rust FFI Bridge (原始 C FFI)
        ↓
Rust Core
  ├─ crypto: aes-256-gcm + argon2id + bip39
  ├─ db: SQLite + 文件级加密
  └─ export: 加密 Zip 导出/导入
```

## 快速开始

### 环境要求

- **Flutter**: >= 3.24.0
- **Rust**: 2021 Edition (1.70+)
- **操作系统**: Windows / macOS / Linux

### 1. 安装 Flutter (Windows)

项目提供自动安装脚本：

```powershell
# 使用默认镜像（CFUG 社区镜像）
.\install_flutter.ps1

# 或指定其他镜像源
.\install_flutter.ps1 -Mirror sjtu   # 上海交大镜像
.\install_flutter.ps1 -Mirror tuna   # 清华大学 TUNA 镜像
```

手动配置环境变量（中国网络环境）：
```powershell
# 临时设置
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

# 永久设置（推荐）
[System.Environment]::SetEnvironmentVariable('PUB_HOSTED_URL', 'https://pub.flutter-io.cn', 'User')
[System.Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL', 'https://storage.flutter-io.cn', 'User')
```

### 2. 安装 Rust

```powershell
# Windows (使用 rustup)
winget install Rustlang.Rust.MSVC

# 或访问 https://rustup.rs/
```

### 3. 完整构建流程

```bash
# 1. 构建 Rust Core
cd rust_core
cargo build --release

# 2. 将生成的动态库复制到 Flutter 资源目录
# Windows: target/release/localfamily_asset_core.dll -> flutter_app/assets/
# Linux: target/release/liblocalfamily_asset_core.so -> flutter_app/assets/
# macOS: target/release/liblocalfamily_asset_core.dylib -> flutter_app/assets/

# 3. 构建 Flutter 应用
cd ../flutter_app
flutter pub get
flutter build windows
```

### 4. 运行开发版本

```bash
cd flutter_app
flutter run -d windows
```

## 开发命令

### Flutter 开发

```bash
cd flutter_app

# 获取依赖
flutter pub get

# 运行应用（Windows）
flutter run -d windows

# 构建 Windows 发布版本
flutter build windows

# 代码检查
flutter analyze
```

### Rust Core 开发

```bash
cd rust_core

# 开发构建
cargo build

# 发布构建
cargo build --release

# 运行测试
cargo test

# 代码检查
cargo clippy
```

## 项目结构

```
localfamily-asset/
├── rust_core/                    # Rust 核心层
│   ├── src/
│   │   ├── crypto/               # 加密模块
│   │   │   ├── mod.rs
│   │   │   ├── aes_gcm.rs        # AES-256-GCM 加密/解密
│   │   │   ├── argon2.rs         # Argon2id 密钥派生
│   │   │   └── bip39.rs          # BIP39 助记词
│   │   ├── db/                   # 数据库模块
│   │   │   ├── mod.rs
│   │   │   ├── models.rs         # 数据模型
│   │   │   ├── schema.rs         # 数据库表结构
│   │   │   ├── crud.rs           # CRUD 操作
│   │   │   └── custom_types.rs   # 自定义资产类型
│   │   ├── export/               # 导出模块
│   │   │   ├── mod.rs
│   │   │   └── zip.rs            # 加密 Zip 导出/导入
│   │   ├── lib.rs                # �入口
│   │   └── ffi.rs                # FFI 接口（C 兼容）
│   └── Cargo.toml
│
├── flutter_app/                  # Flutter 应用
│   ├── lib/
│   │   ├── core/                 # 核心层
│   │   │   ├── ffi_bridge.dart   # FFI 桥接层
│   │   │   ├── theme.dart        # 主题配置
│   │   │   └── app.dart          # 应用入口
│   │   ├── models/               # 数据模型
│   │   │   ├── asset.dart        # Asset 模型 + AssetType 枚举
│   │   │   ├── custom_asset_type.dart
│   │   │   └── portfolio_summary.dart
│   │   ├── providers/            # Provider 状态管理
│   │   │   ├── auth_provider.dart
│   │   │   ├── asset_provider.dart
│   │   │   └── custom_type_provider.dart
│   │   ├── screens/              # 页面
│   │   │   ├── splash_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── auth/
│   │   │   │   ├── setup_screen.dart
│   │   │   │   └── lock_screen.dart
│   │   │   ├── asset_detail_screen.dart
│   │   │   ├── asset_form_screen.dart
│   │   │   └── asset_history_screen.dart
│   │   ├── widgets/              # 通用组件
│   │   │   ├── asset_list_item.dart
│   │   │   ├── asset_summary_card.dart
│   │   │   ├── asset_type_filter_bar.dart
│   │   │   └── smart_asset_name_input.dart
│   │   └── main.dart
│   └── pubspec.yaml
│
├── CLAUDE.md                     # Claude Code 指导文档
├── install_flutter.ps1           # Flutter 自动安装脚本
└── README.md
```

## 资产类型

### 内置资产类型

| 类型值 | 中文名称 | 图标 | 是否负债 |
|--------|----------|------|----------|
| `property` | 房产 | home | 否 |
| `deposit` | 存款 | account_balance | 否 |
| `stock` | 股票 | trending_up | 否 |
| `fund` | 基金 | pie_chart | 否 |
| `insurance` | 保单 | security | 否 |
| `debt` | 负债 | credit_card | 是 |
| `mortgage` | 房贷 | home_work | 是 |
| `carLoan` | 车贷 | directions_car | 是 |
| `creditCard` | 信用卡 | credit_card | 是 |
| `personalLoan` | 个人贷款 | person | 是 |
| `privateLoan` | 私人借款 | handshake | 是 |

### 自定义资产类型

应用支持用户自定义资产类型，可设置为资产或负债类型。

## FFI 接口

Flutter 与 Rust 通过原始 C FFI 通信：

**关键函数**：
| 函数 | 作用 |
|------|------|
| `init_app(db_path)` | 初始化应用，设置数据库路径 |
| `setup_password(password, hint)` | 设置主密码，生成盐值并派生密钥 |
| `verify_password(password)` | 验证密码 |
| `add_asset_with_type(...)` | 添加资产（支持自定义类型） |
| `update_asset_with_type(...)` | 更新资产 |
| `delete_asset(id)` | 删除资产 |
| `get_all_assets()` | 获取所有资产（JSON） |
| `search_assets_by_name(...)` | 按名称搜索资产 |
| `get_asset_changes()` | 获取变更历史（审计日志） |
| `create_custom_asset_type(...)` | 创建自定义资产类型 |
| `get_custom_asset_types()` | 获取所有自定义类型 |
| `delete_custom_asset_type(id)` | 删除自定义类型 |
| `export_data(password, output_path)` | 导出加密 Zip |
| `import_data(password, input_path)` | 导入加密 Zip |

## 加密流程

1. **密钥派生**: 密码 + 32字节随机盐值 → Argon2id → 32字节密钥
2. **数据存储**: 盐值以十六进制存储在 `settings` 表
3. **导出/导入**: 整个数据库文件使用 AES-256-GCM 加密为 Zip

## 常见问题

### Q: Flutter FFI 调用 Rust 函数报错 "DynamicLibrary.open() failed"

A: 确保 Rust 动态库已构建且路径正确：
- Windows: `flutter_app/assets/localfamily_asset_core.dll`

### Q: 修改 Rust 代码后 Flutter 没有更新？

A: 需重新构建 Rust Core：
```bash
cd rust_core && cargo build --release
# 然后复制动态库到 flutter_app/assets/
```

### Q: Dart 和 Rust 的 AssetType 枚举值不一致？

A: 检查两个文件：
- `rust_core/src/ffi.rs` 的 `asset_type_from_int()`
- `flutter_app/lib/models/asset.dart` 的 `AssetTypeExtension.value`

## 许可证

GPL-3.0

**重要**: 避免引入 GPL 传染的依赖（如 SQLCipher），当前使用文件级加密方案。

## 联系方式

- 开发者: yibohub
- 问题反馈: [GitHub Issues](https://github.com/yibohub/localfamily-asset/issues)
