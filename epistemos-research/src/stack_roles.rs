//! HELIOS V5 — Mac-native stack roles + canonical reference
//! checkpoints (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-STACK-ROLES guard
//!
//! Per HELIOS v4 preservation `source_docs/helios_v2.md` §"Rust,
//! MLX, Metal, and the role of microgpt-c":
//!
//! > "Rust should be the **spine** of Helios: lifecycle, paging,
//! >  invariants, telemetry, and type-safe tier transitions. MLX
//! >  should be the **tensor/runtime hand**: model loading, graph
//! >  execution, autograd where needed, and custom-kernel dispatch.
//! >  Metal should be the **nerve endings**: the exact kernels where
//! >  page scoring, residual packing, or fused attention become
//! >  bandwidth-sensitive enough that you need JIT'd MSL."
//!
//! ## Reference checkpoint pinning
//!
//! Per the v2 consensus: "The most realistic benchmark pair
//! available today is an MLX Qwen3 checkpoint from the Alibaba
//! ecosystem on the transformer side and the
//! `cartesia-ai/mamba2-2.7b-4bit-mlx` checkpoint on the SSM side."
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// One of three canonical stack roles per the spine/hand/nerves
/// metaphor.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum StackRole {
    /// Rust — the spine. Lifecycle, paging, invariants, telemetry,
    /// type-safe tier transitions.
    RustSpine,
    /// MLX — the tensor/runtime hand. Model loading, graph
    /// execution, autograd where needed, custom-kernel dispatch.
    MlxHand,
    /// Metal — the nerve endings. JIT'd MSL kernels for page
    /// scoring, residual packing, fused attention.
    MetalNerves,
}

impl StackRole {
    /// Canonical responsibility list per role.
    pub fn responsibility(self) -> &'static str {
        match self {
            StackRole::RustSpine => {
                "lifecycle / paging / invariants / telemetry / type-safe tier transitions"
            }
            StackRole::MlxHand => {
                "model loading / graph execution / autograd / custom-kernel dispatch"
            }
            StackRole::MetalNerves => {
                "page scoring / residual packing / fused attention (JIT'd MSL)"
            }
        }
    }

    /// Returns true when this role is bandwidth-sensitive (i.e. the
    /// substrate where micro-optimization matters most).
    pub fn is_bandwidth_critical(self) -> bool {
        matches!(self, StackRole::MetalNerves)
    }
}

/// All three stack roles in canonical anatomical order
/// (spine → hand → nerves).
pub const ALL_ROLES: [StackRole; 3] = [
    StackRole::RustSpine,
    StackRole::MlxHand,
    StackRole::MetalNerves,
];

/// One of two canonical model-architecture tracks for
/// cross-architecture validation per HELIOS v2.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ArchitectureTrack {
    /// Transformer track (softmax attention).
    Transformer,
    /// State-space (SSM) track (Mamba / Mamba-2 / RWKV).
    StateSpaceModel,
}

/// Reference benchmark checkpoint per architecture track per
/// helios_v2 §"Rust, MLX, Metal".
///
/// Only `Serialize` is derived: the struct holds `&'static str`
/// references to the binary's const pool. Deserialize is omitted
/// because round-tripping into `&'static str` requires owning the
/// strings.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct ReferenceCheckpoint {
    /// HuggingFace repo id (e.g. "Qwen/Qwen3-8B-MLX-4bit").
    pub hf_repo: &'static str,
    /// Architecture track this checkpoint exemplifies.
    pub track: ArchitectureTrack,
    /// Approximate model size in billions of parameters.
    pub size_b: f32,
    /// Quantization label (e.g. "MLX-4bit", "4bit-mlx").
    pub quantization: &'static str,
}

impl ReferenceCheckpoint {
    /// Canonical transformer-track reference: Qwen3-8B at 4-bit MLX.
    pub const TRANSFORMER_REFERENCE: ReferenceCheckpoint = ReferenceCheckpoint {
        hf_repo: "Qwen/Qwen3-8B-MLX-4bit",
        track: ArchitectureTrack::Transformer,
        size_b: 8.0,
        quantization: "MLX-4bit",
    };

    /// Canonical SSM-track reference: Mamba-2 2.7B at 4-bit MLX
    /// from cartesia-ai.
    pub const SSM_REFERENCE: ReferenceCheckpoint = ReferenceCheckpoint {
        hf_repo: "cartesia-ai/mamba2-2.7b-4bit-mlx",
        track: ArchitectureTrack::StateSpaceModel,
        size_b: 2.7,
        quantization: "4bit-mlx",
    };
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn three_stack_roles_in_anatomical_order() {
        assert_eq!(ALL_ROLES.len(), 3);
        assert_eq!(ALL_ROLES[0], StackRole::RustSpine);
        assert_eq!(ALL_ROLES[1], StackRole::MlxHand);
        assert_eq!(ALL_ROLES[2], StackRole::MetalNerves);
    }

    #[test]
    fn three_stack_roles_are_distinct() {
        let set: std::collections::HashSet<StackRole> = ALL_ROLES.iter().copied().collect();
        assert_eq!(set.len(), 3);
    }

    #[test]
    fn each_role_has_a_responsibility_description() {
        for role in ALL_ROLES {
            assert!(!role.responsibility().is_empty());
        }
    }

    #[test]
    fn only_metal_nerves_is_bandwidth_critical() {
        for role in ALL_ROLES {
            if role == StackRole::MetalNerves {
                assert!(role.is_bandwidth_critical());
            } else {
                assert!(!role.is_bandwidth_critical());
            }
        }
    }

    #[test]
    fn transformer_reference_is_qwen3_8b() {
        let r = ReferenceCheckpoint::TRANSFORMER_REFERENCE;
        assert_eq!(r.hf_repo, "Qwen/Qwen3-8B-MLX-4bit");
        assert_eq!(r.track, ArchitectureTrack::Transformer);
        assert_eq!(r.size_b, 8.0);
        assert_eq!(r.quantization, "MLX-4bit");
    }

    #[test]
    fn ssm_reference_is_mamba2_2_7b() {
        let r = ReferenceCheckpoint::SSM_REFERENCE;
        assert_eq!(r.hf_repo, "cartesia-ai/mamba2-2.7b-4bit-mlx");
        assert_eq!(r.track, ArchitectureTrack::StateSpaceModel);
        assert_eq!(r.size_b, 2.7);
    }

    #[test]
    fn two_reference_checkpoints_target_different_tracks() {
        // Cross-architecture validation requires distinct tracks.
        assert_ne!(
            ReferenceCheckpoint::TRANSFORMER_REFERENCE.track,
            ReferenceCheckpoint::SSM_REFERENCE.track
        );
    }

    #[test]
    fn stack_role_serializes_in_snake_case() {
        for (role, expected) in [
            (StackRole::RustSpine, "\"rust_spine\""),
            (StackRole::MlxHand, "\"mlx_hand\""),
            (StackRole::MetalNerves, "\"metal_nerves\""),
        ] {
            assert_eq!(serde_json::to_string(&role).unwrap(), expected);
        }
    }

    #[test]
    fn architecture_track_serializes_in_snake_case() {
        assert_eq!(
            serde_json::to_string(&ArchitectureTrack::Transformer).unwrap(),
            "\"transformer\""
        );
        assert_eq!(
            serde_json::to_string(&ArchitectureTrack::StateSpaceModel).unwrap(),
            "\"state_space_model\""
        );
    }

    #[test]
    fn round_trips_through_json() {
        for role in ALL_ROLES {
            let json = serde_json::to_string(&role).unwrap();
            let parsed: StackRole = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, role);
        }
        for track in [ArchitectureTrack::Transformer, ArchitectureTrack::StateSpaceModel] {
            let json = serde_json::to_string(&track).unwrap();
            let parsed: ArchitectureTrack = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, track);
        }
    }

    #[test]
    fn reference_checkpoint_serializes_with_canonical_repos() {
        let json = serde_json::to_string(&ReferenceCheckpoint::TRANSFORMER_REFERENCE).unwrap();
        assert!(json.contains("Qwen/Qwen3-8B-MLX-4bit"));
        let json = serde_json::to_string(&ReferenceCheckpoint::SSM_REFERENCE).unwrap();
        assert!(json.contains("cartesia-ai/mamba2-2.7b-4bit-mlx"));
    }
}
