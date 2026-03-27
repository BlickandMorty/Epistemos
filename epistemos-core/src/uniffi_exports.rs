// UniFFI-exported free functions.
// These are the Swift-callable entry points defined in epistemos_core.udl.

use crate::vault_analyzer::mtld;
use crate::vault_analyzer::token_estimator;
use crate::vault_analyzer::classifier;
use crate::vault_analyzer::boilerplate_filter;
use crate::vault_analyzer::chunker;
use crate::quality_filter;
use crate::skill_engine;
use crate::auto_tuner::hyperparams;
use crate::auto_tuner::rank_selector;
use crate::scheduler::tier_scheduler;

// ── Vault Analysis ──────────────────────────────────────────────────────────

pub fn compute_mtld(tokens: Vec<String>, threshold: f64) -> f64 {
    mtld::mtld_ma_bid(&tokens, threshold)
}

pub fn tokenize_for_mtld(text: String) -> Vec<String> {
    mtld::tokenize_for_mtld(&text)
}

pub fn estimate_tokens(content: String) -> u64 {
    token_estimator::estimate_tokens(&content) as u64
}

pub fn content_hash(content: String) -> String {
    blake3::hash(content.as_bytes()).to_hex().to_string()
}

pub fn classify_document(content: String) -> classifier::DocumentClassification {
    classifier::classify_document(&content).into()
}

pub fn filter_boilerplate(content: String) -> boilerplate_filter::BoilerplateResult {
    boilerplate_filter::filter_boilerplate(&content).into()
}

// ── Document Chunking ────────────────────────────────────────────────────────

pub fn chunk_document(content: String) -> chunker::ChunkDocumentResult {
    chunker::chunk_document(&content)
}

// ── Quality Filter ───────────────────────────────────────────────────────────

pub fn dedup_texts(texts_json: String, threshold: f64) -> quality_filter::DedupResult {
    quality_filter::dedup_texts(&texts_json, threshold)
}

pub fn score_training_pair(instruction: String, response: String, min_score: f64) -> quality_filter::QualityScore {
    quality_filter::score_training_pair(&instruction, &response, min_score)
}

// ── Adapter Routing ─────────────────────────────────────────────────────────

pub fn route_prompt(prompt: String) -> skill_engine::RoutingDecision {
    skill_engine::route_prompt(&prompt)
}

// ── Auto-Tuning ─────────────────────────────────────────────────────────────

pub fn select_lora_rank(mtld_score: f64, total_tokens: u64) -> u32 {
    rank_selector::select_lora_rank(mtld_score, total_tokens as usize)
}

pub fn select_lora_alpha(rank: u32, dataset_size: u64) -> u32 {
    rank_selector::select_lora_alpha(rank, dataset_size as usize)
}

pub fn auto_tune(
    dataset_size: u64,
    mtld_score: f64,
    total_tokens: u64,
    model_size_b: f64,
    available_memory_mb: u32,
    profile: String,
) -> hyperparams::AutoTuneConfig {
    hyperparams::auto_tune(
        dataset_size as usize,
        mtld_score,
        total_tokens as usize,
        model_size_b,
        available_memory_mb,
        &profile,
    )
}

// ── Instant Recall (Ω18) ────────────────────────────────────────────────────

use crate::instant_recall;
use std::sync::Mutex;
use std::collections::HashMap;

// Global index registry: allows Swift to create/manage multiple indices via handles.
static RECALL_INDICES: std::sync::LazyLock<Mutex<HashMap<String, instant_recall::InstantRecallIndex>>> =
    std::sync::LazyLock::new(|| Mutex::new(HashMap::new()));

static RECALL_EMBEDDER: std::sync::LazyLock<instant_recall::TrigramEmbedder> =
    std::sync::LazyLock::new(|| instant_recall::TrigramEmbedder::new(1024));

/// Create a new instant recall index. Returns the handle ID.
pub fn instant_recall_create(handle: String) -> bool {
    let config = instant_recall::InstantRecallConfig::default();
    let index = instant_recall::InstantRecallIndex::new(config);
    RECALL_INDICES.lock().unwrap().insert(handle, index);
    true
}

/// Encode text to a float32 embedding and insert into the index.
pub fn instant_recall_insert(handle: String, doc_id: String, text: String) -> bool {
    let embedding = RECALL_EMBEDDER.encode(&text);
    if let Some(index) = RECALL_INDICES.lock().unwrap().get_mut(&handle) {
        index.insert(doc_id, embedding, text);
        true
    } else {
        false
    }
}

/// Remove a document from the index.
pub fn instant_recall_remove(handle: String, doc_id: String) -> bool {
    if let Some(index) = RECALL_INDICES.lock().unwrap().get_mut(&handle) {
        index.remove(&doc_id);
        true
    } else {
        false
    }
}

/// Search the index for notes similar to the query text.
/// Returns JSON array of {doc_id, text, score} objects.
pub fn instant_recall_search(handle: String, query_text: String, top_k: u32) -> String {
    let embedding = RECALL_EMBEDDER.encode(&query_text);
    let indices = RECALL_INDICES.lock().unwrap();
    if let Some(index) = indices.get(&handle) {
        let results = index.search(&embedding, top_k as usize);
        let json: Vec<serde_json::Value> = results
            .iter()
            .map(|r| {
                serde_json::json!({
                    "doc_id": r.doc_id,
                    "text": r.text,
                    "score": r.score,
                })
            })
            .collect();
        serde_json::to_string(&json).unwrap_or_else(|_| "[]".to_string())
    } else {
        "[]".to_string()
    }
}

/// Get the number of documents in the index.
pub fn instant_recall_count(handle: String) -> u64 {
    RECALL_INDICES
        .lock()
        .unwrap()
        .get(&handle)
        .map(|i| i.len() as u64)
        .unwrap_or(0)
}

/// Clear all documents from the index.
pub fn instant_recall_clear(handle: String) -> bool {
    if let Some(index) = RECALL_INDICES.lock().unwrap().get_mut(&handle) {
        index.clear();
        true
    } else {
        false
    }
}

/// Encode text to a float32 embedding. Returns JSON array of floats.
pub fn instant_recall_encode(text: String) -> String {
    let embedding = RECALL_EMBEDDER.encode(&text);
    serde_json::to_string(&embedding).unwrap_or_else(|_| "[]".to_string())
}

// ── Scheduling ──────────────────────────────────────────────────────────────

pub fn evaluate_schedule(
    dirty_file_count: u64,
    days_since_micro: i64,
    days_since_deep: i64,
    current_hour: u32,
    current_weekday: u32,
    is_on_battery: bool,
    is_training: bool,
) -> tier_scheduler::TrainingDecision {
    tier_scheduler::evaluate_schedule(
        dirty_file_count as usize,
        days_since_micro,
        days_since_deep,
        current_hour,
        current_weekday,
        is_on_battery,
        is_training,
    )
}
