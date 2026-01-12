//! 导出模块
//!
//! 导出加密 Zip 包（包含数据库和附件）

pub mod zip;

pub use zip::{create_export_zip, import_from_zip};

/// 导出错误类型
#[derive(Debug, thiserror::Error)]
pub enum ExportError {
    #[error("创建 Zip 失败: {0}")]
    ZipCreationFailed(String),

    #[error("导入失败: {0}")]
    ImportFailed(String),

    #[error("文件错误: {0}")]
    FileError(String),

    #[error("加密失败: {0}")]
    EncryptionFailed(String),

    #[error("解密失败: {0}")]
    DecryptionFailed(String),
}

pub type ExportResult<T> = std::result::Result<T, ExportError>;
