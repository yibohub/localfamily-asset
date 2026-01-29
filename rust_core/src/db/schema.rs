//! 数据库 Schema 定义
//!
//! 创建所有必要的表

use rusqlite::Connection;

use super::DbError;

/// 创建数据库表结构
pub fn create_schema(conn: &Connection) -> Result<(), DbError> {
    // 资产表（使用 occurrence_date 替代 buy_date）
    conn.execute(
        "CREATE TABLE IF NOT EXISTS assets (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            amount REAL NOT NULL,
            currency TEXT DEFAULT 'CNY',
            account TEXT,
            occurrence_date TEXT NOT NULL,
            buy_price REAL,
            current_price REAL,
            note TEXT,
            tags TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    // 资产变更记录表（审计日志）
    conn.execute(
        "CREATE TABLE IF NOT EXISTS asset_changes (
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
        "CREATE INDEX IF NOT EXISTS idx_asset_changes_asset_id ON asset_changes(asset_id)",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_asset_changes_changed_at ON asset_changes(changed_at)",
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

/// 获取当前 schema 版本
fn get_schema_version(conn: &Connection) -> Result<i32, DbError> {
    match conn.query_row(
        "SELECT value FROM settings WHERE key = 'schema_version'",
        [],
        |row| {
            let version: String = row.get(0)?;
            version.parse::<i32>().map_err(|_| rusqlite::Error::InvalidQuery)
        },
    ) {
        Ok(v) => Ok(v),
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(1),
        Err(e) => Err(DbError::DatabaseError(e.to_string())),
    }
}

/// 设置 schema 版本
fn set_schema_version(conn: &Connection, version: i32) -> Result<(), DbError> {
    conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES ('schema_version', ?1)",
        [version.to_string()],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;
    Ok(())
}

/// 迁移 v2：重命名 buy_date 为 occurrence_date，并设为 NOT NULL
fn migrate_v2_occurrence_date(conn: &Connection) -> Result<(), DbError> {
    eprintln!("开始数据库迁移 v2：重命名 buy_date 为 occurrence_date");

    // 简化版本：直接检查 buy_date 是否存在
    let mut stmt = conn.prepare("PRAGMA table_info(assets)")
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

    let rows = stmt.query_map([], |row| {
        let col_name: String = row.get(1).unwrap_or_default();
        Ok(col_name)
    }).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    let mut has_buy_date = false;
    let mut has_occurrence_date = false;

    for row in rows {
        let col_name = row.map_err(|e| DbError::DatabaseError(e.to_string()))?;
        if col_name == "buy_date" {
            has_buy_date = true;
        } else if col_name == "occurrence_date" {
            has_occurrence_date = true;
        }
    }

    if has_occurrence_date {
        eprintln!("跳过迁移 v2：occurrence_date 列已存在");
        return Ok(());
    }

    if has_buy_date {
        // 回填空值
        let today = chrono::Utc::now().format("%Y-%m-%d").to_string();
        conn.execute(
            "UPDATE assets SET buy_date = ?1 WHERE buy_date IS NULL",
            [&today],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        // 重建表
        conn.execute(
            "CREATE TABLE assets_new (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                name TEXT NOT NULL,
                amount REAL NOT NULL,
                currency TEXT DEFAULT 'CNY',
                account TEXT,
                occurrence_date TEXT NOT NULL,
                buy_price REAL,
                current_price REAL,
                note TEXT,
                tags TEXT,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )",
            [],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        conn.execute(
            "INSERT INTO assets_new
             SELECT id, type, name, amount, currency, account, buy_date, buy_price, current_price, note, tags, created_at, updated_at
             FROM assets",
            [],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        conn.execute("DROP TABLE assets", [])
            .map_err(|e| DbError::DatabaseError(e.to_string()))?;

        conn.execute("ALTER TABLE assets_new RENAME TO assets", [])
            .map_err(|e| DbError::DatabaseError(e.to_string()))?;
    }

    eprintln!("完成数据库迁移 v2");
    Ok(())
}

/// 迁移 v3：添加审计日志表
fn migrate_v3_audit_log(conn: &Connection) -> Result<(), DbError> {
    eprintln!("开始数据库迁移 v3：添加审计日志表");

    conn.execute(
        "CREATE TABLE IF NOT EXISTS asset_changes (
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
        )",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_asset_changes_asset_id ON asset_changes(asset_id)",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_asset_changes_changed_at ON asset_changes(changed_at)",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    eprintln!("完成数据库迁移 v3");
    Ok(())
}

/// 迁移 v4：添加自定义类型表
fn migrate_v4_custom_types(conn: &Connection) -> Result<(), DbError> {
    eprintln!("开始数据库迁移 v4：添加自定义类型表");

    conn.execute(
        "CREATE TABLE IF NOT EXISTS custom_asset_types (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            icon_name TEXT NOT NULL,
            is_liability INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
        )",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_custom_types_is_liability
         ON custom_asset_types(is_liability)",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    eprintln!("完成数据库迁移 v4");
    Ok(())
}

/// 迁移 v5：添加 buy_price 和 current_price 列
fn migrate_v5_add_price_columns(conn: &Connection) -> Result<(), DbError> {
    eprintln!("========== 开始数据库迁移 v5：添加 buy_price 和 current_price 列 ==========");

    // 检查列是否已存在
    let mut stmt = conn.prepare("PRAGMA table_info(assets)")
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

    let rows = stmt.query_map([], |row| {
        let col_name: String = row.get(1).unwrap_or_default();
        Ok(col_name)
    }).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    let mut has_buy_price = false;
    let mut has_current_price = false;
    let mut column_names = Vec::new();

    for row in rows {
        let col_name = row.map_err(|e| DbError::DatabaseError(e.to_string()))?;
        column_names.push(col_name.clone());
        if col_name == "buy_price" {
            has_buy_price = true;
        } else if col_name == "current_price" {
            has_current_price = true;
        }
    }

    eprintln!("当前 assets 表的列: {:?}", column_names);
    eprintln!("has_buy_price = {}, has_current_price = {}", has_buy_price, has_current_price);

    // 如果列已存在，跳过迁移
    if has_buy_price && has_current_price {
        eprintln!("跳过迁移 v5：buy_price 和 current_price 列已存在");
        return Ok(());
    }

    // 添加 buy_price 列（如果不存在）
    if !has_buy_price {
        eprintln!("正在添加 buy_price 列...");
        match conn.execute(
            "ALTER TABLE assets ADD COLUMN buy_price REAL",
            [],
        ) {
            Ok(_) => eprintln!("已添加 buy_price 列"),
            Err(e) => {
                eprintln!("添加 buy_price 列失败: {}", e);
                return Err(DbError::DatabaseError(e.to_string()));
            }
        }
    }

    // 添加 current_price 列（如果不存在）
    if !has_current_price {
        eprintln!("正在添加 current_price 列...");
        match conn.execute(
            "ALTER TABLE assets ADD COLUMN current_price REAL",
            [],
        ) {
            Ok(_) => eprintln!("已添加 current_price 列"),
            Err(e) => {
                eprintln!("添加 current_price 列失败: {}", e);
                return Err(DbError::DatabaseError(e.to_string()));
            }
        }
    }

    eprintln!("========== 完成数据库迁移 v5 ==========");
    Ok(())
}

/// 初始化数据库（创建表结构并执行迁移）
pub fn init_db(conn: &Connection) -> Result<(), DbError> {
    create_schema(conn)?;

    // 运行版本迁移
    let version = get_schema_version(conn)?;

    if version < 2 {
        migrate_v2_occurrence_date(conn)?;
        set_schema_version(conn, 2)?;
    }

    if version < 3 {
        migrate_v3_audit_log(conn)?;
        set_schema_version(conn, 3)?;
    }

    if version < 4 {
        migrate_v4_custom_types(conn)?;
        set_schema_version(conn, 4)?;
    }

    if version < 5 {
        migrate_v5_add_price_columns(conn)?;
        set_schema_version(conn, 5)?;
    }

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
