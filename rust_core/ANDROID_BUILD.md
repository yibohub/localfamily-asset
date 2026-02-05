# Android Rust 编译指南

本指南说明如何为 Android 平台编译 Rust Core。

## 前置要求

### 1. 安装 Android NDK

在 Android Studio 中安装 NDK：
- 打开 Android Studio
- Tools → SDK Manager → SDK Tools
- 勾选 `NDK (Side by side)`
- 推荐版本：25.2.9519653 或 26.1.10909125

### 2. 安装 Rust 目标架构

```bash
rustup target add aarch64-linux-android      # ARM 64位 (必需)
rustup target add armv7-linux-androideabi    # ARM 32位 (可选)
rustup target add x86_64-linux-android       # x86_64 (模拟器，可选)
rustup target add i686-linux-android         # x86 (模拟器，可选)
```

## 编译方法

### 方法一：使用 PowerShell 脚本（推荐）

```powershell
cd rust_core
.\build_android.ps1
```

脚本会自动：
1. 检测 NDK 安装路径
2. 编译各架构的 .so 文件
3. 输出到 `target/android/` 目录

### 方法二：手动编译

```powershell
# 设置 NDK 路径
$env:ANDROID_NDK_ROOT = "$env:LOCALAPPDATA\Android\Sdk\ndk\25.2.9519653"
$env:CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER = "$env:ANDROID_NDK_ROOT\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android33-clang.cmd"

# 编译 ARM 64位
cargo build --release --target aarch64-linux-android
```

## 输出文件

编译成功后，.so 文件位于：

```
target/android/
├── arm64-v8a/
│   └── liblocalfamily_asset_core.so
└── armeabi-v7a/
    └── liblocalfamily_asset_core.so
```

## 部署到 Flutter

将编译好的 .so 文件复制到 Flutter 项目：

```powershell
# 创建 jniLibs 目录
mkdir flutter_app\android\app\src\main\jniLibs\arm64-v8a

# 复制 .so 文件
copy target\android\arm64-v8a\liblocalfamily_asset_core.so flutter_app\android\app\src\main\jniLibs\arm64-v8a\
```

或者使用脚本（在 `build_android.ps1` 末尾添加）：

```powershell
$flutterJniLibs = "flutter_app\android\app\src\main\jniLibs"

# 复制各架构
Copy-Item -Path "target\android\arm64-v8a\*" -Destination "$flutterJniLibs\arm64-v8a\" -Recurse -Force
```

## 故障排除

### 问题：找不到链接器

```
error: linker `aarch64-linux-android33-clang` not found
```

**解决**：检查 NDK 路径是否正确，确保安装了对应版本。

### 问题：编译错误

```
error: failed to run custom build command for `rusqlite`
```

**解决**：确保 `rusqlite` 使用 `bundled` 特性（已在 Cargo.toml 中配置）。

### 问题：找不到 .so 文件

```
dlopen failed: cannot locate symbol "sqlite3_column_count"
```

**解决**：确保编译时使用了 `--release` 模式。

## 参考链接

- [Android NDK](https://developer.android.com/ndk)
- [Cargo Cross Compilation](https://doc.rust-lang.org/cargo/reference/config.html)
- [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge)
