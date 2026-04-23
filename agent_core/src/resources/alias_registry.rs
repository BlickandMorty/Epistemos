use std::collections::{HashMap, HashSet};

use super::id::ResourceId;

#[derive(Debug, Clone, Default)]
pub struct AliasRegistry {
    by_alias: HashMap<String, ResourceId>,
    by_canonical: HashMap<ResourceId, HashSet<String>>,
}

impl AliasRegistry {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn resolve(&self, alias: &str) -> Option<ResourceId> {
        let normalized = normalize_alias(alias)?;
        self.by_alias.get(&normalized).cloned()
    }

    pub fn register(&mut self, alias: String, canonical: ResourceId) {
        let Some(normalized) = normalize_alias(&alias) else {
            return;
        };
        self.by_alias.insert(normalized.clone(), canonical.clone());
        self.by_canonical
            .entry(canonical)
            .or_default()
            .insert(normalized);
    }

    pub fn register_all<I>(&mut self, aliases: I, canonical: ResourceId)
    where
        I: IntoIterator,
        I::Item: Into<String>,
    {
        for alias in aliases {
            self.register(alias.into(), canonical.clone());
        }
    }

    pub fn aliases_for(&self, id: &ResourceId) -> Vec<String> {
        let mut aliases = self
            .by_canonical
            .get(id)
            .into_iter()
            .flat_map(|aliases| aliases.iter().cloned())
            .collect::<Vec<_>>();
        aliases.sort();
        aliases
    }
}

fn normalize_alias(alias: &str) -> Option<String> {
    let trimmed = alias.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::AliasRegistry;
    use crate::resources::id::ResourceId;

    #[test]
    fn alias_registry_resolves_all_known_legacy_ids() {
        let canonical = ResourceId::Model {
            provider: "openai".into(),
            model_id: "gpt-5.4".into(),
        };

        let mut registry = AliasRegistry::new();
        registry.register_all(
            ["gpt-5.4", "openai:gpt-5.4", "gpt_5_4"],
            canonical.clone(),
        );

        assert_eq!(registry.resolve("gpt-5.4"), Some(canonical.clone()));
        assert_eq!(registry.resolve("openai:gpt-5.4"), Some(canonical.clone()));
        assert_eq!(registry.resolve("gpt_5_4"), Some(canonical.clone()));
        assert_eq!(
            registry.aliases_for(&canonical),
            vec![
                "gpt-5.4".to_string(),
                "gpt_5_4".to_string(),
                "openai:gpt-5.4".to_string(),
            ]
        );
    }
}
