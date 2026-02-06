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
use crate::db::{Asset, AssetRepository, AssetType, Liability, LiabilityRepository, DbError, DbResult, AssetChange, ChangeType, AssetChangeRepository, CustomAssetType, CustomTypeRepository};
use crate::db::{is_encrypted_db, save_encrypted_db, load_encrypted_db, load_plaintext_db};
use rusqlite::Connection;

/// 文件日志
fn write_log(msg: &str) {
    use std::io::Write;
    let timestamp = Local::now().to_rfc3339();
    let log_msg = format!("[{}] {}\n", timestamp, msg);
    let path = r"C:\Users\86131\Documents\localfamily_asset_rust.log";
    match OpenOptions::new()
        .append(true)
        .create(true)
        .open(path)
        .and_then(|mut file| file.write_all(log_msg.as_bytes()))
    {
        Ok(_) => {},
        Err(e) => {
            eprintln!("写入日志失败 ({}): {}", path, e);
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

    // 打开数据库获取盐值和密钥哈希
    let conn = match open_db(&state.db_path) {
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
    // 兼容旧数据库：如果不存在 password_key_hash，则是旧版本数据
    // 第一次成功验证后会自动写入哈希值
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
            if let Err(e) = conn.execute(
                "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
                ["password_key_hash", &key_hash_hex],
            ) {
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

    // 打开数据库获取存储的密钥哈希
    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 计算助记词派生的密钥哈希
    let key_hash = Sha256::digest(&key);
    let key_hash_hex = hex::encode(&key_hash);

    // 从数据库获取存储的助记词密钥哈希
    let stored_mnemonic_hash: String = match conn.query_row(
        "SELECT value FROM settings WHERE key = ?1",
        ["mnemonic_key_hash"],
        |row| row.get(0),
    ) {
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

    // 打开数据库获取密码提示
    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return ptr::null_mut(),
    };

    // 从数据库获取密码提示
    let hint: Option<String> = conn.query_row(
        "SELECT value FROM settings WHERE key = ?1",
        ["password_hint"],
        |row| row.get(0),
    ).ok();

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

    // 打开数据库保存助记词
    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 保存助记词到 settings 表（用于用户查看）
    if let Err(e) = conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
        ["recovery_mnemonic", &mnemonic],
    ) {
        write_log(&format!("保存助记词失败: {}", e));
        return FfiErrorCode::DatabaseError as c_int;
    }

    // 从助记词派生密钥并计算哈希（用于验证）
    let mnemonic_key = match mnemonic_to_key(mnemonic) {
        Ok(k) => k.to_vec(),
        Err(e) => {
            write_log(&format!("助记词派生密钥失败: {}", e));
            return FfiErrorCode::CryptoError as c_int;
        }
    };

    let mnemonic_key_hash = Sha256::digest(&mnemonic_key);
    let mnemonic_key_hash_hex = hex::encode(&mnemonic_key_hash);

    // 保存助记词密钥哈希
    if let Err(e) = conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
        ["mnemonic_key_hash", &mnemonic_key_hash_hex],
    ) {
        write_log(&format!("保存助记词密钥哈希失败: {}", e));
        return FfiErrorCode::DatabaseError as c_int;
    }

    write_log(&format!("助记词密钥哈希已保存: {}", &mnemonic_key_hash_hex[..8]));
    FfiErrorCode::Success as c_int
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    let asset = Asset::new(asset_type_str, name, amount);
    let asset = Asset {
        currency,
        account: _symbol,
        note,
        occurrence_date,
        ..asset
    };

    let asset_id = match AssetRepository::create(&conn, &asset) {
        Ok(id) => id,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 记录审计日志
    let change = AssetChange::new(asset_id.clone(), ChangeType::Created)
        .with_created_snapshot(&asset);
    let _ = AssetChangeRepository::create(&conn, &change);

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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return ptr::null_mut(),
    };

    let assets = match AssetRepository::list(&conn) {
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 先获取现有资产
    let existing = match AssetRepository::get(&conn, &id) {
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

    match AssetRepository::update(&conn, &asset) {
        Ok(_) => {
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
            let _ = AssetChangeRepository::create(&conn, &change);

            FfiErrorCode::Success as c_int
        },
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 先获取现有资产用于审计日志
    let existing = match AssetRepository::get(&conn, &id) {
        Ok(a) => a,
        Err(DbError::NotFound(_)) => return FfiErrorCode::NotFound as c_int,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    match AssetRepository::delete(&conn, &id) {
        Ok(_) => {
            // 记录审计日志
            let change = AssetChange::new(id, ChangeType::Deleted)
                .with_deleted_snapshot(&existing);
            let _ = AssetChangeRepository::create(&conn, &change);

            FfiErrorCode::Success as c_int
        },
        Err(DbError::NotFound(_)) => FfiErrorCode::NotFound as c_int,
        Err(_) => FfiErrorCode::DatabaseError as c_int,
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

    match crate::export::create_export_zip(&db_data, std::path::Path::new(output_path), &key) {
        Ok(_) => string_to_c_char(
            serde_json::json!({"success": true, "path": output_path}).to_string()
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

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
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
        Ok(db_data) => {
            // 写入数据库文件
            match std::fs::write(&state.db_path, &db_data) {
                Ok(_) => string_to_c_char(
                    serde_json::json!({"success": true, "imported": db_data.len()}).to_string()
                ),
                Err(e) => string_to_c_char(
                    serde_json::json!({"error": format!("写入数据库失败: {}", e)}).to_string()
                ),
            }
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return ptr::null_mut(),
    };

    let changes = match AssetChangeRepository::list_all(&conn, Some(1000)) {
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return ptr::null_mut(),
    };

    let changes = match AssetChangeRepository::list_by_asset(&conn, &asset_id) {
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return ptr::null_mut(),
    };

    // 解析类型过滤器 JSON数组 - 现在是字符串数组而不是整数数组
    let type_ids: Vec<String> = match serde_json::from_str(type_filter_json) {
        Ok(v) => v,
        Err(_) => return ptr::null_mut(),
    };

    match AssetRepository::search_by_name(&conn, name_pattern, &type_ids) {
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return string_to_c_char("{\"error\":\"Database error\"}".to_string()),
    };

    match CustomTypeRepository::create(&conn, &custom_type) {
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return string_to_c_char("[]".to_string()),
    };

    match CustomTypeRepository::get_all(&conn) {
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    match CustomTypeRepository::delete(&conn, id) {
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return -1,
    };

    match CustomTypeRepository::is_in_use(&conn, id) {
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
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

    let asset_id = match AssetRepository::create(&conn, &asset) {
        Ok(id) => id,
        Err(e) => {
            write_log(&format!("数据库插入失败: {}\n", e));
            return FfiErrorCode::DatabaseError as c_int;
        }
    };

    write_log(&format!("数据库插入成功，资产 ID = {}\n", asset_id));

    // 立即读取验证
    match AssetRepository::get(&conn, &asset_id) {
        Ok(read_asset) => {
            write_log(&format!("验证读取: buy_price = {:?}, current_price = {:?}\n", read_asset.buy_price, read_asset.current_price));
        },
        Err(e) => {
            write_log(&format!("验证读取失败: {}\n", e));
        }
    }

    // 记录审计日志
    let change = AssetChange::new(asset_id.clone(), ChangeType::Created)
        .with_created_snapshot(&asset);
    let _ = AssetChangeRepository::create(&conn, &change);

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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 先获取现有资产
    let existing = match AssetRepository::get(&conn, &id) {
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

    match AssetRepository::update(&conn, &asset) {
        Ok(_) => {
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
            let _ = AssetChangeRepository::create(&conn, &change);

            FfiErrorCode::Success as c_int
        },
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
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

    let asset_id = match AssetRepository::create(&conn, &asset) {
        Ok(id) => id,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 记录审计日志
    let change = AssetChange::new(asset_id, ChangeType::Created)
        .with_created_snapshot(&asset);
    let _ = AssetChangeRepository::create(&conn, &change);

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
        None => return ptr::null_mut(),
    };

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return ptr::null_mut(),
    };

    let assets = match AssetRepository::list(&conn) {
        Ok(a) => a,
        Err(_) => return ptr::null_mut(),
    };

    match serde_json::to_string(&assets) {
        Ok(json) => string_to_c_char(json),
        Err(_) => ptr::null_mut(),
    }
}

/// 获取仅负债（不包括资产）
#[no_mangle]
pub unsafe extern "C" fn get_liabilities_only() -> *mut c_char {
    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return ptr::null_mut(),
    };

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return ptr::null_mut(),
    };

    let liabilities = match LiabilityRepository::list(&conn) {
        Ok(l) => l,
        Err(_) => return ptr::null_mut(),
    };

    match serde_json::to_string(&liabilities) {
        Ok(json) => string_to_c_char(json),
        Err(_) => ptr::null_mut(),
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return ptr::null_mut(),
    };

    match AssetRepository::get(&conn, &id) {
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 先获取现有资产
    let existing = match AssetRepository::get(&conn, &id) {
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

    match AssetRepository::update(&conn, &asset) {
        Ok(_) => {
            // 在解析扩展字段后，检查扩展字段的变化
            if existing.account != asset.account { changed_fields.push("账户"); }
            if existing.buy_price != asset.buy_price { changed_fields.push("买入价"); }
            if existing.current_price != asset.current_price { changed_fields.push("现价"); }
            if existing.tags != asset.tags { changed_fields.push("标签"); }

            let changed_field = if changed_fields.is_empty() {
                None
            } else if changed_fields.len() == 1 {
                Some(changed_fields[0].to_string())
            } else {
                Some(changed_fields.join(", "))
            };

            // 记录审计日志
            let change = AssetChange::new(asset.id.clone(), ChangeType::Updated)
                .with_updated_snapshots(&existing, &asset, changed_field);
            let _ = AssetChangeRepository::create(&conn, &change);

            FfiErrorCode::Success as c_int
        }
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return ptr::null_mut(),
    };

    let liabilities = match LiabilityRepository::list(&conn) {
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
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

    match LiabilityRepository::create(&conn, &liability) {
        Ok(id) => {
            // 记录审计日志
            let change = AssetChange::new(id.clone(), ChangeType::Created)
                .with_created_snapshot_for_liability(&liability);
            let _ = AssetChangeRepository::create(&conn, &change);

            FfiErrorCode::Success as c_int
        }
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 先获取现有负债
    let existing = match LiabilityRepository::get(&conn, &id) {
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

    match LiabilityRepository::update(&conn, &liability) {
        Ok(_) => {
            // 在解析扩展字段后，检查扩展字段的变化
            if existing.lender != liability.lender { changed_fields.push("债权人"); }
            if existing.interest_rate != liability.interest_rate { changed_fields.push("利率"); }
            if existing.due_date != liability.due_date { changed_fields.push("到期日"); }
            if existing.repayment_method != liability.repayment_method { changed_fields.push("还款方式"); }

            let changed_field = if changed_fields.is_empty() {
                None
            } else if changed_fields.len() == 1 {
                Some(changed_fields[0].to_string())
            } else {
                Some(changed_fields.join(", "))
            };

            // 记录审计日志
            let change = AssetChange::new(id, ChangeType::Updated)
                .with_updated_snapshots_for_liability(&existing, &liability, changed_field);
            let _ = AssetChangeRepository::create(&conn, &change);

            FfiErrorCode::Success as c_int
        }
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

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    // 先获取现有负债用于审计日志
    let existing = match LiabilityRepository::get(&conn, &id) {
        Ok(l) => l,
        Err(DbError::NotFound(_)) => return FfiErrorCode::NotFound as c_int,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    match LiabilityRepository::delete(&conn, &id) {
        Ok(_) => {
            // 记录审计日志
            let change = AssetChange::new(id, ChangeType::Deleted)
                .with_deleted_snapshot_for_liability(&existing);
            let _ = AssetChangeRepository::create(&conn, &change);

            FfiErrorCode::Success as c_int
        }
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
    *state = Some(AppState {
        db_path: db_path.clone(),
        master_key: None,
        memory_conn: None,
        is_dirty: false,
    });

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
            eprintln!("检测数据库类型失败: {}", e);
            FfiErrorCode::DatabaseError as c_int
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
    let password = match CStr::from_ptr(password).to_str() {
        Ok(s) => s,
        Err(_) => return FfiErrorCode::InvalidPassword as c_int,
    };

    let mut state = APP_STATE.lock().unwrap();
    let state = match state.as_mut() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

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

    // 保存加密数据库
    match save_encrypted_db(memory_conn, &state.db_path, &key) {
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
    let should_save = save != 0;

    let mut state = APP_STATE.lock().unwrap();
    let state = match state.as_mut() {
        Some(s) => s,
        None => return FfiErrorCode::Success as c_int, // 已经清理过了
    };

    // 保存数据（如果需要）
    if should_save && state.is_dirty {
        if let Some(key) = state.master_key {
            if let Some(memory_conn) = state.memory_conn.as_ref() {
                match save_encrypted_db(memory_conn, &state.db_path, &key) {
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
