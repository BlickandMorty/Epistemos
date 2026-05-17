//! Source:
//! - `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.26 (KV
//!   implantation + Glass Pipe + weight surgery) + §3.36 (SAE
//!   Cognition Observatory).
//! - `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md`
//!   — "Read-only probes are always safe; intervention probes need
//!   explicit user-tier authorization. The runtime MUST distinguish."
//! - Companions: [`super::kv_implant`], [`super::glass_pipe`],
//!   [`super::weight_patcher`], [`super::sae`].
//!
//! # Wave J2 — Cognition Observatory pipeline envelope
//!
//! Each of the 4 observatory primitives already ships its substrate
//! kernel. This file is the typed envelope that classifies each probe
//! as `ReadOnly` (introspection) or `Intervention` (mutates inference
//! state) so a runtime dispatcher can apply the right authorization
//! before executing.
//!
//! ## Probe taxonomy
//!
//! | Probe              | Class        | What it touches                           |
//! |--------------------|--------------|-------------------------------------------|
//! | KvImplant          | Intervention | restores a captured KV snapshot           |
//! | GlassPipe          | ReadOnly     | intercepts activations into a ring buffer |
//! | WeightPatch        | Intervention | overwrites projection-matrix entries      |
//! | Sae                | ReadOnly     | evaluates residual stream against AUC bar |
//!
//! ## Authorization rule
//!
//! - `ReadOnly` probes pass without explicit user grant (instrumentation
//!   floor; the user already trusts the model with the prompt).
//! - `Intervention` probes require an explicit `IntervenerCapability`
//!   to be present. The substrate-floor capability is a simple
//!   flag-bag; production replaces with the macaroon-based capability
//!   token from `crate::cognitive_dag::macaroons`.

use serde::{Deserialize, Serialize};

/// 4 probe kinds — one per cognition_observatory sub-module.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ProbeKind {
    KvImplant,
    GlassPipe,
    WeightPatch,
    Sae,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ProbeClass {
    /// Pure introspection — no inference-state mutation.
    ReadOnly,
    /// Mutates KV cache, activations, or weights mid-flight.
    Intervention,
}

impl ProbeKind {
    pub const ALL: [ProbeKind; 4] = [
        ProbeKind::KvImplant,
        ProbeKind::GlassPipe,
        ProbeKind::WeightPatch,
        ProbeKind::Sae,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            ProbeKind::KvImplant => "kv_implant",
            ProbeKind::GlassPipe => "glass_pipe",
            ProbeKind::WeightPatch => "weight_patch",
            ProbeKind::Sae => "sae",
        }
    }

    pub const fn class(self) -> ProbeClass {
        match self {
            ProbeKind::KvImplant => ProbeClass::Intervention,
            ProbeKind::GlassPipe => ProbeClass::ReadOnly,
            ProbeKind::WeightPatch => ProbeClass::Intervention,
            ProbeKind::Sae => ProbeClass::ReadOnly,
        }
    }

    pub const fn is_intervention(self) -> bool {
        matches!(self.class(), ProbeClass::Intervention)
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|p| p.code() == code)
    }

    /// Complement to [`Self::is_intervention`]. Cross-surface
    /// invariant: `is_intervention XOR is_read_only` partitions
    /// every ProbeKind.
    pub const fn is_read_only(self) -> bool {
        matches!(self.class(), ProbeClass::ReadOnly)
    }
}

impl ProbeClass {
    pub const ALL: [ProbeClass; 2] = [ProbeClass::ReadOnly, ProbeClass::Intervention];

    pub const fn code(self) -> &'static str {
        match self {
            ProbeClass::ReadOnly => "read_only",
            ProbeClass::Intervention => "intervention",
        }
    }

    /// Reverse lookup for [`Self::code`].
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|c| c.code() == code)
    }

    pub const fn is_read_only(self) -> bool {
        matches!(self, ProbeClass::ReadOnly)
    }

    /// Cross-surface invariant: `is_read_only XOR is_intervention`
    /// partitions every ProbeClass.
    pub const fn is_intervention(self) -> bool {
        matches!(self, ProbeClass::Intervention)
    }
}

/// Substrate-floor capability token. Production replaces with the
/// macaroon-based capability from `crate::cognitive_dag::macaroons`,
/// but the typed surface here is what dispatch code links against.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Default, Serialize, Deserialize)]
pub struct IntervenerCapability {
    pub may_intervene_kv: bool,
    pub may_intervene_weights: bool,
}

impl IntervenerCapability {
    pub const fn none() -> Self {
        Self { may_intervene_kv: false, may_intervene_weights: false }
    }

    pub const fn all() -> Self {
        Self { may_intervene_kv: true, may_intervene_weights: true }
    }

    pub const fn permits(&self, probe: ProbeKind) -> bool {
        match probe {
            ProbeKind::KvImplant => self.may_intervene_kv,
            ProbeKind::WeightPatch => self.may_intervene_weights,
            ProbeKind::GlassPipe | ProbeKind::Sae => true,
        }
    }

    /// Number of intervention bits set (0, 1, or 2). Cross-surface
    /// invariant: equals 2 iff `*self == Self::all()`; equals 0 iff
    /// `*self == Self::none()`.
    pub const fn permits_count(&self) -> u8 {
        (self.may_intervene_kv as u8) + (self.may_intervene_weights as u8)
    }
}

impl DispatchError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            DispatchError::InterventionRequiresCapability { .. } => {
                "intervention_requires_capability"
            }
        }
    }

    /// Probe that triggered the dispatch failure.
    pub const fn probe(&self) -> ProbeKind {
        match self {
            DispatchError::InterventionRequiresCapability { probe } => *probe,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum DispatchError {
    InterventionRequiresCapability { probe: ProbeKind },
}

/// Validate a probe dispatch against the caller's capability set.
/// ReadOnly probes always pass; Intervention probes require the
/// matching capability bit.
pub fn validate_dispatch(
    probe: ProbeKind,
    capability: &IntervenerCapability,
) -> Result<(), DispatchError> {
    if probe.is_intervention() && !capability.permits(probe) {
        return Err(DispatchError::InterventionRequiresCapability { probe });
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn four_distinct_probes() {
        let s: std::collections::HashSet<_> = ProbeKind::ALL.iter().copied().collect();
        assert_eq!(s.len(), 4);
    }

    #[test]
    fn class_partition_two_two() {
        let intervention: Vec<_> =
            ProbeKind::ALL.iter().filter(|p| p.is_intervention()).copied().collect();
        let read_only: Vec<_> =
            ProbeKind::ALL.iter().filter(|p| !p.is_intervention()).copied().collect();
        assert_eq!(intervention.len(), 2);
        assert_eq!(read_only.len(), 2);
        assert!(intervention.contains(&ProbeKind::KvImplant));
        assert!(intervention.contains(&ProbeKind::WeightPatch));
        assert!(read_only.contains(&ProbeKind::GlassPipe));
        assert!(read_only.contains(&ProbeKind::Sae));
    }

    #[test]
    fn probe_codes_unique() {
        let mut s = std::collections::HashSet::new();
        for p in ProbeKind::ALL.iter() {
            assert!(s.insert(p.code()));
        }
    }

    #[test]
    fn read_only_probes_always_pass() {
        let cap = IntervenerCapability::none();
        assert!(validate_dispatch(ProbeKind::GlassPipe, &cap).is_ok());
        assert!(validate_dispatch(ProbeKind::Sae, &cap).is_ok());
    }

    #[test]
    fn intervention_without_capability_rejected() {
        let cap = IntervenerCapability::none();
        assert_eq!(
            validate_dispatch(ProbeKind::KvImplant, &cap).unwrap_err(),
            DispatchError::InterventionRequiresCapability { probe: ProbeKind::KvImplant }
        );
        assert_eq!(
            validate_dispatch(ProbeKind::WeightPatch, &cap).unwrap_err(),
            DispatchError::InterventionRequiresCapability { probe: ProbeKind::WeightPatch }
        );
    }

    #[test]
    fn kv_capability_does_not_grant_weight_capability() {
        let cap = IntervenerCapability { may_intervene_kv: true, may_intervene_weights: false };
        assert!(validate_dispatch(ProbeKind::KvImplant, &cap).is_ok());
        assert!(validate_dispatch(ProbeKind::WeightPatch, &cap).is_err());
    }

    #[test]
    fn weight_capability_does_not_grant_kv_capability() {
        let cap = IntervenerCapability { may_intervene_kv: false, may_intervene_weights: true };
        assert!(validate_dispatch(ProbeKind::WeightPatch, &cap).is_ok());
        assert!(validate_dispatch(ProbeKind::KvImplant, &cap).is_err());
    }

    #[test]
    fn all_capability_permits_everything() {
        let cap = IntervenerCapability::all();
        for p in ProbeKind::ALL.iter() {
            assert!(validate_dispatch(*p, &cap).is_ok());
        }
    }

    #[test]
    fn none_capability_is_default() {
        assert_eq!(IntervenerCapability::default(), IntervenerCapability::none());
    }

    #[test]
    fn probe_serde_roundtrip() {
        let p = ProbeKind::WeightPatch;
        let json = serde_json::to_string(&p).unwrap();
        let back: ProbeKind = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }

    #[test]
    fn capability_serde_roundtrip() {
        let cap = IntervenerCapability { may_intervene_kv: true, may_intervene_weights: false };
        let json = serde_json::to_string(&cap).unwrap();
        let back: IntervenerCapability = serde_json::from_str(&json).unwrap();
        assert_eq!(cap, back);
    }

    #[test]
    fn class_serde_roundtrip() {
        let c = ProbeClass::Intervention;
        let json = serde_json::to_string(&c).unwrap();
        let back: ProbeClass = serde_json::from_str(&json).unwrap();
        assert_eq!(c, back);
    }

    // ── diagnostic surface (iter 179) ────────────────────────────────────────

    #[test]
    fn probe_from_code_roundtrips_all() {
        for p in ProbeKind::ALL.iter().copied() {
            assert_eq!(ProbeKind::from_code(p.code()), Some(p));
        }
        assert_eq!(ProbeKind::from_code("KvImplant"), None);
        assert_eq!(ProbeKind::from_code(""), None);
    }

    #[test]
    fn probe_read_only_xor_intervention_partition() {
        // Cross-surface invariant: is_read_only XOR is_intervention
        // over every ProbeKind.
        for p in ProbeKind::ALL.iter().copied() {
            assert_ne!(p.is_read_only(), p.is_intervention());
        }
    }

    #[test]
    fn probe_class_consistent_with_predicates() {
        // Cross-surface: is_intervention == (class == Intervention).
        for p in ProbeKind::ALL.iter().copied() {
            assert_eq!(p.is_intervention(), p.class() == ProbeClass::Intervention);
            assert_eq!(p.is_read_only(), p.class() == ProbeClass::ReadOnly);
        }
    }

    #[test]
    fn class_from_code_roundtrips() {
        for c in ProbeClass::ALL.iter().copied() {
            assert_eq!(ProbeClass::from_code(c.code()), Some(c));
        }
        assert_eq!(ProbeClass::from_code("ReadOnly"), None);
    }

    #[test]
    fn class_classifiers_partition() {
        // Cross-surface invariant: is_read_only XOR is_intervention.
        for c in ProbeClass::ALL.iter().copied() {
            assert_ne!(c.is_read_only(), c.is_intervention());
        }
    }

    #[test]
    fn capability_permits_count_zero_for_none() {
        assert_eq!(IntervenerCapability::none().permits_count(), 0);
    }

    #[test]
    fn capability_permits_count_two_for_all() {
        assert_eq!(IntervenerCapability::all().permits_count(), 2);
    }

    #[test]
    fn capability_permits_count_one_for_partial() {
        let cap = IntervenerCapability { may_intervene_kv: true, may_intervene_weights: false };
        assert_eq!(cap.permits_count(), 1);
    }

    #[test]
    fn dispatch_error_cause_and_probe_extract() {
        let e = DispatchError::InterventionRequiresCapability { probe: ProbeKind::WeightPatch };
        assert_eq!(e.cause(), "intervention_requires_capability");
        assert_eq!(e.probe(), ProbeKind::WeightPatch);
    }

    #[test]
    fn dispatch_error_probe_aligned_with_validate_input() {
        // Cross-surface: validate_dispatch-returned error carries the
        // probe it was called with.
        let cap = IntervenerCapability::none();
        for p in [ProbeKind::KvImplant, ProbeKind::WeightPatch] {
            let err = validate_dispatch(p, &cap).unwrap_err();
            assert_eq!(err.probe(), p);
        }
    }
}
