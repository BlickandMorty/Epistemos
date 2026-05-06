//! HELIOS V5 E6 — Error-Enriched Convergence (Epi_ε category).
//!
//! HELIOS-E6 guard
//!
//! Five source formalisms admit structure-preserving embeddings into
//! Epi_ε. **NOT metaphysical identity** — embeddings, not equality.

use serde::{Deserialize, Serialize};

/// Tag for one of the five source formalisms whose Epi_ε embedding
/// is canonically defined.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SourceFormalism {
    SmoothManifolds,
    LensCategories,
    ParametricMaps,
    ReverseDerivativeCategories,
    StochasticCategories,
}

/// One Epi_ε embedding witness — claims the source formalism embeds
/// into Epi_ε with the named structure-preservation properties.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EpiEpsilonEmbedding {
    pub source: SourceFormalism,
    pub preserves_composition: bool,
    pub preserves_identity: bool,
    pub preserves_associativity: bool,
}

impl EpiEpsilonEmbedding {
    pub fn new(source: SourceFormalism) -> Self {
        Self {
            source,
            preserves_composition: true,
            preserves_identity: true,
            preserves_associativity: true,
        }
    }

    /// Structure-preserving iff all three properties hold.
    pub fn is_structure_preserving(&self) -> bool {
        self.preserves_composition
            && self.preserves_identity
            && self.preserves_associativity
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_embedding_is_structure_preserving() {
        let e = EpiEpsilonEmbedding::new(SourceFormalism::LensCategories);
        assert!(e.is_structure_preserving());
    }

    #[test]
    fn embedding_round_trips_through_json() {
        let e = EpiEpsilonEmbedding::new(SourceFormalism::ParametricMaps);
        let json = serde_json::to_string(&e).unwrap();
        let parsed: EpiEpsilonEmbedding = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, e);
    }

    #[test]
    fn embedding_serializes_source_in_snake_case() {
        let e = EpiEpsilonEmbedding::new(SourceFormalism::ReverseDerivativeCategories);
        let json = serde_json::to_string(&e).unwrap();
        assert!(json.contains("\"source\":\"reverse_derivative_categories\""));
    }
}
