//! 净资产快照 CRUD

use chrono::Local;
use rusqlite::{params, Connection};

use super::{DbError, DbResult};
use super::models::NetWorthSnapshot;

pub struct NetWorthSnapshotRepository;

impl NetWorthSnapshotRepository {
    /// 记录/更新当日快照（同日覆盖，net_worth = total_assets - total_liabilities）
    pub fn upsert_today(
        conn: &Connection,
        total_assets: f64,
        total_liabilities: f64,
    ) -> DbResult<NetWorthSnapshot> {
        let date = Local::now().format("%Y-%m-%d").to_string();
        let recorded_at = Local::now().timestamp();
        let net_worth = total_assets - total_liabilities;

        conn.execute(
            "INSERT OR REPLACE INTO net_worth_snapshots
                (date, total_assets, total_liabilities, net_worth, recorded_at)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            params![date, total_assets, total_liabilities, net_worth, recorded_at],
        )
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(NetWorthSnapshot {
            date,
            total_assets,
            total_liabilities,
            net_worth,
            recorded_at,
        })
    }

    /// 按日期升序列出全部快照
    pub fn list(conn: &Connection) -> DbResult<Vec<NetWorthSnapshot>> {
        let mut stmt = conn
            .prepare(
                "SELECT date, total_assets, total_liabilities, net_worth, recorded_at
                 FROM net_worth_snapshots ORDER BY date ASC",
            )
            .map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let rows = stmt
            .query_map([], |row| {
                Ok(NetWorthSnapshot {
                    date: row.get(0)?,
                    total_assets: row.get(1)?,
                    total_liabilities: row.get(2)?,
                    net_worth: row.get(3)?,
                    recorded_at: row.get(4)?,
                })
            })
            .map_err(|e| DbError::DatabaseError(e.to_string()))?;

        rows.collect::<Result<Vec<_>, _>>()
            .map_err(|e| DbError::DatabaseError(e.to_string()))
    }
}
