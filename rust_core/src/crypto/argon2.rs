//! Argon2id 密钥派生
//!
//! 从密码或助记词派生 256 位加密密钥

use argon2::{Argon2, Algorithm, Params, Version};
use rand::RngCore;

use super::{CryptoError, Result as CryptoResult};

/// Argon2id 参数（标准安全配置）
const ARGON2_M_COST: u32 = 65536; // 内存成本 (64 MB)
const ARGON2_T_COST: u32 = 3;     // 时间成本 (迭代次数)
const ARGON2_P_COST: u32 = 4;     // 并行度

/// 从密码派生密钥
///
/// 使用 Argon2id 从密码派生 256 位密钥
pub fn derive_key(password: &str, salt: &[u8; 32]) -> CryptoResult<[u8; 32]> {
    // 构建 Argon2id 参数
    let params = Params::new(ARGON2_M_COST, ARGON2_T_COST, ARGON2_P_COST, None)
        .map_err(|e| CryptoError::KeyDerivationFailed(e.to_string()))?;

    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);

    // 使用 Argon2 生成密钥
    let mut key = [0u8; 32];

    // 使用原始密码哈希函数
    argon2
        .hash_password_into(password.as_bytes(), salt, &mut key)
        .map_err(|e| CryptoError::KeyDerivationFailed(e.to_string()))?;

    Ok(key)
}

/// 生成随机 salt
pub fn generate_salt() -> [u8; 32] {
    let mut salt = [0u8; 32];
    rand::rngs::OsRng.fill_bytes(&mut salt);
    salt
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_derive_key() {
        let password = "test_password_123";
        let salt = generate_salt();

        let key1 = derive_key(password, &salt).unwrap();
        let key2 = derive_key(password, &salt).unwrap();

        assert_eq!(key1, key2);
        assert_ne!(key1, [0u8; 32]);
    }

    #[test]
    fn test_different_passwords() {
        let salt = generate_salt();

        let key1 = derive_key("password1", &salt).unwrap();
        let key2 = derive_key("password2", &salt).unwrap();

        assert_ne!(key1, key2);
    }

    #[test]
    fn test_different_salts() {
        let password = "test_password";
        let salt1 = generate_salt();
        let salt2 = generate_salt();

        let key1 = derive_key(password, &salt1).unwrap();
        let key2 = derive_key(password, &salt2).unwrap();

        assert_ne!(key1, key2);
    }
}
