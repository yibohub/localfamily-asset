//! FFI (Foreign Function Interface) 模块
//!
//! 提供 C 兼容的 API 供 Flutter 调用

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_double, c_int};
use std::ptr;
use std::fs::OpenOptions;

use once_cell::sync::Lazy;
use serde_json::json;
use chrono::Local;
use sha2::{Sha256, Digest};

use crate::crypto::{derive_key, generate_salt, mnemonic_to_key};
use crate::db::{Asset, AssetRepository, AssetType, Liability, LiabilityRepository, DbError, DbResult, AssetChange, ChangeType, AssetChangeRepository, CustomAssetType, CustomTypeRepository, NetWorthSnapshot, NetWorthSnapshotRepository};
use crate::db::{is_encrypted_db, save_encrypted_db, load_encrypted_db, load_plaintext_db};
use crate::db::{Attachment, AttachmentRepository};
use crate::db::{
    attachments_dir, get_or_create_attachment_key, save_attachment_file, load_attachment_file,
    delete_attachment_file,
};
use base64::Engine as _;
use rusqlite::Connection;

/// 附件单个文件解密后的大小上限（20 MB，防误传大文件拖垮内存）
const ATTACHMENT_MAX_SIZE: usize = 20 * 1024 * 1024;

/// 文件日志（仅 Windows 桌面端写文件；其余平台静默降级为 stderr，
/// 不能依赖硬编码用户目录——移动端无此路径，写入必然失败）
fn write_log(msg: &str) {
    use std::io::Write;
    let timestamp = Local::now().to_rfc3339();
    let log_msg = format!("[{}] {}\n", timestamp, msg);
    if !cfg!(windows) {
        eprintln!("{}", log_msg);
        return;
    }
    let Some(home) = std::env::var_os("USERPROFILE") else {
        eprintln!("{}", log_msg);
        return;
    };
    let path = std::path::Path::new(&home)
        .join("Documents")
        .join("localfamily_asset_rust.log");
    match OpenOptions::new()
        .append(true)
        .create(true)
        .open(&path)
        .and_then(|mut file| file.write_all(log_msg.as_bytes()))
    {
        Ok(_) => {},
        Err(e) => {
            eprintln!("写入日志失败 ({}): {}", path.display(), e);
        }
    }
}

/// 全局应用状态
static APP_STATE: Lazy<std::sync::Mutex<Option<AppState>>> =
    Lazy::new(|| std::sync::Mutex::new(None));

/// 应用状态
struct AppState {
    db_path: String,
    master_key: Option<[u8; 32]>,  // 固定大小数组用于加密
    memory_conn: Option<Connection>, // 长生命周期内存连接
    is_dirty: bool,                 // 脏标记（数据是否有变更）
}

/// FFI 错误码
#[repr(C)]
pub enum FfiErrorCode {
    Success = 0,
    GenericError = -1,
    InvalidPassword = -2,
    DatabaseError = -3,
    CryptoError = -4,
    NotFound = -5,
}

/// 将 Rust 字符串转换为 C 字符串
///
/// 注意：调用者需要负责释放返回的指针
fn string_to_c_char(s: String) -> *mut c_char {
    match CString::new(s) {
        Ok(c_string) => c_string.into_raw(),
        Err(_) => ptr::null_mut(),
    }
}

/// 打开数据库连接
fn open_db(db_path: &str) -> DbResult<Connection> {
    Connection::open(db_path)
        .map_err(|e| DbError::DatabaseError(e.to_string()))
}

/// 在内存或磁盘数据库上执行操作（V2 兼容）
///
/// 此函数用于支持 V2 加密模式，优先使用内存数据库。
/// 如果内存数据库不存在，则回退到磁盘数据库（兼容旧 API）。
fn with_db_connection<F, R>(
    state: &AppState,
    f: F,
) -> DbResult<R>
where
    F: FnOnce(&Connection) -> DbResult<R>,
{
    // 优先使用内存数据库连接（V2 加密模式）
    if let Some(ref conn) = state.memory_conn {
        return f(conn);
    }

    // 回退到磁盘数据库（旧模式）
    let conn = open_db(&state.db_path)?;
    f(&conn)
}

/// 安全释放 C 字符串
#[no_mangle]
pub unsafe extern "C" fn free_string(s: *mut c_char) {
    if !s.is_null() {
        let _ = CString::from_raw(s);
    }
}

/// 初始化应用
#[export_name = "init_app"]
pub unsafe extern "C" fn init_app(db_path: *const c_char) -> c_int {
    let db_path = match CStr::from_ptr(db_path).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let mut state = APP_STATE.lock().unwrap();
    *state = Some(AppState {
        db_path: db_path.clone(),
        master_key: None,
        memory_conn: None,
        is_dirty: false,
    });

    // 打开数据库并执行迁移（如果需要）
    let conn = match open_db(&db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    match crate::db::init_db(&conn) {
        Ok(_) => eprintln!("应用初始化成功，数据库迁移已完成"),
        Err(e) => {
            eprintln!("数据库迁移失败: {}", e);
            // 不返回错误，允许应用继续运行
        }
    }

    FfiErrorCode::Success as c_int
}

/// 设置主密码
#[export_name = "setup_password"]
pub unsafe extern "C" fn setup_password(
    password: *const c_char,
    hint: *const c_char,
) -> c_int {
    let password = match CStr::from_ptr(password).to_str() {
        Ok(s) => s,
        Err(_) => return FfiErrorCode::InvalidPassword as c_int,
    };

    let _hint = if hint.is_null() {
        None
    } else {
        match CStr::from_ptr(hint).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let mut state = APP_STATE.lock().unwrap();
    let state = match state.as_mut() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 生成盐值并派生密钥
    let salt = generate_salt();
    let key_vec = match derive_key(password, &salt) {
        Ok(k) => k.to_vec(),
        Err(_) => return FfiErrorCode::CryptoError as c_int,
    };

    // 将 Vec<u8> 转换为 [u8; 32]
    let mut key = [0u8; 32];
    key.copy_from_slice(&key_vec);

    // 初始化数据库
    let _conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 创建数据库表结构并执行迁移
    match crate::db::init_db(&_conn) {
        Ok(_) => eprintln!("数据库初始化成功（包括迁移）"),
        Err(e) => {
            eprintln!("初始化数据库失败: {}", e);
            return FfiErrorCode::DatabaseError as c_int;
        }
    }

    // 保存盐值到设置表
    let salt_hex = hex::encode(&salt);
    if let Err(e) = _conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
        ["password_salt", &salt_hex],
    ) {
        eprintln!("保存盐值失败: {}", e);
        return FfiErrorCode::DatabaseError as c_int;
    }

    // 计算并保存密钥哈希（用于后续验证密码）
    let key_hash = Sha256::digest(&key);
    let key_hash_hex = hex::encode(&key_hash);
    if let Err(e) = _conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
        ["password_key_hash", &key_hash_hex],
    ) {
        eprintln!("保存密钥哈希失败: {}", e);
        return FfiErrorCode::DatabaseError as c_int;
    }

    state.master_key = Some(key);

    FfiErrorCode::Success as c_int
}

/// 验证密码
#[no_mangle]
pub unsafe extern "C" fn verify_password(password: *const c_char) -> c_int {
    let password = match CStr::from_ptr(password).to_str() {
        Ok(s) => s,
        Err(_) => return FfiErrorCode::InvalidPassword as c_int,
    };

    let mut state = APP_STATE.lock().unwrap();
    let state = match state.as_mut() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 获取存储的盐值和密钥哈希
    let (salt_hex, stored_key_hash) = match with_db_connection(&state, |conn| -> DbResult<(String, Option<String>)> {
        let salt_hex: String = conn.query_row(
            "SELECT value FROM settings WHERE key = ?1",
            ["password_salt"],
            |row| row.get(0),
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        // 获取存储的密钥哈希
        // 兼容旧数据库：如果不存在 password_key_hash，则是旧版本数据
        // 第一次成功验证后会自动写入哈希值
        let stored_key_hash: Option<String> = conn.query_row(
            "SELECT value FROM settings WHERE key = ?1",
            ["password_key_hash"],
            |row| row.get(0),
        ).ok();

        Ok((salt_hex, stored_key_hash))
    }) {
        Ok(result) => result,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    let salt = match hex::decode(&salt_hex) {
        Ok(s) if s.len() == 32 => {
            let mut arr = [0u8; 32];
            arr.copy_from_slice(&s);
            arr
        }
        _ => return FfiErrorCode::InvalidPassword as c_int,
    };

    // 派生密钥并验证
    let key_vec = match derive_key(password, &salt) {
        Ok(k) => k.to_vec(),
        Err(_) => return FfiErrorCode::CryptoError as c_int,
    };

    // 转换为固定大小数组
    let mut key = [0u8; 32];
    key.copy_from_slice(&key_vec);

    // 计算密钥哈希
    let key_hash = Sha256::digest(&key);
    let key_hash_hex = hex::encode(&key_hash);

    match stored_key_hash {
        Some(stored) => {
            // 新版本数据：验证密钥哈希是否匹配
            if key_hash_hex != stored {
                eprintln!("密码验证失败：密钥哈希不匹配");
                return FfiErrorCode::InvalidPassword as c_int;
            }
        }
        None => {
            // 旧版本数据：没有密钥哈希，自动写入（兼容迁移）
            eprintln!("检测到旧版本数据库，自动写入密钥哈希");
            let result = with_db_connection(&state, |conn| -> DbResult<()> {
                conn.execute(
                    "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
                    ["password_key_hash", &key_hash_hex],
                ).map_err(|e| DbError::DatabaseError(e.to_string()))?;
                Ok(())
            });
            if let Err(e) = result {
                eprintln!("写入密钥哈希失败: {}", e);
                return FfiErrorCode::DatabaseError as c_int;
            }
        }
    }

    // 密码正确，将密钥保存到状态
    state.master_key = Some(key);

    FfiErrorCode::Success as c_int
}

/// 使用助记词验证并恢复访问
#[export_name = "verify_with_mnemonic"]
pub unsafe extern "C" fn verify_with_mnemonic(mnemonic: *const c_char) -> c_int {
    let mnemonic_str = match CStr::from_ptr(mnemonic).to_str() {
        Ok(s) => s,
        Err(_) => return FfiErrorCode::InvalidPassword as c_int,
    };

    let mut state = APP_STATE.lock().unwrap();
    let state = match state.as_mut() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 使用助记词生成密钥
    let key_vec = match mnemonic_to_key(mnemonic_str) {
        Ok(k) => k.to_vec(),
        Err(e) => {
            write_log(&format!("助记词派生密钥失败: {}", e));
            return FfiErrorCode::CryptoError as c_int;
        }
    };

    // 转换为固定大小数组
    let mut key = [0u8; 32];
    key.copy_from_slice(&key_vec);

    // 计算助记词派生的密钥哈希
    let key_hash = Sha256::digest(&key);
    let key_hash_hex = hex::encode(&key_hash);

    // 使用辅助函数从数据库获取存储的助记词密钥哈希（支持内存数据库）
    let stored_mnemonic_hash: String = match with_db_connection(state, |conn| {
        conn.query_row(
            "SELECT value FROM settings WHERE key = ?1",
            ["mnemonic_key_hash"],
            |row| row.get(0),
        ).map_err(|e| DbError::DatabaseError(e.to_string()))
    }) {
        Ok(hash) => hash,
        Err(e) => {
            write_log(&format!("获取助记词密钥哈希失败: {}", e));
            return FfiErrorCode::InvalidPassword as c_int;
        }
    };

    // 验证密钥哈希是否匹配
    if key_hash_hex == stored_mnemonic_hash {
        // 助记词正确，将密钥保存到状态
        state.master_key = Some(key);
        write_log(&format!("助记词验证成功"));
        FfiErrorCode::Success as c_int
    } else {
        write_log(&format!("助记词验证失败：密钥哈希不匹配\n期望: {}\n实际: {}", &stored_mnemonic_hash[..8], &key_hash_hex[..8]));
        FfiErrorCode::InvalidPassword as c_int
    }
}

/// 获取密码提示
#[export_name = "get_password_hint"]
pub unsafe extern "C" fn get_password_hint() -> *mut c_char {
    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return ptr::null_mut(),
    };

    // 使用辅助函数从数据库获取密码提示（支持内存数据库）
    let hint: Option<String> = with_db_connection(state, |conn| {
        conn.query_row(
            "SELECT value FROM settings WHERE key = ?1",
            ["password_hint"],
            |row| row.get(0),
        ).map_err(|e| DbError::DatabaseError(e.to_string()))
    }).ok();

    match hint {
        Some(h) => string_to_c_char(h),
        None => ptr::null_mut(),
    }
}

/// 生成助记词
#[export_name = "generate_mnemonic"]
pub unsafe extern "C" fn generate_mnemonic() -> *mut c_char {
    match crate::crypto::generate_mnemonic() {
        Ok(mnemonic) => string_to_c_char(mnemonic),
        Err(_) => ptr::null_mut(),
    }
}

/// 保存助记词
#[export_name = "save_mnemonic"]
pub unsafe extern "C" fn save_mnemonic(mnemonic: *const c_char) -> c_int {
    let mnemonic = match CStr::from_ptr(mnemonic).to_str() {
        Ok(s) => s,
        Err(_) => return FfiErrorCode::InvalidPassword as c_int,
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 使用辅助函数保存助记词（支持内存数据库）
    let result = with_db_connection(state, |conn| -> DbResult<()> {
        // 保存助记词到 settings 表（用于用户查看）
        conn.execute(
            "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
            ["recovery_mnemonic", &mnemonic],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        // 从助记词派生密钥并计算哈希（用于验证）
        let mnemonic_key = mnemonic_to_key(mnemonic)
            .map_err(|e| DbError::DatabaseError(format!("助记词派生密钥失败: {}", e)))?;

        let mnemonic_key_hash = Sha256::digest(&mnemonic_key);
        let mnemonic_key_hash_hex = hex::encode(&mnemonic_key_hash);

        // 保存助记词密钥哈希
        conn.execute(
            "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
            ["mnemonic_key_hash", &mnemonic_key_hash_hex],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        write_log(&format!("助记词密钥哈希已保存: {}", &mnemonic_key_hash_hex[..8]));
        Ok(())
    });

    match result {
        Ok(_) => FfiErrorCode::Success as c_int,
        Err(_) => FfiErrorCode::DatabaseError as c_int,
    }
}

/// 获取资产类型枚举值（仅处理资产类型，0-4）
fn asset_type_from_int(value: c_int) -> AssetType {
    match value {
        0 => AssetType::Property,
        1 => AssetType::Deposit,
        2 => AssetType::Stock,
        3 => AssetType::Fund,
        4 => AssetType::Insurance,
        _ => AssetType::Stock,
    }
}

/// 添加资产
#[no_mangle]
pub unsafe extern "C" fn add_asset(
    name: *const c_char,
    asset_type: c_int,
    amount: c_double,
    currency: *const c_char,
    symbol: *const c_char,
    notes: *const c_char,
    occurrence_date: *const c_char,
) -> c_int {
    let name = match CStr::from_ptr(name).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    // 将整数类型转换为字符串
    let asset_type_enum = asset_type_from_int(asset_type);
    let asset_type_str = asset_type_enum.as_str().to_string();

    let currency = match CStr::from_ptr(currency).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let _symbol = if symbol.is_null() {
        None
    } else {
        match CStr::from_ptr(symbol).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let note = if notes.is_null() {
        None
    } else {
        match CStr::from_ptr(notes).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let occurrence_date = if occurrence_date.is_null() {
        // 默认为今天
        chrono::Utc::now().format("%Y-%m-%d").to_string()
    } else {
        match CStr::from_ptr(occurrence_date).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    let asset = Asset::new(asset_type_str, name, amount);
    let asset = Asset {
        currency,
        account: _symbol,
        note,
        occurrence_date,
        ..asset
    };

    let _asset_id = match with_db_connection(&state, |conn| -> DbResult<String> {
        let id = AssetRepository::create(conn, &asset)?;

        // 记录审计日志
        let change = AssetChange::new(id.clone(), ChangeType::Created)
            .with_created_snapshot(&asset);
        let _ = AssetChangeRepository::create(conn, &change);

        Ok(id)
    }) {
        Ok(id) => id,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    FfiErrorCode::Success as c_int
}

/// 获取所有资产（JSON 格式）
#[no_mangle]
pub unsafe extern "C" fn get_all_assets() -> *mut c_char {
    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return ptr::null_mut(),
    };

    let assets = match with_db_connection(&state, |conn| -> DbResult<Vec<Asset>> {
        AssetRepository::list(conn)
    }) {
        Ok(a) => a,
        Err(_) => return ptr::null_mut(),
    };

    match serde_json::to_string(&assets) {
        Ok(json) => string_to_c_char(json),
        Err(_) => ptr::null_mut(),
    }
}

/// 更新资产
#[no_mangle]
pub unsafe extern "C" fn update_asset(
    id: *const c_char,
    name: *const c_char,
    asset_type: c_int,
    amount: c_double,
    currency: *const c_char,
    symbol: *const c_char,
    notes: *const c_char,
    occurrence_date: *const c_char,
) -> c_int {
    let id = match CStr::from_ptr(id).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let name = match CStr::from_ptr(name).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    // 将整数类型转换为字符串
    let asset_type_enum = asset_type_from_int(asset_type);
    let asset_type_str = asset_type_enum.as_str().to_string();

    let currency = match CStr::from_ptr(currency).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let _symbol = if symbol.is_null() {
        None
    } else {
        match CStr::from_ptr(symbol).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let note = if notes.is_null() {
        None
    } else {
        match CStr::from_ptr(notes).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let occurrence_date = if occurrence_date.is_null() {
        None
    } else {
        match CStr::from_ptr(occurrence_date).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 先获取现有资产
    let existing = match with_db_connection(&state, |conn| -> DbResult<Asset> {
        AssetRepository::get(conn, &id)
    }) {
        Ok(a) => a,
        Err(DbError::NotFound(_)) => return FfiErrorCode::NotFound as c_int,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 计算修改的字段
    let mut changed_fields = Vec::new();
    if existing.name != name { changed_fields.push("名称"); }
    if existing.amount != amount { changed_fields.push("金额"); }
    if existing.currency != currency { changed_fields.push("币种"); }
    if existing.account != _symbol { changed_fields.push("账户"); }
    if existing.asset_type != asset_type_str { changed_fields.push("类型"); }
    if occurrence_date.is_some() && existing.occurrence_date != *occurrence_date.as_ref().unwrap() {
        changed_fields.push("发生日期");
    }
    if existing.note != note { changed_fields.push("备注"); }

    // 克隆 id 用于后续使用
    let id_clone = id.clone();

    // 更新字段
    let asset = Asset {
        id,
        name,
        asset_type: asset_type_str,
        amount,
        currency,
        account: _symbol,
        note,
        occurrence_date: occurrence_date.unwrap_or_else(|| existing.occurrence_date.clone()),
        // 通用字段
        tags: existing.tags.clone(),
        // 投资类字段
        buy_price: existing.buy_price,
        current_price: existing.current_price,
        code: existing.code.clone(),
        exchange: existing.exchange.clone(),
        quantity: existing.quantity,
        // 房产字段
        address: existing.address.clone(),
        building_area: existing.building_area,
        living_area: existing.living_area,
        property_type: existing.property_type.clone(),
        rooms: existing.rooms,
        floor: existing.floor.clone(),
        build_year: existing.build_year,
        ownership_type: existing.ownership_type.clone(),
        deed_number: existing.deed_number.clone(),
        // 存款字段
        deposit_account_type: existing.deposit_account_type.clone(),
        deposit_period: existing.deposit_period,
        maturity_date: existing.maturity_date.clone(),
        deposit_interest_rate: existing.deposit_interest_rate,
        // 保单字段
        policy_number: existing.policy_number.clone(),
        insurance_type: existing.insurance_type.clone(),
        insured: existing.insured.clone(),
        beneficiary: existing.beneficiary.clone(),
        coverage_amount: existing.coverage_amount,
        premium: existing.premium,
        premium_period: existing.premium_period.clone(),
        coverage_period: existing.coverage_period.clone(),
        insurer: existing.insurer.clone(),
        // 时间戳
        created_at: existing.created_at,
        updated_at: existing.updated_at,
    };

    match with_db_connection(&state, |conn| -> DbResult<()> {
        AssetRepository::update(conn, &asset)?;

        // 记录审计日志
        let changed_field = if changed_fields.is_empty() {
            None
        } else if changed_fields.len() == 1 {
            Some(changed_fields[0].to_string())
        } else {
            Some(changed_fields.join(", "))
        };

        let change = AssetChange::new(id_clone, ChangeType::Updated)
            .with_updated_snapshots(&existing, &asset, changed_field);
        AssetChangeRepository::create(conn, &change)?;

        Ok(())
    }) {
        Ok(_) => FfiErrorCode::Success as c_int,
        Err(_) => FfiErrorCode::DatabaseError as c_int,
    }
}

/// 删除资产
#[no_mangle]
pub unsafe extern "C" fn delete_asset(id: *const c_char) -> c_int {
    let id = match CStr::from_ptr(id).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 先获取现有资产用于审计日志
    let existing = match with_db_connection(&state, |conn| -> DbResult<Asset> {
        AssetRepository::get(conn, &id)
    }) {
        Ok(a) => a,
        Err(DbError::NotFound(_)) => return FfiErrorCode::NotFound as c_int,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 先收集附件密文文件名（删资产后 CASCADE 会清掉记录，届时无从查起）
    let attachment_files: Vec<String> = with_db_connection(&state, |conn| -> DbResult<Vec<String>> {
        Ok(AttachmentRepository::list_by_asset(conn, &id)?
            .into_iter()
            .map(|a| a.encrypted_path)
            .collect())
    })
    .map_err(|e| {
        eprintln!("delete_asset: 收集附件文件名失败: {}", e);
        e
    })
    .unwrap_or_default();

    let delete_result = with_db_connection(&state, |conn| -> DbResult<()> {
        // 事务保证"删资产 + 写删除审计"原子完成，避免部分失败产生孤儿状态
        conn.execute_batch("BEGIN IMMEDIATE")
            .map_err(|e| DbError::DatabaseError(e.to_string()))?;
        let result = (|| -> DbResult<()> {
            AssetRepository::delete(conn, &id)?;

            // 记录审计日志
            let change = AssetChange::new(id.clone(), ChangeType::Deleted)
                .with_deleted_snapshot(&existing);
            AssetChangeRepository::create(conn, &change)?;

            Ok(())
        })();
        match result {
            Ok(_) => conn
                .execute_batch("COMMIT")
                .map_err(|e| DbError::DatabaseError(e.to_string())),
            Err(e) => {
                let _ = conn.execute_batch("ROLLBACK");
                Err(e)
            }
        }
    });

    match delete_result {
        Ok(_) => {
            // 级联清理附件密文文件（记录已随外键 CASCADE 删除）
            let dir = attachments_dir(&state.db_path);
            for name in attachment_files {
                if let Err(e) = delete_attachment_file(&dir, &name) {
                    eprintln!("delete_asset: 清理附件文件失败: {}", e);
                }
            }
            FfiErrorCode::Success as c_int
        }
        Err(DbError::NotFound(_)) => FfiErrorCode::NotFound as c_int,
        Err(e) => {
            eprintln!("delete_asset: 删除失败: {}", e);
            FfiErrorCode::DatabaseError as c_int
        }
    }
}

/// 导出数据
#[no_mangle]
pub unsafe extern "C" fn export_data(
    password: *const c_char,
    output_path: *const c_char,
) -> *mut c_char {
    let _password = match CStr::from_ptr(password).to_str() {
        Ok(s) => s,
        Err(_) => return string_to_c_char("{\"error\":\"Invalid password\"}".to_string()),
    };

    let output_path = match CStr::from_ptr(output_path).to_str() {
        Ok(s) => s,
        Err(_) => return string_to_c_char("{\"error\":\"Invalid path\"}".to_string()),
    };

    let state = APP_STATE.lock().unwrap();
    let _state = match state.as_ref() {
        Some(s) => s,
        None => return string_to_c_char("{\"error\":\"Not initialized\"}".to_string()),
    };

    // 读取数据库文件
    let db_data = match std::fs::read(&_state.db_path) {
        Ok(data) => data,
        Err(e) => return string_to_c_char(
            serde_json::json!({"error": format!("读取数据库失败: {}", e)}).to_string()
        ),
    };

    // 使用主密钥加密并导出
    let key = match _state.master_key.as_ref() {
        Some(k) if k.len() == 32 => {
            let mut arr = [0u8; 32];
            arr.copy_from_slice(k);
            arr
        }
        _ => return string_to_c_char(
            serde_json::json!({"error": "密钥未设置"}).to_string()
        ),
    };

    // 收集数据库登记的附件密文文件（随备份导出）
    let attachments: Vec<(String, Vec<u8>)> = match with_db_connection(&_state, |conn| -> DbResult<Vec<(String, Vec<u8>)>> {
        let mut result = Vec::new();
        let mut seen = std::collections::HashSet::new();
        for a in AttachmentRepository::list_all(conn)? {
            if a.encrypted_path.is_empty() || !seen.insert(a.encrypted_path.clone()) {
                continue;
            }
            let path = attachments_dir(&_state.db_path).join(&a.encrypted_path);
            match std::fs::read(&path) {
                Ok(data) => result.push((a.encrypted_path, data)),
                Err(e) => eprintln!("export_data: 读取附件 {} 失败（跳过）: {}", a.encrypted_path, e),
            }
        }
        Ok(result)
    }) {
        Ok(list) => list,
        Err(e) => {
            return string_to_c_char(
                serde_json::json!({"error": format!("读取附件失败: {}", e)}).to_string()
            );
        }
    };

    match crate::export::create_export_zip(&db_data, &attachments, std::path::Path::new(output_path), &key) {
        Ok(_) => string_to_c_char(
            serde_json::json!({"success": true, "path": output_path, "attachments": attachments.len()}).to_string()
        ),
        Err(e) => string_to_c_char(
            serde_json::json!({"error": format!("导出失败: {}", e)}).to_string()
        ),
    }
}

/// 导入数据
#[no_mangle]
pub unsafe extern "C" fn import_data(
    password: *const c_char,
    input_path: *const c_char,
) -> *mut c_char {
    let _password = match CStr::from_ptr(password).to_str() {
        Ok(s) => s,
        Err(_) => return string_to_c_char("{\"error\":\"Invalid password\"}".to_string()),
    };

    let _input_path = match CStr::from_ptr(input_path).to_str() {
        Ok(s) => s,
        Err(_) => return string_to_c_char("{\"error\":\"Invalid path\"}".to_string()),
    };

    let mut state = APP_STATE.lock().unwrap();
    let state = match state.as_mut() {
        Some(s) => s,
        None => return string_to_c_char(
            serde_json::json!({"error": "未初始化"}).to_string()
        ),
    };

    // 使用主密钥解密并导入
    let key = match state.master_key.as_ref() {
        Some(k) if k.len() == 32 => {
            let mut arr = [0u8; 32];
            arr.copy_from_slice(k);
            arr
        }
        _ => return string_to_c_char(
            serde_json::json!({"error": "密钥未设置"}).to_string()
        ),
    };

    match crate::export::import_from_zip(std::path::Path::new(_input_path), &key) {
        Ok(backup) => {
            // 写入数据库文件
            if let Err(e) = std::fs::write(&state.db_path, &backup.db_data) {
                return string_to_c_char(
                    serde_json::json!({"error": format!("写入数据库失败: {}", e)}).to_string()
                );
            }

            // 还原附件目录：导入即恢复到备份时点，先清空现有密文再写入备份内容
            let att_dir = attachments_dir(&state.db_path);
            if att_dir.exists() {
                if let Err(e) = std::fs::remove_dir_all(&att_dir) {
                    return string_to_c_char(
                        serde_json::json!({"error": format!("清理附件目录失败: {}", e)}).to_string()
                    );
                }
            }
            if let Err(e) = std::fs::create_dir_all(&att_dir) {
                return string_to_c_char(
                    serde_json::json!({"error": format!("创建附件目录失败: {}", e)}).to_string()
                );
            }
            for (file_name, data) in &backup.attachments {
                if let Err(e) = std::fs::write(att_dir.join(file_name), data) {
                    return string_to_c_char(
                        serde_json::json!({"error": format!("写入附件 {} 失败: {}", file_name, e)}).to_string()
                    );
                }
            }

            // 重载内存库:导入的数据必须立即可见,否则 UI 读到的仍是旧数据,
            // 且下一次 saveDatabase 会用内存旧数据覆盖掉刚导入的磁盘文件
            let new_conn = match load_encrypted_db(&state.db_path, &key) {
                Ok(c) => c,
                Err(e) => {
                    return string_to_c_char(
                        serde_json::json!({"error": format!("重载导入数据失败: {}", e)}).to_string()
                    );
                }
            };
            if let Err(e) = crate::db::init_db(&new_conn) {
                return string_to_c_char(
                    serde_json::json!({"error": format!("导入数据迁移失败: {}", e)}).to_string()
                );
            }
            state.memory_conn = Some(new_conn);
            state.is_dirty = false;

            string_to_c_char(
                serde_json::json!({"success": true, "imported": backup.db_data.len(), "attachments": backup.attachments.len()}).to_string()
            )
        }
        Err(e) => string_to_c_char(
            serde_json::json!({"error": format!("导入失败: {}", e)}).to_string()
        ),
    }
}

/// 获取所有资产变更记录（审计日志）
#[no_mangle]
pub unsafe extern "C" fn get_asset_changes() -> *mut c_char {
    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return ptr::null_mut(),
    };

    let changes = match with_db_connection(&state, |conn| -> DbResult<Vec<AssetChange>> {
        AssetChangeRepository::list_all(conn, Some(1000))
    }) {
        Ok(c) => c,
        Err(_) => return ptr::null_mut(),
    };

    match serde_json::to_string(&changes) {
        Ok(json) => string_to_c_char(json),
        Err(_) => ptr::null_mut(),
    }
}

/// 获取指定资产的变更记录
#[no_mangle]
pub unsafe extern "C" fn get_asset_changes_by_asset_id(asset_id: *const c_char) -> *mut c_char {
    let asset_id = match CStr::from_ptr(asset_id).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return ptr::null_mut(),
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return ptr::null_mut(),
    };

    let changes = match with_db_connection(&state, |conn| -> DbResult<Vec<AssetChange>> {
        AssetChangeRepository::list_by_asset(conn, &asset_id)
    }) {
        Ok(c) => c,
        Err(_) => return ptr::null_mut(),
    };

    match serde_json::to_string(&changes) {
        Ok(json) => string_to_c_char(json),
        Err(_) => ptr::null_mut(),
    }
}

/// 按名称搜索资产
#[no_mangle]
pub unsafe extern "C" fn search_assets_by_name(
    name_pattern: *const c_char,
    type_filter_json: *const c_char,
) -> *mut c_char {
    let name_pattern = match CStr::from_ptr(name_pattern).to_str() {
        Ok(s) => s,
        Err(_) => return ptr::null_mut(),
    };

    let type_filter_json = if type_filter_json.is_null() {
        "[]"
    } else {
        match CStr::from_ptr(type_filter_json).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        }
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return ptr::null_mut(),
    };

    // 解析类型过滤器 JSON数组 - 现在是字符串数组而不是整数数组
    let type_ids: Vec<String> = match serde_json::from_str(type_filter_json) {
        Ok(v) => v,
        Err(_) => return ptr::null_mut(),
    };

    match with_db_connection(&state, |conn| -> DbResult<Vec<Asset>> {
        AssetRepository::search_by_name(conn, name_pattern, &type_ids)
    }) {
        Ok(assets) => match serde_json::to_string(&assets) {
            Ok(json) => string_to_c_char(json),
            Err(_) => ptr::null_mut(),
        },
        Err(_) => ptr::null_mut(),
    }
}

/// 创建自定义资产类型
#[export_name = "create_custom_asset_type"]
pub unsafe extern "C" fn create_custom_asset_type(
    name: *const c_char,
    icon_name: *const c_char,
    is_liability: c_int,
) -> *mut c_char {
    let name = match CStr::from_ptr(name).to_str() {
        Ok(s) => s,
        Err(_) => return string_to_c_char("{\"error\":\"Invalid name\"}".to_string()),
    };
    let icon_name = match CStr::from_ptr(icon_name).to_str() {
        Ok(s) => s,
        Err(_) => return string_to_c_char("{\"error\":\"Invalid icon_name\"}".to_string()),
    };

    let custom_type = CustomAssetType::new(
        name.to_string(),
        icon_name.to_string(),
        is_liability != 0,
    );

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return string_to_c_char("{\"error\":\"Not initialized\"}".to_string()),
    };

    match with_db_connection(&state, |conn| -> DbResult<()> {
        CustomTypeRepository::create(conn, &custom_type)
    }) {
        Ok(_) => string_to_c_char(json!({"id": custom_type.id, "success": true}).to_string()),
        Err(e) => string_to_c_char(json!({"error": format!("{}", e)}).to_string()),
    }
}

/// 获取所有自定义类型
#[export_name = "get_custom_asset_types"]
pub unsafe extern "C" fn get_custom_asset_types() -> *mut c_char {
    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return string_to_c_char("[]".to_string()),
    };

    match with_db_connection(&state, |conn| -> DbResult<Vec<CustomAssetType>> {
        CustomTypeRepository::get_all(conn)
    }) {
        Ok(types) => string_to_c_char(serde_json::to_string(&types).unwrap_or_else(|_| "[]".to_string())),
        Err(_) => string_to_c_char("[]".to_string()),
    }
}

/// 删除自定义类型
#[export_name = "delete_custom_asset_type"]
pub unsafe extern "C" fn delete_custom_asset_type(id: *const c_char) -> c_int {
    let id = match CStr::from_ptr(id).to_str() {
        Ok(s) => s,
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    match with_db_connection(&state, |conn| -> DbResult<()> {
        CustomTypeRepository::delete(conn, id)
    }) {
        Ok(_) => FfiErrorCode::Success as c_int,
        Err(DbError::NotFound(_)) => FfiErrorCode::NotFound as c_int,
        Err(_) => FfiErrorCode::DatabaseError as c_int,
    }
}

/// 检查自定义类型是否被使用
#[export_name = "is_custom_type_in_use"]
pub unsafe extern "C" fn is_custom_type_in_use(id: *const c_char) -> c_int {
    let id = match CStr::from_ptr(id).to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return -1,
    };

    match with_db_connection(&state, |conn| -> DbResult<bool> {
        CustomTypeRepository::is_in_use(conn, id)
    }) {
        Ok(true) => 1,
        Ok(false) => 0,
        Err(_) => -1,
    }
}

/// 添加资产（使用字符串类型）
#[no_mangle]
pub unsafe extern "C" fn add_asset_with_type(
    name: *const c_char,
    asset_type: *const c_char,
    amount: c_double,
    currency: *const c_char,
    symbol: *const c_char,
    notes: *const c_char,
    occurrence_date: *const c_char,
    buy_price: c_double,
    current_price: c_double,
    tags_json: *const c_char,
) -> c_int {
    let name = match CStr::from_ptr(name).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let asset_type = match CStr::from_ptr(asset_type).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let currency = match CStr::from_ptr(currency).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let _symbol = if symbol.is_null() {
        None
    } else {
        match CStr::from_ptr(symbol).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let note = if notes.is_null() {
        None
    } else {
        match CStr::from_ptr(notes).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let occurrence_date = if occurrence_date.is_null() {
        chrono::Utc::now().format("%Y-%m-%d").to_string()
    } else {
        match CStr::from_ptr(occurrence_date).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    // 解析买入价（NaN 表示未设置）
    eprintln!("========== add_asset_with_type ==========");
    eprintln!("接收到 buy_price = {}, is_nan = {}", buy_price, buy_price.is_nan());
    write_log(&format!("========== add_asset_with_type ==========\n接收到 buy_price = {}, is_nan = {}", buy_price, buy_price.is_nan()));
    let buy_price = if buy_price.is_nan() {
        eprintln!("买入价未设置（NaN）");
        write_log("买入价未设置（NaN）\n");
        None
    } else {
        eprintln!("买入价设置为: {}", buy_price);
        write_log(&format!("买入价设置为: {}\n", buy_price));
        Some(buy_price)
    };

    // 解析现价（NaN 表示未设置）
    eprintln!("接收到 current_price = {}, is_nan = {}", current_price, current_price.is_nan());
    write_log(&format!("接收到 current_price = {}, is_nan = {}\n", current_price, current_price.is_nan()));
    let current_price = if current_price.is_nan() {
        eprintln!("现价未设置（NaN）");
        write_log("现价未设置（NaN）\n");
        None
    } else {
        eprintln!("现价设置为: {}", current_price);
        write_log(&format!("现价设置为: {}\n", current_price));
        Some(current_price)
    };

    // 解析标签（JSON 字符串）
    let tags = if tags_json.is_null() {
        None
    } else {
        match CStr::from_ptr(tags_json).to_str() {
            Ok(s) => {
                if s.is_empty() {
                    None
                } else {
                    serde_json::from_str(s).ok()
                }
            },
            Err(_) => None,
        }
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    let asset = Asset::new(asset_type.clone(), name, amount);
    let asset = Asset {
        currency,
        account: _symbol,
        note,
        occurrence_date,
        buy_price,
        current_price,
        tags,
        ..asset
    };

    write_log(&format!("创建 Asset 对象: buy_price = {:?}, current_price = {:?}\n", asset.buy_price, asset.current_price));
    write_log(&format!("资产 ID = {}, 名称 = {}\n", asset.id, asset.name));

    let _asset_id = match with_db_connection(&state, |conn| -> DbResult<String> {
        let id = AssetRepository::create(conn, &asset)?;

        write_log(&format!("数据库插入成功，资产 ID = {}\n", id));

        // 立即读取验证
        match AssetRepository::get(conn, &id) {
            Ok(read_asset) => {
                write_log(&format!("验证读取: buy_price = {:?}, current_price = {:?}\n", read_asset.buy_price, read_asset.current_price));
            },
            Err(e) => {
                write_log(&format!("验证读取失败: {}\n", e));
            }
        }

        // 记录审计日志
        let change = AssetChange::new(id.clone(), ChangeType::Created)
            .with_created_snapshot(&asset);
        AssetChangeRepository::create(conn, &change)?;

        Ok(id)
    }) {
        Ok(id) => id,
        Err(e) => {
            write_log(&format!("数据库插入失败: {}\n", e));
            return FfiErrorCode::DatabaseError as c_int;
        }
    };

    write_log("========== add_asset_with_type 结束 ==========\n");

    FfiErrorCode::Success as c_int
}

/// 更新资产（使用字符串类型）
#[no_mangle]
pub unsafe extern "C" fn update_asset_with_type(
    id: *const c_char,
    name: *const c_char,
    asset_type: *const c_char,
    amount: c_double,
    currency: *const c_char,
    symbol: *const c_char,
    notes: *const c_char,
    occurrence_date: *const c_char,
    buy_price: c_double,
    current_price: c_double,
    tags_json: *const c_char,
) -> c_int {
    let id = match CStr::from_ptr(id).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let name = match CStr::from_ptr(name).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let asset_type = match CStr::from_ptr(asset_type).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let currency = match CStr::from_ptr(currency).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let _symbol = if symbol.is_null() {
        None
    } else {
        match CStr::from_ptr(symbol).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let note = if notes.is_null() {
        None
    } else {
        match CStr::from_ptr(notes).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let occurrence_date = if occurrence_date.is_null() {
        None
    } else {
        match CStr::from_ptr(occurrence_date).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    // 解析买入价（NaN 表示未设置）
    let buy_price = if buy_price.is_nan() {
        None
    } else {
        Some(buy_price)
    };

    // 解析现价（NaN 表示未设置）
    let current_price = if current_price.is_nan() {
        None
    } else {
        Some(current_price)
    };

    // 解析标签（JSON 字符串）
    let tags = if tags_json.is_null() {
        None
    } else {
        match CStr::from_ptr(tags_json).to_str() {
            Ok(s) => {
                if s.is_empty() {
                    None
                } else {
                    serde_json::from_str(s).ok()
                }
            },
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 先获取现有资产
    let existing = match with_db_connection(&state, |conn| -> DbResult<Asset> {
        AssetRepository::get(conn, &id)
    }) {
        Ok(a) => a,
        Err(DbError::NotFound(_)) => return FfiErrorCode::NotFound as c_int,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 计算修改的字段
    let mut changed_fields = Vec::new();
    if existing.name != name { changed_fields.push("名称"); }
    if existing.amount != amount { changed_fields.push("金额"); }
    if existing.currency != currency { changed_fields.push("币种"); }
    if existing.account != _symbol { changed_fields.push("账户"); }
    if existing.asset_type != asset_type { changed_fields.push("类型"); }
    if occurrence_date.is_some() && existing.occurrence_date != *occurrence_date.as_ref().unwrap() {
        changed_fields.push("发生日期");
    }
    if existing.note != note { changed_fields.push("备注"); }
    if existing.buy_price != buy_price { changed_fields.push("买入价"); }
    if existing.current_price != current_price { changed_fields.push("现价"); }
    if existing.tags != tags { changed_fields.push("标签"); }

    let id_clone = id.clone();

    let asset = Asset {
        id,
        name,
        asset_type,
        amount,
        currency,
        account: _symbol,
        note,
        occurrence_date: occurrence_date.unwrap_or_else(|| existing.occurrence_date.clone()),
        // 通用字段
        tags,
        // 投资类字段
        buy_price,
        current_price,
        code: existing.code.clone(),
        exchange: existing.exchange.clone(),
        quantity: existing.quantity,
        // 房产字段
        address: existing.address.clone(),
        building_area: existing.building_area,
        living_area: existing.living_area,
        property_type: existing.property_type.clone(),
        rooms: existing.rooms,
        floor: existing.floor.clone(),
        build_year: existing.build_year,
        ownership_type: existing.ownership_type.clone(),
        deed_number: existing.deed_number.clone(),
        // 存款字段
        deposit_account_type: existing.deposit_account_type.clone(),
        deposit_period: existing.deposit_period,
        maturity_date: existing.maturity_date.clone(),
        deposit_interest_rate: existing.deposit_interest_rate,
        // 保单字段
        policy_number: existing.policy_number.clone(),
        insurance_type: existing.insurance_type.clone(),
        insured: existing.insured.clone(),
        beneficiary: existing.beneficiary.clone(),
        coverage_amount: existing.coverage_amount,
        premium: existing.premium,
        premium_period: existing.premium_period.clone(),
        coverage_period: existing.coverage_period.clone(),
        insurer: existing.insurer.clone(),
        // 时间戳
        created_at: existing.created_at,
        updated_at: existing.updated_at,
    };

    match with_db_connection(&state, |conn| -> DbResult<()> {
        AssetRepository::update(conn, &asset)?;

        // 记录审计日志
        let changed_field = if changed_fields.is_empty() {
            None
        } else if changed_fields.len() == 1 {
            Some(changed_fields[0].to_string())
        } else {
            Some(changed_fields.join(", "))
        };

        let change = AssetChange::new(id_clone, ChangeType::Updated)
            .with_updated_snapshots(&existing, &asset, changed_field);
        AssetChangeRepository::create(conn, &change)?;

        Ok(())
    }) {
        Ok(_) => FfiErrorCode::Success as c_int,
        Err(_) => FfiErrorCode::DatabaseError as c_int,
    }
}

/// 添加资产（支持扩展字段）
#[no_mangle]
pub unsafe extern "C" fn add_asset_with_extra_fields(
    name: *const c_char,
    asset_type: *const c_char,
    amount: c_double,
    currency: *const c_char,
    occurrence_date: *const c_char,
    extra_fields_json: *const c_char,
    note: *const c_char,
) -> c_int {
    let name = match CStr::from_ptr(name).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let asset_type = match CStr::from_ptr(asset_type).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let currency = match CStr::from_ptr(currency).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let occurrence_date = if occurrence_date.is_null() {
        chrono::Utc::now().format("%Y-%m-%d").to_string()
    } else {
        match CStr::from_ptr(occurrence_date).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    // 解析 extra_fields_json
    let extra_fields = if extra_fields_json.is_null() {
        None
    } else {
        match CStr::from_ptr(extra_fields_json).to_str() {
            Ok(s) => {
                if s.is_empty() {
                    None
                } else {
                    Some(s)
                }
            },
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let note = if note.is_null() {
        None
    } else {
        match CStr::from_ptr(note).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 创建基础资产对象
    let mut asset = Asset::new(asset_type.clone(), name, amount);
    asset.currency = currency;
    asset.occurrence_date = occurrence_date;
    asset.note = note;

    // 解析扩展字段
    if let Some(json_str) = extra_fields {
        if let Ok(value) = serde_json::from_str::<serde_json::Value>(json_str) {
            if let Some(obj) = value.as_object() {
                // 通用字段
                if let Some(v) = obj.get("account").and_then(|v| v.as_str()) {
                    asset.account = Some(v.to_string());
                }
                if let Some(v) = obj.get("tags").and_then(|v| as_vec_string(v)) {
                    asset.tags = Some(v);
                }

                // 投资类专属字段
                if let Some(v) = obj.get("buy_price").and_then(|v| v.as_f64()) {
                    asset.buy_price = Some(v);
                }
                if let Some(v) = obj.get("current_price").and_then(|v| v.as_f64()) {
                    asset.current_price = Some(v);
                }
                if let Some(v) = obj.get("quantity").and_then(|v| v.as_i64()) {
                    asset.quantity = Some(v as i32);
                }
                // 投资类专属字段 - code 和 exchange
                if let Some(v) = obj.get("code").and_then(|v| v.as_str()) {
                    asset.code = Some(v.to_string());
                }
                if let Some(v) = obj.get("exchange").and_then(|v| v.as_str()) {
                    asset.exchange = Some(v.to_string());
                }

                // 房产专属字段
                if let Some(v) = obj.get("address").and_then(|v| v.as_str()) {
                    asset.address = Some(v.to_string());
                }
                if let Some(v) = obj.get("building_area").and_then(|v| v.as_f64()) {
                    asset.building_area = Some(v);
                }
                if let Some(v) = obj.get("living_area").and_then(|v| v.as_f64()) {
                    asset.living_area = Some(v);
                }
                if let Some(v) = obj.get("property_type").and_then(|v| v.as_str()) {
                    asset.property_type = Some(v.to_string());
                }
                if let Some(v) = obj.get("rooms").and_then(|v| v.as_i64()) {
                    asset.rooms = Some(v as i32);
                }
                if let Some(v) = obj.get("floor").and_then(|v| v.as_str()) {
                    asset.floor = Some(v.to_string());
                }
                if let Some(v) = obj.get("build_year").and_then(|v| v.as_i64()) {
                    asset.build_year = Some(v as i32);
                }
                if let Some(v) = obj.get("ownership_type").and_then(|v| v.as_str()) {
                    asset.ownership_type = Some(v.to_string());
                }
                if let Some(v) = obj.get("deed_number").and_then(|v| v.as_str()) {
                    asset.deed_number = Some(v.to_string());
                }

                // 存款专属字段
                if let Some(v) = obj.get("deposit_account_type").and_then(|v| v.as_str()) {
                    asset.deposit_account_type = Some(v.to_string());
                }
                if let Some(v) = obj.get("deposit_period").and_then(|v| v.as_i64()) {
                    asset.deposit_period = Some(v as i32);
                }
                if let Some(v) = obj.get("maturity_date").and_then(|v| v.as_str()) {
                    asset.maturity_date = Some(v.to_string());
                }
                if let Some(v) = obj.get("deposit_interest_rate").and_then(|v| v.as_f64()) {
                    asset.deposit_interest_rate = Some(v);
                }

                // 保单专属字段
                if let Some(v) = obj.get("policy_number").and_then(|v| v.as_str()) {
                    asset.policy_number = Some(v.to_string());
                }
                if let Some(v) = obj.get("insurance_type").and_then(|v| v.as_str()) {
                    asset.insurance_type = Some(v.to_string());
                }
                if let Some(v) = obj.get("insured").and_then(|v| v.as_str()) {
                    asset.insured = Some(v.to_string());
                }
                if let Some(v) = obj.get("beneficiary").and_then(|v| v.as_str()) {
                    asset.beneficiary = Some(v.to_string());
                }
                if let Some(v) = obj.get("coverage_amount").and_then(|v| v.as_f64()) {
                    asset.coverage_amount = Some(v);
                }
                if let Some(v) = obj.get("premium").and_then(|v| v.as_f64()) {
                    asset.premium = Some(v);
                }
                if let Some(v) = obj.get("premium_period").and_then(|v| v.as_str()) {
                    asset.premium_period = Some(v.to_string());
                }
                if let Some(v) = obj.get("coverage_period").and_then(|v| v.as_str()) {
                    asset.coverage_period = Some(v.to_string());
                }
                if let Some(v) = obj.get("insurer").and_then(|v| v.as_str()) {
                    asset.insurer = Some(v.to_string());
                }
            }
        }
    }

    let asset_id = match with_db_connection(&state, |conn| {
        AssetRepository::create(conn, &asset)
    }) {
        Ok(id) => id,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 记录审计日志
    let change = AssetChange::new(asset_id.clone(), ChangeType::Created)
        .with_created_snapshot(&asset);
    let _ = with_db_connection(&state, |conn| {
        AssetChangeRepository::create(conn, &change)
    });

    FfiErrorCode::Success as c_int
}

/// 辅助函数：将 JSON Value 转换为 Vec<String>
fn as_vec_string(value: &serde_json::Value) -> Option<Vec<String>> {
    value.as_array().and_then(|arr| {
        let mut result = Vec::new();
        for item in arr {
            if let Some(s) = item.as_str() {
                result.push(s.to_string());
            }
        }
        if result.is_empty() {
            None
        } else {
            Some(result)
        }
    })
}

/// 获取仅资产（不包括负债）
#[no_mangle]
pub unsafe extern "C" fn get_assets_only() -> *mut c_char {
    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => {
            eprintln!("get_assets_only: state 为空");
            return ptr::null_mut();
        }
    };

    eprintln!("get_assets_only: 检查状态 - master_key: {}, memory_conn: {}",
        state.master_key.is_some(),
        state.memory_conn.is_some());

    let assets = match with_db_connection(&state, |conn| -> DbResult<Vec<Asset>> {
        AssetRepository::list(conn)
    }) {
        Ok(a) => {
            eprintln!("get_assets_only: 成功获取 {} 个资产", a.len());
            a
        }
        Err(e) => {
            eprintln!("get_assets_only: 获取资产失败: {}", e);
            return ptr::null_mut();
        }
    };

    match serde_json::to_string(&assets) {
        Ok(json) => {
            eprintln!("get_assets_only: JSON 序列化成功，长度: {}", json.len());
            string_to_c_char(json)
        }
        Err(e) => {
            eprintln!("get_assets_only: JSON 序列化失败: {}", e);
            ptr::null_mut()
        }
    }
}

/// 获取仅负债（不包括资产）
#[no_mangle]
pub unsafe extern "C" fn get_liabilities_only() -> *mut c_char {
    eprintln!("get_liabilities_only: 被调用");
    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => {
            eprintln!("get_liabilities_only: state 为空");
            return ptr::null_mut();
        }
    };

    eprintln!("get_liabilities_only: 检查状态 - master_key: {}, memory_conn: {}",
        state.master_key.is_some(),
        state.memory_conn.is_some());

    let liabilities = match with_db_connection(&state, |conn| -> DbResult<Vec<Liability>> {
        LiabilityRepository::list(conn)
    }) {
        Ok(l) => {
            eprintln!("get_liabilities_only: 成功获取 {} 个负债", l.len());
            l
        }
        Err(e) => {
            eprintln!("get_liabilities_only: 获取负债失败: {}", e);
            return ptr::null_mut();
        }
    };

    match serde_json::to_string(&liabilities) {
        Ok(json) => {
            eprintln!("get_liabilities_only: JSON 序列化成功，长度: {}", json.len());
            string_to_c_char(json)
        }
        Err(e) => {
            eprintln!("get_liabilities_only: JSON 序列化失败: {}", e);
            ptr::null_mut()
        }
    }
}

/// 根据 ID 获取单个资产
#[no_mangle]
pub unsafe extern "C" fn get_asset_by_id(id: *const c_char) -> *mut c_char {
    let id = match CStr::from_ptr(id).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return ptr::null_mut(),
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return ptr::null_mut(),
    };

    match with_db_connection(&state, |conn| -> DbResult<Asset> {
        AssetRepository::get(conn, &id)
    }) {
        Ok(asset) => match serde_json::to_string(&asset) {
            Ok(json) => string_to_c_char(json),
            Err(_) => ptr::null_mut(),
        },
        Err(DbError::NotFound(_)) => ptr::null_mut(),
        Err(_) => ptr::null_mut(),
    }
}

/// 更新资产（支持扩展字段）
#[no_mangle]
pub unsafe extern "C" fn update_asset_with_extra_fields(
    id: *const c_char,
    name: *const c_char,
    asset_type: *const c_char,
    amount: c_double,
    currency: *const c_char,
    occurrence_date: *const c_char,
    extra_fields_json: *const c_char,
    note: *const c_char,
) -> c_int {
    let id = match CStr::from_ptr(id).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let name = match CStr::from_ptr(name).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let asset_type = match CStr::from_ptr(asset_type).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let currency = match CStr::from_ptr(currency).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let occurrence_date = if occurrence_date.is_null() {
        None
    } else {
        match CStr::from_ptr(occurrence_date).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    // 解析 extra_fields_json
    let extra_fields = if extra_fields_json.is_null() {
        None
    } else {
        match CStr::from_ptr(extra_fields_json).to_str() {
            Ok(s) => {
                if s.is_empty() {
                    None
                } else {
                    Some(s)
                }
            },
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let note = if note.is_null() {
        None
    } else {
        match CStr::from_ptr(note).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 先获取现有资产
    let existing = match with_db_connection(&state, |conn| -> DbResult<Asset> {
        AssetRepository::get(conn, &id)
    }) {
        Ok(a) => a,
        Err(DbError::NotFound(_)) => return FfiErrorCode::NotFound as c_int,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 计算修改的字段（在移动变量之前）
    let mut changed_fields = Vec::new();
    if existing.name != name { changed_fields.push("名称"); }
    if existing.amount != amount { changed_fields.push("金额"); }
    if existing.currency != currency { changed_fields.push("币种"); }
    if existing.asset_type != asset_type { changed_fields.push("类型"); }
    if occurrence_date.is_some() && existing.occurrence_date != *occurrence_date.as_ref().unwrap() {
        changed_fields.push("发生日期");
    }
    if existing.note != note { changed_fields.push("备注"); }

    // 创建基础更新对象
    let mut asset = Asset {
        id: id.clone(),
        name: name.clone(),
        asset_type: asset_type.clone(),
        amount,
        currency: currency.clone(),
        occurrence_date: occurrence_date.clone().unwrap_or_else(|| existing.occurrence_date.clone()),
        note: note.clone(),
        // 默认保留现有值
        account: existing.account.clone(),
        tags: existing.tags.clone(),
        buy_price: existing.buy_price,
        current_price: existing.current_price,
        code: existing.code.clone(),
        exchange: existing.exchange.clone(),
        quantity: existing.quantity,
        address: existing.address.clone(),
        building_area: existing.building_area,
        living_area: existing.living_area,
        property_type: existing.property_type.clone(),
        rooms: existing.rooms,
        floor: existing.floor.clone(),
        build_year: existing.build_year,
        ownership_type: existing.ownership_type.clone(),
        deed_number: existing.deed_number.clone(),
        deposit_account_type: existing.deposit_account_type.clone(),
        deposit_period: existing.deposit_period,
        maturity_date: existing.maturity_date.clone(),
        deposit_interest_rate: existing.deposit_interest_rate,
        policy_number: existing.policy_number.clone(),
        insurance_type: existing.insurance_type.clone(),
        insured: existing.insured.clone(),
        beneficiary: existing.beneficiary.clone(),
        coverage_amount: existing.coverage_amount,
        premium: existing.premium,
        premium_period: existing.premium_period.clone(),
        coverage_period: existing.coverage_period.clone(),
        insurer: existing.insurer.clone(),
        created_at: existing.created_at,
        updated_at: existing.updated_at,
    };

    // 解析扩展字段并更新
    if let Some(json_str) = extra_fields {
        if let Ok(value) = serde_json::from_str::<serde_json::Value>(json_str) {
            if let Some(obj) = value.as_object() {
                // 通用字段
                if let Some(v) = obj.get("account").and_then(|v| v.as_str()) {
                    asset.account = Some(v.to_string());
                }
                if let Some(v) = obj.get("tags").and_then(|v| as_vec_string(v)) {
                    asset.tags = Some(v);
                }

                // 投资类专属字段
                if let Some(v) = obj.get("buy_price").and_then(|v| v.as_f64()) {
                    asset.buy_price = Some(v);
                }
                if let Some(v) = obj.get("current_price").and_then(|v| v.as_f64()) {
                    asset.current_price = Some(v);
                }
                if let Some(v) = obj.get("quantity").and_then(|v| v.as_i64()) {
                    asset.quantity = Some(v as i32);
                }
                // 投资类专属字段 - code 和 exchange
                if let Some(v) = obj.get("code").and_then(|v| v.as_str()) {
                    asset.code = Some(v.to_string());
                }
                if let Some(v) = obj.get("exchange").and_then(|v| v.as_str()) {
                    asset.exchange = Some(v.to_string());
                }

                // 房产专属字段
                if let Some(v) = obj.get("address").and_then(|v| v.as_str()) {
                    asset.address = Some(v.to_string());
                }
                if let Some(v) = obj.get("building_area").and_then(|v| v.as_f64()) {
                    asset.building_area = Some(v);
                }
                if let Some(v) = obj.get("living_area").and_then(|v| v.as_f64()) {
                    asset.living_area = Some(v);
                }
                if let Some(v) = obj.get("property_type").and_then(|v| v.as_str()) {
                    asset.property_type = Some(v.to_string());
                }
                if let Some(v) = obj.get("rooms").and_then(|v| v.as_i64()) {
                    asset.rooms = Some(v as i32);
                }
                if let Some(v) = obj.get("floor").and_then(|v| v.as_str()) {
                    asset.floor = Some(v.to_string());
                }
                if let Some(v) = obj.get("build_year").and_then(|v| v.as_i64()) {
                    asset.build_year = Some(v as i32);
                }
                if let Some(v) = obj.get("ownership_type").and_then(|v| v.as_str()) {
                    asset.ownership_type = Some(v.to_string());
                }
                if let Some(v) = obj.get("deed_number").and_then(|v| v.as_str()) {
                    asset.deed_number = Some(v.to_string());
                }

                // 存款专属字段
                if let Some(v) = obj.get("deposit_account_type").and_then(|v| v.as_str()) {
                    asset.deposit_account_type = Some(v.to_string());
                }
                if let Some(v) = obj.get("deposit_period").and_then(|v| v.as_i64()) {
                    asset.deposit_period = Some(v as i32);
                }
                if let Some(v) = obj.get("maturity_date").and_then(|v| v.as_str()) {
                    asset.maturity_date = Some(v.to_string());
                }
                if let Some(v) = obj.get("deposit_interest_rate").and_then(|v| v.as_f64()) {
                    asset.deposit_interest_rate = Some(v);
                }

                // 保单专属字段
                if let Some(v) = obj.get("policy_number").and_then(|v| v.as_str()) {
                    asset.policy_number = Some(v.to_string());
                }
                if let Some(v) = obj.get("insurance_type").and_then(|v| v.as_str()) {
                    asset.insurance_type = Some(v.to_string());
                }
                if let Some(v) = obj.get("insured").and_then(|v| v.as_str()) {
                    asset.insured = Some(v.to_string());
                }
                if let Some(v) = obj.get("beneficiary").and_then(|v| v.as_str()) {
                    asset.beneficiary = Some(v.to_string());
                }
                if let Some(v) = obj.get("coverage_amount").and_then(|v| v.as_f64()) {
                    asset.coverage_amount = Some(v);
                }
                if let Some(v) = obj.get("premium").and_then(|v| v.as_f64()) {
                    asset.premium = Some(v);
                }
                if let Some(v) = obj.get("premium_period").and_then(|v| v.as_str()) {
                    asset.premium_period = Some(v.to_string());
                }
                if let Some(v) = obj.get("coverage_period").and_then(|v| v.as_str()) {
                    asset.coverage_period = Some(v.to_string());
                }
                if let Some(v) = obj.get("insurer").and_then(|v| v.as_str()) {
                    asset.insurer = Some(v.to_string());
                }
            }
        }
    }

    match with_db_connection(&state, |conn| -> DbResult<()> {
        AssetRepository::update(conn, &asset)?;

        // 在解析扩展字段后，检查扩展字段的变化
        let mut extended_changed_fields = changed_fields.clone();
        if existing.account != asset.account { extended_changed_fields.push("账户"); }
        if existing.buy_price != asset.buy_price { extended_changed_fields.push("买入价"); }
        if existing.current_price != asset.current_price { extended_changed_fields.push("现价"); }
        if existing.tags != asset.tags { extended_changed_fields.push("标签"); }

        let changed_field = if extended_changed_fields.is_empty() {
            None
        } else if extended_changed_fields.len() == 1 {
            Some(extended_changed_fields[0].to_string())
        } else {
            Some(extended_changed_fields.join(", "))
        };

        // 记录审计日志
        let change = AssetChange::new(asset.id.clone(), ChangeType::Updated)
            .with_updated_snapshots(&existing, &asset, changed_field);
        AssetChangeRepository::create(conn, &change)?;

        Ok(())
    }) {
        Ok(_) => FfiErrorCode::Success as c_int,
        Err(e) => {
            eprintln!("更新资产失败: {}", e);
            FfiErrorCode::DatabaseError as c_int
        }
    }
}

// ============================================================
// 负债相关 FFI 函数
// ============================================================

/// 获取所有负债（JSON 格式）
#[no_mangle]
pub unsafe extern "C" fn get_all_liabilities() -> *mut c_char {
    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return ptr::null_mut(),
    };

    let liabilities = match with_db_connection(&state, |conn| -> DbResult<Vec<Liability>> {
        LiabilityRepository::list(conn)
    }) {
        Ok(l) => l,
        Err(_) => return ptr::null_mut(),
    };

    match serde_json::to_string(&liabilities) {
        Ok(json) => string_to_c_char(json),
        Err(_) => ptr::null_mut(),
    }
}

/// 添加负债（支持扩展字段）
#[no_mangle]
pub unsafe extern "C" fn add_liability_with_extra_fields(
    name: *const c_char,
    liability_type: *const c_char,
    amount: c_double,
    currency: *const c_char,
    occurrence_date: *const c_char,
    extra_fields_json: *const c_char,
    note: *const c_char,
) -> c_int {
    let name = match CStr::from_ptr(name).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let liability_type = match CStr::from_ptr(liability_type).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let currency = match CStr::from_ptr(currency).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let occurrence_date = if occurrence_date.is_null() {
        chrono::Utc::now().format("%Y-%m-%d").to_string()
    } else {
        match CStr::from_ptr(occurrence_date).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    // 解析 extra_fields_json
    let extra_fields = if extra_fields_json.is_null() {
        None
    } else {
        match CStr::from_ptr(extra_fields_json).to_str() {
            Ok(s) => {
                if s.is_empty() {
                    None
                } else {
                    Some(s)
                }
            },
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let note = if note.is_null() {
        None
    } else {
        match CStr::from_ptr(note).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 解析扩展字段
    let mut liability = Liability::new(liability_type.clone(), name, amount);
    liability.currency = currency;
    liability.occurrence_date = occurrence_date;
    liability.note = note;

    if let Some(json_str) = extra_fields {
        if let Ok(value) = serde_json::from_str::<serde_json::Value>(json_str) {
            if let Some(obj) = value.as_object() {
                // 贷款类通用字段
                if let Some(v) = obj.get("lender").and_then(|v| v.as_str()) {
                    liability.lender = Some(v.to_string());
                }
                if let Some(v) = obj.get("due_date").and_then(|v| v.as_str()) {
                    liability.due_date = Some(v.to_string());
                }
                if let Some(v) = obj.get("interest_rate").and_then(|v| v.as_f64()) {
                    liability.interest_rate = Some(v);
                }
                if let Some(v) = obj.get("repayment_method").and_then(|v| v.as_str()) {
                    liability.repayment_method = Some(v.to_string());
                }
                if let Some(v) = obj.get("loan_term").and_then(|v| v.as_i64()) {
                    liability.loan_term = Some(v as i32);
                }

                // 信用卡专属字段
                if let Some(v) = obj.get("last_four_digits").and_then(|v| v.as_str()) {
                    liability.last_four_digits = Some(v.to_string());
                }
                if let Some(v) = obj.get("billing_date").and_then(|v| v.as_str()) {
                    liability.billing_date = Some(v.to_string());
                }
                if let Some(v) = obj.get("payment_due_date").and_then(|v| v.as_str()) {
                    liability.payment_due_date = Some(v.to_string());
                }
                if let Some(v) = obj.get("credit_limit").and_then(|v| v.as_f64()) {
                    liability.credit_limit = Some(v);
                }
                if let Some(v) = obj.get("cash_limit").and_then(|v| v.as_f64()) {
                    liability.cash_limit = Some(v);
                }
                if let Some(v) = obj.get("annual_fee").and_then(|v| v.as_f64()) {
                    liability.annual_fee = Some(v);
                }
                if let Some(v) = obj.get("issuer").and_then(|v| v.as_str()) {
                    liability.issuer = Some(v.to_string());
                }

                // 房贷专属字段
                if let Some(v) = obj.get("property_address").and_then(|v| v.as_str()) {
                    liability.property_address = Some(v.to_string());
                }
                if let Some(v) = obj.get("original_loan_amount").and_then(|v| v.as_f64()) {
                    liability.original_loan_amount = Some(v);
                }
                if let Some(v) = obj.get("remaining_principal").and_then(|v| v.as_f64()) {
                    liability.remaining_principal = Some(v);
                }
                if let Some(v) = obj.get("loan_type").and_then(|v| v.as_str()) {
                    liability.loan_type = Some(v.to_string());
                }

                // 车贷专属字段
                if let Some(v) = obj.get("vehicle_brand").and_then(|v| v.as_str()) {
                    liability.vehicle_brand = Some(v.to_string());
                }
                if let Some(v) = obj.get("vehicle_model").and_then(|v| v.as_str()) {
                    liability.vehicle_model = Some(v.to_string());
                }
                if let Some(v) = obj.get("license_plate").and_then(|v| v.as_str()) {
                    liability.license_plate = Some(v.to_string());
                }

                // 个人/私人借款专属字段
                if let Some(v) = obj.get("purpose").and_then(|v| v.as_str()) {
                    liability.purpose = Some(v.to_string());
                }
                if let Some(v) = obj.get("has_interest").and_then(|v| v.as_bool()) {
                    liability.has_interest = Some(v);
                }
                if let Some(v) = obj.get("repayment_plan").and_then(|v| v.as_str()) {
                    liability.repayment_plan = Some(v.to_string());
                }
            }
        }
    }

    match with_db_connection(&state, |conn| -> DbResult<String> {
        let id = LiabilityRepository::create(conn, &liability)?;

        // 记录审计日志
        let change = AssetChange::new(id.clone(), ChangeType::Created)
            .with_created_snapshot_for_liability(&liability);
        AssetChangeRepository::create(conn, &change)?;

        Ok(id)
    }) {
        Ok(_) => FfiErrorCode::Success as c_int,
        Err(e) => {
            eprintln!("创建负债失败: {}", e);
            FfiErrorCode::DatabaseError as c_int
        }
    }
}

/// 更新负债（支持扩展字段）
#[no_mangle]
pub unsafe extern "C" fn update_liability_with_extra_fields(
    id: *const c_char,
    name: *const c_char,
    liability_type: *const c_char,
    amount: c_double,
    currency: *const c_char,
    occurrence_date: *const c_char,
    extra_fields_json: *const c_char,
    note: *const c_char,
) -> c_int {
    let id = match CStr::from_ptr(id).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let name = match CStr::from_ptr(name).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let liability_type = match CStr::from_ptr(liability_type).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let currency = match CStr::from_ptr(currency).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let occurrence_date = if occurrence_date.is_null() {
        None
    } else {
        match CStr::from_ptr(occurrence_date).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    // 解析 extra_fields_json
    let extra_fields = if extra_fields_json.is_null() {
        None
    } else {
        match CStr::from_ptr(extra_fields_json).to_str() {
            Ok(s) => {
                if s.is_empty() {
                    None
                } else {
                    Some(s)
                }
            },
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let note = if note.is_null() {
        None
    } else {
        match CStr::from_ptr(note).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 先获取现有负债
    let existing = match with_db_connection(&state, |conn| -> DbResult<Liability> {
        LiabilityRepository::get(conn, &id)
    }) {
        Ok(l) => l,
        Err(DbError::NotFound(_)) => return FfiErrorCode::NotFound as c_int,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 计算修改的字段（在移动变量之前）
    let mut changed_fields = Vec::new();
    if existing.name != name { changed_fields.push("名称"); }
    if existing.amount != amount { changed_fields.push("金额"); }
    if existing.currency != currency { changed_fields.push("币种"); }
    if existing.liability_type != liability_type { changed_fields.push("类型"); }
    if occurrence_date.is_some() && existing.occurrence_date != *occurrence_date.as_ref().unwrap() {
        changed_fields.push("发生日期");
    }
    if existing.note != note { changed_fields.push("备注"); }

    // 更新字段
    let mut liability = Liability {
        id: id.clone(),
        name: name.clone(),
        liability_type: liability_type.clone(),
        amount,
        currency: currency.clone(),
        occurrence_date: occurrence_date.clone().unwrap_or_else(|| existing.occurrence_date.clone()),
        note: note.clone(),
        // 贷款类通用字段
        lender: existing.lender.clone(),
        due_date: existing.due_date.clone(),
        interest_rate: existing.interest_rate,
        repayment_method: existing.repayment_method.clone(),
        loan_term: existing.loan_term,
        // 信用卡专属字段
        last_four_digits: existing.last_four_digits.clone(),
        billing_date: existing.billing_date.clone(),
        payment_due_date: existing.payment_due_date.clone(),
        credit_limit: existing.credit_limit,
        cash_limit: existing.cash_limit,
        annual_fee: existing.annual_fee,
        issuer: existing.issuer.clone(),
        // 房贷专属字段
        property_address: existing.property_address.clone(),
        original_loan_amount: existing.original_loan_amount,
        remaining_principal: existing.remaining_principal,
        loan_type: existing.loan_type.clone(),
        // 车贷专属字段
        vehicle_brand: existing.vehicle_brand.clone(),
        vehicle_model: existing.vehicle_model.clone(),
        license_plate: existing.license_plate.clone(),
        // 个人/私人借款专属字段
        purpose: existing.purpose.clone(),
        has_interest: existing.has_interest,
        repayment_plan: existing.repayment_plan.clone(),
        // 时间戳
        created_at: existing.created_at,
        updated_at: existing.updated_at,
    };

    // 解析扩展字段并更新
    if let Some(json_str) = extra_fields {
        if let Ok(value) = serde_json::from_str::<serde_json::Value>(json_str) {
            if let Some(obj) = value.as_object() {
                // 贷款类通用字段
                if let Some(v) = obj.get("lender").and_then(|v| v.as_str()) {
                    liability.lender = Some(v.to_string());
                }
                if let Some(v) = obj.get("due_date").and_then(|v| v.as_str()) {
                    liability.due_date = Some(v.to_string());
                }
                if let Some(v) = obj.get("interest_rate").and_then(|v| v.as_f64()) {
                    liability.interest_rate = Some(v);
                }
                if let Some(v) = obj.get("repayment_method").and_then(|v| v.as_str()) {
                    liability.repayment_method = Some(v.to_string());
                }
                if let Some(v) = obj.get("loan_term").and_then(|v| v.as_i64()) {
                    liability.loan_term = Some(v as i32);
                }

                // 信用卡专属字段
                if let Some(v) = obj.get("last_four_digits").and_then(|v| v.as_str()) {
                    liability.last_four_digits = Some(v.to_string());
                }
                if let Some(v) = obj.get("billing_date").and_then(|v| v.as_str()) {
                    liability.billing_date = Some(v.to_string());
                }
                if let Some(v) = obj.get("payment_due_date").and_then(|v| v.as_str()) {
                    liability.payment_due_date = Some(v.to_string());
                }
                if let Some(v) = obj.get("credit_limit").and_then(|v| v.as_f64()) {
                    liability.credit_limit = Some(v);
                }
                if let Some(v) = obj.get("cash_limit").and_then(|v| v.as_f64()) {
                    liability.cash_limit = Some(v);
                }
                if let Some(v) = obj.get("annual_fee").and_then(|v| v.as_f64()) {
                    liability.annual_fee = Some(v);
                }
                if let Some(v) = obj.get("issuer").and_then(|v| v.as_str()) {
                    liability.issuer = Some(v.to_string());
                }

                // 房贷专属字段
                if let Some(v) = obj.get("property_address").and_then(|v| v.as_str()) {
                    liability.property_address = Some(v.to_string());
                }
                if let Some(v) = obj.get("original_loan_amount").and_then(|v| v.as_f64()) {
                    liability.original_loan_amount = Some(v);
                }
                if let Some(v) = obj.get("remaining_principal").and_then(|v| v.as_f64()) {
                    liability.remaining_principal = Some(v);
                }
                if let Some(v) = obj.get("loan_type").and_then(|v| v.as_str()) {
                    liability.loan_type = Some(v.to_string());
                }

                // 车贷专属字段
                if let Some(v) = obj.get("vehicle_brand").and_then(|v| v.as_str()) {
                    liability.vehicle_brand = Some(v.to_string());
                }
                if let Some(v) = obj.get("vehicle_model").and_then(|v| v.as_str()) {
                    liability.vehicle_model = Some(v.to_string());
                }
                if let Some(v) = obj.get("license_plate").and_then(|v| v.as_str()) {
                    liability.license_plate = Some(v.to_string());
                }

                // 个人/私人借款专属字段
                if let Some(v) = obj.get("purpose").and_then(|v| v.as_str()) {
                    liability.purpose = Some(v.to_string());
                }
                if let Some(v) = obj.get("has_interest").and_then(|v| v.as_bool()) {
                    liability.has_interest = Some(v);
                }
                if let Some(v) = obj.get("repayment_plan").and_then(|v| v.as_str()) {
                    liability.repayment_plan = Some(v.to_string());
                }
            }
        }
    }

    match with_db_connection(&state, |conn| -> DbResult<()> {
        LiabilityRepository::update(conn, &liability)?;

        // 在解析扩展字段后，检查扩展字段的变化
        let mut extended_changed_fields = changed_fields.clone();
        if existing.lender != liability.lender { extended_changed_fields.push("债权人"); }
        if existing.interest_rate != liability.interest_rate { extended_changed_fields.push("利率"); }
        if existing.due_date != liability.due_date { extended_changed_fields.push("到期日"); }
        if existing.repayment_method != liability.repayment_method { extended_changed_fields.push("还款方式"); }

        let changed_field = if extended_changed_fields.is_empty() {
            None
        } else if extended_changed_fields.len() == 1 {
            Some(extended_changed_fields[0].to_string())
        } else {
            Some(extended_changed_fields.join(", "))
        };

        // 记录审计日志
        let change = AssetChange::new(id.clone(), ChangeType::Updated)
            .with_updated_snapshots_for_liability(&existing, &liability, changed_field);
        AssetChangeRepository::create(conn, &change)?;

        Ok(())
    }) {
        Ok(_) => FfiErrorCode::Success as c_int,
        Err(e) => {
            eprintln!("更新负债失败: {}", e);
            FfiErrorCode::DatabaseError as c_int
        }
    }
}

/// 重置应用（清除内存中的敏感数据和数据库内容）
///
/// 此函数用于"忘记密码"场景：
/// 1. 先清空数据库中的所有数据（即使文件无法删除，数据也被清除）
/// 2. 清除内存中的主密钥（用零覆盖）
/// 3. 清除 AppState
///
/// 调用方（Dart 端）应负责删除数据库文件（如果可能）
#[export_name = "reset_app"]
pub unsafe extern "C" fn reset_app() -> c_int {
    let mut state = APP_STATE.lock().unwrap();

    // 保存数据库路径
    let db_path = state.as_ref().map(|s| s.db_path.clone());

    // 步骤1: 先清空数据库中的所有数据（防御性措施）
    if let Some(path) = &db_path {
        if let Ok(conn) = open_db(path) {
            match crate::db::wipe_db(&conn) {
                Ok(_) => eprintln!("数据库数据已清空"),
                Err(e) => eprintln!("清空数据库数据失败: {}", e),
            }
        }
    }

    // 步骤2: 清除主密钥（用零覆盖，防止内存转储攻击）
    if let Some(ref mut s) = state.as_mut() {
        if let Some(mut key) = s.master_key.take() {
            for byte in key.iter_mut() {
                *byte = 0;
            }
        }
    }

    // 步骤3: 清除内存连接和脏标记
    if let Some(ref mut s) = state.as_mut() {
        s.memory_conn = None;
        s.is_dirty = false;
    }

    // 步骤4: 清除 AppState（释放数据库连接）
    *state = None;

    // 步骤5: 删除附件密文目录（DEK 随数据库销毁后密文不可解密，但不应残留磁盘）
    if let Some(path) = &db_path {
        let dir = attachments_dir(path);
        if dir.exists() {
            match std::fs::remove_dir_all(&dir) {
                Ok(_) => eprintln!("附件目录已删除: {}", dir.display()),
                Err(e) => eprintln!("删除附件目录失败: {}", e),
            }
        }
    }

    eprintln!("应用已重置，所有敏感数据已从内存和数据库清除");
    FfiErrorCode::Success as c_int
}

/// 删除负债
#[no_mangle]
pub unsafe extern "C" fn delete_liability(id: *const c_char) -> c_int {
    let id = match CStr::from_ptr(id).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 先获取现有负债用于审计日志
    let existing = match with_db_connection(&state, |conn| -> DbResult<Liability> {
        LiabilityRepository::get(conn, &id)
    }) {
        Ok(l) => l,
        Err(DbError::NotFound(_)) => return FfiErrorCode::NotFound as c_int,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    match with_db_connection(&state, |conn| -> DbResult<()> {
        LiabilityRepository::delete(conn, &id)?;

        // 记录审计日志
        let change = AssetChange::new(id.clone(), ChangeType::Deleted)
            .with_deleted_snapshot_for_liability(&existing);
        AssetChangeRepository::create(conn, &change)?;

        Ok(())
    }) {
        Ok(_) => FfiErrorCode::Success as c_int,
        Err(DbError::NotFound(_)) => FfiErrorCode::NotFound as c_int,
        Err(_) => FfiErrorCode::DatabaseError as c_int,
    }
}

// ============================================================
// V2 API: 文件级加密支持
// ============================================================

/// 初始化应用 V2（支持加密检测）
///
/// 此函数会：
/// 1. 检测数据库文件是否存在以及是否已加密
/// 2. 如果是新数据库，返回初始化状态
/// 3. 如果是加密数据库，需要调用 verify_password_v2 解锁
/// 4. 如果是明文数据库，会自动迁移到加密格式
#[export_name = "init_app_v2"]
pub unsafe extern "C" fn init_app_v2(db_path: *const c_char) -> c_int {
    let db_path = match CStr::from_ptr(db_path).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let mut state = APP_STATE.lock().unwrap();
    // 只在 state 为 None 时才创建新的 state
    // 如果 state 已存在（例如已解锁），则不覆盖
    if state.is_none() {
        eprintln!("initAppV2: 创建新的 AppState");
        *state = Some(AppState {
            db_path: db_path.clone(),
            master_key: None,
            memory_conn: None,
            is_dirty: false,
        });
    } else {
        // state 已存在，只更新 db_path（以防路径变化）
        eprintln!("initAppV2: AppState 已存在，保留现有状态（master_key: {}, memory_conn: {}）",
            state.as_ref().unwrap().master_key.is_some(),
            state.as_ref().unwrap().memory_conn.is_some());
        if let Some(s) = state.as_mut() {
            s.db_path = db_path.clone();
        }
    }

    // 检测文件是否存在
    if !std::path::Path::new(&db_path).exists() {
        // 新数据库，需要设置密码
        eprintln!("新数据库，需要设置密码");
        return FfiErrorCode::Success as c_int;
    }

    // 检测是否为加密数据库
    match is_encrypted_db(&db_path) {
        Ok(is_encrypted) => {
            if is_encrypted {
                eprintln!("检测到加密数据库");
            } else {
                eprintln!("检测到明文数据库，将在首次解锁后迁移到加密格式");
            }
            FfiErrorCode::Success as c_int
        }
        Err(e) => {
            // 文件存在但损坏或无法识别（比如文件太小）
            // 删除损坏的文件，作为新数据库处理
            eprintln!("检测数据库类型失败: {}，删除损坏的文件", e);
            if let Err(remove_err) = std::fs::remove_file(&db_path) {
                eprintln!("删除损坏文件失败: {}", remove_err);
                return FfiErrorCode::DatabaseError as c_int;
            }
            eprintln!("损坏文件已删除，作为新数据库处理");
            FfiErrorCode::Success as c_int
        }
    }
}

/// 验证密码 V2（支持加密数据库）
///
/// 此函数会：
/// 1. 验证密码
/// 2. 如果是加密数据库，解密到内存
/// 3. 如果是明文数据库，加载到内存（下次保存时会自动加密）
#[export_name = "verify_password_v2"]
pub unsafe extern "C" fn verify_password_v2(password: *const c_char) -> c_int {
    eprintln!("verify_password_v2: 被调用");
    let password = match CStr::from_ptr(password).to_str() {
        Ok(s) => s,
        Err(_) => return FfiErrorCode::InvalidPassword as c_int,
    };

    let mut state = APP_STATE.lock().unwrap();
    let state = match state.as_mut() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 检查当前状态
    let has_memory_conn = state.memory_conn.is_some();
    let has_master_key = state.master_key.is_some();
    eprintln!("verify_password_v2: 当前状态 - memory_conn: {}, master_key: {}", has_memory_conn, has_master_key);

    // 如果已经解锁（有 master_key 和 memory_conn），只验证密码而不重新加载数据库
    if has_master_key && has_memory_conn {
        eprintln!("verify_password_v2: 应用已解锁，仅验证密码");

        // 从内存数据库获取 salt 来验证密码
        let memory_conn = state.memory_conn.as_ref().unwrap();
        let salt_hex: String = match memory_conn.query_row(
            "SELECT value FROM settings WHERE key = ?1",
            ["password_salt"],
            |row| row.get(0),
        ) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("verify_password_v2: 无法获取盐值: {}", e);
                return FfiErrorCode::DatabaseError as c_int;
            }
        };

        let salt = match hex::decode(&salt_hex) {
            Ok(s) if s.len() == 32 => {
                let mut arr = [0u8; 32];
                arr.copy_from_slice(&s);
                arr
            }
            _ => {
                eprintln!("verify_password_v2: 盐值格式错误");
                return FfiErrorCode::DatabaseError as c_int;
            }
        };

        // 使用相同的 salt 派生密钥
        let key_vec = match derive_key(password, &salt) {
            Ok(k) => k.to_vec(),
            Err(_) => return FfiErrorCode::CryptoError as c_int,
        };

        let mut key = [0u8; 32];
        key.copy_from_slice(&key_vec);

        // 验证密钥哈希
        let stored_key_hash: Option<String> = memory_conn.query_row(
            "SELECT value FROM settings WHERE key = ?1",
            ["password_key_hash"],
            |row| row.get(0),
        ).ok();

        if let Some(stored) = stored_key_hash {
            let key_hash = Sha256::digest(&key);
            let key_hash_hex = hex::encode(&key_hash);
            if key_hash_hex != stored {
                eprintln!("verify_password_v2: 密码验证失败：密钥哈希不匹配");
                return FfiErrorCode::InvalidPassword as c_int;
            }
        }

        eprintln!("verify_password_v2: 密码验证成功，保持现有内存数据库");
        return FfiErrorCode::Success as c_int;
    }

    let db_path = state.db_path.clone();

    // 检测是否为新数据库（文件不存在）
    let is_new_db = !std::path::Path::new(&db_path).exists();

    if is_new_db {
        // 新数据库，直接派生密钥
        let salt = generate_salt();
        let key_vec = match derive_key(password, &salt) {
            Ok(k) => k.to_vec(),
            Err(_) => return FfiErrorCode::CryptoError as c_int,
        };

        let mut key = [0u8; 32];
        key.copy_from_slice(&key_vec);

        // 创建新的内存数据库
        let memory_conn = match Connection::open_in_memory() {
            Ok(c) => c,
            Err(e) => {
                eprintln!("创建内存数据库失败: {}", e);
                return FfiErrorCode::DatabaseError as c_int;
            }
        };

        // 初始化数据库结构
        match crate::db::init_db(&memory_conn) {
            Ok(_) => eprintln!("内存数据库初始化成功"),
            Err(e) => {
                eprintln!("初始化内存数据库失败: {}", e);
                return FfiErrorCode::DatabaseError as c_int;
            }
        }

        // 保存盐值到 settings 表
        let salt_hex = hex::encode(&salt);
        if let Err(e) = memory_conn.execute(
            "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
            ["password_salt", &salt_hex],
        ) {
            eprintln!("保存盐值失败: {}", e);
            return FfiErrorCode::DatabaseError as c_int;
        }

        // 保存密码提示（如果有）
        // 注意：这里需要从 state 获取密码提示，但目前没有存储
        // 这部分需要由 Dart 端在设置密码时调用其他接口

        state.master_key = Some(key);
        state.memory_conn = Some(memory_conn);
        state.is_dirty = true; // 新数据库需要保存

        eprintln!("新数据库创建成功");
        return FfiErrorCode::Success as c_int;
    }

    // 现有数据库，检测加密格式
    let is_encrypted = match is_encrypted_db(&db_path) {
        Ok(is_enc) => is_enc,
        Err(e) => {
            eprintln!("检测数据库类型失败: {}", e);
            return FfiErrorCode::DatabaseError as c_int;
        }
    };

    // 如果是明文数据库，需要先获取 salt 来验证密码
    if !is_encrypted {
        // 打开明文数据库获取 salt
        let conn = match open_db(&db_path) {
            Ok(c) => c,
            Err(_) => return FfiErrorCode::DatabaseError as c_int,
        };

        // 获取存储的盐值
        let salt_hex: String = match conn.query_row(
            "SELECT value FROM settings WHERE key = ?1",
            ["password_salt"],
            |row| row.get(0),
        ) {
            Ok(s) => s,
            Err(_) => return FfiErrorCode::InvalidPassword as c_int,
        };

        // 获取存储的密钥哈希
        let stored_key_hash: Option<String> = conn.query_row(
            "SELECT value FROM settings WHERE key = ?1",
            ["password_key_hash"],
            |row| row.get(0),
        ).ok();

        let salt = match hex::decode(&salt_hex) {
            Ok(s) if s.len() == 32 => {
                let mut arr = [0u8; 32];
                arr.copy_from_slice(&s);
                arr
            }
            _ => return FfiErrorCode::InvalidPassword as c_int,
        };

        // 派生密钥并验证
        let key_vec = match derive_key(password, &salt) {
            Ok(k) => k.to_vec(),
            Err(_) => return FfiErrorCode::CryptoError as c_int,
        };

        let mut key = [0u8; 32];
        key.copy_from_slice(&key_vec);

        // 计算密钥哈希
        let key_hash = Sha256::digest(&key);
        let key_hash_hex = hex::encode(&key_hash);

        match stored_key_hash {
            Some(stored) => {
                if key_hash_hex != stored {
                    eprintln!("密码验证失败：密钥哈希不匹配");
                    return FfiErrorCode::InvalidPassword as c_int;
                }
            }
            None => {
                // 旧版本数据，自动写入哈希
                eprintln!("检测到旧版本数据库，自动写入密钥哈希");
                if let Err(e) = conn.execute(
                    "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
                    ["password_key_hash", &key_hash_hex],
                ) {
                    eprintln!("写入密钥哈希失败: {}", e);
                    return FfiErrorCode::DatabaseError as c_int;
                }
            }
        }

        // 密码正确，加载明文数据库到内存
        let memory_conn = match load_plaintext_db(&db_path) {
            Ok(c) => c,
            Err(e) => {
                eprintln!("加载明文数据库失败: {}", e);
                return FfiErrorCode::DatabaseError as c_int;
            }
        };

        // 幂等执行 schema 创建与版本迁移（存量库在此完成升级，如 v8 移除审计表外键）
        if let Err(e) = crate::db::init_db(&memory_conn) {
            eprintln!("加载明文库后执行 schema 迁移失败: {}", e);
            return FfiErrorCode::DatabaseError as c_int;
        }

        state.master_key = Some(key);
        state.memory_conn = Some(memory_conn);
        state.is_dirty = true; // 明文数据库需要迁移保存

        eprintln!("明文数据库已加载，将在下次保存时迁移到加密格式");
        return FfiErrorCode::Success as c_int;
    }

    // 加密数据库：需要使用加密文件的 salt
    // 读取加密文件获取 salt
    let file_data = match std::fs::read(&db_path) {
        Ok(d) => d,
        Err(e) => {
            eprintln!("读取加密文件失败: {}", e);
            return FfiErrorCode::DatabaseError as c_int;
        }
    };

    if file_data.len() < 8 + 1 + 32 {
        eprintln!("加密文件格式错误：文件太短");
        return FfiErrorCode::DatabaseError as c_int;
    }

    // 检查魔数
    if &file_data[..8] != crate::db::encrypted::ENCRYPTED_MAGIC {
        eprintln!("加密文件格式错误：魔数不匹配");
        return FfiErrorCode::DatabaseError as c_int;
    }

    // 提取文件中的 salt
    let file_salt = &file_data[9..41];
    let mut salt = [0u8; 32];
    salt.copy_from_slice(file_salt);

    // 使用文件中的 salt 派生密钥
    let key_vec = match derive_key(password, &salt) {
        Ok(k) => k.to_vec(),
        Err(_) => return FfiErrorCode::CryptoError as c_int,
    };

    let mut key = [0u8; 32];
    key.copy_from_slice(&key_vec);

    // 尝试解密数据库
    let memory_conn = match load_encrypted_db(&db_path, &key) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("解密数据库失败: {}", e);
            return FfiErrorCode::InvalidPassword as c_int;
        }
    };

    // 幂等执行 schema 创建与版本迁移（存量加密库在此完成升级，如 v8 移除审计表外键）
    if let Err(e) = crate::db::init_db(&memory_conn) {
        eprintln!("解密加载后执行 schema 迁移失败: {}", e);
        return FfiErrorCode::DatabaseError as c_int;
    }

    // 从内存数据库中获取 stored_key_hash 来验证
    let stored_key_hash: Option<String> = memory_conn.query_row(
        "SELECT value FROM settings WHERE key = ?1",
        ["password_key_hash"],
        |row| row.get(0),
    ).ok();

    // 计算密钥哈希验证
    let key_hash = Sha256::digest(&key);
    let key_hash_hex = hex::encode(&key_hash);

    if let Some(stored) = stored_key_hash {
        if key_hash_hex != stored {
            eprintln!("密码验证失败：密钥哈希不匹配");
            return FfiErrorCode::InvalidPassword as c_int;
        }
    } else {
        // 首次验证，写入哈希
        if let Err(e) = memory_conn.execute(
            "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
            ["password_key_hash", &key_hash_hex],
        ) {
            eprintln!("写入密钥哈希失败: {}", e);
            return FfiErrorCode::DatabaseError as c_int;
        }
    }

    state.master_key = Some(key);
    state.memory_conn = Some(memory_conn);
    state.is_dirty = false;

    eprintln!("加密数据库已解密并加载到内存");
    FfiErrorCode::Success as c_int
}

/// 设置主密码 V2（加密数据库模式）
///
/// 此函数用于首次设置密码，会：
/// 1. 派生密钥
/// 2. 创建内存数据库
/// 3. 初始化表结构
/// 4. 保存盐值和密码提示
///
/// 注意：调用此函数后，需要调用 save_database() 将加密数据库保存到磁盘
#[export_name = "setup_password_v2"]
pub unsafe extern "C" fn setup_password_v2(
    password: *const c_char,
    hint: *const c_char,
) -> c_int {
    let password = match CStr::from_ptr(password).to_str() {
        Ok(s) => s,
        Err(_) => return FfiErrorCode::InvalidPassword as c_int,
    };

    let hint_str = if hint.is_null() {
        None
    } else {
        match CStr::from_ptr(hint).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };

    let mut state = APP_STATE.lock().unwrap();
    let state = match state.as_mut() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 生成盐值并派生密钥
    let salt = generate_salt();
    let key_vec = match derive_key(password, &salt) {
        Ok(k) => k.to_vec(),
        Err(_) => return FfiErrorCode::CryptoError as c_int,
    };

    let mut key = [0u8; 32];
    key.copy_from_slice(&key_vec);

    // 创建新的内存数据库
    let mut memory_conn = match Connection::open_in_memory() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("创建内存数据库失败: {}", e);
            return FfiErrorCode::DatabaseError as c_int;
        }
    };

    // 修改密码场景：当前已解锁且有旧库时，先把现有数据整体迁移到新库，
    // 避免 changePassword（verify + setup + save）清空全部数据。
    // 注意 backup 会整体覆盖目标库，因此必须先于 init_db 执行；
    // 其后的 init_db 幂等补齐 schema/默认设置并把版本推进到最新（如 v8），
    // 旧 salt/key_hash 再由下方 INSERT OR REPLACE 覆盖为新值。
    if let Some(ref old_conn) = state.memory_conn {
        use rusqlite::backup::Backup;
        let migrate = Backup::new(old_conn, &mut memory_conn)
            .and_then(|b| {
                b.run_to_completion(16, std::time::Duration::from_millis(5), None)
            });
        match migrate {
            Ok(_) => eprintln!("setup_password_v2: 已迁移现有数据（修改密码场景）"),
            Err(e) => {
                eprintln!("setup_password_v2: 数据迁移失败: {}", e);
                return FfiErrorCode::DatabaseError as c_int;
            }
        }
    }

    // 初始化数据库结构（幂等：backup 后补齐缺失表/默认设置并推进 schema 版本）
    match crate::db::init_db(&memory_conn) {
        Ok(_) => eprintln!("内存数据库初始化成功"),
        Err(e) => {
            eprintln!("初始化内存数据库失败: {}", e);
            return FfiErrorCode::DatabaseError as c_int;
        }
    }

    // 保存盐值到 settings 表
    let salt_hex = hex::encode(&salt);
    if let Err(e) = memory_conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
        ["password_salt", &salt_hex],
    ) {
        eprintln!("保存盐值失败: {}", e);
        return FfiErrorCode::DatabaseError as c_int;
    }

    // 保存密钥哈希（用于后续验证密码）
    let key_hash = Sha256::digest(&key);
    let key_hash_hex = hex::encode(&key_hash);
    if let Err(e) = memory_conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
        ["password_key_hash", &key_hash_hex],
    ) {
        eprintln!("保存密钥哈希失败: {}", e);
        return FfiErrorCode::DatabaseError as c_int;
    }

    // 保存密码提示（如果有）
    if let Some(hint) = hint_str {
        if let Err(e) = memory_conn.execute(
            "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
            ["password_hint", &hint],
        ) {
            eprintln!("保存密码提示失败: {}", e);
            return FfiErrorCode::DatabaseError as c_int;
        }
    }

    state.master_key = Some(key);
    state.memory_conn = Some(memory_conn);
    state.is_dirty = true; // 新数据库需要保存

    eprintln!("新数据库创建成功（V2 加密模式）");
    FfiErrorCode::Success as c_int
}

/// 保存加密数据库到磁盘
///
/// 将当前内存数据库加密后保存到磁盘
#[export_name = "save_database"]
pub unsafe extern "C" fn save_database() -> c_int {
    let mut state = APP_STATE.lock().unwrap();
    let state = match state.as_mut() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 检查是否已解锁
    let key = match state.master_key {
        Some(k) => k,
        None => {
            eprintln!("保存失败：应用未解锁");
            return FfiErrorCode::GenericError as c_int;
        }
    };

    // 检查是否有内存连接
    let memory_conn = match state.memory_conn.as_ref() {
        Some(c) => c,
        None => {
            eprintln!("保存失败：内存数据库不存在");
            return FfiErrorCode::DatabaseError as c_int;
        }
    };

    // 检查当前内存数据库中的资产数量
    let _asset_count: i64 = match memory_conn.query_row(
        "SELECT COUNT(*) FROM assets",
        [],
        |row| row.get(0),
    ) {
        Ok(count) => {
            eprintln!("save_database: 准备保存，当前内存数据库中有 {} 条资产记录", count);
            count
        }
        Err(e) => {
            eprintln!("save_database: 无法查询资产数量: {}", e);
            0
        }
    };

    // 从内存数据库获取盐值
    let salt_hex: String = match memory_conn.query_row(
        "SELECT value FROM settings WHERE key = ?1",
        ["password_salt"],
        |row| row.get(0),
    ) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("保存失败：无法获取盐值: {}", e);
            return FfiErrorCode::DatabaseError as c_int;
        }
    };

    let salt = match hex::decode(&salt_hex) {
        Ok(s) if s.len() == 32 => {
            let mut arr = [0u8; 32];
            arr.copy_from_slice(&s);
            arr
        }
        _ => {
            eprintln!("保存失败：盐值格式错误");
            return FfiErrorCode::DatabaseError as c_int;
        }
    };

    // 保存加密数据库（使用内存数据库中的盐值）
    match save_encrypted_db(memory_conn, &state.db_path, &key, &salt) {
        Ok(_) => {
            state.is_dirty = false;
            eprintln!("数据库已加密保存");
            FfiErrorCode::Success as c_int
        }
        Err(e) => {
            eprintln!("保存加密数据库失败: {}", e);
            FfiErrorCode::DatabaseError as c_int
        }
    }
}

/// 清理应用（退出时调用）
///
/// 此函数会：
/// 1. 如果 save=true，保存加密数据库到磁盘
/// 2. 清除内存中的敏感数据
/// 3. 关闭内存数据库连接
#[export_name = "cleanup_app"]
pub unsafe extern "C" fn cleanup_app(save: c_int) -> c_int {
    eprintln!("cleanup_app: 被调用，save={}", save);
    let should_save = save != 0;

    let mut state = APP_STATE.lock().unwrap();
    let state = match state.as_mut() {
        Some(s) => s,
        None => return FfiErrorCode::Success as c_int, // 已经清理过了
    };

    // 保存数据（如果需要）
    // 注意：即使 is_dirty 为 false，如果内存数据库存在也需要保存（用于迁移明文数据库）
    if should_save && state.memory_conn.is_some() {
        eprintln!("cleanup_app: 准备保存数据，memory_conn 存在");
        if let Some(key) = state.master_key {
            eprintln!("cleanup_app: master_key 存在，开始保存");
            if let Some(memory_conn) = state.memory_conn.as_ref() {
                // 从内存数据库获取盐值
                let result: Result<(), DbError> = (|| {
                    let salt_hex: String = memory_conn.query_row(
                        "SELECT value FROM settings WHERE key = ?1",
                        ["password_salt"],
                        |row| row.get(0),
                    ).map_err(|e| DbError::DatabaseError(format!("无法获取盐值: {}", e)))?;

                    let salt = hex::decode(&salt_hex)
                        .map_err(|e| DbError::DatabaseError(format!("盐值解码失败: {}", e)))?;
                    if salt.len() != 32 {
                        return Err(DbError::DatabaseError("盐值长度错误".to_string()));
                    }
                    let mut salt_arr = [0u8; 32];
                    salt_arr.copy_from_slice(&salt);

                    save_encrypted_db(memory_conn, &state.db_path, &key, &salt_arr)
                })();

                match result {
                    Ok(_) => {
                        state.is_dirty = false;
                        eprintln!("退出前已保存数据库");
                    }
                    Err(e) => {
                        eprintln!("保存数据库失败: {}", e);
                        // 继续清理，不返回错误
                    }
                }
            }
        }
    }

    // 清除主密钥（用零覆盖）
    if let Some(mut key) = state.master_key.take() {
        for byte in key.iter_mut() {
            *byte = 0;
        }
    }

    // 关闭内存连接
    state.memory_conn = None;
    state.is_dirty = false;

    eprintln!("应用已清理，所有敏感数据已从内存清除");
    FfiErrorCode::Success as c_int
}

// ============================================================
// 净资产快照（财富曲线）
// ============================================================


/// 记录/更新当日净值快照
///
/// 汇总数值由 Dart 端计算传入（与 UI 显示口径一致），
/// Rust 端负责落库（同日覆盖）。注意：本函数不自动保存数据库，
/// 遵循即时保存策略由调用方随后调用 save_database。
///
/// # Safety
/// 由 FFI 调用方保证在已初始化（init_app_v2 + 解锁）后调用
#[no_mangle]
pub unsafe extern "C" fn record_net_worth_snapshot(
    total_assets: c_double,
    total_liabilities: c_double,
) -> c_int {
    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => {
            eprintln!("record_net_worth_snapshot: state 为空");
            return FfiErrorCode::GenericError as c_int;
        }
    };

    match with_db_connection(&state, |conn| -> DbResult<()> {
        NetWorthSnapshotRepository::upsert_today(conn, total_assets, total_liabilities).map(|_| ())
    }) {
        Ok(_) => FfiErrorCode::Success as c_int,
        Err(e) => {
            eprintln!("record_net_worth_snapshot 失败: {}", e);
            FfiErrorCode::DatabaseError as c_int
        }
    }
}

/// 获取全部净值快照（按日期升序），JSON 数组，失败返回 NULL
///
/// # Safety
/// 返回的字符串需调用 free_string 释放
#[no_mangle]
pub unsafe extern "C" fn get_net_worth_snapshots() -> *mut c_char {
    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => {
            eprintln!("get_net_worth_snapshots: state 为空");
            return ptr::null_mut();
        }
    };

    let snapshots = match with_db_connection(&state, |conn| -> DbResult<Vec<NetWorthSnapshot>> {
        NetWorthSnapshotRepository::list(conn)
    }) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("get_net_worth_snapshots 失败: {}", e);
            return ptr::null_mut();
        }
    };

    match serde_json::to_string(&snapshots) {
        Ok(json) => string_to_c_char(json),
        Err(e) => {
            eprintln!("get_net_worth_snapshots 序列化失败: {}", e);
            ptr::null_mut()
        }
    }
}

// ============================================================
// 投资收益（XIRR 年化）
// ============================================================

/// 获取投资类资产的收益信息（含组合 XIRR 年化），JSON，失败返回 NULL
///
/// 口径：成本 = buy_price × quantity，现值 = amount，买入时点 = occurrence_date；
/// 缺成本或日期无法解析的投资资产不计入。
///
/// # Safety
/// 返回的字符串需调用 free_string 释放
#[no_mangle]
pub unsafe extern "C" fn get_investment_returns() -> *mut c_char {
    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => {
            eprintln!("get_investment_returns: state 为空");
            return ptr::null_mut();
        }
    };

    let assets = match with_db_connection(&state, |conn| -> DbResult<Vec<Asset>> {
        AssetRepository::list(conn)
    }) {
        Ok(a) => a,
        Err(e) => {
            eprintln!("get_investment_returns: 获取资产失败: {}", e);
            return ptr::null_mut();
        }
    };

    let today = Local::now().date_naive();
    let inputs = assets
        .iter()
        .filter(|a| a.is_investment())
        .filter_map(|a| {
            let buy_price = a.buy_price?;
            let quantity = a.quantity? as f64;
            let cost = buy_price * quantity;
            Some((
                a.id.clone(),
                a.name.clone(),
                a.currency.clone(),
                cost,
                a.amount,
                a.occurrence_date.clone(),
            ))
        })
        .collect();

    let result = crate::returns::summarize(inputs, today);
    match serde_json::to_string(&result) {
        Ok(json) => string_to_c_char(json),
        Err(e) => {
            eprintln!("get_investment_returns 序列化失败: {}", e);
            ptr::null_mut()
        }
    }
}

// ============================================================
// 附件（保单/房产证等照片，文件级加密存储）
// ============================================================

/// 添加附件：二进制内容以 Base64 传入，加密落盘后登记元数据
///
/// 返回 Success / GenericError（参数非法）/ NotFound（资产不存在）/ DatabaseError
///
/// # Safety
/// 由 FFI 调用方保证在已初始化（init_app_v2 + 解锁）后调用
#[no_mangle]
pub unsafe extern "C" fn add_attachment(
    asset_id: *const c_char,
    file_name: *const c_char,
    mime_type: *const c_char,
    data_base64: *const c_char,
) -> c_int {
    let asset_id = match CStr::from_ptr(asset_id).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };
    let file_name = match CStr::from_ptr(file_name).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };
    let mime_type = if mime_type.is_null() {
        None
    } else {
        match CStr::from_ptr(mime_type).to_str() {
            Ok(s) => Some(s.to_string()),
            Err(_) => return FfiErrorCode::GenericError as c_int,
        }
    };
    let data_b64 = match CStr::from_ptr(data_base64).to_str() {
        Ok(s) => s,
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let data = match base64::engine::general_purpose::STANDARD.decode(data_b64) {
        Ok(d) => d,
        Err(e) => {
            eprintln!("add_attachment: Base64 解码失败: {}", e);
            return FfiErrorCode::GenericError as c_int;
        }
    };
    if data.is_empty() || data.len() > ATTACHMENT_MAX_SIZE {
        eprintln!("add_attachment: 附件大小非法（{} 字节）", data.len());
        return FfiErrorCode::GenericError as c_int;
    }

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    // 资产必须存在
    let exists = match with_db_connection(&state, |conn| -> DbResult<bool> {
        match AssetRepository::get(conn, &asset_id) {
            Ok(_) => Ok(true),
            Err(DbError::NotFound(_)) => Ok(false),
            Err(e) => Err(e),
        }
    }) {
        Ok(true) => true,
        Ok(false) => return FfiErrorCode::NotFound as c_int,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };
    if !exists {
        return FfiErrorCode::NotFound as c_int;
    }

    let attachment_id = uuid::Uuid::new_v4().to_string();
    let dir = attachments_dir(&state.db_path);

    // 先加密写文件，再登记元数据；写失败时不留下孤儿记录
    let stored_name = match with_db_connection(&state, |conn| -> DbResult<String> {
        let key = get_or_create_attachment_key(conn)?;
        save_attachment_file(&dir, &attachment_id, &key, &data)
    }) {
        Ok(name) => name,
        Err(e) => {
            eprintln!("add_attachment: 写入附件文件失败: {}", e);
            return FfiErrorCode::DatabaseError as c_int;
        }
    };

    let attachment = Attachment {
        id: attachment_id,
        asset_id,
        file_name,
        file_size: data.len() as i64,
        encrypted_path: stored_name,
        mime_type,
        created_at: chrono::Utc::now().timestamp(),
    };

    let result = with_db_connection(&state, |conn| -> DbResult<String> {
        AttachmentRepository::create(conn, &attachment)
    });
    match result {
        Ok(_) => FfiErrorCode::Success as c_int,
        Err(e) => {
            eprintln!("add_attachment: 登记元数据失败: {}", e);
            // 回滚已写入的密文文件，避免孤儿文件
            let _ = delete_attachment_file(&dir, &attachment.encrypted_path);
            FfiErrorCode::DatabaseError as c_int
        }
    }
}

/// 获取某资产的附件列表（JSON 数组，不含文件内容），失败返回 NULL
///
/// # Safety
/// 返回的字符串需调用 free_string 释放
#[no_mangle]
pub unsafe extern "C" fn get_attachments_by_asset(asset_id: *const c_char) -> *mut c_char {
    let asset_id = match CStr::from_ptr(asset_id).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return ptr::null_mut(),
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return ptr::null_mut(),
    };

    let list = match with_db_connection(&state, |conn| -> DbResult<Vec<Attachment>> {
        AttachmentRepository::list_by_asset(conn, &asset_id)
    }) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("get_attachments_by_asset 失败: {}", e);
            return ptr::null_mut();
        }
    };

    let items: Vec<serde_json::Value> = list
        .iter()
        .map(|a| {
            json!({
                "id": a.id,
                "assetId": a.asset_id,
                "fileName": a.file_name,
                "fileSize": a.file_size,
                "mimeType": a.mime_type,
                "createdAt": a.created_at,
            })
        })
        .collect();
    match serde_json::to_string(&items) {
        Ok(json) => string_to_c_char(json),
        Err(_) => ptr::null_mut(),
    }
}

/// 读取附件内容（解密后以 Base64 返回），失败返回 NULL
///
/// # Safety
/// 返回的字符串需调用 free_string 释放
#[no_mangle]
pub unsafe extern "C" fn read_attachment_data(attachment_id: *const c_char) -> *mut c_char {
    let attachment_id = match CStr::from_ptr(attachment_id).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return ptr::null_mut(),
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return ptr::null_mut(),
    };

    let dir = attachments_dir(&state.db_path);
    let data = match with_db_connection(&state, |conn| -> DbResult<Vec<u8>> {
        let attachment = AttachmentRepository::get(conn, &attachment_id)?;
        let key = get_or_create_attachment_key(conn)?;
        load_attachment_file(&dir, &attachment.encrypted_path, &key)
    }) {
        Ok(d) => d,
        Err(e) => {
            eprintln!("read_attachment_data 失败: {}", e);
            return ptr::null_mut();
        }
    };

    string_to_c_char(base64::engine::general_purpose::STANDARD.encode(data))
}

/// 删除附件：同时删除密文文件与元数据记录
///
/// 返回 Success / GenericError（参数非法或状态为空）/ NotFound / DatabaseError
///
/// # Safety
/// 由 FFI 调用方保证在已初始化（init_app_v2 + 解锁）后调用
#[no_mangle]
pub unsafe extern "C" fn delete_attachment(attachment_id: *const c_char) -> c_int {
    let attachment_id = match CStr::from_ptr(attachment_id).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    let dir = attachments_dir(&state.db_path);
    // 顺序：先查记录 → 删文件 → 删记录。文件删除失败（如 Windows 文件占用）时
    // 记录仍在，用户重试即可；若先删记录，文件删除失败将留下无入口的孤儿文件
    match with_db_connection(&state, |conn| -> DbResult<()> {
        let attachment = AttachmentRepository::get(conn, &attachment_id)?;
        delete_attachment_file(&dir, &attachment.encrypted_path)?;
        AttachmentRepository::delete(conn, &attachment_id)?;
        Ok(())
    }) {
        Ok(()) => FfiErrorCode::Success as c_int,
        Err(DbError::NotFound(_)) => FfiErrorCode::NotFound as c_int,
        Err(e) => {
            eprintln!("delete_attachment: 删除失败: {}", e);
            FfiErrorCode::DatabaseError as c_int
        }
    }
}
