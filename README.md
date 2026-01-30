# LocalFamily Asset (隐财)

> 你的资产，只有你知道 - 一本加密的家庭资产账本

**隐财**是一款隐私优先的家庭资产登记管理工具，采用本地加密存储，所有数据只保存在你的设备上。

---

## ⚠️ 产品说明

**重要**：隐财是一个纯工具性质的资产登记管理应用。

- ✅ **是**：一本加密的家庭资产账本
- ✅ **是**：隐私优先的数据记录工具
- ✅ **是**：本地安全的资产清单应用
- ❌ **不是**：理财产品
- ❌ **不是**：投资顾问
- ❌ **不是**：交易平台

我们不提供理财产品推荐、不进行投资建议、不支持资产交易——只帮你安全、私密地记录和管理家庭资产信息。

## 核心特点

| 特性 | 说明 |
|------|------|
| **📝 多资产记录** | 房产、存款、股票、基金、保单、负债统一登记 |
| **🔒 本地加密存储** | 所有数据仅存储在设备本地，无云端同步 |
| **🔐 AES-256 加密** | 文件级整库加密，支持密码和 BIP39 助记词恢复 |
| **📊 可视化统计** | 自动计算资产总额，按类型分组展示 |
| **💾 数据可控** | 支持加密导出/导入，随时备份恢复 |
| **🖥️ 跨平台支持** | Windows / Android / iOS / macOS / Linux |
| **👁️ 完全开源** | GPL-3.0 许可证，代码可审计 |

## 核心功能

### 资产登记管理

记录和管理家庭各类资产信息，每条资产记录包含以下字段：

**基本字段**：
- **名称**：资产名称（如"招商银行存款"、"腾讯股票"）
- **类型**：房产/存款/股票/基金/保单/负债等（支持自定义类型）
- **金额**：资产价值或负债金额
- **币种**：支持 CNY/USD/HKD/EUR 等
- **账户**：可选，如银行名称、证券账户等
- **发生日期**：购买日期或记录日期
- **买入价/现价**：✅ 已实现，用于计算盈亏（适用于股票、基金等）
- **备注**：详细信息记录（详见下方说明）
- **标签**：可选，用于分类和筛选

**当前功能状态**：

| 功能 | 状态 | 说明 |
|------|------|------|
| 买入价/现价输入 | ✅ 已实现 | 支持记录和自动计算盈亏 |
| 盈亏百分比显示 | ✅ 已实现 | 列表和详情页显示盈亏信息 |
| 预设详细字段 | ⏳ 计划中 | 未来版本将添加（见路线图） |

**详细信息记录方式**：

目前，除买入价/现价外，其他详细信息（如地址、面积、股票代码等）通过**备注字段**灵活记录：

| 资产类型 | 备注记录示例 |
|---------|-------------|
| 房产 | 地址：xx市xx区xx路xx号；面积：120㎡；户型：3室2厅；贷款信息：工商银行贷款200万 |
| 存款 | 银行：招商银行；账户类型：定期存款；利率：3.5%；到期日：2025-12-31 |
| 股票 | 代码：00700.HK；持仓数量：1000股；买入时间：2024-01-15 |
| 基金 | 代码：110022；持有份额：5000份 |
| 保单 | 保险类型：重疾险；保单号：P202401010001；受益人：张三；保费：年缴5000元 |
| 负债 | 负债类型：信用卡；额度：50000元；还款日：每月5号 |

**设计理念**：通过灵活的备注字段，你可以自由记录任何与资产相关的详细信息，而不受预设字段的限制。

### 隐私与安全

- **零数据收集**：不联网、无追踪、无第三方 SDK
- **本地优先**：数据永不离开你的设备
- **军工级加密**：AES-256-GCM + Argon2id 密钥派生

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

### 产品相关

**Q: 隐财是理财产品吗？**

A: 不是。隐财是一个纯工具性质的资产登记管理应用，不涉及任何交易、投资或理财建议。我们只帮你记录和管理资产信息。

**Q: 隐财会推荐理财产品吗？**

A: 不会。我们只提供资产登记和统计功能，不进行任何产品推荐。

**Q: 为什么不做云端同步？**

A: 云端同步意味着数据要上传到服务器，这与我们的隐私优先定位冲突。我们提供加密导出/导入功能，用户可以手动在设备间传输数据。

**Q: 设备丢了数据怎么办？**

A: 我们强烈建议用户定期使用加密导出功能备份数据。由于所有数据都在本地且加密，设备丢失意味着数据丢失（这是隐私保护的代价）。

**Q: 忘记密码怎么办？**

A: 由于使用强加密保护，忘记密码无法找回数据。建议使用助记词恢复功能作为备份。

### 技术相关

**Q: 修改 Rust 代码后 Flutter 没有更新？**

A: **⚠️ 常见错误**：修改 Rust 代码后忘记复制 DLL，导致 Flutter 仍在使用旧版本。

**Rust 代码修改后的操作流程**：
1. 重新编译：`cd rust_core && cargo build`
2. 停止应用：关闭正在运行的 Flutter 应用
3. 复制 DLL：`cp target/debug/localfamily_asset_core.dll ../flutter_app/`
4. 重启应用：`flutter run -d windows`

**判断是否需要重新编译**：
| 操作 | 需重新编译 Rust |
|------|----------------|
| 修改 Dart 代码 | ❌ 否 |
| 修改 Rust 代码 | ✅ 是 |

**Q: Flutter FFI 调用 Rust 函数报错 "DynamicLibrary.open() failed"**

A: 确保 Rust 动态库已构建且路径正确：
- Windows: `flutter_app/assets/localfamily_asset_core.dll`

**Q: Dart 和 Rust 的 AssetType 枚举值不一致？**

A: 检查两个文件：
- `rust_core/src/ffi.rs` 的 `asset_type_from_int()`
- `flutter_app/lib/models/asset.dart` 的 `AssetTypeExtension.value`

**Q: 如何调试 FFI 数据传递问题？**

A: **快速诊断**：
```bash
# 检查 DLL 文件修改时间
ls -la rust_core/target/debug/localfamily_asset_core.dll
ls -la flutter_app/localfamily_asset_core.dll

# 直接查询数据库验证数据
cd rust_core
cargo run --example check_all
```

**调试方法**：
- `eprintln!()` in Rust → 输出会显示在 Flutter 控制台
- Dart `debugPrint()` → Dart 端调试
- 直接 SQL 查询 → 隔离数据库问题

**Q: 为什么要开源？**

A: 开源让代码可以接受公众审计，证明我们确实做到了隐私保护，也让大家可以验证加密实现的安全性。

---

## 与云端记账软件对比

| 特性 | 隐财 | 云端记账软件 |
|------|------|-------------|
| 数据存储 | 本地设备 | 云端服务器 |
| 隐私风险 | 用户完全掌控 | 平台可访问 |
| 网络依赖 | 离线可用 | 必须联网 |
| 数据收集 | 零收集 | 可能收集 |
| 产品定位 | 登记工具 | 理财平台 |

**核心差异化**：真正的隐私保护，数据不离开设备

---

## 品牌文档

更多品牌信息请查看：
- [品牌指南](docs/brand/BRAND_GUIDELINES.md) - 完整的品牌视觉和使用规范
- [产品定位说明](docs/brand/product-positioning.md) - 详细的产品定位和差异化
- [设计哲学](docs/brand/design-philosophy.md) - Cryptic Sanctuary 设计理念

---

## 路线图

### 已完成 ✅

- [x] 买入价/现价功能 - 支持记录投资成本和当前价值，自动计算盈亏
- [x] 盈亏百分比显示 - 在列表和详情页显示盈亏信息

### 计划中 ⏳

**数据增强**：
- [ ] 预设详细字段 - 为不同资产类型添加专属字段（如房产的地址/面积、股票的代码/持仓量等）
- [ ] 字段模板 - 为常见资产类型提供预设模板，快速填充常用信息
- [ ] 资产图片附件支持 - 支持上传保单、房产证等图片附件
- [ ] 资产价值变化趋势图 - 追踪资产价值的历史变化

**功能完善**：
- [ ] 完善资产变更历史和审计日志
- [ ] 添加到期提醒功能（保单到期、存款到期等）
- [ ] 支持多设备数据合并
- [ ] 资产导入模板 - 支持 Excel/CSV 批量导入

**平台支持**：
- [ ] 发布移动端版本（Android/iOS）
- [ ] Web 端版本（支持跨平台访问）

---

## 许可证

GPL-3.0

**重要**: 避免引入 GPL 传染的依赖（如 SQLCipher），当前使用文件级加密方案。

## 联系方式

- 开发者: yibohub
- 问题反馈: [GitHub Issues](https://github.com/yibohub/localfamily-asset/issues)
