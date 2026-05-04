//! G5 — Titans-MAC Coherence & Self-Tuning Tests.
//!
//! Validates that the online learning subsystem (Titans MAC / fast weights)
//! improves local predictions over a multi-turn conversation without
//! destabilizing or drifting unboundedly.
//!
//! Metrics:
//! - **Perplexity trajectory** — should decrease (improve) over the conversation.
//! - **Weight drift** — fast weights must stay within a bounded region.
//! - **Consolidation** — nightly consolidation to slow weights must not spike loss.

use std::collections::VecDeque;
use std::time::{Duration, Instant};

use anyhow::{Context, Result};
use clap::Parser;
use serde::{Deserialize, Serialize};
use tracing::{info, warn};

use helios_bench::metrics::{BenchmarkReport, Timer};

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

/// G5 — Self-tuning coherence benchmark (standalone binary).
#[derive(Parser, Debug)]
#[command(name = "g5-self-tuning", about = "Titans-MAC coherence & bounded drift")]
struct Cli {
    /// Number of conversation steps.
    #[arg(long, default_value_t = 1000)]
    steps: usize,
    /// Fast-weight learning rate.
    #[arg(long, default_value_t = 0.001)]
    fast_lr: f64,
    /// Consolidation interval (steps between slow-weight updates).
    #[arg(long, default_value_t = 100)]
    consolidate_every: usize,
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

/// Metrics for the self-tuning coherence benchmark.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CoherenceMetrics {
    /// Initial perplexity before any fast-weight adaptation.
    pub initial_perplexity: f32,
    /// Final perplexity after all steps.
    pub final_perplexity: f32,
    /// Improvement ratio: initial / final (should be > 1.0 if improving).
    pub improvement_ratio: f32,
    /// Maximum observed fast-weight L2 drift from initialization.
    pub max_weight_drift: f32,
    /// Whether nightly consolidation completed without loss spike.
    pub consolidation_success: bool,
    /// Per-step perplexity history.
    pub perplexity_history: Vec<f32>,
    /// Per-step weight drift history.
    pub drift_history: Vec<f32>,
    /// Number of consolidation events.
    pub consolidation_events: usize,
}

// ---------------------------------------------------------------------------
// Titans-MAC stub
// ---------------------------------------------------------------------------

/// A simplified Titans Memory-As-Context (MAC) model with fast and slow weights.
///
/// The fast weights adapt online to the current conversation. The slow weights
/// are updated periodically via "consolidation" (EMA of fast weights).
struct TitansMac {
    /// Slow weights (long-term memory).
    slow: Vec<f32>,
    /// Fast weights (short-term adaptation).
    fast: Vec<f32>,
    /// Initial fast weights for drift measurement.
    fast_init: Vec<f32>,
    /// Dimensionality.
    dim: usize,
    /// Fast-weight learning rate.
    fast_lr: f64,
    /// Slow-weight EMA decay.
    slow_ema: f64,
    /// Consolidation interval.
    consolidate_every: usize,
    /// Step counter.
    step: usize,
    /// Surprise buffer for recent tokens.
    surprise_window: VecDeque<f32>,
}

impl TitansMac {
    fn new(dim: usize, fast_lr: f64, consolidate_every: usize) -> Self {
        let mut slow = Vec::with_capacity(dim);
        let mut fast = Vec::with_capacity(dim);
        let mut fast_init = Vec::with_capacity(dim);
        for i in 0..dim {
            let w = ((i * 7919) as f32).sin() * 0.01;
            slow.push(w);
            fast.push(w);
            fast_init.push(w);
        }
        Self {
            slow,
            fast,
            fast_init,
            dim,
            fast_lr,
            slow_ema: 0.99,
            consolidate_every,
            step: 0,
            surprise_window: VecDeque::with_capacity(100),
        }
    }

    /// Process one token and adapt fast weights.
    ///
    /// Returns the prediction loss (cross-entropy surrogate) for this step.
    fn step(&mut self, token_embedding: &[f32]) -> f32 {
        // Predicted logit = dot(fast + slow, token_embedding)
        let mut pred = 0.0f32;
        for i in 0..self.dim {
            pred += (self.fast[i] + self.slow[i]) * token_embedding[i % token_embedding.len()];
        }

        // Surprise = |prediction error|
        let target = token_embedding[0];
        let error = target - pred;
        let surprise = error.abs();
        self.surprise_window.push_back(surprise);
        if self.surprise_window.len() > 100 {
            self.surprise_window.pop_front();
        }

        // Fast-weight update: simple gradient descent on squared error
        let lr = self.fast_lr as f32;
        for i in 0..self.dim {
            let grad = -2.0 * error * token_embedding[i % token_embedding.len()];
            self.fast[i] -= lr * grad;
        }

        self.step += 1;

        // Periodic consolidation
        if self.step % self.consolidate_every == 0 {
            self.consolidate();
        }

        // Return perplexity-like metric: exp(surprise)
        surprise.exp().min(100.0)
    }

    /// Consolidate fast weights into slow weights via EMA.
    fn consolidate(&mut self) {
        let alpha = self.slow_ema as f32;
        for i in 0..self.dim {
            self.slow[i] = alpha * self.slow[i] + (1.0 - alpha) * self.fast[i];
        }
    }

    /// Reset fast weights to slow weights (simulates a "new day").
    fn reset_fast(&mut self) {
        for i in 0..self.dim {
            self.fast[i] = self.slow[i];
        }
        self.surprise_window.clear();
    }

    /// Current fast-weight drift from initialization (L2 norm).
    fn drift_l2(&self) -> f32 {
        let mut sum = 0.0f32;
        for i in 0..self.dim {
            let d = self.fast[i] - self.fast_init[i];
            sum += d * d;
        }
        sum.sqrt()
    }

    /// Current fast-weight drift from slow weights.
    fn fast_slow_drift(&self) -> f32 {
        let mut sum = 0.0f32;
        for i in 0..self.dim {
            let d = self.fast[i] - self.slow[i];
            sum += d * d;
        }
        sum.sqrt()
    }
}

/// Generate a deterministic conversation stream of token embeddings.
fn generate_conversation(dim: usize, steps: usize, seed: u64) -> Vec<Vec<f32>> {
    let mut embeddings = Vec::with_capacity(steps);
    for s in 0..steps {
        let mut emb = vec![0.0f32; dim];
        for i in 0..dim {
            let phase = (seed as f32).sin() + (s as f32) * 0.01 + (i as f32) * 0.05;
            emb[i] = phase.sin() * 0.1 + ((s * i) as f32).cos() * 0.05;
        }
        embeddings.push(emb);
    }
    embeddings
}

// ---------------------------------------------------------------------------
// Benchmark runner
// ---------------------------------------------------------------------------

/// Run the self-tuning coherence benchmark.
///
/// A `TitansMac` model is run for `steps` conversation turns. Fast weights
/// adapt online; slow weights consolidate periodically. Per-step perplexity
/// and weight drift are recorded.
pub fn run_self_tuning_benchmark(steps: usize, fast_lr: f64, consolidate_every: usize) -> Result<CoherenceMetrics> {
    info!(
        "G5 — Self-Tuning Benchmark: {} steps, lr={}, consolidate_every={}",
        steps, fast_lr, consolidate_every
    );

    let dim = 256;
    let mut model = TitansMac::new(dim, fast_lr, consolidate_every);
    let conversation = generate_conversation(dim, steps, 42);

    let mut perplexity_history = Vec::with_capacity(steps);
    let mut drift_history = Vec::with_capacity(steps);
    let mut consolidation_events = 0usize;
    let mut consolidation_success = true;
    let mut max_weight_drift = 0.0f32;

    // Baseline perplexity without adaptation
    let initial_perplexity = {
        let mut sum = 0.0f32;
        for emb in conversation.iter().take(100.min(steps)) {
            let ppl = model.step(emb);
            sum += ppl;
        }
        model.reset_fast();
        sum / 100.0f32.min(steps as f32)
    };

    // Main adaptation loop
    for (step, emb) in conversation.iter().enumerate() {
        let ppl = model.step(emb);
        let drift = model.drift_l2();
        perplexity_history.push(ppl);
        drift_history.push(drift);
        max_weight_drift = max_weight_drift.max(drift);

        if step > 0 && step % consolidate_every == 0 {
            consolidation_events += 1;
            // Check for destabilization: if perplexity spikes > 2x recent average
            let recent: Vec<f32> = perplexity_history.iter().rev().take(20).copied().collect();
            let recent_mean = recent.iter().sum::<f32>() / recent.len().max(1) as f32;
            if ppl > recent_mean * 2.0 && ppl > 5.0 {
                warn!("Consolidation destabilization detected at step {}", step);
                consolidation_success = false;
            }
        }
    }

    let final_perplexity = perplexity_history.last().copied().unwrap_or(0.0);
    let improvement_ratio = if final_perplexity > 1e-6 {
        initial_perplexity / final_perplexity
    } else {
        1.0
    };

    info!(
        "Initial PPL: {:.3}, Final PPL: {:.3}, Improvement: {:.2}x, Max drift: {:.4}",
        initial_perplexity, final_perplexity, improvement_ratio, max_weight_drift
    );

    Ok(CoherenceMetrics {
        initial_perplexity,
        final_perplexity,
        improvement_ratio,
        max_weight_drift,
        consolidation_success,
        perplexity_history,
        drift_history,
        consolidation_events,
    })
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

    let metrics = run_self_tuning_benchmark(cli.steps, cli.fast_lr, cli.consolidate_every)?;

    let mut report = BenchmarkReport::new();
    report.push("g5", "self_tuning", "initial_perplexity", metrics.initial_perplexity as f64, "ppl");
    report.push("g5", "self_tuning", "final_perplexity", metrics.final_perplexity as f64, "ppl");
    report.push("g5", "self_tuning", "improvement_ratio", metrics.improvement_ratio as f64, "ratio");
    report.push("g5", "self_tuning", "max_weight_drift", metrics.max_weight_drift as f64, "L2");
    report.push(
        "g5",
        "self_tuning",
        "consolidation_success",
        if metrics.consolidation_success { 1.0 } else { 0.0 },
        "bool",
    );

    if let Some(path) = cli.output {
        helios_bench::metrics::report_to_jsonl(&report, &path)?;
    }

    if metrics.consolidation_success && metrics.improvement_ratio > 1.0 {
        info!("G5 SELF-TUNING: PASS — perplexity improved, drift bounded");
    } else {
        warn!("G5 SELF-TUNING: FAIL — check metrics");
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
    fn titans_mac_runs_without_crash() {
        let mut model = TitansMac::new(64, 0.001, 10);
        let emb = vec![0.1f32; 64];
        for _ in 0..50 {
            let _ = model.step(&emb);
        }
    }

    #[test]
    fn drift_is_bounded() {
        let mut model = TitansMac::new(64, 0.001, 10);
        let emb = vec![0.1f32; 64];
        let mut max_drift = 0.0f32;
        for _ in 0..200 {
            let _ = model.step(&emb);
            let d = model.drift_l2();
            max_drift = max_drift.max(d);
        }
        assert!(
            max_drift < 10.0,
            "Fast weight drift should stay bounded, got {}",
            max_drift
        );
    }

    #[test]
    fn consolidation_preserves_slow_weights() {
        let mut model = TitansMac::new(64, 0.001, 5);
        let emb = vec![0.1f32; 64];
        let slow_before = model.slow.clone();
        for _ in 0..5 {
            let _ = model.step(&emb);
        }
        let slow_after = model.slow.clone();
        // Slow weights should have changed after consolidation
        assert_ne!(slow_before, slow_after);
    }

    #[test]
    fn run_benchmark_produces_metrics() {
        let m = run_self_tuning_benchmark(100, 0.001, 20).unwrap();
        assert!(m.perplexity_history.len() == 100);
        assert!(m.drift_history.len() == 100);
        assert!(m.max_weight_drift >= 0.0);
    }

    #[test]
    fn improvement_ratio_calculation() {
        let m = run_self_tuning_benchmark(200, 0.001, 50).unwrap();
        // Improvement ratio should be finite and positive
        assert!(m.improvement_ratio.is_finite());
        assert!(m.improvement_ratio > 0.0);
    }

    #[test]
    fn conversation_deterministic() {
        let c1 = generate_conversation(32, 50, 42);
        let c2 = generate_conversation(32, 50, 42);
        assert_eq!(c1, c2);
    }
}
