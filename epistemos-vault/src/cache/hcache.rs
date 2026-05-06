//! HELIOS V5 W22a — HCache (Vault).
//!
//! HELIOS-W22-HCACHE guard
//!
//! HCache is an experimental KV-cache layer that compresses cold
//! pages via huffman + delta encoding for cross-session restore.
//! Lane 5 Vault — never in MAS.

use serde::{Deserialize, Serialize};

/// One HCache entry: compressed key+value pages with a
/// reconstruction recipe.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct HCacheEntry {
    pub entry_id: String,
    pub key_bytes: Vec<u8>,
    pub value_bytes: Vec<u8>,
    /// Recipe for reconstructing the original f32 vectors.
    pub recipe: HCacheRecipe,
}

/// Reconstruction recipe metadata.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct HCacheRecipe {
    pub compression: HCacheCompression,
    pub original_dim: u32,
    pub original_count: u32,
}

/// HCache compression algorithm tag.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HCacheCompression {
    /// No compression — raw bytes.
    Raw,
    /// Huffman + delta encoding.
    HuffmanDelta,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn entry_round_trips_through_json() {
        let e = HCacheEntry {
            entry_id: "e1".to_string(),
            key_bytes: vec![0u8; 16],
            value_bytes: vec![0u8; 16],
            recipe: HCacheRecipe {
                compression: HCacheCompression::Raw,
                original_dim: 8,
                original_count: 2,
            },
        };
        let json = serde_json::to_string(&e).unwrap();
        let parsed: HCacheEntry = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, e);
    }

    #[test]
    fn compression_serializes_in_snake_case() {
        assert_eq!(
            serde_json::to_string(&HCacheCompression::HuffmanDelta).unwrap(),
            "\"huffman_delta\""
        );
    }
}
