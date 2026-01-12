//! AES-256-GCM 加密/解密实现
//!
//! 使用 12 字节 nonce，AES-256-GCM 认证加密

use aes_gcm::{
    aead::{Aead, AeadCore, KeyInit, OsRng},
    Aes256Gcm, Nonce,
};

use super::{CryptoError, Result as CryptoResult};

/// 加密数据
///
/// 返回格式: [nonce (12字节)] + [ciphertext + auth_tag]
pub fn encrypt_data(key: &[u8; 32], plaintext: &[u8]) -> CryptoResult<Vec<u8>> {
    // 创建密文实例
    let cipher = Aes256Gcm::new(key.into());

    // 生成随机 nonce
    let nonce = Aes256Gcm::generate_nonce(&mut OsRng);

    // 加密
    let ciphertext = cipher
        .encrypt(&nonce, plaintext)
        .map_err(|e| CryptoError::EncryptionFailed(e.to_string()))?;

    // 返回 nonce + ciphertext
    let mut result = Vec::with_capacity(12 + ciphertext.len());
    result.extend_from_slice(&nonce);
    result.extend_from_slice(&ciphertext);

    Ok(result)
}

/// 解密数据
///
/// 输入格式: [nonce (12字节)] + [ciphertext + auth_tag]
pub fn decrypt_data(key: &[u8; 32], encrypted: &[u8]) -> CryptoResult<Vec<u8>> {
    if encrypted.len() < 12 {
        return Err(CryptoError::DecryptionFailed(
            "加密数据太短".to_string(),
        ));
    }

    // 提取 nonce
    let nonce = Nonce::from_slice(&encrypted[..12]);

    // 提取密文
    let ciphertext = &encrypted[12..];

    // 创建密文实例
    let cipher = Aes256Gcm::new(key.into());

    // 解密
    let plaintext = cipher
        .decrypt(nonce, ciphertext)
        .map_err(|e| CryptoError::DecryptionFailed(e.to_string()))?;

    Ok(plaintext)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encrypt_decrypt() {
        let key = [0u8; 32];
        let plaintext = b"Hello, LocalFamily Asset!";

        let encrypted = encrypt_data(&key, plaintext).unwrap();
        let decrypted = decrypt_data(&key, &encrypted).unwrap();

        assert_eq!(plaintext.to_vec(), decrypted);
    }

    #[test]
    fn test_wrong_key_fails() {
        let key1 = [1u8; 32];
        let key2 = [2u8; 32];
        let plaintext = b"Secret data";

        let encrypted = encrypt_data(&key1, plaintext).unwrap();
        let result = decrypt_data(&key2, &encrypted);

        assert!(result.is_err());
    }
}
