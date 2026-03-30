use super::rank_selector::{select_lora_alpha, select_lora_rank};
use serde::{Deserialize, Serialize};

/// Auto-tuned training configuration.
/// Exported to Swift via UniFFI as a dictionary type.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AutoTuneConfig {
    pub lora_rank: u32,
    pub lora_alpha: u32,
    pub epochs: u32,
    pub max_iters: u32,
    pub batch_size: u32,
    pub learning_rate: f64,
    pub warmup_ratio: f64,
    pub weight_decay: f64,
    pub max_seq_length: u32,
    pub estimated_memory_mb: u32,
    pub target_modules: Vec<String>,
    pub adapter_type: String,
}

/// Generate a complete auto-tuned training config.
/// Replaces KnowledgeFusionViewModel.autoConfigureForHardware().
pub fn auto_tune(
    dataset_size: usize,
    mtld_score: f64,
    total_tokens: usize,
    model_size_b: f64,
    available_memory_mb: u32,
    profile: &str,
) -> AutoTuneConfig {
    let lora_rank = select_lora_rank(mtld_score, total_tokens);
    let lora_alpha = select_lora_alpha(lora_rank, dataset_size);

    let target_modules: Vec<String> = if profile == "style" {
        ["q_proj", "k_proj", "v_proj", "o_proj"]
            .iter()
            .map(|s| s.to_string())
            .collect()
    } else {
        [
            "q_proj",
            "k_proj",
            "v_proj",
            "o_proj",
            "gate_proj",
            "up_proj",
            "down_proj",
        ]
        .iter()
        .map(|s| s.to_string())
        .collect()
    };

    let epochs = if dataset_size == 0 {
        1
    } else {
        (500usize / dataset_size).clamp(1, 3) as u32
    };

    let batch_size: u32 = if available_memory_mb >= 32000 { 2 } else { 1 };
    let max_iters = (epochs * dataset_size as u32 / batch_size.max(1)).max(100);

    let learning_rate = match profile {
        "style" => 1e-5,
        _ => match model_size_b as u32 {
            0..=1 => 5e-5,
            2..=3 => 2e-5,
            _ => 1e-5,
        },
    };

    let warmup_ratio = if dataset_size < 100 { 0.10 } else { 0.15 };
    let weight_decay = if dataset_size < 100 { 0.1 } else { 0.05 };
    let max_seq_length = if available_memory_mb < 20000 {
        1024
    } else {
        2048
    };

    let model_memory = (model_size_b * 1000.0 * 0.5) as u32;
    let lora_memory = (lora_rank * 32 * 2 * 128 * 2 / 1024) as u32;
    let estimated_memory_mb = model_memory + lora_memory + 500;

    AutoTuneConfig {
        lora_rank,
        lora_alpha,
        epochs,
        max_iters,
        batch_size,
        learning_rate,
        warmup_ratio,
        weight_decay,
        max_seq_length,
        estimated_memory_mb,
        target_modules,
        adapter_type: profile.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_knowledge_profile() {
        let config = auto_tune(200, 80.0, 50000, 3.0, 18000, "knowledge");
        assert_eq!(config.target_modules.len(), 7);
        assert_eq!(config.adapter_type, "knowledge");
        assert!(config.estimated_memory_mb <= 11500);
    }

    #[test]
    fn test_style_profile() {
        let config = auto_tune(200, 80.0, 50000, 3.0, 18000, "style");
        assert_eq!(config.target_modules.len(), 4);
        assert_eq!(config.learning_rate, 1e-5);
    }

    #[test]
    fn test_memory_within_budget() {
        let config = auto_tune(500, 100.0, 100000, 8.0, 18000, "knowledge");
        assert!(config.estimated_memory_mb <= 11500);
    }

    #[test]
    fn test_small_dataset_alpha_doubled() {
        let config = auto_tune(50, 50.0, 5000, 1.0, 18000, "knowledge");
        assert_eq!(config.lora_alpha, config.lora_rank * 2);
    }

    #[test]
    fn test_min_iters() {
        let config = auto_tune(10, 50.0, 1000, 1.0, 18000, "knowledge");
        assert!(config.max_iters >= 100);
    }
}
