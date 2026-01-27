use rusqlite::Connection;

fn main() {
    let db_path = r"C:\Users\86131\Documents\localfamily_asset.db";
    let conn = Connection::open(db_path).expect("无法打开数据库");
    
    println!("开始手动迁移数据库...");
    
    // 1. 检查 buy_date 列是否存在
    let mut check_stmt = conn.prepare("PRAGMA table_info(assets)").unwrap();
    let columns = check_stmt.query_map([], |row| {
        let name: String = row.get(1)?;
        Ok(name)
    }).unwrap();
    
    let mut has_buy_date = false;
    let mut has_occurrence_date = false;
    
    for col in columns {
        if let Ok(name) = col {
            if name == "buy_date" {
                has_buy_date = true;
            } else if name == "occurrence_date" {
                has_occurrence_date = true;
            }
        }
    }
    
    println!("  has_buy_date: {}, has_occurrence_date: {}", has_buy_date, has_occurrence_date);
    
    if has_occurrence_date {
        println!("  occurrence_date 列已存在，跳过迁移");
        return;
    }
    
    if !has_buy_date {
        println!("  buy_date 列不存在，无需迁移");
        return;
    }
    
    // 2. 回填空值
    let today = chrono::Utc::now().format("%Y-%m-%d").to_string();
    println!("  回填空值为: {}", today);
    conn.execute(
        "UPDATE assets SET buy_date = ?1 WHERE buy_date IS NULL",
        [&today],
    ).expect("回填失败");
    
    // 3. 创建新表
    println!("  创建新表 assets_new...");
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
    ).expect("创建新表失败");
    
    // 4. 复制数据
    println!("  复制数据...");
    conn.execute(
        "INSERT INTO assets_new
         SELECT id, type, name, amount, currency, account, buy_date, buy_price, current_price, note, tags, created_at, updated_at
         FROM assets",
        [],
    ).expect("复制数据失败");
    
    // 5. 删除旧表并重命名
    println!("  删除旧表并重命名...");
    conn.execute("DROP TABLE assets", []).expect("删除旧表失败");
    conn.execute("ALTER TABLE assets_new RENAME TO assets", []).expect("重命名失败");
    
    // 6. 创建审计日志表
    println!("  创建审计日志表...");
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
    ).expect("创建审计日志表失败");
    
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_asset_changes_asset_id ON asset_changes(asset_id)",
        [],
    ).expect("创建索引失败");
    
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_asset_changes_changed_at ON asset_changes(changed_at)",
        [],
    ).expect("创建索引失败");
    
    // 7. 更新 schema 版本
    println!("  更新 schema 版本...");
    conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES ('schema_version', '3')",
        [],
    ).expect("更新版本失败");
    
    // 8. 验证数据
    let count: i64 = conn.query_row("SELECT COUNT(*) FROM assets", [], |row| row.get(0)).unwrap();
    println!("\n迁移完成！资产数量: {}", count);
}
