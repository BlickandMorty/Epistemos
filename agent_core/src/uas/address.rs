//! UasAddress — content-addressed substrate identity.
//!
//! Per §4.G UAS LOCK: identity is independent of residency. A `UasAddress`
//! is the joint identity (`kind` × content `hash` × `created_at_ms`) that
//! resolves the same regardless of where the artifact currently lives
//! (RAM hot · RAM warm · SSD cold · cloud cascade).
//!
//! Source:
//! - Canonical doctrine `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md`
//!   §5 register row #1.
//! - Phase B blueprint `docs/audits/UAS_ACS_PHASE_B_BLUEPRINT_2026_05_17.md`
//!   §2.1 iter 21.

use blake3::Hash;
use serde::{Deserialize, Serialize};
use std::fmt;
use std::str::FromStr;

use crate::uas::UasKind;

/// Content-addressed UAS identity.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct UasAddress {
    pub kind: UasKind,
    #[serde(with = "serde_blake3_hash")]
    pub hash: Hash,
    pub created_at_ms: u64,
}

impl UasAddress {
    /// Build a new `UasAddress` by content-hashing `bytes`.
    pub fn new(kind: UasKind, bytes: &[u8], created_at_ms: u64) -> Self {
        Self {
            kind,
            hash: blake3::hash(bytes),
            created_at_ms,
        }
    }

    /// Build from an already-computed hash.
    pub fn from_hash(kind: UasKind, hash: Hash, created_at_ms: u64) -> Self {
        Self { kind, hash, created_at_ms }
    }
}

/// Wire-format error surface for `<UasAddress as FromStr>::from_str`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum UasAddressParseError {
    /// Wire string lacked the canonical `<kind>:<hex>@<ms>` shape.
    BadShape,
    /// `<kind>` segment is wire-format malformed (empty). Unknown tags do
    /// NOT trigger this — they deserialize to `UasKind::Other` per the
    /// forward-compat escape hatch.
    BadKind(String),
    /// `<hex>` segment was not a valid 64-hex-char BLAKE3 representation.
    BadHash(String),
    /// `<ms>` segment did not parse as `u64`.
    BadCreatedAt(String),
}

impl fmt::Display for UasAddressParseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            UasAddressParseError::BadShape => write!(f, "UasAddress wire-format must be `<kind>:<hex>@<ms>`"),
            UasAddressParseError::BadKind(k) => write!(f, "malformed UasKind wire tag `{}` (empty)", k),
            UasAddressParseError::BadHash(h) => write!(f, "invalid BLAKE3 hex `{}` (expected 64 hex chars)", h),
            UasAddressParseError::BadCreatedAt(ms) => write!(f, "invalid created_at_ms `{}` (expected u64)", ms),
        }
    }
}

impl std::error::Error for UasAddressParseError {}

impl fmt::Display for UasAddress {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{}:{}@{}",
            self.kind.wire_tag(),
            self.hash.to_hex(),
            self.created_at_ms
        )
    }
}

impl FromStr for UasAddress {
    type Err = UasAddressParseError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let (kind_part, rest) = s.split_once(':').ok_or(UasAddressParseError::BadShape)?;
        let (hex_part, ms_part) = rest.split_once('@').ok_or(UasAddressParseError::BadShape)?;

        // UasKind::from_wire_tag is total — unknown tags deserialize to
        // UasKind::Other(tag.to_string()). BadKind in the error enum is
        // reserved for kind segments that are wire-format malformed (empty
        // string) rather than unknown.
        if kind_part.is_empty() {
            return Err(UasAddressParseError::BadKind(String::new()));
        }
        let kind = UasKind::from_wire_tag(kind_part);

        let hash = Hash::from_hex(hex_part)
            .map_err(|_| UasAddressParseError::BadHash(hex_part.to_string()))?;

        let created_at_ms = ms_part
            .parse::<u64>()
            .map_err(|_| UasAddressParseError::BadCreatedAt(ms_part.to_string()))?;

        Ok(UasAddress { kind, hash, created_at_ms })
    }
}

mod serde_blake3_hash {
    use blake3::Hash;
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S: Serializer>(h: &Hash, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&h.to_hex().to_string())
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<Hash, D::Error> {
        let hex = String::deserialize(d)?;
        Hash::from_hex(&hex).map_err(serde::de::Error::custom)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip_display_fromstr() {
        let addr = UasAddress::new(UasKind::VaultNote, b"hello-uas", 1_234_567_890);
        let s = addr.to_string();
        let parsed = UasAddress::from_str(&s).expect("Display/FromStr must round-trip");
        assert_eq!(addr, parsed);
    }

    #[test]
    fn round_trip_serde_json() {
        let addr = UasAddress::new(UasKind::VaultNote, b"hello-uas", 1_234_567_890);
        let json = serde_json::to_string(&addr).expect("serialize must succeed");
        let parsed: UasAddress = serde_json::from_str(&json).expect("deserialize must succeed");
        assert_eq!(addr, parsed);
    }

    #[test]
    fn hash_is_blake3_32_bytes() {
        let addr = UasAddress::new(UasKind::VaultNote, b"x", 0);
        assert_eq!(addr.hash.as_bytes().len(), 32);
    }

    #[test]
    fn bad_shape_surfaces_typed_error() {
        let err = UasAddress::from_str("no-colon-no-at").unwrap_err();
        assert_eq!(err, UasAddressParseError::BadShape);
    }

    #[test]
    fn unknown_kind_falls_back_to_other_variant() {
        // The forward-compat escape hatch: an unknown kind tag deserializes
        // to UasKind::Other, NOT BadKind. BadKind is reserved for wire-format
        // malformed (empty) tag segments.
        let fake_hex: String = std::iter::repeat('a').take(64).collect();
        let s = format!("future_variant_xyz:{}@0", fake_hex);
        let parsed = UasAddress::from_str(&s).expect("unknown kind must fall back to Other, not error");
        assert_eq!(parsed.kind, UasKind::Other("future_variant_xyz".to_string()));
    }

    #[test]
    fn empty_kind_surfaces_bad_kind_error() {
        let fake_hex: String = std::iter::repeat('a').take(64).collect();
        let s = format!(":{}@0", fake_hex);
        let err = UasAddress::from_str(&s).unwrap_err();
        assert_eq!(err, UasAddressParseError::BadKind(String::new()));
    }

    #[test]
    fn bad_hash_surfaces_typed_error() {
        let s = "vault_note:not-a-hash@0";
        let err = UasAddress::from_str(s).unwrap_err();
        assert!(matches!(err, UasAddressParseError::BadHash(_)));
    }

    #[test]
    fn bad_created_at_surfaces_typed_error() {
        let fake_hex: String = std::iter::repeat('a').take(64).collect();
        let s = format!("vault_note:{}@not-a-number", fake_hex);
        let err = UasAddress::from_str(&s).unwrap_err();
        assert!(matches!(err, UasAddressParseError::BadCreatedAt(_)));
    }
}
