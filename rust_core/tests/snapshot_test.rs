//! 数据库快照模块测试：创建/列出/清理/恢复/全删

use localfamily_asset_core::db::snapshot::{
    create_snapshot, delete_all_snapshots, list_snapshots, prune_snapshots, restore_snapshot,
    MAX_SNAPSHOTS,
};
use std::fs;
use std::thread;
use std::time::Duration;

/// 每个测试使用独立的临时目录，避免并行冲突
fn temp_dir(tag: &str) -> std::path::PathBuf {
    let dir = std::env::temp_dir().join(format!(
        "lfa_snapshot_test_{}_{}",
        tag,
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    dir
}

#[test]
fn test_create_list_snapshot() {
    let dir = temp_dir("create_list");
    let db = dir.join("test.db");
    fs::write(&db, b"encrypted-content-v1").unwrap();

    let info = create_snapshot(&db).unwrap();
    assert!(info.name.starts_with("snapshot_"));
    assert!(info.name.ends_with(".db"));
    assert_eq!(info.size, b"encrypted-content-v1".len() as u64);

    let list = list_snapshots(&db).unwrap();
    assert_eq!(list.len(), 1);
    assert_eq!(list[0].name, info.name);

    delete_all_snapshots(&db).unwrap();
    fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn test_snapshot_without_db_file_fails() {
    let dir = temp_dir("no_db");
    let db = dir.join("missing.db");
    assert!(create_snapshot(&db).is_err());
    fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn test_prune_keeps_max() {
    let dir = temp_dir("prune");
    let db = dir.join("test.db");
    fs::write(&db, b"data").unwrap();

    // 同一秒内连续创建也不允许互相覆盖（名称自动加序号）
    for _ in 0..(MAX_SNAPSHOTS + 3) {
        create_snapshot(&db).unwrap();
    }

    prune_snapshots(&db).unwrap();
    let list = list_snapshots(&db).unwrap();
    assert_eq!(list.len(), MAX_SNAPSHOTS);

    // 清理后再 prune 应无变化
    prune_snapshots(&db).unwrap();
    assert_eq!(list_snapshots(&db).unwrap().len(), MAX_SNAPSHOTS);

    delete_all_snapshots(&db).unwrap();
    fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn test_restore_roundtrip() {
    let dir = temp_dir("restore");
    let db = dir.join("test.db");
    fs::write(&db, b"old-good-data").unwrap();
    let info = create_snapshot(&db).unwrap();

    // 模拟数据被写坏
    fs::write(&db, b"corrupted!!").unwrap();

    restore_snapshot(&db, &info.name).unwrap();
    assert_eq!(fs::read(&db).unwrap(), b"old-good-data");

    // 恢复前会先快照当前（写坏的）数据，因此快照数应为 2
    let list = list_snapshots(&db).unwrap();
    assert_eq!(list.len(), 2);

    delete_all_snapshots(&db).unwrap();
    fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn test_restore_rejects_bad_names() {
    let dir = temp_dir("bad_names");
    let db = dir.join("test.db");
    fs::write(&db, b"data").unwrap();

    assert!(restore_snapshot(&db, "../escape.db").is_err());
    assert!(restore_snapshot(&db, "snapshot_x\\y.db").is_err());
    assert!(restore_snapshot(&db, "not_a_snapshot.db").is_err());
    assert!(restore_snapshot(&db, "snapshot_20990101_000000.db").is_err());

    fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn test_delete_all_snapshots_without_dir_is_ok() {
    let dir = temp_dir("delete_none");
    let db = dir.join("test.db");
    fs::write(&db, b"data").unwrap();
    // 从未创建过快照也应返回成功
    delete_all_snapshots(&db).unwrap();
    fs::remove_dir_all(&dir).unwrap();
}

/// 建一个附件目录（含一个应被跳过的 .tmp），返回目录路径
fn setup_attachments(dir: &std::path::Path, files: &[(&str, &[u8])]) -> std::path::PathBuf {
    let att = dir.join("attachments");
    fs::create_dir_all(&att).unwrap();
    for (name, content) in files {
        fs::write(att.join(name), content).unwrap();
    }
    fs::write(att.join("incomplete.lfaenc.tmp"), b"partial").unwrap();
    att
}

#[test]
fn test_attachment_snapshot_and_restore() {
    let dir = temp_dir("att_restore");
    let db = dir.join("test.db");
    fs::write(&db, b"db-content").unwrap();
    let att = setup_attachments(
        &dir,
        &[
            ("att_a.lfaenc", b"photo-a-bytes".as_slice()),
            ("att_b.lfaenc", b"photo-b-bytes".as_slice()),
        ],
    );

    let info = create_snapshot(&db).unwrap();
    // .tmp 被跳过，附件数与大小只计密文
    assert_eq!(info.attachment_files, 2);
    assert_eq!(
        info.attachments_size,
        ("photo-a-bytes".len() + "photo-b-bytes".len()) as u64
    );
    let list = list_snapshots(&db).unwrap();
    assert_eq!(list[0].attachment_files, 2);

    // 快照后：删 b、加 c、改 db——恢复应还原 a/b、去掉 c、库内容回滚
    fs::remove_file(att.join("att_b.lfaenc")).unwrap();
    fs::write(att.join("att_c.lfaenc"), b"photo-c-bytes").unwrap();
    fs::write(&db, b"new-db-content").unwrap();

    restore_snapshot(&db, &info.name).unwrap();

    assert_eq!(fs::read(&db).unwrap(), b"db-content");
    assert_eq!(
        fs::read(att.join("att_a.lfaenc")).unwrap(),
        b"photo-a-bytes"
    );
    assert_eq!(
        fs::read(att.join("att_b.lfaenc")).unwrap(),
        b"photo-b-bytes"
    );
    assert!(!att.join("att_c.lfaenc").exists());

    // 恢复前的安全快照：此刻应有 2 份
    assert_eq!(list_snapshots(&db).unwrap().len(), 2);

    delete_all_snapshots(&db).unwrap();
    fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn test_prune_removes_attachment_dirs() {
    let dir = temp_dir("att_prune");
    let db = dir.join("test.db");
    fs::write(&db, b"data").unwrap();
    let att = setup_attachments(&dir, &[("att_a.lfaenc", b"x".as_slice())]);

    for _ in 0..(MAX_SNAPSHOTS + 2) {
        create_snapshot(&db).unwrap();
    }
    prune_snapshots(&db).unwrap();

    let snapshots_dir = dir.join("snapshots");
    let db_snaps = fs::read_dir(&snapshots_dir)
        .unwrap()
        .flatten()
        .filter(|e| {
            e.file_name()
                .to_string_lossy()
                .starts_with("snapshot_")
                && e.file_name().to_string_lossy().ends_with(".db")
        })
        .count();
    let files_dirs = fs::read_dir(&snapshots_dir)
        .unwrap()
        .flatten()
        .filter(|e| {
            e.file_name()
                .to_string_lossy()
                .ends_with("_files")
        })
        .count();
    assert_eq!(db_snaps, MAX_SNAPSHOTS);
    assert_eq!(files_dirs, MAX_SNAPSHOTS);

    delete_all_snapshots(&db).unwrap();
    assert!(!snapshots_dir.exists());
    // 附件本体不受清理影响
    assert!(att.join("att_a.lfaenc").exists());
    fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn test_snapshot_without_attachments_dir() {
    let dir = temp_dir("no_att");
    let db = dir.join("test.db");
    fs::write(&db, b"data").unwrap();

    let info = create_snapshot(&db).unwrap();
    assert_eq!(info.attachment_files, 0);

    // 恢复到无附件快照：不创建附件目录，也不报错
    fs::write(&db, b"changed").unwrap();
    restore_snapshot(&db, &info.name).unwrap();
    assert_eq!(fs::read(&db).unwrap(), b"data");

    delete_all_snapshots(&db).unwrap();
    fs::remove_dir_all(&dir).unwrap();
}
