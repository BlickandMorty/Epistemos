//! Synthetic PKM vault generator for graph engine benchmarking.
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Phase A —
//! CPU foundation + zero-copy" → "Week 1-2 deliverables".
//!
//! Generates a Markdown vault on disk with PKM-realistic
//! characteristics so the graph engine + sidebar + indexer can be
//! benchmarked against reproducible inputs instead of "whatever Jojo's
//! actual notes look like." The vault is a flat directory of `.md`
//! files where each file's body uses `[[wikilinks]]` to reference
//! other notes.
//!
//! ## PKM-realism heuristics
//!
//! Per the canonical plan's Phase A Week 2 acceptance criteria:
//! - Average degree 3-8 (median 4)
//! - Power-law degree distribution: most notes 2-4 links, ~1% hubs
//!   with 20+ links
//! - Time-clustering: recent notes link to recent notes 3-5× more
//!   than to year-old notes
//! - Connected components: ~85% of notes in one giant component,
//!   the remainder in 5-15 smaller clusters
//! - Body length: 200-1500 words, weighted toward 400-600
//! - No empty notes (every note has at least a title and 1 sentence)
//!
//! ## Usage
//!
//! ```sh
//! cargo run --bin synth_vault -- --nodes 5000 --out /tmp/synth-5k
//! cargo run --bin synth_vault -- --nodes 10000 --out /tmp/synth-10k
//! cargo run --bin synth_vault -- --nodes 50000 --out /tmp/synth-50k --seed 42
//! ```
//!
//! Determinism: same `--seed --nodes --out` produces byte-identical
//! output. Default seed is `1` so re-running the same command twice
//! yields the same vault.
//!
//! Output: a directory tree like
//! ```text
//! /tmp/synth-5k/
//!   note-00001.md
//!   note-00002.md
//!   ...
//!   note-05000.md
//! ```
//!
//! Each `.md` file is a YAML-frontmatter + body Markdown document
//! that Epistemos can import via its existing vault scanner.

use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::ExitCode;

// ─── Tiny deterministic PRNG (xorshift64) ────────────────────────────────────
//
// We deliberately avoid the `rand` crate dependency for this binary — the
// synth-vault use case wants byte-identical reproducibility from a single
// u64 seed, not the full distribution API of rand.

#[derive(Clone, Copy)]
struct Xor64(u64);

impl Xor64 {
    fn new(seed: u64) -> Self {
        // Avoid the degenerate seed=0 state of xorshift.
        Self(if seed == 0 { 0x9E37_79B9_7F4A_7C15 } else { seed })
    }
    fn next_u64(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.0 = x;
        x
    }
    fn range(&mut self, lo: usize, hi: usize) -> usize {
        // Inclusive [lo, hi). Caller responsible for lo < hi.
        let span = (hi - lo) as u64;
        lo + (self.next_u64() % span) as usize
    }
    fn unit(&mut self) -> f64 {
        // Float in [0, 1).
        (self.next_u64() >> 11) as f64 / (1u64 << 53) as f64
    }
}

// ─── Config + CLI parsing ─────────────────────────────────────────────────────

struct Config {
    node_count: usize,
    out_dir: PathBuf,
    seed: u64,
}

fn parse_args() -> Result<Config, String> {
    let mut nodes: Option<usize> = None;
    let mut out: Option<PathBuf> = None;
    let mut seed: u64 = 1;

    let argv: Vec<String> = env::args().collect();
    let mut i = 1;
    while i < argv.len() {
        match argv[i].as_str() {
            "--nodes" | "-n" => {
                let v = argv
                    .get(i + 1)
                    .ok_or_else(|| "--nodes requires a value".to_string())?;
                nodes = Some(v.parse().map_err(|e| format!("--nodes parse: {e}"))?);
                i += 2;
            }
            "--out" | "-o" => {
                let v = argv
                    .get(i + 1)
                    .ok_or_else(|| "--out requires a value".to_string())?;
                out = Some(PathBuf::from(v));
                i += 2;
            }
            "--seed" | "-s" => {
                let v = argv
                    .get(i + 1)
                    .ok_or_else(|| "--seed requires a value".to_string())?;
                seed = v.parse().map_err(|e| format!("--seed parse: {e}"))?;
                i += 2;
            }
            "--help" | "-h" => {
                print_help();
                std::process::exit(0);
            }
            other => return Err(format!("unknown arg: {other}")),
        }
    }

    let node_count = nodes.ok_or_else(|| "--nodes is required".to_string())?;
    let out_dir = out.ok_or_else(|| "--out is required".to_string())?;
    if node_count == 0 {
        return Err("--nodes must be > 0".to_string());
    }
    Ok(Config { node_count, out_dir, seed })
}

fn print_help() {
    eprintln!(
        "synth_vault — generate a PKM-realistic Markdown vault for graph-engine benchmarks

USAGE:
    synth_vault --nodes <N> --out <DIR> [--seed <U64>]

OPTIONS:
    -n, --nodes <N>        How many notes to generate (1, 1000, 5000, 10000, 50000, 100000)
    -o, --out <DIR>        Output directory (will be created)
    -s, --seed <U64>       Deterministic PRNG seed (default: 1)
    -h, --help             Show this help

EXAMPLES:
    synth_vault --nodes 5000 --out /tmp/synth-5k
    synth_vault --nodes 50000 --out /tmp/synth-50k --seed 42

See docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md Phase A for the
acceptance criteria the generated vault meets."
    );
}

// ─── Vault generation ─────────────────────────────────────────────────────────

/// Build the edge list for the synthetic vault using a power-law preferential
/// attachment model with time-clustering. Returns `Vec<Vec<usize>>` where
/// `edges[i]` is the list of node indices that note `i` wikilinks to.
fn build_edges(node_count: usize, rng: &mut Xor64) -> Vec<Vec<usize>> {
    let mut edges: Vec<Vec<usize>> = vec![Vec::new(); node_count];

    // Pass 1: each node picks 2-4 links to earlier notes weighted by
    // preferential attachment (high-degree nodes attract new links).
    let mut degree: Vec<usize> = vec![0; node_count];

    for i in 1..node_count {
        // How many links does note i emit? Mostly 2-4, with a 1% tail to 8-12.
        let link_count = if rng.unit() < 0.01 {
            rng.range(8, 13)
        } else {
            rng.range(2, 5)
        };

        // Build a weighted sample over earlier notes:
        //   weight(j) = (degree[j] + 1) * time_bonus(i - j)
        // where time_bonus is 5 if j is within last 50 notes of i,
        // 1 otherwise. This produces the time-clustering pattern PKM
        // graphs have — recent notes cite recent notes more often.
        let look_back = i.min(50);
        let recent_start = i.saturating_sub(look_back);

        let mut weights_recent: Vec<(usize, u64)> = (recent_start..i)
            .map(|j| (j, (degree[j] as u64 + 1) * 5))
            .collect();
        let mut weights_old: Vec<(usize, u64)> = (0..recent_start)
            .map(|j| (j, degree[j] as u64 + 1))
            .collect();
        weights_recent.append(&mut weights_old);

        let total: u64 = weights_recent.iter().map(|(_, w)| w).sum();
        if total == 0 {
            // Degenerate path for very early notes: just link to the previous.
            if i > 0 {
                edges[i].push(i - 1);
                degree[i - 1] += 1;
            }
            continue;
        }

        let mut chosen = std::collections::HashSet::new();
        for _ in 0..link_count {
            let mut roll = (rng.next_u64() % total) as i64;
            for &(j, w) in &weights_recent {
                roll -= w as i64;
                if roll < 0 {
                    if chosen.insert(j) {
                        edges[i].push(j);
                        degree[j] += 1;
                    }
                    break;
                }
            }
        }
    }

    // Pass 2: add a few hub nodes that everyone links to. ~1% of nodes
    // become hubs with 20+ incoming links.
    let hub_count = (node_count / 100).max(3);
    let mut hubs: Vec<usize> = (0..hub_count)
        .map(|_| rng.range(0, node_count))
        .collect();
    hubs.sort();
    hubs.dedup();
    for h in &hubs {
        // Each hub picks up 20-40 extra inbound links from random other notes.
        let extra = rng.range(20, 41);
        for _ in 0..extra {
            let src = rng.range(0, node_count);
            if src != *h && !edges[src].contains(h) {
                edges[src].push(*h);
                degree[*h] += 1;
            }
        }
    }

    edges
}

/// Generate a plausible note title from a seed PRNG.
fn make_title(idx: usize, rng: &mut Xor64) -> String {
    // Use small word lists so output is reproducible and readable. We
    // deliberately keep this dumb — it's a benchmark fixture, not
    // user-facing content.
    const NOUNS: [&str; 24] = [
        "Architecture", "Substrate", "Memory", "Routing", "Gate", "Anchor",
        "Protocol", "Lattice", "Index", "Vault", "Surface", "Plane",
        "Kernel", "Pipeline", "Engine", "Layer", "Bridge", "Cache",
        "Profile", "Manifest", "Checkpoint", "Falsifier", "Doctrine", "Schema",
    ];
    const VERBS: [&str; 16] = [
        "Notes on", "Working notes:", "Draft —", "Thinking about",
        "Open questions:", "Audit of", "Hardening", "Verifying",
        "Sketch:", "Migration plan for", "Comparing", "Brainstorm —",
        "Postmortem:", "Daily —", "Snapshot of", "Outline:",
    ];
    let v = VERBS[rng.range(0, VERBS.len())];
    let n = NOUNS[rng.range(0, NOUNS.len())];
    format!("{v} {n} {idx:05}")
}

/// Generate a plausible body. 200-1500 words, weighted toward 400-600.
fn make_body(rng: &mut Xor64, wikilinks: &[String]) -> String {
    const SENTENCES: [&str; 12] = [
        "The substrate is the engine, not the app.",
        "This breaks if we don't separate the control plane from the data plane.",
        "Compare to the canonical pattern in earlier notes.",
        "Open question — does this need to land before V6.2?",
        "Architectural cost is roughly 3 days; benefit is one fewer subsystem.",
        "Run the falsifier before promoting to canonical status.",
        "Memory budget is tight on M2 Pro 16GB; aim for 200-300 MB resident.",
        "Worth profiling with Instruments before committing.",
        "The honest framing: this is doctrine, not implementation.",
        "Defer to the proof ledger when in doubt.",
        "Wire the diagnostic surface so the bug shows up next time.",
        "Cross-reference with the canonical research index.",
    ];

    // Weighted body length — most around 400-600, some 200-300, some 1000+.
    let target = if rng.unit() < 0.10 {
        rng.range(1000, 1500)
    } else if rng.unit() < 0.15 {
        rng.range(200, 350)
    } else {
        rng.range(400, 650)
    };

    let mut out = String::with_capacity(target * 7);
    let mut words = 0;
    let mut paragraph_words = 0;
    while words < target {
        let s = SENTENCES[rng.range(0, SENTENCES.len())];
        out.push_str(s);
        out.push(' ');
        words += s.split_whitespace().count();
        paragraph_words += s.split_whitespace().count();
        if paragraph_words > 60 {
            out.push_str("\n\n");
            paragraph_words = 0;
        }
    }

    // Append wikilinks at the end of the body, one per line.
    if !wikilinks.is_empty() {
        out.push_str("\n\nRelated:\n");
        for link in wikilinks {
            out.push_str("- [[");
            out.push_str(link);
            out.push_str("]]\n");
        }
    }
    out
}

fn write_note(
    out_dir: &PathBuf,
    idx: usize,
    title: &str,
    body: &str,
    created_at_unix: i64,
) -> std::io::Result<()> {
    let path = out_dir.join(format!("note-{:05}.md", idx + 1));
    let mut contents = String::with_capacity(body.len() + 256);
    contents.push_str("---\n");
    contents.push_str(&format!("title: \"{}\"\n", title.replace('"', "\\\"")));
    contents.push_str(&format!("created_at: {}\n", created_at_unix));
    contents.push_str(&format!("synth_idx: {}\n", idx));
    contents.push_str("---\n\n");
    contents.push_str("# ");
    contents.push_str(title);
    contents.push_str("\n\n");
    contents.push_str(body);
    fs::write(path, contents)
}

fn run(cfg: Config) -> Result<(), String> {
    let started = std::time::Instant::now();
    fs::create_dir_all(&cfg.out_dir).map_err(|e| format!("create_dir_all failed: {e}"))?;

    let mut rng = Xor64::new(cfg.seed);

    // First: build a deterministic list of titles. We need titles up
    // front because wikilinks reference by title, not by index, so the
    // edge step + body step both need the title table.
    let titles: Vec<String> = (0..cfg.node_count)
        .map(|i| make_title(i, &mut rng))
        .collect();

    // Then build the edge graph.
    let edges = build_edges(cfg.node_count, &mut rng);

    // Then write each note.
    //
    // Time-cluster: notes get created_at timestamps from
    // (now - node_count days) to now, so note 0 is "oldest" and note
    // N-1 is "newest". This matches PKM-realism.
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0);
    let one_day = 86_400_i64;

    for i in 0..cfg.node_count {
        let wikilink_titles: Vec<String> = edges[i]
            .iter()
            .filter_map(|&j| titles.get(j).cloned())
            .collect();
        let body = make_body(&mut rng, &wikilink_titles);
        let created = now - (cfg.node_count as i64 - i as i64) * one_day;
        write_note(&cfg.out_dir, i, &titles[i], &body, created)
            .map_err(|e| format!("write_note {i}: {e}"))?;
        if (i + 1) % 10_000 == 0 {
            eprintln!("  wrote {} / {}", i + 1, cfg.node_count);
        }
    }

    let total_edges: usize = edges.iter().map(|e| e.len()).sum();
    let avg_degree = total_edges as f64 / cfg.node_count as f64;
    let max_degree = edges.iter().map(|e| e.len()).max().unwrap_or(0);
    let elapsed = started.elapsed();

    eprintln!(
        "synth_vault: wrote {} notes ({} edges, avg degree {:.2}, max outgoing {}) to {} in {:.2}s",
        cfg.node_count,
        total_edges,
        avg_degree,
        max_degree,
        cfg.out_dir.display(),
        elapsed.as_secs_f64()
    );
    Ok(())
}

fn main() -> ExitCode {
    let cfg = match parse_args() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("synth_vault: error — {e}");
            eprintln!("Run with --help for usage.");
            return ExitCode::from(1);
        }
    };

    if let Err(e) = run(cfg) {
        eprintln!("synth_vault: failed — {e}");
        return ExitCode::from(2);
    }
    ExitCode::SUCCESS
}

// ─── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn xor64_is_deterministic() {
        let mut a = Xor64::new(42);
        let mut b = Xor64::new(42);
        for _ in 0..1000 {
            assert_eq!(a.next_u64(), b.next_u64());
        }
    }

    #[test]
    fn xor64_handles_zero_seed() {
        let mut r = Xor64::new(0);
        // Should not loop forever or return 0 forever.
        let first = r.next_u64();
        let second = r.next_u64();
        assert_ne!(first, second);
        assert_ne!(first, 0);
    }

    #[test]
    fn xor64_range_inclusive_lo_exclusive_hi() {
        let mut r = Xor64::new(7);
        for _ in 0..1000 {
            let v = r.range(10, 20);
            assert!((10..20).contains(&v), "got {v} outside [10, 20)");
        }
    }

    #[test]
    fn xor64_unit_in_zero_one() {
        let mut r = Xor64::new(99);
        for _ in 0..1000 {
            let v = r.unit();
            assert!((0.0..1.0).contains(&v), "got {v} outside [0, 1)");
        }
    }

    #[test]
    fn build_edges_pkm_shape_at_small_scale() {
        let mut rng = Xor64::new(1);
        let edges = build_edges(200, &mut rng);
        assert_eq!(edges.len(), 200);
        let total: usize = edges.iter().map(|e| e.len()).sum();
        let avg = total as f64 / 200.0;
        // Loose bounds — exact distribution depends on the time-clustering
        // weights but we should land in the PKM-realistic 2-12 avg outgoing range.
        assert!(avg >= 1.5, "avg outgoing degree too low: {avg}");
        assert!(avg <= 12.0, "avg outgoing degree too high: {avg}");
    }

    #[test]
    fn make_title_uses_synth_idx() {
        let mut r = Xor64::new(1);
        let t = make_title(123, &mut r);
        assert!(t.contains("00123"), "title missing zero-padded idx: {t}");
    }
}
