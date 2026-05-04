//! Shared type system for tier transitions, page headers, and token signatures.

/// Stable token identifier inside a deterministic replay log.
pub type TokenId = u64;

/// The six memory tiers in the Helios hierarchy.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum TierState {
    /// L0 exact hot state: bf16 / full precision ring buffer.
    Hot,
    /// L1 residual checkpoint: compressed residual plus deterministic K/V recomputation.
    Residual,
    /// L2 sparse sketch state for page routing.
    Shadow,
    /// L3 SSD backed oracle page.
    Ssd,
    /// L4 Hermes / cloud fallback boundary.
    Cloud,
    /// L_SE bounded online memory and nightly adapter consolidation.
    SelfEvolving,
}

/// Learning substrate selected for an update.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum LearningMode {
    /// No learning; inference only.
    Freeze,
    /// Session-local fast-weight patch.
    FastWeight,
    /// Persistent adapter bank update.
    LoRa,
    /// Sketch-only update.
    Sketch,
}

/// Claim epistemic class used by the Resonance Gate.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum ClaimType {
    /// Locally grounded primitive claim.
    Prime,
    /// Multi-source or cloud-derived claim requiring provenance.
    Composite,
    /// Missing evidence, contradiction, or unverified assertion.
    Gap,
}

/// Direction field for the eight-field resonance signature.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum Direction {
    Upward,
    Downward,
    Sideways,
    Inward,
    OnItself,
    None,
}

/// Compact 32-byte page header. This is intentionally fixed width for mmap/Metal alignment.
#[repr(C, align(32))]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct PageHeader {
    pub magic: u32,
    pub version: u16,
    pub tier: u8,
    pub flags: u8,
    pub page_id: u64,
    pub token_start: u64,
    pub token_len: u32,
    pub checksum: u32,
}

impl PageHeader {
    pub const MAGIC: u32 = 0x4845_4C49; // HELI

    /// Construct a deterministic page header.
    #[must_use]
    pub const fn new(tier: TierState, page_id: u64, token_start: u64, token_len: u32, checksum: u32) -> Self {
        Self {
            magic: Self::MAGIC,
            version: 1,
            tier: tier as u8,
            flags: 0,
            page_id,
            token_start,
            token_len,
            checksum,
        }
    }
}

/// Eight-field signature applied to every token or agent event.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ResonanceSignature {
    pub token_id: TokenId,
    pub tier: TierState,
    pub claim_type: ClaimType,
    pub direction: Direction,
    pub coherence: f32,
    pub surprise: f32,
    pub provenance_hash: u64,
    pub entropy: f32,
}

impl ResonanceSignature {
    /// Returns true when all normalized scalar fields are inside the closed unit interval.
    #[must_use]
    pub fn scalar_fields_valid(self) -> bool {
        self.coherence.is_finite()
            && self.surprise.is_finite()
            && self.entropy.is_finite()
            && (0.0..=1.0).contains(&self.coherence)
            && (0.0..=1.0).contains(&self.surprise)
            && (0.0..=1.0).contains(&self.entropy)
    }
}

#[cfg(test)]
mod tests {
    use super::{PageHeader, TierState};

    #[test]
    fn page_header_is_32_bytes() {
        assert_eq!(core::mem::size_of::<PageHeader>(), 32);
        assert_eq!(core::mem::align_of::<PageHeader>(), 32);
        let header = PageHeader::new(TierState::Residual, 7, 1024, 128, 42);
        assert_eq!(header.magic, PageHeader::MAGIC);
    }
}
