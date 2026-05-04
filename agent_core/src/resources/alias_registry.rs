use std::collections::{HashMap, HashSet};
use std::sync::OnceLock;

use super::id::ResourceId;

/// Registry mapping legacy / alternate identifier strings to their
/// canonical [`ResourceId`] form. Seeded at construction time; internal
/// HashMaps are `&self`-accessible (read-only after seeding).
///
/// Phase R.2 in `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` + authoritative
/// spec in `docs/RESOURCE_RUNTIME_RESEARCH.md` §1. Fixes the I-001 bug
/// class documented in `docs/KNOWN_ISSUES_REGISTER.md` ("gpt-5.4" vs
/// "openai:gpt-5.4" split-brain).
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

// -- Default registry (seeded with known model-ID aliases) --------------

/// Global, lazily-initialized [`AliasRegistry`] pre-populated with the
/// known canonical-form + alternate-form model IDs present in the
/// Epistemos codebase. Used by the UniFFI-exposed canonicalization
/// helpers below so Swift clients can route through a single source of
/// truth without having to hold a Rust handle.
///
/// To register additional aliases from a runtime context (tests, feature
/// flags, etc.), use [`AliasRegistry::register`] on a local instance —
/// this global is intentionally static once initialized.
static DEFAULT_REGISTRY: OnceLock<AliasRegistry> = OnceLock::new();

fn default_registry() -> &'static AliasRegistry {
    DEFAULT_REGISTRY.get_or_init(build_default_registry)
}

fn build_default_registry() -> AliasRegistry {
    let mut registry = AliasRegistry::new();

    // OpenAI — current generation. The `gpt-5.4` vs `openai:gpt-5.4`
    // split-brain is I-001. Additional underscore variant observed in
    // some filename-safe contexts.
    registry.register_all(
        ["gpt-5.4", "openai:gpt-5.4", "gpt_5_4"],
        ResourceId::Model {
            provider: "openai".into(),
            model_id: "gpt-5.4".into(),
        },
    );
    registry.register_all(
        ["gpt-5.3", "openai:gpt-5.3", "gpt_5_3"],
        ResourceId::Model {
            provider: "openai".into(),
            model_id: "gpt-5.3".into(),
        },
    );
    registry.register_all(
        ["o4-mini", "openai:o4-mini", "o4_mini"],
        ResourceId::Model {
            provider: "openai".into(),
            model_id: "o4-mini".into(),
        },
    );

    // Anthropic — current generation. The `claude-sonnet-4-6` family has
    // the same split-brain risk.
    registry.register_all(
        [
            "claude-sonnet-4-6",
            "anthropic:claude-sonnet-4-6",
            "claude_sonnet_4_6",
        ],
        ResourceId::Model {
            provider: "anthropic".into(),
            model_id: "claude-sonnet-4-6".into(),
        },
    );
    registry.register_all(
        [
            "claude-opus-4-6",
            "anthropic:claude-opus-4-6",
            "claude_opus_4_6",
        ],
        ResourceId::Model {
            provider: "anthropic".into(),
            model_id: "claude-opus-4-6".into(),
        },
    );
    registry.register_all(
        [
            "claude-haiku-4-5",
            "anthropic:claude-haiku-4-5",
            "claude_haiku_4_5",
        ],
        ResourceId::Model {
            provider: "anthropic".into(),
            model_id: "claude-haiku-4-5".into(),
        },
    );

    // Google Gemini.
    registry.register_all(
        ["gemini-3-pro", "google:gemini-3-pro", "gemini_3_pro"],
        ResourceId::Model {
            provider: "google".into(),
            model_id: "gemini-3-pro".into(),
        },
    );
    registry.register_all(
        ["gemini-3-flash", "google:gemini-3-flash", "gemini_3_flash"],
        ResourceId::Model {
            provider: "google".into(),
            model_id: "gemini-3-flash".into(),
        },
    );

    // Perplexity.
    registry.register_all(
        [
            "perplexity-sonar-pro",
            "perplexity:sonar-pro",
            "perplexity_sonar_pro",
        ],
        ResourceId::Model {
            provider: "perplexity".into(),
            model_id: "sonar-pro".into(),
        },
    );

    // Local models — Qwen family (4-bit MLX quantizations).
    registry.register_all(
        [
            "qwen3-4b",
            "qwen:qwen3-4b",
            "qwen_3_4b",
            "Qwen3-4B-MLX-4bit",
        ],
        ResourceId::Model {
            provider: "qwen".into(),
            model_id: "qwen3-4b".into(),
        },
    );
    registry.register_all(
        [
            "qwen3-8b",
            "qwen:qwen3-8b",
            "qwen_3_8b",
            "Qwen3-8B-MLX-4bit",
        ],
        ResourceId::Model {
            provider: "qwen".into(),
            model_id: "qwen3-8b".into(),
        },
    );
    registry.register_all(
        [
            "qwen3.5-4b",
            "qwen:qwen3.5-4b",
            "qwen_3_5_4b",
            "Qwen3.5-4B-MLX-4bit",
        ],
        ResourceId::Model {
            provider: "qwen".into(),
            model_id: "qwen3.5-4b".into(),
        },
    );

    // Hermes family (NousResearch).
    registry.register_all(
        ["hermes-3", "nousresearch:hermes-3", "hermes_3"],
        ResourceId::Model {
            provider: "nousresearch".into(),
            model_id: "hermes-3".into(),
        },
    );

    registry
}

// -- UniFFI-exposed canonicalization helpers ----------------------------

/// Return the canonical identifier string (`"provider:model_id"`) for a
/// given model alias. Returns `None` if the alias is not registered —
/// Swift callers should treat `None` as "keep the input as-is".
///
/// This is the fix site for I-001 write-edge drift (see `docs/
/// AUDIT_REFLECTION_2026_04_23.md` §4). Call at the point where a
/// model identifier is about to be persisted (e.g.
/// `ChatCoordinator.swift` L4424 `authoredByModelID = authorship.modelID`)
/// to guarantee new records are canonical.
#[uniffi::export]
pub fn canonical_model_id(alias: String) -> Option<String> {
    default_registry().resolve(&alias).and_then(|id| match id {
        ResourceId::Model { provider, model_id } => Some(format!("{provider}:{model_id}")),
        _ => None,
    })
}

/// Given a model identifier in ANY known format (canonical or alias),
/// return every known equivalent identifier string for the same
/// underlying model, INCLUDING the input. If the alias is unregistered,
/// returns `vec![alias]` unchanged so callers can treat this as a
/// safe no-op expansion.
///
/// This is the fix site for I-001 read-edge drift. Used by
/// `ModelInvolvementSheet.loadContributions` to expand the filter set
/// before fetching `SDMessage` records, so `authoredByModelID == "gpt-5.4"`
/// AND `authoredByModelID == "openai:gpt-5.4"` both return the correct
/// chat history.
///
/// Output is sorted + deduplicated for deterministic iteration.
#[uniffi::export]
pub fn expand_model_aliases(alias: String) -> Vec<String> {
    let registry = default_registry();
    match registry.resolve(&alias) {
        Some(canonical) => {
            let mut set: HashSet<String> = registry.aliases_for(&canonical).into_iter().collect();
            set.insert(alias);
            let mut out: Vec<String> = set.into_iter().collect();
            out.sort();
            out
        }
        None => vec![alias],
    }
}

// -- Tests --------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::{build_default_registry, canonical_model_id, expand_model_aliases, AliasRegistry};
    use crate::resources::id::ResourceId;

    #[test]
    fn alias_registry_resolves_all_known_legacy_ids() {
        let canonical = ResourceId::Model {
            provider: "openai".into(),
            model_id: "gpt-5.4".into(),
        };

        let mut registry = AliasRegistry::new();
        registry.register_all(["gpt-5.4", "openai:gpt-5.4", "gpt_5_4"], canonical.clone());

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

    #[test]
    fn default_registry_includes_all_known_provider_families() {
        let reg = build_default_registry();
        // Each provider family should resolve at least one representative.
        assert!(reg.resolve("gpt-5.4").is_some());
        assert!(reg.resolve("claude-sonnet-4-6").is_some());
        assert!(reg.resolve("gemini-3-pro").is_some());
        assert!(reg.resolve("perplexity-sonar-pro").is_some());
        assert!(reg.resolve("qwen3-4b").is_some());
        assert!(reg.resolve("hermes-3").is_some());
    }

    #[test]
    fn canonical_model_id_normalizes_gpt_5_4_split_brain() {
        // The headline I-001 case: both forms canonicalize identically.
        assert_eq!(
            canonical_model_id("gpt-5.4".into()),
            Some("openai:gpt-5.4".to_string())
        );
        assert_eq!(
            canonical_model_id("openai:gpt-5.4".into()),
            Some("openai:gpt-5.4".to_string())
        );
        assert_eq!(
            canonical_model_id("gpt_5_4".into()),
            Some("openai:gpt-5.4".to_string())
        );
    }

    #[test]
    fn canonical_model_id_returns_none_for_unknown() {
        assert_eq!(canonical_model_id("totally-made-up-model".into()), None);
    }

    #[test]
    fn expand_model_aliases_fans_out_for_known_alias() {
        let expanded = expand_model_aliases("gpt-5.4".into());
        // Must include all three registered forms, sorted.
        assert_eq!(
            expanded,
            vec![
                "gpt-5.4".to_string(),
                "gpt_5_4".to_string(),
                "openai:gpt-5.4".to_string(),
            ]
        );
    }

    #[test]
    fn expand_model_aliases_fans_out_when_queried_by_any_alias() {
        // Query by ANY alias — still get the full set.
        let via_prefixed = expand_model_aliases("openai:gpt-5.4".into());
        let via_plain = expand_model_aliases("gpt-5.4".into());
        let via_underscore = expand_model_aliases("gpt_5_4".into());
        assert_eq!(via_prefixed, via_plain);
        assert_eq!(via_plain, via_underscore);
    }

    #[test]
    fn expand_model_aliases_preserves_input_for_unknown() {
        // Unknown aliases must round-trip unchanged — the fetch should
        // still work (albeit only for that exact stored string).
        let out = expand_model_aliases("future-model-v99".into());
        assert_eq!(out, vec!["future-model-v99".to_string()]);
    }

    #[test]
    fn expand_model_aliases_always_includes_input_even_when_unregistered() {
        // Safety net: a random alias must always come back in the output
        // so callers can unconditionally `contains(input)`.
        let out = expand_model_aliases("xyzzy".into());
        assert!(out.contains(&"xyzzy".to_string()));
    }
}
