//! 数据库 Schema 定义
//!
//! 创建所有必要的表

use rusqlite::Connection;

use super::DbError;

/// 创建数据库表结构
pub fn create_schema(conn: &Connection) -> Result<(), DbError> {
    // 资产表（完整版，包含所有类型专属字段）
    conn.execute(
        "CREATE TABLE IF NOT EXISTS assets (
            id TEXT PRIMARY KEY,
            asset_type TEXT NOT NULL,
            name TEXT NOT NULL,
            amount REAL NOT NULL,
            currency TEXT DEFAULT 'CNY',
            account TEXT,
            occurrence_date TEXT NOT NULL,
            buy_price REAL,
            current_price REAL,
            code TEXT,
            exchange TEXT,
            quantity INTEGER,
            note TEXT,
            tags TEXT,
            -- 房产专属字段
            address TEXT,
            building_area REAL,
            living_area REAL,
            property_type TEXT,
            rooms INTEGER,
            floor TEXT,
            build_year INTEGER,
            ownership_type TEXT,
            deed_number TEXT,
            -- 存款专属字段
            deposit_account_type TEXT,
            deposit_period INTEGER,
            maturity_date TEXT,
            deposit_interest_rate REAL,
            -- 保单专属字段
            policy_number TEXT,
            insurance_type TEXT,
            insured TEXT,
            beneficiary TEXT,
            coverage_amount REAL,
            premium REAL,
            premium_period TEXT,
            coverage_period TEXT,
            insurer TEXT,
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

    // 净资产快照表（一天一条，date 为主键，同日覆盖更新）
    conn.execute(
        "CREATE TABLE IF NOT EXISTS net_worth_snapshots (
            date TEXT PRIMARY KEY,
            total_assets REAL NOT NULL,
            total_liabilities REAL NOT NULL,
            net_worth REAL NOT NULL,
            recorded_at INTEGER NOT NULL
        )",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    // 创建索引
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_assets_type ON assets(asset_type)",
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

/// 迁移 v6：添加扩展字段支持（投资类、房产、存款、保单、负债）
fn migrate_v6_add_extended_fields(conn: &Connection) -> Result<(), DbError> {
    eprintln!("========== 开始数据库迁移 v6：添加扩展字段 ==========");

    let mut stmt = conn.prepare("PRAGMA table_info(assets)")
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

    let rows = stmt.query_map([], |row| {
        let col_name: String = row.get(1).unwrap_or_default();
        Ok(col_name)
    }).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    let existing_columns: Vec<String> = rows.filter_map(|r| r.ok()).collect();
    eprintln!("当前列: {:?}", existing_columns);

    // 需要添加的扩展字段
    let columns_to_add = vec![
        // 投资类字段
        ("quantity", "REAL"),
        ("code", "TEXT"),
        ("exchange", "TEXT"),
        // 房产字段
        ("address", "TEXT"),
        ("building_area", "REAL"),
        ("living_area", "REAL"),
        ("property_type", "TEXT"),
        ("rooms", "INTEGER"),
        ("floor", "TEXT"),
        ("build_year", "INTEGER"),
        ("ownership_type", "TEXT"),
        ("deed_number", "TEXT"),
        // 存款字段
        ("deposit_account_type", "TEXT"),
        ("deposit_period", "INTEGER"),
        ("maturity_date", "TEXT"),
        ("deposit_interest_rate", "REAL"),
        // 保单字段
        ("policy_number", "TEXT"),
        ("insurance_type", "TEXT"),
        ("insured", "TEXT"),
        ("beneficiary", "TEXT"),
        ("coverage_amount", "REAL"),
        ("premium", "REAL"),
        ("premium_period", "TEXT"),
        ("coverage_period", "TEXT"),
        ("insurer", "TEXT"),
        // 负债字段
        ("lender", "TEXT"),
        ("due_date", "TEXT"),
        ("interest_rate", "REAL"),
        ("repayment_method", "TEXT"),
        // 信用卡字段
        ("billing_date", "TEXT"),
        ("payment_due_date", "TEXT"),
        ("credit_limit", "REAL"),
        ("cash_limit", "REAL"),
        ("annual_fee", "REAL"),
        ("issuer", "TEXT"),
        ("last_four_digits", "TEXT"),
        // 贷款专属字段
        ("property_address", "TEXT"),
        ("original_loan_amount", "REAL"),
        ("remaining_principal", "REAL"),
        ("loan_type", "TEXT"),
        ("loan_term", "INTEGER"),
        ("vehicle_brand", "TEXT"),
        ("vehicle_model", "TEXT"),
        ("license_plate", "TEXT"),
        ("purpose", "TEXT"),
        ("has_interest", "INTEGER"),
        ("repayment_plan", "TEXT"),
    ];

    for (col_name, col_type) in columns_to_add {
        if !existing_columns.contains(&col_name.to_string()) {
            eprintln!("正在添加列 {} ({})...", col_name, col_type);
            match conn.execute(
                &format!("ALTER TABLE assets ADD COLUMN {} {}", col_name, col_type),
                [],
            ) {
                Ok(_) => eprintln!("已添加 {} 列", col_name),
                Err(err) => {
                    eprintln!("添加 {} 列失败: {}", col_name, err);
                    // 继续尝试添加其他列，不中断
                }
            }
        }
    }

    eprintln!("========== 完成数据库迁移 v6 ==========");
    Ok(())
}

/// 迁移 v7：重命名 type 列为 asset_type
/// SQLite 不支持直接重命名列，需要重建表
fn migrate_v7_rename_type_to_asset_type(conn: &Connection) -> Result<(), DbError> {
    eprintln!("========== 开始数据库迁移 v7：重命名 type 列为 asset_type ==========");

    // 检查当前列名
    let mut stmt = conn.prepare("PRAGMA table_info(assets)")
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

    let rows = stmt.query_map([], |row| {
        let col_name: String = row.get(1).unwrap_or_default();
        Ok(col_name)
    }).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    let existing_columns: Vec<String> = rows.filter_map(|r| r.ok()).collect();
    eprintln!("当前 assets 表的列: {:?}", existing_columns);

    // 如果已经有 asset_type 列，跳过迁移
    if existing_columns.contains(&"asset_type".to_string()) {
        eprintln!("跳过迁移 v7：asset_type 列已存在");
        return Ok(());
    }

    // 如果没有 type 列但有 asset_type 列（理论上不应该发生），也跳过
    if !existing_columns.contains(&"type".to_string()) {
        eprintln!("跳过迁移 v7：type 列不存在（可能是新数据库）");
        return Ok(());
    }

    eprintln!("开始重建 assets 表，将 type 列重命名为 asset_type...");

    // 清理之前可能失败的迁移
    let _ = conn.execute("DROP TABLE IF EXISTS assets_new", []);

    // SQLite 不支持 ALTER TABLE RENAME COLUMN，需要重建表
    // 1. 获取原表的 CREATE TABLE 语句，然后替换 type 为 asset_type
    let create_sql: String = conn.query_row(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name='assets'",
        [],
        |row| row.get(0),
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    eprintln!("原表 CREATE SQL: {}", create_sql);

    // 替换表名和列名
    let new_create_sql = create_sql
        .replace("CREATE TABLE assets", "CREATE TABLE assets_new")
        .replace("type TEXT NOT NULL", "asset_type TEXT NOT NULL")
        .replace(",type TEXT,", ",asset_type TEXT,")
        .replace(", type TEXT NOT NULL,", ", asset_type TEXT NOT NULL,");

    eprintln!("新表 CREATE SQL: {}", new_create_sql);

    // 2. 创建新表
    conn.execute(&new_create_sql, [])
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

    // 3. 复制数据（将 type 映射到 asset_type）
    // 构建列列表（type 改为 asset_type）
    let columns_list = existing_columns.iter()
        .map(|c| if c == "type" { "asset_type".to_string() } else { c.clone() })
        .collect::<Vec<_>>()
        .join(", ");

    let source_columns = existing_columns.iter()
        .map(|c| if c == "type" { "type as asset_type".to_string() } else { c.clone() })
        .collect::<Vec<_>>()
        .join(", ");

    let copy_sql = format!(
        "INSERT INTO assets_new ({}) SELECT {} FROM assets",
        columns_list, source_columns
    );

    eprintln!("复制数据 SQL: {}", copy_sql);

    conn.execute(&copy_sql, [])
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

    // 4. 删除旧表
    conn.execute("DROP TABLE assets", [])
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

    // 5. 重命名新表
    conn.execute("ALTER TABLE assets_new RENAME TO assets", [])
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

    // 6. 重建索引
    // 删除旧索引（如果存在）
    let _ = conn.execute("DROP INDEX IF EXISTS idx_assets_type", []);
    let _ = conn.execute("DROP INDEX IF EXISTS idx_assets_created_at", []);

    // 创建新索引
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_assets_type ON assets(asset_type)",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_assets_created_at ON assets(created_at)",
        [],
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    eprintln!("========== 完成数据库迁移 v7 ==========");
    Ok(())
}

/// 强制检查并添加 buy_price 和 current_price 列
/// 无论数据库版本如何，都确保这两个列存在
fn ensure_price_columns_exist(conn: &Connection) -> Result<(), DbError> {
    eprintln!("========== 强制检查 buy_price 和 current_price 列 ==========");

    let mut stmt = conn.prepare("PRAGMA table_info(assets)")
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

    let rows = stmt.query_map([], |row| {
        let col_name: String = row.get(1).unwrap_or_default();
        Ok(col_name)
    }).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    let mut has_buy_price = false;
    let mut has_current_price = false;

    for row in rows {
        let col_name = row.map_err(|e| DbError::DatabaseError(e.to_string()))?;
        if col_name == "buy_price" {
            has_buy_price = true;
        } else if col_name == "current_price" {
            has_current_price = true;
        }
    }

    eprintln!("has_buy_price = {}, has_current_price = {}", has_buy_price, has_current_price);

    // 添加 buy_price 列（如果不存在）
    if !has_buy_price {
        eprintln!("强制添加 buy_price 列...");
        match conn.execute(
            "ALTER TABLE assets ADD COLUMN buy_price REAL",
            [],
        ) {
            Ok(_) => eprintln!("已添加 buy_price 列"),
            Err(e) => {
                eprintln!("添加 buy_price 列失败: {}", e);
            }
        }
    }

    // 添加 current_price 列（如果不存在）
    if !has_current_price {
        eprintln!("强制添加 current_price 列...");
        match conn.execute(
            "ALTER TABLE assets ADD COLUMN current_price REAL",
            [],
        ) {
            Ok(_) => eprintln!("已添加 current_price 列"),
            Err(e) => {
                eprintln!("添加 current_price 列失败: {}", e);
            }
        }
    }

    eprintln!("========== 完成强制检查 ==========");
    Ok(())
}

/// 初始化数据库（创建表结构并执行迁移）
pub fn init_db(conn: &Connection) -> Result<(), DbError> {
    create_schema(conn)?;

    // 运行版本迁移
    let version = get_schema_version(conn)?;

    // 强制检查并添加 buy_price 和 current_price 列（无论版本如何）
    ensure_price_columns_exist(conn)?;

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

    if version < 6 {
        migrate_v6_add_extended_fields(conn)?;
        set_schema_version(conn, 6)?;
    }

    if version < 7 {
        migrate_v7_rename_type_to_asset_type(conn)?;
        set_schema_version(conn, 7)?;
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

/// 清空数据库中的所有数据（用于重置应用）
///
/// 此函数会删除所有表中的数据，但保留表结构
/// 即使文件因锁定无法删除，也可以确保数据被清除
pub fn wipe_db(conn: &Connection) -> Result<(), DbError> {
    eprintln!("开始清空数据库数据...");

    // 获取所有表名
    let mut tables = conn.prepare(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

    let table_names: Vec<String> = tables.query_map([], |row| {
        let name: String = row.get(0)?;
        Ok(name)
    }).map_err(|e| DbError::DatabaseError(e.to_string()))?
    .filter_map(|r| r.ok())
    .collect();

    eprintln!("找到表: {:?}", table_names);

    // 对每个表执行 DELETE
    for table in &table_names {
        if table == "sqlite_sequence" {
            continue;
        }

        match conn.execute(&format!("DELETE FROM {}", table), []) {
            Ok(rows_affected) => {
                eprintln!("清空表 {}: {} 行", table, rows_affected);
            }
            Err(e) => {
                eprintln!("清空表 {} 失败: {}", table, e);
            }
        }

        // 重置自增序列
        let _ = conn.execute(&format!("DELETE FROM sqlite_sequence WHERE name='{}'", table), []);
    }

    eprintln!("数据库数据清空完成");
    Ok(())
}
