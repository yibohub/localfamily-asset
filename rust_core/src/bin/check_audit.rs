use rusqlite::Connection;

fn main() {
    let db_path = r"C:\Users\86131\Documents\localfamily_asset.db";
    let conn = Connection::open(db_path).expect("无法打开数据库");
    
    // 检查审计日志数量
    let count: i64 = conn.query_row("SELECT COUNT(*) FROM asset_changes", [], |row| row.get(0)).unwrap();
    println!("=== 审计日志统计 ===");
    println!("总记录数: {}", count);
    
    // 显示最近的审计日志
    let mut stmt = conn.prepare(
        "SELECT asset_id, change_type, name_new, amount_new, changed_at 
         FROM asset_changes 
         ORDER BY changed_at DESC 
         LIMIT 10"
    ).unwrap();
    
    println!("\n=== 最近 10 条审计日志 ===");
    let logs = stmt.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,  // asset_id
            row.get::<_, String>(1)?,  // change_type
            row.get::<_, Option<String>>(2)?,  // name_new
            row.get::<_, Option<f64>>(3)?,   // amount_new
            row.get::<_, i64>(4)?,     // changed_at
        ))
    }).unwrap();
    
    for log in logs {
        if let Ok((asset_id, change_type, name_new, amount_new, changed_at)) = log {
            let time = chrono::DateTime::from_timestamp(changed_at, 0)
                .map(|dt| dt.format("%Y-%m-%d %H:%M:%S").to_string())
                .unwrap_or_default();
            
            let amount = amount_new.map(|a| a.to_string()).unwrap_or("N/A".to_string());
            
            println!("  [{}] {} - {} - ¥{} ({})", 
                asset_id.chars().take(8).collect::<String>(),
                change_type,
                name_new.unwrap_or_default(),
                amount,
                time
            );
        }
    }
}
