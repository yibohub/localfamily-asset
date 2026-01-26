//! 数据模型定义

use serde::{Deserialize, Serialize};
use chrono::Utc;

/// 资产类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AssetType {
    #[serde(rename = "property")]
    Property,       // 房产
    #[serde(rename = "deposit")]
    Deposit,        // 存款
    #[serde(rename = "stock")]
    Stock,          // 股票
    #[serde(rename = "fund")]
    Fund,           // 基金
    #[serde(rename = "insurance")]
    Insurance,      // 保单
    #[serde(rename = "debt")]
    Debt,           // 负债（通用）
    #[serde(rename = "mortgage")]
    Mortgage,       // 房贷
    #[serde(rename = "car_loan")]
    CarLoan,        // 车贷
    #[serde(rename = "credit_card")]
    CreditCard,     // 信用卡
    #[serde(rename = "personal_loan")]
    PersonalLoan,   // 个人贷款
    #[serde(rename = "private_loan")]
    PrivateLoan,    // 私人借款
}

impl AssetType {
    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "property" => Some(AssetType::Property),
            "deposit" => Some(AssetType::Deposit),
            "stock" => Some(AssetType::Stock),
            "fund" => Some(AssetType::Fund),
            "insurance" => Some(AssetType::Insurance),
            "debt" => Some(AssetType::Debt),
            "mortgage" => Some(AssetType::Mortgage),
            "car_loan" => Some(AssetType::CarLoan),
            "credit_card" => Some(AssetType::CreditCard),
            "personal_loan" => Some(AssetType::PersonalLoan),
            "private_loan" => Some(AssetType::PrivateLoan),
            _ => None,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            AssetType::Property => "property",
            AssetType::Deposit => "deposit",
            AssetType::Stock => "stock",
            AssetType::Fund => "fund",
            AssetType::Insurance => "insurance",
            AssetType::Debt => "debt",
            AssetType::Mortgage => "mortgage",
            AssetType::CarLoan => "car_loan",
            AssetType::CreditCard => "credit_card",
            AssetType::PersonalLoan => "personal_loan",
            AssetType::PrivateLoan => "private_loan",
        }
    }

    /// 判断是否为负债类型
    pub fn is_liability(&self) -> bool {
        matches!(self,
            AssetType::Debt |
            AssetType::Mortgage |
            AssetType::CarLoan |
            AssetType::CreditCard |
            AssetType::PersonalLoan |
            AssetType::PrivateLoan
        )
    }
}

/// 资产记录
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Asset {
    pub id: String,
    #[serde(rename = "type")]
    pub asset_type: AssetType,
    pub name: String,
    pub amount: f64,
    pub currency: String,
    pub account: Option<String>,
    pub buy_date: Option<String>,
    pub buy_price: Option<f64>,
    pub current_price: Option<f64>,
    pub note: Option<String>,
    pub tags: Option<Vec<String>>,
    pub created_at: i64,
    pub updated_at: i64,
}

impl Asset {
    pub fn new(
        asset_type: AssetType,
        name: String,
        amount: f64,
    ) -> Self {
        let now = Utc::now().timestamp();
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            asset_type,
            name,
            amount,
            currency: "CNY".to_string(),
            account: None,
            buy_date: None,
            buy_price: None,
            current_price: None,
            note: None,
            tags: None,
            created_at: now,
            updated_at: now,
        }
    }

    /// 计算盈亏（百分比）
    pub fn profit_loss_percent(&self) -> Option<f64> {
        match (self.buy_price, self.current_price) {
            (Some(buy), Some(current)) => {
                if buy > 0.0 {
                    Some((current - buy) / buy * 100.0)
                } else {
                    None
                }
            }
            _ => None,
        }
    }

    /// 计算盈亏金额
    pub fn profit_loss_amount(&self) -> Option<f64> {
        match (self.buy_price, self.current_price) {
            (Some(buy), Some(current)) => Some(current - buy),
            _ => None,
        }
    }
}

/// 资产历史价格
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AssetHistory {
    pub id: String,
    pub asset_id: String,
    pub price: f64,
    pub recorded_at: i64,
}

impl AssetHistory {
    pub fn new(asset_id: String, price: f64) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            asset_id,
            price,
            recorded_at: Utc::now().timestamp(),
        }
    }
}

/// 附件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Attachment {
    pub id: String,
    pub asset_id: String,
    pub file_name: String,
    pub file_size: i64,
    pub encrypted_path: String,
    pub mime_type: Option<String>,
    pub created_at: i64,
}

impl Attachment {
    pub fn new(
        asset_id: String,
        file_name: String,
        file_size: i64,
        encrypted_path: String,
    ) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            asset_id,
            file_name,
            file_size,
            encrypted_path,
            mime_type: None,
            created_at: Utc::now().timestamp(),
        }
    }
}

/// 设置项
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Setting {
    pub key: String,
    pub value: String,
}

/// 币种
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Currency {
    CNY,
    USD,
    HKD,
    EUR,
}

impl Currency {
    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "CNY" => Some(Currency::CNY),
            "USD" => Some(Currency::USD),
            "HKD" => Some(Currency::HKD),
            "EUR" => Some(Currency::EUR),
            _ => None,
        }
    }
}
