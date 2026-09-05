//! 创建和导入加密 Zip 导出文件
//!
//! Zip 内布局：
//! - metadata.json（明文元数据）
//! - database.enc（主密钥加密的数据库）
//! - attachments/<name>.lfaenc（主密钥再加密的附件密文；附件本身以 DEK 加密落盘，
//!   备份中再包一层导出密钥，与数据库文件保持同一保护强度）

use std::io::{Read, Write};
use std::fs::File;
use std::path::Path;

use super::{ExportError, ExportResult};
use crate::crypto::{encrypt_data, decrypt_data};

/// 导出元数据（版本信息）
pub const EXPORT_VERSION: &str = "1.0";
pub const EXPORT_METADATA_FILE: &str = "metadata.json";
/// Zip 内附件条目的目录前缀
pub const EXPORT_ATTACHMENTS_PREFIX: &str = "attachments/";

/// 导出元数据结构
#[derive(serde::Serialize, serde::Deserialize)]
pub struct ExportMetadata {
    pub version: String,
    pub created_at: i64,
    pub app_name: String,
}

/// 导入结果：数据库字节 + 附件密文（文件名, 经导出密钥加密的字节）
pub struct ImportedBackup {
    pub db_data: Vec<u8>,
    pub attachments: Vec<(String, Vec<u8>)>,
}

/// 创建加密导出 Zip
///
/// 参数:
/// - db_data: 加密后的数据库字节数据
/// - attachments: 附件密文列表（文件名, 密文字节），写入前会再用导出密钥加密
/// - output_path: 输出 Zip 文件路径
/// - key: 加密密钥
pub fn create_export_zip(
    db_data: &[u8],
    attachments: &[(String, Vec<u8>)],
    output_path: &Path,
    key: &[u8; 32],
) -> ExportResult<()> {
    use zip::{ZipWriter, write::FileOptions};

    let file = File::create(output_path)
        .map_err(|e| ExportError::FileError(e.to_string()))?;

    let mut zip = ZipWriter::new(file);
    let options: FileOptions<'_, ()> = FileOptions::default()
        .compression_method(zip::CompressionMethod::Deflated);

    // 创建元数据
    let metadata = ExportMetadata {
        version: EXPORT_VERSION.to_string(),
        created_at: chrono::Utc::now().timestamp(),
        app_name: "LocalFamily Asset".to_string(),
    };
    let metadata_json = serde_json::to_string_pretty(&metadata)
        .map_err(|e| ExportError::ZipCreationFailed(e.to_string()))?;

    // 添加元数据文件（不加密）
    zip.start_file(EXPORT_METADATA_FILE, options)
        .map_err(|e| ExportError::ZipCreationFailed(e.to_string()))?;
    zip.write_all(metadata_json.as_bytes())
        .map_err(|e| ExportError::ZipCreationFailed(e.to_string()))?;

    // 加密数据库数据
    let encrypted_db = encrypt_data(key, db_data)
        .map_err(|e| ExportError::EncryptionFailed(e.to_string()))?;

    // 添加加密的数据库文件
    zip.start_file("database.enc", options)
        .map_err(|e| ExportError::ZipCreationFailed(e.to_string()))?;
    zip.write_all(&encrypted_db)
        .map_err(|e| ExportError::ZipCreationFailed(e.to_string()))?;

    // 附件密文（重新用导出密钥加密，避免依赖外部保护）
    for (file_name, data) in attachments {
        let encrypted = encrypt_data(key, data)
            .map_err(|e| ExportError::EncryptionFailed(e.to_string()))?;
        let entry = format!("{}{}", EXPORT_ATTACHMENTS_PREFIX, file_name);
        zip.start_file(entry, options)
            .map_err(|e| ExportError::ZipCreationFailed(e.to_string()))?;
        zip.write_all(&encrypted)
            .map_err(|e| ExportError::ZipCreationFailed(e.to_string()))?;
    }

    zip.finish()
        .map_err(|e| ExportError::ZipCreationFailed(e.to_string()))?;

    Ok(())
}

/// 从加密 Zip 导入数据库与附件
///
/// 参数:
/// - zip_path: Zip 文件路径
/// - key: 解密密钥
///
/// 返回解密后的数据库字节数据与附件密文列表（旧版本备份无附件时列表为空）
pub fn import_from_zip(
    zip_path: &Path,
    key: &[u8; 32],
) -> ExportResult<ImportedBackup> {
    use zip::ZipArchive;

    let file = File::open(zip_path)
        .map_err(|e| ExportError::FileError(e.to_string()))?;

    let mut archive = ZipArchive::new(file)
        .map_err(|e| ExportError::ImportFailed(e.to_string()))?;

    // 检查元数据文件是否存在
    let _metadata = match archive.by_name(EXPORT_METADATA_FILE) {
        Ok(mut metadata_file) => {
            let mut metadata_str = String::new();
            metadata_file.read_to_string(&mut metadata_str)
                .map_err(|e| ExportError::ImportFailed(e.to_string()))?;

            serde_json::from_str::<ExportMetadata>(&metadata_str)
                .map_err(|e| ExportError::ImportFailed(format!("无效的元数据: {}", e)))?
        }
        Err(_) => {
            return Err(ExportError::ImportFailed("缺少元数据文件".to_string()));
        }
    };

    // 读取加密的数据库（块内限制 ZipFile 借用，随后才能遍历附件条目）
    let encrypted_db = {
        let mut db_file = archive.by_name("database.enc")
            .map_err(|_| ExportError::ImportFailed("缺少数据库文件".to_string()))?;

        let mut encrypted_db = Vec::new();
        db_file.read_to_end(&mut encrypted_db)
            .map_err(|e| ExportError::ImportFailed(e.to_string()))?;
        encrypted_db
    };

    // 解密
    let db_data = decrypt_data(key, &encrypted_db)
        .map_err(|e| ExportError::DecryptionFailed(e.to_string()))?;

    // 收集附件条目（旧版本备份没有该目录，返回空列表）
    let mut attachments: Vec<(String, Vec<u8>)> = Vec::new();
    for i in 0..archive.len() {
        let mut entry = archive.by_index(i)
            .map_err(|e| ExportError::ImportFailed(e.to_string()))?;
        let name = entry.name().to_string();
        let Some(base_name) = name.strip_prefix(EXPORT_ATTACHMENTS_PREFIX) else {
            continue;
        };
        // 防路径穿越：只接受纯文件名
        if base_name.is_empty()
            || base_name.contains('/')
            || base_name.contains('\\')
            || base_name.contains("..")
        {
            continue;
        }
        let mut encrypted = Vec::new();
        entry.read_to_end(&mut encrypted)
            .map_err(|e| ExportError::ImportFailed(e.to_string()))?;
        let data = decrypt_data(key, &encrypted)
            .map_err(|e| ExportError::DecryptionFailed(format!("附件 {} 解密失败: {}", base_name, e)))?;
        attachments.push((base_name.to_string(), data));
    }

    Ok(ImportedBackup { db_data, attachments })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_and_import_zip() {
        let key = [42u8; 32];
        let db_data = b"test database content";
        let output_path = std::env::temp_dir().join("test_export.zip");
        let attachments = vec![(
            "att-1.lfaenc".to_string(),
            b"encrypted attachment bytes".to_vec(),
        )];

        // 创建导出
        create_export_zip(db_data, &attachments, &output_path, &key).unwrap();

        // 导入
        let imported = import_from_zip(&output_path, &key).unwrap();
        assert_eq!(db_data.to_vec(), imported.db_data);
        assert_eq!(imported.attachments.len(), 1);
        assert_eq!(imported.attachments[0].0, "att-1.lfaenc");
        assert_eq!(imported.attachments[0].1, b"encrypted attachment bytes".to_vec());

        // 清理
        std::fs::remove_file(output_path).ok();
    }

    #[test]
    fn test_import_zip_without_attachments() {
        let key = [42u8; 32];
        let db_data = b"legacy backup";
        let output_path = std::env::temp_dir().join("test_export_legacy.zip");
        let no_attachments: Vec<(String, Vec<u8>)> = Vec::new();

        create_export_zip(db_data, &no_attachments, &output_path, &key).unwrap();

        let imported = import_from_zip(&output_path, &key).unwrap();
        assert_eq!(db_data.to_vec(), imported.db_data);
        assert!(imported.attachments.is_empty());

        std::fs::remove_file(output_path).ok();
    }

    #[test]
    fn test_wrong_key_fails() {
        let key1 = [1u8; 32];
        let key2 = [2u8; 32];
        let db_data = b"test database content";
        let output_path = std::env::temp_dir().join("test_export_wrong.zip");
        let attachments = vec![("a.lfaenc".to_string(), b"data".to_vec())];

        create_export_zip(db_data, &attachments, &output_path, &key1).unwrap();

        let result = import_from_zip(&output_path, &key2);
        assert!(result.is_err());

        std::fs::remove_file(output_path).ok();
    }
}
