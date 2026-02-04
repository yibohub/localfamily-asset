# CLAUDE.md

项目开发指南（Claude Code 使用）

## 项目概述

**LocalFamily Asset** - 本地优先的家庭资产管理应用（Flutter UI + Rust Core）

核心特点：
- 真·本地存储：所有数据仅存储在设备本地，零数据收集
- AES-256 加密：文件级整库加密，支持 BIP39 助记词/密码恢复
- 跨平台：Windows/Android/iOS/macOS/Linux

## 技术架构

```
Flutter UI (Provider 状态管理)
        ↓
   Rust FFI Bridge (原始 C FFI)
        ↓
Rust Core (加密 + 存储)
  ├─ crypto: aes-256-gcm + argon2id + bip39
  ├─ db: SQLite + 文件级加密
  └─ export: 加密 Zip 导出/导入
```

**重要设计决策**：
- 避免使用 SQLCipher（GPL 许可证传染风险），改用文件级加密
- 所有加密操作在 Rust Core 层完成，Flutter 仅负责 UI

## 常用开发命令

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

### 修改 Rust 代码后

**⚠️ 重要**：修改 Rust 代码后必须重新编译

1. 重新编译：`cd rust_core && cargo build`
2. 停止应用：关闭正在运行的 Flutter 应用
3. 重启应用：`flutter run -d windows`（Debug 模式自动从 target/debug/ 加载）

| 操作 | 需重新编译 Rust |
|------|----------------|
| 修改 Dart 代码 | ❌ 否 |
| 修改 Rust 代码 | ✅ 是 |

## 代码架构

### 目录结构

```
localfamily-asset/
├── rust_core/                    # Rust 核心层
│   ├── src/
│   │   ├── crypto/               # 加密模块
│   │   ├── db/                   # 数据库模块
│   │   ├── export/               # 导出模块
│   │   ├── lib.rs                # 库入口
│   │   └── ffi.rs                # FFI 接口
│   └── Cargo.toml
│
├── flutter_app/                  # Flutter 应用
│   ├── lib/
│   │   ├── core/                 # 核心层
│   │   │   ├── ffi_bridge.dart   # FFI 桥接层
│   │   │   ├── theme.dart        # 主题配置
│   │   │   └── app.dart          # 应用入口
│   │   ├── models/               # 数据模型
│   │   │   ├── financial_models.dart    # ✅ 分离的 Asset/Liability 类
│   │   │   ├── custom_asset_type.dart
│   │   │   ├── asset_change.dart        # 审计日志
│   │   │   └── portfolio_summary.dart
│   │   ├── providers/            # Provider 状态管理
│   │   │   ├── financial_provider.dart  # ✅ 新 Provider
│   │   │   ├── auth_provider.dart
│   │   │   ├── custom_type_provider.dart
│   │   │   └── theme_provider.dart
│   │   ├── screens/              # 页面
│   │   │   ├── splash_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── auth/                    # 认证页面
│   │   │   │   ├── setup_screen.dart
│   │   │   │   └── lock_screen.dart
│   │   │   ├── main/                    # ✅ 主界面（标签页）
│   │   │   │   ├── main_navigation_screen.dart
│   │   │   │   ├── assets_tab_screen.dart       # 资产标签页
│   │   │   │   ├── liabilities_tab_screen.dart  # 负债标签页
│   │   │   │   └── overview_tab_screen.dart     # 概览标签页
│   │   │   ├── financial_list_screen.dart        # 资产负债列表页
│   │   │   ├── financial_record_form_screen.dart # 记录表单页
│   │   │   └── financial_record_detail_screen.dart # 记录详情页
│   │   ├── widgets/              # 通用组件
│   │   │   ├── smart_financial_record_name_input.dart # ✅ 智能输入组件
│   │   │   ├── financial_record_form.dart               # 记录表单
│   │   │   ├── liability_grouped_list.dart             # 负债分组列表
│   │   │   ├── liability_list_tile.dart                # 负债列表项
│   │   │   ├── asset_type_filter_bar.dart              # 资产类型筛选
│   │   │   ├── liability_type_filter_bar.dart          # 负债类型筛选
│   │   │   ├── custom_type_manage_dialog.dart          # 自定义类型管理
│   │   │   └── add_asset_dialog.dart                   # 快速添加
│   │   └── main.dart
│   └── pubspec.yaml
│
└── docs/                         # 文档
```

## 数据模型架构（v0.2.0+）

**✅ 迁移已完成**

采用分离模型架构，类型安全且职责明确：

```dart
// 资产类
class Asset extends FinancialRecord {
  final AssetType type;  // property, deposit, stock, fund, insurance
  final String? account;
  final double? buyPrice;
  final double? currentPrice;
}

// 负债类
class Liability extends FinancialRecord {
  final LiabilityType type;  // debt, mortgage, carLoan, creditCard, personalLoan, privateLoan
  final String? lender;
  final String? issuer;
  final DateTime? dueDate;
}
```

**架构优势**：
- ✅ 类型安全：编译时检查，避免混淆资产和负债
- ✅ 职责明确：Asset 和 Liability 各自管理专属字段
- ✅ 旧模型代码已完全清理

### 资产类型（AssetType）

| 值 | 中文名称 |
|---|----------|
| `property` | 房产 |
| `deposit` | 存款 |
| `stock` | 股票 |
| `fund` | 基金 |
| `insurance` | 保单 |

### 负债类型（LiabilityType）

| 值 | 中文名称 |
|---|----------|
| `debt` | 其他负债 |
| `mortgage` | 房贷 |
| `carLoan` | 车贷 |
| `creditCard` | 信用卡 |
| `personalLoan` | 个人贷款 |
| `privateLoan` | 私人借款 |

## 同名资产智能合并

应用自动将同名资产合并显示，提升浏览体验：

**分组规则**：
- 同一名称的多个资产自动合并为分组卡片
- 使用名称规范化处理空格差异（"招商银行" 和 "招商 银行" 会被合并）
- 去除零宽字符等不可见字符
- 点击分组卡片可展开查看所有子账户

**示例**：
- 5个"建设银行存款"账户 → 显示为1个分组卡片（5个账户）
- 单一资产 → 直接显示为独立卡片

**实现位置**：
- 资产分组：`flutter_app/lib/screens/main/assets_tab_screen.dart`
- 负债分组：`flutter_app/lib/widgets/liability_grouped_list.dart`

## FFI 接口规范

Flutter 与 Rust 通过原始 C FFI 通信：

**Rust 端**（`rust_core/src/ffi.rs`）：
- 所有导出函数使用 `#[no_mangle]` 和 `extern "C"`
- 字符串使用 `*const c_char`，调用方负责释放
- 返回字符串通过 `string_to_c_char()` 转换，调用方使用 `free_string()` 释放

**Flutter 端**（`flutter_app/lib/core/ffi_bridge.dart`）：
- `FfiBridge` 单例负责加载动态库和函数查找
- 所有指针操作需在 `finally` 块中释放内存
- 使用 `toNativeUtf8()` 和 `malloc.free()` 管理字符串内存

**关键 FFI 函数**：

| 函数 | 作用 |
|------|------|
| `init_app(db_path)` | 初始化应用 |
| `setup_password(password, hint)` | 设置主密码 |
| `verify_password(password)` | 验证密码 |
| `add_asset_with_extra_fields()` | 添加资产 |
| `add_liability_with_extra_fields()` | 添加负债 |
| `update_asset_with_extra_fields()` | 更新资产 |
| `update_liability_with_extra_fields()` | 更新负债 |
| `get_assets_only()` | 获取资产列表 |
| `get_liabilities_only()` | 获取负债列表 |
| `delete_asset()` / `delete_liability()` | 删除记录 |
| `get_asset_changes()` | 获取审计日志 |
| `export_data(password, output_path)` | 导出加密 Zip |
| `import_data(password, input_path)` | 导入加密 Zip |

## 命名规则（FFI 通信）

**核心原则**：Dart 驼峰 ↔ Rust 蛇形，FFI 使用蛇形命名

```
Dart              Rust             FFI
carLoan     →    car_loan     →   "car_loan"
creditCard  →    credit_card  →   "credit_card"
```

**Dart 端**：发送/接收使用 `.snakeCaseName`

**Rust 端**：直接使用蛇形命名

## 环境配置

### Flutter 国内镜像

项目提供自动安装脚本 `install_flutter.ps1`：

```powershell
# 使用默认镜像（CFUG 社区镜像）
.\install_flutter.ps1

# 或指定其他镜像源
.\install_flutter.ps1 -Mirror sjtu   # 上海交大镜像
.\install_flutter.ps1 -Mirror tuna   # 清华大学 TUNA 镜像
```

手动配置环境变量：
```powershell
# 永久设置（推荐）
[System.Environment]::SetEnvironmentVariable('PUB_HOSTED_URL', 'https://pub.flutter-io.cn', 'User')
[System.Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL', 'https://storage.flutter-io.cn', 'User')
```

## 加密流程

### 密钥派生
1. 用户输入密码/助记词
2. 生成 32 字节随机盐值
3. 使用 Argon2id 派生 32 字节密钥
4. 盐值以十六进制存储在 `settings` 表的 `password_salt` 键中

### 数据库加密（计划中）
- 当前 MVP 版本使用明文 SQLite（开发阶段）
- 生产版本将实现文件级加密：整个 `.db` 文件用 AES-256-GCM 加密

## 许可证

GPL-3.0

**重要**：避免引入 GPL 传染的依赖：
- ❌ SQLCipher 开源版（GPL）
- ✅ 自己实现文件级加密（当前方案）
- ✅ 使用 MIT/Apache 2.0 许可证的库（aes-gcm, argon2, bip39 等）
