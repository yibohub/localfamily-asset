//! FFI (Foreign Function Interface) 模块
//!
//! 提供 C 兼容的 API 供 Flutter 调用

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_double, c_int};
use std::ptr;

use once_cell::sync::Lazy;

use crate::crypto::{derive_key, generate_salt};
use crate::db::{Asset, AssetRepository, AssetType, DbError, DbResult};
use rusqlite::Connection;

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
        db_path,
        master_key: None,
    });

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

    // 创建数据库表结构
    if let Err(e) = crate::db::create_schema(&_conn) {
        eprintln!("创建数据库表结构失败: {}", e);
        return FfiErrorCode::DatabaseError as c_int;
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

    // 打开数据库获取盐值
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

    // 将密钥保存到状态
    state.master_key = Some(key);

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
) -> c_int {
    let name = match CStr::from_ptr(name).to_str() {
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

    let asset_type = asset_type_from_int(asset_type);

    let state = APP_STATE.lock().unwrap();
    let state = match state.as_ref() {
        Some(s) => s,
        None => return FfiErrorCode::GenericError as c_int,
    };

    let conn = match open_db(&state.db_path) {
        Ok(c) => c,
        Err(_) => return FfiErrorCode::DatabaseError as c_int,
    };

    let asset = Asset::new(asset_type, name, amount);
    let asset = Asset {
        currency,
        note,
        ..asset
    };

    match AssetRepository::create(&conn, &asset) {
        Ok(_) => FfiErrorCode::Success as c_int,
        Err(_) => FfiErrorCode::DatabaseError as c_int,
    }
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
) -> c_int {
    let id = match CStr::from_ptr(id).to_str() {
        Ok(s) => s.to_string(),
        Err(_) => return FfiErrorCode::GenericError as c_int,
    };

    let name = match CStr::from_ptr(name).to_str() {
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

    let asset_type = asset_type_from_int(asset_type);

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

    // 更新字段
    let asset = Asset {
        id,
        name,
        amount,
        currency,
        asset_type,
        note,
        ..existing
    };

    match AssetRepository::update(&conn, &asset) {
        Ok(_) => FfiErrorCode::Success as c_int,
        Err(_) => FfiErrorCode::DatabaseError as c_int,
    }
}

/// 删除资产
#[no_mangle]
pub unsafe extern "C" fn delete_asset(id: *const c_char) -> c_int {
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

    match AssetRepository::delete(&conn, id) {
        Ok(_) => FfiErrorCode::Success as c_int,
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
