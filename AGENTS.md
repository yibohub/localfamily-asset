# AGENTS.md

LocalFamily Asset（隐财）：本地加密的家庭资产登记应用。两个包：`flutter_app/`（Flutter UI，Provider 状态管理）+ `rust_core/`（Rust 核心），通过**原始 C FFI** 通信，无 flutter_rust_bridge 代码生成。

## 常用命令

```bash
# Rust Core（在 rust_core/ 下）
cargo build            # 开发构建；--release 用于发布
cargo test             # 含 tests/test_custom_types.rs
cargo clippy

# Flutter 应用（在 flutter_app/ 下）
flutter pub get
flutter run -d windows
flutter analyze        # 静态检查
flutter test           # 仅 test/widget_test.dart
```

注意：CLAUDE.md 中提到的 `flutter drive` 集成测试命令已失效——仓库中不存在 `integration_test/` 目录。

## ⚠️ 修改 Rust 代码后必须手动重建并重启

Rust 改动不会热重载。流程：`cd rust_core && cargo build` → 关闭运行中的应用 → 重新 `flutter run -d windows`。

动态库没有自动化复制集成（CMake 不处理它）：
- Windows 上加载名为 `localfamily_asset_core.dll`（crate 名是 `localfamily-asset-core`，lib 名 `localfamily_asset_core`）
- `ffi_bridge.dart` 查找顺序：先按 Windows 标准 DLL 搜索路径（含 exe 所在目录）打开 `localfamily_asset_core.dll`，失败再试当前目录 `./localfamily_asset_core.dll`；CI 手动复制到构建输出目录
- 加载失败报 "DynamicLibrary.open() failed" 时先检查 DLL 是否存在及位置

## FFI 层规则

- **只用 `flutter_app/lib/core/ffi_bridge.dart`**（FfiBridge 单例）。`lib/core/rust_ffi.dart` 是遗留死代码，打开的库名是错的，不要误改它。
- 内存管理：Rust 返回的字符串用 `free_string()` 释放；Dart 端指针操作必须在 `finally` 块中用 `malloc.free()` 释放。
- 错误通过负整数返回（`FfiErrorCode`），不抛异常跨 FFI。
- **命名跨边界转换**：Dart camelCase ↔ Rust snake_case，FFI 线上格式用 snake_case（如 `"car_loan"`）。Dart 枚举顺序与 `rust_core/src/ffi.rs` 中整数映射必须保持一致。

## 新增资产/负债类型 = 多文件联动修改

必须同时改 4 个文件，漏改任一处会导致类型显示为英文或映射错误：
1. `flutter_app/lib/models/financial_models.dart` — 枚举值 + 扩展方法（displayName/iconName/isInvestment 等）
2. `rust_core/src/db/models.rs` — 枚举 + `from_str`/`as_str`
3. `rust_core/src/ffi.rs` — 整数映射（两端枚举顺序必须一致）
4. `flutter_app/lib/models/asset_change.dart` — `_translateEnumValue()` 中文映射（审计日志显示）

建议同步：`smart_financial_record_name_input.dart` 的类型标签、README.md 和 CLAUDE.md 中的类型表格。

## 许可证约束（硬性）

项目 GPL-3.0：**禁止引入 GPL 依赖**（尤其 SQLCipher）。加密方案为自研文件级加密（AES-256-GCM + Argon2id），新依赖须选 MIT/Apache-2.0 许可证。

## 数据持久化：内存库 + 即时加密落盘

- 运行时数据在**内存 SQLite**（`Connection::open_in_memory`）中操作；Dart 端每次数据变更后立即调 `saveDatabase()` 加密落盘（即时保存策略，无定时器），退出走 `cleanup_app`，安全重置走 `reset_app`。
- 数据库文件是自研加密格式（magic header `LFAENC01`），用 SQLite 工具直接打开是乱码，属正常现象；改加密相关代码前先读 `docs/encryption-implementation.md`。
- `ffi.rs` 中旧的明文 API（`init_app`/`setup_password`/`verify_password`）已被 V2 版本（`init_app_v2`/`setup_password_v2`/`verify_password_v2`）取代，新代码一律用 V2。
- 密码盐值以十六进制存于 `settings` 表（`password_salt`），同时写入加密文件头。

## 其他约定

- `ROADMAP.md` 是路线图、战略决策与竞品/市场事实的**唯一事实来源**：做规划排期或对外描述产品定位前先读它；阶段状态或竞品格局变化时同步更新（竞品数据须重新核实并更新文首采集日期）。
- `CHANGELOG.md` 按 Keep a Changelog 维护：功能/Bug 修复/破坏性变更/文档更新写入 `[Unreleased]` 章节；纯格式化、内部重构不写。
- 推送 `v*` 标签会触发 `.github/workflows/build.yml` 发布构建（Windows/Linux/Android）；仅在用户明确要求时推送标签。
- 国内网络需设置镜像：`PUB_HOSTED_URL` / `FLUTTER_STORAGE_BASE_URL`（或用根目录 `install_flutter.ps1 -Mirror sjtu|tuna`）。
- `rust_core/src/bin/` 下是一次性数据库维护工具（check_db、migrate_db、cleanup_duplicates 等），用 `cargo run --bin <名>` 执行。
