use std::collections::HashMap;
use std::sync::Arc;

use agent_core::bridge::{route_capture_contract, route_variant_b_schema_json};
use agent_core::route::variant_a::{try_centroid, FolderCentroid, FolderMedoidStore};
use agent_core::route::variant_b::{
    build_route_grammar_schema, try_llm_classify, ClassifierError, LlmClassifier, VariantBOutput,
};
use agent_core::route::variant_c::{
    try_concept_anchored, Concept, ConceptExtractor, EntityResolver, ExtractorError,
    NeighbourFinder, NeighbourHit, Resolution,
};
use agent_core::route::{
    route_capture, Action, EmbeddingProvider, RouteCtx, RouteDecision, RouteInput, VaultTreeEntry,
    CREATE_FOLDER_CLUSTER_COSINE, CREATE_FOLDER_CLUSTER_MIN_COUNT, MERGE_CONFIDENCE_GATE,
    MERGE_STALENESS_HOURS, REASONING_TRACE_MAX_CHARS, VARIANT_A_FLOOR, VARIANT_B_FLOOR,
    VARIANT_C_CREATE_FOLDER_CONFIDENCE, VARIANT_C_FLOOR, VARIANT_C_PLACE_VIA_FOUND_CONFIDENCE,
};
use async_trait::async_trait;
use serde_json::json;

struct MapEmbedder {
    vectors: HashMap<String, Vec<f32>>,
}

#[async_trait]
impl EmbeddingProvider for MapEmbedder {
    async fn embed(&self, text: &str) -> Vec<f32> {
        self.vectors.get(text).cloned().unwrap_or_default()
    }
}

struct StaticClassifier(VariantBOutput);

#[async_trait]
impl LlmClassifier for StaticClassifier {
    async fn classify(
        &self,
        _capture_text: &str,
        _allowed_paths: &[String],
    ) -> Result<VariantBOutput, ClassifierError> {
        Ok(self.0.clone())
    }
}

struct NullClassifier;

#[async_trait]
impl LlmClassifier for NullClassifier {
    async fn classify(
        &self,
        _capture_text: &str,
        _allowed_paths: &[String],
    ) -> Result<VariantBOutput, ClassifierError> {
        Err(ClassifierError::Inference("not wired".to_string()))
    }
}

struct StaticExtractor(Vec<Concept>);

#[async_trait]
impl ConceptExtractor for StaticExtractor {
    async fn extract(&self, _text: &str) -> Result<Vec<Concept>, ExtractorError> {
        Ok(self.0.clone())
    }
}

struct StaticResolver(Resolution);

#[async_trait]
impl EntityResolver for StaticResolver {
    async fn resolve(&self, _canonical_name: &str) -> Resolution {
        self.0.clone()
    }
}

struct StaticNeighbours(Vec<NeighbourHit>);

#[async_trait]
impl NeighbourFinder for StaticNeighbours {
    async fn find(&self, _query: &str, _k: usize) -> Vec<NeighbourHit> {
        self.0.clone()
    }
}

fn embedder(pairs: &[(&str, Vec<f32>)]) -> Arc<dyn EmbeddingProvider> {
    Arc::new(MapEmbedder {
        vectors: pairs
            .iter()
            .map(|(key, value)| ((*key).to_string(), value.clone()))
            .collect(),
    })
}

fn hit(path: &str, folder: &str, cosine: f64, last_edited_hours_ago: u64) -> NeighbourHit {
    NeighbourHit {
        path: path.to_string(),
        folder: folder.to_string(),
        cosine,
        last_edited_hours_ago,
    }
}

fn route_input() -> RouteInput {
    RouteInput {
        capture_text: "gradient checkpointing note".to_string(),
        vault_tree: vec![VaultTreeEntry {
            path: "research/ml".to_string(),
            centroid_id: "centroid-1".to_string(),
            note_count: 5,
            exemplar_titles: Vec::new(),
        }],
        recent_captures: Vec::new(),
    }
}

fn null_ctx() -> RouteCtx {
    RouteCtx {
        embedder: embedder(&[]),
        folders: Vec::new(),
        classifier: Arc::new(NullClassifier),
        vault_paths: Vec::new(),
        extractor: Arc::new(StaticExtractor(Vec::new())),
        resolver: Arc::new(StaticResolver(Resolution::New)),
        neighbours: Arc::new(StaticNeighbours(Vec::new())),
        parent_unfit: Arc::new(|_| true),
    }
}

#[test]
fn route_constants_match_canonical_floors_and_gates() {
    assert_eq!(VARIANT_A_FLOOR, 0.85);
    assert_eq!(VARIANT_B_FLOOR, 0.75);
    assert_eq!(VARIANT_C_FLOOR, 0.70);
    assert_eq!(MERGE_CONFIDENCE_GATE, 0.90);
    assert_eq!(MERGE_STALENESS_HOURS, 24);
    assert_eq!(CREATE_FOLDER_CLUSTER_COSINE, 0.80);
    assert_eq!(CREATE_FOLDER_CLUSTER_MIN_COUNT, 3);
    assert_eq!(REASONING_TRACE_MAX_CHARS, 280);
}

#[test]
fn ffi_exposes_route_capture_contract_to_swift_hosts() {
    let contract = route_capture_contract();

    assert_eq!(
        contract.input_schema_id,
        "epistemos://schemas/route_capture.input.v1.json"
    );
    assert_eq!(
        contract.output_schema_id,
        "epistemos://schemas/route_capture.output.v1.json"
    );
    assert_eq!(
        contract.actions,
        [
            "place",
            "merge_into_existing_note",
            "create_folder",
            "defer"
        ]
    );
    assert_eq!(contract.variant_a_floor, VARIANT_A_FLOOR);
    assert_eq!(contract.variant_b_floor, VARIANT_B_FLOOR);
    assert_eq!(contract.variant_c_floor, VARIANT_C_FLOOR);
    assert_eq!(
        contract.reasoning_trace_max_chars,
        REASONING_TRACE_MAX_CHARS as u64
    );
    assert_eq!(contract.review_inbox_path, "_inbox/review/");
}

#[test]
fn ffi_exposes_deterministic_variant_b_closed_vocabulary_schema() {
    let schema_json = route_variant_b_schema_json(vec![
        "_inbox/raw".to_string(),
        "research/vision".to_string(),
        "research/ml".to_string(),
        "research/ml".to_string(),
    ])
    .expect("schema serializes for Swift host");
    let schema: serde_json::Value = serde_json::from_str(&schema_json).unwrap();

    assert_eq!(
        schema["properties"]["path"]["enum"],
        serde_json::json!(["research/ml", "research/vision", "NEW", "DEFER"])
    );
    assert_eq!(schema["additionalProperties"], false);
}

#[test]
fn action_enum_has_exactly_the_four_canonical_wire_values() {
    let values = [
        serde_json::to_value(Action::Place).unwrap(),
        serde_json::to_value(Action::MergeIntoExistingNote).unwrap(),
        serde_json::to_value(Action::CreateFolder).unwrap(),
        serde_json::to_value(Action::Defer).unwrap(),
    ];
    assert_eq!(
        values,
        [
            "place",
            "merge_into_existing_note",
            "create_folder",
            "defer"
        ]
    );
}

#[tokio::test]
async fn variant_a_places_only_when_centroid_floor_clears() {
    let folders = vec![
        FolderCentroid {
            path: "research/ml".to_string(),
            note_count: 5,
            medoid: vec![1.0, 0.0],
        },
        FolderCentroid {
            path: "_inbox/review".to_string(),
            note_count: 99,
            medoid: vec![1.0, 0.0],
        },
    ];
    let provider = embedder(&[("capture", vec![1.0, 0.0])]);
    let decision = try_centroid("capture", &folders, &provider)
        .await
        .expect("top cosine clears floor");
    assert_eq!(decision.action, Action::Place);
    assert_eq!(decision.folder_path.as_deref(), Some("research/ml"));
    assert!(decision.confidence >= VARIANT_A_FLOOR);

    let miss_provider = embedder(&[("capture", vec![0.0, 1.0])]);
    assert!(try_centroid("capture", &folders, &miss_provider)
        .await
        .is_none());
}

#[tokio::test]
async fn variant_a_medoids_persist_with_wal_and_load_deterministically() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join(".epistemos").join("route_medoids.sqlite");
    let store = FolderMedoidStore::open(&path).expect("store opens");
    assert_eq!(store.journal_mode().unwrap().to_lowercase(), "wal");

    store
        .upsert(&FolderCentroid {
            path: "research/vision".to_string(),
            note_count: 4,
            medoid: vec![0.0, 1.0],
        })
        .unwrap();
    store
        .upsert(&FolderCentroid {
            path: "research/ml".to_string(),
            note_count: 5,
            medoid: vec![1.0, 0.0],
        })
        .unwrap();

    let reopened = FolderMedoidStore::open(&path).expect("store reopens");
    let folders = reopened.load_all().unwrap();
    assert_eq!(
        folders
            .iter()
            .map(|folder| folder.path.as_str())
            .collect::<Vec<_>>(),
        ["research/ml", "research/vision"]
    );

    let provider = embedder(&[("capture", vec![1.0, 0.0])]);
    let decision = try_centroid("capture", &folders, &provider)
        .await
        .expect("loaded medoid routes capture");
    assert_eq!(decision.folder_path.as_deref(), Some("research/ml"));
}

#[test]
fn variant_a_medoid_store_rejects_non_finite_vectors() {
    let store = FolderMedoidStore::open_in_memory().unwrap();
    let error = store
        .upsert(&FolderCentroid {
            path: "research/ml".to_string(),
            note_count: 5,
            medoid: vec![f32::NAN],
        })
        .expect_err("NaN medoid is rejected");

    assert!(error.to_string().contains("finite"));
}

#[tokio::test]
async fn variant_b_honors_confidence_floor_new_and_defer_sentinels() {
    let vault_paths = vec!["research/ml".to_string(), "_inbox/raw".to_string()];

    let place = StaticClassifier(VariantBOutput {
        path: "research/ml".to_string(),
        confidence: 0.81,
        rationale: "topic match".to_string(),
    });
    let decision = try_llm_classify("capture", &vault_paths, &place)
        .await
        .expect("above floor places");
    assert_eq!(decision.action, Action::Place);

    let low = StaticClassifier(VariantBOutput {
        path: "research/ml".to_string(),
        confidence: 0.50,
        rationale: "uncertain".to_string(),
    });
    assert!(try_llm_classify("capture", &vault_paths, &low)
        .await
        .is_none());

    let new = StaticClassifier(VariantBOutput {
        path: "NEW".to_string(),
        confidence: 0.99,
        rationale: "new concept".to_string(),
    });
    assert!(try_llm_classify("capture", &vault_paths, &new)
        .await
        .is_none());

    let defer = StaticClassifier(VariantBOutput {
        path: "DEFER".to_string(),
        confidence: 0.20,
        rationale: "ambiguous".to_string(),
    });
    let decision = try_llm_classify("capture", &vault_paths, &defer)
        .await
        .expect("self defer is accepted");
    assert_eq!(decision.action, Action::Defer);
}

#[test]
fn variant_b_schema_uses_deterministic_closed_vocabulary() {
    let schema = build_route_grammar_schema(&[
        "zeta/notes".to_string(),
        "_inbox/raw".to_string(),
        "research/ml".to_string(),
        "research/ml".to_string(),
    ]);

    assert_eq!(
        schema["properties"]["path"]["enum"],
        json!(["research/ml", "zeta/notes", "NEW", "DEFER"])
    );
}

#[tokio::test]
async fn variant_b_rejects_classifier_paths_outside_closed_vocabulary() {
    let vault_paths = vec!["research/ml".to_string(), "_inbox/raw".to_string()];
    let outside = StaticClassifier(VariantBOutput {
        path: "private/outside".to_string(),
        confidence: 0.99,
        rationale: "not in grammar".to_string(),
    });

    assert!(try_llm_classify("capture", &vault_paths, &outside)
        .await
        .is_none());
}

#[tokio::test]
async fn variant_c_can_merge_or_create_folder_from_concepts_and_neighbours() {
    let found = StaticResolver(Resolution::Found {
        concept_id: "concept-1".to_string(),
    });
    let neighbours = StaticNeighbours(vec![
        hit("research/ml/a.md", "research/ml", 0.95, 48),
        hit("research/ml/b.md", "research/ml", 0.86, 72),
        hit("research/ml/c.md", "research/ml", 0.81, 96),
    ]);
    let decision = try_concept_anchored(
        "capture",
        &StaticExtractor(vec![Concept {
            canonical_name: "gradient-checkpointing".to_string(),
            surface_form: "gradient checkpointing".to_string(),
        }]),
        &found,
        &neighbours,
        |_| false,
    )
    .await
    .expect("merge branch");
    assert_eq!(decision.action, Action::MergeIntoExistingNote);
    assert_eq!(
        decision.target_note_path.as_deref(),
        Some("research/ml/a.md")
    );

    let new = StaticResolver(Resolution::New);
    let decision = try_concept_anchored(
        "capture",
        &StaticExtractor(vec![Concept {
            canonical_name: "novel-concept".to_string(),
            surface_form: "novel concept".to_string(),
        }]),
        &new,
        &neighbours,
        |_| true,
    )
    .await
    .expect("create folder branch");
    assert_eq!(decision.action, Action::CreateFolder);
    assert_eq!(decision.confidence, VARIANT_C_CREATE_FOLDER_CONFIDENCE);
}

#[tokio::test]
async fn route_capture_walks_a_b_c_then_defer() {
    let mut ctx = null_ctx();
    ctx.embedder = embedder(&[("gradient checkpointing note", vec![1.0, 0.0])]);
    ctx.folders = vec![FolderCentroid {
        path: "research/ml".to_string(),
        note_count: 5,
        medoid: vec![1.0, 0.0],
    }];
    let decision = route_capture(&route_input(), &ctx).await;
    assert_eq!(decision.action, Action::Place);
    assert!(decision.reasoning_trace.contains("variant_a"));

    let mut ctx = null_ctx();
    ctx.classifier = Arc::new(StaticClassifier(VariantBOutput {
        path: "research/ml".to_string(),
        confidence: 0.82,
        rationale: "classification match".to_string(),
    }));
    ctx.vault_paths = vec!["research/ml".to_string()];
    let decision = route_capture(&route_input(), &ctx).await;
    assert_eq!(decision.action, Action::Place);
    assert_eq!(decision.confidence, 0.82);

    let mut ctx = null_ctx();
    ctx.extractor = Arc::new(StaticExtractor(vec![Concept {
        canonical_name: "gradient-checkpointing".to_string(),
        surface_form: "gradient checkpointing".to_string(),
    }]));
    ctx.resolver = Arc::new(StaticResolver(Resolution::Found {
        concept_id: "concept-1".to_string(),
    }));
    ctx.neighbours = Arc::new(StaticNeighbours(vec![
        hit("research/ml/a.md", "research/ml", 0.86, 12),
        hit("research/ml/b.md", "research/ml", 0.84, 12),
        hit("research/ml/c.md", "research/ml", 0.82, 12),
    ]));
    let decision = route_capture(&route_input(), &ctx).await;
    assert_eq!(decision.action, Action::Place);
    assert_eq!(decision.confidence, VARIANT_C_PLACE_VIA_FOUND_CONFIDENCE);

    let decision = route_capture(&route_input(), &null_ctx()).await;
    assert_eq!(decision.action, Action::Defer);
    assert_eq!(decision.folder_path.as_deref(), Some("_inbox/review/"));
    assert_eq!(decision.confidence, 1.0);
}

#[test]
fn route_decision_validation_rejects_oversized_trace_and_bad_folder_name() {
    let valid = RouteDecision::defer("low confidence", Vec::new());
    valid.validate().expect("valid defer decision");

    let mut bad_trace = valid.clone();
    bad_trace.reasoning_trace = "x".repeat(REASONING_TRACE_MAX_CHARS + 1);
    assert!(bad_trace.validate().is_err());

    let mut bad_folder = RouteDecision::create_folder("research", "BadCamel", 0.71, "x");
    assert!(bad_folder.validate().is_err());
    bad_folder.new_folder_name = Some("good-folder".to_string());
    bad_folder.validate().expect("lower-kebab folder name");
}
