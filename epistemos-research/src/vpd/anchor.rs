//! HELIOS V5 W18 + PCF-1 — ParamAnchor library.
//!
//! HELIOS-W18 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §B:
//!
//! > "PCF-1 ParamAnchor (VPD extraction → frozen anchor library) —
//! >  Lane 3 [RESEARCH-ONLY] — Training-time decomposition; never
//! >  user-visible at runtime."

use serde::{Deserialize, Serialize};

use super::extract::ParamComponent;

/// One frozen ParamAnchor — a labeled cluster of components with
/// known semantic role. Anchors are produced by long-horizon VPD
/// extraction (offline) and then reused as canonical references for
/// downstream attribution.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ParamAnchor {
    pub anchor_id: String,
    pub label: String,
    pub component_ids: Vec<u32>,
    /// Salience score in [0, 1] — how strongly this anchor's
    /// components contribute on the corpus the extraction was run
    /// on.
    pub salience: f32,
}

/// Read-only library of anchors. Anchors are immutable once added —
/// retraining produces a new library, never mutates an existing one.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ParamAnchorLibrary {
    anchors: Vec<ParamAnchor>,
}

impl ParamAnchorLibrary {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add(&mut self, anchor: ParamAnchor) {
        self.anchors.push(anchor);
    }

    pub fn anchors(&self) -> &[ParamAnchor] {
        &self.anchors
    }

    pub fn len(&self) -> usize {
        self.anchors.len()
    }

    pub fn is_empty(&self) -> bool {
        self.anchors.is_empty()
    }

    /// Lookup anchor by id.
    pub fn get(&self, id: &str) -> Option<&ParamAnchor> {
        self.anchors.iter().find(|a| a.anchor_id == id)
    }

    /// Attach a fresh ParamComponent to the anchor that owns its
    /// component_id. No-op if the component_id isn't claimed by any
    /// anchor.
    pub fn attach_component(&self, _component: &ParamComponent) {
        // Library is read-only by design. Attachment lives in the
        // ParamAttributionGraph (PCF-3) which is the mutable
        // analytical surface.
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn library_starts_empty() {
        let lib = ParamAnchorLibrary::new();
        assert!(lib.is_empty());
        assert_eq!(lib.len(), 0);
    }

    #[test]
    fn library_round_trip_through_json() {
        let mut lib = ParamAnchorLibrary::new();
        lib.add(ParamAnchor {
            anchor_id: "anchor-syntax".to_string(),
            label: "syntactic role detection".to_string(),
            component_ids: vec![1, 2, 3],
            salience: 0.85,
        });
        let json = serde_json::to_string(&lib).unwrap();
        let parsed: ParamAnchorLibrary = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, lib);
    }

    #[test]
    fn lookup_by_id_finds_anchor() {
        let mut lib = ParamAnchorLibrary::new();
        lib.add(ParamAnchor {
            anchor_id: "a1".to_string(),
            label: "x".to_string(),
            component_ids: vec![],
            salience: 0.0,
        });
        assert!(lib.get("a1").is_some());
        assert!(lib.get("a2").is_none());
    }
}
