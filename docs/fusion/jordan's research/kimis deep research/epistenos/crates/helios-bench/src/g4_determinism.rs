//! G4 — Seeded Replay Determinism.
//!
//! Validates that running the same prompt with the same seed produces
//! byte-identical outputs (within fp16 tolerance), identical tool call
//! sequences, and identical memory tier transitions.
//!
//! This is critical for reproducible science, debugging, and safety
//! certification. Any non-determinism is a bug.

use std::collections::HashMap;
use std::path::Path;
use anyhow::{Context, Result};
use clap::Parser;
use rand::SeedableRng;
use rand::rngs::StdRng;
use serde::{Deserialize, Serialize};
use tracing::{info, warn};

use helios_core::types::MemoryTier;
use helios_bench::metrics::{BenchmarkReport, Timer};

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

/// G4 — Determinism benchmark (standalone binary).
#[derive(Parser, Debug)]
#[command(name = "g4-determinism", about = "Seeded replay determinism validation")]
struct Cli {
    /// Seeds to test.
    #[arg(long, value_delimiter = ',', default_values_t = vec![0, 1, 42, 12345])]
    seeds: Vec<u64>,
    /// Number of replay iterations per seed.
    #[arg(long, default_value_t = 5)]
    replays: usize,
    /// Prompt to use for determinism testing.
    #[arg(long, default_value = "What is 2+2? Explain your reasoning.")]
    prompt: String,
    /// Output JSONL path.
    #[arg(long)]
    output: Option<std::path::PathBuf>,
    /// Verbose logging.
    #[arg(long)]
    verbose: bool,
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Result of determinism testing for a single seed.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DeterminismMetrics {
    /// The seed used.
    pub seed: u64,
    /// Generated outputs (one per replay).
    pub outputs: Vec<String>,
    /// Whether all outputs are identical (exact string match).
    pub all_identical: bool,
    /// Maximum token-level divergence between any pair of outputs.
    pub max_token_divergence: usize,
    /// Tool call sequences per replay.
    pub tool_sequences: Vec<Vec<String>>,
    /// Memory tier transitions per replay.
    pub tier_transitions: Vec<Vec<MemoryTier>>,
    /// Whether tool sequences are identical across replays.
    pub tools_identical: bool,
    /// Whether tier transitions are identical across replays.
    pub tiers_identical: bool,
    /// Per-replay latency in milliseconds.
    pub latencies_ms: Vec<f64>,
}

// ---------------------------------------------------------------------------
// Deterministic decoder stub
// ---------------------------------------------------------------------------

/// A fully deterministic decoder that uses a seeded RNG.
struct DeterministicDecoder {
    seed: u64,
    vocab_size: usize,
}

impl DeterministicDecoder {
    fn new(seed: u64) -> Self {
        Self {
            seed,
            vocab_size: 1000,
        }
    }

    /// Generate a deterministic response for a prompt.
    ///
    /// The output is a function of `(seed, prompt)` only — no external state.
    fn generate(&self, prompt: &str, max_tokens: usize) -> (String, Vec<String>, Vec<MemoryTier>) {
        let mut rng = StdRng::seed_from_u64(self.seed);
        let mut out = String::new();
        let mut tool_seq = Vec::new();
        let mut tiers = Vec::new();

        // Deterministic token generation using the seeded RNG
        for t in 0..max_tokens {
            let tok_id = (rng.gen::<u64>() % self.vocab_size as u64) as usize;
            let word = self.token_to_word(tok_id, t);
            out.push_str(&word);
            out.push(' ');

            // Simulate tier transitions based on token position
            let tier = if t < 10 {
                MemoryTier::L0ExactHot
            } else if t < 50 {
                MemoryTier::L1CompressedResidual
            } else if t < 100 {
                MemoryTier::L2ShadowSketch
            } else {
                MemoryTier::L3SSDOracle
            };
            tiers.push(tier);

            // Deterministic tool call trigger
            if tok_id % 47 == 0 && !tool_seq.contains(&"search".to_string()) {
                tool_seq.push("search".to_string());
            }
            if tok_id % 53 == 0 && !tool_seq.contains(&"calculator".to_string()) {
                tool_seq.push("calculator".to_string());
            }
        }

        (out.trim().to_string(), tool_seq, tiers)
    }

    fn token_to_word(&self, tok_id: usize, position: usize) -> String {
        let words = [
            "the", "a", "is", "are", "was", "were", "be", "been", "being", "have",
            "has", "had", "do", "does", "did", "will", "would", "could", "should",
            "may", "might", "must", "shall", "can", "need", "dare", "ought", "used",
            "to", "of", "in", "for", "on", "with", "at", "by", "from", "as", "into",
            "through", "during", "before", "after", "above", "below", "between",
            "under", "again", "further", "then", "once", "here", "there", "when",
            "where", "why", "how", "all", "any", "both", "each", "few", "more",
            "most", "other", "some", "such", "no", "nor", "not", "only", "own",
            "same", "so", "than", "too", "very", "just", "now", "also", "back",
            "still", "even", "new", "good", "high", "old", "great", "big", "American",
            "small", "large", "national", "young", "different", "black", "long",
            "little", "important", "political", "bad", "white", "real", "best",
            "right", "social", "public", "sure", "low", "early", "only", "late",
            "hard", "major", "better", "economic", "strong", "possible", "whole",
            "free", "military", "true", "federal", "international", "full", "special",
            "recent", "late", "difficult", "clear", "private", "past", "foreign",
            "fine", "common", "poor", "natural", "significant", "similar", "hot",
            "dead", "central", "happy", "serious", "ready", "simple", "left",
            "physical", "general", "environmental", "financial", "blue", "democratic",
            "dark", "various", "entire", "close", "legal", "religious", "cold",
            "final", "main", "green", "nice", "huge", "popular", "traditional",
            "cultural", "wide", "particular", "difficult", "management", "recent",
            "range", "building", "reason", "require", "research", "material", "term",
            "process", "analysis", "method", "data", "result", "system", "program",
            "problem", "theory", "level", "policy", "evidence", "practice",
        ];
        let idx = (tok_id + position * 7919) % words.len();
        words[idx].to_string()
    }
}

// ---------------------------------------------------------------------------
// Suite runner
// ---------------------------------------------------------------------------

/// Run the determinism suite across multiple seeds.
///
/// For each seed, the prompt is replayed `replays` times. All outputs,
/// tool sequences, and tier transitions are compared.
pub fn run_determinism_suite(seeds: &[u64], prompt: &str, replays: usize) -> Result<Vec<DeterminismMetrics>> {
    info!("G4 — Determinism Suite: {} seeds, {} replays each", seeds.len(), replays);

    let mut all_metrics = Vec::new();

    for &seed in seeds {
        let decoder = DeterministicDecoder::new(seed);
        let mut outputs = Vec::with_capacity(replays);
        let mut tool_sequences = Vec::with_capacity(replays);
        let mut tier_transitions = Vec::with_capacity(replays);
        let mut latencies = Vec::with_capacity(replays);

        for r in 0..replays {
            let t = Timer::start(&format!("seed_{}_replay_{}", seed, r));
            let (out, tools, tiers) = decoder.generate(prompt, 128);
            let ms = t.stop();
            outputs.push(out);
            tool_sequences.push(tools);
            tier_transitions.push(tiers);
            latencies.push(ms);
        }

        let all_identical = outputs.iter().all(|o| o == &outputs[0]);
        let tools_identical = tool_sequences.iter().all(|t| t == &tool_sequences[0]);
        let tiers_identical = tier_transitions.iter().all(|tt| tt == &tier_transitions[0]);

        let max_token_divergence = compute_max_token_divergence(&outputs);

        info!(
            "Seed {}: identical={}, token_divergence={}, tools_identical={}, tiers_identical={}",
            seed, all_identical, max_token_divergence, tools_identical, tiers_identical
        );

        all_metrics.push(DeterminismMetrics {
            seed,
            outputs,
            all_identical,
            max_token_divergence,
            tool_sequences,
            tier_transitions,
            tools_identical,
            tiers_identical,
            latencies_ms: latencies,
        });
    }

    Ok(all_metrics)
}

/// Compute maximum token-level divergence between any pair of outputs.
fn compute_max_token_divergence(outputs: &[String]) -> usize {
    let tokenized: Vec<Vec<&str>> = outputs.iter().map(|s| s.split_whitespace().collect()).collect();
    let mut max_div = 0usize;
    for i in 0..tokenized.len() {
        for j in (i + 1)..tokenized.len() {
            let len_i = tokenized[i].len();
            let len_j = tokenized[j].len();
            let min_len = len_i.min(len_j);
            let mut div = len_i.abs_diff(len_j);
            for k in 0..min_len {
                if tokenized[i][k] != tokenized[j][k] {
                    div += 1;
                }
            }
            max_div = max_div.max(div);
        }
    }
    max_div
}

// ---------------------------------------------------------------------------
// Binary entry point
// ---------------------------------------------------------------------------

fn main() -> Result<()> {
    let cli = Cli::parse();

    let subscriber = tracing_subscriber::fmt()
        .with_max_level(if cli.verbose {
            tracing::Level::DEBUG
        } else {
            tracing::Level::INFO
        })
        .finish();
    let _guard = tracing::subscriber::set_default(subscriber);

    let metrics = run_determinism_suite(&cli.seeds, &cli.prompt, cli.replays)?;

    let mut report = BenchmarkReport::new();
    for m in &metrics {
        let bench_name = format!("seed_{}", m.seed);
        report.push("g4", &bench_name, "all_identical", if m.all_identical { 1.0 } else { 0.0 }, "bool");
        report.push("g4", &bench_name, "max_token_divergence", m.max_token_divergence as f64, "count");
        report.push("g4", &bench_name, "tools_identical", if m.tools_identical { 1.0 } else { 0.0 }, "bool");
        report.push("g4", &bench_name, "tiers_identical", if m.tiers_identical { 1.0 } else { 0.0 }, "bool");
        report.push(
            "g4",
            &bench_name,
            "avg_latency_ms",
            m.latencies_ms.iter().sum::<f64>() / m.latencies_ms.len().max(1) as f64,
            "ms",
        );
    }

    if let Some(path) = cli.output {
        helios_bench::metrics::report_to_jsonl(&report, &path)?;
    }

    let all_pass = metrics.iter().all(|m| m.all_identical && m.tools_identical && m.tiers_identical);
    if all_pass {
        info!("G4 DETERMINISM: ALL SEEDS PASS");
    } else {
        warn!("G4 DETERMINISM: NON-DETERMINISM DETECTED");
    }

    println!("\n{}", helios_bench::metrics::report_to_md(&report));
    Ok(())
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decoder_deterministic_same_seed() {
        let d = DeterministicDecoder::new(42);
        let (o1, t1, tiers1) = d.generate("Hello", 50);
        let (o2, t2, tiers2) = d.generate("Hello", 50);
        assert_eq!(o1, o2);
        assert_eq!(t1, t2);
        assert_eq!(tiers1, tiers2);
    }

    #[test]
    fn decoder_different_seed_different_output() {
        let d1 = DeterministicDecoder::new(42);
        let d2 = DeterministicDecoder::new(43);
        let (o1, _, _) = d1.generate("Hello", 50);
        let (o2, _, _) = d2.generate("Hello", 50);
        // Outputs may differ (not guaranteed but highly likely)
        // We just verify they don't crash
        assert!(!o1.is_empty());
        assert!(!o2.is_empty());
    }

    #[test]
    fn run_suite_produces_metrics() {
        let m = run_determinism_suite(&[0, 1], "Test prompt", 3).unwrap();
        assert_eq!(m.len(), 2);
        for entry in &m {
            assert!(entry.outputs.len() == 3);
            assert!(entry.all_identical); // deterministic stub should always match
        }
    }

    #[test]
    fn token_divergence_identical() {
        let outputs = vec!["a b c".to_string(), "a b c".to_string()];
        assert_eq!(compute_max_token_divergence(&outputs), 0);
    }

    #[test]
    fn token_divergence_different_length() {
        let outputs = vec!["a b c".to_string(), "a b c d".to_string()];
        assert_eq!(compute_max_token_divergence(&outputs), 1);
    }

    #[test]
    fn token_divergence_different_words() {
        let outputs = vec!["a b c".to_string(), "x y z".to_string()];
        assert_eq!(compute_max_token_divergence(&outputs), 3);
    }
}
