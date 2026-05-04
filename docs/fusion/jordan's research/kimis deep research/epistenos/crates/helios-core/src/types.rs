//! Core types and type-state machine for the Helios memory hierarchy.
//!
//! This module defines the fundamental types that enforce memory tier semantics
//! at compile time. The type-state pattern ensures that tokens in different
//! memory tiers carry static guarantees about their precision, compressibility,
//! and retrieval guarantees.

use std::marker::PhantomData;

// ---------------------------------------------------------------------------
// Secure newtypes
// ---------------------------------------------------------------------------

/// A secure newtype for token identifiers.
///
/// `TokenId` wraps a `usize` to prevent accidental mixing with other index
/// types and provides checked arithmetic.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct TokenId(pub usize);

impl TokenId {
    /// Create a new `TokenId`.
    pub const fn new(id: usize) -> Self {
        Self(id)
    }

    /// Checked add: returns `None` on overflow.
    pub fn checked_add(self, rhs: usize) -> Option<Self> {
        self.0.checked_add(rhs).map(Self)
    }

    /// Checked sub: returns `None` on underflow.
    pub fn checked_sub(self, rhs: usize) -> Option<Self> {
        self.0.checked_sub(rhs).map(Self)
    }
}

/// A secure newtype for layer identifiers.
///
/// `LayerId` wraps a `usize` to distinguish layer indices from token or
/// sequence positions in function signatures.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct LayerId(pub usize);

impl LayerId {
    /// Create a new `LayerId`.
    pub const fn new(id: usize) -> Self {
        Self(id)
    }

    /// Checked add: returns `None` on overflow.
    pub fn checked_add(self, rhs: usize) -> Option<Self> {
        self.0.checked_add(rhs).map(Self)
    }
}

// ---------------------------------------------------------------------------
// Memory tiers
// ---------------------------------------------------------------------------

/// The six memory tiers of the Epistenos system.
///
/// Each tier represents a different trade-off between precision, capacity, and
/// retrieval cost. The tiers form a partial order from exact (L0) to
/// self-evolving (L_SE).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub enum MemoryTier {
    /// L0 — Exact hot cache. Full-precision, immediately accessible.
    L0ExactHot,
    /// L1 — Compressed residual. Stored via lattice quantization (E8/Leech).
    L1CompressedResidual,
    /// L2 — Shadow sketch. CountSketch / sparse JL for approximate retrieval.
    L2ShadowSketch,
    /// L3 — SSD oracle. Spilled to persistent storage with learned oracle.
    L3SSDOracle,
    /// L4 — Hermes cascade. Retrieved via external consensus / network call.
    L4HermesCascade,
    /// L_SE — Self-evolving. Online-adapted, may diverge from static snapshot.
    LSESelfEvolving,
}

impl MemoryTier {
    /// Return a human-readable description of the tier.
    pub fn description(self) -> &'static str {
        match self {
            MemoryTier::L0ExactHot => "Exact hot cache (full f32 precision)",
            MemoryTier::L1CompressedResidual => "Lattice-quantized residual (E8/Leech)",
            MemoryTier::L2ShadowSketch => "CountSketch / sparse JL sketch",
            MemoryTier::L3SSDOracle => "SSD spill with learned oracle",
            MemoryTier::L4HermesCascade => "Hermes network cascade",
            MemoryTier::LSESelfEvolving => "Self-evolving online adaptation",
        }
    }

    /// Returns `true` if this tier is considered "exact" (lossless).
    pub fn is_exact(self) -> bool {
        matches!(self, MemoryTier::L0ExactHot)
    }

    /// Returns `true` if this tier may diverge from a static snapshot.
    pub fn is_evolved(self) -> bool {
        matches!(self, MemoryTier::LSESelfEvolving)
    }
}

// ---------------------------------------------------------------------------
// Type-state phantom markers
// ---------------------------------------------------------------------------

/// Marker type for L0 (exact hot) tier.
///
/// Tokens carrying this marker are guaranteed to reside in full-precision
/// memory and support exact arithmetic.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct L0;

/// Marker type for L1 (compressed residual) tier.
///
/// Tokens carrying this marker have been quantized via lattice codebooks
/// (E8 or Leech) and incur bounded reconstruction error.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct L1;

/// Marker type for L2 (shadow sketch) tier.
///
/// Tokens carrying this marker are represented by CountSketch or sparse JL
/// projections and support approximate inner-product queries.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct L2;

/// Marker type for L3 (SSD oracle) tier.
///
/// Tokens carrying this marker have been spilled to persistent storage and
/// are retrieved on-demand via a learned oracle.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct L3;

/// Marker type for L4 (Hermes cascade) tier.
///
/// Tokens carrying this marker are resolved via external consensus or
/// network retrieval.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct L4;

/// Marker type for L_SE (self-evolving) tier.
///
/// Tokens carrying this marker are subject to online adaptation and may
/// diverge from their original static representations.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct L_SE;

// ---------------------------------------------------------------------------
// TokenState — generic type-state struct
// ---------------------------------------------------------------------------

/// A token annotated with its memory tier at the type level.
///
/// The phantom type parameter `Tier` statically guarantees which operations
/// are available. Only `TokenState<L0>` supports exact arithmetic; lower
/// tiers expose approximate or retrieved values.
///
/// # Example
/// ```
/// use helios_core::types::{TokenState, L0, TokenId, LayerId};
/// let t = TokenState::<L0>::new(TokenId::new(0), LayerId::new(0));
/// ```
#[derive(Clone, Debug, PartialEq)]
pub struct TokenState<Tier> {
    pub token_id: TokenId,
    pub layer_id: LayerId,
    _marker: PhantomData<Tier>,
}

impl<Tier> TokenState<Tier> {
    /// Create a new `TokenState` without a tier transition (internal).
    fn new_raw(token_id: TokenId, layer_id: LayerId) -> Self {
        Self {
            token_id,
            layer_id,
            _marker: PhantomData,
        }
    }

    /// Create a new `TokenState` in tier `Tier`.
    pub fn new(token_id: TokenId, layer_id: LayerId) -> Self {
        Self::new_raw(token_id, layer_id)
    }

    /// Access the token identifier.
    pub fn token_id(&self) -> TokenId {
        self.token_id
    }

    /// Access the layer identifier.
    pub fn layer_id(&self) -> LayerId {
        self.layer_id
    }
}

// ---------------------------------------------------------------------------
// Tier promotion / demotion — compile-time verified transitions
// ---------------------------------------------------------------------------

/// Promote an L0 token to L1 (compress via lattice quantization).
///
/// This is a lossy transition. The returned `TokenState<L1>` no longer
/// guarantees exact precision.
pub fn promote_l0_to_l1(token: TokenState<L0>) -> TokenState<L1> {
    TokenState::new_raw(token.token_id, token.layer_id)
}

/// Demote an L1 token to L2 (sketch for approximate retrieval).
///
/// Further loss of precision. The token is now represented by a sketch
/// suitable for approximate similarity search.
pub fn demote_l1_to_l2(token: TokenState<L1>) -> TokenState<L2> {
    TokenState::new_raw(token.token_id, token.layer_id)
}

/// Demote an L2 token to L3 (spill to SSD).
///
/// The token leaves RAM and is retrieved on demand.
pub fn demote_l2_to_l3(token: TokenState<L2>) -> TokenState<L3> {
    TokenState::new_raw(token.token_id, token.layer_id)
}

/// Demote an L3 token to L4 (external cascade).
///
/// The token is resolved via network / consensus.
pub fn demote_l3_to_l4(token: TokenState<L3>) -> TokenState<L4> {
    TokenState::new_raw(token.token_id, token.layer_id)
}

/// Promote any tier to L_SE (self-evolving online adaptation).
///
/// This is a special tier that may diverge from static snapshots.
/// The phantom type `FromTier` ensures we track the origin tier in the
/// type system even though the runtime value is dropped.
pub fn promote_to_l_se<FromTier>(token: TokenState<FromTier>) -> TokenState<L_SE> {
    TokenState::new_raw(token.token_id, token.layer_id)
}

// ---------------------------------------------------------------------------
// TernaryState
// ---------------------------------------------------------------------------

/// A signed ternary value: -1, 0, or +1.
///
/// Used for hash signs in CountSketch and for sparse indicator projections.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub enum TernaryState {
    /// Negative (-1)
    Neg = -1,
    /// Zero (0)
    #[default]
    Zero = 0,
    /// Positive (+1)
    Pos = 1,
}

impl TernaryState {
    /// Convert to `i8`.
    pub const fn as_i8(self) -> i8 {
        match self {
            TernaryState::Neg => -1,
            TernaryState::Zero => 0,
            TernaryState::Pos => 1,
        }
    }

    /// Convert to `f32`.
    pub const fn as_f32(self) -> f32 {
        match self {
            TernaryState::Neg => -1.0,
            TernaryState::Zero => 0.0,
            TernaryState::Pos => 1.0,
        }
    }

    /// Return the sign of a `f32` value as a `TernaryState`.
    pub fn from_f32(x: f32) -> Self {
        if x > 0.0 {
            TernaryState::Pos
        } else if x < 0.0 {
            TernaryState::Neg
        } else {
            TernaryState::Zero
        }
    }
}

// ---------------------------------------------------------------------------
// BlockScale
// ---------------------------------------------------------------------------

/// A per-block quantization scale factor.
///
/// `BlockScale` wraps an `f32` to distinguish scale factors from raw weights
/// and to provide checked conversion utilities.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct BlockScale(pub f32);

impl BlockScale {
    /// Create a new `BlockScale`.
    pub const fn new(scale: f32) -> Self {
        Self(scale)
    }

    /// Apply the scale to a quantized integer value, returning a dequantized
    /// `f32`.
    pub fn dequantize(self, q: i8) -> f32 {
        self.0 * q as f32
    }

    /// Quantize a `f32` value using this scale.
    pub fn quantize(self, x: f32) -> i8 {
        (x / self.0).round().clamp(-128.0, 127.0) as i8
    }
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn token_id_checked_add() {
        let t = TokenId::new(10);
        assert_eq!(t.checked_add(5), Some(TokenId(15)));
        assert_eq!(TokenId(usize::MAX).checked_add(1), None);
    }

    #[test]
    fn token_id_checked_sub() {
        let t = TokenId::new(10);
        assert_eq!(t.checked_sub(5), Some(TokenId(5)));
        assert_eq!(t.checked_sub(15), None);
    }

    #[test]
    fn layer_id_checked_add() {
        let l = LayerId::new(3);
        assert_eq!(l.checked_add(2), Some(LayerId(5)));
    }

    #[test]
    fn memory_tier_exact_only_l0() {
        assert!(MemoryTier::L0ExactHot.is_exact());
        assert!(!MemoryTier::L1CompressedResidual.is_exact());
        assert!(!MemoryTier::L2ShadowSketch.is_exact());
        assert!(!MemoryTier::L3SSDOracle.is_exact());
        assert!(!MemoryTier::L4HermesCascade.is_exact());
        assert!(!MemoryTier::LSESelfEvolving.is_exact());
    }

    #[test]
    fn memory_tier_evolved_only_lse() {
        assert!(!MemoryTier::L0ExactHot.is_evolved());
        assert!(!MemoryTier::L1CompressedResidual.is_evolved());
        assert!(!MemoryTier::L2ShadowSketch.is_evolved());
        assert!(!MemoryTier::L3SSDOracle.is_evolved());
        assert!(!MemoryTier::L4HermesCascade.is_evolved());
        assert!(MemoryTier::LSESelfEvolving.is_evolved());
    }

    #[test]
    fn type_state_promotion_l0_to_l1() {
        let t0 = TokenState::<L0>::new(TokenId::new(42), LayerId::new(7));
        let t1 = promote_l0_to_l1(t0);
        assert_eq!(t1.token_id(), TokenId::new(42));
        assert_eq!(t1.layer_id(), LayerId::new(7));
    }

    #[test]
    fn type_state_demotion_l1_to_l2() {
        let t1 = TokenState::<L1>::new(TokenId::new(1), LayerId::new(2));
        let t2 = demote_l1_to_l2(t1);
        assert_eq!(t2.token_id(), TokenId::new(1));
        assert_eq!(t2.layer_id(), LayerId::new(2));
    }

    #[test]
    fn type_state_full_cascade() {
        let t0 = TokenState::<L0>::new(TokenId::new(0), LayerId::new(0));
        let t1 = promote_l0_to_l1(t0);
        let t2 = demote_l1_to_l2(t1);
        let t3 = demote_l2_to_l3(t2);
        let t4 = demote_l3_to_l4(t3);
        assert_eq!(t4.token_id(), TokenId::new(0));
        assert_eq!(t4.layer_id(), LayerId::new(0));
    }

    #[test]
    fn type_state_promote_to_lse_from_any_tier() {
        let t0 = TokenState::<L0>::new(TokenId::new(0), LayerId::new(0));
        let t_se = promote_to_l_se(t0);
        assert_eq!(t_se.token_id(), TokenId::new(0));
        assert_eq!(t_se.layer_id(), LayerId::new(0));

        let t3 = TokenState::<L3>::new(TokenId::new(3), LayerId::new(1));
        let t_se_3 = promote_to_l_se(t3);
        assert_eq!(t_se_3.token_id(), TokenId::new(3));
    }

    #[test]
    fn ternary_state_values() {
        assert_eq!(TernaryState::Neg.as_i8(), -1);
        assert_eq!(TernaryState::Zero.as_i8(), 0);
        assert_eq!(TernaryState::Pos.as_i8(), 1);

        assert_eq!(TernaryState::Neg.as_f32(), -1.0);
        assert_eq!(TernaryState::Zero.as_f32(), 0.0);
        assert_eq!(TernaryState::Pos.as_f32(), 1.0);
    }

    #[test]
    fn ternary_from_f32() {
        assert_eq!(TernaryState::from_f32(-0.5), TernaryState::Neg);
        assert_eq!(TernaryState::from_f32(0.0), TernaryState::Zero);
        assert_eq!(TernaryState::from_f32(0.5), TernaryState::Pos);
    }

    #[test]
    fn block_scale_round_trip() {
        let scale = BlockScale::new(0.125);
        let x = 3.0_f32;
        let q = scale.quantize(x); // 3.0 / 0.125 = 24
        let y = scale.dequantize(q);
        assert_eq!(q, 24);
        assert!((y - 3.0).abs() < 1e-6);
    }

    #[test]
    fn token_state_clone_and_eq() {
        let a = TokenState::<L0>::new(TokenId::new(1), LayerId::new(2));
        let b = a.clone();
        assert_eq!(a, b);
    }
}
