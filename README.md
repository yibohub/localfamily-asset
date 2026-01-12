# LocalFamily Asset

> Notion 级的资产维度 + 钱迹式离线体验 + 1Password 级的加密恢复

## 核心特点

- **真·本地存储** - 所有数据仅存储在设备本地
- **零数据收集** - 不联网、无追踪、无第三方 SDK
- **开源可审计** - 完全开源，代码可审查
- **AES-256 加密** - 文件级整库加密，助记词恢复

## 开发计划

目前处于**计划阶段**，详细实现方案请查看 [docs/implementation-plan.md](docs/implementation-plan.md)

## 技术架构

```
Flutter UI (Riverpod)
        ↓
Rust Core (FFI边界)
  ├─ 加密: aes-256-gcm + argon2id
  ├─ 存储: SQLite + 文件级加密
  └─ 恢复: BIP39 助记词/密码
```

## 许可证

GPL-3.0

## 联系方式

- 开发者: yibohub
- 问题反馈: [GitHub Issues](https://github.com/yibohub/localfamily-asset/issues)
