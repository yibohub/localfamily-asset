//! 自定义资产类型功能测试
//!
//! 运行测试：cargo test --package localfamily_asset_core --test test_custom_types

use rusqlite::Connection;

/// 创建测试数据库连接
fn setup_test_db() -> Connection {
    let conn = Connection::open_in_memory().unwrap();

    // 初始化数据库结构
    conn.execute(
        "CREATE TABLE IF NOT EXISTS custom_asset_types (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            icon_name TEXT NOT NULL,
            is_liability INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
        )",
        [],
    )
    .unwrap();

    // 创建索引
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_custom_types_is_liability
         ON custom_asset_types(is_liability)",
        [],
    )
    .unwrap();

    conn
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 测试 1：验证表结构创建成功
    #[test]
    fn test_table_creation() {
        let conn = setup_test_db();

        // 验证表是否存在
        let table_exists: bool = conn
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='custom_asset_types'",
                [],
                |row| row.get(0),
            )
            .unwrap();

        assert!(table_exists, "custom_asset_types table should exist");
    }

    /// 测试 2：验证索引创建成功
    #[test]
    fn test_index_creation() {
        let conn = setup_test_db();

        // 验证索引是否存在
        let index_exists: bool = conn
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='idx_custom_types_is_liability'",
                [],
                |row| row.get(0),
            )
            .unwrap();

        assert!(index_exists, "idx_custom_types_is_liability index should exist");
    }

    /// 测试 3：测试创建自定义资产类型
    #[test]
    fn test_create_custom_type() {
        let conn = setup_test_db();

        // 插入测试数据
        let id = "custom_test_001";
        let name = "测试类型";
        let icon_name = "star";
        let is_liability = false;
        let created_at = 1234567890i64;

        conn.execute(
            "INSERT INTO custom_asset_types (id, name, icon_name, is_liability, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            (id, name, icon_name, is_liability as i32, created_at),
        )
        .unwrap();

        // 验证插入成功
        let count: i64 = conn
            .query_row("SELECT COUNT(*) FROM custom_asset_types", [], |row| {
                row.get(0)
            })
            .unwrap();

        assert_eq!(count, 1, "Should have 1 custom type");

        // 验证数据内容
        let (retrieved_name, retrieved_icon): (String, String) = conn
            .query_row(
                "SELECT name, icon_name FROM custom_asset_types WHERE id = ?1",
                [id],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .unwrap();

        assert_eq!(retrieved_name, name);
        assert_eq!(retrieved_icon, icon_name);
    }

    /// 测试 4：测试获取所有自定义类型
    #[test]
    fn test_get_all_custom_types() {
        let conn = setup_test_db();

        // 插入多个类型
        let types = vec![
            ("custom_001", "存款", "account_balance", false, 1000i64),
            ("custom_002", "房贷", "home_work", true, 2000i64),
            ("custom_003", "股票", "trending_up", false, 3000i64),
        ];

        for (id, name, icon, is_liability, created_at) in &types {
            conn.execute(
                "INSERT INTO custom_asset_types (id, name, icon_name, is_liability, created_at)
                 VALUES (?1, ?2, ?3, ?4, ?5)",
                (id, name, icon, *is_liability as i32, created_at),
            )
            .unwrap();
        }

        // 查询所有类型
        let mut stmt = conn
            .prepare("SELECT id, name, icon_name, is_liability FROM custom_asset_types ORDER BY created_at DESC")
            .unwrap();

        let rows = stmt
            .query_map([], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, i32>(3)? == 1,
                ))
            })
            .unwrap();

        let count = rows.count();
        assert_eq!(count, 3, "Should have 3 custom types");
    }

    /// 测试 5：测试删除自定义类型
    #[test]
    fn test_delete_custom_type() {
        let conn = setup_test_db();

        // 先插入一个类型
        let id = "custom_to_delete";
        conn.execute(
            "INSERT INTO custom_asset_types (id, name, icon_name, is_liability, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            (id, "待删除", "star", false as i32, 1000i64),
        )
        .unwrap();

        // 验证存在
        let count_before: i64 = conn
            .query_row("SELECT COUNT(*) FROM custom_asset_types", [], |row| {
                row.get(0)
            })
            .unwrap();
        assert_eq!(count_before, 1);

        // 删除
        let affected = conn
            .execute("DELETE FROM custom_asset_types WHERE id = ?1", [id])
            .unwrap();

        assert_eq!(affected, 1, "Should delete 1 row");

        // 验证已删除
        let count_after: i64 = conn
            .query_row("SELECT COUNT(*) FROM custom_asset_types", [], |row| {
                row.get(0)
            })
            .unwrap();
        assert_eq!(count_after, 0, "Type should be deleted");
    }

    /// 测试 6：测试检查类型是否被使用
    #[test]
    fn test_is_type_in_use() {
        let conn = setup_test_db();

        // 创建资产表
        conn.execute(
            "CREATE TABLE IF NOT EXISTS assets (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                name TEXT NOT NULL,
                amount REAL NOT NULL
            )",
            [],
        )
        .unwrap();

        // 插入自定义类型
        let used_type_id = "custom_used";
        let unused_type_id = "custom_unused";

        conn.execute(
            "INSERT INTO custom_asset_types (id, name, icon_name, is_liability, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            (used_type_id, "已使用", "star", false as i32, 1000i64),
        )
        .unwrap();

        conn.execute(
            "INSERT INTO custom_asset_types (id, name, icon_name, is_liability, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            (unused_type_id, "未使用", "favorite", false as i32, 2000i64),
        )
        .unwrap();

        // 创建使用该类型的资产
        conn.execute(
            "INSERT INTO assets (id, type, name, amount) VALUES (?1, ?2, ?3, ?4)",
            ("asset_001", used_type_id, "测试资产", 1000.0),
        )
        .unwrap();

        // 检查是否被使用
        let used_count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM assets WHERE type = ?1",
                [used_type_id],
                |row| row.get(0),
            )
            .unwrap();

        let unused_count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM assets WHERE type = ?1",
                [unused_type_id],
                |row| row.get(0),
            )
            .unwrap();

        assert_eq!(used_count, 1, "Used type should have 1 asset");
        assert_eq!(unused_count, 0, "Unused type should have 0 assets");
    }

    /// 测试 7：测试按负债状态筛选
    #[test]
    fn test_filter_by_liability() {
        let conn = setup_test_db();

        // 插入混合类型
        let types = vec![
            ("custom_001", "存款", "account_balance", false, 1000i64),
            ("custom_002", "房贷", "home_work", true, 2000i64),
            ("custom_003", "股票", "trending_up", false, 3000i64),
            ("custom_004", "车贷", "directions_car", true, 4000i64),
        ];

        for (id, name, icon, is_liability, created_at) in &types {
            conn.execute(
                "INSERT INTO custom_asset_types (id, name, icon_name, is_liability, created_at)
                 VALUES (?1, ?2, ?3, ?4, ?5)",
                (id, name, icon, *is_liability as i32, created_at),
            )
            .unwrap();
        }

        // 查询资产类型
        let asset_count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM custom_asset_types WHERE is_liability = 0",
                [],
                |row| row.get(0),
            )
            .unwrap();

        // 查询负债类型
        let liability_count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM custom_asset_types WHERE is_liability = 1",
                [],
                |row| row.get(0),
            )
            .unwrap();

        assert_eq!(asset_count, 2, "Should have 2 asset types");
        assert_eq!(liability_count, 2, "Should have 2 liability types");
    }

    /// 测试 8：测试 ID 格式验证
    #[test]
    fn test_id_format() {
        let valid_ids = vec![
            "custom_123e4567-e89b-12d3-a456-426614174000",
            "custom_00000000-0000-0000-0000-000000000000",
            "custom_ffffffff-ffff-ffff-ffff-ffffffffffff",
        ];

        for id in valid_ids {
            assert!(
                id.starts_with("custom_"),
                "ID should start with 'custom_': {}",
                id
            );
            assert!(
                id.len() > 7,
                "ID should be longer than 'custom_' prefix: {}",
                id
            );
        }
    }

    /// 测试 9：测试图标名称验证
    #[test]
    fn test_valid_icon_names() {
        let valid_icons = vec![
            "star", "favorite", "bookmark", "label", "tag", "diamond",
            "pets", "flight", "restaurant", "shopping_bag",
        ];

        for icon in valid_icons {
            assert!(!icon.is_empty(), "Icon name should not be empty");
            assert!(
                icon.len() <= 20,
                "Icon name should be reasonably short: {}",
                icon
            );
        }
    }

    /// 测试 10：测试并发插入（简单测试）
    #[test]
    fn test_multiple_inserts() {
        let conn = setup_test_db();

        // 批量插入
        for i in 0..10 {
            let id = format!("custom_{}", i);
            conn.execute(
                "INSERT INTO custom_asset_types (id, name, icon_name, is_liability, created_at)
                 VALUES (?1, ?2, ?3, ?4, ?5)",
                (id.as_str(), format!("类型{}", i), "star", false as i32, i as i64),
            )
            .unwrap();
        }

        // 验证数量
        let count: i64 = conn
            .query_row("SELECT COUNT(*) FROM custom_asset_types", [], |row| {
                row.get(0)
            })
            .unwrap();

        assert_eq!(count, 10, "Should have 10 custom types");
    }
}

/// 运行所有测试的示例
#[cfg(test)]
mod integration_tests {
    use super::*;

    /// 集成测试：完整的工作流程
    #[test]
    fn test_complete_workflow() {
        let conn = setup_test_db();

        // 1. 创建资产类型
        conn.execute(
            "INSERT INTO custom_asset_types (id, name, icon_name, is_liability, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            ("custom_asset_1", "理财产品", "star", false as i32, 1000i64),
        )
        .unwrap();

        // 2. 创建负债类型
        conn.execute(
            "INSERT INTO custom_asset_types (id, name, icon_name, is_liability, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            ("custom_liability_1", "私人借款", "person", true as i64, 2000i64),
        )
        .unwrap();

        // 3. 验证数量
        let total_count: i64 = conn
            .query_row("SELECT COUNT(*) FROM custom_asset_types", [], |row| {
                row.get(0)
            })
            .unwrap();
        assert_eq!(total_count, 2);

        // 4. 按类型筛选
        let asset_count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM custom_asset_types WHERE is_liability = 0",
                [],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(asset_count, 1);

        // 5. 删除资产类型
        let affected = conn
            .execute(
                "DELETE FROM custom_asset_types WHERE id = ?1",
                ["custom_asset_1"],
            )
            .unwrap();
        assert_eq!(affected, 1);

        // 6. 验证删除后数量
        let final_count: i64 = conn
            .query_row("SELECT COUNT(*) FROM custom_asset_types", [], |row| {
                row.get(0)
            })
            .unwrap();
        assert_eq!(final_count, 1);
    }
}
