//! 附件加密存储模块
//!
//! 保单/房产证等附件文件的加密落盘与读取：
//! - 附件文件使用独立的附件密钥（DEK）进行 AES-256-GCM 加密，
//!   DEK 随机生成后保存在 settings 表中，受数据库主密码加密保护；
//!   修改密码只需重新加密数据库，附件文件无需重加密。
//! - 文件格式与加密数据库一致：
//!   `LFAENC01` (8B) + version (1B) + salt (32B，占位) + AES-256-GCM 密文

use std::fs;
use std::path::{Path, PathBuf};

use rusqlite::Connection;

use crate::crypto::{encrypt_data, decrypt_data, generate_salt};
use super::{DbError, DbResult};

/// settings 表中附件密钥的键名
pub const ATTACHMENT_DEK_KEY: &str = "attachment_dek";

/// 附件密文文件扩展名
pub const ATTACHMENT_FILE_EXT: &str = "lfaenc";

/// 附件文件头长度：magic(8) + version(1) + salt(32)
const ATTACHMENT_HEADER_LEN: usize = 41;

/// 附件目录：数据库文件所在目录下的 attachments/ 子目录
pub fn attachments_dir<P: AsRef<Path>>(db_path: P) -> PathBuf {
    db_path
        .as_ref()
        .parent()
        .unwrap_or_else(|| Path::new("."))
        .join("attachments")
}

/// 读取（或首次生成）附件密钥
///
/// 密钥为随机 32 字节，以十六进制存于 settings 表，
/// 数据库本身已用主密码加密，因此密钥安全级别与主数据一致。
pub fn get_or_create_attachment_key(conn: &Connection) -> DbResult<[u8; 32]> {
    let existing: Option<String> = conn
        .query_row(
            "SELECT value FROM settings WHERE key = ?1",
            [ATTACHMENT_DEK_KEY],
            |row| row.get(0),
        )
        .map(Some)
        .or_else(|e| match e {
            rusqlite::Error::QueryReturnedNoRows => Ok(None),
            other => Err(DbError::DatabaseError(other.to_string())),
        })?;

    if let Some(hex_str) = existing {
        let bytes = hex::decode(&hex_str)
            .map_err(|e| DbError::DatabaseError(format!("附件密钥解码失败: {}", e)))?;
        if bytes.len() != 32 {
            return Err(DbError::DatabaseError("附件密钥长度非法".to_string()));
        }
        let mut key = [0u8; 32];
        key.copy_from_slice(&bytes);
        return Ok(key);
    }

    let key = generate_salt(); // 复用 CSPRNG 32 字节生成
    conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
        [ATTACHMENT_DEK_KEY, &hex::encode(key)],
    )
    .map_err(|e| DbError::DatabaseError(format!("保存附件密钥失败: {}", e)))?;
    Ok(key)
}

/// 将附件字节加密后写入附件目录
///
/// 返回密文文件名（仅文件名，不含目录；完整路径由调用方按数据库位置推导）
pub fn save_attachment_file(
    dir: &Path,
    file_stem: &str,
    key: &[u8; 32],
    data: &[u8],
) -> DbResult<String> {
    fs::create_dir_all(dir)
        .map_err(|e| DbError::DatabaseError(format!("创建附件目录失败: {}", e)))?;

    let encrypted = encrypt_data(key, data)
        .map_err(|e| DbError::DatabaseError(format!("附件加密失败: {}", e)))?;

    let mut file_data = Vec::with_capacity(ATTACHMENT_HEADER_LEN + encrypted.len());
    file_data.extend_from_slice(super::encrypted::ENCRYPTED_MAGIC);
    file_data.push(super::encrypted::ENCRYPTED_VERSION);
    file_data.extend_from_slice(&generate_salt());
    file_data.extend_from_slice(&encrypted);

    let file_name = format!("{}.{}", file_stem, ATTACHMENT_FILE_EXT);
    let path = dir.join(&file_name);
    fs::write(&path, &file_data)
        .map_err(|e| DbError::DatabaseError(format!("写入附件文件失败: {}", e)))?;
    Ok(file_name)
}

/// 从附件目录读取并解密附件字节
pub fn load_attachment_file(dir: &Path, file_name: &str, key: &[u8; 32]) -> DbResult<Vec<u8>> {
    // 防路径穿越：只允许纯文件名
    if file_name.contains('/') || file_name.contains('\\') || file_name.contains("..") {
        return Err(DbError::DatabaseError("附件文件名非法".to_string()));
    }

    let path = dir.join(file_name);
    let file_data = fs::read(&path)
        .map_err(|e| DbError::DatabaseError(format!("读取附件文件失败: {}", e)))?;

    if file_data.len() < ATTACHMENT_HEADER_LEN || &file_data[..8] != super::encrypted::ENCRYPTED_MAGIC {
        return Err(DbError::DatabaseError("附件文件格式非法".to_string()));
    }

    decrypt_data(key, &file_data[ATTACHMENT_HEADER_LEN..])
        .map_err(|e| DbError::DatabaseError(format!("附件解密失败: {}", e)))
}

/// 删除附件密文文件（文件不存在视为已删除）
pub fn delete_attachment_file(dir: &Path, file_name: &str) -> DbResult<()> {
    if file_name.contains('/') || file_name.contains('\\') || file_name.contains("..") {
        return Err(DbError::DatabaseError("附件文件名非法".to_string()));
    }
    let path = dir.join(file_name);
    if path.exists() {
        fs::remove_file(&path)
            .map_err(|e| DbError::DatabaseError(format!("删除附件文件失败: {}", e)))?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_conn() -> Connection {
        let conn = Connection::open_in_memory().unwrap();
        crate::db::create_schema(&conn).unwrap();
        conn
    }

    #[test]
    fn test_attachment_key_get_or_create() {
        let conn = test_conn();
        let key1 = get_or_create_attachment_key(&conn).unwrap();
        let key2 = get_or_create_attachment_key(&conn).unwrap();
        assert_eq!(key1, key2, "同库两次获取应返回同一密钥");

        // 换一个新库，密钥应不同
        let conn2 = test_conn();
        let key3 = get_or_create_attachment_key(&conn2).unwrap();
        assert_ne!(key1, key3, "不同库的密钥应相互独立");
    }

    #[test]
    fn test_attachment_file_roundtrip() {
        let conn = test_conn();
        let key = get_or_create_attachment_key(&conn).unwrap();
        let dir = std::env::temp_dir().join(format!("lfa_att_test_{}", std::process::id()));

        let data = b"fake insurance photo bytes".to_vec();
        let file_name = save_attachment_file(&dir, "att-1", &key, &data).unwrap();
        assert!(file_name.ends_with(ATTACHMENT_FILE_EXT));
        assert!(dir.join(&file_name).exists());

        let loaded = load_attachment_file(&dir, &file_name, &key).unwrap();
        assert_eq!(loaded, data);

        delete_attachment_file(&dir, &file_name).unwrap();
        assert!(!dir.join(&file_name).exists());
        let _ = fs::remove_dir(&dir);
    }

    #[test]
    fn test_attachment_file_wrong_key_fails() {
        let conn = test_conn();
        let key = get_or_create_attachment_key(&conn).unwrap();
        let dir = std::env::temp_dir().join(format!("lfa_att_test2_{}", std::process::id()));

        let file_name = save_attachment_file(&dir, "att-2", &key, b"secret").unwrap();
        let wrong_key = [7u8; 32];
        assert!(load_attachment_file(&dir, &file_name, &wrong_key).is_err());

        delete_attachment_file(&dir, &file_name).unwrap();
        let _ = fs::remove_dir(&dir);
    }

    #[test]
    fn test_attachment_file_rejects_path_traversal() {
        let dir = std::env::temp_dir();
        assert!(load_attachment_file(&dir, "../evil.lfaenc", &[0u8; 32]).is_err());
        assert!(delete_attachment_file(&dir, "a\\b.lfaenc").is_err());
    }
}
