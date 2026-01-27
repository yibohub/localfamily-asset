use rusqlite::Connection;

fn main() {
    let db_path = r"C:\Users\86131\Documents\localfamily_asset.db";
    let conn = Connection::open(db_path).expect("无法打开数据库");
    
    println!("开始更新负债类型...");
    
    // 将 type='debt' 的记录更新为更具体的类型
    let mut stmt = conn.prepare("SELECT id, name, type FROM assets WHERE type = 'debt'").unwrap();
    
    let debts = stmt.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, String>(2)?,
        ))
    }).unwrap().collect::<Result<Vec<_>, _>>().unwrap();
    
    for (id, name, _current_type) in debts {
        let new_type = infer_debt_type(&name);
        let updated_at = chrono::Utc::now().timestamp().to_string();
        
        conn.execute(
            "UPDATE assets SET type = ?1, updated_at = ?2 WHERE id = ?3",
            &[&new_type as &str, &updated_at as &str, &id as &str],
        ).expect("更新失败");
        
        println!("  [{}] {} -> {}", id.chars().take(8).collect::<String>(), name, new_type);
        
        // 记录审计日志
        let change_id = uuid::Uuid::new_v4().to_string();
        let changed_at = chrono::Utc::now().timestamp().to_string();
        
        conn.execute(
            "INSERT INTO asset_changes (id, asset_id, change_type, changed_field, name_old, name_new, changed_at)
             VALUES (?1, ?2, 'updated', 'type', ?3, ?4, ?5)",
            [&change_id as &str, &id as &str, &name as &str, &new_type as &str, &changed_at as &str],
        ).expect("插入审计日志失败");
    }
    
    println!("\n更新完成！");
}

fn infer_debt_type(name: &str) -> &'static str {
    if name.contains("房贷") || name.contains("房屋") {
        "mortgage"
    } else if name.contains("车贷") || name.contains("汽车") {
        "car_loan"
    } else if name.contains("信用卡") {
        "credit_card"
    } else if name.contains("个人贷") {
        "personal_loan"
    } else if name.contains("私人") {
        "private_loan"
    } else {
        "debt"  // 默认保留为通用负债
    }
}
