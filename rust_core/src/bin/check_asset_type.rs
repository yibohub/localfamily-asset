use rusqlite::Connection;

fn main() {
    let db_path = r"C:\Users\86131\Documents\localfamily_asset.db";
    let conn = Connection::open(db_path).expect("无法打开数据库");
    
    // 查询所有资产及其类型
    let mut stmt = conn.prepare(
        "SELECT id, name, type FROM assets ORDER BY created_at DESC"
    ).unwrap();
    
    println!("=== 当前资产及其类型 ===");
    let assets = stmt.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, String>(2)?,
        ))
    }).unwrap();
    
    for asset in assets {
        if let Ok((id, name, asset_type)) = asset {
            println!("  [{}] {} - {}", id.chars().take(8).collect::<String>(), name, asset_type);
        }
    }
}
