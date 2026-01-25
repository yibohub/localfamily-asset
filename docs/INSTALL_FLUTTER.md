# Flutter 安装指南（中国网络环境）

> 官方文档: https://docs.flutter.cn/community/china/

---

## 方法一：自动安装脚本（推荐）

使用项目提供的自动安装脚本，自动配置国内镜像源并下载最新版本。

```powershell
# 使用默认镜像（CFUG 社区镜像）
.\install_flutter.ps1

# 或指定其他镜像源
.\install_flutter.ps1 -Mirror cfug   # CFUG 社区镜像（推荐）
.\install_flutter.ps1 -Mirror sjtu   # 上海交大镜像
.\install_flutter.ps1 -Mirror tuna   # 清华大学 TUNA 镜像

# 自定义安装路径
.\install_flutter.ps1 -InstallPath "D:\dev"
```

脚本会自动：
1. 配置国内镜像环境变量（永久生效）
2. 获取最新稳定版本
3. 下载并解压 Flutter SDK
4. 添加到 PATH 环境变量
5. 运行 `flutter doctor` 验证安装

---

## 方法二：手动安装

### 1. 配置镜像环境变量

打开 PowerShell，执行以下命令（临时生效）：

```powershell
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
```

**永久设置（推荐）**：
```powershell
[System.Environment]::SetEnvironmentVariable('PUB_HOSTED_URL', 'https://pub.flutter-io.cn', 'User')
[System.Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL', 'https://storage.flutter-io.cn', 'User')
```

### 2. 下载 Flutter SDK

从镜像站点下载最新稳定版：

```
https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_3.27.5-stable.zip
```

或访问 Flutter 中文网获取最新版本：
```
https://flutter.cn/docs/get-started/install/windows
```

### 3. 解压到指定目录

解压到 `C:\flutter` 或 `%USERPROFILE%\dev\flutter`（避免路径中有空格或中文）

### 4. 添加到环境变量

将 Flutter 的 `bin` 目录添加到系统 PATH：

1. 右键"此电脑" → 属性 → 高级系统设置
2. 环境变量 → 用户变量 → Path → 编辑
3. 添加 `C:\flutter\bin` 或你的安装路径
4. 重启终端使 PATH 生效

### 5. 验证安装

```bash
flutter --version
flutter doctor
```

---

## 国内镜像源列表

| 镜像源 | PUB_HOSTED_URL | FLUTTER_STORAGE_BASE_URL |
|--------|----------------|--------------------------|
| **CFUG（推荐）** | `https://pub.flutter-io.cn` | `https://storage.flutter-io.cn` |
| 上海交大 | `https://mirror.sjtu.edu.cn/dart-pub` | `https://mirror.sjtu.edu.cn` |
| 清华 TUNA | `https://mirrors.tuna.tsinghua.edu.cn/dart-pub` | `https://mirrors.tuna.tsinghua.edu.cn/flutter` |

---

## 运行项目

安装完成后，在项目目录运行：

```bash
# 进入 Flutter 应用目录
cd flutter_app

# 获取依赖（使用镜像源自动加速）
flutter pub get

# 运行（需要连接设备或模拟器）
flutter run
```

---

## 依赖检查

运行 `flutter doctor` 检查需要安装的依赖：

| 组件 | 说明 | 下载地址 |
|------|------|----------|
| Android Studio | Android 开发 IDE | https://developer.android.com/studio |
| VS Code + Flutter 插件 | 轻量级编辑器 | https://code.visualstudio.com/ |
| Android SDK | Android 开发工具包 | 通过 Android Studio 安装 |
| Chrome | Web 调试 | https://www.google.com/chrome/ |

### 安装 Android Studio 后配置

1. 打开 Android Studio
2. 安装 Android SDK（Tools → SDK Manager）
3. 安装 Android SDK Command-line Tools
4. 接受 Android licenses: `flutter doctor --android-licenses`

---

## 常见问题

### Q: 下载速度慢或失败？
A: 确保已正确设置镜像环境变量，使用自动安装脚本可自动配置。

### Q: flutter pub get 失败？
A: 检查 `PUB_HOSTED_URL` 环境变量是否正确设置。

### Q: 如何切换镜像源？
A: 重新设置环境变量，或重新运行安装脚本指定 `-Mirror` 参数。

### Q: 如何更新 Flutter？
A: `flutter upgrade`（会自动使用配置的镜像源）
