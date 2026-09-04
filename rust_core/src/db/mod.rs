//! 数据库模块
//!
//! SQLite 数据库操作和模型定义

pub mod models;
pub mod schema;
pub mod crud;
pub mod custom_types;
pub mod custom_crud;
pub mod encrypted;
pub mod snapshot_crud;
pub mod attachment_storage;

pub use models::{Asset, Liability, AssetHistory, Attachment, AssetType, LiabilityType, AssetChange, ChangeType, NetWorthSnapshot};
pub use schema::{create_schema, init_db, wipe_db};
pub use crud::{AssetRepository, LiabilityRepository, HistoryRepository, AttachmentRepository, AssetChangeRepository};
pub use custom_types::CustomAssetType;
pub use custom_crud::CustomTypeRepository;
pub use encrypted::{is_encrypted_db, save_encrypted_db, load_encrypted_db, load_plaintext_db};
pub use snapshot_crud::NetWorthSnapshotRepository;
pub use attachment_storage::{
    attachments_dir, get_or_create_attachment_key, save_attachment_file, load_attachment_file,
    delete_attachment_file,
};

use rusqlite::Connection;

/// 数据库错误类型
#[derive(Debug, thiserror::Error)]
pub enum DbError {
    #[error("数据库错误: {0}")]
    DatabaseError(String),

    #[error("未找到记录: {0}")]
    NotFound(String),

    #[error("记录已存在: {0}")]
    AlreadyExists(String),

    #[error("无效参数: {0}")]
    InvalidParam(String),
}

pub type DbResult<T> = std::result::Result<T, DbError>;

/// 打开内存数据库（用于解密后的数据）
pub fn open_memory_db() -> DbResult<Connection> {
    Connection::open_in_memory()
        .map_err(|e| DbError::DatabaseError(e.to_string()))
}
