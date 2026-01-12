//! BIP39 助记词生成与恢复
//!
//! 支持 12/15/18/21/24 词助记词

use bip39::Mnemonic;
use bip39::Language;
use rand::RngCore;

use super::{CryptoError, Result as CryptoResult};

/// 生成 12 词助记词（默认）
pub fn generate_mnemonic() -> CryptoResult<String> {
    // 使用随机熵生成助记词
    let mut entropy = [0u8; 16]; // 12 词需要 128 位熵
    rand::rngs::OsRng.fill_bytes(&mut entropy);
    let mnemonic = Mnemonic::from_entropy_in(Language::English, &entropy)
        .map_err(|e| CryptoError::InvalidMnemonic(e.to_string()))?;
    Ok(mnemonic.to_string())
}

/// 从助记词派生种子密钥
///
/// 可选密码（passphrase）用于增强安全性
pub fn mnemonic_to_seed(mnemonic: &str, passphrase: Option<&str>) -> CryptoResult<[u8; 32]> {
    let mnemonic = Mnemonic::parse_in_normalized(Language::English, mnemonic)
        .map_err(|e| CryptoError::InvalidMnemonic(e.to_string()))?;

    let seed = mnemonic.to_seed(passphrase.unwrap_or(""));
    let seed_bytes = seed.as_ref();

    // 取前 32 字节作为密钥
    if seed_bytes.len() < 32 {
        return Err(CryptoError::InvalidMnemonic(
            "种子长度不足".to_string(),
        ));
    }

    let mut key = [0u8; 32];
    key.copy_from_slice(&seed_bytes[..32]);
    Ok(key)
}

/// 验证助记词是否有效
pub fn validate_mnemonic(mnemonic: &str) -> CryptoResult<bool> {
    Ok(Mnemonic::parse_in_normalized(Language::English, mnemonic).is_ok())
}

/// 从助记词直接派生加密密钥（不带额外密码）
pub fn mnemonic_to_key(mnemonic: &str) -> CryptoResult<[u8; 32]> {
    mnemonic_to_seed(mnemonic, None)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_mnemonic() {
        let mnemonic = generate_mnemonic().unwrap();
        let words: Vec<&str> = mnemonic.split_whitespace().collect();
        assert_eq!(words.len(), 12);
    }

    #[test]
    fn test_mnemonic_to_key() {
        let mnemonic = generate_mnemonic().unwrap();
        let key = mnemonic_to_key(&mnemonic).unwrap();
        assert_ne!(key, [0u8; 32]);
    }

    #[test]
    fn test_same_mnemonic_same_key() {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
        let key1 = mnemonic_to_key(mnemonic).unwrap();
        let key2 = mnemonic_to_key(mnemonic).unwrap();
        assert_eq!(key1, key2);
    }

    #[test]
    fn test_validate_mnemonic() {
        let valid = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
        let invalid = "word word word word";

        assert!(validate_mnemonic(valid).unwrap());
        assert!(!validate_mnemonic(invalid).unwrap());
    }

    #[test]
    fn test_mnemonic_with_passphrase() {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
        let key1 = mnemonic_to_seed(mnemonic, Some("password")).unwrap();
        let key2 = mnemonic_to_seed(mnemonic, None).unwrap();

        assert_ne!(key1, key2);
    }
}
