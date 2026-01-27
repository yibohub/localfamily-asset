//! 数据库模块
//!
//! SQLite 数据库操作和模型定义

pub mod models;
pub mod schema;
pub mod crud;

pub use models::{Asset, AssetHistory, Attachment, AssetType, AssetChange, ChangeType};
pub use schema::{create_schema, init_db};
pub use crud::{AssetRepository, HistoryRepository, AttachmentRepository, AssetChangeRepository};

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
