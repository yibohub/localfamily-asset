//! 数据库 CRUD 操作

use rusqlite::{Connection, params};

use super::{DbError, DbResult};
use super::models::{Asset, AssetHistory, Attachment, AssetType, AssetChange, ChangeType};

/// 资产仓库
pub struct AssetRepository;

impl AssetRepository {
    /// 创建资产
    pub fn create(conn: &Connection, asset: &Asset) -> DbResult<String> {
        eprintln!("===== AssetRepository::create 开始 =====");
        eprintln!("资产 ID: {}", asset.id);
        eprintln!("资产名称: {}", asset.name);
        eprintln!("买入价: {:?}", asset.buy_price);
        eprintln!("现价: {:?}", asset.current_price);

        let tags_json = asset.tags.as_ref()
            .map(|t| serde_json::to_string(t).ok())
            .flatten();

        // 使用命名参数，显式指定类型
        conn.execute(
            "INSERT INTO assets (id, type, name, amount, currency, account, occurrence_date, buy_price, current_price, note, tags, created_at, updated_at)
             VALUES (:id, :type, :name, :amount, :currency, :account, :occurrence_date, :buy_price, :current_price, :note, :tags, :created_at, :updated_at)",
            &[
                (":id", &asset.id as &dyn rusqlite::ToSql),
                (":type", &asset.asset_type as &dyn rusqlite::ToSql),
                (":name", &asset.name as &dyn rusqlite::ToSql),
                (":amount", &asset.amount as &dyn rusqlite::ToSql),
                (":currency", &asset.currency as &dyn rusqlite::ToSql),
                (":account", &asset.account as &dyn rusqlite::ToSql),
                (":occurrence_date", &asset.occurrence_date as &dyn rusqlite::ToSql),
                (":buy_price", &asset.buy_price as &dyn rusqlite::ToSql),
                (":current_price", &asset.current_price as &dyn rusqlite::ToSql),
                (":note", &asset.note as &dyn rusqlite::ToSql),
                (":tags", &tags_json as &dyn rusqlite::ToSql),
                (":created_at", &asset.created_at as &dyn rusqlite::ToSql),
                (":updated_at", &asset.updated_at as &dyn rusqlite::ToSql),
            ],
        ).map_err(|e| {
            eprintln!("插入失败: {}", e);
            DbError::DatabaseError(e.to_string())
        })?;

        eprintln!("插入成功");
        Ok(asset.id.clone())
    }

    /// 获取单个资产
    pub fn get(conn: &Connection, id: &str) -> DbResult<Asset> {
        let mut stmt = conn.prepare(
            "SELECT id, type, name, amount, currency, account, occurrence_date, buy_price, current_price, note, tags, created_at, updated_at
             FROM assets WHERE id = ?1"
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let asset = stmt.query_row(params![id], |row| {
            let asset_type: String = row.get(1)?;

            let tags_json: Option<String> = row.get(10)?;
            let tags = tags_json.and_then(|j| serde_json::from_str(&j).ok());

            Ok(Asset {
                id: row.get(0)?,
                asset_type,
                name: row.get(2)?,
                amount: row.get(3)?,
                currency: row.get(4)?,
                account: row.get(5)?,
                occurrence_date: row.get(6)?,
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
            "SELECT id, type, name, amount, currency, account, occurrence_date, buy_price, current_price, note, tags, created_at, updated_at
             FROM assets ORDER BY created_at DESC"
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let assets = stmt.query_map([], |row| {
            let asset_type: String = row.get(1)?;

            let tags_json: Option<String> = row.get(10)?;
            let tags = tags_json.and_then(|j| serde_json::from_str(&j).ok());

            Ok(Asset {
                id: row.get(0)?,
                asset_type,
                name: row.get(2)?,
                amount: row.get(3)?,
                currency: row.get(4)?,
                account: row.get(5)?,
                occurrence_date: row.get(6)?,
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
             occurrence_date = ?6, buy_price = ?7, current_price = ?8, note = ?9, tags = ?10, updated_at = ?11
             WHERE id = ?12",
            params![
                &asset.asset_type,
                asset.name,
                asset.amount,
                asset.currency,
                asset.account,
                asset.occurrence_date,
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
    pub fn list_by_type(conn: &Connection, type_id: &str) -> DbResult<Vec<Asset>> {
        let mut stmt = conn.prepare(
            "SELECT id, type, name, amount, currency, account, occurrence_date, buy_price, current_price, note, tags, created_at, updated_at
             FROM assets WHERE type = ?1 ORDER BY created_at DESC"
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let assets = stmt.query_map(params![type_id], |row| {
            let asset_type: String = row.get(1)?;

            let tags_json: Option<String> = row.get(10)?;
            let tags = tags_json.and_then(|j| serde_json::from_str(&j).ok());

            Ok(Asset {
                id: row.get(0)?,
                asset_type,
                name: row.get(2)?,
                amount: row.get(3)?,
                currency: row.get(4)?,
                account: row.get(5)?,
                occurrence_date: row.get(6)?,
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

    /// 按名称搜索资产（支持模糊匹配和类型过滤）
    pub fn search_by_name(
        conn: &Connection,
        name_pattern: &str,
        type_ids: &[String]
    ) -> DbResult<Vec<Asset>> {
        if type_ids.is_empty() {
            return Ok(Vec::new());
        }

        let type_strs: Vec<&str> = type_ids.iter().map(|s| s.as_str()).collect();
        let placeholders = type_ids.iter().map(|_| "?").collect::<Vec<_>>().join(",");
        let sql = format!(
            "SELECT id, type, name, amount, currency, account, occurrence_date, buy_price, current_price, note, tags, created_at, updated_at
             FROM assets
             WHERE name LIKE ? AND type IN ({})
             ORDER BY name ASC, created_at DESC",
            placeholders
        );

        let mut stmt = conn.prepare(&sql)
            .map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let pattern = format!("%{}%", name_pattern);

        // 构建参数列表
        let mut params_list: Vec<&dyn rusqlite::ToSql> = vec![&pattern];
        for t in &type_strs {
            params_list.push(t);
        }

        let assets = stmt.query_map(params_list.as_slice(), |row| {
            let asset_type: String = row.get(1)?;

            let tags_json: Option<String> = row.get(10)?;
            let tags = tags_json.and_then(|j| serde_json::from_str(&j).ok());

            Ok(Asset {
                id: row.get(0)?,
                asset_type,
                name: row.get(2)?,
                amount: row.get(3)?,
                currency: row.get(4)?,
                account: row.get(5)?,
                occurrence_date: row.get(6)?,
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

/// 资产变更记录仓库（审计日志）
pub struct AssetChangeRepository;

impl AssetChangeRepository {
    /// 创建变更记录
    pub fn create(conn: &Connection, change: &AssetChange) -> DbResult<String> {
        conn.execute(
            "INSERT INTO asset_changes (id, asset_id, change_type, occurrence_date_old, occurrence_date_new,
             amount_old, amount_new, name_old, name_new, data_snapshot_old, data_snapshot_new, changed_field, changed_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)",
            params![
                change.id,
                change.asset_id,
                change.change_type.as_str(),
                change.occurrence_date_old,
                change.occurrence_date_new,
                change.amount_old,
                change.amount_new,
                change.name_old,
                change.name_new,
                change.data_snapshot_old,
                change.data_snapshot_new,
                change.changed_field,
                change.changed_at,
            ],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(change.id.clone())
    }

    /// 获取指定资产的所有变更记录
    pub fn list_by_asset(conn: &Connection, asset_id: &str) -> DbResult<Vec<AssetChange>> {
        let mut stmt = conn.prepare(
            "SELECT id, asset_id, change_type, occurrence_date_old, occurrence_date_new,
             amount_old, amount_new, name_old, name_new, data_snapshot_old, data_snapshot_new, changed_field, changed_at
             FROM asset_changes WHERE asset_id = ?1 ORDER BY changed_at DESC"
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let changes = stmt.query_map(params![asset_id], |row| {
            let change_type_str: String = row.get(2)?;
            let change_type = ChangeType::from_str(&change_type_str)
                .ok_or_else(|| rusqlite::Error::InvalidQuery)?;

            Ok(AssetChange {
                id: row.get(0)?,
                asset_id: row.get(1)?,
                change_type,
                occurrence_date_old: row.get(3)?,
                occurrence_date_new: row.get(4)?,
                amount_old: row.get(5)?,
                amount_new: row.get(6)?,
                name_old: row.get(7)?,
                name_new: row.get(8)?,
                data_snapshot_old: row.get(9)?,
                data_snapshot_new: row.get(10)?,
                changed_field: row.get(11)?,
                changed_at: row.get(12)?,
            })
        }).map_err(|e| DbError::DatabaseError(e.to_string()))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(changes)
    }

    /// 获取所有变更记录
    pub fn list_all(conn: &Connection, limit: Option<usize>) -> DbResult<Vec<AssetChange>> {
        let limit_sql = limit.map(|l| format!(" LIMIT {}", l)).unwrap_or_default();
        let sql = format!(
            "SELECT id, asset_id, change_type, occurrence_date_old, occurrence_date_new,
             amount_old, amount_new, name_old, name_new, data_snapshot_old, data_snapshot_new, changed_field, changed_at
             FROM asset_changes ORDER BY changed_at DESC{}",
            limit_sql
        );

        let mut stmt = conn.prepare(&sql)
            .map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let changes = stmt.query_map([], |row| {
            let change_type_str: String = row.get(2)?;
            let change_type = ChangeType::from_str(&change_type_str)
                .ok_or_else(|| rusqlite::Error::InvalidQuery)?;

            Ok(AssetChange {
                id: row.get(0)?,
                asset_id: row.get(1)?,
                change_type,
                occurrence_date_old: row.get(3)?,
                occurrence_date_new: row.get(4)?,
                amount_old: row.get(5)?,
                amount_new: row.get(6)?,
                name_old: row.get(7)?,
                name_new: row.get(8)?,
                data_snapshot_old: row.get(9)?,
                data_snapshot_new: row.get(10)?,
                changed_field: row.get(11)?,
                changed_at: row.get(12)?,
            })
        }).map_err(|e| DbError::DatabaseError(e.to_string()))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(changes)
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
