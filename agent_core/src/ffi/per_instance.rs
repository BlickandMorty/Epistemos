//! `PerInstanceData` — the C-ABI struct that crosses the SPSC
//! ring buffer per frame (S4; DOCTRINE I-8 / IMPLEMENTATION §2.2).
//!
//! Layout is `#[repr(C)]` and exactly **64 bytes** so each delta
//! occupies one cache line on Apple Silicon (64-byte cache line)
//! and 8-byte alignment is satisfied by the leading `u64` pair.
//! The Swift side mirrors the layout in `Simulation/DeltaRingBridge.swift`
//! — any change here MUST be replicated there in the same commit.
//!
//! Field bit-packing (per IMPLEMENTATION §2.2 + §2.4.1):
//!
//!   agent_id_lo / agent_id_hi   ULID → two u64s. Stable identity.
//!   position[2]                 scene-space x/y. Snapped to integer
//!                               pixels in the vertex shader; Rust
//!                               clamps to integer pre-FFI per I-16.
//!   scale[2]                    integer multiples only (1×/2×/3×/4×).
//!                               `debug_assert!` on the Rust side
//!                               catches fractional inputs (I-16).
//!   atlas_index                 which 2D slice of the texture array
//!                               (one per head shape — Block / Orb /
//!                               Sage / Hermes-Snake).
//!   frame_index                 which frame within the slice (per
//!                               §5.3 14-state animation rig).
//!   palette_id                  which `PaletteRef` row to apply via
//!                               the channel-mask shader (§10.5).
//!   tint[4]                     RGBA override (Custom palettes).
//!   state_flags                 bit-packed: gate=0x01, error=0x02,
//!                               idle_ambient=0x04, active_halo=0x08,
//!                               recovery=0x10. The Metal renderer
//!                               gates the additive halo / eye-bloom
//!                               draws on `active_halo`.

use serde::{Deserialize, Serialize};

use crate::companions::CompanionId;

/// 64-byte, cache-line-aligned per-companion render delta.
/// `#[repr(C)]` so the layout matches the Swift mirror exactly.
#[repr(C)]
#[derive(Copy, Clone, Default, Debug, Serialize, Deserialize, PartialEq)]
pub struct PerInstanceData {
    pub agent_id_lo: u64,
    pub agent_id_hi: u64,
    pub position: [f32; 2],
    pub scale: [f32; 2],
    pub atlas_index: u32,
    pub frame_index: u32,
    pub palette_id: u32,
    pub tint: [f32; 4],
    pub state_flags: u32,
}

// Static sanity: the cache-line-alignment promise is part of the
// FFI contract. If any field reorder breaks 64 bytes / 8-byte
// alignment, this fails at compile time.
const _: () = assert!(std::mem::size_of::<PerInstanceData>() == 64);
const _: () = assert!(std::mem::align_of::<PerInstanceData>() == 8);

/// Bit-packed runtime flags for `PerInstanceData::state_flags`.
/// Stable across the FFI boundary — Swift mirrors these constants
/// numerically.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct StateFlags(pub u32);

impl StateFlags {
    pub const NONE: Self = Self(0);
    pub const GATE: Self = Self(1 << 0);
    pub const ERROR: Self = Self(1 << 1);
    pub const IDLE_AMBIENT: Self = Self(1 << 2);
    pub const ACTIVE_HALO: Self = Self(1 << 3);
    pub const RECOVERY: Self = Self(1 << 4);

    pub const fn empty() -> Self {
        Self(0)
    }

    pub fn insert(&mut self, flag: StateFlags) {
        self.0 |= flag.0;
    }

    pub fn remove(&mut self, flag: StateFlags) {
        self.0 &= !flag.0;
    }

    pub fn contains(self, flag: StateFlags) -> bool {
        self.0 & flag.0 == flag.0
    }
}

impl From<StateFlags> for u32 {
    fn from(f: StateFlags) -> u32 {
        f.0
    }
}

impl From<u32> for StateFlags {
    fn from(v: u32) -> StateFlags {
        StateFlags(v)
    }
}

impl PerInstanceData {
    /// Build a zero-init delta with a `CompanionId` set. Used by
    /// the reducer as the starting point for a per-frame snapshot.
    pub fn new(agent_id: CompanionId) -> Self {
        let bytes = agent_id.0.to_bytes();
        // ULID is 16 bytes; split into two u64 (low / high).
        let lo = u64::from_le_bytes(bytes[0..8].try_into().unwrap());
        let hi = u64::from_le_bytes(bytes[8..16].try_into().unwrap());
        Self {
            agent_id_lo: lo,
            agent_id_hi: hi,
            position: [0.0, 0.0],
            scale: [1.0, 1.0],
            atlas_index: 0,
            frame_index: 0,
            palette_id: 0,
            tint: [1.0, 1.0, 1.0, 1.0],
            state_flags: 0,
        }
    }

    /// Recover the `CompanionId` from the packed (lo, hi) u64 pair.
    pub fn agent_id(self) -> CompanionId {
        let mut bytes = [0u8; 16];
        bytes[0..8].copy_from_slice(&self.agent_id_lo.to_le_bytes());
        bytes[8..16].copy_from_slice(&self.agent_id_hi.to_le_bytes());
        CompanionId(ulid::Ulid::from_bytes(bytes))
    }

    /// Validate I-16 integer-scale invariant. Returns `Err` if
    /// either scale axis is non-integer. Production callers
    /// `debug_assert!` on this; tests assert positively.
    pub fn validate_integer_scale(&self) -> Result<(), &'static str> {
        for axis in 0..2 {
            let s = self.scale[axis];
            if (s - s.round()).abs() > 1e-6 {
                return Err("fractional sprite scale violates I-16");
            }
            if !(1.0..=4.0).contains(&s.abs()) && s != 0.0 {
                // Out-of-band scales (e.g. 0×, >4×) likely mean a
                // bug; the reducer should have clamped before
                // pushing to the ring.
                return Err("scale out of I-16 range [1×..=4×]");
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn size_and_alignment_are_stable() {
        assert_eq!(std::mem::size_of::<PerInstanceData>(), 64);
        assert_eq!(std::mem::align_of::<PerInstanceData>(), 8);
    }

    #[test]
    fn agent_id_round_trips() {
        let id = CompanionId::new_ulid();
        let data = PerInstanceData::new(id);
        assert_eq!(data.agent_id(), id);
    }

    #[test]
    fn integer_scale_validation_accepts_canonical_multiples() {
        for s in [1.0_f32, 2.0, 3.0, 4.0] {
            let mut d = PerInstanceData::new(CompanionId::new_ulid());
            d.scale = [s, s];
            assert!(d.validate_integer_scale().is_ok(), "{s}× must validate");
        }
    }

    #[test]
    fn integer_scale_validation_rejects_fractional() {
        let mut d = PerInstanceData::new(CompanionId::new_ulid());
        d.scale = [1.5, 1.0];
        assert!(d.validate_integer_scale().is_err(), "1.5× must reject");
    }

    #[test]
    fn integer_scale_validation_rejects_out_of_range() {
        let mut d = PerInstanceData::new(CompanionId::new_ulid());
        d.scale = [5.0, 5.0];
        assert!(d.validate_integer_scale().is_err(), "5× exceeds I-16 cap");
    }

    #[test]
    fn state_flags_set_and_query() {
        let mut f = StateFlags::empty();
        assert!(!f.contains(StateFlags::ACTIVE_HALO));
        f.insert(StateFlags::ACTIVE_HALO);
        f.insert(StateFlags::IDLE_AMBIENT);
        assert!(f.contains(StateFlags::ACTIVE_HALO));
        assert!(f.contains(StateFlags::IDLE_AMBIENT));
        assert!(!f.contains(StateFlags::ERROR));
        f.remove(StateFlags::ACTIVE_HALO);
        assert!(!f.contains(StateFlags::ACTIVE_HALO));
        assert!(f.contains(StateFlags::IDLE_AMBIENT));
    }

    #[test]
    fn default_init_zeroes_everything() {
        let d = PerInstanceData::default();
        assert_eq!(d.agent_id_lo, 0);
        assert_eq!(d.position, [0.0, 0.0]);
        assert_eq!(d.scale, [0.0, 0.0]);
        assert_eq!(d.tint, [0.0, 0.0, 0.0, 0.0]);
    }
}
