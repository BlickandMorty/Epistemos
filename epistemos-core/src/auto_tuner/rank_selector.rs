/// Data-aware LoRA rank selection using MTLD as proxy for intrinsic dimensionality.
///
/// Formula: r = clip(4, 64, round(log2(MTLD) * sqrt(total_tokens / 1000)))
///
/// Reference: LoRA-DA (arXiv:2510.24561), GeLoRA (arXiv:2412.09250v2)
pub fn select_lora_rank(mtld_score: f64, total_tokens: usize) -> u32 {
    if !mtld_score.is_finite() || mtld_score <= 0.0 || total_tokens == 0 {
        return 8; // Safe default
    }

    let log_mtld = mtld_score.log2();
    let token_factor = (total_tokens as f64 / 1000.0).sqrt();
    let raw_rank = (log_mtld * token_factor).round() as u32;

    raw_rank.clamp(4, 64)
}

pub fn select_lora_alpha(rank: u32, dataset_size: usize) -> u32 {
    if dataset_size < 100 {
        rank * 2
    } else {
        rank
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_on_invalid() {
        assert_eq!(select_lora_rank(f64::NAN, 1000), 8);
        assert_eq!(select_lora_rank(-1.0, 1000), 8);
        assert_eq!(select_lora_rank(50.0, 0), 8);
    }

    #[test]
    fn test_low_diversity_low_rank() {
        // Low MTLD (20), small dataset → should get low rank
        let rank = select_lora_rank(20.0, 5000);
        assert!(rank <= 16, "Low MTLD should yield low rank, got {rank}");
    }

    #[test]
    fn test_high_diversity_high_rank() {
        // High MTLD (150), large dataset → should get higher rank
        let rank = select_lora_rank(150.0, 100000);
        assert!(
            rank >= 16,
            "High MTLD + large data should yield higher rank, got {rank}"
        );
    }

    #[test]
    fn test_rank_clamped() {
        // Extreme values should be clamped to [4, 64]
        let low = select_lora_rank(1.1, 10);
        assert!(low >= 4);
        let high = select_lora_rank(500.0, 10_000_000);
        assert!(high <= 64);
    }

    #[test]
    fn test_alpha_small_dataset() {
        assert_eq!(select_lora_alpha(16, 50), 32); // rank * 2
    }

    #[test]
    fn test_alpha_large_dataset() {
        assert_eq!(select_lora_alpha(16, 500), 16); // rank * 1
    }
}
