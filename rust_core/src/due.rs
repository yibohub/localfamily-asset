//! 到期提醒计算
//!
//! 扫描资产/负债中的到期相关字段，汇总未来窗口内（含已逾期）的到期项：
//! - 存款（deposit）：maturity_date 固定到期日
//! - 贷款类（mortgage/car_loan/personal_loan/private_loan）：due_date 预计还清日
//! - 信用卡（credit_card）：payment_due_date 的"日"做每月循环还款提醒
//! - 保单（insurance）：coverage_period 文本解析"N年"，到期日 = 投保日 + N 年；
//!   "终身/至XX岁"等无法解析的不提醒
//!
//! 已过期项同样返回（days_left 为负），逾期比临近更需提醒。

use chrono::{Datelike, NaiveDate};
use rusqlite::Connection;
use serde::{Deserialize, Serialize};

use crate::db::{DbError, DbResult};

/// 单条到期提醒项
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DueItem {
    pub id: String,
    /// 资产类型字符串（deposit/insurance/credit_card/mortgage/car_loan/...）
    pub asset_type: String,
    pub name: String,
    /// 下一个到期日（YYYY-MM-DD；信用卡为最近一次循环还款日）
    pub due_date: String,
    /// 距到期天数，负数表示已逾期
    pub days_left: i64,
}

/// 解析 "YYYY-MM-DD"（容忍 ISO 带时间的完整串，取前 10 字符；
/// 用 get 防御多字节 UTF-8 字符恰跨第 10 字节的切片 panic）
fn parse_date(s: &str) -> Option<NaiveDate> {
    let prefix = s.get(..10)?;
    NaiveDate::parse_from_str(prefix, "%Y-%m-%d").ok()
}

/// 从 coverage_period 文本提取"N年"的 N（如"20年"/"保 10 年"；"终身/至70岁"返回 None）
///
/// 数字与"年"之间容忍空白（"10 年"）；钳制范围 1..=1000 防溢出
fn parse_coverage_years(text: &str) -> Option<i64> {
    let chars: Vec<char> = text.chars().collect();
    let mut start: Option<usize> = None;
    for (i, &c) in chars.iter().enumerate() {
        if c.is_ascii_digit() {
            if start.is_none() {
                start = Some(i);
            }
        } else if start.is_some() && c == '年' {
            let digits: String = chars[start.unwrap()..i].iter().collect();
            let n = digits.trim().parse::<i64>().ok()?;
            return if (1..=1000).contains(&n) { Some(n) } else { None };
        } else if start.is_some() && c.is_whitespace() {
            continue; // 数字段内部的空白（"10 年"）
        } else {
            start = None;
        }
    }
    None
}

/// 信用卡下一个还款日：payment_due_date 提供循环"日"，返回 [today, today+window] 内
/// 最近的一次还款日；当月无该日（如 31 日在 2 月）时回退到当月最后一天
fn next_credit_card_due(due: &str, today: NaiveDate, window_end: NaiveDate) -> Option<NaiveDate> {
    let base = parse_date(due)?;
    let day = base.day().min(31);

    // 从当月开始最多推进 13 个月，必能命中窗口
    for add in 0..13 {
        let (year, month) = {
            let total = today.year() * 12 + (today.month() as i32 - 1) + add;
            (total / 12, (total % 12 + 1) as u32)
        };
        // 目标日：优先 day，当月不存在该日（如 31 日在 2 月）时取月末
        let last = days_in_month(year, month);
        let candidate = NaiveDate::from_ymd_opt(year, month, day.min(last))?;
        if candidate >= today && candidate <= window_end {
            return Some(candidate);
        }
    }
    None
}

fn days_in_month(year: i32, month: u32) -> u32 {
    let (ny, nm) = if month == 12 { (year + 1, 1) } else { (year, month + 1) };
    (NaiveDate::from_ymd_opt(ny, nm, 1)
        .map(|first| (first - chrono::Duration::days(1)).day())
        .unwrap_or(28)) as u32
}

/// 汇总窗口内的到期项（含已逾期），按剩余天数升序
pub fn collect_due_items(conn: &Connection, today: NaiveDate, window_days: i64) -> DbResult<Vec<DueItem>> {
    let window_end = today + chrono::Duration::days(window_days.max(0));
    // 已逾期项只回看 30 天：一次性日期（存款/贷款/保单）过期后 days_left 恒为负，
    // 不设下限会让多年前的旧记录永远霸占列表头部
    let overdue_start = today - chrono::Duration::days(30);
    let mut items: Vec<DueItem> = Vec::new();

    let push = |id: String, asset_type: &str, name: String, date: Option<NaiveDate>, items: &mut Vec<DueItem>| {
        if let Some(d) = date {
            if d >= overdue_start && d <= window_end {
                items.push(DueItem {
                    id,
                    asset_type: asset_type.to_string(),
                    name,
                    due_date: d.format("%Y-%m-%d").to_string(),
                    days_left: (d - today).num_days(),
                });
            }
        }
    };

    // 1. 存款与贷款类：固定日期字段
    let mut stmt = conn
        .prepare(
            "SELECT id, asset_type, name, maturity_date, due_date
             FROM assets
             WHERE asset_type IN ('deposit', 'debt', 'mortgage', 'car_loan', 'personal_loan', 'private_loan')",
        )
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;
    let rows = stmt
        .query_map([], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, String>(2)?,
                row.get::<_, Option<String>>(3)?,
                row.get::<_, Option<String>>(4)?,
            ))
        })
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;
    for row in rows {
        let (id, asset_type, name, maturity_date, due_date) =
            row.map_err(|e| DbError::DatabaseError(e.to_string()))?;
        let date = if asset_type == "deposit" {
            maturity_date.as_deref().and_then(parse_date)
        } else {
            due_date.as_deref().and_then(parse_date)
        };
        push(id, &asset_type, name, date, &mut items);
    }

    // 2. 信用卡：payment_due_date 的"日"做每月循环
    let mut stmt = conn
        .prepare(
            "SELECT id, name, payment_due_date FROM assets WHERE asset_type = 'credit_card'",
        )
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;
    let rows = stmt
        .query_map([], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, Option<String>>(2)?,
            ))
        })
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;
    for row in rows {
        let (id, name, payment_due_date) =
            row.map_err(|e| DbError::DatabaseError(e.to_string()))?;
        let date = payment_due_date
            .as_deref()
            .and_then(|d| next_credit_card_due(d, today, window_end));
        push(id, "credit_card", name, date, &mut items);
    }

    // 3. 保单：coverage_period 文本解析"N年"，到期日 = 投保日 + N 年
    let mut stmt = conn
        .prepare(
            "SELECT id, name, occurrence_date, coverage_period
             FROM assets WHERE asset_type = 'insurance'",
        )
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;
    let rows = stmt
        .query_map([], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, Option<String>>(2)?,
                row.get::<_, Option<String>>(3)?,
            ))
        })
        .map_err(|e| DbError::DatabaseError(e.to_string()))?;
    for row in rows {
        let (id, name, occurrence_date, coverage_period) =
            row.map_err(|e| DbError::DatabaseError(e.to_string()))?;
        let date = occurrence_date
            .as_deref()
            .and_then(parse_date)
            .and_then(|start| {
                parse_coverage_years(coverage_period.as_deref().unwrap_or(""))
                    .and_then(|years| add_years(start, years))
            });
        push(id, "insurance", name, date, &mut items);
    }

    items.sort_by_key(|i| i.days_left);
    Ok(items)
}

/// 日期加 N 年（2/29 平年回退到 2/28）
fn add_years(date: NaiveDate, years: i64) -> Option<NaiveDate> {
    let year = date.year() + years as i32;
    NaiveDate::from_ymd_opt(year, date.month(), date.day())
        .or_else(|| NaiveDate::from_ymd_opt(year, date.month(), 28))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn d(s: &str) -> NaiveDate {
        NaiveDate::parse_from_str(s, "%Y-%m-%d").unwrap()
    }

    fn setup(rows: &[(&str, &str, &str, Option<&str>, Option<&str>, Option<&str>, Option<&str>)]) -> Connection {
        let conn = Connection::open_in_memory().unwrap();
        // init_db 跑全部迁移,确保负债扩展列(due_date/payment_due_date 等)存在
        crate::db::init_db(&conn).unwrap();
        for (id, t, name, maturity, due, pay, coverage) in rows {
            conn.execute(
                "INSERT INTO assets (id, asset_type, name, amount, currency, occurrence_date, maturity_date, due_date, payment_due_date, coverage_period, created_at, updated_at)
                 VALUES (?1, ?2, ?3, 0, 'CNY', '2024-01-01', ?4, ?5, ?6, ?7, 0, 0)",
                rusqlite::params![id, t, name, maturity, due, pay, coverage],
            )
            .unwrap();
        }
        conn
    }

    #[test]
    fn test_deposit_maturity_included() {
        let conn = setup(&[("d1", "deposit", "定期存款", Some("2030-01-15"), None, None, None)]);
        let items = collect_due_items(&conn, d("2030-01-01"), 30).unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].due_date, "2030-01-15");
        assert_eq!(items[0].days_left, 14);
    }

    #[test]
    fn test_loan_due_included_and_expired_listed() {
        let conn = setup(&[(
            "l1",
            "mortgage",
            "房贷",
            None,
            Some("2029-12-17"),
            None,
            None,
        )]);
        // 已逾期也返回（负数天数；-15 在 30 天回看窗口内）
        let items = collect_due_items(&conn, d("2030-01-01"), 30).unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].days_left, -15);

        // 逾期超过 30 天回看窗口的不再返回
        let items = collect_due_items(&conn, d("2030-02-15"), 30).unwrap();
        assert!(items.is_empty());
    }

    #[test]
    fn test_credit_card_monthly_cycle() {
        // 还款日为 15 号:2026-09-10 时下一个还款日是 2026-09-15
        let conn = setup(&[("c1", "credit_card", "招行卡", None, None, Some("2024-05-15"), None)]);
        let items = collect_due_items(&conn, d("2026-09-10"), 30).unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].due_date, "2026-09-15");

        // 已过 15 号则推进到下月 15 号
        let items = collect_due_items(&conn, d("2026-09-16"), 30).unwrap();
        assert_eq!(items[0].due_date, "2026-10-15");
    }

    #[test]
    fn test_credit_card_month_end_fallback() {
        // 还款日 31 号:2 月没有 31 号,回退到 2 月 28 日
        let conn = setup(&[("c2", "credit_card", "月末卡", None, None, Some("2024-01-31"), None)]);
        let items = collect_due_items(&conn, d("2026-02-01"), 30).unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].due_date, "2026-02-28");
    }

    #[test]
    fn test_insurance_years_parsing() {
        // "20年" + 投保日 2024-01-01 → 到期 2044-01-01
        let conn = setup(&[("i1", "insurance", "重疾险", None, None, None, Some("20年"))]);
        let items = collect_due_items(&conn, d("2044-01-01"), 30).unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].due_date, "2044-01-01");

        // "终身"/"至70岁"/异常数值 不提醒
        let conn = setup(&[
            ("i2", "insurance", "终身寿", None, None, None, Some("终身")),
            ("i3", "insurance", "定寿", None, None, None, Some("至70岁")),
            ("i4", "insurance", "天文", None, None, None, Some("99999999999年")),
        ]);
        let items = collect_due_items(&conn, d("2100-01-01"), 36500).unwrap();
        assert!(items.is_empty());

        // 数字与"年"之间带空白同样可解析
        let conn = setup(&[("i5", "insurance", "带空格", None, None, None, Some("保 10 年"))]);
        let items = collect_due_items(&conn, d("2034-01-01"), 30).unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].due_date, "2034-01-01");
    }

    #[test]
    fn test_sorted_by_days_left_and_window_excludes_far() {
        let conn = setup(&[
            ("d1", "deposit", "近", Some("2026-09-05"), None, None, None),
            ("l1", "car_loan", "中", None, Some("2026-09-20"), None, None),
            ("d2", "deposit", "远", Some("2026-12-31"), None, None, None),
        ]);
        let items = collect_due_items(&conn, d("2026-09-04"), 30).unwrap();
        assert_eq!(items.len(), 2, "窗口外的不应返回");
        assert_eq!(items[0].name, "近");
        assert_eq!(items[1].name, "中");
    }
}
