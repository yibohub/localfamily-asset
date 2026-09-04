//! 投资收益计算（XIRR 年化收益率）
//!
//! XIRR（扩展内部收益率）：考虑每笔投入时点的年化收益率。
//! 现金流约定：买入为负（流出），当前市值为正（视为今日收回）。
//! 解方程 Σ CFᵢ / (1+r)^(tᵢ/365) = 0，二分法求根。

use chrono::NaiveDate;
use serde::{Deserialize, Serialize};

/// 单条投资资产的收益信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InvestmentReturn {
    pub asset_id: String,
    pub name: String,
    pub currency: String,
    pub cost: f64,
    pub current_value: f64,
    pub profit: f64,
    pub profit_percent: f64,
    pub holding_days: i64,
    /// 年化收益率（小数，如 0.123 = 12.3%）；无法求解时为 None
    pub xirr: Option<f64>,
}

/// 组合投资收益汇总
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PortfolioReturns {
    pub items: Vec<InvestmentReturn>,
    pub total_cost: f64,
    pub total_value: f64,
    pub total_profit: f64,
    /// 组合年化（全部投资资产现金流合并求解）
    pub portfolio_xirr: Option<f64>,
}

/// 一笔现金流：金额（负=投入）与发生日期
#[derive(Debug, Clone)]
pub struct CashFlow {
    pub amount: f64,
    pub date: NaiveDate,
}

/// 解 XIRR（二分法）
///
/// - `flows`: 现金流（必须同时存在正负项，否则返回 None）
///
/// 返回年化收益率（小数）。区间 (-0.9999, 1000]，100 次二分足够收敛。
pub fn xirr(flows: &[CashFlow]) -> Option<f64> {
    if flows.is_empty() {
        return None;
    }
    let has_negative = flows.iter().any(|f| f.amount < 0.0);
    let has_positive = flows.iter().any(|f| f.amount > 0.0);
    if !has_negative || !has_positive {
        return None;
    }

    // 基准日取最早现金流日期，折现因子从 1 起
    let base = flows.iter().map(|f| f.date).min()?;

    let npv = |r: f64| -> f64 {
        flows
            .iter()
            .map(|f| {
                let days = (f.date - base).num_days().max(0) as f64;
                f.amount / (1.0 + r).powf(days / 365.0)
            })
            .sum()
    };

    // r → -1+ 时 NPV → +∞（折现爆炸），r 增大 NPV 单调递减趋向 -(终值)
    // 故低点取 -0.9999 处 NPV 应为正、高点处为负，区间内必有唯一根
    let mut low = -0.9999_f64;
    let mut high = 1000.0_f64;
    if npv(low) * npv(high) > 0.0 {
        return None;
    }

    for _ in 0..200 {
        let mid = (low + high) / 2.0;
        let v = npv(mid);
        if v.abs() < 1e-7 {
            return Some(mid);
        }
        if npv(low) * v < 0.0 {
            high = mid;
        } else {
            low = mid;
        }
    }
    Some((low + high) / 2.0)
}

/// 汇总投资资产的收益（含组合 XIRR）
///
/// `inputs`: (资产ID, 名称, 币种, 成本, 现值, 买入日期)
/// 成本/现值非正值或日期无法解析的资产被跳过（无法年化）
pub fn summarize(
    inputs: Vec<(String, String, String, f64, f64, String)>,
    today: NaiveDate,
) -> PortfolioReturns {
    let mut items = Vec::new();
    let mut all_flows: Vec<CashFlow> = Vec::new();
    let mut total_cost = 0.0;
    let mut total_value = 0.0;

    for (asset_id, name, currency, cost, current_value, buy_date) in inputs {
        if cost <= 0.0 || current_value <= 0.0 {
            continue;
        }
        let Ok(date) = NaiveDate::parse_from_str(&buy_date, "%Y-%m-%d") else {
            continue;
        };

        let profit = current_value - cost;
        let profit_percent = profit / cost * 100.0;
        let holding_days = (today - date).num_days().max(0);

        let x = xirr(
            &[
                CashFlow { amount: -cost, date },
                CashFlow { amount: current_value, date: today },
            ],
        );

        items.push(InvestmentReturn {
            asset_id,
            name,
            currency,
            cost,
            current_value,
            profit,
            profit_percent,
            holding_days,
            xirr: x,
        });

        all_flows.push(CashFlow { amount: -cost, date });
        all_flows.push(CashFlow { amount: current_value, date: today });
        total_cost += cost;
        total_value += current_value;
    }

    let total_profit = total_value - total_cost;
    let portfolio_xirr = xirr(&all_flows);

    PortfolioReturns {
        items,
        total_cost,
        total_value,
        total_profit,
        portfolio_xirr,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn d(y: i32, m: u32, day: u32) -> NaiveDate {
        NaiveDate::from_ymd_opt(y, m, day).unwrap()
    }

    #[test]
    fn xirr_single_investment_one_year_double() {
        // 一年前投 100，今天值 200 → 翻倍，XIRR ≈ 100%
        let flows = vec![
            CashFlow { amount: -100.0, date: d(2025, 1, 1) },
            CashFlow { amount: 200.0, date: d(2026, 1, 1) },
        ];
        let r = xirr(&flows).unwrap();
        assert!((r - 1.0).abs() < 1e-4, "XIRR 应约等于 1.0，实际 {}", r);
    }

    #[test]
    fn xirr_half_year_quadruple_annualizes_higher() {
        // 半年前投 100（184 天），今天值 200 → 年化 ≈ 2^(365/184)-1 ≈ 2.96
        let flows = vec![
            CashFlow { amount: -100.0, date: d(2025, 7, 1) },
            CashFlow { amount: 200.0, date: d(2026, 1, 1) },
        ];
        let r = xirr(&flows).unwrap();
        assert!(
            (r - 2.955).abs() < 0.01,
            "半年翻倍年化应约 295%，实际 {}",
            r
        );
    }

    #[test]
    fn xirr_loss_returns_negative() {
        // 一年前投 100，今天值 50 → -50%
        let flows = vec![
            CashFlow { amount: -100.0, date: d(2025, 1, 1) },
            CashFlow { amount: 50.0, date: d(2026, 1, 1) },
        ];
        let r = xirr(&flows).unwrap();
        assert!((r + 0.5).abs() < 1e-3, "XIRR 应约等于 -0.5，实际 {}", r);
    }

    #[test]
    fn xirr_same_sign_returns_none() {
        let flows = vec![
            CashFlow { amount: -100.0, date: d(2025, 1, 1) },
            CashFlow { amount: -50.0, date: d(2025, 6, 1) },
        ];
        assert!(xirr(&flows).is_none());
    }

    #[test]
    fn summarize_aggregates_and_skips_invalid() {
        let today = d(2026, 1, 1);
        let result = summarize(
            vec![
                ("a1".into(), "股票A".into(), "CNY".into(), 100.0, 200.0, "2025-01-01".into()),
                ("a2".into(), "股票B".into(), "CNY".into(), 0.0, 500.0, "2025-01-01".into()), // 无成本，跳过
                ("a3".into(), "基金C".into(), "CNY".into(), 300.0, 250.0, "bad-date".into()), // 日期坏，跳过
            ],
            today,
        );

        assert_eq!(result.items.len(), 1);
        assert_eq!(result.items[0].asset_id, "a1");
        assert_eq!(result.total_cost, 100.0);
        assert_eq!(result.total_value, 200.0);
        assert_eq!(result.total_profit, 100.0);
        assert!(result.portfolio_xirr.unwrap() > 0.99);
    }
}
