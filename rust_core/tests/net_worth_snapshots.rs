//! 净资产快照 CRUD 集成测试

use localfamily_asset_core::db::{init_db, NetWorthSnapshotRepository};
use rusqlite::Connection;

fn setup_db() -> Connection {
    let conn = Connection::open_in_memory().unwrap();
    init_db(&conn).unwrap();
    conn
}

#[test]
fn upsert_creates_and_updates_same_day() {
    let conn = setup_db();

    let first = NetWorthSnapshotRepository::upsert_today(&conn, 1000.0, 200.0).unwrap();
    assert_eq!(first.total_assets, 1000.0);
    assert_eq!(first.total_liabilities, 200.0);
    assert_eq!(first.net_worth, 800.0);
    assert_eq!(first.date.len(), 10); // YYYY-MM-DD

    // 同日再次记录应覆盖而非新增
    let second = NetWorthSnapshotRepository::upsert_today(&conn, 1500.0, 300.0).unwrap();
    assert_eq!(second.net_worth, 1200.0);

    let all = NetWorthSnapshotRepository::list(&conn).unwrap();
    assert_eq!(all.len(), 1, "同日快照应去重为一条");
    assert_eq!(all[0].net_worth, 1200.0);
}

#[test]
fn list_returns_snapshots_in_date_order() {
    let conn = setup_db();

    NetWorthSnapshotRepository::upsert_today(&conn, 1000.0, 0.0).unwrap();

    // 手工插入一条更早日期的快照，验证排序
    conn.execute(
        "INSERT INTO net_worth_snapshots (date, total_assets, total_liabilities, net_worth, recorded_at)
         VALUES ('2026-01-01', 500.0, 100.0, 400.0, 0)",
        [],
    )
    .unwrap();

    let all = NetWorthSnapshotRepository::list(&conn).unwrap();
    assert_eq!(all.len(), 2);
    assert_eq!(all[0].date, "2026-01-01", "应按日期升序");
    assert!(all[1].date > all[0].date);
}

#[test]
fn snapshots_survive_reinit() {
    // 模拟重启：同一连接上重新 init_db（幂等建表），快照仍在
    let conn = setup_db();
    NetWorthSnapshotRepository::upsert_today(&conn, 100.0, 0.0).unwrap();

    init_db(&conn).unwrap();
    let all = NetWorthSnapshotRepository::list(&conn).unwrap();
    assert_eq!(all.len(), 1);
}
