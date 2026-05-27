//! O(1)-target ACS (Anchored Cognitive Substrate) anchor registry.

use std::collections::HashMap;

use crate::uas::{AcsAnchor, AcsAnchorPlaneProjection};

// UAS: uas/acs-anchor-registry/<anchor_id>
// Plane: RuntimePlane::Episodic
// Residency: ResidencyTier::VerifiedFloor
/// Lookup registry for ACS anchor references carried by UAS objects.
#[derive(Clone, Debug, Default)]
pub struct AcsAnchorRegistry {
    anchors: HashMap<String, AcsAnchor>,
}

impl AcsAnchorRegistry {
    pub fn with_capacity(capacity: usize) -> Self {
        Self {
            anchors: HashMap::with_capacity(capacity),
        }
    }

    pub fn insert(&mut self, anchor: AcsAnchor) -> Option<AcsAnchor> {
        self.anchors.insert(anchor.anchor_id.clone(), anchor)
    }

    pub fn lookup(&self, anchor_id: &str) -> Option<&AcsAnchor> {
        self.anchors.get(anchor_id)
    }

    pub fn lookup_via_projection(
        &self,
        projection: AcsAnchorPlaneProjection<'_>,
    ) -> Option<&AcsAnchor> {
        let anchor = self.lookup(projection.anchor_id)?;
        (anchor.project_to_plane() == projection).then_some(anchor)
    }

    pub fn len(&self) -> usize {
        self.anchors.len()
    }

    pub fn is_empty(&self) -> bool {
        self.anchors.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::{ResidencyTier, RuntimePlane};

    #[test]
    fn lookup_returns_inserted_anchor() {
        let mut registry = AcsAnchorRegistry::with_capacity(1);
        let mut anchor = AcsAnchor::new(
            "claim-1",
            "E1",
            RuntimePlane::Episodic,
            ResidencyTier::VerifiedFloor,
            0.8,
        );
        anchor.source_hash = Some("blake3:abc".to_string());
        registry.insert(anchor.clone());
        assert_eq!(registry.lookup("claim-1"), Some(&anchor));
        assert_eq!(
            registry.lookup_via_projection(anchor.project_to_plane()),
            Some(&anchor)
        );
        assert!(registry.lookup("missing").is_none());
    }

    #[test]
    fn projection_lookup_rejects_silent_field_loss() {
        let mut registry = AcsAnchorRegistry::with_capacity(1);
        let mut anchor = AcsAnchor::new(
            "claim-1",
            "E1",
            RuntimePlane::Episodic,
            ResidencyTier::VerifiedFloor,
            0.8,
        );
        anchor.source_hash = Some("blake3:abc".to_string());
        let mut projection_source = anchor.clone();
        projection_source.source_hash = Some("blake3:changed".to_string());
        registry.insert(anchor);

        assert!(registry
            .lookup_via_projection(projection_source.project_to_plane())
            .is_none());
    }
}
