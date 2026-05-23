//! R2 (2026-05-23): integration tests for
//! `agent_core::storage::vault::produce_vault_recall_trace`.
//!
//! These tests live in `agent_core/tests/` rather than the inline
//! `storage::vault::tests` module because the lib-test build on this
//! HEAD has pre-existing breakage in unrelated modules
//! (`tools_v2`, `cache::mod`, `skill_discovery`) — those errors block
//! the inline test build but not the integration-test crate, which
//! consumes only the lib's public surface.
//!
//! Cross-ref:
//! - `agent_core/src/storage/vault.rs::produce_vault_recall_trace`
//! - `agent_core/src/bridge.rs::vault_recall_trace_json` (scaffold path)
//! - `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` W-21

use agent_core::storage::retrieval_trace::{
    RetrievalCandidate, RetrievalSignal, RetrievalSignalScore, RetrievalTrace,
};
use agent_core::storage::vault::{
    produce_vault_recall_trace, SearchResult, VaultBackend, VaultError,
};
use async_trait::async_trait;

/// Minimal `VaultBackend` test double whose `hybrid_search_with_trace`
/// returns a caller-supplied `(results, trace)` pair (or an error).
/// The other trait methods are not exercised by these tests.
struct StubBackend {
    outcome: Result<(Vec<SearchResult>, RetrievalTrace), VaultError>,
}

impl StubBackend {
    fn ok(results: Vec<SearchResult>, trace: RetrievalTrace) -> Self {
        Self {
            outcome: Ok((results, trace)),
        }
    }

    fn err(error: VaultError) -> Self {
        Self {
            outcome: Err(error),
        }
    }

    fn cloned(&self) -> Result<(Vec<SearchResult>, RetrievalTrace), VaultError> {
        match &self.outcome {
            Ok((results, trace)) => Ok((results.clone(), trace.clone())),
            Err(VaultError::IndexError(message)) => {
                Err(VaultError::IndexError(message.clone()))
            }
            Err(VaultError::NotFound(path)) => Err(VaultError::NotFound(path.clone())),
            Err(VaultError::DatabaseError(message)) => {
                Err(VaultError::DatabaseError(message.clone()))
            }
            Err(VaultError::PathTraversal(path)) => {
                Err(VaultError::PathTraversal(path.clone()))
            }
            Err(VaultError::IoError(error)) => Err(VaultError::IoError(
                std::io::Error::new(error.kind(), error.to_string()),
            )),
        }
    }
}

#[async_trait]
impl VaultBackend for StubBackend {
    async fn hybrid_search(
        &self,
        _query: &str,
        _limit: usize,
        _tag_filter: &[String],
    ) -> Result<Vec<SearchResult>, VaultError> {
        self.cloned().map(|(results, _)| results)
    }

    async fn hybrid_search_with_trace(
        &self,
        _query: &str,
        _limit: usize,
        _tag_filter: &[String],
    ) -> Result<(Vec<SearchResult>, RetrievalTrace), VaultError> {
        self.cloned()
    }

    async fn read(&self, path: &str) -> Result<String, VaultError> {
        Err(VaultError::NotFound(path.to_string()))
    }

    async fn write(
        &self,
        _path: &str,
        _content: &str,
        _tags: Option<&[String]>,
        _append: bool,
    ) -> Result<(), VaultError> {
        Ok(())
    }

    async fn list(&self, _path_prefix: &str) -> Result<Vec<String>, VaultError> {
        Ok(Vec::new())
    }

    async fn exists(&self, _path: &str) -> Result<bool, VaultError> {
        Ok(false)
    }

    async fn delete(&self, _path: &str) -> Result<bool, VaultError> {
        Ok(false)
    }
}

fn lexical_candidate(path: &str, score: f64) -> RetrievalCandidate {
    RetrievalCandidate::new(path, score).with_signal(RetrievalSignalScore::new(
        RetrievalSignal::Lexical,
        score,
        score,
    ))
}

/// When the backend omits `ladder_tier`, the production helper defaults
/// it to `"production-hybrid"` so consumers can distinguish a real
/// retrieval from the bridge `vault_recall_trace_json` scaffold path
/// (which tags itself `"scaffold-lexical"`).
#[tokio::test]
async fn produce_vault_recall_trace_defaults_ladder_tier_when_backend_omits_it() {
    let mut trace = RetrievalTrace::new("residency governance", "residency governance")
        .with_pool_size(1);
    trace.record_signal(RetrievalSignal::Lexical);
    trace.push_candidate(lexical_candidate("notes/governance.md", 3.42));
    assert!(
        trace.ladder_tier.is_none(),
        "precondition: backend emits no ladder_tier"
    );

    let results = vec![SearchResult {
        path: "notes/governance.md".to_string(),
        excerpt: "residency governance recap".to_string(),
        score: 3.42,
        tags: Vec::new(),
    }];

    let backend = StubBackend::ok(results, trace);
    let (out_results, out_trace) =
        produce_vault_recall_trace(&backend, "residency governance", 5, &[])
            .await
            .expect("production helper succeeds");

    assert_eq!(out_results.len(), 1, "results pass through unchanged");
    assert_eq!(
        out_trace.ladder_tier.as_deref(),
        Some("production-hybrid"),
        "helper defaults ladder_tier when backend omits it"
    );
    assert_ne!(
        out_trace.ladder_tier.as_deref(),
        Some("scaffold-lexical"),
        "production trace MUST NOT be confused with the bridge scaffold path"
    );
}

/// When the backend already set a `ladder_tier` (e.g. a Variant-Ladder
/// tier label like `"T1_Lexical_Bm25"` or `"T3_Rrf_Hybrid"`), the
/// production helper preserves it verbatim. The default is a fallback,
/// not an override.
#[tokio::test]
async fn produce_vault_recall_trace_preserves_backend_supplied_ladder_tier() {
    let mut trace = RetrievalTrace::new("ssm cache", "ssm cache")
        .with_ladder_tier("T3_Rrf_Hybrid")
        .with_pool_size(2);
    trace.record_signal(RetrievalSignal::Lexical);
    trace.record_signal(RetrievalSignal::Semantic);
    trace.push_candidate(lexical_candidate("notes/ssm.md", 5.1));

    let backend = StubBackend::ok(Vec::new(), trace);
    let (_, out_trace) = produce_vault_recall_trace(&backend, "ssm cache", 5, &[])
        .await
        .expect("production helper succeeds");

    assert_eq!(
        out_trace.ladder_tier.as_deref(),
        Some("T3_Rrf_Hybrid"),
        "helper preserves backend-supplied ladder_tier; does NOT clobber with default"
    );
    assert_eq!(
        out_trace.signal_summary.len(),
        2,
        "backend signal_summary passes through"
    );
}

/// Backend errors propagate unchanged — no swallowing into a fake
/// "empty trace" result. Consumers depend on this to surface real
/// index failures (e.g. closed Tantivy index, locked DB).
#[tokio::test]
async fn produce_vault_recall_trace_propagates_backend_error() {
    let backend = StubBackend::err(VaultError::IndexError(
        "tantivy reader closed".to_string(),
    ));
    let result = produce_vault_recall_trace(&backend, "anything", 3, &[]).await;

    match result {
        Err(VaultError::IndexError(message)) => assert_eq!(message, "tantivy reader closed"),
        other => panic!("expected IndexError propagation; got {:?}", other),
    }
}
