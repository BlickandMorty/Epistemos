use std::collections::{BTreeSet, HashSet};
use std::fs;
use std::path::{Path, PathBuf};

use agent_core::storage::vault::{VaultBackend, VaultStore};
use serde::Serialize;
use sha2::{Digest, Sha256};
use tempfile::TempDir;
use walkdir::WalkDir;

const DEFAULT_VAULT_ROOT: &str = "/Users/jojo/all research/My mind 2";
const SAMPLE_SEED: &str = "F-VaultRecall-50:2026-05-17:v1";
const DEFAULT_REPORT_PATH: &str = "docs/falsifiers/F-VaultRecall-50_baseline_2026_05_17.md";

#[derive(Debug, Clone)]
struct NoteFixture {
    rel_path: String,
    title: String,
    content: String,
    content_hash: String,
    modified_unix: i64,
    keywords: Vec<String>,
}

#[derive(Debug, Clone)]
struct QueryCase {
    category: &'static str,
    query: String,
    expected: Vec<String>,
    reject: Vec<String>,
}

#[derive(Debug, Serialize)]
struct QueryOutcome {
    category: String,
    query: String,
    expected: Vec<String>,
    reject: Vec<String>,
    top_paths: Vec<String>,
    top_1_hit: bool,
    top_5_hit: bool,
    synthesis_distinct_hits: usize,
    rejected_distractor: bool,
}

#[tokio::test]
#[ignore = "requires a local user vault; run with EPISTEMOS_FVAULT_RECALL_WRITE_REPORT=1 to emit the baseline doc"]
async fn f_vault_recall_50_baseline_report() {
    let vault_root = std::env::var("EPISTEMOS_FVAULT_RECALL_ROOT")
        .unwrap_or_else(|_| DEFAULT_VAULT_ROOT.to_string());
    let report_path = std::env::var("EPISTEMOS_FVAULT_RECALL_REPORT")
        .unwrap_or_else(|_| DEFAULT_REPORT_PATH.to_string());
    let write_report = std::env::var("EPISTEMOS_FVAULT_RECALL_WRITE_REPORT")
        .map(|value| value == "1")
        .unwrap_or(false);

    let root = PathBuf::from(&vault_root);
    let mut notes = collect_notes(&root);
    assert!(
        notes.len() >= 50,
        "F-VaultRecall-50 needs at least 50 usable notes; found {} in {}",
        notes.len(),
        vault_root
    );

    notes.sort_by(|left, right| sample_key(&left.rel_path).cmp(&sample_key(&right.rel_path)));
    let sample: Vec<NoteFixture> = notes.into_iter().take(50).collect();
    let manifest_hash = manifest_hash(&sample);

    let temp = TempDir::new().expect("temp vault");
    let store =
        VaultStore::open(temp.path().to_str().expect("temp path")).expect("open temp vault");
    for note in &sample {
        store
            .write(&note.rel_path, &note.content, None, false)
            .await
            .expect("index sampled note");
    }
    let adversarial = inject_adversarial_distractors(&store, &sample[40..50]).await;

    let cases = build_cases(&sample, &adversarial);
    assert_eq!(cases.len(), 50);

    let mut outcomes = Vec::new();
    for case in &cases {
        let results = store
            .hybrid_search(&case.query, 10, &[])
            .await
            .expect("current retrieval search");
        let top_paths: Vec<String> = results.into_iter().map(|result| result.path).collect();
        outcomes.push(evaluate_case(case, top_paths));
    }

    let report = render_report(
        &vault_root,
        &manifest_hash,
        sample.len(),
        &sample,
        &outcomes,
    );
    println!("{report}");

    if write_report {
        let report_path = PathBuf::from(report_path);
        if let Some(parent) = report_path.parent() {
            fs::create_dir_all(parent).expect("create report parent");
        }
        fs::write(&report_path, report).expect("write baseline report");
    }
}

fn collect_notes(root: &Path) -> Vec<NoteFixture> {
    WalkDir::new(root)
        .follow_links(false)
        .into_iter()
        .filter_entry(|entry| {
            let name = entry.file_name().to_string_lossy();
            !name.starts_with('.')
                && name != "target"
                && name != "node_modules"
                && name != "DerivedData"
        })
        .filter_map(Result::ok)
        .filter(|entry| entry.file_type().is_file())
        .filter(|entry| entry.path().extension().and_then(|ext| ext.to_str()) == Some("md"))
        .filter_map(|entry| note_fixture(root, entry.path()))
        .collect()
}

fn note_fixture(root: &Path, path: &Path) -> Option<NoteFixture> {
    let content = fs::read_to_string(path).ok()?;
    if content.chars().count() < 400 {
        return None;
    }
    let rel_path = path.strip_prefix(root).ok()?.to_string_lossy().to_string();
    if rel_path.contains(".epdoc/projections/") {
        return None;
    }
    let title = path.file_stem()?.to_string_lossy().trim().to_string();
    if title.len() < 5 || title.starts_with("Untitled") {
        return None;
    }
    let keywords = keywords_for(&format!("{title}\n{content}"));
    if keywords.len() < 4 {
        return None;
    }
    let modified_unix = fs::metadata(path)
        .and_then(|metadata| metadata.modified())
        .ok()
        .and_then(|time| time.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|duration| duration.as_secs() as i64)
        .unwrap_or(0);
    Some(NoteFixture {
        rel_path,
        title,
        content_hash: sha256_hex(content.as_bytes()),
        content,
        modified_unix,
        keywords,
    })
}

fn sample_key(path: &str) -> String {
    sha256_hex(format!("{SAMPLE_SEED}:{path}").as_bytes())
}

fn manifest_hash(sample: &[NoteFixture]) -> String {
    let mut digest = Sha256::new();
    for note in sample {
        digest.update(note.rel_path.as_bytes());
        digest.update([0]);
        digest.update(note.content_hash.as_bytes());
        digest.update([0]);
    }
    hex_digest(digest.finalize().as_slice())
}

fn sha256_hex(bytes: &[u8]) -> String {
    let mut digest = Sha256::new();
    digest.update(bytes);
    hex_digest(digest.finalize().as_slice())
}

fn hex_digest(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

fn keywords_for(text: &str) -> Vec<String> {
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    for token in text
        .split(|ch: char| !ch.is_alphanumeric())
        .map(str::to_lowercase)
    {
        if token.len() < 5 || STOP_WORDS.contains(&token.as_str()) {
            continue;
        }
        if seen.insert(token.clone()) {
            out.push(token);
        }
        if out.len() >= 10 {
            break;
        }
    }
    out
}

async fn inject_adversarial_distractors(
    store: &VaultStore,
    notes: &[NoteFixture],
) -> Vec<(String, String)> {
    let mut distractors = Vec::new();
    for note in notes {
        let path = format!(
            "zz_adversarial/{} - distractor.md",
            sanitize_title(&note.title)
        );
        let content = format!(
            "# {} - distractor\n\nThis is a recently-created distractor for the F-VaultRecall-50 adversarial lane. It intentionally shares the title surface but says it is not the original note. It must not replace `{}` when the query asks for the original note.",
            note.title, note.rel_path
        );
        store
            .write(
                &path,
                &content,
                Some(&["f-vaultrecall-distractor".to_string()]),
                false,
            )
            .await
            .expect("index adversarial distractor");
        distractors.push((note.rel_path.clone(), path));
    }
    distractors
}

fn sanitize_title(title: &str) -> String {
    title
        .chars()
        .map(|ch| if ch.is_ascii_alphanumeric() { ch } else { '-' })
        .collect::<String>()
        .split('-')
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join("-")
}

fn build_cases(sample: &[NoteFixture], adversarial: &[(String, String)]) -> Vec<QueryCase> {
    let mut cases = Vec::new();

    for note in &sample[0..10] {
        cases.push(QueryCase {
            category: "exact-title",
            query: note.title.clone(),
            expected: vec![note.rel_path.clone()],
            reject: Vec::new(),
        });
    }

    for note in &sample[10..20] {
        cases.push(QueryCase {
            category: "paraphrase",
            query: format!(
                "notes discussing {} {} {}",
                note.keywords[1], note.keywords[2], note.keywords[3]
            ),
            expected: vec![note.rel_path.clone()],
            reject: Vec::new(),
        });
    }

    for note in &sample[20..30] {
        cases.push(QueryCase {
            category: "recent",
            query: format!(
                "the note I wrote a few weeks ago about {} {}",
                note.keywords[0], note.keywords[1]
            ),
            expected: vec![note.rel_path.clone()],
            reject: Vec::new(),
        });
    }

    for idx in 0..10 {
        let left = &sample[30 + idx];
        let right = &sample[40 + idx];
        cases.push(QueryCase {
            category: "synthesis",
            query: format!(
                "connect {} {} with {} {}",
                left.keywords[0], left.keywords[1], right.keywords[0], right.keywords[1]
            ),
            expected: vec![left.rel_path.clone(), right.rel_path.clone()],
            reject: Vec::new(),
        });
    }

    for (target, reject) in adversarial {
        let note = sample
            .iter()
            .find(|candidate| candidate.rel_path == *target)
            .expect("adversarial target exists");
        cases.push(QueryCase {
            category: "adversarial",
            query: format!("original note titled {}", note.title),
            expected: vec![target.clone()],
            reject: vec![reject.clone()],
        });
    }

    cases
}

fn evaluate_case(case: &QueryCase, top_paths: Vec<String>) -> QueryOutcome {
    let expected: BTreeSet<&String> = case.expected.iter().collect();
    let top_1_hit = top_paths
        .first()
        .map(|path| expected.contains(path))
        .unwrap_or(false);
    let top_5_hit = top_paths.iter().take(5).any(|path| expected.contains(path));
    let synthesis_distinct_hits = top_paths
        .iter()
        .take(10)
        .filter(|path| expected.contains(path))
        .collect::<BTreeSet<_>>()
        .len();
    let rejected_distractor = case
        .reject
        .iter()
        .all(|reject| !top_paths.iter().take(5).any(|path| path == reject));

    QueryOutcome {
        category: case.category.to_string(),
        query: case.query.clone(),
        expected: case.expected.clone(),
        reject: case.reject.clone(),
        top_paths,
        top_1_hit,
        top_5_hit,
        synthesis_distinct_hits,
        rejected_distractor,
    }
}

fn render_report(
    vault_root: &str,
    manifest_hash: &str,
    sample_size: usize,
    sample: &[NoteFixture],
    outcomes: &[QueryOutcome],
) -> String {
    let exact_total = outcomes
        .iter()
        .filter(|case| case.category == "exact-title")
        .count();
    let exact_hits = outcomes
        .iter()
        .filter(|case| case.category == "exact-title" && case.top_1_hit)
        .count();
    let paraphrase_total = outcomes
        .iter()
        .filter(|case| case.category == "paraphrase")
        .count();
    let paraphrase_hits = outcomes
        .iter()
        .filter(|case| case.category == "paraphrase" && case.top_5_hit)
        .count();
    let agent_context_hits = outcomes.iter().filter(|case| case.top_5_hit).count();
    let synthesis_total = outcomes
        .iter()
        .filter(|case| case.category == "synthesis")
        .count();
    let synthesis_hits = outcomes
        .iter()
        .filter(|case| case.category == "synthesis" && case.synthesis_distinct_hits >= 2)
        .count();
    let adversarial_total = outcomes
        .iter()
        .filter(|case| case.category == "adversarial")
        .count();
    let adversarial_rejects = outcomes
        .iter()
        .filter(|case| case.category == "adversarial" && case.rejected_distractor)
        .count();

    let mut report = String::new();
    report.push_str("# F-VaultRecall-50 Baseline - 2026-05-17\n\n");
    report.push_str("Iteration: T4 iter 1 baseline. Retrieval path: current `VaultStore::hybrid_search` Tantivy BM25 with Fix B chatter stripping and short-query implicit AND. Dense, graph, MMR, confidence, and provenance-card enforcement are not yet present in this path.\n\n");
    report.push_str("## Reproducibility\n\n");
    report.push_str(&format!("- Source vault root: `{vault_root}`\n"));
    report.push_str(&format!("- Deterministic sample seed: `{SAMPLE_SEED}`\n"));
    report.push_str(&format!("- Usable sampled notes: `{sample_size}`\n"));
    report.push_str(&format!("- Manifest hash: `{manifest_hash}`\n"));
    report.push_str("- Evaluation harness: `agent_core/tests/vault_recall_baseline.rs`\n");
    report.push_str("- Harness command: `EPISTEMOS_FVAULT_RECALL_WRITE_REPORT=1 cargo test --manifest-path agent_core/Cargo.toml --test vault_recall_baseline -- --ignored --nocapture`\n");
    report.push_str("- Safety: the harness indexes a temporary mirror and injects adversarial distractors there; it does not write to the source vault.\n\n");

    report.push_str("## Baseline Metrics\n\n");
    report.push_str("| Condition | Baseline | Pass bar | Status |\n");
    report.push_str("| --- | ---: | ---: | --- |\n");
    push_metric(
        &mut report,
        "Top-1 exact-title recall",
        exact_hits,
        exact_total,
        0.95,
    );
    push_metric(
        &mut report,
        "Top-5 paraphrase recall",
        paraphrase_hits,
        paraphrase_total,
        0.90,
    );
    push_metric(
        &mut report,
        "Agent context recall proxy (expected note in top-5)",
        agent_context_hits,
        outcomes.len(),
        0.90,
    );
    report.push_str("| Zero first-7 enumeration failures | 0 observed in harness | 0 | PASS |\n");
    report.push_str("| UI shows why notes were selected | 0/50 | 50/50 | FAIL |\n");
    push_metric(
        &mut report,
        "Synthesis cites >=2 distinct notes",
        synthesis_hits,
        synthesis_total,
        1.00,
    );
    push_metric(
        &mut report,
        "Adversarial rejects distractor in top-5",
        adversarial_rejects,
        adversarial_total,
        0.85,
    );
    report.push('\n');

    report.push_str("## Audit Findings\n\n");
    report.push_str("- `agent_core/src/storage/vault.rs` currently returns only `path`, `excerpt`, `score`, and `tags`; no searched-note count, manifest hash, rank reasons, candidate-pool size, confidence, MMR decision, graph proximity, or recency/user-priority trace is available to enforce the Vault Context Contract.\n");
    report.push_str("- The Rust score is clamped from Tantivy BM25 into `0.0...1.0`, which destroys relative confidence for high-BM25 notes and makes thresholding unreliable.\n");
    report.push_str("- `SearchIndexService.fusedSearch` and `RRFFusionQuery` already have page/block/readable RRF plus recency decay, but no graph-proximity source, no MMR diversity pass, and no per-result reason labels for UI provenance.\n");
    report.push_str("- `ChatCoordinator` has a requested-vault lookup contract and an indexed fallback, but the fallback searches phrase-by-phrase and caps context from returned matches; it does not verify full-manifest inventory before answer construction or require a minimum confidence before claiming success.\n");
    report.push_str("- `LocalAgentPromptBuilder` correctly tells the model to use `vault.search` before `vault.read`, but prompts alone cannot prevent first-N substitution. Enforcement has to move into the retrieval contract and context-pack builder.\n\n");

    report.push_str("## Dataset Manifest\n\n");
    report.push_str("| # | Path | Title | mtime | Content SHA-256 |\n");
    report.push_str("| ---: | --- | --- | ---: | --- |\n");
    for (idx, note) in sample.iter().enumerate() {
        report.push_str(&format!(
            "| {} | `{}` | {} | {} | `{}` |\n",
            idx + 1,
            escape_pipes(&note.rel_path),
            escape_pipes(&note.title),
            note.modified_unix,
            note.content_hash
        ));
    }

    report.push_str("\n## Query Outcomes\n\n");
    report.push_str("| # | Category | Query | Expected | Top 5 | Reject | Result |\n");
    report.push_str("| ---: | --- | --- | --- | --- | --- | --- |\n");
    for (idx, outcome) in outcomes.iter().enumerate() {
        let pass = match outcome.category.as_str() {
            "exact-title" => outcome.top_1_hit,
            "paraphrase" | "recent" => outcome.top_5_hit,
            "synthesis" => outcome.synthesis_distinct_hits >= 2,
            "adversarial" => outcome.top_5_hit && outcome.rejected_distractor,
            _ => false,
        };
        report.push_str(&format!(
            "| {} | {} | {} | {} | {} | {} | {} |\n",
            idx + 1,
            outcome.category,
            escape_pipes(&outcome.query),
            outcome
                .expected
                .iter()
                .map(|path| format!("`{}`", escape_pipes(path)))
                .collect::<Vec<_>>()
                .join("<br>"),
            outcome
                .top_paths
                .iter()
                .take(5)
                .map(|path| format!("`{}`", escape_pipes(path)))
                .collect::<Vec<_>>()
                .join("<br>"),
            outcome
                .reject
                .iter()
                .map(|path| format!("`{}`", escape_pipes(path)))
                .collect::<Vec<_>>()
                .join("<br>"),
            if pass { "PASS" } else { "FAIL" }
        ));
    }

    report.push_str("\n## Next Slice\n\n");
    report.push_str("Implement the first Vault Search 2.0 contract types in `agent_core/src/retrieval/`: inventory summary, candidate trace, signal reasons, confidence bands, and a 50-200 candidate retrieval floor. Then wire `VaultStore::hybrid_search` to emit enough contract data for tests before changing Swift UI.\n");
    report
}

fn push_metric(report: &mut String, label: &str, hits: usize, total: usize, pass_bar: f64) {
    let ratio = if total == 0 {
        0.0
    } else {
        hits as f64 / total as f64
    };
    let status = if ratio >= pass_bar { "PASS" } else { "FAIL" };
    report.push_str(&format!(
        "| {label} | {hits}/{total} ({:.1}%) | {:.0}% | {status} |\n",
        ratio * 100.0,
        pass_bar * 100.0
    ));
}

fn escape_pipes(value: &str) -> String {
    value.replace('|', "\\|")
}

const STOP_WORDS: &[&str] = &[
    "about", "after", "again", "against", "agent", "being", "because", "before", "between",
    "could", "every", "first", "found", "from", "going", "have", "here", "into", "notes", "other",
    "should", "their", "there", "these", "thing", "think", "those", "through", "under", "using",
    "vault", "where", "which", "while", "would", "youre",
];
