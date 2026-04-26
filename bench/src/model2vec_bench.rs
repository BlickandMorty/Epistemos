//! Wave 8.4 day-1 spike — Model2Vec encode latency on the user's M-series.
//!
//! The W8.4 plan calls for Model2Vec embeddings as the dense-retrieval
//! leg of the Halo Shadow stack (alongside usearch HNSW + tantivy BM25
//! + RRF fusion). The W8.4 research agent flagged Model2Vec as the
//! single highest-risk unknown: v0.1.x port, no published per-platform
//! benchmark, target budget &lt;5 ms p99 / paragraph encode.
//!
//! This binary measures p50 / p95 / p99 / max / throughput for 1000
//! synthetic paragraph encodes against the canonical
//! `minishlab/potion-base-8M` model. Auto-downloads on first run via
//! `hf-hub` (~30 MB cached under `~/.cache/huggingface/hub/`).
//!
//! ## Recorded result on this M-series Mac (2026-04-26)
//!
//! Two consecutive runs from the in-tree bench:
//!
//! ```text
//! cargo run --release --manifest-path bench/Cargo.toml --bin model2vec-bench
//!
//! Run 1 (cold caches, /tmp probe):
//!   p50 = 219 µs   p95 = 350 µs   p99 = 607 µs   max = 1.22 ms
//!   throughput = 4484 samples/sec
//!
//! Run 2 (warm CPU caches, in-tree bench):
//!   p50 = 181 µs   p95 = 270 µs   p99 = 286 µs   max = 314 µs
//!   throughput = 5718 samples/sec
//! ```
//!
//! Verdict: **green light.** Even the cold-cache p99 of 607 µs is
//! **8× under** the 5 ms ceiling the W8.4 plan budgets for a
//! paragraph encode. Throughput is ~4500–5700 samples/sec single-
//! threaded — a vault scan of 10K paragraphs costs ~2 s end-to-end
//! on this hardware. Model2Vec is NOT the W8.4 risk the upstream
//! research feared; the multi-week real-backend commit can proceed
//! with the canonical
//! `model2vec_rs::model::StaticModel::from_pretrained(...)` path
//! without falling back to the `TrigramEmbedder` placeholder.
//!
//! ## How to re-run
//!
//! ```sh
//! cargo run --release --manifest-path bench/Cargo.toml --bin model2vec-bench
//! ```
//!
//! Re-runs are cheap once the model is cached. The first run pays a
//! ~33 s release-mode compile + ~2 s HuggingFace download; subsequent
//! runs are pure encode work.

use std::time::Instant;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    eprintln!("[bench] loading minishlab/potion-base-8M (auto-download via hf-hub)...");
    let model = model2vec_rs::model::StaticModel::from_pretrained(
        "minishlab/potion-base-8M",
        None,
        None,
        None,
    )?;
    eprintln!("[bench] model loaded.");

    // Generate 1000 synthetic paragraphs of varied length (~50–200 words).
    // Lorem-class prose is a fair stand-in for vault prose for encode
    // latency since Model2Vec is static-token + ignores semantics.
    let lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. \
                 Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. \
                 Ut enim ad minim veniam, quis nostrud exercitation ullamco. ";
    let paragraphs: Vec<String> = (0..1000)
        .map(|i| {
            let n = 50 + (i % 150);
            let mut buf = String::with_capacity(n * 10);
            while buf.len() < n * 5 {
                buf.push_str(lorem);
            }
            buf
        })
        .collect();

    eprintln!(
        "[bench] encoding {} paragraphs (warming up first 100)...",
        paragraphs.len()
    );
    // Warmup so the JIT-style overhead inside the tokenizer doesn't
    // skew the first few measurements.
    let _ = model.encode(&paragraphs[..100]);

    let mut latencies = Vec::with_capacity(paragraphs.len());
    let total_start = Instant::now();
    for paragraph in &paragraphs {
        let t = Instant::now();
        // encode takes &[String]; per-paragraph timing means we measure
        // the realistic per-keystroke / per-paragraph editor latency
        // budget rather than the amortised batch throughput.
        let _ = model.encode(std::slice::from_ref(paragraph));
        latencies.push(t.elapsed());
    }
    let total = total_start.elapsed();

    latencies.sort();
    let p50 = latencies[latencies.len() / 2];
    let p95 = latencies[(latencies.len() * 95) / 100];
    let p99 = latencies[(latencies.len() * 99) / 100];
    let max = latencies[latencies.len() - 1];

    println!("[bench] p50 = {:?}", p50);
    println!("[bench] p95 = {:?}", p95);
    println!("[bench] p99 = {:?}", p99);
    println!("[bench] max = {:?}", max);
    println!(
        "[bench] total {} encodes in {:?} → {:.0} samples/sec",
        paragraphs.len(),
        total,
        paragraphs.len() as f64 / total.as_secs_f64()
    );
    Ok(())
}
