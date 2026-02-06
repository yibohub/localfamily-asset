//! 数据库文件级加密模块
//!
//! 使用 AES-256-GCM 对 SQLite 数据库进行文件级加密
//! - 直接使用文件读写进行序列化
//! - 支持向后兼容（自动检测并迁移旧明文数据库）

use std::fs::File;
use std::io::Read;
use std::path::Path;

use rusqlite::Connection;

use crate::crypto::{decrypt_data, encrypt_data};
use super::{DbError, DbResult};

/// 加密文件魔数（用于识别加密数据库文件）
pub const ENCRYPTED_MAGIC: &[u8; 8] = b"LFAENC01";

/// 加密文件格式版本
pub const ENCRYPTED_VERSION: u8 = 0x01;

/// SQLite 文件魔数（用于识别明文数据库）
pub const SQLITE_MAGIC: &[u8; 16] = b"SQLite format 3\x00";

/// 检测文件是否为加密数据库
///
/// 通过读取文件头判断：
/// - "LFAENC01" 开头 → 加密数据库
/// - "SQLite format 3" 开头 → 明文数据库
/// - 其他 → 无效文件
pub fn is_encrypted_db<P: AsRef<Path>>(path: P) -> DbResult<bool> {
    let path = path.as_ref();

    // 检查文件是否存在
    if !path.exists() {
        return Ok(false); // 文件不存在，不算加密
    }

    let mut file = File::open(path)
        .map_err(|e| DbError::DatabaseError(format!("无法打开文件: {}", e)))?;

    let mut header = [0u8; 16];
    let n = file.read(&mut header)
        .map_err(|e| DbError::DatabaseError(format!("无法读取文件头: {}", e)))?;

    if n < 8 {
        return Err(DbError::DatabaseError("文件太小，无法识别".to_string()));
    }

    // 检查是否为加密格式
    if &header[..8] == ENCRYPTED_MAGIC {
        return Ok(true);
    }

    // 检查是否为 SQLite 格式
    if n >= 16 && &header[..16] == SQLITE_MAGIC {
        return Ok(false);
    }

    Err(DbError::DatabaseError("无法识别的文件格式".to_string()))
}

/// 序列化内存数据库到字节
///
/// 使用 SQL dump 和重建的方式来序列化内存数据库
pub fn serialize_db(conn: &Connection) -> DbResult<Vec<u8>> {
    let temp_dir = std::env::temp_dir();
    let temp_path = temp_dir.join(format!("localfamily_serialize_{}.db", std::process::id()));

    // 首先使用 backup API 将内存数据库备份到文件
    // backup 方法的签名是: backup<P: AsRef<Path>>(name, path, progress)
    let progress: Option<fn(rusqlite::backup::Progress)> = None;
    conn.backup(
        rusqlite::DatabaseName::Main,
        &temp_path,
        progress,
    ).map_err(|e| DbError::DatabaseError(format!("序列化数据库失败: {}", e)))?;

    // 读取临时文件内容
    let db_bytes = std::fs::read(&temp_path)
        .map_err(|e| DbError::DatabaseError(format!("无法读取临时文件: {}", e)))?;

    // 删除临时文件
    let _ = std::fs::remove_file(&temp_path);

    Ok(db_bytes)
}

/// 将字节反序列化到内存数据库
///
/// 从字节数据创建一个新的内存数据库
pub fn deserialize_to_memory(bytes: &[u8]) -> DbResult<Connection> {
    // 创建临时文件
    let temp_dir = std::env::temp_dir();
    let temp_path = temp_dir.join(format!("localfamily_load_{}.db", std::process::id()));

    // 写入字节数据到临时文件
    std::fs::write(&temp_path, bytes)
        .map_err(|e| DbError::DatabaseError(format!("无法写入临时文件: {}", e)))?;

    // 创建内存数据库
    let mut memory_conn = Connection::open_in_memory()
        .map_err(|e| DbError::DatabaseError(format!("无法创建内存数据库: {}", e)))?;

    // 使用 restore API：从文件恢复到内存数据库
    // 使用类型注解明确指定 None 的类型
    let progress: Option<fn(rusqlite::backup::Progress)> = None;
    memory_conn.restore(
        rusqlite::DatabaseName::Main,
        &temp_path,
        progress,
    ).map_err(|e| DbError::DatabaseError(format!("恢复内存数据库失败: {}", e)))?;

    // 删除临时文件
    let _ = std::fs::remove_file(&temp_path);

    Ok(memory_conn)
}

/// 加密并保存数据库到文件
///
/// 文件格式：
/// ┌─────────────────────────────────────────┐
/// │ Magic Header (8B): "LFAENC01"          │
/// ├─────────────────────────────────────────┤
/// │ Version (1B): 0x01                      │
/// ├─────────────────────────────────────────┤
/// │ Salt (32B)                              │
/// ├─────────────────────────────────────────┤
/// │ Encrypted Payload (AES-256-GCM):        │
/// │   - nonce (12B)                         │
/// │   - ciphertext + auth_tag               │
/// └─────────────────────────────────────────┘
pub fn save_encrypted_db<P: AsRef<Path>>(
    conn: &Connection,
    path: P,
    key: &[u8; 32],
    salt: &[u8; 32],
) -> DbResult<()> {
    // 序列化数据库
    let db_bytes = serialize_db(conn)?;

    // 使用提供的盐值和主密钥加密数据库字节
    let encrypted = encrypt_data(key, &db_bytes)
        .map_err(|e| DbError::DatabaseError(format!("加密失败: {}", e)))?;

    // 构建加密文件
    let mut file_data = Vec::new();
    file_data.extend_from_slice(ENCRYPTED_MAGIC);
    file_data.push(ENCRYPTED_VERSION);
    file_data.extend_from_slice(salt);
    file_data.extend_from_slice(&encrypted);

    // 写入文件
    let path = path.as_ref();

    // Windows 平台：先删除目标文件（如果存在），避免 rename 失败
    if path.exists() {
        // 尝试删除目标文件，忽略不存在的错误
        let _ = std::fs::remove_file(path);
    }

    // 写入临时文件
    let temp_path = path.with_extension("tmp");
    std::fs::write(&temp_path, &file_data)
        .map_err(|e| DbError::DatabaseError(format!("写入加密文件失败: {}", e)))?;

    // 原子性重命名（此时目标文件已被删除）
    std::fs::rename(&temp_path, path)
        .map_err(|e| DbError::DatabaseError(format!("重命名加密文件失败: {}", e)))?;

    Ok(())
}

/// 加载并解密数据库文件到内存
pub fn load_encrypted_db<P: AsRef<Path>>(
    path: P,
    key: &[u8; 32],
) -> DbResult<Connection> {
    let path = path.as_ref();

    // 读取加密文件
    let file_data = std::fs::read(path)
        .map_err(|e| DbError::DatabaseError(format!("读取加密文件失败: {}", e)))?;

    // 解析文件头
    if file_data.len() < 8 + 1 + 32 {
        return Err(DbError::DatabaseError("加密文件格式错误：文件太短".to_string()));
    }

    // 检查魔数
    if &file_data[..8] != ENCRYPTED_MAGIC {
        return Err(DbError::DatabaseError("加密文件格式错误：魔数不匹配".to_string()));
    }

    // 检查版本
    let version = file_data[8];
    if version != ENCRYPTED_VERSION {
        return Err(DbError::DatabaseError(format!("不支持的加密文件版本: {}", version)));
    }

    // 提取加密数据
    let encrypted = &file_data[41..];

    // 直接使用主密钥解密数据
    let decrypted = decrypt_data(key, encrypted)
        .map_err(|e| DbError::DatabaseError(format!("解密失败: {}", e)))?;

    // 反序列化到内存数据库
    deserialize_to_memory(&decrypted)
}

/// 加载旧明文数据库（向后兼容）
///
/// 此函数用于加载未加密的 SQLite 数据库文件
pub fn load_plaintext_db<P: AsRef<Path>>(path: P) -> DbResult<Connection> {
    let path = path.as_ref();

    // 读取明文数据库文件
    let db_bytes = std::fs::read(path)
        .map_err(|e| DbError::DatabaseError(format!("读取明文数据库失败: {}", e)))?;

    // 反序列化到内存数据库
    deserialize_to_memory(&db_bytes)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_encrypted_db_magic_detection() {
        let temp_dir = std::env::temp_dir();

        // 测试加密文件检测
        let encrypted_path = temp_dir.join("test_encrypted.db");
        let mut encrypted_data = ENCRYPTED_MAGIC.to_vec();
        encrypted_data.push(0x01);
        encrypted_data.extend_from_slice(&[0u8; 32]);
        encrypted_data.extend_from_slice(b"encrypted payload");
        std::fs::write(&encrypted_path, &encrypted_data).unwrap();
        assert!(is_encrypted_db(&encrypted_path).unwrap());
        std::fs::remove_file(&encrypted_path).unwrap();

        // 测试明文文件检测
        let plaintext_path = temp_dir.join("test_plaintext.db");
        std::fs::write(&plaintext_path, SQLITE_MAGIC).unwrap();
        assert!(!is_encrypted_db(&plaintext_path).unwrap());
        std::fs::remove_file(&plaintext_path).unwrap();
    }

    #[test]
    fn test_serialize_deserialize_roundtrip() {
        // 创建一个内存数据库并添加一些数据
        let conn = Connection::open_in_memory().unwrap();
        crate::db::create_schema(&conn).unwrap();

        // 添加当前时间戳
        let now = chrono::Utc::now().timestamp();

        conn.execute(
            "INSERT INTO assets (id, name, asset_type, amount, currency, occurrence_date, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            rusqlite::params!("test-id", "Test Asset", "deposit", 1000.0, "CNY", "2024-01-01", now, now),
        ).unwrap();

        // 序列化
        let bytes = serialize_db(&conn).unwrap();
        assert!(!bytes.is_empty());

        // 反序列化
        let conn2 = deserialize_to_memory(&bytes).unwrap();

        // 验证数据
        let name: String = conn2.query_row("SELECT name FROM assets WHERE id = ?", ["test-id"], |row| row.get(0)).unwrap();
        assert_eq!(name, "Test Asset");
    }

    #[test]
    fn test_encrypt_decrypt_roundtrip() {
        // 创建测试数据库
        let conn = Connection::open_in_memory().unwrap();
        crate::db::create_schema(&conn).unwrap();

        // 添加当前时间戳
        let now = chrono::Utc::now().timestamp();

        conn.execute(
            "INSERT INTO assets (id, name, asset_type, amount, currency, occurrence_date, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            rusqlite::params!("encrypt-test", "Encrypted Asset", "stock", 5000.0, "USD", "2024-02-01", now, now),
        ).unwrap();

        // 加密保存
        let temp_dir = std::env::temp_dir();
        let encrypted_path = temp_dir.join("test_encrypt_roundtrip.db");
        let key = [0u8; 32];

        save_encrypted_db(&conn, &encrypted_path, &key).unwrap();
        assert!(encrypted_path.exists());

        // 检测为加密文件
        assert!(is_encrypted_db(&encrypted_path).unwrap());

        // 解密加载
        let conn2 = load_encrypted_db(&encrypted_path, &key).unwrap();

        // 验证数据
        let name: String = conn2.query_row("SELECT name FROM assets WHERE id = ?", ["encrypt-test"], |row| row.get(0)).unwrap();
        assert_eq!(name, "Encrypted Asset");

        // 清理
        std::fs::remove_file(&encrypted_path).unwrap();
    }

    #[test]
    fn test_wrong_key_fails() {
        // 创建测试数据库
        let conn = Connection::open_in_memory().unwrap();
        crate::db::create_schema(&conn).unwrap();

        // 添加当前时间戳
        let now = chrono::Utc::now().timestamp();

        conn.execute(
            "INSERT INTO assets (id, name, asset_type, amount, currency, occurrence_date, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            rusqlite::params!("test-id", "Test Asset", "deposit", 1000.0, "CNY", "2024-01-01", now, now),
        ).unwrap();

        // 加密保存
        let temp_dir = std::env::temp_dir();
        let encrypted_path = temp_dir.join("test_wrong_key.db");
        let key1 = [1u8; 32];

        save_encrypted_db(&conn, &encrypted_path, &key1).unwrap();

        // 用错误的密钥解密
        let key2 = [2u8; 32];
        let result = load_encrypted_db(&encrypted_path, &key2);

        assert!(result.is_err());

        // 清理
        std::fs::remove_file(&encrypted_path).unwrap();
    }

    #[test]
    fn test_load_plaintext_db() {
        // 创建一个明文 SQLite 数据库
        let temp_dir = std::env::temp_dir();
        let plaintext_path = temp_dir.join("test_plaintext_load.db");

        // 添加当前时间戳
        let now = chrono::Utc::now().timestamp();

        {
            let conn = Connection::open(&plaintext_path).unwrap();
            crate::db::create_schema(&conn).unwrap();
            conn.execute(
                "INSERT INTO assets (id, name, asset_type, amount, currency, occurrence_date, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                rusqlite::params!("plaintext-test", "Plaintext Asset", "fund", 3000.0, "CNY", "2024-03-01", now, now),
            ).unwrap();
        }

        // 使用 load_plaintext_db 加载
        let conn = load_plaintext_db(&plaintext_path).unwrap();

        // 验证数据
        let name: String = conn.query_row("SELECT name FROM assets WHERE id = ?", ["plaintext-test"], |row| row.get(0)).unwrap();
        assert_eq!(name, "Plaintext Asset");

        // 清理
        std::fs::remove_file(&plaintext_path).unwrap();
    }
}
