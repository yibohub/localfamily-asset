# 本地优先家庭资产管理 App 完整实现方案

## 一、产品定位

```
一句话：Notion 级的资产维度 + 钱迹式的离线体验 + 1Password 级的加密恢复
目标用户：隐私敏感的中产家庭、技术极客、资产分散的多人家庭
核心差异：真·本地存储 + 零数据收集 + 开源可审计
```

---

## 二、技术架构（避开 GPL 陷阱）

```
┌─────────────────────────────────────────────────────────┐
│  移动端 UI (Flutter)                                      │
│  ├─ iOS: Flutter + Cupertino封装                         │
│  ├─ Android: Flutter + Material封装                      │
│  └─ 状态管理: Riverpod                                   │
└─────────────────────────────────────────────────────────┘
                        ↓ Platform Channel
┌─────────────────────────────────────────────────────────┐
│  Rust Core (FFI边界)                                     │
│  ├─ 加密层: aes-gcm + argon2id (libsodium)               │
│  ├─ 存储层: SQLite + 文件级整库加密                      │
│  ├─ 业务层: 资产模型 / CRUD / 导出导入                   │
│  └─ 恢复层: 12词助记词 / 文件密码 (BIP39)                │
└─────────────────────────────────────────────────────────┘
                        ↓ flutter_rust_bridge
┌─────────────────────────────────────────────────────────┐
│  数据库文件 (加密)                                        │
│  └─ assets.db.enc (启动解密到内存，退出加密落盘)          │
└─────────────────────────────────────────────────────────┘
```

### 为什么不用 SQLCipher？

| 方案 | 成本 | 许可证 | 风险 |
|------|------|--------|------|
| SQLCipher 开源版 | $0 | GPL | 整个App必须开源，Pro版形同虚设 |
| SQLCipher 商业版 | $2000 | 商业 | 小团队成本高 |
| **文件级加密 (推荐)** | $0 | MIT/Apache | ✅ 无GPL传染，完全控制 |

---

## 三、数据库设计

```sql
-- 核心资产表
CREATE TABLE assets (
    id TEXT PRIMARY KEY,           -- UUID
    type TEXT NOT NULL,            -- property/deposit/stock/fund/insurance/debt
    name TEXT NOT NULL,            -- 资产名称
    amount REAL NOT NULL,          -- 金额
    currency TEXT DEFAULT 'CNY',   -- 币种
    account TEXT,                  -- 账户/平台
    buy_date TEXT,                 -- 购入日期
    buy_price REAL,                -- 成本价（用于计算盈亏）
    current_price REAL,            -- 当前市价
    note TEXT,                     -- 备注
    tags TEXT,                     -- 标签（JSON数组）
    created_at INTEGER NOT NULL,   -- 创建时间戳
    updated_at INTEGER NOT NULL    -- 更新时间戳
);

-- 历史价格表（用于画图表）
CREATE TABLE asset_history (
    id TEXT PRIMARY KEY,
    asset_id TEXT NOT NULL,
    price REAL NOT NULL,
    recorded_at INTEGER NOT NULL,
    FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
);

-- 附件表（合同扫描件等）
CREATE TABLE attachments (
    id TEXT PRIMARY KEY,
    asset_id TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    encrypted_path TEXT NOT NULL,  -- 加密后的本地路径
    mime_type TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
);

-- 设置表（存储币种、主题等）
CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
```

**预计数据量**：
- 3000 条资产记录 ≈ 3MB
- 100 个附件 ≈ 5MB
- **总计 8-10MB**，解密到内存无压力

---

## 四、加密方案详解

### 4.1 双层加密架构

```
┌─────────────────────────────────────────────────────────┐
│  第1层：数据库文件加密 (aes-256-gcm)                      │
│  ├─ 密钥派生: argon2id(password, salt)                  │
│  ├─ 加密范围: 整个 .db 文件                             │
│  └─ 启动流程: 解密→ 内存DB → 操作 → 加密落盘            │
├─────────────────────────────────────────────────────────┤
│  第2层：附件内容加密 (aes-256-gcm)                       │
│  ├─ 每个文件独立密钥                                     │
│  └─ 存储路径: /data/data/xxx/files/enc/{uuid}.bin       │
├─────────────────────────────────────────────────────────┤
│  恢复方案 (二选一):                                      │
│  ├─ 方案A: 12词助记词 (BIP39) → 派生数据库密钥          │
│  └─ 方案B: 文件密码 → 直接作为数据库密钥                │
└─────────────────────────────────────────────────────────┘
```

### 4.2 密钥派生流程

```rust
// Rust 伪代码
use argon2::{Argon2, Algorithm, Version};
use aes_gcm::{Aes256Gcm, Key, Nonce};

// 1. 从助记词或密码派生密钥
fn derive_key(password: &str, salt: &[u8]) -> [u8; 32] {
    let argon2 = Argon2::new(
        Algorithm::Argon2id,
        Version::Version13,
        argon2::Params::new(65536, 3, 4, None)?  // 标准参数
    );
    let mut key = [0u8; 32];
    argon2.hash_password_into(password.as_bytes(), salt, &mut key)?;
    key
}

// 2. 解密数据库文件
fn decrypt_database(encrypted_db: &[u8], key: &[u8; 32]) -> Result<Vec<u8>> {
    // 提取 nonce (前12字节) 和 密文
    let nonce = Nonce::from_slice(&encrypted_db[..12]);
    let ciphertext = &encrypted_db[12..];

    let cipher = Aes256Gcm::new(Key::from_slice(key));
    cipher.decrypt(nonce, ciphertext)?;
}

// 3. 加密数据库文件
fn encrypt_database(db: &[u8], key: &[u8; 32]) -> Result<Vec<u8>> {
    let nonce = generate_random_nonce();
    let cipher = Aes256Gcm::new(Key::from_slice(key));
    let encrypted = cipher.encrypt(&nonce, db)?;

    // 返回 nonce + ciphertext
    [nonce.as_slice(), &encrypted].concat()
}
```

---

## 五、MVP 功能清单

| 模块 | 功能 | 优先级 | 说明 |
|------|------|--------|------|
| **资产核心** | 增删改查 | P0 | 6类资产：房产/存款/股票/基金/保单/负债 |
| **资产核心** | 多币种 | P0 | CNY/USD/HKD/EUR，自动换算总资产 |
| **加密** | 双模式解锁 | P0 | 助记词 OR 文件密码，首次启动必选其一 |
| **加密** | 自动锁定 | P1 | 后台3分钟/切屏锁定 |
| **附件** | 拍照/相册 | P0 | 压缩到最大1MB，AES-256加密存储 |
| **附件** | 查看器 | P0 | 内置图片查看，支持缩放/旋转 |
| **换机** | 导出加密Zip | P0 | 包含DB + 附件，密码同解锁密码 |
| **换机** | 导入恢复 | P0 | 扫描二维码或选择Zip文件 |
| **UI** | 三栏布局 | P0 | 总览/列表/详情，iPad/平板适配 |
| **UI** | 暗黑模式 | P0 | 跟随系统或手动切换 |
| **UI** | Demo模式 | P0 | **关键**：内置巴菲特/马斯克资产表 |
| **统计** | 总资产趋势 | P1 | 折线图（近6/12个月），MPAndroidChart |
| **统计** | 资产分布饼图 | P1 | 按类型/币种分组 |
| **搜索** | 全文搜索 | P1 | 名称/备注/标签模糊匹配 |
| **导出** | PDF报告 | P1 | **Pro功能**：专业排版资产清单 |

**V1.0 不做**：云同步、多设备协作、AI分析

---

## 六、开发计划（2-3人，3个月）

### 第 1 周：项目搭建
```
□ Flutter项目初始化
□ Rust FFI项目搭建
□ 数据库Schema定义
□ 加密模块单元测试
□ Demo数据准备（巴菲特/马斯克资产表）
```

### 第 2-3 周：Rust Core
```
□ 文件级加密/解密实现
□ SQLite CRUD封装
□ 助记词生成/恢复 (BIP39)
□ 导出加密Zip (包含附件)
□ FFI接口定义
```

### 第 4-5 周：Flutter UI
```
□ 三栏布局框架
□ 总览页（资产卡片 + 总额）
□ 资产列表（分组/筛选/排序）
□ 资产详情（编辑/删除）
□ 附件拍照/查看
```

### 第 6 周：加密流程
```
□ 首次启动引导（助记词/密码二选一）
□ 助记词确认（3次输入验证）
□ 锁定/解锁界面
□ 导出/导入流程
```

### 第 7 周：优化与测试
```
□ 暗黑模式适配
□ 图表功能（折线图/饼图）
□ 性能优化（启动<500ms）
□ 崩溃测试
```

### 第 8 周：内测
```
□ V2EX/酷安/Reddit 发内测包
□ 收集100条反馈
□ 修复Top10崩溃
□ 补充国际化 (en/zh)
```

### 第 9-10 周：上架准备
```
□ 隐私政策（"零数据收集"声明）
□ F-Droid 元数据
□ GitHub Release准备
□ 录60秒演示视频
```

### 第 11-12 周：正式发布
```
□ GitHub 开源
□ F-Droid上架
□ 酷安上架
□ TestFlight公测
□ 建立用户反馈渠道
```

---

## 七、目录结构（遵循架构规范）

```
localfamily-asset/
├── rust_core/                    # Rust核心层（独立子项目）
│   ├── src/
│   │   ├── crypto/               # 加密模块
│   │   │   ├── mod.rs            # <100行
│   │   │   ├── aes_gcm.rs        # <150行
│   │   │   ├── argon2.rs         # <100行
│   │   │   └── bip39.rs          # <150行
│   │   ├── db/                   # 数据库模块
│   │   │   ├── mod.rs            # <100行
│   │   │   ├── models.rs         # <150行
│   │   │   ├── schema.rs         # <100行
│   │   │   └── crud.rs           # <200行
│   │   ├── export/               # 导出模块
│   │   │   ├── mod.rs            # <100行
│   │   │   └── zip.rs            # <150行
│   │   └── lib.rs                # FFI入口 <150行
│   └── Cargo.toml
│
├── flutter_app/                  # Flutter应用
│   ├── lib/
│   │   ├── core/                 # FFI桥接
│   │   │   ├── crypto_bridge.dart
│   │   │   ├── db_bridge.dart
│   │   │   └── export_bridge.dart
│   │   ├── models/               # 数据模型
│   │   │   ├── asset.dart
│   │   │   └── attachment.dart
│   │   ├── providers/            # Riverpod状态
│   │   │   ├── asset_provider.dart
│   │   │   ├── crypto_provider.dart
│   │   │   └── settings_provider.dart
│   │   ├── screens/              # 页面
│   │   │   ├── home/
│   │   │   │   ├── overview_page.dart
│   │   │   │   ├── asset_list_page.dart
│   │   │   │   └── asset_detail_page.dart
│   │   │   ├── crypto/
│   │   │   │   ├── setup_page.dart
│   │   │   │   └── unlock_page.dart
│   │   │   └── export/
│   │   │       └── export_page.dart
│   │   ├── widgets/              # 通用组件
│   │   │   ├── asset_card.dart
│   │   │   ├── chart_widget.dart
│   │   │   └── attachment_viewer.dart
│   │   └── main.dart
│   └── pubspec.yaml
│
├── demo_data/                    # Demo数据
│   ├── buffett_assets.json
│   └── musk_assets.json
│
├── docs/                         # 文档
│   ├── ARCHITECTURE.md
│   ├── ENCRYPTION.md
│   └── PRIVACY.md
│
└── README.md
```

**文件数量检查**：
- `rust_core/src/`: 3个子文件夹 × <4个文件 = 符合<8个文件
- `flutter_app/lib/`: 6个子文件夹，每个<5个文件 = 符合规范

---

## 八、盈利模式

### 8.1 免费功能（开源）
- 所有核心资产管理功能
- 本地加密存储
- 导出/导入
- 基础图表

### 8.2 Pro功能（¥38 买断）
| 功能 | 说明 | 为什么能收费 |
|------|------|--------------|
| PDF资产报告 | 专业排版，可直接打印 | 即便开源，用户也没模板/字体 |
| AI合同OCR | 本地跑OCR识别合同信息 | 需要模型文件（200MB），不打包在免费版 |
| 多图表主题 | 5种专业图表配色 | 设计资产，直接复制无价值 |
| 优先支持 | 问题48小时内响应 | 服务本身 |

### 8.3 收入预期（保守）
```
第1-3个月：月活 500-1000，转化率3% → 月入 ¥600-1200
第4-6个月：月活 2000-5000，转化率5% → 月入 ¥3800-9500
第7-12个月：月活 5000-10000，转化率5% → 月入 ¥9500-19000
```

---

## 九、合规与隐私

### 9.1 隐私政策（模板）
```
【本地家庭资产管理App】隐私政策

本应用坚持"零数据收集"原则：

1. 不收集任何个人信息
2. 不联网（除导出/导入功能外）
3. 不使用第三方SDK（无统计、无广告、无推送）
4. 所有数据仅存储在您的设备本地
5. 数据由您设置的密码/助记词加密，开发者无法解密

权利人信息：
- 开发者：XXX
- 联系邮箱：XXX
- 数据处理地点：您的设备本地

如您卸载本应用，所有数据将被清除，请提前导出备份。
```

### 9.2 应用商店声明
```
Google Play Data Safety:
- 收集数据：无
- 共享数据：无
- 第三方追踪：无
- 用户数据加密：是（本地AES-256）
- 用户提供数据：否（用户自行输入）

酷安审核：
- 无违规内容
- 无后端服务器
- 开源代码可审查
```

---

## 十、风险控制

| 风险 | 概率 | 对策 |
|------|------|------|
| 助记词丢失 | 高 | 3次强制确认 + 纸质提醒 + 金属板周边 |
| 低端机性能 | 低 | 8MB数据库 + 异步加载 + 分页 |
| GPL纠纷 | 低 | 避开SQLCipher，用纯Rust加密 |
| 竞品抄袭 | 中 | GPL-3.0协议 + 社区运营优先 |
| 应用商店拒审 | 低 | 无数据收集 + 开源可审计 |

---

## 十一、下一步行动

### 立即可做（0成本）
```
□ 占坑GitHub仓库：localfamily-asset
□ 发V2EX预热帖收集意向用户
□ 做Figma原型放GitHub收Star
□ 建邮件列表收集邮箱
```

### 技术验证（第1周）
```
□ Rust加密模块PoC（<500行代码）
□ Flutter+Rust FFI跑通
□ Demo数据入库测试
```

---

**方案总结**：这是一份**避开了所有已知陷阱**的完整方案，核心差异化在于：
1. ✅ 避开GPL，完全控制商业路径
2. ✅ 文件级加密，8MB无性能压力
3. ✅ Demo模式，降低冷启动门槛
4. ✅ Pro功能锁定在服务/模型，代码开源也不怕抄
