//! Plan §12 verification command for Phase 3:
//! `cargo run --bin route_eval -- --set agent_core/eval/route_v1.jsonl`
//!
//! Loads JSONL fixtures, builds a stub RouteCtx (variants A/B/C
//! return None per Phase 3E since real MLX inference lands at
//! Phase 6), runs `route_capture` per fixture, prints the §11
//! Phase 3 EXIT pass-criteria report.
//!
//! Exit codes:
//! - 0: report generated cleanly + passes_phase_3_exit() == true
//! - 1: usage / IO / parse error
//! - 2: report generated but pass criteria failed

use std::env;
use std::fs::File;
use std::io::BufReader;
use std::process::ExitCode;
use std::sync::Arc;

use async_trait::async_trait;

use agent_core::cache::StubEmbedder;
use agent_core::eval::{load_fixtures_jsonl, run_route_eval};
use agent_core::route::{variant_b, variant_c, RouteCtx};

#[tokio::main]
async fn main() -> ExitCode {
    let mut args = env::args().skip(1);
    let mut set_path: Option<String> = None;
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--set" => {
                set_path = args.next();
            }
            "--help" | "-h" => {
                eprintln!("usage: route_eval --set <path>");
                eprintln!("       Plan §12 / Phase 3 verification harness.");
                return ExitCode::from(1);
            }
            other => {
                eprintln!("unknown argument: {}", other);
                return ExitCode::from(1);
            }
        }
    }
    let set_path = match set_path {
        Some(p) => p,
        None => {
            eprintln!("error: --set <path> is required");
            return ExitCode::from(1);
        }
    };

    let file = match File::open(&set_path) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("io error opening {}: {}", set_path, e);
            return ExitCode::from(1);
        }
    };
    let reader = BufReader::new(file);
    let fixtures = match load_fixtures_jsonl(reader) {
        Ok(fs) => fs,
        Err(e) => {
            eprintln!("parse error: {}", e);
            return ExitCode::from(1);
        }
    };

    // Phase 3E uses a stub RouteCtx. Real MLX-backed embedder +
    // GBNF-bound classifier + concept_extract/entity_resolve/vault.
    // search land in Phase 6 wiring; once those are in, this binary
    // accepts a different ctx flag (e.g. `--ctx production`) and
    // exercises the real ladder.
    let ctx = stub_ctx();

    let report = run_route_eval(&fixtures, &ctx).await;

    println!("{}", report.summary());
    println!("breakdown:");
    println!("  total                = {}", report.total);
    println!("  correct_top_1        = {}", report.correct_top_1);
    println!("  defer_count          = {}", report.defer_count);
    println!("  schema_violations    = {}", report.schema_violations);
    println!("  top_1_accuracy       = {:.3}", report.top_1_accuracy());
    println!("  defer_rate           = {:.3}", report.defer_rate());
    println!(
        "  passes §11 Phase 3   = {}",
        report.passes_phase_3_exit()
    );
    println!();
    println!(
        "Note: Phase 3E ships the harness mechanics + a synthetic seed corpus.\n\
         Real pass-criteria evaluation requires Phase 6 MLX wiring; until then\n\
         this run uses a stub RouteCtx that always defers."
    );

    if report.passes_phase_3_exit() {
        ExitCode::from(0)
    } else {
        ExitCode::from(2)
    }
}

fn stub_ctx() -> RouteCtx {
    struct NullClassifier;
    #[async_trait]
    impl variant_b::LlmClassifier for NullClassifier {
        async fn classify(
            &self,
            _: &str,
            _: &[String],
        ) -> Result<variant_b::VariantBOutput, variant_b::ClassifierError> {
            Err(variant_b::ClassifierError::Inference(
                "phase 3E stub — Phase 6 wires real MLX-backed classifier".into(),
            ))
        }
    }
    struct NullExtractor;
    #[async_trait]
    impl variant_c::ConceptExtractor for NullExtractor {
        async fn extract(
            &self,
            _: &str,
        ) -> Result<Vec<variant_c::Concept>, variant_c::ExtractorError> {
            Ok(Vec::new())
        }
    }
    struct NullResolver;
    #[async_trait]
    impl variant_c::EntityResolver for NullResolver {
        async fn resolve(&self, _: &str) -> variant_c::Resolution {
            variant_c::Resolution::New
        }
    }
    struct NullNeighbours;
    #[async_trait]
    impl variant_c::NeighbourFinder for NullNeighbours {
        async fn find(&self, _: &str, _: usize) -> Vec<variant_c::NeighbourHit> {
            Vec::new()
        }
    }
    RouteCtx {
        embedder: Arc::new(StubEmbedder { dim: 8 }),
        folders: Vec::new(),
        classifier: Arc::new(NullClassifier),
        vault_paths: Vec::new(),
        extractor: Arc::new(NullExtractor),
        resolver: Arc::new(NullResolver),
        neighbours: Arc::new(NullNeighbours),
        parent_unfit_fn: Arc::new(|_| true),
    }
}
