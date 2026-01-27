use rusqlite::Connection;

fn main() {
    let db_path = r"C:\Users\86131\Documents\localfamily_asset.db";
    if let Ok(conn) = Connection::open(db_path) {
        // 检查 settings 表内容
        if let Ok(mut stmt) = conn.prepare("SELECT key, value FROM settings") {
            println!("=== Settings 表内容 ===");
            if let Ok(rows) = stmt.query_map([], |row| {
                let key: String = row.get(0)?;
                let value: String = row.get(1)?;
                Ok((key, value))
            }) {
                for row in rows {
                    if let Ok((key, value)) = row {
                        println!("  {}: {}", key, value);
                    }
                }
            }
        }
        
        // 检查 schema_version
        if let Ok(version) = conn.query_row("SELECT value FROM settings WHERE key = 'schema_version'", [], |row| {
            let version: String = row.get(0)?;
            Ok(version)
        }) {
            println!("\n当前 schema 版本: {}", version);
        } else {
            println!("\nschema_version 不存在，将被视为版本 1");
        }
    }
}
