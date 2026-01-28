//! 自定义资产类型模型

use serde::{Deserialize, Serialize};

/// 自定义资产类型
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CustomAssetType {
    pub id: String,              // 格式: "custom_<uuid>"
    pub name: String,            // 用户定义名称
    pub icon_name: String,       // 图标名称（从预设列表选择）
    pub is_liability: bool,      // 是否为负债类型
    pub created_at: i64,
}

impl CustomAssetType {
    pub fn new(name: String, icon_name: String, is_liability: bool) -> Self {
        Self {
            id: format!("custom_{}", uuid::Uuid::new_v4()),
            name,
            icon_name,
            is_liability,
            created_at: chrono::Utc::now().timestamp(),
        }
    }
}
