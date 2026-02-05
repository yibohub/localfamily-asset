//! 数据模型定义
//!
//! 资产/负债分离的数据模型

use serde::{Deserialize, Serialize};
use chrono::Utc;

// ============================================================
// 枚举定义
// ============================================================

/// 资产类型（仅包含非负债类型）
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AssetType {
    #[serde(rename = "property")]
    Property,       // 房产（非投资类）
    #[serde(rename = "deposit")]
    Deposit,        // 存款（非投资类）
    #[serde(rename = "stock")]
    Stock,          // 股票（投资类）
    #[serde(rename = "fund")]
    Fund,           // 基金（投资类）
    #[serde(rename = "insurance")]
    Insurance,      // 保单（非投资类）
}

impl AssetType {
    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "property" => Some(AssetType::Property),
            "deposit" => Some(AssetType::Deposit),
            "stock" => Some(AssetType::Stock),
            "fund" => Some(AssetType::Fund),
            "insurance" => Some(AssetType::Insurance),
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
        }
    }

    /// 是否为投资类资产（有买入价/现价概念）
    pub fn is_investment(&self) -> bool {
        matches!(self, AssetType::Stock | AssetType::Fund)
    }
}

/// 负债类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LiabilityType {
    #[serde(rename = "debt")]
    Debt,           // 通用负债
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

impl LiabilityType {
    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "debt" => Some(LiabilityType::Debt),
            "mortgage" => Some(LiabilityType::Mortgage),
            "car_loan" => Some(LiabilityType::CarLoan),
            "credit_card" => Some(LiabilityType::CreditCard),
            "personal_loan" => Some(LiabilityType::PersonalLoan),
            "private_loan" => Some(LiabilityType::PrivateLoan),
            _ => None,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            LiabilityType::Debt => "debt",
            LiabilityType::Mortgage => "mortgage",
            LiabilityType::CarLoan => "car_loan",
            LiabilityType::CreditCard => "credit_card",
            LiabilityType::PersonalLoan => "personal_loan",
            LiabilityType::PrivateLoan => "private_loan",
        }
    }

    /// 是否为信用卡类型
    pub fn is_credit_card(&self) -> bool {
        matches!(self, LiabilityType::CreditCard)
    }
}

/// 还款方式
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum RepaymentMethod {
    #[serde(rename = "equal_principal_and_interest")]
    EqualPrincipalAndInterest,  // 等额本息
    #[serde(rename = "equal_principal")]
    EqualPrincipal,             // 等额本金
    #[serde(rename = "bullet_payment")]
    BulletPayment,              // 到期还本付息
    #[serde(rename = "monthly_interest")]
    MonthlyInterest,            // 按月付息到期还本
    #[serde(rename = "custom")]
    Custom,                     // 自定义
}

impl RepaymentMethod {
    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "equal_principal_and_interest" => Some(RepaymentMethod::EqualPrincipalAndInterest),
            "equal_principal" => Some(RepaymentMethod::EqualPrincipal),
            "bullet_payment" => Some(RepaymentMethod::BulletPayment),
            "monthly_interest" => Some(RepaymentMethod::MonthlyInterest),
            "custom" => Some(RepaymentMethod::Custom),
            _ => None,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            RepaymentMethod::EqualPrincipalAndInterest => "equal_principal_and_interest",
            RepaymentMethod::EqualPrincipal => "equal_principal",
            RepaymentMethod::BulletPayment => "bullet_payment",
            RepaymentMethod::MonthlyInterest => "monthly_interest",
            RepaymentMethod::Custom => "custom",
        }
    }
}

/// 变更类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ChangeType {
    #[serde(rename = "created")]
    Created,   // 新增
    #[serde(rename = "updated")]
    Updated,   // 修改
    #[serde(rename = "deleted")]
    Deleted,   // 删除
}

impl ChangeType {
    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "created" => Some(ChangeType::Created),
            "updated" => Some(ChangeType::Updated),
            "deleted" => Some(ChangeType::Deleted),
            _ => None,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            ChangeType::Created => "created",
            ChangeType::Updated => "updated",
            ChangeType::Deleted => "deleted",
        }
    }
}

/// 资产变更记录（审计日志）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AssetChange {
    pub id: String,
    pub asset_id: String,
    pub change_type: ChangeType,
    pub occurrence_date_old: Option<String>,
    pub occurrence_date_new: Option<String>,
    pub amount_old: Option<f64>,
    pub amount_new: Option<f64>,
    pub name_old: Option<String>,
    pub name_new: Option<String>,
    pub data_snapshot_old: Option<String>,
    pub data_snapshot_new: Option<String>,
    pub changed_field: Option<String>,
    pub changed_at: i64,
}

impl AssetChange {
    pub fn new(asset_id: String, change_type: ChangeType) -> Self {
        let now = Utc::now().timestamp();
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            asset_id,
            change_type,
            occurrence_date_old: None,
            occurrence_date_new: None,
            amount_old: None,
            amount_new: None,
            name_old: None,
            name_new: None,
            data_snapshot_old: None,
            data_snapshot_new: None,
            changed_field: None,
            changed_at: now,
        }
    }

    /// 设置 Created 类型的快照
    pub fn with_created_snapshot(mut self, new_asset: &Asset) -> Self {
        self.data_snapshot_new = Some(serde_json::to_string(new_asset).unwrap_or_default());
        self.name_new = Some(new_asset.name.clone());
        self.amount_new = Some(new_asset.amount);
        self.occurrence_date_new = Some(new_asset.occurrence_date.clone());
        self
    }

    /// 设置 Deleted 类型的快照
    pub fn with_deleted_snapshot(mut self, old_asset: &Asset) -> Self {
        self.data_snapshot_old = Some(serde_json::to_string(old_asset).unwrap_or_default());
        self.name_old = Some(old_asset.name.clone());
        self.amount_old = Some(old_asset.amount);
        self.occurrence_date_old = Some(old_asset.occurrence_date.clone());
        self
    }

    /// 设置 Updated 类型的快照
    pub fn with_updated_snapshots(mut self, old_asset: &Asset, new_asset: &Asset, changed_field: Option<String>) -> Self {
        self.data_snapshot_old = Some(serde_json::to_string(old_asset).unwrap_or_default());
        self.data_snapshot_new = Some(serde_json::to_string(new_asset).unwrap_or_default());
        self.name_old = Some(old_asset.name.clone());
        self.name_new = Some(new_asset.name.clone());
        self.amount_old = Some(old_asset.amount);
        self.amount_new = Some(new_asset.amount);
        self.occurrence_date_old = Some(old_asset.occurrence_date.clone());
        self.occurrence_date_new = Some(new_asset.occurrence_date.clone());
        self.changed_field = changed_field;
        self
    }

    /// 设置 Created 类型的快照（Liability 版本）
    pub fn with_created_snapshot_for_liability(mut self, new_liability: &Liability) -> Self {
        self.data_snapshot_new = Some(serde_json::to_string(new_liability).unwrap_or_default());
        self.name_new = Some(new_liability.name.clone());
        self.amount_new = Some(new_liability.amount);
        self.occurrence_date_new = Some(new_liability.occurrence_date.clone());
        self
    }

    /// 设置 Deleted 类型的快照（Liability 版本）
    pub fn with_deleted_snapshot_for_liability(mut self, old_liability: &Liability) -> Self {
        self.data_snapshot_old = Some(serde_json::to_string(old_liability).unwrap_or_default());
        self.name_old = Some(old_liability.name.clone());
        self.amount_old = Some(old_liability.amount);
        self.occurrence_date_old = Some(old_liability.occurrence_date.clone());
        self
    }

    /// 设置 Updated 类型的快照（Liability 版本）
    pub fn with_updated_snapshots_for_liability(
        mut self,
        old_liability: &Liability,
        new_liability: &Liability,
        changed_field: Option<String>
    ) -> Self {
        self.data_snapshot_old = Some(serde_json::to_string(old_liability).unwrap_or_default());
        self.data_snapshot_new = Some(serde_json::to_string(new_liability).unwrap_or_default());
        self.name_old = Some(old_liability.name.clone());
        self.name_new = Some(new_liability.name.clone());
        self.amount_old = Some(old_liability.amount);
        self.amount_new = Some(new_liability.amount);
        self.occurrence_date_old = Some(old_liability.occurrence_date.clone());
        self.occurrence_date_new = Some(new_liability.occurrence_date.clone());
        self.changed_field = changed_field;
        self
    }
}

// ============================================================
// 金融记录统一接口
// ============================================================

/// 金融记录 trait - 定义 Asset 和 Liability 的共同接口
pub trait FinancialRecord {
    /// 获取 ID
    fn id(&self) -> &str;

    /// 获取名称
    fn name(&self) -> &str;

    /// 获取金额
    fn amount(&self) -> f64;

    /// 获取币种
    fn currency(&self) -> &str;

    /// 获取发生日期
    fn occurrence_date(&self) -> &str;

    /// 获取备注
    fn note(&self) -> Option<&str>;

    /// 获取创建时间
    fn created_at(&self) -> i64;

    /// 获取更新时间
    fn updated_at(&self) -> i64;

    /// 获取记录类型（"asset" 或 "liability"）
    fn record_type(&self) -> &'static str;
}

// ============================================================
// 资产模型（支持扩展字段）
// ============================================================

/// 资产记录（支持各类资产的可选字段）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Asset {
    pub id: String,
    pub asset_type: String,  // 内置类型名称（如 "stock"）或自定义类型 ID（如 "custom_xxx"）
    pub name: String,
    pub amount: f64,
    pub currency: String,
    pub occurrence_date: String,
    pub note: Option<String>,

    // 通用字段
    pub account: Option<String>,       // 账户/平台（所有类型可选）
    pub tags: Option<Vec<String>>,     // 标签

    // 投资类专属字段（Stock, Fund）
    pub buy_price: Option<f64>,        // 买入单价
    pub current_price: Option<f64>,    // 当前单价
    pub code: Option<String>,          // 证券代码/基金代码
    pub exchange: Option<String>,      // 交易所/平台
    pub quantity: Option<i32>,         // 持有数量

    // 房产专属字段（Property）
    pub address: Option<String>,           // 地址
    pub building_area: Option<f64>,        // 建筑面积（㎡）
    pub living_area: Option<f64>,          // 使用面积（㎡）
    pub property_type: Option<String>,     // 房屋类型
    pub rooms: Option<i32>,                // 房间数
    pub floor: Option<String>,             // 楼层
    pub build_year: Option<i32>,           // 建成年份
    pub ownership_type: Option<String>,    // 产权性质
    pub deed_number: Option<String>,       // 不动产证号

    // 存款专属字段（Deposit）
    pub deposit_account_type: Option<String>,   // 账户类型：活期/定期
    pub deposit_period: Option<i32>,            // 存期（月）
    pub maturity_date: Option<String>,          // 到期日期
    pub deposit_interest_rate: Option<f64>,     // 利率（%）

    // 保单专属字段（Insurance）
    pub policy_number: Option<String>,      // 保单号
    pub insurance_type: Option<String>,     // 保险类型
    pub insured: Option<String>,            // 被保人
    pub beneficiary: Option<String>,        // 受益人
    pub coverage_amount: Option<f64>,       // 保额
    pub premium: Option<f64>,               // 保费
    pub premium_period: Option<String>,     // 缴费期限
    pub coverage_period: Option<String>,    // 保险期限
    pub insurer: Option<String>,            // 保险公司

    pub created_at: i64,
    pub updated_at: i64,
}

impl Asset {
    pub fn new(
        asset_type: String,
        name: String,
        amount: f64,
    ) -> Self {
        let now = Utc::now().timestamp();
        let today = chrono::Utc::now().format("%Y-%m-%d").to_string();
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            asset_type,
            name,
            amount,
            currency: "CNY".to_string(),
            occurrence_date: today,
            note: None,
            account: None,
            tags: None,
            buy_price: None,
            current_price: None,
            code: None,
            exchange: None,
            quantity: None,
            // 房产字段
            address: None,
            building_area: None,
            living_area: None,
            property_type: None,
            rooms: None,
            floor: None,
            build_year: None,
            ownership_type: None,
            deed_number: None,
            // 存款字段
            deposit_account_type: None,
            deposit_period: None,
            maturity_date: None,
            deposit_interest_rate: None,
            // 保单字段
            policy_number: None,
            insurance_type: None,
            insured: None,
            beneficiary: None,
            coverage_amount: None,
            premium: None,
            premium_period: None,
            coverage_period: None,
            insurer: None,
            created_at: now,
            updated_at: now,
        }
    }

    /// 判断是否为投资类资产
    pub fn is_investment(&self) -> bool {
        matches!(self.asset_type.as_str(), "stock" | "fund")
    }

    /// 计算盈亏（百分比）
    pub fn profit_loss_percent(&self) -> Option<f64> {
        match (self.buy_price, self.current_price) {
            (Some(buy), Some(current)) if buy > 0.0 => {
                Some((current - buy) / buy * 100.0)
            },
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

// 实现 FinancialRecord trait
impl FinancialRecord for Asset {
    fn id(&self) -> &str {
        &self.id
    }

    fn name(&self) -> &str {
        &self.name
    }

    fn amount(&self) -> f64 {
        self.amount
    }

    fn currency(&self) -> &str {
        &self.currency
    }

    fn occurrence_date(&self) -> &str {
        &self.occurrence_date
    }

    fn note(&self) -> Option<&str> {
        self.note.as_deref()
    }

    fn created_at(&self) -> i64 {
        self.created_at
    }

    fn updated_at(&self) -> i64 {
        self.updated_at
    }

    fn record_type(&self) -> &'static str {
        "asset"
    }
}

// ============================================================
// 负债模型（支持扩展字段）
// ============================================================

/// 负债记录（支持各类负债的可选字段）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Liability {
    pub id: String,
    pub liability_type: String,  // 内置类型名称（如 "mortgage"）或自定义类型 ID
    pub name: String,
    pub amount: f64,
    pub currency: String,
    pub occurrence_date: String,
    pub note: Option<String>,

    // 贷款类通用字段（Mortgage, CarLoan, PersonalLoan, PrivateLoan）
    pub lender: Option<String>,                  // 债权人/贷款机构
    pub due_date: Option<String>,                // 到期日/预计还清日
    pub interest_rate: Option<f64>,              // 年利率（%）
    pub repayment_method: Option<String>,        // 还款方式
    pub loan_term: Option<i32>,                  // 贷款期限（月）

    // 信用卡专属字段（CreditCard）
    pub last_four_digits: Option<String>,        // 卡号后四位
    pub billing_date: Option<String>,            // 账单日
    pub payment_due_date: Option<String>,        // 还款日
    pub credit_limit: Option<f64>,               // 信用额度
    pub cash_limit: Option<f64>,                 // 取现额度
    pub annual_fee: Option<f64>,                 // 年费
    pub issuer: Option<String>,                  // 发卡行

    // 房贷专属字段（Mortgage）
    pub property_address: Option<String>,        // 房产地址
    pub original_loan_amount: Option<f64>,       // 原始贷款金额
    pub remaining_principal: Option<f64>,        // 剩余本金
    pub loan_type: Option<String>,               // 贷款类型

    // 车贷专属字段（CarLoan）
    pub vehicle_brand: Option<String>,           // 车辆品牌
    pub vehicle_model: Option<String>,           // 车型
    pub license_plate: Option<String>,           // 车牌号

    // 个人/私人借款专属字段（PersonalLoan, PrivateLoan）
    pub purpose: Option<String>,                 // 借款用途
    pub has_interest: Option<bool>,              // 是否有利息
    pub repayment_plan: Option<String>,          // 还款计划描述

    pub created_at: i64,
    pub updated_at: i64,
}

impl Liability {
    pub fn new(
        liability_type: String,
        name: String,
        amount: f64,
    ) -> Self {
        let now = Utc::now().timestamp();
        let today = chrono::Utc::now().format("%Y-%m-%d").to_string();
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            liability_type,
            name,
            amount,
            currency: "CNY".to_string(),
            occurrence_date: today,
            note: None,
            // 贷款类通用字段
            lender: None,
            due_date: None,
            interest_rate: None,
            repayment_method: None,
            loan_term: None,
            // 信用卡专属字段
            last_four_digits: None,
            billing_date: None,
            payment_due_date: None,
            credit_limit: None,
            cash_limit: None,
            annual_fee: None,
            issuer: None,
            // 房贷专属字段
            property_address: None,
            original_loan_amount: None,
            remaining_principal: None,
            loan_type: None,
            // 车贷专属字段
            vehicle_brand: None,
            vehicle_model: None,
            license_plate: None,
            // 个人/私人借款专属字段
            purpose: None,
            has_interest: None,
            repayment_plan: None,
            created_at: now,
            updated_at: now,
        }
    }

    /// 判断是否为信用卡类型
    pub fn is_credit_card(&self) -> bool {
        self.liability_type == "credit_card"
    }

    /// 计算信用使用率（仅信用卡有效）
    pub fn credit_utilization(&self) -> Option<f64> {
        if !self.is_credit_card() {
            return None;
        }
        match self.credit_limit {
            Some(limit) if limit > 0.0 => Some(self.amount / limit * 100.0),
            _ => None,
        }
    }

    /// 计算可用额度（仅信用卡有效）
    pub fn available_credit(&self) -> Option<f64> {
        if !self.is_credit_card() {
            return None;
        }
        self.credit_limit.map(|limit| limit - self.amount)
    }
}

// 实现 FinancialRecord trait
impl FinancialRecord for Liability {
    fn id(&self) -> &str {
        &self.id
    }

    fn name(&self) -> &str {
        &self.name
    }

    fn amount(&self) -> f64 {
        self.amount
    }

    fn currency(&self) -> &str {
        &self.currency
    }

    fn occurrence_date(&self) -> &str {
        &self.occurrence_date
    }

    fn note(&self) -> Option<&str> {
        self.note.as_deref()
    }

    fn created_at(&self) -> i64 {
        self.created_at
    }

    fn updated_at(&self) -> i64 {
        self.updated_at
    }

    fn record_type(&self) -> &'static str {
        "liability"
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
