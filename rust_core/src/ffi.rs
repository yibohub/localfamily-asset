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
use crate::db::{Asset, AssetRepository, AssetType, DbError, DbResult, AssetChange, ChangeType, AssetChangeRepository, CustomAssetType, CustomTypeRepository};
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
    master_key: Option<Vec<u8>>,
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
#[no_mangle]
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
#[no_mangle]
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
    let key = match derive_key(password, &salt) {
        Ok(k) => k.to_vec(),
        Err(_) => return FfiErrorCode::CryptoError as c_int,
    };

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
    let key = match derive_key(password, &salt) {
        Ok(k) => k.to_vec(),
        Err(_) => return FfiErrorCode::CryptoError as c_int,
    };

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
#[no_mangle]
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
    let key = match mnemonic_to_key(mnemonic_str) {
        Ok(k) => k.to_vec(),
        Err(e) => {
            write_log(&format!("助记词派生密钥失败: {}", e));
            return FfiErrorCode::CryptoError as c_int;
        }
    };

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
#[no_mangle]
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
#[no_mangle]
#[export_name = "generate_mnemonic"]
pub unsafe extern "C" fn generate_mnemonic() -> *mut c_char {
    match crate::crypto::generate_mnemonic() {
        Ok(mnemonic) => string_to_c_char(mnemonic),
        Err(_) => ptr::null_mut(),
    }
}

/// 保存助记词
#[no_mangle]
#[export_name = "save_mnemonic"]
pub unsafe extern "C" fn save_mnemonic(mnemonic: *const c_char) -> c_int {
    let mnemonic = match CStr::from_ptr(mnemonic).to_str() {
        Ok(s) => s,
        Err(_) => return FfiErrorCode::InvalidPassword as c_int,
    };

    let mut state = APP_STATE.lock().unwrap();
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

/// 获取资产类型枚举值
fn asset_type_from_int(value: c_int) -> AssetType {
    match value {
        0 => AssetType::Property,
        1 => AssetType::Deposit,
        2 => AssetType::Stock,
        3 => AssetType::Fund,
        4 => AssetType::Insurance,
        5 => AssetType::Debt,
        6 => AssetType::Mortgage,
        7 => AssetType::CarLoan,
        8 => AssetType::CreditCard,
        9 => AssetType::PersonalLoan,
        10 => AssetType::PrivateLoan,
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
        buy_price: existing.buy_price,
        current_price: existing.current_price,
        tags: existing.tags.clone(),
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
#[no_mangle]
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
#[no_mangle]
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
#[no_mangle]
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
#[no_mangle]
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
        buy_price,
        current_price,
        tags,
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

