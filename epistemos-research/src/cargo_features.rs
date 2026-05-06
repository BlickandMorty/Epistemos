//! HELIOS V5 — Canonical Cargo feature flag taxonomy
//! (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-CARGO-FEATURES guard
//!
//! Per HELIOS v4 preservation `source_docs/epistenos_build_prompt.md`
//! §4.3 (Feature Flags) — the canonical Cargo feature names used
//! across the helios-* workspace.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// Canonical Cargo feature names per the build-prompt §4.3 spec.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CanonicalFeature {
    /// `metal` — direct-Metal kernel path. Default.
    Metal,
    /// `mlx` — MLX tensor backend. Default.
    Mlx,
    /// `ane` — Apple Neural Engine (EXPERIMENTAL).
    Ane,
    /// `ssm` — Mamba / state-space model harness.
    Ssm,
    /// `ttt` — Test-Time Training inner-loop SGD.
    Ttt,
    /// `self_tuning` — L_SE Titans-MAC + SEAL DoRA.
    SelfTuning,
    /// `vault` — Vault FFI surface for biometric-scoped agents.
    Vault,
    /// `hermes` — Hermes cloud gateway (Pro builds only).
    Hermes,
    /// `bench` — benchmark harness.
    Bench,
}

impl CanonicalFeature {
    /// True when this feature is in the default-features list per
    /// build-prompt §4.3 (`default = ["metal", "mlx"]`).
    pub fn is_default(self) -> bool {
        matches!(self, CanonicalFeature::Metal | CanonicalFeature::Mlx)
    }

    /// True when this feature is experimental / not-product-ready.
    pub fn is_experimental(self) -> bool {
        matches!(self, CanonicalFeature::Ane)
    }

    /// True when this feature is Pro-build-only per the
    /// MAS-First Focus Doctrine.
    pub fn is_pro_only(self) -> bool {
        matches!(self, CanonicalFeature::Hermes)
    }

    /// Cargo feature string per the build-prompt's `[features]`
    /// table.
    pub fn cargo_name(self) -> &'static str {
        match self {
            CanonicalFeature::Metal => "metal",
            CanonicalFeature::Mlx => "mlx",
            CanonicalFeature::Ane => "ane",
            CanonicalFeature::Ssm => "ssm",
            CanonicalFeature::Ttt => "ttt",
            CanonicalFeature::SelfTuning => "self_tuning",
            CanonicalFeature::Vault => "vault",
            CanonicalFeature::Hermes => "hermes",
            CanonicalFeature::Bench => "bench",
        }
    }
}

/// All nine canonical Cargo features in build-prompt order.
pub const NINE_FEATURES: [CanonicalFeature; 9] = [
    CanonicalFeature::Metal,
    CanonicalFeature::Mlx,
    CanonicalFeature::Ane,
    CanonicalFeature::Ssm,
    CanonicalFeature::Ttt,
    CanonicalFeature::SelfTuning,
    CanonicalFeature::Vault,
    CanonicalFeature::Hermes,
    CanonicalFeature::Bench,
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn nine_features_listed_in_canonical_order() {
        assert_eq!(NINE_FEATURES.len(), 9);
        assert_eq!(NINE_FEATURES[0], CanonicalFeature::Metal);
        assert_eq!(NINE_FEATURES[1], CanonicalFeature::Mlx);
        assert_eq!(NINE_FEATURES[8], CanonicalFeature::Bench);
    }

    #[test]
    fn nine_features_are_distinct() {
        let set: std::collections::HashSet<CanonicalFeature> =
            NINE_FEATURES.iter().copied().collect();
        assert_eq!(set.len(), 9);
    }

    #[test]
    fn metal_and_mlx_are_default_others_are_not() {
        assert!(CanonicalFeature::Metal.is_default());
        assert!(CanonicalFeature::Mlx.is_default());
        for f in [
            CanonicalFeature::Ane,
            CanonicalFeature::Ssm,
            CanonicalFeature::Ttt,
            CanonicalFeature::SelfTuning,
            CanonicalFeature::Vault,
            CanonicalFeature::Hermes,
            CanonicalFeature::Bench,
        ] {
            assert!(!f.is_default());
        }
    }

    #[test]
    fn only_ane_is_experimental() {
        for f in NINE_FEATURES {
            if f == CanonicalFeature::Ane {
                assert!(f.is_experimental());
            } else {
                assert!(!f.is_experimental());
            }
        }
    }

    #[test]
    fn only_hermes_is_pro_only() {
        for f in NINE_FEATURES {
            if f == CanonicalFeature::Hermes {
                assert!(f.is_pro_only());
            } else {
                assert!(!f.is_pro_only());
            }
        }
    }

    #[test]
    fn cargo_names_match_canonical_doctrine() {
        // Pin every cargo string per the [features] table.
        assert_eq!(CanonicalFeature::Metal.cargo_name(), "metal");
        assert_eq!(CanonicalFeature::Mlx.cargo_name(), "mlx");
        assert_eq!(CanonicalFeature::Ane.cargo_name(), "ane");
        assert_eq!(CanonicalFeature::Ssm.cargo_name(), "ssm");
        assert_eq!(CanonicalFeature::Ttt.cargo_name(), "ttt");
        assert_eq!(CanonicalFeature::SelfTuning.cargo_name(), "self_tuning");
        assert_eq!(CanonicalFeature::Vault.cargo_name(), "vault");
        assert_eq!(CanonicalFeature::Hermes.cargo_name(), "hermes");
        assert_eq!(CanonicalFeature::Bench.cargo_name(), "bench");
    }

    #[test]
    fn cargo_names_are_all_distinct() {
        let names: std::collections::HashSet<&'static str> =
            NINE_FEATURES.iter().map(|f| f.cargo_name()).collect();
        assert_eq!(names.len(), 9);
    }

    #[test]
    fn canonical_feature_serializes_in_snake_case() {
        for (f, expected) in [
            (CanonicalFeature::Metal, "\"metal\""),
            (CanonicalFeature::Mlx, "\"mlx\""),
            (CanonicalFeature::Ane, "\"ane\""),
            (CanonicalFeature::Ssm, "\"ssm\""),
            (CanonicalFeature::Ttt, "\"ttt\""),
            (CanonicalFeature::SelfTuning, "\"self_tuning\""),
            (CanonicalFeature::Vault, "\"vault\""),
            (CanonicalFeature::Hermes, "\"hermes\""),
            (CanonicalFeature::Bench, "\"bench\""),
        ] {
            assert_eq!(serde_json::to_string(&f).unwrap(), expected);
        }
    }

    #[test]
    fn canonical_feature_round_trips_through_json() {
        for f in NINE_FEATURES {
            let json = serde_json::to_string(&f).unwrap();
            let parsed: CanonicalFeature = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, f);
        }
    }

    #[test]
    fn default_experimental_pro_only_classifications_are_disjoint() {
        // No feature is in more than one classification.
        for f in NINE_FEATURES {
            let count = [f.is_default(), f.is_experimental(), f.is_pro_only()]
                .iter()
                .filter(|&&b| b)
                .count();
            assert!(count <= 1, "{:?} fits more than one classification", f);
        }
    }
}
