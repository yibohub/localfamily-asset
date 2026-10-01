# 鸿蒙（HarmonyOS NEXT）构建指南

> 状态（2026-10-01）：**代码侧适配已落地，真机/模拟器验证待做**（ROADMAP Phase 4）。
> 本文是鸿蒙构建的完整操作手册；战略背景与市场判断见 `ROADMAP.md` Phase 4 章节。

## 0. 适配总览

| 层 | 内容 | 位置 |
|---|---|---|
| Rust Core | 交叉编译到 `aarch64-unknown-linux-ohos`，产出 `.so` | `scripts/build-ohos.sh` |
| 宿主工程 | Flutter ohos 工程脚手架（AppScope/entry/ArkTS/hvigor） | `flutter_app/ohos/` |
| FFI 加载 | `DynamicLibrary.open('liblocalfamily_asset_core.so')` | `flutter_app/lib/core/ffi_bridge.dart` |
| 平台门控 | `isOhosPlatform` / `isMobileLikePlatform`（不用 `Platform.isOhos`，见 §5） | `flutter_app/lib/core/platform_info.dart` |
| 插件适配 | path_provider / shared_preferences / image_picker / file_picker 的 `*_ohos` 版 | `flutter_app/pubspec.yaml`（注释块） |
| CI | `build.yml` 实验性 ohos Rust 交叉编译腿（cargo-zigbuild） | `.github/workflows/build.yml` |

## 1. 前置条件

1. **DevEco Studio 5.0+**（含 OpenHarmony SDK、ohpm、hvigor 命令行工具）
   —— HAP 打包、签名、真机调试都需要它。从华为开发者官网下载。
2. **ohos Flutter SDK**：使用 **CPF-Flutter 基线**（华为侧维护者主导的官方适配线，
   托管于 GitCode `CPF-Flutter` 组织）。按其文档 git 拉取**指定 tag** 到本地独立目录，
   **禁用 `flutter upgrade`**（会拉错上游）。`flutter --version` 正常输出即就绪。
3. **Rust**（rustup）——编译 Rust Core 用。
4. 签名（仅发布/真机安装需要）：AGC 开发者账号 + 证书；debug 阶段可用 DevEco
   自动签名（需登录华为账号）。

> ⚠️ 各基线对 DevEco Studio / OpenHarmony API 版本有配套要求，以所用 tag 的
> 发布说明为准；`ohos/build-profile.json5` 的 `compatibleSdkVersion` 需与之匹配。

## 2. 首次构建步骤

```bash
# ① 编译 Rust Core 并放入 ohos 工程（默认 arm64 真机）
#    两种方式任选：
scripts/build-ohos.sh            # A. 用本机 DevEco/OHOS SDK 的 clang（推荐）
scripts/build-ohos.sh --zig      # B. cargo-zigbuild，无需 OHOS SDK（pip install cargo-zigbuild）
# 模拟器（x86_64）场景：
OHOS_TARGETS="x86_64-unknown-linux-ohos" scripts/build-ohos.sh

# ② 启用鸿蒙插件适配（仅构建 ohos 时）
#    编辑 flutter_app/pubspec.yaml，取消 dependency_overrides 注释，
#    并把 <CPF-Flutter 适配仓库地址> 替换为 CPF-Flutter 三方库适配清单中的实际 git 地址
cd flutter_app
flutter pub get

# ③ 构建 HAP（用 ohos Flutter SDK 的 flutter 命令）
flutter build hap --release   # 或 --debug
# 产物：build/outputs/.../*.hap
```

也可以直接用 **DevEco Studio 打开 `flutter_app/ohos/`** 运行/调试（先完成 ①② 及
下述 har 同步）。首次用 ohos Flutter SDK 执行 `flutter build hap` 或 `flutter run`
时，flutter 工具会把引擎 `flutter_ohos.har` 复制到 `ohos/entry/har/`（已 gitignore），
并从 pubspec 同步 versionCode/versionName 到 `AppScope/app.json5`。

## 3. 签名

1. DevEco Studio → File → Project Structure → Signing Configs → 勾选
   "Automatically generate signature"，登录华为账号（个人调试证书即可）→
   签名配置会写入 `ohos/build-profile.json5`（该文件含证书指纹，勿提交个人密钥相关改动）。
2. 正式分发：AGC 创建发布证书/Profile，填入 signingConfigs，`flutter build hap --release`
   出签名包。上架应用市场或以"签名 HAP + 安装指引"形式随 GitHub Release 分发。

## 4. 脚手架维护说明

`flutter_app/ohos/` 是按 flutter-ohos 模板手工搭的最小脚手架（FlutterEntry 宿主 +
无额外能力）。如果所用 SDK 版本与脚手架不兼容（hvigor modelVersion / API 版本报错）：

1. 备份后删除 `flutter_app/ohos/`，用 ohos Flutter SDK 重新生成：
   `flutter create --platforms ohos . --project-name localfamily_asset --org io.github.yibohub`
2. 重新应用本项目定制（差异清单）：
   - `AppScope/app.json5`：bundleName `io.github.yibohub.localfamily_asset`、vendor、版本号
   - `AppScope/resources/base/element/string.json`：app_name = `隐财`
   - 图标：`AppScope/resources/base/media/app_icon.png`（192×192，与 Android 同源）
   - `entry/src/main/module.json5`：仅声明 `ohos.permission.CAMERA`（附件拍照），
     label `隐财`，启动页背景 `#FAF9F5`
   - `entry/libs/arm64-v8a/`：Rust Core `.so`（§2 第①步生成）
   - `entry/oh-package.json5`：`@ohos/flutter_ohos` har 引用

## 5. 平台判定的写法约定（重要）

ohos Flutter SDK 给 `dart:io` 打了补丁、提供 `Platform.isOhos`，但**上游官方 SDK
没有这个 getter**——直接引用会让 Windows/Linux/Android 的 analyze/构建直接失败。
因此本项目统一：

```dart
// lib/core/platform_info.dart
bool get isOhosPlatform => !kIsWeb && Platform.operatingSystem == 'ohos';
```

两条 SDK 线下均成立。新增平台分支时**不要**散落 `Platform.is*`，统一走
`platform_info.dart` 的判定。

## 6. 已核对的平台门控（ohos 行为）

| 位置 | 原分支 | ohos 行为 |
|---|---|---|
| `ffi_bridge.dart` `_loadLibrary` | Android/Win/Linux/macOS | 新增 ohos 分支：按 soname 打开 `.so`（与 Android 一致） |
| `financial_record_detail_screen.dart` 附件入口 | `Platform.isAndroid \|\| isIOS` | 改为 `isMobileLikePlatform`：拍照/相册入口在 ohos 显示 |
| `file_dialogs.dart` 导出路径 | 桌面弹保存框 / 移动端落文档目录 | ohos 走移动端路径（依赖 path_provider_ohos） |
| `main.dart` 窗口管理器、`asset_provider.dart` 文件日志 | 仅桌面 | ohos 自动跳过，无需改动 |

## 7. 常见问题

- **`DynamicLibrary.open() failed / liblocalfamily_asset_core.so 找不到`**
  → 检查 `flutter_app/ohos/entry/libs/arm64-v8a/` 是否有 `.so`（重跑 `scripts/build-ohos.sh`）；
  架构要与设备一致（真机 arm64 / 模拟器 x86_64）。
- **插件 `MissingPluginException`（路径、主题、拍照）**
  → pubspec 的 `dependency_overrides` 未取消注释或地址未填；改完必须重新 `flutter pub get`。
- **hvigor `modelVersion` 不匹配 / API 版本报错**
  → 用 DevEco Studio 打开 `flutter_app/ohos/` 按提示迁移，或按 §4 重新生成脚手架。
- **`flutter_ohos.har` 不存在**
  → 用 ohos Flutter SDK 跑一次 `flutter pub get && flutter build hap`，由 flutter 工具复制。
- **发布到 GitHub Release**
  → HAP 必须签名后才能安装（侧载不豁免）；CI 目前只产出 ohos 的 Rust `.so`
  artifact，HAP 打包在本地完成后再上传。

## 8. 验证清单（真机，Phase 4 完成标准）

- [ ] 安装 → 初始化密码 → 记录一条资产 → 加密落盘 → 杀进程重启解锁
- [ ] 附件：拍照 / 相册 / 加密落盘 / 全屏预览 / 删除
- [ ] 加密导出/导入、CSV/Excel 批量导入
- [ ] 到期提醒、净值走势、深浅色主题切换
