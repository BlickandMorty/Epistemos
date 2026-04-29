//! `.soul` — paired-file fusion for agent identity.
//!
//! Plan §2.3: `<name>.soul.json` (machine surface, schema-strict) +
//! `<name>.soul.md` (narrative surface, LLM-consumed system-prompt
//! context). The pair is bidirectionally linked:
//! - JSON side: `narrative_path` field points at the .md sibling.
//! - Markdown side: line-1 `---{json}---` frontmatter contains
//!   `{"soul_id": "<json.id>", "persona_version": "<json.version>"}`.
//!
//! At load time the two halves are validated against each other.
//! Orphans (one half missing or mismatch) are rejected loudly — never
//! silently fall back to a half-loaded soul.
//!
//! §24.4 user-soul (4-file directory: SOUL/STYLE/SKILL/MEMORY) is a
//! separate shape; its per-file schemas are not defined in the plan
//! and land in a follow-up commit.

use std::path::{Path, PathBuf};

use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

use super::{validate_against, FormatError};

pub const SOUL_V1_ID: &str = "epistemos://schemas/soul.v1.json";

#[derive(Serialize, Deserialize, JsonSchema, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "lowercase")]
pub enum ModelTier {
    Local,
    Cloud,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct ModelPick {
    pub tier: ModelTier,
    pub model: String,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq, Default)]
#[serde(deny_unknown_fields)]
pub struct ModelPreference {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub primary: Option<ModelPick>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fallback: Option<ModelPick>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub escalation: Option<ModelPick>,
}

impl ModelPreference {
    pub fn is_empty(&self) -> bool {
        self.primary.is_none() && self.fallback.is_none() && self.escalation.is_none()
    }
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct SoulManifest {
    #[serde(rename = "$schema")]
    pub schema: String,
    pub id: String,
    pub name: String,
    pub version: String, // semver
    pub narrative_path: String,
    #[serde(default, skip_serializing_if = "ModelPreference::is_empty")]
    pub model_preference: ModelPreference,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tool_whitelist: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tool_blacklist: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_turns: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub latency_budget_ms: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub confidence_offset: Option<f64>,
    pub schema_version: u32,
}

/// Frontmatter on the `.soul.md` half — single-line `---{json}---` line 1.
#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct SoulNarrativeFrontmatter {
    pub soul_id: String,
    pub persona_version: String,
}

#[derive(Clone, Debug)]
pub struct SoulPair {
    pub manifest: SoulManifest,
    pub narrative_frontmatter: SoulNarrativeFrontmatter,
    pub narrative_body: String,
    pub manifest_path: PathBuf,
    pub narrative_path: PathBuf,
}

impl SoulPair {
    /// Load `<name>.soul.json` + `<name>.soul.md` from disk and verify
    /// bidirectional integrity. The path argument is the `.soul.json` path.
    pub fn load(manifest_path: &Path) -> Result<Self, FormatError> {
        let manifest_bytes = std::fs::read_to_string(manifest_path)?;
        let manifest: SoulManifest = serde_json::from_str(&manifest_bytes)?;

        if manifest.schema != SOUL_V1_ID {
            return Err(FormatError::SoulIntegrity(format!(
                "manifest $schema must be {}, got {}",
                SOUL_V1_ID, manifest.schema
            )));
        }
        validate_against(super::schemas::SOUL_V1, &serde_json::to_value(&manifest)?)?;

        let narrative_path = manifest_path
            .parent()
            .ok_or_else(|| {
                FormatError::SoulIntegrity(format!(
                    "manifest path has no parent: {}",
                    manifest_path.display()
                ))
            })?
            .join(&manifest.narrative_path);

        if !narrative_path.exists() {
            return Err(FormatError::SoulMissingFile(format!(
                "narrative half missing at {}",
                narrative_path.display()
            )));
        }

        let narrative_bytes = std::fs::read_to_string(&narrative_path)?;
        let (front, body) = parse_narrative(&narrative_bytes)?;

        if front.soul_id != manifest.id {
            return Err(FormatError::SoulIntegrity(format!(
                "soul_id mismatch: manifest={} narrative={}",
                manifest.id, front.soul_id
            )));
        }
        if front.persona_version != manifest.version {
            return Err(FormatError::SoulIntegrity(format!(
                "persona_version mismatch: manifest={} narrative={}",
                manifest.version, front.persona_version
            )));
        }

        Ok(Self {
            manifest,
            narrative_frontmatter: front,
            narrative_body: body,
            manifest_path: manifest_path.to_path_buf(),
            narrative_path,
        })
    }

    /// Convenience: write a fresh soul pair to disk via atomic
    /// tempfile-rename per plan §6.9. Used by tests + by the
    /// soul-authoring CLI in Phase 6.5.
    pub fn write(
        dir: &Path,
        name: &str,
        manifest: SoulManifest,
        narrative_body: &str,
    ) -> Result<Self, FormatError> {
        std::fs::create_dir_all(dir)?;
        let manifest_path = dir.join(format!("{}.soul.json", name));
        let narrative_path = dir.join(format!("{}.soul.md", name));

        let front = SoulNarrativeFrontmatter {
            soul_id: manifest.id.clone(),
            persona_version: manifest.version.clone(),
        };
        let frontmatter_json = serde_json::to_string(&front)?;
        let narrative_text = format!("---{}---\n{}", frontmatter_json, narrative_body);

        // Plan §6.9: tempfile-rename atomic write so half-written
        // pairs are never visible to readers. The two halves are still
        // written sequentially — Phase 8 Intent→Effect work adds the
        // pair-level atomicity (write both halves under a transaction
        // boundary). For Phase 1 single-half atomic is the canonical
        // bar.
        crate::util::atomic_write_json(&manifest_path, &manifest)?;
        crate::util::atomic_write_bytes(&narrative_path, narrative_text.as_bytes())?;

        Self::load(&manifest_path)
    }
}

fn parse_narrative(input: &str) -> Result<(SoulNarrativeFrontmatter, String), FormatError> {
    let (header_line, body) = match input.find('\n') {
        Some(idx) => (&input[..idx], &input[idx + 1..]),
        None => (input, ""),
    };
    let header_line = header_line.trim_end_matches('\r');
    let inner = header_line
        .strip_prefix("---")
        .and_then(|s| s.strip_suffix("---"))
        .ok_or_else(|| {
            FormatError::SoulIntegrity(format!(
                "narrative line 1 must be ---{{json}}---, got {:?}",
                header_line
            ))
        })?;
    let front: SoulNarrativeFrontmatter = serde_json::from_str(inner).map_err(|e| {
        FormatError::SoulIntegrity(format!("narrative frontmatter parse: {}", e))
    })?;
    Ok((front, body.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn sample_manifest() -> SoulManifest {
        SoulManifest {
            schema: SOUL_V1_ID.to_string(),
            id: "soul.router.v1".to_string(),
            name: "Router".to_string(),
            version: "1.0.0".to_string(),
            narrative_path: "router.soul.md".to_string(),
            model_preference: ModelPreference {
                primary: Some(ModelPick {
                    tier: ModelTier::Local,
                    model: "qwen2.5-1.5b-instruct-4bit".to_string(),
                }),
                fallback: None,
                escalation: None,
            },
            tool_whitelist: vec!["vault.search".to_string(), "reason.think".to_string()],
            tool_blacklist: vec!["action.shell".to_string()],
            max_turns: Some(6),
            latency_budget_ms: Some(800),
            confidence_offset: None,
            schema_version: 1,
        }
    }

    #[test]
    fn pair_round_trips_via_disk() {
        let dir = tempdir().unwrap();
        let m = sample_manifest();
        let pair = SoulPair::write(dir.path(), "router", m.clone(), "# Router\n\nHi.").unwrap();
        assert_eq!(pair.manifest, m);
        assert_eq!(pair.narrative_frontmatter.soul_id, "soul.router.v1");
        assert_eq!(pair.narrative_frontmatter.persona_version, "1.0.0");
        assert_eq!(pair.narrative_body, "# Router\n\nHi.");
    }

    #[test]
    fn missing_narrative_half_is_rejected() {
        let dir = tempdir().unwrap();
        let manifest = sample_manifest();
        let manifest_path = dir.path().join("router.soul.json");
        std::fs::write(&manifest_path, serde_json::to_string_pretty(&manifest).unwrap()).unwrap();
        // No `.soul.md` written.
        let r = SoulPair::load(&manifest_path);
        assert!(matches!(r, Err(FormatError::SoulMissingFile(_))));
    }

    #[test]
    fn soul_id_mismatch_between_halves_is_rejected() {
        let dir = tempdir().unwrap();
        let manifest = sample_manifest();
        let manifest_path = dir.path().join("router.soul.json");
        let narrative_path = dir.path().join("router.soul.md");
        std::fs::write(&manifest_path, serde_json::to_string_pretty(&manifest).unwrap()).unwrap();
        // Hand-write a bad narrative with a wrong soul_id.
        let bad = r#"---{"soul_id":"soul.WRONG.v1","persona_version":"1.0.0"}---
# Router
"#;
        std::fs::write(&narrative_path, bad).unwrap();
        let r = SoulPair::load(&manifest_path);
        assert!(matches!(r, Err(FormatError::SoulIntegrity(_))));
    }

    #[test]
    fn version_mismatch_between_halves_is_rejected() {
        let dir = tempdir().unwrap();
        let manifest = sample_manifest();
        let manifest_path = dir.path().join("router.soul.json");
        let narrative_path = dir.path().join("router.soul.md");
        std::fs::write(&manifest_path, serde_json::to_string_pretty(&manifest).unwrap()).unwrap();
        let bad = r#"---{"soul_id":"soul.router.v1","persona_version":"9.9.9"}---
# Router
"#;
        std::fs::write(&narrative_path, bad).unwrap();
        let r = SoulPair::load(&manifest_path);
        assert!(matches!(r, Err(FormatError::SoulIntegrity(_))));
    }

    #[test]
    fn manifest_schema_validates() {
        let m = sample_manifest();
        let v = serde_json::to_value(&m).unwrap();
        super::super::validate_against(super::super::schemas::SOUL_V1, &v).unwrap();
    }

    #[test]
    fn schema_rejects_bad_id_pattern() {
        let mut m = sample_manifest();
        m.id = "not-a-soul-id".to_string();
        let v = serde_json::to_value(&m).unwrap();
        assert!(super::super::validate_against(super::super::schemas::SOUL_V1, &v).is_err());
    }

    #[test]
    fn schema_rejects_bad_version_pattern() {
        let mut m = sample_manifest();
        m.version = "1.0".to_string(); // Not full semver
        let v = serde_json::to_value(&m).unwrap();
        assert!(super::super::validate_against(super::super::schemas::SOUL_V1, &v).is_err());
    }

    #[test]
    fn schema_rejects_narrative_path_without_soul_md_suffix() {
        let mut m = sample_manifest();
        m.narrative_path = "router.txt".to_string();
        let v = serde_json::to_value(&m).unwrap();
        assert!(super::super::validate_against(super::super::schemas::SOUL_V1, &v).is_err());
    }

    #[test]
    fn schema_enforces_additional_properties_false() {
        let mut v = serde_json::to_value(sample_manifest()).unwrap();
        v.as_object_mut().unwrap().insert(
            "rogue_field".to_string(),
            serde_json::Value::String("bad".to_string()),
        );
        assert!(super::super::validate_against(super::super::schemas::SOUL_V1, &v).is_err());
    }
}
