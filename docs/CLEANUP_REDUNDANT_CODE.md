# 代码冗余清理计划

## 概述

本文档记录了 LocalFamily Asset 应用中的冗余代码清理计划。项目正处于从旧模型向新模型迁移的阶段，存在大量可安全删除的冗余代码。

**生成时间**: 2026-02-03
**预计清理代码量**: ~4,431 行

---

## 架构变更背景

### 旧模型（将遗弃）

- **统一 Asset 类**: 一个 `Asset` 类同时处理资产和负债
- **AssetType 枚举**: 包含资产类型和负债类型的混合枚举
- **AssetProvider**: 旧的状态管理 Provider

```dart
// 旧模型示例
enum AssetType {
  property, deposit, stock, fund, insurance,  // 资产类型
  debt, mortgage, carLoan, creditCard,        // 负债类型（混合）
  personalLoan, privateLoan
}

class Asset {
  final AssetType type;
  final double amount;
  // ... 其他字段
}
```

### 新模型（当前使用）

- **分离的 Asset/Liability 类**: 类型安全，职责明确
- **分离的枚举**: `AssetType` (5个类型) 和 `LiabilityType` (6个类型)
- **FinancialProvider**: 新的状态管理 Provider

```dart
// 新模型示例
enum AssetType { property, deposit, stock, fund, insurance }
enum LiabilityType { debt, mortgage, carLoan, creditCard, personalLoan, privateLoan }

class Asset extends FinancialRecord { /* ... */ }
class Liability extends FinancialRecord { /* ... */ }
```

---

## 阶段 1: 删除旧页面（最安全）

### 文件清单

| 文件路径 | 替代方案 | 代码行数 | 优先级 |
|---------|---------|---------|--------|
| `lib/screens/asset_list_screen.dart` | `lib/screens/main/assets_tab_screen.dart` | ~500 | HIGH |
| `lib/screens/asset_form_screen.dart` | `lib/screens/financial_record_form_screen.dart` | ~600 | HIGH |
| `lib/screens/asset_detail_screen.dart` | `lib/screens/financial_record_detail_screen.dart` | ~500 | HIGH |
| `lib/screens/asset_history_screen.dart` | 新审计日志功能 | ~400 | HIGH |

### 删除原因

1. **asset_list_screen.dart**
   - 使用旧 `AssetProvider`
   - 已被 `main/assets_tab_screen.dart` 完全替代
   - 功能不完整，缺少类型筛选

2. **asset_form_screen.dart**
   - 使用旧 `AssetProvider` 和旧 `Asset` 模型
   - 已被 `financial_record_form_screen.dart` 替代
   - 不支持扩展字段

3. **asset_detail_screen.dart**
   - 使用旧 `AssetProvider`
   - 已被 `financial_record_detail_screen.dart` 替代
   - 显示逻辑不完整

4. **asset_history_screen.dart**
   - 旧的审计日志查看页面
   - 审计功能已集成到新的详情页面

### 执行步骤

```bash
# 1. 确认无引用
grep -r "asset_list_screen" lib/
grep -r "asset_form_screen" lib/
grep -r "asset_detail_screen" lib/
grep -r "asset_history_screen" lib/

# 2. 删除文件
git rm lib/screens/asset_list_screen.dart
git rm lib/screens/asset_form_screen.dart
git rm lib/screens/asset_detail_screen.dart
git rm lib/screens/asset_history_screen.dart

# 3. 测试应用
flutter run -d windows
```

### 验证清单

- [ ] 应用启动正常
- [ ] 资产列表页面显示正常
- [ ] 添加资产功能正常
- [ ] 查看资产详情正常
- [ ] 审计日志显示正常

---

## 阶段 2: 删除旧组件（较安全）

### 文件清单

| 文件路径 | 替代方案 | 代码行数 | 优先级 |
|---------|---------|---------|--------|
| `lib/widgets/smart_asset_name_input.dart` | `smart_financial_record_name_input.dart` | ~300 | HIGH |
| `lib/widgets/asset_list_item.dart` | 新页面内嵌组件 | ~250 | MEDIUM |
| `lib/widgets/grouped_asset_list_item.dart` | `liability_grouped_list.dart` | ~350 | MEDIUM |
| `lib/widgets/two_level_grouped_asset_list.dart` | 新标签页导航 | ~400 | MEDIUM |
| `lib/widgets/asset_summary_card.dart` | `main/overview_tab_screen.dart` | ~200 | MEDIUM |

### 删除原因

1. **smart_asset_name_input.dart**
   - 使用旧 `AssetProvider` 搜索
   - 已被 `smart_financial_record_name_input.dart` 替代
   - 不支持负债类型

2. **asset_list_item.dart**
   - 旧的资产列表项组件
   - 功能已整合到新页面的内嵌组件

3. **grouped_asset_list_item.dart**
   - 旧的分组逻辑
   - 被 `liability_grouped_list.dart` 替代

4. **two_level_grouped_asset_list.dart**
   - 复杂的二级分组组件
   - 新架构使用标签页导航，不再需要

5. **asset_summary_card.dart**
   - 旧的汇总卡片
   - 被 `overview_tab_screen.dart` 中的新卡片替代

### 执行步骤

```bash
# 1. 确认无引用
grep -r "smart_asset_name_input" lib/
grep -r "asset_list_item" lib/
grep -r "grouped_asset_list_item" lib/
grep -r "two_level_grouped_asset_list" lib/
grep -r "asset_summary_card" lib/

# 2. 删除文件
git rm lib/widgets/smart_asset_name_input.dart
git rm lib/widgets/asset_list_item.dart
git rm lib/widgets/grouped_asset_list_item.dart
git rm lib/widgets/two_level_grouped_asset_list.dart
git rm lib/widgets/asset_summary_card.dart

# 3. 测试应用
flutter run -d windows
```

### 验证清单

- [ ] 智能输入功能正常
- [ ] 资产列表显示正常
- [ ] 负债分组显示正常
- [ ] 汇总卡片显示正常

---

## 阶段 3: 删除旧 Provider（需验证）

### 文件清单

| 文件路径 | 替代方案 | 代码行数 | 优先级 |
|---------|---------|---------|--------|
| `lib/providers/asset_provider.dart` | `financial_provider.dart` | 568 | HIGH |

### 依赖分析

需要查找所有引用 `AssetProvider` 的文件并替换为 `FinancialProvider`：

```bash
# 查找所有引用
grep -r "AssetProvider" lib/
```

### 迁移步骤

1. **搜索引用**
   ```bash
   grep -r "import.*asset_provider" lib/
   grep -r "AssetProvider" lib/
   ```

2. **替换导入**
   ```dart
   // 旧代码
   import '../providers/asset_provider.dart';
   final provider = context.watch<AssetProvider>();

   // 新代码
   import '../providers/financial_provider.dart';
   final provider = context.watch<FinancialProvider>();
   ```

3. **替换数据访问**
   ```dart
   // 旧代码
   provider.assets
   provider.addAsset(...)
   provider.updateAsset(...)

   // 新代码（资产）
   provider.assets
   provider.addAsset(...)

   // 新代码（负债）
   provider.liabilities
   provider.addLiability(...)
   ```

4. **测试**
   ```bash
   flutter test
   flutter run -d windows
   ```

5. **删除文件**
   ```bash
   git rm lib/providers/asset_provider.dart
   ```

### 验证清单

- [ ] 所有引用已替换
- [ ] 单元测试通过
- [ ] 集成测试通过
- [ ] 应用功能正常

---

## 阶段 4: 删除旧模型（最复杂）

### 文件清单

| 文件路径 | 替代方案 | 代码行数 | 优先级 |
|---------|---------|---------|--------|
| `lib/models/asset.dart` | `financial_models.dart` | 363 | CRITICAL |

### 循环依赖问题

**当前问题**：

```dart
// lib/models/financial_models.dart 第6行
import 'asset.dart' as legacy; // ❌ 循环依赖

// 兼容性方法
Asset toAsset() {
  return legacy.Asset(
    // ...
  );
}
```

### 解决方案

1. **移除循环依赖**
   ```dart
   // 从 financial_models.dart 删除
   import 'asset.dart' as legacy;

   // 删除兼容性方法 toAsset()
   ```

2. **查找所有使用旧模型的代码**
   ```bash
   grep -r "import.*models/asset" lib/
   grep -r "models/asset" lib/
   ```

3. **替换导入**
   ```dart
   // 旧代码
   import '../models/asset.dart';

   // 新代码
   import '../models/financial_models.dart';
   ```

4. **更新类型引用**
   ```dart
   // 旧代码
   AssetType.creditCard  // 旧模型中是资产类型

   // 新代码
   LiabilityType.creditCard  // 新模型中是负债类型
   ```

5. **测试**
   ```bash
   flutter test
   flutter run -d windows
   ```

6. **删除文件**
   ```bash
   git rm lib/models/asset.dart
   ```

### 验证清单

- [ ] 循环依赖已移除
- [ ] 所有导入已更新
- [ ] 类型引用已更正
- [ ] 单元测试通过
- [ ] 集成测试通过
- [ ] 应用功能正常

---

## 统计摘要

| 阶段 | 文件数 | 代码行数 | 风险等级 | 预计时间 |
|------|--------|----------|----------|----------|
| 阶段1: 旧页面 | 4 | ~2,000 | LOW | 1小时 |
| 阶段2: 旧组件 | 5 | ~1,500 | LOW-MEDIUM | 1小时 |
| 阶段3: 旧Provider | 1 | 568 | MEDIUM | 2-3小时 |
| 阶段4: 旧模型 | 1 | 363 | HIGH | 3-4小时 |
| **总计** | **11** | **~4,431** | - | **7-9小时** |

---

## 风险评估

| 风险等级 | 描述 | 影响范围 |
|---------|------|---------|
| **CRITICAL** | 循环依赖需要仔细处理 | `asset.dart`, `financial_models.dart` |
| **HIGH** | Provider 删除影响状态管理 | 全局状态管理 |
| **MEDIUM** | 页面删除可能影响路由 | 导航路由 |
| **LOW** | 组件删除相对隔离 | UI 显示 |

---

## 注意事项

1. **备份**: 每个阶段执行前先创建分支备份
2. **测试**: 每个阶段完成后必须全面测试
3. **文档**: 更新相关文档和注释
4. **提交**: 每个阶段单独提交，便于回滚
5. **通知**: 如果是团队协作，通知其他开发者

---

## 执行建议

### 推荐执行方式

```bash
# 1. 创建清理分支
git checkout -b cleanup/redundant-code-phase1

# 2. 执行阶段1（删除旧页面）
# ... 执行删除和测试

# 3. 提交阶段1
git add .
git commit -m "cleanup: 删除旧模型页面（阶段1）

- 删除 asset_list_screen.dart
- 删除 asset_form_screen.dart
- 删除 asset_detail_screen.dart
- 删除 asset_history_screen.dart

这些页面已被新模型页面完全替代：
- assets_tab_screen.dart
- financial_record_form_screen.dart
- financial_record_detail_screen.dart"

# 4. 创建阶段2分支
git checkout -b cleanup/redundant-code-phase2

# 5. 继续执行后续阶段
```

### 回滚方案

如果出现问题，可以快速回滚：

```bash
# 回滚到阶段1之前
git revert <commit-hash>

# 或直接切换回主分支
git checkout master
git branch -D cleanup/redundant-code-phase1
```

---

## 当前状态

- [x] 阶段1: 已识别4个旧页面
- [x] 阶段2: 已识别5个旧组件
- [x] 阶段3: 已识别旧 Provider
- [x] 阶段4: 已识别循环依赖问题
- [ ] 等待执行清理操作

---

## 参考资料

- [CLAUDE.md](../CLAUDE.md) - 项目架构指南
- [README.md](../README.md) - 项目概述
- 数据模型迁移: `lib/models/financial_models.dart`
