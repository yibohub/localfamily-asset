//! 自定义资产类型 CRUD 操作

use rusqlite::{Connection, params};
use super::{DbError, DbResult};
use super::custom_types::CustomAssetType;

/// 自定义类型仓储
pub struct CustomTypeRepository;

impl CustomTypeRepository {
    /// 创建自定义类型
    pub fn create(conn: &Connection, custom_type: &CustomAssetType) -> DbResult<()> {
        conn.execute(
            "INSERT INTO custom_asset_types (id, name, icon_name, is_liability, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            params![
                custom_type.id,
                custom_type.name,
                custom_type.icon_name,
                custom_type.is_liability as i32,
                custom_type.created_at,
            ],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;
        Ok(())
    }

    /// 获取所有自定义类型
    pub fn get_all(conn: &Connection) -> DbResult<Vec<CustomAssetType>> {
        let mut stmt = conn.prepare(
            "SELECT id, name, icon_name, is_liability, created_at
             FROM custom_asset_types ORDER BY created_at DESC"
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let mut types = Vec::new();
        let rows = stmt.query_map([], |row| {
            Ok(CustomAssetType {
                id: row.get(0)?,
                name: row.get(1)?,
                icon_name: row.get(2)?,
                is_liability: row.get::<_, i32>(3)? == 1,
                created_at: row.get(4)?,
            })
        }).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        for row in rows {
            types.push(row.map_err(|e| DbError::DatabaseError(e.to_string()))?);
        }
        Ok(types)
    }

    /// 删除自定义类型
    pub fn delete(conn: &Connection, id: &str) -> DbResult<()> {
        let affected = conn.execute(
            "DELETE FROM custom_asset_types WHERE id = ?1",
            [id],
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        if affected == 0 {
            return Err(DbError::NotFound(format!("Custom type {} not found", id)));
        }
        Ok(())
    }

    /// 检查自定义类型是否被使用
    pub fn is_in_use(conn: &Connection, type_id: &str) -> DbResult<bool> {
        let mut stmt = conn.prepare(
            "SELECT COUNT(*) FROM assets WHERE type = ?1"
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let count: i64 = stmt.query_row([type_id], |row| row.get(0))
            .map_err(|e| DbError::DatabaseError(e.to_string()))?;
        Ok(count > 0)
    }

    /// 根据 ID 获取自定义类型
    pub fn get(conn: &Connection, id: &str) -> DbResult<CustomAssetType> {
        let mut stmt = conn.prepare(
            "SELECT id, name, icon_name, is_liability, created_at
             FROM custom_asset_types WHERE id = ?1"
        ).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        let custom_type = stmt.query_row([id], |row| {
            Ok(CustomAssetType {
                id: row.get(0)?,
                name: row.get(1)?,
                icon_name: row.get(2)?,
                is_liability: row.get::<_, i32>(3)? == 1,
                created_at: row.get(4)?,
            })
        }).map_err(|e| DbError::DatabaseError(e.to_string()))?;

        Ok(custom_type)
    }
}
