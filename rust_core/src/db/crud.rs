//! 数据库 CRUD 操作

use rusqlite::{Connection, params};

use super::{DbError, DbResult};
use super::models::{Asset, Liability, AssetHistory, Attachment, AssetChange, ChangeType};

/// 从行数据构建 Asset 对象（包含所有扩展字段）
fn make_asset_from_row(
    id: String,
    asset_type: String,
    name: String,
    amount: f64,
    currency: String,
    account: Option<String>,
    occurrence_date: String,
    buy_price: Option<f64>,
    current_price: Option<f64>,
    note: Option<String>,
    tags: Option<Vec<String>>,
    // 投资类专属字段
    code: Option<String>,
    exchange: Option<String>,
    quantity: Option<i64>,
    // 房产专属字段
    address: Option<String>,
    building_area: Option<f64>,
    living_area: Option<f64>,
    property_type: Option<String>,
    rooms: Option<i32>,
    floor: Option<String>,
    build_year: Option<i32>,
    ownership_type: Option<String>,
    deed_number: Option<String>,
    // 存款专属字段
    deposit_account_type: Option<String>,
    deposit_period: Option<i32>,
    maturity_date: Option<String>,
    deposit_interest_rate: Option<f64>,
    // 保单专属字段
    policy_number: Option<String>,
    insurance_type: Option<String>,
    insured: Option<String>,
    beneficiary: Option<String>,
    coverage_amount: Option<f64>,
    premium: Option<f64>,
    premium_period: Option<String>,
    coverage_period: Option<String>,
    insurer: Option<String>,
    // 时间戳
    created_at: i64,
    updated_at: i64,
) -> Asset {
    Asset {
        id,
        asset_type,
        name,
        amount,
        currency,
        occurrence_date,
        note,
        account,
        tags,
        buy_price,
        current_price,
        // 投资类专属字段
        code,
        exchange,
        quantity: quantity.map(|q| q as i32),
        // 房产专属字段
        address,
        building_area,
        living_area,
        property_type,
        rooms,
        floor,
        build_year,
        ownership_type,
        deed_number,
        // 存款专属字段
        deposit_account_type,
        deposit_period,
        maturity_date,
        deposit_interest_rate,
        // 保单专属字段
        policy_number,
        insurance_type,
        insured,
        beneficiary,
        coverage_amount,
        premium,
        premium_period,
        coverage_period,
        insurer,
        created_at,
        updated_at,
    }
}

/// 资产仓库
pub struct AssetRepository;

impl AssetRepository {
    /// 创建资产（包含所有扩展字段）
    pub fn create(conn: &Connection, asset: &Asset) -> DbResult<String> {
        eprintln!("===== AssetRepository::create 开始 =====");
        eprintln!("资产 ID: {}", asset.id);
        eprintln!("资产名称: {}", asset.name);
        eprintln!("资产类型: {}", asset.asset_type);
        eprintln!("买入价: {:?}", asset.buy_price);
        eprintln!("现价: {:?}", asset.current_price);

        let tags_json = asset.tags.as_ref()
            .and_then(|t| serde_json::to_string(t).ok());

        // INSERT 语句包含所有字段（使用位置参数）
        conn.execute(
            "INSERT INTO assets (
                id, asset_type, name, amount, currency, account, occurrence_date,
                buy_price, current_price, code, exchange, quantity,
                address, building_area, living_area, property_type, rooms, floor,
                build_year, ownership_type, deed_number,
                deposit_account_type, deposit_period, maturity_date, deposit_interest_rate,
                policy_number, insurance_type, insured, beneficiary, coverage_amount,
                premium, premium_period, coverage_period, insurer,
                note, tags, created_at, updated_at
            ) VALUES (
                ?1, ?2, ?3, ?4, ?5, ?6, ?7,
                ?8, ?9, ?10, ?11, ?12,
                ?13, ?14, ?15, ?16, ?17, ?18,
                ?19, ?20, ?21,
                ?22, ?23, ?24, ?25,
                ?26, ?27, ?28, ?29, ?30,
                ?31, ?32, ?33, ?34,
                ?35, ?36, ?37, ?38
            )",
            params![
                &asset.id,
                &asset.asset_type,
                &asset.name,
                asset.amount,
                &asset.currency,
                &asset.account,
                &asset.occurrence_date,
                &asset.buy_price,
                &asset.current_price,
                &asset.code,
                &asset.exchange,
                asset.quantity.map(|q| q as i64),
                &asset.address,
                asset.building_area,
                asset.living_area,
                &asset.property_type,
                asset.rooms,
                &asset.floor,
                asset.build_year,
                &asset.ownership_type,
                &asset.deed_number,
                &asset.deposit_account_type,
                asset.deposit_period,
                &asset.maturity_date,
                asset.deposit_interest_rate,
                &asset.policy_number,
                &asset.insurance_type,
                &asset.insured,
                &asset.beneficiary,
                asset.coverage_amount,
                asset.premium,
                &asset.premium_period,
                &asset.coverage_period,
                &asset.insurer,
                &asset.note,
                &tags_json,
                asset.created_at,
                asset.updated_at,
            ],
        ).map_err(|e| {
            eprintln!("插入失败: {}", e);
            DbError::DatabaseError(e.to_string())
        })?;

        eprintln!("插入成功");
        Ok(asset.id.clone())
    }

    /// 获取单个资产（包含所有扩展字段）
    pub fn get(conn: &Connection, id: &str) -> DbResult<Asset> {
        let mut stmt = conn.prepare(
            "SELECT
                id, asset_type, name, amount, currency, account, occurrence_date,
                buy_price, current_price, code, exchange, quantity,
                address, building_area, living_area, property_type, rooms, floor,
                build_year, ownership_type, deed_number,
                deposit_account_type, deposit_period, maturity_date, deposit_interest_rate,
                policy_number, insurance_type, insured, beneficiary, coverage_amount,
                premium, premium_period, coverage_period, insurer,
                note, tags, created_at, updated_at
             FROM assets WHERE id = ?1"
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let asset = stmt.query_row(params![id], |row| {
            let asset_type: String = row.get(1)?;
            let tags_json: Option<String> = row.get(35)?;
            let tags = tags_json.and_then(|j| serde_json::from_str(&j).ok());

            Ok(make_asset_from_row(
                row.get(0)?,   // id
                asset_type,    // asset_type
                row.get(2)?,   // name
                row.get(3)?,   // amount
                row.get(4)?,   // currency
                row.get(5)?,   // account
                row.get(6)?,   // occurrence_date
                row.get(7)?,   // buy_price
                row.get(8)?,   // current_price
                row.get(34)?,  // note
                tags,
                // 投资类字段
                row.get(9)?,   // code
                row.get(10)?,  // exchange
                row.get(11)?,  // quantity
                // 房产字段
                row.get(12)?,  // address
                row.get(13)?,  // building_area
                row.get(14)?,  // living_area
                row.get(15)?,  // property_type
                row.get(16)?,  // rooms
                row.get(17)?,  // floor
                row.get(18)?,  // build_year
                row.get(19)?,  // ownership_type
                row.get(20)?,  // deed_number
                // 存款字段
                row.get(21)?,  // deposit_account_type
                row.get(22)?,  // deposit_period
                row.get(23)?,  // maturity_date
                row.get(24)?,  // deposit_interest_rate
                // 保单字段
                row.get(25)?,  // policy_number
                row.get(26)?,  // insurance_type
                row.get(27)?,  // insured
                row.get(28)?,  // beneficiary
                row.get(29)?,  // coverage_amount
                row.get(30)?,  // premium
                row.get(31)?,  // premium_period
                row.get(32)?,  // coverage_period
                row.get(33)?,  // insurer
                // 时间戳
                row.get(36)?,  // created_at
                row.get(37)?,  // updated_at
            ))
        }).map_err(|e| match e {
            rusqlite::Error::QueryReturnedNoRows => DbError::NotFound(id.to_string()),
            _ => DbError::DatabaseError(e.to_string()),
        })?;

        Ok(asset)
    }

    /// 获取所有资产（包含所有扩展字段）
    pub fn list(conn: &Connection) -> DbResult<Vec<Asset>> {
        // 资产类型列表
        let asset_types = ["property", "deposit", "stock", "fund", "insurance"];
        let placeholders = asset_types.iter().map(|_| "?").collect::<Vec<_>>().join(",");

        let sql = format!(
            "SELECT
                id, asset_type, name, amount, currency, account, occurrence_date,
                buy_price, current_price, code, exchange, quantity,
                address, building_area, living_area, property_type, rooms, floor,
                build_year, ownership_type, deed_number,
                deposit_account_type, deposit_period, maturity_date, deposit_interest_rate,
                policy_number, insurance_type, insured, beneficiary, coverage_amount,
                premium, premium_period, coverage_period, insurer,
                note, tags, created_at, updated_at
             FROM assets WHERE asset_type IN ({}) ORDER BY created_at DESC",
            placeholders
        );

        let mut stmt = conn.prepare(&sql).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        // 构建参数列表
        let params_list: Vec<&dyn rusqlite::ToSql> = asset_types.iter().map(|s| s as &dyn rusqlite::ToSql).collect();

        let assets = stmt.query_map(params_list.as_slice(), |row| {
            let asset_type: String = row.get(1)?;
            let tags_json: Option<String> = row.get(35)?;
            let tags = tags_json.and_then(|j| serde_json::from_str(&j).ok());

            Ok(make_asset_from_row(
                row.get(0)?,   // id
                asset_type,    // asset_type
                row.get(2)?,   // name
                row.get(3)?,   // amount
                row.get(4)?,   // currency
                row.get(5)?,   // account
                row.get(6)?,   // occurrence_date
                row.get(7)?,   // buy_price
                row.get(8)?,   // current_price
                row.get(34)?,  // note
                tags,
                // 投资类字段
                row.get(9)?,   // code
                row.get(10)?,  // exchange
                row.get(11)?,  // quantity
                // 房产字段
                row.get(12)?,  // address
                row.get(13)?,  // building_area
                row.get(14)?,  // living_area
                row.get(15)?,  // property_type
                row.get(16)?,  // rooms
                row.get(17)?,  // floor
                row.get(18)?,  // build_year
                row.get(19)?,  // ownership_type
                row.get(20)?,  // deed_number
                // 存款字段
                row.get(21)?,  // deposit_account_type
                row.get(22)?,  // deposit_period
                row.get(23)?,  // maturity_date
                row.get(24)?,  // deposit_interest_rate
                // 保单字段
                row.get(25)?,  // policy_number
                row.get(26)?,  // insurance_type
                row.get(27)?,  // insured
                row.get(28)?,  // beneficiary
                row.get(29)?,  // coverage_amount
                row.get(30)?,  // premium
                row.get(31)?,  // premium_period
                row.get(32)?,  // coverage_period
                row.get(33)?,  // insurer
                // 时间戳
                row.get(36)?,  // created_at
                row.get(37)?,  // updated_at
            ))
        }).map_err(|e| DbError::DatabaseError(e.to_string()))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(assets)
    }

    /// 更新资产（包含所有扩展字段）
    pub fn update(conn: &Connection, asset: &Asset) -> DbResult<()> {
        let tags_json = asset.tags.as_ref()
            .and_then(|t| serde_json::to_string(t).ok());
        let updated_at = chrono::Utc::now().timestamp();

        conn.execute(
            "UPDATE assets SET
                asset_type = ?1, name = ?2, amount = ?3, currency = ?4, account = ?5,
                occurrence_date = ?6, buy_price = ?7, current_price = ?8,
                code = ?9, exchange = ?10, quantity = ?11,
                address = ?12, building_area = ?13, living_area = ?14, property_type = ?15,
                rooms = ?16, floor = ?17, build_year = ?18, ownership_type = ?19, deed_number = ?20,
                deposit_account_type = ?21, deposit_period = ?22, maturity_date = ?23, deposit_interest_rate = ?24,
                policy_number = ?25, insurance_type = ?26, insured = ?27, beneficiary = ?28,
                coverage_amount = ?29, premium = ?30, premium_period = ?31, coverage_period = ?32, insurer = ?33,
                note = ?34, tags = ?35, updated_at = ?36
             WHERE id = ?37",
            params![
                &asset.asset_type,
                asset.name,
                asset.amount,
                asset.currency,
                asset.account,
                asset.occurrence_date,
                asset.buy_price,
                asset.current_price,
                asset.code,
                asset.exchange,
                asset.quantity.map(|q| q as i64),
                asset.address,
                asset.building_area,
                asset.living_area,
                asset.property_type,
                asset.rooms,
                asset.floor,
                asset.build_year,
                asset.ownership_type,
                asset.deed_number,
                asset.deposit_account_type,
                asset.deposit_period,
                asset.maturity_date,
                asset.deposit_interest_rate,
                asset.policy_number,
                asset.insurance_type,
                asset.insured,
                asset.beneficiary,
                asset.coverage_amount,
                asset.premium,
                asset.premium_period,
                asset.coverage_period,
                asset.insurer,
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

    /// 按类型获取资产（包含所有扩展字段）
    pub fn list_by_type(conn: &Connection, type_id: &str) -> DbResult<Vec<Asset>> {
        let mut stmt = conn.prepare(
            "SELECT
                id, asset_type, name, amount, currency, account, occurrence_date,
                buy_price, current_price, code, exchange, quantity,
                address, building_area, living_area, property_type, rooms, floor,
                build_year, ownership_type, deed_number,
                deposit_account_type, deposit_period, maturity_date, deposit_interest_rate,
                policy_number, insurance_type, insured, beneficiary, coverage_amount,
                premium, premium_period, coverage_period, insurer,
                note, tags, created_at, updated_at
             FROM assets WHERE asset_type = ?1 ORDER BY created_at DESC"
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let assets = stmt.query_map(params![type_id], |row| {
            let asset_type: String = row.get(1)?;
            let tags_json: Option<String> = row.get(35)?;
            let tags = tags_json.and_then(|j| serde_json::from_str(&j).ok());

            Ok(make_asset_from_row(
                row.get(0)?,   // id
                asset_type,    // asset_type
                row.get(2)?,   // name
                row.get(3)?,   // amount
                row.get(4)?,   // currency
                row.get(5)?,   // account
                row.get(6)?,   // occurrence_date
                row.get(7)?,   // buy_price
                row.get(8)?,   // current_price
                row.get(34)?,  // note
                tags,
                // 投资类字段
                row.get(9)?,   // code
                row.get(10)?,  // exchange
                row.get(11)?,  // quantity
                // 房产字段
                row.get(12)?,  // address
                row.get(13)?,  // building_area
                row.get(14)?,  // living_area
                row.get(15)?,  // property_type
                row.get(16)?,  // rooms
                row.get(17)?,  // floor
                row.get(18)?,  // build_year
                row.get(19)?,  // ownership_type
                row.get(20)?,  // deed_number
                // 存款字段
                row.get(21)?,  // deposit_account_type
                row.get(22)?,  // deposit_period
                row.get(23)?,  // maturity_date
                row.get(24)?,  // deposit_interest_rate
                // 保单字段
                row.get(25)?,  // policy_number
                row.get(26)?,  // insurance_type
                row.get(27)?,  // insured
                row.get(28)?,  // beneficiary
                row.get(29)?,  // coverage_amount
                row.get(30)?,  // premium
                row.get(31)?,  // premium_period
                row.get(32)?,  // coverage_period
                row.get(33)?,  // insurer
                // 时间戳
                row.get(36)?,  // created_at
                row.get(37)?,  // updated_at
            ))
        }).map_err(|e| DbError::DatabaseError(e.to_string()))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(assets)
    }

    /// 按名称搜索资产（支持模糊匹配和类型过滤，包含所有扩展字段）
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
            "SELECT
                id, asset_type, name, amount, currency, account, occurrence_date,
                buy_price, current_price, code, exchange, quantity,
                address, building_area, living_area, property_type, rooms, floor,
                build_year, ownership_type, deed_number,
                deposit_account_type, deposit_period, maturity_date, deposit_interest_rate,
                policy_number, insurance_type, insured, beneficiary, coverage_amount,
                premium, premium_period, coverage_period, insurer,
                note, tags, created_at, updated_at
             FROM assets
             WHERE name LIKE ? AND asset_type IN ({})
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
            let tags_json: Option<String> = row.get(35)?;
            let tags = tags_json.and_then(|j| serde_json::from_str(&j).ok());

            Ok(make_asset_from_row(
                row.get(0)?,   // id
                asset_type,    // asset_type
                row.get(2)?,   // name
                row.get(3)?,   // amount
                row.get(4)?,   // currency
                row.get(5)?,   // account
                row.get(6)?,   // occurrence_date
                row.get(7)?,   // buy_price
                row.get(8)?,   // current_price
                row.get(34)?,  // note
                tags,
                // 投资类字段
                row.get(9)?,   // code
                row.get(10)?,  // exchange
                row.get(11)?,  // quantity
                // 房产字段
                row.get(12)?,  // address
                row.get(13)?,  // building_area
                row.get(14)?,  // living_area
                row.get(15)?,  // property_type
                row.get(16)?,  // rooms
                row.get(17)?,  // floor
                row.get(18)?,  // build_year
                row.get(19)?,  // ownership_type
                row.get(20)?,  // deed_number
                // 存款字段
                row.get(21)?,  // deposit_account_type
                row.get(22)?,  // deposit_period
                row.get(23)?,  // maturity_date
                row.get(24)?,  // deposit_interest_rate
                // 保单字段
                row.get(25)?,  // policy_number
                row.get(26)?,  // insurance_type
                row.get(27)?,  // insured
                row.get(28)?,  // beneficiary
                row.get(29)?,  // coverage_amount
                row.get(30)?,  // premium
                row.get(31)?,  // premium_period
                row.get(32)?,  // coverage_period
                row.get(33)?,  // insurer
                // 时间戳
                row.get(36)?,  // created_at
                row.get(37)?,  // updated_at
            ))
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

/// 从行数据构建 Liability 对象（包含所有扩展字段）
fn make_liability_from_row(
    id: String,
    liability_type: String,
    name: String,
    amount: f64,
    currency: String,
    occurrence_date: String,
    note: Option<String>,
    // 贷款类通用字段
    lender: Option<String>,
    due_date: Option<String>,
    interest_rate: Option<f64>,
    repayment_method: Option<String>,
    loan_term: Option<i32>,
    // 信用卡专属字段
    last_four_digits: Option<String>,
    billing_date: Option<String>,
    payment_due_date: Option<String>,
    credit_limit: Option<f64>,
    cash_limit: Option<f64>,
    annual_fee: Option<f64>,
    issuer: Option<String>,
    // 房贷专属字段
    property_address: Option<String>,
    original_loan_amount: Option<f64>,
    remaining_principal: Option<f64>,
    loan_type: Option<String>,
    // 车贷专属字段
    vehicle_brand: Option<String>,
    vehicle_model: Option<String>,
    license_plate: Option<String>,
    // 个人/私人借款专属字段
    purpose: Option<String>,
    has_interest: Option<bool>,
    repayment_plan: Option<String>,
    // 时间戳
    created_at: i64,
    updated_at: i64,
) -> Liability {
    Liability {
        id,
        liability_type,
        name,
        amount,
        currency,
        occurrence_date,
        note,
        // 贷款类通用字段
        lender,
        due_date,
        interest_rate,
        repayment_method,
        loan_term,
        // 信用卡专属字段
        last_four_digits,
        billing_date,
        payment_due_date,
        credit_limit,
        cash_limit,
        annual_fee,
        issuer,
        // 房贷专属字段
        property_address,
        original_loan_amount,
        remaining_principal,
        loan_type,
        // 车贷专属字段
        vehicle_brand,
        vehicle_model,
        license_plate,
        // 个人/私人借款专属字段
        purpose,
        has_interest,
        repayment_plan,
        created_at,
        updated_at,
    }
}

/// 负债仓库
pub struct LiabilityRepository;

impl LiabilityRepository {
    /// 创建负债（包含所有扩展字段）
    pub fn create(conn: &Connection, liability: &Liability) -> DbResult<String> {
        eprintln!("===== LiabilityRepository::create 开始 =====");
        eprintln!("负债 ID: {}", liability.id);
        eprintln!("负债名称: {}", liability.name);
        eprintln!("负债类型: {}", liability.liability_type);

        // INSERT 语句包含所有字段（使用 asset_type 列存储负债类型）
        conn.execute(
            "INSERT INTO assets (
                id, asset_type, name, amount, currency, occurrence_date,
                lender, due_date, interest_rate, repayment_method, loan_term,
                last_four_digits, billing_date, payment_due_date, credit_limit,
                cash_limit, annual_fee, issuer,
                property_address, original_loan_amount, remaining_principal, loan_type,
                vehicle_brand, vehicle_model, license_plate,
                purpose, has_interest, repayment_plan,
                note, created_at, updated_at
            ) VALUES (
                ?1, ?2, ?3, ?4, ?5, ?6,
                ?7, ?8, ?9, ?10, ?11,
                ?12, ?13, ?14, ?15,
                ?16, ?17, ?18,
                ?19, ?20, ?21, ?22,
                ?23, ?24, ?25,
                ?26, ?27, ?28,
                ?29, ?30, ?31
            )",
            params![
                &liability.id,
                &liability.liability_type,
                &liability.name,
                liability.amount,
                &liability.currency,
                &liability.occurrence_date,
                // 贷款类通用字段
                &liability.lender,
                &liability.due_date,
                liability.interest_rate,
                &liability.repayment_method,
                liability.loan_term,
                // 信用卡专属字段
                &liability.last_four_digits,
                &liability.billing_date,
                &liability.payment_due_date,
                liability.credit_limit,
                liability.cash_limit,
                liability.annual_fee,
                &liability.issuer,
                // 房贷专属字段
                &liability.property_address,
                liability.original_loan_amount,
                liability.remaining_principal,
                &liability.loan_type,
                // 车贷专属字段
                &liability.vehicle_brand,
                &liability.vehicle_model,
                &liability.license_plate,
                // 个人/私人借款专属字段
                &liability.purpose,
                liability.has_interest.map(|b| if b { 1 } else { 0 }),
                &liability.repayment_plan,
                &liability.note,
                liability.created_at,
                liability.updated_at,
            ],
        ).map_err(|e| {
            eprintln!("插入负债失败: {}", e);
            DbError::DatabaseError(e.to_string())
        })?;

        eprintln!("插入负债成功");
        Ok(liability.id.clone())
    }

    /// 获取单个负债（包含所有扩展字段）
    pub fn get(conn: &Connection, id: &str) -> DbResult<Liability> {
        let mut stmt = conn.prepare(
            "SELECT
                id, asset_type, name, amount, currency, occurrence_date,
                lender, due_date, interest_rate, repayment_method, loan_term,
                last_four_digits, billing_date, payment_due_date, credit_limit,
                cash_limit, annual_fee, issuer,
                property_address, original_loan_amount, remaining_principal, loan_type,
                vehicle_brand, vehicle_model, license_plate,
                purpose, has_interest, repayment_plan,
                note, created_at, updated_at
             FROM assets WHERE id = ?1"
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let liability = stmt.query_row(params![id], |row| {
            let has_interest: Option<i32> = row.get(26)?;
            Ok(make_liability_from_row(
                row.get(0)?,   // id
                row.get(1)?,   // liability_type (asset_type in db)
                row.get(2)?,   // name
                row.get(3)?,   // amount
                row.get(4)?,   // currency
                row.get(5)?,   // occurrence_date
                row.get(28)?,  // note
                // 贷款类通用字段
                row.get(6)?,   // lender
                row.get(7)?,   // due_date
                row.get(8)?,   // interest_rate
                row.get(9)?,   // repayment_method
                row.get(10)?,  // loan_term
                // 信用卡专属字段
                row.get(11)?,  // last_four_digits
                row.get(12)?,  // billing_date
                row.get(13)?,  // payment_due_date
                row.get(14)?,  // credit_limit
                row.get(15)?,  // cash_limit
                row.get(16)?,  // annual_fee
                row.get(17)?,  // issuer
                // 房贷专属字段
                row.get(18)?,  // property_address
                row.get(19)?,  // original_loan_amount
                row.get(20)?,  // remaining_principal
                row.get(21)?,  // loan_type
                // 车贷专属字段
                row.get(22)?,  // vehicle_brand
                row.get(23)?,  // vehicle_model
                row.get(24)?,  // license_plate
                // 个人/私人借款专属字段
                row.get(25)?,  // purpose
                has_interest.map(|v| v == 1),  // has_interest (i32 to bool)
                row.get(27)?,  // repayment_plan
                // 时间戳
                row.get(29)?,  // created_at
                row.get(30)?,  // updated_at
            ))
        }).map_err(|e| match e {
            rusqlite::Error::QueryReturnedNoRows => DbError::NotFound(id.to_string()),
            _ => DbError::DatabaseError(e.to_string()),
        })?;

        Ok(liability)
    }

    /// 获取所有负债（包含所有扩展字段）
    pub fn list(conn: &Connection) -> DbResult<Vec<Liability>> {
        // 负债类型列表
        let liability_types = ["debt", "mortgage", "car_loan", "credit_card", "personal_loan", "private_loan"];
        let placeholders = liability_types.iter().map(|_| "?").collect::<Vec<_>>().join(",");

        let sql = format!(
            "SELECT
                id, asset_type, name, amount, currency, occurrence_date,
                lender, due_date, interest_rate, repayment_method, loan_term,
                last_four_digits, billing_date, payment_due_date, credit_limit,
                cash_limit, annual_fee, issuer,
                property_address, original_loan_amount, remaining_principal, loan_type,
                vehicle_brand, vehicle_model, license_plate,
                purpose, has_interest, repayment_plan,
                note, created_at, updated_at
             FROM assets WHERE asset_type IN ({}) ORDER BY created_at DESC",
            placeholders
        );

        let mut stmt = conn.prepare(&sql).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        // 构建参数列表
        let params_list: Vec<&dyn rusqlite::ToSql> = liability_types.iter().map(|s| s as &dyn rusqlite::ToSql).collect();

        let liabilities = stmt.query_map(params_list.as_slice(), |row| {
            let has_interest: Option<i32> = row.get(26)?;
            Ok(make_liability_from_row(
                row.get(0)?,   // id
                row.get(1)?,   // liability_type (asset_type in db)
                row.get(2)?,   // name
                row.get(3)?,   // amount
                row.get(4)?,   // currency
                row.get(5)?,   // occurrence_date
                row.get(28)?,  // note
                // 贷款类通用字段
                row.get(6)?,   // lender
                row.get(7)?,   // due_date
                row.get(8)?,   // interest_rate
                row.get(9)?,   // repayment_method
                row.get(10)?,  // loan_term
                // 信用卡专属字段
                row.get(11)?,  // last_four_digits
                row.get(12)?,  // billing_date
                row.get(13)?,  // payment_due_date
                row.get(14)?,  // credit_limit
                row.get(15)?,  // cash_limit
                row.get(16)?,  // annual_fee
                row.get(17)?,  // issuer
                // 房贷专属字段
                row.get(18)?,  // property_address
                row.get(19)?,  // original_loan_amount
                row.get(20)?,  // remaining_principal
                row.get(21)?,  // loan_type
                // 车贷专属字段
                row.get(22)?,  // vehicle_brand
                row.get(23)?,  // vehicle_model
                row.get(24)?,  // license_plate
                // 个人/私人借款专属字段
                row.get(25)?,  // purpose
                has_interest.map(|v| v == 1),  // has_interest (i32 to bool)
                row.get(27)?,  // repayment_plan
                // 时间戳
                row.get(29)?,  // created_at
                row.get(30)?,  // updated_at
            ))
        }).map_err(|e| DbError::DatabaseError(e.to_string()))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(liabilities)
    }

    /// 更新负债（包含所有扩展字段）
    pub fn update(conn: &Connection, liability: &Liability) -> DbResult<()> {
        let updated_at = chrono::Utc::now().timestamp();

        conn.execute(
            "UPDATE assets SET
                asset_type = ?1, name = ?2, amount = ?3, currency = ?4, occurrence_date = ?5,
                lender = ?6, due_date = ?7, interest_rate = ?8, repayment_method = ?9, loan_term = ?10,
                last_four_digits = ?11, billing_date = ?12, payment_due_date = ?13, credit_limit = ?14,
                cash_limit = ?15, annual_fee = ?16, issuer = ?17,
                property_address = ?18, original_loan_amount = ?19, remaining_principal = ?20, loan_type = ?21,
                vehicle_brand = ?22, vehicle_model = ?23, license_plate = ?24,
                purpose = ?25, has_interest = ?26, repayment_plan = ?27,
                note = ?28, updated_at = ?29
             WHERE id = ?30",
            params![
                &liability.liability_type,
                liability.name,
                liability.amount,
                &liability.currency,
                &liability.occurrence_date,
                // 贷款类通用字段
                &liability.lender,
                &liability.due_date,
                liability.interest_rate,
                &liability.repayment_method,
                liability.loan_term,
                // 信用卡专属字段
                &liability.last_four_digits,
                &liability.billing_date,
                &liability.payment_due_date,
                liability.credit_limit,
                liability.cash_limit,
                liability.annual_fee,
                &liability.issuer,
                // 房贷专属字段
                &liability.property_address,
                liability.original_loan_amount,
                liability.remaining_principal,
                &liability.loan_type,
                // 车贷专属字段
                &liability.vehicle_brand,
                &liability.vehicle_model,
                &liability.license_plate,
                // 个人/私人借款专属字段
                &liability.purpose,
                liability.has_interest.map(|b| if b { 1 } else { 0 }),
                &liability.repayment_plan,
                &liability.note,
                updated_at,
                liability.id,
            ],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(())
    }

    /// 删除负债
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
}
