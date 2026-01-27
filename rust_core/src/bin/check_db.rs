use rusqlite::Connection;

fn main() {
    let db_path = r"C:\Users\86131\Documents\localfamily_asset.db";
    if let Ok(conn) = Connection::open(db_path) {
        // 检查表是否存在
        let mut stmt = conn.prepare("SELECT name FROM sqlite_master WHERE type='table'").unwrap();
        let tables = stmt.query_map([], |row| {
            let name: String = row.get(0)?;
            Ok(name)
        }).unwrap();
        
        println!("=== 数据库表 ===");
        for table in tables {
            if let Ok(name) = table {
                println!("  - {}", name);
            }
        }
        
        // 检查资产数量
        if let Ok(count) = conn.query_row("SELECT COUNT(*) FROM assets", [], |row| {
            let count: i64 = row.get(0)?;
            Ok(count)
        }) {
            println!("\n=== 资产数量 ===");
            println!("  总计: {}", count);
        }
        
        // 检查表结构
        if let Ok(mut stmt) = conn.prepare("PRAGMA table_info(assets)") {
            println!("\n=== assets 表结构 ===");
            let columns = stmt.query_map([], |row| {
                let name: String = row.get(1)?;
                let type_name: String = row.get(2)?;
                let not_null: i32 = row.get(3)?;
                Ok((name, type_name, not_null))
            }).unwrap();
            
            for col in columns {
                if let Ok((name, type_name, not_null)) = col {
                    println!("  - {}: {} {}", name, type_name, if not_null == 1 { "NOT NULL" } else { "" });
                }
            }
        }
        
        // 检查一些示例数据
        if let Ok(mut stmt) = conn.prepare("SELECT id, name, amount, type FROM assets LIMIT 5") {
            println!("\n=== 示例数据 ===");
            if let Ok(rows) = stmt.query_map([], |row| {
                let id: String = row.get(0)?;
                let name: String = row.get(1)?;
                let amount: f64 = row.get(2)?;
                let asset_type: String = row.get(3)?;
                Ok((id, name, amount, asset_type))
            }) {
                for row in rows {
                    if let Ok((id, name, amount, asset_type)) = row {
                        println!("  [{}] {} - {} ({})", id, name, amount, asset_type);
                    }
                }
            }
        }
    } else {
        println!("无法打开数据库");
    }
}
