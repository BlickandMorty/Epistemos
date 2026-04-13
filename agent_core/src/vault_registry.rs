use std::collections::{HashMap, HashSet};
use std::path::PathBuf;

#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub enum VaultIdentity {
    Model(String),
    Agent(String),
    Team(Vec<String>),
    UseCase(String),
    Personal,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct MergedVaultView {
    pub ordered_entries: Vec<(VaultIdentity, PathBuf)>,
}

impl MergedVaultView {
    pub fn paths(&self) -> Vec<PathBuf> {
        self.ordered_entries
            .iter()
            .map(|(_, path)| path.clone())
            .collect()
    }
}

#[derive(Debug, Clone, Default)]
pub struct VaultRegistry {
    entries: HashMap<VaultIdentity, PathBuf>,
}

impl VaultRegistry {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn register(
        &mut self,
        identity: VaultIdentity,
        path: impl Into<PathBuf>,
    ) -> Option<PathBuf> {
        self.entries.insert(identity, path.into())
    }

    pub fn resolve(&self, identity: &VaultIdentity) -> Option<PathBuf> {
        self.entries.get(identity).cloned()
    }

    pub fn list(&self) -> Vec<(VaultIdentity, PathBuf)> {
        let mut entries = self
            .entries
            .iter()
            .map(|(identity, path)| (identity.clone(), path.clone()))
            .collect::<Vec<_>>();
        entries.sort_by(|left, right| {
            identity_priority(&left.0)
                .cmp(&identity_priority(&right.0))
                .then_with(|| identity_sort_key(&left.0).cmp(&identity_sort_key(&right.0)))
                .then_with(|| left.1.cmp(&right.1))
        });
        entries
    }

    pub fn merge_vaults(&self, identities: &[VaultIdentity]) -> MergedVaultView {
        let mut resolved = identities
            .iter()
            .filter_map(|identity| {
                self.resolve(identity)
                    .map(|path| (identity.clone(), path, identity_priority(identity)))
            })
            .collect::<Vec<_>>();
        resolved.sort_by(|left, right| {
            left.2
                .cmp(&right.2)
                .then_with(|| identity_sort_key(&left.0).cmp(&identity_sort_key(&right.0)))
                .then_with(|| left.1.cmp(&right.1))
        });

        let mut seen = HashSet::new();
        let ordered_entries = resolved
            .into_iter()
            .filter_map(|(identity, path, _)| {
                if seen.insert(path.clone()) {
                    Some((identity, path))
                } else {
                    None
                }
            })
            .collect();

        MergedVaultView { ordered_entries }
    }
}

fn identity_priority(identity: &VaultIdentity) -> usize {
    match identity {
        VaultIdentity::Agent(_) => 0,
        VaultIdentity::Team(_) => 1,
        VaultIdentity::Model(_) => 2,
        VaultIdentity::UseCase(_) => 3,
        VaultIdentity::Personal => 4,
    }
}

fn identity_sort_key(identity: &VaultIdentity) -> String {
    match identity {
        VaultIdentity::Model(name) => format!("model:{name}"),
        VaultIdentity::Agent(name) => format!("agent:{name}"),
        VaultIdentity::Team(names) => format!("team:{}", names.join(",")),
        VaultIdentity::UseCase(name) => format!("use-case:{name}"),
        VaultIdentity::Personal => "personal".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::{VaultIdentity, VaultRegistry};
    use std::path::PathBuf;

    #[test]
    fn vault_registry_registers_and_resolves_entries() {
        let mut registry = VaultRegistry::new();
        let personal = VaultIdentity::Personal;
        let path = PathBuf::from("/vaults/personal");

        registry.register(personal.clone(), path.clone());

        assert_eq!(registry.resolve(&personal), Some(path));
    }

    #[test]
    fn vault_registry_list_sorts_by_priority() {
        let mut registry = VaultRegistry::new();
        registry.register(VaultIdentity::Personal, "/vaults/personal");
        registry.register(
            VaultIdentity::Model("claude".into()),
            "/vaults/models/claude",
        );
        registry.register(
            VaultIdentity::Agent("research".into()),
            "/vaults/agents/research",
        );

        let identities = registry
            .list()
            .into_iter()
            .map(|(identity, _)| identity)
            .collect::<Vec<_>>();

        assert_eq!(
            identities,
            vec![
                VaultIdentity::Agent("research".into()),
                VaultIdentity::Model("claude".into()),
                VaultIdentity::Personal,
            ]
        );
    }

    #[test]
    fn merge_vaults_preserves_priority_and_deduplicates_paths() {
        let mut registry = VaultRegistry::new();
        registry.register(VaultIdentity::Personal, "/vaults/shared");
        registry.register(
            VaultIdentity::Model("claude".into()),
            "/vaults/models/claude",
        );
        registry.register(VaultIdentity::Agent("research".into()), "/vaults/shared");

        let merged = registry.merge_vaults(&[
            VaultIdentity::Personal,
            VaultIdentity::Model("claude".into()),
            VaultIdentity::Agent("research".into()),
        ]);

        assert_eq!(
            merged.paths(),
            vec![
                PathBuf::from("/vaults/shared"),
                PathBuf::from("/vaults/models/claude"),
            ]
        );
        assert_eq!(
            merged.ordered_entries[0].0,
            VaultIdentity::Agent("research".into())
        );
    }
}
