//! F-UAS-ZeroCopy-Spine — path 3 substrate-floor integration test.
//!
//! Per `docs/falsifiers/F-UAS-ZeroCopy-Spine_2026_05_17.md` §2.1 row 3:
//! "KV cache page metadata" must round-trip across an FFI-shaped surface
//! with `copy_count == 0`.
//!
//! # Substrate-floor scope
//!
//! Production path: KV cache page metadata (UasAddress + ResidencyLease)
//! crosses the Rust → Swift FFI boundary as a fixed-size byte buffer with
//! no serde / no JSON / no allocation. Swift unpacks the buffer directly
//! into its mirror types.
//!
//! This test exercises the substrate-floor pack/unpack contract using
//! manual byte-packing into a caller-allocated [u8; N] buffer. Zero
//! allocations on the hot path.

use agent_core::uas::copy_counter::{self, CountingAllocator};
use agent_core::uas::{ResidencyLease, ResidencyTier, UasAddress, UasKind};
use std::sync::Mutex;

#[global_allocator]
static GLOBAL: CountingAllocator = CountingAllocator::new();

static FILE_SERIAL: Mutex<()> = Mutex::new(());

/// Fixed-size on-wire layout for KV-page metadata (UasAddress +
/// ResidencyLease):
///
/// | offset | size | field |
/// |---|---|---|
/// | 0  | 32 | blake3 hash |
/// | 32 | 8  | created_at_ms |
/// | 40 | 1  | UasKind tag-index (0 = VaultNote ... 7 = TriFusionBlock; 0xFF = Other-unsupported) |
/// | 41 | 1  | ResidencyTier tag-index (0 = CurrentApp / 1 = VerifiedFloor / 2 = CapabilityCeiling) |
/// | 42 | 8  | granted_at_ms |
/// | 50 | 8  | ttl_ms |
/// total: 58 bytes
const WIRE_SIZE: usize = 58;

/// Pack `UasAddress + ResidencyLease` into a caller-allocated buffer.
/// Zero allocations on the hot path.
///
/// Returns the number of bytes written (always `WIRE_SIZE` on success);
/// caller is expected to pass a `&mut [u8; WIRE_SIZE]`-sized buffer.
fn pack_kv_metadata(
    address: &UasAddress,
    lease: &ResidencyLease,
    out: &mut [u8],
) -> Result<usize, &'static str> {
    if out.len() < WIRE_SIZE {
        return Err("buffer too small");
    }

    out[0..32].copy_from_slice(address.hash.as_bytes());
    out[32..40].copy_from_slice(&address.created_at_ms.to_le_bytes());

    out[40] = uas_kind_tag(&address.kind);
    out[41] = residency_tier_tag(&lease.tier);

    out[42..50].copy_from_slice(&lease.granted_at_ms.to_le_bytes());
    out[50..58].copy_from_slice(&lease.ttl_ms.to_le_bytes());

    Ok(WIRE_SIZE)
}

/// Unpack the inverse of `pack_kv_metadata`. Zero allocations on hot path.
fn unpack_kv_metadata(
    buf: &[u8],
) -> Result<(UasKind, u64, ResidencyTier, u64, u64, [u8; 32]), &'static str> {
    if buf.len() < WIRE_SIZE {
        return Err("buffer too small");
    }

    let mut hash_bytes = [0_u8; 32];
    hash_bytes.copy_from_slice(&buf[0..32]);

    let created_at_ms = u64::from_le_bytes(buf[32..40].try_into().map_err(|_| "bad u64")?);

    let kind = uas_kind_from_tag(buf[40]).ok_or("bad UasKind tag")?;
    let tier = residency_tier_from_tag(buf[41]).ok_or("bad ResidencyTier tag")?;

    let granted_at_ms = u64::from_le_bytes(buf[42..50].try_into().map_err(|_| "bad u64")?);
    let ttl_ms = u64::from_le_bytes(buf[50..58].try_into().map_err(|_| "bad u64")?);

    Ok((kind, created_at_ms, tier, granted_at_ms, ttl_ms, hash_bytes))
}

fn uas_kind_tag(k: &UasKind) -> u8 {
    match k {
        UasKind::VaultNote => 0,
        UasKind::GraphNode => 1,
        UasKind::KvPage => 2,
        UasKind::ModelComponent => 3,
        UasKind::AgentTrace => 4,
        UasKind::ToolResult => 5,
        UasKind::AnswerPacket => 6,
        UasKind::TriFusionBlock => 7,
        UasKind::Other(_) => 0xFF, // wire-form drops the string; lossy by design
    }
}

fn uas_kind_from_tag(tag: u8) -> Option<UasKind> {
    match tag {
        0 => Some(UasKind::VaultNote),
        1 => Some(UasKind::GraphNode),
        2 => Some(UasKind::KvPage),
        3 => Some(UasKind::ModelComponent),
        4 => Some(UasKind::AgentTrace),
        5 => Some(UasKind::ToolResult),
        6 => Some(UasKind::AnswerPacket),
        7 => Some(UasKind::TriFusionBlock),
        _ => None,
    }
}

fn residency_tier_tag(t: &ResidencyTier) -> u8 {
    match t {
        ResidencyTier::CurrentApp => 0,
        ResidencyTier::VerifiedFloor => 1,
        ResidencyTier::CapabilityCeiling => 2,
    }
}

fn residency_tier_from_tag(tag: u8) -> Option<ResidencyTier> {
    match tag {
        0 => Some(ResidencyTier::CurrentApp),
        1 => Some(ResidencyTier::VerifiedFloor),
        2 => Some(ResidencyTier::CapabilityCeiling),
        _ => None,
    }
}

/// GATE: KV metadata pack/unpack hot path is zero-copy + zero-alloc.
#[test]
fn kv_metadata_pack_unpack_is_zero_copy_zero_alloc() {
    let _guard = FILE_SERIAL.lock().unwrap_or_else(|p| p.into_inner());

    let address = UasAddress::new(UasKind::KvPage, b"kv-page-content", 1_000_000);
    let lease = ResidencyLease::new(address.clone(), ResidencyTier::VerifiedFloor, 1_000_000, 30_000);
    let mut buf = [0_u8; WIRE_SIZE];

    // Warmup.
    for _ in 0..10 {
        let _ = pack_kv_metadata(&address, &lease, &mut buf);
        let _ = unpack_kv_metadata(&buf);
    }

    // Hot path.
    let ((), stats) = copy_counter::with_tracking(|| {
        for _ in 0..200 {
            let _ = pack_kv_metadata(&address, &lease, &mut buf);
            let _ = unpack_kv_metadata(&buf);
        }
    });

    assert_eq!(stats.copy_count, 0, "F-UAS-ZeroCopy-Spine path 3 FAILED: copy_count = {}", stats.copy_count);
    assert_eq!(stats.alloc_count, 0, "F-UAS-ZeroCopy-Spine path 3 FAILED: alloc_count = {}", stats.alloc_count);
}

/// Correctness sanity — pack then unpack returns identical fields.
#[test]
fn kv_metadata_round_trip_preserves_fields() {
    let _guard = FILE_SERIAL.lock().unwrap_or_else(|p| p.into_inner());

    let address = UasAddress::new(UasKind::AnswerPacket, b"round-trip", 7777);
    let lease = ResidencyLease::new(address.clone(), ResidencyTier::CapabilityCeiling, 7777, 5_000);
    let mut buf = [0_u8; WIRE_SIZE];

    pack_kv_metadata(&address, &lease, &mut buf).expect("pack must succeed");
    let (kind, created_at_ms, tier, granted_at_ms, ttl_ms, hash_bytes) =
        unpack_kv_metadata(&buf).expect("unpack must succeed");

    assert_eq!(kind, UasKind::AnswerPacket);
    assert_eq!(created_at_ms, 7777);
    assert_eq!(tier, ResidencyTier::CapabilityCeiling);
    assert_eq!(granted_at_ms, 7777);
    assert_eq!(ttl_ms, 5_000);
    assert_eq!(&hash_bytes, address.hash.as_bytes());
}

/// Edge case: buffer too small surfaces typed error.
#[test]
fn pack_into_undersized_buffer_errors() {
    let _guard = FILE_SERIAL.lock().unwrap_or_else(|p| p.into_inner());
    let address = UasAddress::new(UasKind::VaultNote, b"x", 0);
    let lease = ResidencyLease::new(address.clone(), ResidencyTier::CurrentApp, 0, 100);
    let mut small_buf = [0_u8; 16];
    let result = pack_kv_metadata(&address, &lease, &mut small_buf);
    assert!(result.is_err());
}

/// Edge case: invalid kind tag on unpack surfaces typed error.
#[test]
fn unpack_invalid_kind_tag_errors() {
    let _guard = FILE_SERIAL.lock().unwrap_or_else(|p| p.into_inner());
    let mut buf = [0_u8; WIRE_SIZE];
    buf[40] = 99; // invalid tag
    assert!(unpack_kv_metadata(&buf).is_err());
}
