//! HELIOS V5 PCF-4 — ComponentRoute (deferred until PCF-1 verified).

use serde::{Deserialize, Serialize};

/// Route inference through a chosen component subset. **Deferred**
/// until PCF-1 ParamAnchor library verifies on M2 Max — until then
/// this type is a frozen schema with no behavior.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct ComponentRoute {
    pub route_id: String,
    /// Ordered sequence of component clusters this route activates.
    pub component_path: Vec<u32>,
}

impl ComponentRoute {
    pub fn new(route_id: String) -> Self {
        Self {
            route_id,
            component_path: Vec::new(),
        }
    }

    pub fn extend(&mut self, component_id: u32) {
        self.component_path.push(component_id);
    }

    pub fn len(&self) -> usize {
        self.component_path.len()
    }

    pub fn is_empty(&self) -> bool {
        self.component_path.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_route_constructed_with_id() {
        let r = ComponentRoute::new("r1".to_string());
        assert!(r.is_empty());
    }

    #[test]
    fn extend_grows_path() {
        let mut r = ComponentRoute::new("r1".to_string());
        r.extend(10);
        r.extend(20);
        assert_eq!(r.len(), 2);
        assert_eq!(r.component_path, vec![10, 20]);
    }
}
