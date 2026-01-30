//! 加密模块
//!
//! 提供文件级 AES-256-GCM 加密和 Argon2id 密钥派生

pub mod aes_gcm;
pub mod argon2;
pub mod bip39;

pub use aes_gcm::{decrypt_data, encrypt_data};
pub use argon2::{derive_key, generate_salt};
pub use bip39::{generate_mnemonic, mnemonic_to_seed, mnemonic_to_key, validate_mnemonic};

/// 加密错误类型
#[derive(Debug, thiserror::Error)]
pub enum CryptoError {
    #[error("加密失败: {0}")]
    EncryptionFailed(String),

    #[error("解密失败: {0}")]
    DecryptionFailed(String),

    #[error("密钥派生失败: {0}")]
    KeyDerivationFailed(String),

    #[error("助记词无效: {0}")]
    InvalidMnemonic(String),

    #[error("配置错误: {0}")]
    ConfigError(String),
}

pub type Result<T> = std::result::Result<T, CryptoError>;
