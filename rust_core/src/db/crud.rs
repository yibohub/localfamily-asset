//! 数据库 CRUD 操作

use rusqlite::{Connection, params};

use super::{DbError, DbResult};
use super::models::{Asset, AssetHistory, Attachment, AssetType};

/// 资产仓库
pub struct AssetRepository;

impl AssetRepository {
    /// 创建资产
    pub fn create(conn: &Connection, asset: &Asset) -> DbResult<String> {
        let tags_json = asset.tags.as_ref()
            .map(|t| serde_json::to_string(t).ok())
            .flatten();

        conn.execute(
            "INSERT INTO assets (id, type, name, amount, currency, account, buy_date, buy_price, current_price, note, tags, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)",
            params![
                asset.id,
                asset.asset_type.as_str(),
                asset.name,
                asset.amount,
                asset.currency,
                asset.account,
                asset.buy_date,
                asset.buy_price,
                asset.current_price,
                asset.note,
                tags_json,
                asset.created_at,
                asset.updated_at,
            ],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(asset.id.clone())
    }

    /// 获取单个资产
    pub fn get(conn: &Connection, id: &str) -> DbResult<Asset> {
        let mut stmt = conn.prepare(
            "SELECT id, type, name, amount, currency, account, buy_date, buy_price, current_price, note, tags, created_at, updated_at
             FROM assets WHERE id = ?1"
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let asset = stmt.query_row(params![id], |row| {
            let asset_type_str: String = row.get(1)?;
            let asset_type = AssetType::from_str(&asset_type_str)
                .ok_or_else(|| rusqlite::Error::InvalidQuery)?;

            let tags_json: Option<String> = row.get(10)?;
            let tags = tags_json.and_then(|j| serde_json::from_str(&j).ok());

            Ok(Asset {
                id: row.get(0)?,
                asset_type,
                name: row.get(2)?,
                amount: row.get(3)?,
                currency: row.get(4)?,
                account: row.get(5)?,
                buy_date: row.get(6)?,
                buy_price: row.get(7)?,
                current_price: row.get(8)?,
                note: row.get(9)?,
                tags,
                created_at: row.get(11)?,
                updated_at: row.get(12)?,
            })
        }).map_err(|e| match e {
            rusqlite::Error::QueryReturnedNoRows => DbError::NotFound(id.to_string()),
            _ => DbError::DatabaseError(e.to_string()),
        })?;

        Ok(asset)
    }

    /// 获取所有资产
    pub fn list(conn: &Connection) -> DbResult<Vec<Asset>> {
        let mut stmt = conn.prepare(
            "SELECT id, type, name, amount, currency, account, buy_date, buy_price, current_price, note, tags, created_at, updated_at
             FROM assets ORDER BY created_at DESC"
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let assets = stmt.query_map([], |row| {
            let asset_type_str: String = row.get(1)?;
            let asset_type = AssetType::from_str(&asset_type_str)
                .ok_or_else(|| rusqlite::Error::InvalidQuery)?;

            let tags_json: Option<String> = row.get(10)?;
            let tags = tags_json.and_then(|j| serde_json::from_str(&j).ok());

            Ok(Asset {
                id: row.get(0)?,
                asset_type,
                name: row.get(2)?,
                amount: row.get(3)?,
                currency: row.get(4)?,
                account: row.get(5)?,
                buy_date: row.get(6)?,
                buy_price: row.get(7)?,
                current_price: row.get(8)?,
                note: row.get(9)?,
                tags,
                created_at: row.get(11)?,
                updated_at: row.get(12)?,
            })
        }).map_err(|e| DbError::DatabaseError(e.to_string()))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(assets)
    }

    /// 更新资产
    pub fn update(conn: &Connection, asset: &Asset) -> DbResult<()> {
        let tags_json = asset.tags.as_ref()
            .map(|t| serde_json::to_string(t).ok())
            .flatten();
        let updated_at = chrono::Utc::now().timestamp();

        conn.execute(
            "UPDATE assets SET type = ?1, name = ?2, amount = ?3, currency = ?4, account = ?5,
             buy_date = ?6, buy_price = ?7, current_price = ?8, note = ?9, tags = ?10, updated_at = ?11
             WHERE id = ?12",
            params![
                asset.asset_type.as_str(),
                asset.name,
                asset.amount,
                asset.currency,
                asset.account,
                asset.buy_date,
                asset.buy_price,
                asset.current_price,
                asset.note,
                tags_json,
                updated_at,
                asset.id,
            ],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(())
    }

    /// 删除资产
    pub fn delete(conn: &Connection, id: &str) -> DbResult<()> {
        let rows_affected = conn.execute(
            "DELETE FROM assets WHERE id = ?1",
            params![id],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        if rows_affected == 0 {
            return Err(DbError::NotFound(id.to_string()));
        }

        Ok(())
    }

    /// 按类型获取资产
    pub fn list_by_type(conn: &Connection, asset_type: AssetType) -> DbResult<Vec<Asset>> {
        let mut stmt = conn.prepare(
            "SELECT id, type, name, amount, currency, account, buy_date, buy_price, current_price, note, tags, created_at, updated_at
             FROM assets WHERE type = ?1 ORDER BY created_at DESC"
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let assets = stmt.query_map(params![asset_type.as_str()], |row| {
            let asset_type_str: String = row.get(1)?;
            let asset_type = AssetType::from_str(&asset_type_str)
                .ok_or_else(|| rusqlite::Error::InvalidQuery)?;

            let tags_json: Option<String> = row.get(10)?;
            let tags = tags_json.and_then(|j| serde_json::from_str(&j).ok());

            Ok(Asset {
                id: row.get(0)?,
                asset_type,
                name: row.get(2)?,
                amount: row.get(3)?,
                currency: row.get(4)?,
                account: row.get(5)?,
                buy_date: row.get(6)?,
                buy_price: row.get(7)?,
                current_price: row.get(8)?,
                note: row.get(9)?,
                tags,
                created_at: row.get(11)?,
                updated_at: row.get(12)?,
            })
        }).map_err(|e| DbError::DatabaseError(e.to_string()))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(assets)
    }
}

/// 历史价格仓库
pub struct HistoryRepository;

impl HistoryRepository {
    pub fn create(conn: &Connection, history: &AssetHistory) -> DbResult<String> {
        conn.execute(
            "INSERT INTO asset_history (id, asset_id, price, recorded_at)
             VALUES (?1, ?2, ?3, ?4)",
            params![
                history.id,
                history.asset_id,
                history.price,
                history.recorded_at,
            ],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(history.id.clone())
    }

    pub fn list_by_asset(conn: &Connection, asset_id: &str) -> DbResult<Vec<AssetHistory>> {
        let mut stmt = conn.prepare(
            "SELECT id, asset_id, price, recorded_at
             FROM asset_history WHERE asset_id = ?1 ORDER BY recorded_at DESC"
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let histories = stmt.query_map(params![asset_id], |row| {
            Ok(AssetHistory {
                id: row.get(0)?,
                asset_id: row.get(1)?,
                price: row.get(2)?,
                recorded_at: row.get(3)?,
            })
        }).map_err(|e| DbError::DatabaseError(e.to_string()))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(histories)
    }
}

/// 附件仓库
pub struct AttachmentRepository;

impl AttachmentRepository {
    pub fn create(conn: &Connection, attachment: &Attachment) -> DbResult<String> {
        conn.execute(
            "INSERT INTO attachments (id, asset_id, file_name, file_size, encrypted_path, mime_type, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                attachment.id,
                attachment.asset_id,
                attachment.file_name,
                attachment.file_size,
                attachment.encrypted_path,
                attachment.mime_type,
                attachment.created_at,
            ],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(attachment.id.clone())
    }

    pub fn list_by_asset(conn: &Connection, asset_id: &str) -> DbResult<Vec<Attachment>> {
        let mut stmt = conn.prepare(
            "SELECT id, asset_id, file_name, file_size, encrypted_path, mime_type, created_at
             FROM attachments WHERE asset_id = ?1 ORDER BY created_at DESC"
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let attachments = stmt.query_map(params![asset_id], |row| {
            Ok(Attachment {
                id: row.get(0)?,
                asset_id: row.get(1)?,
                file_name: row.get(2)?,
                file_size: row.get(3)?,
                encrypted_path: row.get(4)?,
                mime_type: row.get(5)?,
                created_at: row.get(6)?,
            })
        }).map_err(|e| DbError::DatabaseError(e.to_string()))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(attachments)
    }

    pub fn delete(conn: &Connection, id: &str) -> DbResult<()> {
        conn.execute(
            "DELETE FROM attachments WHERE id = ?1",
            params![id],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(())
    }
}
