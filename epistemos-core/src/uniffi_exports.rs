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
