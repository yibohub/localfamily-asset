# 快速测试指南

## 一键构建和启动

```powershell
# 1. 构建 Rust Core
cd rust_core
cargo build --release

# 2. 复制动态库到 Flutter 资源目录
# Windows
Copy-Item target/release/localfamily_asset_core.dll ../flutter_app/assets/ -Force

# 3. 启动 Flutter 应用
cd ../flutter_app
flutter run -d windows
```

---

## 核心功能快速测试（5 分钟）

### ✅ 测试 1：创建自定义资产类型

1. 启动应用后，进入"资产"标签页
2. 点击筛选栏右侧的 **➕** 按钮（在最后一个类型后面）
3. 在管理对话框中点击右下角 **➕** 按钮
4. 输入名称：`理财产品`
5. 选择图标：⭐（星星）
6. 点击"创建"

**验证点：**
- 显示"创建成功"提示
- 筛选栏出现"理财产品"选项
- 管理列表显示该类型

---

### ✅ 测试 2：使用自定义类型添加资产

1. 点击右下角 **➕** 按钮（添加资产）
2. 填写表单：
   - 资产名称：`测试理财`
   - 选择类型：`理财产品`（应该能看到）
   - 金额：`10000`
3. 点击"添加资产"

**验证点：**
- 资产成功添加
- 资产列表显示该资产
- 类型显示为"理财产品"

---

### ✅ 测试 3：筛选功能

1. 在筛选栏点击"理财产品"
2. 查看资产列表

**验证点：**
- 只显示"理财产品"类型的资产
- 列表标题显示正确数量

---

### ✅ 测试 4：删除保护

1. 点击筛选栏 **➕** 按钮
2. 尝试删除"理财产品"
3. 确认删除

**验证点：**
- 显示"该类型正在使用中，无法删除"
- 类型未被删除

---

### ✅ 测试 5：删除未使用的类型

1. 创建一个新类型（不添加资产）
2. 在管理对话框中删除该类型
3. 确认删除

**验证点：**
- 显示"删除成功"
- 类型从列表中消失
- 筛选栏中移除

---

## 常见问题排查

### 问题 1：动态库加载失败

**症状**：启动时报错 "DynamicLibrary.open() failed"

**解决**：
```powershell
# 检查动态库是否存在
Test-Path flutter_app/assets/localfamily_asset_core.dll

# 如果不存在，重新构建
cd rust_core
cargo build --release
Copy-Item target/release/localfamily_asset_core.dll ../flutter_app/assets/ -Force
```

---

### 问题 2：自定义类型不显示

**症状**：创建后筛选栏没有显示

**检查**：
1. 查看控制台是否有错误日志
2. 重启应用
3. 清除应用数据后重新测试

---

### 问题 3：删除操作无响应

**症状**：点击删除按钮没反应

**检查**：
1. 确认是否正在使用该类型
2. 查看 FFI 调用日志
3. 检查数据库中的数据

---

## 手动数据库验证

```bash
# 打开数据库（使用 SQLite 工具）
sqlite64.exe assets.db  # 或任何 SQLite 客户端

# 查看自定义类型表
.schema custom_asset_types

# 查询所有自定义类型
SELECT * FROM custom_asset_types;

# 查询使用自定义类型的资产
SELECT id, type, name, amount FROM assets WHERE type LIKE 'custom_%';

# 检查类型使用情况
SELECT type, COUNT(*) as count FROM assets GROUP BY type;
```

---

## 性能基准

| 操作 | 预期时间 | 实际时间 |
|------|----------|----------|
| 启动应用 | < 3s | _____ |
| 创建自定义类型 | < 500ms | _____ |
| 加载类型列表 | < 200ms | _____ |
| 筛选资产 | < 100ms | _____ |
| 删除类型 | < 300ms | _____ |

---

## 测试完成检查

- [x] 自定义类型创建成功
- [x] 使用自定义类型添加资产成功
- [x] 筛选功能正常
- [x] 删除保护正常工作
- [x] 未使用类型可删除
- [x] UI 响应流畅
- [x] 无控制台错误

---

## 下一步

测试通过后，可以：
1. 测试更多边界情况（参考 TEST_PLAN.md）
2. 添加更多自定义类型测试 UI 性能
3. 验证数据导出/导入功能
4. 测试跨平台兼容性（Android/macOS）
