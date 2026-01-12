//! 数据库 Schema 定义
//!
//! 创建所有必要的表

use rusqlite::Connection;

use super::DbError;

/// 创建数据库表结构
pub fn create_schema(conn: &Connection) -> Result<(), DbError> {
    // 资产表
    conn.execute(
        "CREATE TABLE IF NOT EXISTS assets (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            amount REAL NOT NULL,
            currency TEXT DEFAULT 'CNY',
            account TEXT,
            buy_date TEXT,
            buy_price REAL,
            current_price REAL,
            note TEXT,
            tags TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    // 历史价格表
    conn.execute(
        "CREATE TABLE IF NOT EXISTS asset_history (
            id TEXT PRIMARY KEY,
            asset_id TEXT NOT NULL,
            price REAL NOT NULL,
            recorded_at INTEGER NOT NULL,
            FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
        )",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    // 附件表
    conn.execute(
        "CREATE TABLE IF NOT EXISTS attachments (
            id TEXT PRIMARY KEY,
            asset_id TEXT NOT NULL,
            file_name TEXT NOT NULL,
            file_size INTEGER NOT NULL,
            encrypted_path TEXT NOT NULL,
            mime_type TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
        )",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    // 设置表
    conn.execute(
        "CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    // 创建索引
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_assets_type ON assets(type)",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_assets_created_at ON assets(created_at)",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_history_asset_id ON asset_history(asset_id)",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_history_recorded_at ON asset_history(recorded_at)",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    Ok(())
}

/// 初始化数据库（创建表结构）
pub fn init_db(conn: &Connection) -> Result<(), DbError> {
    create_schema(conn)?;

    // 插入默认设置
    let default_settings = vec![
        ("version", "1"),
        ("default_currency", "CNY"),
    ];

    for (key, value) in default_settings {
        conn.execute(
            "INSERT OR IGNORE INTO settings (key, value) VALUES (?1, ?2)",
            [key, value],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;
    }

    Ok(())
}
