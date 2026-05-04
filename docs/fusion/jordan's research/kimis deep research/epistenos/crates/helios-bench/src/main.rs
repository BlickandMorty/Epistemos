//! `helios-bench` — Main benchmark runner.
//!
//! This is the central CLI entry point for all six validation gates:
//!
//! ```text
//! helios-bench g1-kv-direct --model <path> --prompts <path>
//! helios-bench g2-recall --suite ruler
//! helios-bench g3-memory --tiers all
//! helios-bench g4-determinism --seeds 100
//! helios-bench g5-self-tuning --steps 1000
//! helios-bench g6-vault-security --iterations 100
//! ```
//!
//! Global flags apply to all subcommands:
//! `--output <jsonl>`, `--verbose`, `--warmup`

use std::path::PathBuf;
use std::time::Duration;

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use tracing::{info, warn};

use helios_bench::g1_kv_direct::{run_g1, DecodeMode, G1Config};
use helios_bench::g2_recall::{run_recall_suite, RecallSuite};
use helios_bench::g3_memory::{run_memory_benchmark, MemoryConfig};
use helios_bench::g4_determinism::run_determinism_suite;
use helios_bench::g5_self_tuning::run_self_tuning_benchmark;
use helios_bench::g6_vault_security::run_vault_security;
use helios_bench::metrics::{compare_runs, report_to_jsonl, BenchmarkReport};

// ---------------------------------------------------------------------------
// Global CLI
// ---------------------------------------------------------------------------

/// Helios benchmark runner — empirical validation for the Epistenos architecture.
#[derive(Parser, Debug)]
#[command(name = "helios-bench", version, about = "Benchmarks and test harnesses for Epistenos")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
    /// Output JSONL path for all results.
    #[arg(long, global = true)]
    output: Option<PathBuf>,
    /// Enable verbose (debug) logging.
    #[arg(long, global = true)]
    verbose: bool,
    /// Number of warmup iterations before measurement.
    #[arg(long, global = true, default_value_t = 1)]
    warmup: usize,
    /// Baseline JSONL path for regression comparison.
    #[arg(long, global = true)]
    baseline: Option<PathBuf>,
}

// ---------------------------------------------------------------------------
// Subcommands
// ---------------------------------------------------------------------------

#[derive(Subcommand, Debug)]
enum Commands {
    /// G1 — KV-Direct gate experiment (THE architecture gate).
    G1KvDirect {
        /// Model weights path.
        #[arg(long)]
        model: PathBuf,
        /// Prompts JSONL path.
        #[arg(long)]
        prompts: PathBuf,
        /// Decode mode.
        #[arg(long, value_enum, default_value = "greedy")]
        decode_mode: DecodeMode,
        /// Max new tokens.
        #[arg(long, default_value_t = 128)]
        max_new_tokens: usize,
        /// Checkpoint intervals.
        #[arg(long, value_delimiter = ',', default_values_t = vec![32, 64, 128])]
        checkpoint_intervals: Vec<usize>,
    },
    /// G2 — Long-context recall benchmark.
    G2Recall {
        /// Recall suite to run.
        #[arg(long, value_enum, default_value = "ruler-needle")]
        suite: RecallSuite,
        /// Model weights path (optional).
        #[arg(long)]
        model: Option<PathBuf>,
    },
    /// G3 — Memory budget validation across tiers.
    G3Memory {
        /// Tiers to test (comma-separated or "all").
        #[arg(long, default_value = "all")]
        tiers: String,
        /// Data size in MB per tier.
        #[arg(long, default_value_t = 16)]
        data_mb: usize,
        /// Number of query iterations.
        #[arg(long, default_value_t = 1000)]
        queries: usize,
    },
    /// G4 — Seeded replay determinism.
    G4Determinism {
        /// Seeds to test.
        #[arg(long, value_delimiter = ',', default_values_t = vec![0, 1, 42, 12345])]
        seeds: Vec<u64>,
        /// Number of replays per seed.
        #[arg(long, default_value_t = 5)]
        replays: usize,
        /// Prompt for determinism testing.
        #[arg(long, default_value = "What is 2+2? Explain your reasoning.")]
        prompt: String,
    },
    /// G5 — Titans-MAC self-tuning coherence.
    G5SelfTuning {
        /// Number of conversation steps.
        #[arg(long, default_value_t = 1000)]
        steps: usize,
        /// Fast-weight learning rate.
        #[arg(long, default_value_t = 0.001)]
        fast_lr: f64,
        /// Consolidation interval.
        #[arg(long, default_value_t = 100)]
        consolidate_every: usize,
    },
    /// G6 — Vault security (biometric, HMAC, permissions).
    G6VaultSecurity {
        /// Number of iterations.
        #[arg(long, default_value_t = 100)]
        iterations: usize,
    },
    /// Run ALL gates sequentially and produce a combined report.
    All {
        /// Model path (used by G1 and G2).
        #[arg(long)]
        model: Option<PathBuf>,
        /// Prompts path (used by G1).
        #[arg(long)]
        prompts: Option<PathBuf>,
    },
}

// ---------------------------------------------------------------------------
// Main entry
// ---------------------------------------------------------------------------

fn main() -> Result<()> {
    let cli = Cli::parse();

    let max_level = if cli.verbose {
        tracing::Level::DEBUG
    } else {
        tracing::Level::INFO
    };
    let subscriber = tracing_subscriber::fmt()
        .with_max_level(max_level)
        .finish();
    let _guard = tracing::subscriber::set_default(subscriber);

    info!("helios-bench starting — {:?}", cli.command);

    let mut report = BenchmarkReport::new();

    match &cli.command {
        Commands::G1KvDirect {
            model,
            prompts,
            decode_mode,
            max_new_tokens,
            checkpoint_intervals,
        } => {
            let config = G1Config {
                model_path: model.clone(),
                prompts_path: prompts.clone(),
                decode_mode: *decode_mode,
                max_new_tokens: *max_new_tokens,
                checkpoint_intervals: checkpoint_intervals.clone(),
                warmup: cli.warmup,
            };
            let results = run_g1(&config)?;
            for res in &results {
                let bench = format!("kv_direct_{}", res.checkpoint_interval);
                report.push("g1", &bench, "kl_divergence", res.kl_divergence as f64, "f32");
                report.push("g1", &bench, "decode_tok_per_sec", res.decode_tok_per_sec as f64, "tok/s");
                report.push("g1", &bench, "memory_reduction_ratio", res.memory_reduction_ratio as f64, "ratio");
                report.push("g1", &bench, "passes_gate", if res.passes_gate { 1.0 } else { 0.0 }, "bool");
            }
            let all_pass = results.iter().all(|r| r.passes_gate);
            println!("\nG1 GATE: {}", if all_pass { "PASS" } else { "FAIL" });
        }

        Commands::G2Recall { suite, model } => {
            let model_path = model.as_deref().unwrap_or(std::path::Path::new("/dev/null"));
            let metrics = run_recall_suite(*suite, model_path)?;
            report.push("g2", &metrics.suite_name, "accuracy_at_4k", metrics.accuracy_at_4k as f64, "ratio");
            report.push("g2", &metrics.suite_name, "accuracy_at_32k", metrics.accuracy_at_32k as f64, "ratio");
            report.push("g2", &metrics.suite_name, "accuracy_at_128k", metrics.accuracy_at_128k as f64, "ratio");
            report.push("g2", &metrics.suite_name, "avg_latency_ms", metrics.avg_latency_ms as f64, "ms");
        }

        Commands::G3Memory { tiers, data_mb, queries } => {
            let config = MemoryConfig {
                tiers: MemoryConfig::parse_tiers(tiers),
                data_mb: *data_mb,
                queries: *queries,
            };
            let metrics = run_memory_benchmark(&config)?;
            for m in &metrics {
                let bench = format!("{:?}", m.tier);
                report.push("g3", &bench, "compression_ratio", m.compression_ratio as f64, "ratio");
                report.push("g3", &bench, "pack_throughput_mb_s", m.pack_throughput_mb_s as f64, "MB/s");
                report.push("g3", &bench, "query_latency_us", m.query_latency_us as f64, "us");
                report.push("g3", &bench, "quality_score", m.quality_score as f64, "ratio");
            }
        }

        Commands::G4Determinism { seeds, replays, prompt } => {
            let metrics = run_determinism_suite(seeds, prompt, *replays)?;
            for m in &metrics {
                let bench = format!("seed_{}", m.seed);
                report.push("g4", &bench, "all_identical", if m.all_identical { 1.0 } else { 0.0 }, "bool");
                report.push("g4", &bench, "max_token_divergence", m.max_token_divergence as f64, "count");
                report.push("g4", &bench, "tools_identical", if m.tools_identical { 1.0 } else { 0.0 }, "bool");
                report.push("g4", &bench, "tiers_identical", if m.tiers_identical { 1.0 } else { 0.0 }, "bool");
            }
        }

        Commands::G5SelfTuning {
            steps,
            fast_lr,
            consolidate_every,
        } => {
            let metrics = run_self_tuning_benchmark(*steps, *fast_lr, *consolidate_every)?;
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
        }

        Commands::G6VaultSecurity { iterations } => {
            let metrics = run_vault_security(*iterations)?;
            report.push("g6", "vault", "auth_latency_ms", metrics.auth_latency_ms as f64, "ms");
            report.push("g6", "vault", "token_validation_rate", metrics.token_validation_rate as f64, "tok/s");
            report.push("g6", "vault", "forgery_detection_rate", metrics.forgery_detection_rate as f64, "ratio");
            report.push(
                "g6",
                "vault",
                "permission_violation_blocked",
                if metrics.permission_violation_blocked { 1.0 } else { 0.0 },
                "bool",
            );
        }

        Commands::All { model, prompts } => {
            run_all_gates(&cli, model.as_ref(), prompts.as_ref(), &mut report)?;
        }
    }

    // Write JSONL output
    if let Some(path) = cli.output {
        report_to_jsonl(&report, &path)?;
    }

    // Regression comparison
    if let Some(base_path) = cli.baseline {
        let base_content = std::fs::read_to_string(&base_path)
            .with_context(|| format!("Failed to read baseline {}", base_path.display()))?;
        let mut baseline = BenchmarkReport::new();
        for line in base_content.lines() {
            if line.trim().is_empty() {
                continue;
            }
            if let Ok(record) = serde_json::from_str::<helios_bench::metrics::BenchmarkRecord>(line) {
                baseline.records.push(record);
            }
        }
        let comparison = compare_runs(&baseline, &report, None);
        println!("\n## Regression Comparison\n");
        println!("Passes: {}", comparison.passes);
        if !comparison.regressed.is_empty() {
            println!("\n### Regressed Metrics\n");
            for r in &comparison.regressed {
                println!(
                    "- {}::{}::{}: {:.4} → {:.4} ({:+.1}%)",
                    r.gate, r.benchmark, r.metric,
                    r.baseline_mean, r.current_mean,
                    r.relative_change * 100.0
                );
            }
        }
        if !comparison.improved.is_empty() {
            println!("\n### Improved Metrics\n");
            for i in &comparison.improved {
                println!(
                    "- {}::{}::{}: {:.4} → {:.4} ({:+.1}%)",
                    i.gate, i.benchmark, i.metric,
                    i.baseline_mean, i.current_mean,
                    i.relative_change * 100.0
                );
            }
        }
    }

    // Always print markdown summary to stdout
    println!("\n{}", helios_bench::metrics::report_to_md(&report));

    Ok(())
}

/// Run all six gates sequentially.
fn run_all_gates(
    cli: &Cli,
    model: Option<&PathBuf>,
    prompts: Option<&PathBuf>,
    report: &mut BenchmarkReport,
) -> Result<()> {
    info!("Running ALL gates sequentially");

    // G1
    if let (Some(m), Some(p)) = (model, prompts) {
        let config = G1Config {
            model_path: m.clone(),
            prompts_path: p.clone(),
            decode_mode: DecodeMode::Greedy,
            max_new_tokens: 128,
            checkpoint_intervals: vec![32, 64, 128],
            warmup: cli.warmup,
        };
        let g1 = run_g1(&config)?;
        for res in &g1 {
            let bench = format!("kv_direct_{}", res.checkpoint_interval);
            report.push("g1", &bench, "kl_divergence", res.kl_divergence as f64, "f32");
            report.push("g1", &bench, "decode_tok_per_sec", res.decode_tok_per_sec as f64, "tok/s");
            report.push("g1", &bench, "passes_gate", if res.passes_gate { 1.0 } else { 0.0 }, "bool");
        }
    } else {
        warn!("Skipping G1 — model and prompts required");
        report.log_error("G1 skipped: missing --model or --prompts".to_string());
    }

    // G2
    let model_path = model.map(|p| p.as_path()).unwrap_or(std::path::Path::new("/dev/null"));
    let g2 = run_recall_suite(RecallSuite::RulerNeedle, model_path)?;
    report.push("g2", &g2.suite_name, "accuracy_at_4k", g2.accuracy_at_4k as f64, "ratio");
    report.push("g2", &g2.suite_name, "accuracy_at_32k", g2.accuracy_at_32k as f64, "ratio");
    report.push("g2", &g2.suite_name, "accuracy_at_128k", g2.accuracy_at_128k as f64, "ratio");

    // G3
    let g3 = run_memory_benchmark(&MemoryConfig {
        tiers: MemoryConfig::parse_tiers("all"),
        data_mb: 16,
        queries: 1000,
    })?;
    for m in &g3 {
        let bench = format!("{:?}", m.tier);
        report.push("g3", &bench, "compression_ratio", m.compression_ratio as f64, "ratio");
        report.push("g3", &bench, "quality_score", m.quality_score as f64, "ratio");
    }

    // G4
    let g4 = run_determinism_suite(&[0, 1, 42], "Test prompt for determinism.", 3)?;
    for m in &g4 {
        let bench = format!("seed_{}", m.seed);
        report.push("g4", &bench, "all_identical", if m.all_identical { 1.0 } else { 0.0 }, "bool");
    }

    // G5
    let g5 = run_self_tuning_benchmark(200, 0.001, 50)?;
    report.push("g5", "self_tuning", "improvement_ratio", g5.improvement_ratio as f64, "ratio");
    report.push("g5", "self_tuning", "max_weight_drift", g5.max_weight_drift as f64, "L2");

    // G6
    let g6 = run_vault_security(100)?;
    report.push("g6", "vault", "forgery_detection_rate", g6.forgery_detection_rate as f64, "ratio");
    report.push("g6", "vault", "permission_violation_blocked", if g6.permission_violation_blocked { 1.0 } else { 0.0 }, "bool");

    info!("All gates completed");
    Ok(())
}
