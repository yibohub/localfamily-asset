//! LocalFamily Asset Core
//!
//! 本地家庭资产管理应用的核心库
//!
//! # 功能模块
//!
//! - **crypto**: 加密/解密、密钥派生、助记词
//! - **db**: 数据库模型、Schema、CRUD 操作
//! - **export**: 导出/导入加密 Zip

pub mod crypto;
pub mod db;
pub mod export;
pub mod ffi;

// 重新导出常用类型
pub use crypto::{
    CryptoError, Result as CryptoResult,
    encrypt_data, decrypt_data,
    derive_key, generate_salt,
    generate_mnemonic, mnemonic_to_seed, validate_mnemonic,
};

pub use db::{
    DbError, DbResult,
    Asset, AssetHistory, Attachment,
    AssetRepository, HistoryRepository, AttachmentRepository,
    create_schema, init_db, open_memory_db,
};

pub use db::models::AssetType;

pub use export::{
    ExportError, ExportResult,
    create_export_zip, import_from_zip,
};

/// 库版本
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// 库名称
pub const NAME: &str = env!("CARGO_PKG_NAME");

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version() {
        assert_eq!(VERSION, "0.1.0");
        assert_eq!(NAME, "localfamily-asset-core");
    }
}
