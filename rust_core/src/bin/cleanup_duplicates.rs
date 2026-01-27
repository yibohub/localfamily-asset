use rusqlite::Connection;

fn main() {
    let db_path = r"C:\Users\86131\Documents\localfamily_asset.db";
    let conn = Connection::open(db_path).expect("无法打开数据库");
    
    println!("开始清理重复的审计日志...");
    
    // 找出重复的记录（保留最早的，删除其他的）
    conn.execute(
        "DELETE FROM asset_changes 
         WHERE id NOT IN (
             SELECT MIN(id) FROM asset_changes 
             GROUP BY asset_id, change_type, changed_at, name_new, amount_new
         )",
        [],
    ).expect("删除失败");
    
    // 检查剩余记录数
    let count: i64 = conn.query_row("SELECT COUNT(*) FROM asset_changes", [], |row| row.get(0)).unwrap();
    println!("\n清理完成！剩余记录数: {}", count);
    
    // 显示剩余记录
    let mut stmt = conn.prepare(
        "SELECT change_type, name_new, amount_new, changed_at 
         FROM asset_changes 
         ORDER BY changed_at DESC"
    ).unwrap();
    
    println!("\n=== 剩余的审计日志 ===");
    let logs = stmt.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, Option<String>>(1)?,
            row.get::<_, Option<f64>>(2)?,
            row.get::<_, i64>(3)?,
        ))
    }).unwrap();
    
    for log in logs {
        if let Ok((change_type, name_new, amount_new, changed_at)) = log {
            let time = chrono::DateTime::from_timestamp(changed_at, 0)
                .map(|dt| dt.format("%Y-%m-%d %H:%M:%S").to_string())
                .unwrap_or_default();
            
            let amount = amount_new.map(|a| a.to_string()).unwrap_or("N/A".to_string());
            
            println!("  {} - {} - ¥{} ({})", 
                change_type,
                name_new.unwrap_or_default(),
                amount,
                time
            );
        }
    }
}
