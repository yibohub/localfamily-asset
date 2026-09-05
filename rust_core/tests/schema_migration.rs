//! Schema 迁移集成测试
//!
//! 重点覆盖 v8(移除 asset_changes 外键):存量数据库在解锁加载路径
//! (verify_password_v2 → load_encrypted_db)上依赖 init_db 幂等执行迁移,
//! 这些用例保证迁移正确、数据无损且可重复执行。

use localfamily_asset_core::db::{create_schema, init_db};
use rusqlite::Connection;

/// 构造一个 v7 形态的存量库:带 CASCADE 外键的 asset_changes 表 + 审计数据,
/// schema_version 停在 7(settings 表由调用方补建并写版本号)
fn create_legacy_v7_conn() -> Connection {
    let conn = Connection::open_in_memory().unwrap();
    conn.execute_batch(
        "CREATE TABLE assets (
            id TEXT PRIMARY KEY,
            asset_type TEXT NOT NULL,
            name TEXT NOT NULL,
            amount REAL NOT NULL,
            currency TEXT NOT NULL,
            occurrence_date TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );
        CREATE TABLE asset_changes (
            id TEXT PRIMARY KEY,
            asset_id TEXT NOT NULL,
            change_type TEXT NOT NULL,
            occurrence_date_old TEXT,
            occurrence_date_new TEXT,
            amount_old REAL,
            amount_new REAL,
            name_old TEXT,
            name_new TEXT,
            data_snapshot_old TEXT,
            data_snapshot_new TEXT,
            changed_field TEXT,
            changed_at INTEGER NOT NULL,
            FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
        );
        INSERT INTO assets VALUES ('asset-1', 'deposit', 'Legacy', 100.0, 'CNY', '2024-01-01', 1, 1);
        INSERT INTO asset_changes (id, asset_id, change_type, changed_at)
            VALUES ('chg-1', 'asset-1', 'created', 1);",
    )
    .unwrap();
    conn
}

#[test]
fn test_v8_migration_drops_fk_and_keeps_data() {
    let conn = create_legacy_v7_conn();

    // 补建 settings 表并标记版本 7(模拟存量库)
    conn.execute_batch(
        "CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
         INSERT INTO settings (key, value) VALUES ('schema_version', '7');",
    )
    .unwrap();

    // init_db 幂等执行迁移(解锁加载路径上的调用方式)
    init_db(&conn).unwrap();

    // 迁移后 asset_changes 不再含外键
    let create_sql: String = conn
        .query_row(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name='asset_changes'",
            [],
            |row| row.get(0),
        )
        .unwrap();
    assert!(
        !create_sql.to_uppercase().contains("FOREIGN KEY"),
        "v8 迁移后 asset_changes 不应再带外键, 实际: {}",
        create_sql
    );

    // 审计数据逐行保留
    let count: i64 = conn
        .query_row("SELECT COUNT(*) FROM asset_changes", [], |r| r.get(0))
        .unwrap();
    assert_eq!(count, 1);
    let asset_id: String = conn
        .query_row(
            "SELECT asset_id FROM asset_changes WHERE id = 'chg-1'",
            [],
            |r| r.get(0),
        )
        .unwrap();
    assert_eq!(asset_id, "asset-1");

    // schema 版本推进到 8
    let version: String = conn
        .query_row(
            "SELECT value FROM settings WHERE key = 'schema_version'",
            [],
            |r| r.get(0),
        )
        .unwrap();
    assert_eq!(version, "8");
}

#[test]
fn test_v8_migration_is_idempotent() {
    let conn = create_legacy_v7_conn();
    conn.execute_batch(
        "CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
         INSERT INTO settings (key, value) VALUES ('schema_version', '7');",
    )
    .unwrap();

    init_db(&conn).unwrap();
    let before: i64 = conn
        .query_row("SELECT COUNT(*) FROM asset_changes", [], |r| r.get(0))
        .unwrap();

    // 重复执行(每次解锁都会调 init_db)不改变数据
    init_db(&conn).unwrap();
    init_db(&conn).unwrap();
    let after: i64 = conn
        .query_row("SELECT COUNT(*) FROM asset_changes", [], |r| r.get(0))
        .unwrap();
    assert_eq!(before, after);

    // 迁移后可以向 asset_changes 写入"引用已删除资产"的删除审计(回归核心场景)
    conn.execute(
        "INSERT INTO asset_changes (id, asset_id, change_type, changed_at)
         VALUES ('chg-del', 'deleted-asset', 'deleted', 2)",
        [],
    )
    .unwrap();
}

#[test]
fn test_delete_audit_allowed_after_v8() {
    // 全新库(create_schema,已无外键):资产删除后仍能插入其删除审计
    let conn = Connection::open_in_memory().unwrap();
    create_schema(&conn).unwrap();

    conn.execute_batch(
        "INSERT INTO assets (id, asset_type, name, amount, currency, occurrence_date, created_at, updated_at)
             VALUES ('a1', 'fund', 'T', 1.0, 'CNY', '2024-01-01', 1, 1);
         DELETE FROM assets WHERE id = 'a1';",
    )
    .unwrap();

    let inserted = conn.execute(
        "INSERT INTO asset_changes (id, asset_id, change_type, changed_at)
         VALUES ('c1', 'a1', 'deleted', 9)",
        [],
    );
    assert!(inserted.is_ok(), "无外键的审计表应允许引用已删除资产");
}
