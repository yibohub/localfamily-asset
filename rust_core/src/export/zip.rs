//! 创建和导入加密 Zip 导出文件

use std::io::{Read, Write};
use std::fs::File;
use std::path::Path;

use super::{ExportError, ExportResult};
use crate::crypto::{encrypt_data, decrypt_data};

/// 导出元数据（版本信息）
pub const EXPORT_VERSION: &str = "1.0";
pub const EXPORT_METADATA_FILE: &str = "metadata.json";

/// 导出元数据结构
#[derive(serde::Serialize, serde::Deserialize)]
pub struct ExportMetadata {
    pub version: String,
    pub created_at: i64,
    pub app_name: String,
}

/// 创建加密导出 Zip
///
/// 参数:
/// - db_data: 加密后的数据库字节数据
/// - output_path: 输出 Zip 文件路径
/// - key: 加密密钥
pub fn create_export_zip(
    db_data: &[u8],
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

    zip.finish()
        .map_err(|e| ExportError::ZipCreationFailed(e.to_string()))?;

    Ok(())
}

/// 从加密 Zip 导入数据库
///
/// 参数:
/// - zip_path: Zip 文件路径
/// - key: 解密密钥
///
/// 返回解密后的数据库字节数据
pub fn import_from_zip(
    zip_path: &Path,
    key: &[u8; 32],
) -> ExportResult<Vec<u8>> {
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

    // 读取加密的数据库
    let mut db_file = archive.by_name("database.enc")
        .map_err(|_| ExportError::ImportFailed("缺少数据库文件".to_string()))?;

    let mut encrypted_db = Vec::new();
    db_file.read_to_end(&mut encrypted_db)
        .map_err(|e| ExportError::ImportFailed(e.to_string()))?;

    // 解密
    let db_data = decrypt_data(key, &encrypted_db)
        .map_err(|e| ExportError::DecryptionFailed(e.to_string()))?;

    Ok(db_data)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_and_import_zip() {
        let key = [42u8; 32];
        let db_data = b"test database content";
        let output_path = std::env::temp_dir().join("test_export.zip");

        // 创建导出
        create_export_zip(db_data, &output_path, &key).unwrap();

        // 导入
        let imported_data = import_from_zip(&output_path, &key).unwrap();
        assert_eq!(db_data.to_vec(), imported_data);

        // 清理
        std::fs::remove_file(output_path).ok();
    }

    #[test]
    fn test_wrong_key_fails() {
        let key1 = [1u8; 32];
        let key2 = [2u8; 32];
        let db_data = b"test database content";
        let output_path = std::env::temp_dir().join("test_export_wrong.zip");

        create_export_zip(db_data, &output_path, &key1).unwrap();

        let result = import_from_zip(&output_path, &key2);
        assert!(result.is_err());

        std::fs::remove_file(output_path).ok();
    }
}
