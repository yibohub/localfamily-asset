# 鸿蒙适配验证收尾——换机接续任务书

> **用法**：新机器克隆本仓库后，把本文件路径发给 AI 执行即可（无需其他上下文）。
> **背景**：鸿蒙适配代码侧已在 commit 2b83d33 落地（ohos 宿主工程 / 交叉编译脚本 /
> FFI ohos 分支 / 平台门控 / CI 实验腿 / 文档），两项验证因原机器蓝屏中断待补：
> ① ohos 交叉编译实测；② flutter analyze / test。战略与状态见 `ROADMAP.md` Phase 4。

## 任务（按序执行，每步汇报）

1. **基线**：`cd rust_core && cargo test` 确认全绿。
2. **ohos 交叉编译实测**：`pipx install cargo-zigbuild` 后运行 `scripts/build-ohos.sh --zig`
   （Git Bash / Linux；装了 DevEco Studio 可直接跑默认模式用其 clang）。
   验证产物：`flutter_app/ohos/entry/libs/arm64-v8a/liblocalfamily_asset_core.so` 存在、
   `file` 显示 AArch64、`nm -D --defined-only` 含 `init_app_v2` / `save_database` / `free_string`。
3. **Dart 验证**：`cd flutter_app && flutter pub get && flutter analyze && flutter test`；
   重点检查最近改动：`lib/core/platform_info.dart`（新增）、`ffi_bridge.dart` ohos 分支、
   `financial_record_detail_screen.dart` 的 `isMobileLikePlatform` 门控，有问题就修复。
4. **（可选，需 DevEco Studio + CPF-Flutter ohos SDK）** 按 `docs/harmonyos-build.md`
   第 2 节构建 HAP（含取消 pubspec overrides 注释并填 CPF-Flutter 适配清单地址）。
5. **收尾**：更新 `ROADMAP.md` Phase 4 勾选与 `CHANGELOG.md` [Unreleased]，
   按仓库格式提交（feat/fix 前缀 + 中文描述）。

## 硬性约束

- pubspec 的 `*_ohos` dependency_overrides 平时保持注释，仅构建 ohos 时临时启用（全局生效）；
- 平台判定只走 `lib/core/platform_info.dart`，**禁止 `Platform.isOhos`**（上游 SDK 无此 getter）;
- **禁止推送 `v*` 标签**（触发发布构建）；push 先征得用户同意；
- GPL-3.0 项目：禁止引入 GPL 依赖，新依赖须 MIT/Apache-2.0；
- 环境安装：Flutter 见仓库根 `install_flutter.ps1` 或 `docs/INSTALL_FLUTTER.md`（国内镜像），
  Rust 用 rustup。
