use std::sync::Arc;

use async_trait::async_trait;
use schemars::{schema_for, JsonSchema};
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::format::{validate_nonempty, validate_unit_interval, FormatError};

pub mod variant_a;
pub mod variant_b;
pub mod variant_b_classifiers;
pub mod variant_c;
pub mod variant_c_providers;

pub const ROUTE_INPUT_V1_ID: &str = "epistemos://schemas/route_capture.input.v1.json";
pub const ROUTE_OUTPUT_V1_ID: &str = "epistemos://schemas/route_capture.output.v1.json";

pub const VARIANT_A_FLOOR: f64 = 0.85;
pub const VARIANT_B_FLOOR: f64 = 0.75;
pub const VARIANT_C_FLOOR: f64 = 0.70;

pub const MERGE_CONFIDENCE_GATE: f64 = 0.90;
pub const MERGE_STALENESS_HOURS: u64 = 24;
pub const CREATE_FOLDER_CLUSTER_COSINE: f64 = 0.80;
pub const CREATE_FOLDER_CLUSTER_MIN_COUNT: usize = 3;
pub const REASONING_TRACE_MAX_CHARS: usize = 280;

pub const VARIANT_C_PLACE_VIA_FOUND_CONFIDENCE: f64 = 0.72;
pub const VARIANT_C_CREATE_FOLDER_CONFIDENCE: f64 = 0.71;
pub const VARIANT_C_PLACE_VIA_MAJORITY_CONFIDENCE: f64 = 0.70;

#[async_trait]
pub trait EmbeddingProvider: Send + Sync {
    async fn embed(&self, text: &str) -> Vec<f32>;
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum Action {
    Place,
    MergeIntoExistingNote,
    CreateFolder,
    Defer,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct VaultTreeEntry {
    pub path: String,
    pub centroid_id: String,
    pub note_count: u32,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub exemplar_titles: Vec<String>,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct RecentCapture {
    pub text: String,
    pub placed_at: String,
    pub ts: i64,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct RouteInput {
    pub capture_text: String,
    #[serde(default)]
    pub vault_tree: Vec<VaultTreeEntry>,
    #[serde(default)]
    pub recent_captures: Vec<RecentCapture>,
}

impl RouteInput {
    pub fn validate(&self) -> Result<(), FormatError> {
        validate_nonempty(&self.capture_text, "capture_text")?;
        if self.capture_text.chars().count() > 2_000 {
            return Err(FormatError::Validation(
                "capture_text must be at most 2000 characters".to_string(),
            ));
        }
        if self.recent_captures.len() > 10 {
            return Err(FormatError::Validation(
                "recent_captures must contain at most 10 entries".to_string(),
            ));
        }
        Ok(())
    }
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct AlternativePath {
    pub path: String,
    pub score: f64,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct RouteDecision {
    pub action: Action,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub folder_path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub target_note_path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub new_folder_name: Option<String>,
    pub confidence: f64,
    pub reasoning_trace: String,
    #[serde(default)]
    pub alternative_paths: Vec<AlternativePath>,
}

impl RouteDecision {
    pub fn defer(reason: impl Into<String>, alternative_paths: Vec<AlternativePath>) -> Self {
        Self {
            action: Action::Defer,
            folder_path: Some("_inbox/review/".to_string()),
            target_note_path: None,
            new_folder_name: None,
            confidence: 1.0,
            reasoning_trace: truncate_chars(reason.into(), REASONING_TRACE_MAX_CHARS),
            alternative_paths,
        }
    }

    pub fn place(folder: impl Into<String>, confidence: f64, reason: impl Into<String>) -> Self {
        Self {
            action: Action::Place,
            folder_path: Some(folder.into()),
            target_note_path: None,
            new_folder_name: None,
            confidence,
            reasoning_trace: truncate_chars(reason.into(), REASONING_TRACE_MAX_CHARS),
            alternative_paths: Vec::new(),
        }
    }

    pub fn merge(target: impl Into<String>, confidence: f64, reason: impl Into<String>) -> Self {
        Self {
            action: Action::MergeIntoExistingNote,
            folder_path: None,
            target_note_path: Some(target.into()),
            new_folder_name: None,
            confidence,
            reasoning_trace: truncate_chars(reason.into(), REASONING_TRACE_MAX_CHARS),
            alternative_paths: Vec::new(),
        }
    }

    pub fn create_folder(
        parent_folder: impl Into<String>,
        new_folder_name: impl Into<String>,
        confidence: f64,
        reason: impl Into<String>,
    ) -> Self {
        Self {
            action: Action::CreateFolder,
            folder_path: Some(parent_folder.into()),
            target_note_path: None,
            new_folder_name: Some(new_folder_name.into()),
            confidence,
            reasoning_trace: truncate_chars(reason.into(), REASONING_TRACE_MAX_CHARS),
            alternative_paths: Vec::new(),
        }
    }

    pub fn validate(&self) -> Result<(), FormatError> {
        validate_unit_interval(self.confidence, "confidence")?;
        if self.reasoning_trace.chars().count() > REASONING_TRACE_MAX_CHARS {
            return Err(FormatError::Validation(format!(
                "reasoning_trace must be at most {REASONING_TRACE_MAX_CHARS} characters"
            )));
        }
        match self.action {
            Action::Place => validate_present(&self.folder_path, "folder_path"),
            Action::MergeIntoExistingNote => {
                validate_present(&self.target_note_path, "target_note_path")
            }
            Action::CreateFolder => {
                validate_present(&self.folder_path, "folder_path")?;
                let name = self.new_folder_name.as_deref().ok_or_else(|| {
                    FormatError::Validation("new_folder_name is required".to_string())
                })?;
                validate_folder_name(name)
            }
            Action::Defer => validate_present(&self.folder_path, "folder_path"),
        }
    }
}

pub fn route_input_schema_json() -> Value {
    serde_json::to_value(schema_for!(RouteInput)).expect("RouteInput schema serializes")
}

pub fn route_output_schema_json() -> Value {
    serde_json::to_value(schema_for!(RouteDecision)).expect("RouteDecision schema serializes")
}

pub struct RouteCtx {
    pub embedder: Arc<dyn EmbeddingProvider>,
    pub folders: Vec<variant_a::FolderCentroid>,
    pub classifier: Arc<dyn variant_b::LlmClassifier>,
    pub vault_paths: Vec<String>,
    pub extractor: Arc<dyn variant_c::ConceptExtractor>,
    pub resolver: Arc<dyn variant_c::EntityResolver>,
    pub neighbours: Arc<dyn variant_c::NeighbourFinder>,
    pub parent_unfit: Arc<dyn Fn(&str) -> bool + Send + Sync>,
}

pub async fn route_capture(input: &RouteInput, ctx: &RouteCtx) -> RouteDecision {
    if let Some(decision) =
        variant_a::try_centroid(&input.capture_text, &ctx.folders, &ctx.embedder).await
    {
        if decision.confidence >= VARIANT_A_FLOOR {
            return decision;
        }
    }

    if let Some(decision) = variant_b::try_llm_classify(
        &input.capture_text,
        &ctx.vault_paths,
        ctx.classifier.as_ref(),
    )
    .await
    {
        if decision.action == Action::Defer || decision.confidence >= VARIANT_B_FLOOR {
            return decision;
        }
    }

    let parent_unfit = Arc::clone(&ctx.parent_unfit);
    if let Some(decision) = variant_c::try_concept_anchored(
        &input.capture_text,
        ctx.extractor.as_ref(),
        ctx.resolver.as_ref(),
        ctx.neighbours.as_ref(),
        move |folder| parent_unfit(folder),
    )
    .await
    {
        if decision.confidence >= VARIANT_C_FLOOR {
            return decision;
        }
    }

    let alternatives = input
        .vault_tree
        .iter()
        .take(3)
        .map(|entry| AlternativePath {
            path: entry.path.clone(),
            score: 0.0,
        })
        .collect();
    RouteDecision::defer("low_confidence_after_three_variants", alternatives)
}

fn truncate_chars(value: String, max_chars: usize) -> String {
    if value.chars().count() <= max_chars {
        value
    } else {
        value.chars().take(max_chars).collect()
    }
}

fn validate_present(value: &Option<String>, label: &str) -> Result<(), FormatError> {
    match value.as_deref() {
        Some(value) => validate_nonempty(value, label),
        None => Err(FormatError::Validation(format!("{label} is required"))),
    }
}

fn validate_folder_name(value: &str) -> Result<(), FormatError> {
    let valid = (2..=48).contains(&value.chars().count())
        && value
            .bytes()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
        && !value.starts_with('-')
        && !value.ends_with('-')
        && !value.contains("--");
    if valid {
        Ok(())
    } else {
        Err(FormatError::Validation(
            "new_folder_name must be lower-kebab 2..48 characters".to_string(),
        ))
    }
}
