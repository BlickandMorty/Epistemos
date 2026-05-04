use std::sync::atomic::Ordering;

use agent_core::arena::{
    container::legacy_base, AppGroupContainer, ArenaHeader, ArtefactRef, MappedArena, RequestSlot,
    ResponseSlot, APP_GROUP_ID, ARENA_FILE_NAME, ARENA_MAGIC, ARENA_VERSION, INLINE_REQ_BYTES,
    MAX_ARTEFACT_REFS, SLOT_COUNT, STATE_READY,
};

#[test]
fn app_group_identifier_uses_canonical_epistemos_spelling() {
    assert_eq!(APP_GROUP_ID, "group.com.epistemos.shared");
    assert!(APP_GROUP_ID.contains("epistemos"));
    assert!(legacy_base().to_string_lossy().contains("Epistemos"));
}

#[test]
fn app_group_container_derives_expected_paths() {
    let temp = tempfile::tempdir().unwrap();
    let container = AppGroupContainer::from_base(temp.path());

    assert_eq!(container.arena_path(), temp.path().join(ARENA_FILE_NAME));
    assert_eq!(container.blobs_path(), temp.path().join("blobs"));
    assert_eq!(
        container.provenance_db_path(),
        temp.path().join("provenance.sqlite")
    );
    assert_eq!(
        container.vault_index_path(),
        temp.path().join("vault_index.sqlite")
    );
    assert_eq!(
        container.resonance_db_path(),
        temp.path().join("resonance.sqlite")
    );

    container.ensure_layout().unwrap();
    assert!(container.blobs_path().is_dir());
}

#[test]
fn arena_layout_sizes_are_page_aligned() {
    assert_eq!(std::mem::size_of::<ArenaHeader>(), 4_096);
    assert_eq!(std::mem::size_of::<RequestSlot>(), 4_096);
    assert_eq!(std::mem::size_of::<ResponseSlot>(), 8_192);
    assert_eq!(
        MappedArena::SIZE,
        4_096 + SLOT_COUNT * 4_096 + SLOT_COUNT * 8_192
    );
}

#[test]
fn request_slot_rejects_oversized_payload() {
    let payload = vec![7_u8; INLINE_REQ_BYTES + 1];

    assert!(RequestSlot::new(1, 0, &payload, [ArtefactRef::nil(); MAX_ARTEFACT_REFS]).is_err());
}

#[test]
fn mapped_arena_initializes_header_and_file_size() {
    let temp = tempfile::tempdir().unwrap();
    let path = temp.path().join("arena.dat");

    let arena = MappedArena::open_or_create(&path).unwrap();

    assert_eq!(arena.path(), path);
    assert_eq!(arena.header().magic, ARENA_MAGIC);
    assert_eq!(arena.header().version, ARENA_VERSION);
    assert_eq!(
        std::fs::metadata(&path).unwrap().len(),
        MappedArena::SIZE as u64
    );
}

#[test]
fn mapped_arena_resets_corrupt_header() {
    let temp = tempfile::tempdir().unwrap();
    let path = temp.path().join("arena.dat");
    std::fs::write(&path, vec![0xAB; MappedArena::SIZE]).unwrap();

    let arena = MappedArena::open_or_create(&path).unwrap();

    assert_eq!(arena.header().magic, ARENA_MAGIC);
    assert_eq!(arena.header().version, ARENA_VERSION);
    assert_eq!(arena.header().req_head.load(Ordering::Acquire), 0);
}

#[test]
fn mapped_arena_submits_and_reads_request_snapshot() {
    let temp = tempfile::tempdir().unwrap();
    let path = temp.path().join("arena.dat");
    let mut arena = MappedArena::open_or_create(&path).unwrap();
    let request =
        RequestSlot::new(42, 123, b"hello", [ArtefactRef::nil(); MAX_ARTEFACT_REFS]).unwrap();

    let seq = arena.submit_request(request).unwrap();
    let snapshot = arena.request_snapshot(seq).unwrap();

    assert_eq!(seq, 1);
    assert_eq!(snapshot.op, 42);
    assert_eq!(snapshot.timestamp, 123);
    assert_eq!(snapshot.payload, b"hello");
    assert_eq!(arena.header().req_head.load(Ordering::Acquire), 1);
    assert_eq!(arena.request_snapshot(seq).unwrap().seq, seq);
}

#[test]
fn mapped_arena_consumes_request_and_detects_full_ring() {
    let temp = tempfile::tempdir().unwrap();
    let path = temp.path().join("arena.dat");
    let mut arena = MappedArena::open_or_create(&path).unwrap();

    for idx in 0..SLOT_COUNT {
        let request = RequestSlot::new(
            idx as u16,
            idx as u64,
            &[idx as u8],
            [ArtefactRef::nil(); MAX_ARTEFACT_REFS],
        )
        .unwrap();
        arena.submit_request(request).unwrap();
    }

    let full = RequestSlot::new(99, 99, b"full", [ArtefactRef::nil(); MAX_ARTEFACT_REFS]).unwrap();
    assert!(arena.submit_request(full).is_err());

    arena.mark_request_consumed(1).unwrap();
    let next =
        RequestSlot::new(100, 100, b"next", [ArtefactRef::nil(); MAX_ARTEFACT_REFS]).unwrap();
    let seq = arena.submit_request(next).unwrap();
    assert_eq!(seq, SLOT_COUNT as u64 + 1);
    assert_eq!(arena.request_snapshot(seq).unwrap().payload, b"next");
}

#[test]
fn submitted_request_state_is_ready() {
    let temp = tempfile::tempdir().unwrap();
    let path = temp.path().join("arena.dat");
    let mut arena = MappedArena::open_or_create(&path).unwrap();
    let request = RequestSlot::new(1, 0, b"x", [ArtefactRef::nil(); MAX_ARTEFACT_REFS]).unwrap();

    let seq = arena.submit_request(request).unwrap();

    assert_eq!(arena.request_snapshot(seq).unwrap().seq, seq);
    assert_eq!(STATE_READY, 2);
}
