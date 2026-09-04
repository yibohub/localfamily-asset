# ROADMAP — 项目推进路线图（事实来源）

> 本文档是 LocalFamily Asset（隐财）的**唯一路线图事实来源**：战略决策、阶段计划、竞品与市场数据以这里为准。
> 分工：`CHANGELOG.md` 记录"已发布的变更"（Keep a Changelog）；本文档记录"将要做的事"与"支撑决策的外部事实"。
> 最后更新：2026-09-04（第二节竞品数据采集日期为 2026-08-30）

## 一、当前状态快照（2026-09-04）

**项目本身**

- 版本 0.2.1（`[Unreleased]` 含移动端 UI 适配与旧界面死代码清理）
- 实际可用平台：**Windows 桌面端**（日常形态）+ **Android**（CI 产物已真机验证，Phase 1 收尾中）；CI（`build.yml`）具备 Windows/Linux/Android 构建管线
- 加密落盘已实现：内存 SQLite + 文件级加密（LFAENC01 格式，AES-256-GCM + Argon2id），BIP39 助记词恢复
- 核心迭代集中于 2026 年 1-2 月（约 140 次提交）；2026-08-30 重启推进，Phase 0 已收官

**能力清单（已完成）**

- 资产/负债分离模型 + 11 种内置类型（5 资产 + 6 负债）+ 自定义类型
- 买入价/现价与盈亏显示、同名资产智能合并、审计日志
- 密码 + 密码提示 + BIP39 助记词恢复、加密导出/导入（Zip）
- 浅色/深色主题、自定义 Windows 标题栏

**已知技术债**（影响后续排期的事实）

1. 新增内置类型需 4 文件枚举联动（顺序敏感，易错）
2. ~~`lib/core/rust_ffi.dart` 遗留死代码，可删除~~ ✅ 2026-09-02 已删除
3. `ffi.rs` 中 v1 明文 API（`init_app` 等）与 v2 加密 API 并存，v1 待清理
4. 无集成测试；Flutter 侧仅 `widget_test.dart`
5. 动态库复制未进构建系统（CMake 不处理，CI 手动复制）

## 二、市场事实（采集于 2026-08-30）

**国际开源对标**（按星数排序；数据来自 GitHub API / 官网）

| 项目 | Stars | 状态 | 定位 | 对隐财的意义 |
|---|---|---|---|---|
| [Maybe](https://github.com/maybe-finance/maybe) | 54.3k | 已归档（2025-07） | 开源 Mint 替代 | 反面教材：融资式打法在本品类不可持续 |
| [Actual Budget](https://github.com/actualbudget/actual) | 28.4k | 活跃 | 本地优先预算（MIT） | "本地优先 + 加密同步"架构参照 |
| [Firefly III](https://github.com/firefly-iii/firefly-iii) | 24.5k | 活跃 | 自托管记账 | 需服务器，与零部署互斥 |
| [Ghostfolio](https://ghostfol.io/en) | 9.2k | 活跃 | 自托管净值/组合仪表盘 | 定位接近但需自托管 |
| [Wealthfolio](https://github.com/wealthfolio/wealthfolio) | 8.7k | 活跃（v3.6） | 纯本地投资+净值+支出，Tauri+Rust | **基因最像的对手**：同为 Rust 内核/本地优先/无账号，2.0 已补 iOS |
| [Portfolio Performance](https://github.com/portfolio-performance/portfolio) | 4.0k | 活跃 | 桌面组合分析（2012 年起） | XIRR/TWR 功能标杆 |

**国内**

- 钱迹：闭源，600 万+ 用户，持续活跃（2026-08-01 仍在更新 PC 版），AI 截图记账，"三无"定位；数据可本地备份但非端到端加密 → 隐财的差异化缝隙
- **Family Ledger（家庭账房）**：2026-05 创建，约 3 个月 348 星，活跃；自托管 Web + XIRR/TWR 真实年化 + AI 资产体检；定位与隐财几乎重合；经阮一峰周刊自荐起量 → **冷启动渠道已被验证**
- 其余同类小项目：PanassetLite（浏览器本地存储）、home-finance、生财有迹、知盈 iAssets

**趋势判断（2026）**

1. 隐私优先/本地优先是上升赛道，用户反感数据聚合（Plaid 式）
2. AI 功能成为标配热点（自动记账、资产诊断）
3. XIRR/TWR 真实年化是资产工具的"硬通货"功能
4. 移动端是入场券，桌面-only 资产工具无存活先例
5. 可持续模式 = 单人/小团队 + 低成本维护（Maybe 之死的反面印证）

**战略结论：机会窗口**

"零部署纯离线 + 整库端到端加密 + BIP39 恢复 + 移动端"四者同时满足的产品，截至 2026-08 仍是空位；窗口在收窄（Family Ledger 正在逼近）。⚠️ 本节竞品数据每季度复核一次，发现新的直接竞品立即更新。

关键来源：[Wealthfolio](https://github.com/wealthfolio/wealthfolio) · [Ghostfolio](https://ghostfol.io/en) · [Actual Budget](https://github.com/actualbudget/actual) · [Maybe](https://github.com/maybe-finance/maybe) · [钱迹官方文档](https://docs.qianjiapp.com/) · [Family Ledger 自荐帖](https://github.com/ruanyf/weekly/issues/10286) · [2026 隐私优先应用盘点](https://budgetvault.app/blog/privacy-first-alternatives)

## 三、推进路线

原则：成本递增、按序执行；对外曝光只做一次，留给最完整形态。

### Phase 0 — 真正开源 ⏳ 进行中（2026-08-30 已完成主体）

- [x] 清理 git 历史中的 `rust_core/target/` 构建产物（git filter-repo，223MB → 4.7MB，141 提交全部保留）
- [x] 推送 GitHub 公开仓库（2026-08-30 翻转为 public，匿名克隆验证通过）
- [x] 发布前最终检查：git 历史中无真实资产数据、密钥等敏感文件
- [x] 发 GitHub Release，附 Windows 安装包（2026-09-02 v0.2.1 发布，含 Windows/Linux/Android 全平台产物）
- [x] README 补截图/演示 GIF（2026-09-02 已补 4 张界面截图：初始设置/资产/负债/设置）

**完成标准**：公网可匿名访问仓库与 Release。

### Phase 1 — Android 收尾 ⏳ 门槛：每周可稳定投入数小时（预计 2-6 周）

- [x] CI 产出的 APK 真机安装验证（Rust `.so` 加载、FFI 调用、加密流程）——2026-09-02 模拟器验证通过（发现并修复：CI 此前未将 Rust `.so` 打进 APK、缺少 x86_64 ABI；现 APK 含 arm64-v8a/armeabi-v7a/x86_64 三 ABI，初始化+加密落盘+解锁+Demo 数据全流程正常）
- [x] 桌面专属代码平台门控（2026-09-02：window_manager 调用已在 main.dart 门控且为唯一入口；删除未使用桌面组件 window_title_bar.dart；导出路径移动端改落应用目录；asset_provider 日志去硬编码 Windows 路径）
- [x] 移动端 UI 适配（2026-09-04：15 处小数键盘、表单底部保存、5 个对话框键盘避让/滚动、列表/详情/总览防溢出、锁屏可滚动、字体平台门控；顺带删除约 5,200 行不可达旧界面代码；Pixel 7 模拟器全流程走查 + Windows 桌面冒烟通过，全程无 RenderFlex overflow）
- [ ] 签名配置，酷安 + GitHub Release 分发（🫸 2026-09-04 用户决定暂缓；签名基础设施已就绪——build.gradle 支持 key.properties 可选签名 + CI Secrets 注入（2907c5b），待生成 keystore 并配置 4 个 Secrets 后即可启用）
- [x] 顺手清理技术债 #2（删除 `rust_ffi.dart`）——2026-09-02 已删除

**完成标准**：陌生用户能从 Release 下载 APK，完成初始化并成功记录一条资产。

### Phase 2 — 冷启动曝光 ❌ 未开始（时机：Phase 1 完成后）

- [ ] 阮一峰周刊开源自荐（参考 Family Ledger 路径）
- [ ] 酷安上架、V2EX / 小众软件发帖
- [ ] （可选）Product Hunt
- 原则：首印象给"加密 + 零部署 + 有移动端"的完整形态；曝光窗口期间冻结功能大改

### Phase 3 — 产品增强 ⏳ 进行中（Phase 1 后按序推进）

1. **净值快照时间序列 + 趋势图** ✅ 2026-09-04 完成：打开应用自动记录当日净值（同日覆盖、即时加密落盘），总览页新增"净值走势"卡片（fl_chart 折线，最近 90 天，触摸查看逐日数值，<2 天显示引导文案）；新增 `net_worth_snapshots` 表与 2 个 FFI 函数，Rust 集成测试 3 例通过；Android 模拟器端到端验证通过
2. **XIRR/TWR 真实年化**：对标 Family Ledger 核心卖点
3. **CSV/Excel 批量导入**：初始录入摩擦是此类工具流失用户的头号原因
4. **附件支持**：保单/房产证照片，沿用现有文件级加密方案
5. **到期提醒**：保单/存款/信用卡

### 非目标（明确不做）

- 云端同步/账号体系：与隐私优先定位冲突，用加密导出/导入替代
- 自动连接银行/券商抓取数据：合规与隐私风险
- 理财推荐、社区、任何交易功能：README 产品定位红线
- iOS / Web：Android 站稳之前不启动

## 四、维护约定

- 本文是路线图、战略与竞品事实的**唯一来源**；README 的路线图章节只保留指向链接
- 更新时机：①阶段状态变化（勾选任务、推进阶段）；②重大产品决策；③每季度复核第二节竞品数据（更新采集日期）；④发现新的直接竞品
- 竞品数据改动必须重新核实并更新文首"最后更新"日期；无法核实的数据直接删除
- 状态标记：❌ 未开始 / ⏳ 进行中 / ✅ 已完成 / 🚫 已放弃（放弃时写明原因与日期）
