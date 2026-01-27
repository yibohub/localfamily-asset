use rusqlite::Connection;
use uuid::Uuid;

fn main() {
    let db_path = r"C:\Users\86131\Documents\localfamily_asset.db";
    let conn = Connection::open(db_path).expect("无法打开数据库");
    
    println!("开始为现有资产补充审计日志...");
    
    // 获取所有现有资产
    let mut stmt = conn.prepare(
        "SELECT id, type, name, amount, currency, account, occurrence_date, 
                buy_price, current_price, note, tags, created_at, updated_at 
         FROM assets"
    ).unwrap();
    
    let assets = stmt.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,  // id
            row.get::<_, String>(1)?,  // type
            row.get::<_, String>(2)?,  // name
            row.get::<_, f64>(3)?,     // amount
            row.get::<_, String>(4)?,  // currency
            row.get::<_, Option<String>>(5)?,  // account
            row.get::<_, String>(6)?,  // occurrence_date
            row.get::<_, Option<f64>>(7)?,   // buy_price
            row.get::<_, Option<f64>>(8)?,   // current_price
            row.get::<_, Option<String>>(9)?, // note
            row.get::<_, Option<String>>(10)?, // tags
            row.get::<_, i64>(11)?,    // created_at
            row.get::<_, i64>(12)?,    // updated_at
        ))
    }).unwrap();
    
    let mut count = 0;
    for asset in assets {
        if let Ok((
            id, asset_type, name, amount, currency, account, occurrence_date,
            buy_price, current_price, note, tags, created_at, updated_at
        )) = asset {
            // 创建审计日志记录
            let change_id = Uuid::new_v4().to_string();
            let created_at_str = created_at.to_string();
            
            // 构建数据快照
            let snapshot = format!(r#"{{"id":"{}","type":"{}","name":"{}","amount":{},"currency":"{}","account":{},"occurrenceDate":"{}","buy_price":{},"current_price":{},"note":{},"tags":{},"created_at":{},"updated_at":{}}}"#,
                id, asset_type, name, amount, currency,
                account.as_ref().map(|s| format!("\"{}\"", s)).unwrap_or("null".to_string()),
                occurrence_date,
                buy_price.map(|v| v.to_string()).unwrap_or("null".to_string()),
                current_price.map(|v| v.to_string()).unwrap_or("null".to_string()),
                note.as_ref().map(|s| format!("\"{}\"", s)).unwrap_or("null".to_string()),
                tags.as_ref().map(|s| format!("\"{}\"", s)).unwrap_or("null".to_string()),
                created_at, updated_at
            );
            
            conn.execute(
                "INSERT INTO asset_changes (id, asset_id, change_type, name_new, amount_new, 
                 occurrence_date_new, data_snapshot_new, changed_at)
                 VALUES (?1, ?2, 'created', ?3, ?4, ?5, ?6, ?7)",
                [
                    &change_id as &str,
                    &id as &str,
                    &name as &str,
                    &amount.to_string() as &str,
                    &occurrence_date as &str,
                    &snapshot as &str,
                    &created_at_str as &str,
                ],
            ).expect("插入审计日志失败");
            
            count += 1;
            println!("  [{}] 为资产 \"{}\" 创建审计日志", count, name);
        }
    }
    
    println!("\n完成！为 {} 条资产补充了审计日志", count);
}
