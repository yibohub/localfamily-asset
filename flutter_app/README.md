# LocalFamily Asset - Flutter 应用

这是 [LocalFamily Asset](https://github.com/yibohub/localfamily-asset) 项目的 Flutter UI 层。

## 项目说明

本应用是隐财的前端界面，使用 Flutter 框架开发，通过 FFI 调用 Rust Core 层的加密和存储功能。

## 技术栈

- **Flutter**: >= 3.24.0
- **状态管理**: Provider
- **FFI**: 原始 C FFI（调用 Rust Core）
- **主题**: Material Design 3

## 开发指南

### 获取依赖

```bash
flutter pub get
```

### 运行开发版本

```bash
# Windows
flutter run -d windows

# Android
flutter run -d android

# iOS
flutter run -d ios
```

### 构建发布版本

```bash
# Windows
flutter build windows

# Android
flutter build apk

# iOS
flutter build ios
```

### 代码检查

```bash
flutter analyze
```

## 项目结构

```
lib/
├── core/                 # 核心层
│   ├── ffi_bridge.dart   # FFI 桥接层
│   ├── theme.dart        # 主题配置
│   └── app.dart          # 应用入口
├── models/               # 数据模型
│   ├── asset.dart        # Asset 模型
│   └── portfolio_summary.dart
├── providers/            # Provider 状态管理
│   ├── auth_provider.dart
│   └── asset_provider.dart
├── screens/              # 页面
│   ├── splash_screen.dart
│   ├── home_screen.dart
│   └── auth/
├── widgets/              # 通用组件
│   ├── asset_list_item.dart
│   └── asset_summary_card.dart
└── main.dart
```

## 依赖说明

### 主要依赖

- `provider`: 状态管理
- `intl`: 国际化和日期格式化
- `flutter_localizations`: Flutter 官方国际化支持

### FFI 动态库

应用需要 Rust Core 动态库才能运行：

- Windows: `assets/localfamily_asset_core.dll`
- Linux: `assets/liblocalfamily_asset_core.so`
- macOS: `assets/liblocalfamily_asset_core.dylib`

构建动态库请参考项目根目录的 [README](../README.md)。

## 主题配置

应用使用深海蓝（#0A2463）作为主品牌色，翡翠绿（#059669）表示成功状态。

更多品牌规范请参考 [品牌指南](../docs/brand/BRAND_GUIDELINES.md)。

## 国际化

应用支持中文和英文：

- 添加新翻译：编辑 `lib/l10n/app_*.arb`
- 生成翻译代码：`flutter gen-l10n`

## 常见问题

### Q: 如何调试 FFI 调用？

A: Rust Core 使用 `eprintln!()` 输出到 stderr，可以在终端查看。

### Q: 如何添加新的资产类型？

A: 需要同时修改：
1. `rust_core/src/ffi.rs` 的 `asset_type_from_int()`
2. `flutter_app/lib/models/asset.dart` 的 `AssetType` 枚举

## 贡献指南

1. Fork 项目
2. 创建功能分支
3. 提交变更
4. 发起 Pull Request

## 许可证

GPL-3.0

---

更多项目信息请访问 [主 README](../README.md)。
