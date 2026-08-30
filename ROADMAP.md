# ROADMAP — 项目推进路线图（事实来源）

> 本文档是 LocalFamily Asset（隐财）的**唯一路线图事实来源**：战略决策、阶段计划、竞品与市场数据以这里为准。
> 分工：`CHANGELOG.md` 记录"已发布的变更"（Keep a Changelog）；本文档记录"将要做的事"与"支撑决策的外部事实"。
> 最后更新：2026-08-30（第二节竞品数据采集日期同日）

## 一、当前状态快照（2026-08-30）

**项目本身**

- 版本 0.2.0；`[Unreleased]` 含一个安全修复（重置时清除 Rust 端主密钥，新增 `reset_app` FFI）
- 实际可用平台：**仅 Windows 桌面端**；CI（`build.yml`）已具备 Windows/Linux/Android 构建管线，Android 产物未真机验证
- 加密落盘已实现：内存 SQLite + 文件级加密（LFAENC01 格式，AES-256-GCM + Argon2id），BIP39 助记词恢复
- 核心迭代集中于 2026 年 1-2 月（约 140 次提交）；本路线图是重启后的推进基线

**能力清单（已完成）**

- 资产/负债分离模型 + 11 种内置类型（5 资产 + 6 负债）+ 自定义类型
- 买入价/现价与盈亏显示、同名资产智能合并、审计日志
- 密码 + 密码提示 + BIP39 助记词恢复、加密导出/导入（Zip）
- 浅色/深色主题、自定义 Windows 标题栏

**已知技术债**（影响后续排期的事实）

1. 新增内置类型需 4 文件枚举联动（顺序敏感，易错）
2. `lib/core/rust_ffi.dart` 遗留死代码，可删除
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

### Phase 0 — 真正开源 ❌ 未开始（预计 1 周内可完成，零成本）

- [ ] 清理 git 历史中的 `rust_core/target/` 构建产物（`git filter-repo` 或重建历史）
- [ ] 推送 GitHub 公开仓库
- [ ] 发 GitHub Release，附 Windows 安装包
- [ ] README 补截图/演示 GIF（建议，自荐帖要用）
- [ ] 发布前最终检查：git 历史中无真实资产数据、密钥等敏感文件

**完成标准**：公网可匿名访问仓库与 Release。

### Phase 1 — Android 收尾 ⏳ 门槛：每周可稳定投入数小时（预计 2-6 周）

- [ ] CI 产出的 APK 真机安装验证（Rust `.so` 加载、FFI 调用、加密流程）
- [ ] 桌面专属代码平台门控（`window_manager`、自定义标题栏）
- [ ] 移动端 UI 适配（导航/表单/列表小屏过一遍）
- [ ] 签名配置，酷安 + GitHub Release 分发
- [ ] 顺手清理技术债 #2（删除 `rust_ffi.dart`）

**完成标准**：陌生用户能从 Release 下载 APK，完成初始化并成功记录一条资产。

### Phase 2 — 冷启动曝光 ❌ 未开始（时机：Phase 1 完成后）

- [ ] 阮一峰周刊开源自荐（参考 Family Ledger 路径）
- [ ] 酷安上架、V2EX / 小众软件发帖
- [ ] （可选）Product Hunt
- 原则：首印象给"加密 + 零部署 + 有移动端"的完整形态；曝光窗口期间冻结功能大改

### Phase 3 — 产品增强 ❌ 未开始（Phase 1 后按序推进）

1. **净值快照时间序列 + 趋势图**：打开应用自动记录当日净值——回答"这一年的财富曲线"，是把打开理由从"记一笔"变成"看一眼"的留存关键
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
