use rusqlite::Connection;

fn main() {
    let db_path = r"C:\Users\86131\Documents\localfamily_asset.db";
    let conn = Connection::open(db_path).expect("无法打开数据库");
    
    // 测试获取审计日志（模拟 FFI 函数的行为）
    let mut stmt = conn.prepare(
        "SELECT id, asset_id, change_type, occurrence_date_old, occurrence_date_new,
                amount_old, amount_new, name_old, name_new, data_snapshot_old, 
                data_snapshot_new, changed_field, changed_at
         FROM asset_changes
         ORDER BY changed_at DESC
         LIMIT 100"
    ).unwrap();
    
    let changes = stmt.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,   // id
            row.get::<_, String>(1)?,   // asset_id
            row.get::<_, String>(2)?,   // change_type
            row.get::<_, Option<String>>(3)?,  // occurrence_date_old
            row.get::<_, Option<String>>(4)?,  // occurrence_date_new
            row.get::<_, Option<f64>>(5)?,     // amount_old
            row.get::<_, Option<f64>>(6)?,     // amount_new
            row.get::<_, Option<String>>(7)?,  // name_old
            row.get::<_, Option<String>>(8)?,  // name_new
            row.get::<_, Option<String>>(9)?,  // data_snapshot_old
            row.get::<_, Option<String>>(10)?, // data_snapshot_new
            row.get::<_, Option<String>>(11)?, // changed_field
            row.get::<_, i64>(12)?,     // changed_at
        ))
    }).unwrap().collect::<Result<Vec<_>, _>>().unwrap();
    
    println!("=== 审计日志数据（JSON格式） ===");
    
    // 转换为 JSON 格式（模拟 FFI 返回）
    for change in &changes {
        let json = serde_json::json!({
            "id": change.0,
            "asset_id": change.1,
            "change_type": change.2,
            "occurrence_date_old": change.3,
            "occurrence_date_new": change.4,
            "amount_old": change.5,
            "amount_new": change.6,
            "name_old": change.7,
            "name_new": change.8,
            "data_snapshot_old": change.9,
            "data_snapshot_new": change.10,
            "changed_field": change.11,
            "changed_at": change.12,
        });
        println!("{}", json);
    }
    
    println!("\n共 {} 条记录", changes.len());
}
