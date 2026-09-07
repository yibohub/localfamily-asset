//! 数据库快照：加密库文件 + 附件密文的字节级滚动备份
//!
//! 数据库文件本身已是自研加密格式（LFAENC01，密钥由用户密码派生），
//! 快照即对密文的复制——无新增密钥与依赖，安全性与主库一致
//! （没有密码同样读不了快照）。
//!
//! 附件覆盖：附件密文文件写入后不可变（只有增删），快照时对未变化文件
//! 使用**硬链接**（近零空间），硬链接失败（如跨卷/非 NTFS）回退为复制；
//! 恢复时整目录重建附件目录，保证附件与恢复后的数据库记录一致。
//!
//! 策略：
//! - 每天首次保存前自动快照一份，高危操作（导入恢复、修改密码、
//!   快照恢复本身）前强制快照；
//! - 快照目录与数据库同目录 `snapshots/`：每份快照为
//!   `snapshot_时间戳.db`（库文件）+ `snapshot_时间戳_files/`（附件集），
//!   最多保留 [`MAX_SNAPSHOTS`] 份，超出时清理最旧的；
//! - 安全重置（reset）会连带删除快照目录——重置是安全功能，不留可恢复密文。

use super::DbResult;
use chrono::Local;
use std::fs;
use std::path::{Path, PathBuf};

/// 快照目录名（与数据库文件同级的 snapshots/ 子目录）
const SNAPSHOT_DIR: &str = "snapshots";
/// 快照文件名前缀
const SNAPSHOT_PREFIX: &str = "snapshot_";
/// 最多保留的快照数量（超出时清理最旧的）
pub const MAX_SNAPSHOTS: usize = 10;

/// 快照元信息
#[derive(Debug, Clone)]
pub struct SnapshotInfo {
    pub name: String,
    pub timestamp: i64, // Unix 秒
    pub size: u64,      // 库文件字节
    pub attachment_files: usize, // 附件密文文件数
    pub attachments_size: u64,   // 附件密文字节合计
}

/// 快照目录（不存在则创建）
fn snapshots_dir(db_path: &Path) -> DbResult<PathBuf> {
    let dir = db_path
        .parent()
        .ok_or_else(|| super::DbError::DatabaseError("无法定位数据库目录".into()))?
        .join(SNAPSHOT_DIR);
    fs::create_dir_all(&dir)
        .map_err(|e| super::DbError::DatabaseError(format!("创建快照目录失败: {}", e)))?;
    Ok(dir)
}

/// 某份快照对应的附件集目录
fn snapshot_files_dir(dir: &Path, snapshot_name: &str) -> PathBuf {
    let stem = snapshot_name.strip_suffix(".db").unwrap_or(snapshot_name);
    dir.join(format!("{}_files", stem))
}

/// 判断文件名是否是快照库文件
fn is_snapshot_name(name: &str) -> bool {
    name.starts_with(SNAPSHOT_PREFIX) && name.ends_with(".db")
}

/// 统计目录下的文件数与合计大小
fn summarize_files(dir: &Path) -> (usize, u64) {
    let mut count = 0usize;
    let mut size = 0u64;
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            if let Ok(meta) = entry.metadata() {
                if meta.is_file() {
                    count += 1;
                    size += meta.len();
                }
            }
        }
    }
    (count, size)
}

/// 把附件目录快照进 dest：优先硬链接（附件不可变，链接即完整备份），
/// 失败回退复制。跳过中断写入遗留的 `.tmp` 文件。
fn snapshot_attachments(att_dir: &Path, dest: &Path) -> DbResult<()> {
    fs::create_dir_all(dest)
        .map_err(|e| super::DbError::DatabaseError(format!("创建快照附件目录失败: {}", e)))?;
    let entries = fs::read_dir(att_dir)
        .map_err(|e| super::DbError::DatabaseError(format!("读取附件目录失败: {}", e)))?;
    for entry in entries {
        let entry = entry.map_err(|e| super::DbError::DatabaseError(e.to_string()))?;
        let path = entry.path();
        if !path.is_file() {
            continue;
        }
        let file_name = entry.file_name();
        if file_name.to_string_lossy().ends_with(".tmp") {
            continue;
        }
        let target = dest.join(&file_name);
        // 重建场景下清理同名残留，避免硬链接失败
        let _ = fs::remove_file(&target);
        if fs::hard_link(&path, &target).is_err() {
            fs::copy(&path, &target).map_err(|e| {
                super::DbError::DatabaseError(format!("快照附件 {} 失败: {}", file_name.to_string_lossy(), e))
            })?;
        }
    }
    Ok(())
}

/// 创建快照：复制加密库文件 + 硬链接/复制附件集
pub fn create_snapshot<P: AsRef<Path>>(db_path: P) -> DbResult<SnapshotInfo> {
    let path = db_path.as_ref();
    if !path.exists() {
        return Err(super::DbError::NotFound(
            "数据库文件不存在，无法创建快照".into(),
        ));
    }
    let dir = snapshots_dir(path)?;
    let now = Local::now();
    let stem = format!("{}_{}", SNAPSHOT_PREFIX, now.format("%Y%m%d_%H%M%S"));
    // 同一秒内多次快照（如改密紧接着导入）不能覆盖旧快照：追加序号保证唯一
    let mut name = format!("{}.db", stem);
    let mut seq = 0u32;
    while dir.join(&name).exists() {
        seq += 1;
        name = format!("{}_{}.db", stem, seq);
    }
    let dest = dir.join(&name);

    fs::copy(path, &dest)
        .map_err(|e| super::DbError::DatabaseError(format!("复制快照失败: {}", e)))?;

    // 附件一并快照；失败时回滚已复制的库文件，不留半份快照
    let files_dir = snapshot_files_dir(&dir, &name);
    let att_dir = super::attachment_storage::attachments_dir(path);
    let att_result = if att_dir.exists() {
        snapshot_attachments(&att_dir, &files_dir)
    } else {
        fs::create_dir_all(&files_dir)
            .map_err(|e| super::DbError::DatabaseError(format!("创建快照附件目录失败: {}", e)))
    };
    if let Err(e) = att_result {
        let _ = fs::remove_file(&dest);
        let _ = fs::remove_dir_all(&files_dir);
        return Err(e);
    }

    let (attachment_files, attachments_size) = summarize_files(&files_dir);
    Ok(SnapshotInfo {
        name,
        timestamp: now.timestamp(),
        size: fs::metadata(&dest)
            .map_err(|e| super::DbError::DatabaseError(format!("读取快照信息失败: {}", e)))?
            .len(),
        attachment_files,
        attachments_size,
    })
}

/// 列出全部快照（按文件名倒序 = 时间倒序，文件名含零填充时间戳）
pub fn list_snapshots<P: AsRef<Path>>(db_path: P) -> DbResult<Vec<SnapshotInfo>> {
    let path = db_path.as_ref();
    let dir = snapshots_dir(path)?;
    let mut out = Vec::new();
    for entry in fs::read_dir(&dir)
        .map_err(|e| super::DbError::DatabaseError(format!("读取快照目录失败: {}", e)))?
    {
        let entry = entry.map_err(|e| super::DbError::DatabaseError(e.to_string()))?;
        let name = match entry.file_name().into_string() {
            Ok(n) if is_snapshot_name(&n) => n,
            _ => continue,
        };
        let meta = match fs::metadata(entry.path()) {
            Ok(m) => m,
            Err(_) => continue,
        };
        let timestamp = meta
            .modified()
            .ok()
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);
        let (attachment_files, attachments_size) =
            summarize_files(&snapshot_files_dir(&dir, &name));
        out.push(SnapshotInfo {
            name,
            timestamp,
            size: meta.len(),
            attachment_files,
            attachments_size,
        });
    }
    out.sort_by(|a, b| b.name.cmp(&a.name));
    Ok(out)
}

/// 清理最旧的快照（连同其附件集目录），最多保留 [`MAX_SNAPSHOTS`] 份
pub fn prune_snapshots<P: AsRef<Path>>(db_path: P) -> DbResult<()> {
    let dir = snapshots_dir(db_path.as_ref())?;
    let snapshots = list_snapshots(db_path)?;
    for info in snapshots.iter().skip(MAX_SNAPSHOTS) {
        if let Err(e) = fs::remove_file(dir.join(&info.name)) {
            return Err(super::DbError::DatabaseError(format!(
                "清理快照 {} 失败: {}",
                info.name, e
            )));
        }
        let files_dir = snapshot_files_dir(&dir, &info.name);
        if files_dir.exists() {
            let _ = fs::remove_dir_all(&files_dir);
        }
    }
    Ok(())
}

/// 从快照恢复：先为当前库与附件做一份快照（双保险），再把库文件与
/// 附件目录整体还原到快照时点
///
/// 仅替换磁盘文件；内存库的重载由调用方（FFI 层）完成
pub fn restore_snapshot<P: AsRef<Path>>(db_path: P, name: &str) -> DbResult<()> {
    // 防路径穿越：只允许纯文件名
    if name.contains('/') || name.contains('\\') || name.contains("..") {
        return Err(super::DbError::InvalidParam("非法快照名".into()));
    }
    if !is_snapshot_name(name) {
        return Err(super::DbError::InvalidParam("非法快照名".into()));
    }
    let path = db_path.as_ref();
    if !path.exists() {
        return Err(super::DbError::NotFound("数据库文件不存在".into()));
    }
    let dir = snapshots_dir(path)?;
    let source = dir.join(name);
    if !source.exists() {
        return Err(super::DbError::NotFound(format!("快照不存在: {}", name)));
    }
    let files_dir = snapshot_files_dir(&dir, name);

    // 恢复前先快照当前数据，恢复错了还能退回来
    create_snapshot(path)?;

    // 库文件
    fs::copy(&source, path)
        .map_err(|e| super::DbError::DatabaseError(format!("恢复快照失败: {}", e)))?;

    // 附件目录整体重建为快照时点状态（删除之后加的、找回之前删的）。
    // 旧版快照没有附件集目录：跳过附件恢复，保持仅库文件回滚的旧语义。
    if files_dir.exists() {
        let att_dir = super::attachment_storage::attachments_dir(path);
        if att_dir.exists() {
            fs::remove_dir_all(&att_dir).map_err(|e| {
                super::DbError::DatabaseError(format!("清理附件目录失败: {}", e))
            })?;
        }
        fs::create_dir_all(&att_dir)
            .map_err(|e| super::DbError::DatabaseError(format!("重建附件目录失败: {}", e)))?;
        for entry in fs::read_dir(&files_dir)
            .map_err(|e| super::DbError::DatabaseError(format!("读取快照附件失败: {}", e)))?
        {
            let entry = entry.map_err(|e| super::DbError::DatabaseError(e.to_string()))?;
            let target = att_dir.join(entry.file_name());
            fs::copy(entry.path(), &target).map_err(|e| {
                super::DbError::DatabaseError(format!(
                    "恢复附件 {} 失败: {}",
                    entry.file_name().to_string_lossy(),
                    e
                ))
            })?;
        }
    }

    Ok(())
}

/// 删除全部快照（安全重置时调用；目录不存在视为成功）
pub fn delete_all_snapshots<P: AsRef<Path>>(db_path: P) -> DbResult<()> {
    let dir = match db_path.as_ref().parent() {
        Some(parent) => parent.join(SNAPSHOT_DIR),
        None => return Ok(()),
    };
    if dir.exists() {
        fs::remove_dir_all(&dir)
            .map_err(|e| super::DbError::DatabaseError(format!("清理快照失败: {}", e)))?;
    }
    Ok(())
}
