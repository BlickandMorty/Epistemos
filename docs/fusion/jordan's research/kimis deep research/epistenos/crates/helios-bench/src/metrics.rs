//! Shared metrics types, reporting, and statistical utilities for all benchmarks.
//!
//! This module provides:
//!
//! - `BenchmarkReport` — a container that collects all benchmark results
//! - `StatisticalSummary` — mean, median, p95, stddev with confidence intervals
//! - `report_to_jsonl` — append-only JSONL serialization
//! - `report_to_md` — human-readable markdown summary
//! - `compare_runs` — regression detection between baseline and current

use std::collections::HashMap;
use std::fmt::Write as FmtWrite;
use std::fs::{File, OpenOptions};
use std::io::{BufWriter, Write};
use std::path::Path;
use std::time::{Duration, Instant};

use anyhow::{Context, Result};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use tracing::{debug, info, warn};

// ---------------------------------------------------------------------------
// Core types
// ---------------------------------------------------------------------------

/// A single measurement record in JSONL format.
///
/// Each benchmark emits one or more `BenchmarkRecord` rows. The `gate`
/// field identifies which of the six validation gates produced the row.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct BenchmarkRecord {
    /// ISO-8601 timestamp of the measurement.
    pub timestamp: String,
    /// Gate identifier: g1 … g6.
    pub gate: String,
    /// Benchmark name within the gate.
    pub benchmark: String,
    /// Metric name (e.g. "kl_divergence", "accuracy_at_32k").
    pub metric: String,
    /// Numeric value.
    pub value: f64,
    /// Unit of measurement.
    pub unit: String,
    /// Optional human-readable context.
    pub note: Option<String>,
}

/// A full benchmark report containing all records plus metadata.
///
/// `BenchmarkReport` is the primary interchange structure. It can be
/// serialized to JSONL (one row per record) or rendered to Markdown.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct BenchmarkReport {
    /// Report generation timestamp.
    pub generated_at: String,
    /// Git revision or build identifier.
    pub revision: String,
    /// Hostname where the benchmark ran.
    pub hostname: String,
    /// All measurement records.
    pub records: Vec<BenchmarkRecord>,
    /// Any fatal or non-fatal errors encountered.
    pub errors: Vec<String>,
}

impl BenchmarkReport {
    /// Create a new empty report with current metadata.
    pub fn new() -> Self {
        Self {
            generated_at: Utc::now().to_rfc3339(),
            revision: option_env!("HELIOS_REVISION")
                .unwrap_or("unknown")
                .to_string(),
            hostname: std::process::Command::new("hostname")
                .output()
                .ok()
                .and_then(|o| String::from_utf8(o.stdout).ok())
                .unwrap_or_else(|| "unknown".to_string())
                .trim()
                .to_string(),
            records: Vec::new(),
            errors: Vec::new(),
        }
    }

    /// Append a single record.
    pub fn push(&mut self, gate: &str, benchmark: &str, metric: &str, value: f64, unit: &str) {
        self.records.push(BenchmarkRecord {
            timestamp: Utc::now().to_rfc3339(),
            gate: gate.to_string(),
            benchmark: benchmark.to_string(),
            metric: metric.to_string(),
            value,
            unit: unit.to_string(),
            note: None,
        });
    }

    /// Append a record with a note.
    pub fn push_note(
        &mut self,
        gate: &str,
        benchmark: &str,
        metric: &str,
        value: f64,
        unit: &str,
        note: &str,
    ) {
        self.records.push(BenchmarkRecord {
            timestamp: Utc::now().to_rfc3339(),
            gate: gate.to_string(),
            benchmark: benchmark.to_string(),
            metric: metric.to_string(),
            value,
            unit: unit.to_string(),
            note: Some(note.to_string()),
        });
    }

    /// Log an error without failing the whole suite.
    pub fn log_error(&mut self, msg: String) {
        warn!("Benchmark error: {}", msg);
        self.errors.push(msg);
    }

    /// Return records filtered by gate.
    pub fn by_gate(&self, gate: &str) -> Vec<&BenchmarkRecord> {
        self.records.iter().filter(|r| r.gate == gate).collect()
    }

    /// Return records filtered by benchmark name.
    pub fn by_benchmark(&self, benchmark: &str) -> Vec<&BenchmarkRecord> {
        self.records
            .iter()
            .filter(|r| r.benchmark == benchmark)
            .collect()
    }
}

// ---------------------------------------------------------------------------
// Statistical summary
// ---------------------------------------------------------------------------

/// Statistical summary of a sample with confidence intervals.
///
/// Computed from a vector of `f64` observations. The 95 % confidence
/// interval uses the normal approximation (mean ± 1.96·SE).
#[derive(Clone, Copy, Debug, Default, Serialize, Deserialize, PartialEq)]
pub struct StatisticalSummary {
    /// Number of observations.
    pub n: usize,
    /// Sample mean.
    pub mean: f64,
    /// Sample median (via sorting).
    pub median: f64,
    /// 95th percentile.
    pub p95: f64,
    /// Sample standard deviation (Bessel-corrected).
    pub stddev: f64,
    /// Standard error of the mean.
    pub sem: f64,
    /// Lower bound of 95 % confidence interval.
    pub ci_lower: f64,
    /// Upper bound of 95 % confidence interval.
    pub ci_upper: f64,
    /// Minimum observed value.
    pub min: f64,
    /// Maximum observed value.
    pub max: f64,
}

impl StatisticalSummary {
    /// Compute a `StatisticalSummary` from a slice of observations.
    ///
    /// Returns `None` if the slice is empty.
    pub fn from_slice(data: &[f64]) -> Option<Self> {
        if data.is_empty() {
            return None;
        }
        let n = data.len();
        let mut sorted = data.to_vec();
        sorted.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));

        let mean = sorted.iter().sum::<f64>() / n as f64;
        let variance = if n > 1 {
            sorted.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / (n - 1) as f64
        } else {
            0.0
        };
        let stddev = variance.sqrt();
        let sem = stddev / (n as f64).sqrt();
        let ci_delta = 1.96 * sem;

        let median = if n % 2 == 0 {
            (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
        } else {
            sorted[n / 2]
        };

        let p95_idx = ((n as f64) * 0.95).ceil() as usize;
        let p95_idx = p95_idx.min(n - 1);
        let p95 = sorted[p95_idx];

        Some(Self {
            n,
            mean,
            median,
            p95,
            stddev,
            sem,
            ci_lower: mean - ci_delta,
            ci_upper: mean + ci_delta,
            min: sorted[0],
            max: sorted[n - 1],
        })
    }

    /// Format as a compact human-readable string.
    pub fn fmt_compact(&self) -> String {
        format!(
            "mean={:.4} (CI95 {:.4}..{:.4}), median={:.4}, p95={:.4}, std={:.4} [n={}]",
            self.mean, self.ci_lower, self.ci_upper, self.median, self.p95, self.stddev, self.n
        )
    }
}

// ---------------------------------------------------------------------------
// JSONL reporting
// ---------------------------------------------------------------------------

/// Serialize a `BenchmarkReport` to a JSONL file.
///
/// Each `BenchmarkRecord` becomes one line of JSON. The file is opened in
/// append mode if it already exists, so multiple benchmark invocations can
/// write to the same log.
///
/// # Errors
///
/// Returns `Err` if the file cannot be opened or written.
pub fn report_to_jsonl(report: &BenchmarkReport, path: &Path) -> Result<()> {
    let file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)
        .with_context(|| format!("Failed to open JSONL output at {}", path.display()))?;

    let mut writer = BufWriter::new(file);

    for record in &report.records {
        let line = serde_json::to_string(record)
            .with_context(|| "Failed to serialize BenchmarkRecord")?;
        writeln!(writer, "{}", line)
            .with_context(|| format!("Failed to write to {}", path.display()))?;
    }

    writer.flush().with_context(|| "Failed to flush JSONL writer")?;
    info!(
        "Wrote {} records to JSONL at {}",
        report.records.len(),
        path.display()
    );
    Ok(())
}

// ---------------------------------------------------------------------------
// Markdown reporting
// ---------------------------------------------------------------------------

/// Render a `BenchmarkReport` as a Markdown summary.
///
/// The markdown includes a header, per-gate tables, statistical summaries,
/// and an error section if any errors occurred.
pub fn report_to_md(report: &BenchmarkReport) -> String {
    let mut md = String::new();

    writeln!(
        md,
        "# Helios Benchmark Report\n\n"
    )
    .unwrap();
    writeln!(
        md,
        "- **Generated:** {}\n- **Revision:** {}\n- **Hostname:** {}\n",
        report.generated_at, report.revision, report.hostname
    )
    .unwrap();

    // Group records by gate → benchmark → metric
    let mut grouped: HashMap<String, HashMap<String, HashMap<String, Vec<f64>>>> = HashMap::new();
    for rec in &report.records {
        grouped
            .entry(rec.gate.clone())
            .or_default()
            .entry(rec.benchmark.clone())
            .or_default()
            .entry(rec.metric.clone())
            .or_default()
            .push(rec.value);
    }

    for (gate, benches) in &grouped {
        writeln!(md, "## Gate {}\n", gate).unwrap();
        writeln!(
            md,
            "| Benchmark | Metric | N | Mean | Median | P95 | StdDev | CI95 |",
        )
        .unwrap();
        writeln!(
            md,
            "|-----------|--------|---|------|--------|-----|--------|------|",
        )
        .unwrap();

        for (bench, metrics) in benches {
            for (metric, values) in metrics {
                if let Some(summary) = StatisticalSummary::from_slice(values) {
                    writeln!(
                        md,
                        "| {} | {} | {} | {:.4} | {:.4} | {:.4} | {:.4} | {:.4}..{:.4} |",
                        bench,
                        metric,
                        summary.n,
                        summary.mean,
                        summary.median,
                        summary.p95,
                        summary.stddev,
                        summary.ci_lower,
                        summary.ci_upper,
                    )
                    .unwrap();
                }
            }
        }
        writeln!(md).unwrap();
    }

    if !report.errors.is_empty() {
        writeln!(md, "## Errors\n").unwrap();
        for err in &report.errors {
            writeln!(md, "- {}\n", err).unwrap();
        }
    }

    md
}

// ---------------------------------------------------------------------------
// Comparison / regression detection
// ---------------------------------------------------------------------------

/// Result of comparing a baseline report to a current report.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Comparison {
    /// Metrics that improved (lower is better by default; override via tag).
    pub improved: Vec<MetricDelta>,
    /// Metrics that regressed beyond threshold.
    pub regressed: Vec<MetricDelta>,
    /// Metrics that are unchanged within threshold.
    pub unchanged: Vec<MetricDelta>,
    /// Overall pass/fail: true if no regressions.
    pub passes: bool,
}

/// A single metric delta between baseline and current.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MetricDelta {
    /// Gate identifier.
    pub gate: String,
    /// Benchmark name.
    pub benchmark: String,
    /// Metric name.
    pub metric: String,
    /// Baseline mean.
    pub baseline_mean: f64,
    /// Current mean.
    pub current_mean: f64,
    /// Relative change: (current - baseline) / |baseline|.
    pub relative_change: f64,
    /// Whether lower values are better.
    pub lower_is_better: bool,
}

/// Compare two benchmark reports, flagging regressions.
///
/// The default regression threshold is 5 % (configurable). For each metric
/// that appears in both reports, the baseline and current means are compared.
/// If `lower_is_better` is true, a positive relative change > threshold is
/// a regression. If false, a negative relative change with magnitude > threshold
/// is a regression.
///
/// # Arguments
///
/// * `baseline` — the reference benchmark report.
/// * `current` — the new benchmark report.
/// * `threshold` — relative change fraction that triggers a regression (default 0.05).
pub fn compare_runs(
    baseline: &BenchmarkReport,
    current: &BenchmarkReport,
    threshold: Option<f64>,
) -> Comparison {
    let threshold = threshold.unwrap_or(0.05);
    let mut comp = Comparison::default();

    // Build baseline summaries
    let mut base_summaries: HashMap<(String, String, String), StatisticalSummary> = HashMap::new();
    for rec in &baseline.records {
        let key = (rec.gate.clone(), rec.benchmark.clone(), rec.metric.clone());
        // We re-aggregate all matching records; this is a simple but correct approach
        let vals: Vec<f64> = baseline
            .records
            .iter()
            .filter(|r| {
                r.gate == rec.gate && r.benchmark == rec.benchmark && r.metric == rec.metric
            })
            .map(|r| r.value)
            .collect();
        if let Some(s) = StatisticalSummary::from_slice(&vals) {
            base_summaries.insert(key, s);
        }
    }

    // Build current summaries and compare
    let mut seen: HashMap<(String, String, String), bool> = HashMap::new();
    for rec in &current.records {
        let key = (rec.gate.clone(), rec.benchmark.clone(), rec.metric.clone());
        if seen.contains_key(&key) {
            continue;
        }
        seen.insert(key.clone(), true);

        let cur_vals: Vec<f64> = current
            .records
            .iter()
            .filter(|r| {
                r.gate == rec.gate && r.benchmark == rec.benchmark && r.metric == rec.metric
            })
            .map(|r| r.value)
            .collect();
        let cur_summary = match StatisticalSummary::from_slice(&cur_vals) {
            Some(s) => s,
            None => continue,
        };

        let base_summary = match base_summaries.get(&key) {
            Some(s) => *s,
            None => {
                // New metric in current — treat as improvement
                comp.improved.push(MetricDelta {
                    gate: rec.gate.clone(),
                    benchmark: rec.benchmark.clone(),
                    metric: rec.metric.clone(),
                    baseline_mean: 0.0,
                    current_mean: cur_summary.mean,
                    relative_change: f64::INFINITY,
                    lower_is_better: default_lower_is_better(&rec.metric),
                });
                continue;
            }
        };

        let delta = MetricDelta {
            gate: rec.gate.clone(),
            benchmark: rec.benchmark.clone(),
            metric: rec.metric.clone(),
            baseline_mean: base_summary.mean,
            current_mean: cur_summary.mean,
            relative_change: if base_summary.mean.abs() > 1e-12 {
                (cur_summary.mean - base_summary.mean) / base_summary.mean.abs()
            } else {
                0.0
            },
            lower_is_better: default_lower_is_better(&rec.metric),
        };

        let is_regression = if delta.lower_is_better {
            delta.relative_change > threshold
        } else {
            delta.relative_change < -threshold
        };

        let is_improvement = if delta.lower_is_better {
            delta.relative_change < -threshold
        } else {
            delta.relative_change > threshold
        };

        if is_regression {
            comp.regressed.push(delta);
        } else if is_improvement {
            comp.improved.push(delta);
        } else {
            comp.unchanged.push(delta);
        }
    }

    comp.passes = comp.regressed.is_empty();
    comp
}

/// Heuristic: does a lower value mean better performance?
fn default_lower_is_better(metric: &str) -> bool {
    let lower_better = [
        "kl_divergence",
        "peak_ram_mb",
        "reconstruction_time_ms",
        "decode_latency_ms",
        "query_latency_us",
        "perplexity",
        "max_weight_drift",
        "auth_latency_ms",
        "error_rate",
        "token_divergence",
    ];
    let higher_better = [
        "decode_tok_per_sec",
        "memory_reduction_ratio",
        "compression_ratio",
        "pack_throughput_mb_s",
        "unpack_throughput_mb_s",
        "accuracy_at_4k",
        "accuracy_at_32k",
        "accuracy_at_128k",
        "token_validation_rate",
        "forgery_detection_rate",
        "improvement_ratio",
        "consolidation_success",
        "passes_gate",
        "all_identical",
    ];
    if lower_better.iter().any(|m| metric.contains(m)) {
        return true;
    }
    if higher_better.iter().any(|m| metric.contains(m)) {
        return false;
    }
    // Default assumption: lower is better for unknown metrics.
    true
}

// ---------------------------------------------------------------------------
// Timing utilities
// ---------------------------------------------------------------------------

/// A simple wall-clock timer for benchmark sections.
///
/// # Example
/// ```
/// use helios_bench::metrics::Timer;
/// let t = Timer::start("encode");
/// // ... work ...
/// let elapsed_ms = t.elapsed_ms();
/// ```
pub struct Timer {
    label: String,
    start: Instant,
}

impl Timer {
    /// Start a new timer with the given label.
    pub fn start(label: &str) -> Self {
        Self {
            label: label.to_string(),
            start: Instant::now(),
        }
    }

    /// Elapsed time in milliseconds.
    pub fn elapsed_ms(&self) -> f64 {
        let d = self.start.elapsed();
        d.as_secs_f64() * 1000.0
    }

    /// Elapsed time in microseconds.
    pub fn elapsed_us(&self) -> f64 {
        let d = self.start.elapsed();
        d.as_secs_f64() * 1_000_000.0
    }

    /// Consume the timer and return elapsed milliseconds, logging at debug level.
    pub fn stop(self) -> f64 {
        let ms = self.elapsed_ms();
        debug!("Timer [{}] elapsed {:.3} ms", self.label, ms);
        ms
    }
}

// ---------------------------------------------------------------------------
// Memory measurement helpers (cross-platform stubs where needed)
// ---------------------------------------------------------------------------

/// Attempt to read current process RSS in megabytes.
///
/// On Linux this reads `/proc/self/status`. On macOS it uses `task_info`.
/// If neither is available, returns 0.0.
pub fn current_rss_mb() -> f64 {
    #[cfg(target_os = "linux")]
    {
        if let Ok(content) = std::fs::read_to_string("/proc/self/status") {
            for line in content.lines() {
                if line.starts_with("VmRSS:") {
                    let parts: Vec<&str> = line.split_whitespace().collect();
                    if parts.len() >= 2 {
                        if let Ok(kb) = parts[1].parse::<f64>() {
                            return kb / 1024.0;
                        }
                    }
                }
            }
        }
    }
    #[cfg(target_os = "macos")]
    {
        // macOS RSS via libc::task_info is nontrivial to bind; stub for now.
        // In a full build this would call into helios-metal.
        return 0.0;
    }
    0.0
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn statistical_summary_basic() {
        let data = vec![1.0, 2.0, 3.0, 4.0, 5.0];
        let s = StatisticalSummary::from_slice(&data).unwrap();
        assert_eq!(s.n, 5);
        assert!((s.mean - 3.0).abs() < 1e-9);
        assert!((s.median - 3.0).abs() < 1e-9);
        assert!(s.stddev > 0.0);
        assert!(s.ci_lower < s.mean);
        assert!(s.ci_upper > s.mean);
    }

    #[test]
    fn statistical_summary_empty() {
        assert!(StatisticalSummary::from_slice(&[]).is_none());
    }

    #[test]
    fn report_push_and_filter() {
        let mut r = BenchmarkReport::new();
        r.push("g1", "kv_direct_32", "kl_divergence", 0.003, "");
        r.push("g1", "kv_direct_64", "kl_divergence", 0.005, "");
        r.push("g2", "needle", "accuracy_at_32k", 0.92, "");
        assert_eq!(r.by_gate("g1").len(), 2);
        assert_eq!(r.by_benchmark("needle").len(), 1);
    }

    #[test]
    fn report_to_jsonl_roundtrip() {
        let mut r = BenchmarkReport::new();
        r.push("g1", "kv", "kl", 0.001, "f32");
        let tmp = std::env::temp_dir().join("helios_bench_test.jsonl");
        report_to_jsonl(&r, &tmp).unwrap();
        let content = std::fs::read_to_string(&tmp).unwrap();
        assert!(content.contains("kl"));
        std::fs::remove_file(&tmp).ok();
    }

    #[test]
    fn report_to_md_contains_header() {
        let mut r = BenchmarkReport::new();
        r.push("g1", "kv", "kl", 0.001, "f32");
        let md = report_to_md(&r);
        assert!(md.contains("Helios Benchmark Report"));
        assert!(md.contains("kl"));
    }

    #[test]
    fn compare_runs_detects_regression() {
        let mut base = BenchmarkReport::new();
        base.push("g1", "kv", "kl_divergence", 0.001, "");
        let mut cur = BenchmarkReport::new();
        cur.push("g1", "kv", "kl_divergence", 0.100, ""); // huge regression
        let comp = compare_runs(&base, &cur, None);
        assert!(!comp.passes);
        assert!(!comp.regressed.is_empty());
    }

    #[test]
    fn compare_runs_detects_improvement() {
        let mut base = BenchmarkReport::new();
        base.push("g1", "kv", "decode_tok_per_sec", 10.0, "");
        let mut cur = BenchmarkReport::new();
        cur.push("g1", "kv", "decode_tok_per_sec", 15.0, ""); // 50% improvement
        let comp = compare_runs(&base, &cur, None);
        assert!(comp.passes);
        assert!(!comp.improved.is_empty());
    }

    #[test]
    fn timer_measures_time() {
        let t = Timer::start("test");
        std::thread::sleep(std::time::Duration::from_millis(5));
        let ms = t.stop();
        assert!(ms >= 4.0, "Timer reported {:.3} ms", ms);
    }
}
