//! DeerFlow slice 3 — the ORCHESTRATOR (the parallel "researcher" stage).
//!
//! Runs a validated [`ResearchPlan`] layer-by-layer: each
//! [`ResearchPlan::execution_layers`] batch runs its sub-questions CONCURRENTLY
//! (capped at `max_concurrency` for the M2 Pro 16 GB ship rig), in dependency
//! order, passing earlier layers' results forward (for `depends_on` context).
//!
//! The per-sub-question work is abstracted behind [`SubAgentResearcher`] so the
//! orchestration is testable WITHOUT a model. The live researcher — an isolated
//! agent_core sub-agent loop per sub-question (own message history, shared tool
//! registry) — wires in as an impl in the next slice. Still inert: nothing here
//! calls a model; single-agent stays the default.

use super::{DeepResearchError, ResearchPlan, SubQuestion, SubResult};
use async_trait::async_trait;
use futures::stream::{self, StreamExt};
use std::sync::Arc;

/// Researches ONE sub-question. `prior` carries results from already-completed
/// layers (a `depends_on` sub-question reads them). The live impl will run an
/// isolated agent_core sub-agent loop; the orchestration doesn't care which.
/// `Send + Sync` so the orchestrator can hold it in an `Arc<dyn …>` and let each
/// concurrent sub-agent future OWN an Arc clone (no borrows → the future is
/// `'static + Send`, required behind the UniFFI async export).
#[async_trait]
pub trait SubAgentResearcher: Send + Sync {
    async fn research(&self, sub_question: &SubQuestion, prior: &[SubResult]) -> SubResult;
}

/// Run the plan: execute each dependency-ordered layer as a concurrent batch
/// (≤ `max_concurrency` in flight), in dependency order, forwarding completed
/// results. Output is in plan order within each layer (deterministic — `buffered`
/// yields in input order while running concurrently). Returns the validation
/// error if the plan is cyclic.
pub async fn run_plan(
    plan: &ResearchPlan,
    researcher: Arc<dyn SubAgentResearcher>,
    max_concurrency: usize,
) -> Result<Vec<SubResult>, DeepResearchError> {
    let layers = plan.execution_layers()?;
    let cap = max_concurrency.max(1);
    let mut all: Vec<SubResult> = Vec::new();

    for layer in layers {
        // Snapshot of every completed layer — every sub-agent in THIS layer sees
        // the same prior context (read-only, shared across the concurrent batch).
        // Arc so each sub-agent future owns a cheap handle to it.
        let prior = Arc::new(all.clone());
        // Stream the sub-questions BY VALUE (own them up front) so the map closure
        // takes an OWNED input — not a borrowed `&SubQuestion` tied to the plan's
        // lifetime. With an owned input + Arc'd researcher/prior, the per-sub-agent
        // future borrows NOTHING (`'static + Send`) and the closure is HRTB-general,
        // both of which the UniFFI async export (run_deep_research_session) requires.
        let owned_layer: Vec<SubQuestion> = layer.into_iter().cloned().collect();
        let layer_results: Vec<SubResult> = stream::iter(owned_layer.into_iter())
            .map(|sq| {
                let prior = Arc::clone(&prior);
                let researcher = Arc::clone(&researcher);
                async move { researcher.research(&sq, &prior).await }
            })
            .buffered(cap)
            .collect()
            .await;
        all.extend(layer_results);
    }

    Ok(all)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};

    fn sq(id: &str, deps: &[&str]) -> SubQuestion {
        SubQuestion {
            id: id.to_string(),
            question: format!("q{id}"),
            depends_on: deps.iter().map(|s| s.to_string()).collect(),
        }
    }

    fn diamond() -> ResearchPlan {
        // a → (b, c) → d
        ResearchPlan {
            objective: "x".to_string(),
            sub_questions: vec![
                sq("a", &[]),
                sq("b", &["a"]),
                sq("c", &["a"]),
                sq("d", &["b", "c"]),
            ],
        }
    }

    /// Records peak concurrency + the prior-count each sub-agent saw.
    struct ProbeResearcher {
        current: AtomicUsize,
        peak: AtomicUsize,
        prior_for_d: AtomicUsize,
    }

    #[async_trait]
    impl SubAgentResearcher for ProbeResearcher {
        async fn research(&self, sub_question: &SubQuestion, prior: &[SubResult]) -> SubResult {
            let now = self.current.fetch_add(1, Ordering::SeqCst) + 1;
            self.peak.fetch_max(now, Ordering::SeqCst);
            if sub_question.id == "d" {
                self.prior_for_d.store(prior.len(), Ordering::SeqCst);
            }
            // Yield several times so a concurrent batch actually overlaps before
            // anyone decrements — deterministic peak measurement, no timing.
            for _ in 0..8 {
                tokio::task::yield_now().await;
            }
            self.current.fetch_sub(1, Ordering::SeqCst);
            SubResult {
                id: sub_question.id.clone(),
                findings: format!("found {} (saw {} prior)", sub_question.id, prior.len()),
            }
        }
    }

    fn probe() -> ProbeResearcher {
        ProbeResearcher {
            current: AtomicUsize::new(0),
            peak: AtomicUsize::new(0),
            prior_for_d: AtomicUsize::new(0),
        }
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 4)]
    async fn runs_all_subquestions_in_plan_order() {
        let p = diamond();
        let r = std::sync::Arc::new(probe());
        let results = run_plan(&p, r.clone(), 4).await.unwrap();
        let ids: Vec<&str> = results.iter().map(|r| r.id.as_str()).collect();
        // Layer order: [a], [b, c], [d]; within a layer, plan order.
        assert_eq!(ids, vec!["a", "b", "c", "d"]);
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 4)]
    async fn a_parallel_layer_actually_runs_concurrently() {
        let p = diamond();
        let r = std::sync::Arc::new(probe());
        let _ = run_plan(&p, r.clone(), 4).await.unwrap();
        // The b,c layer is 2-wide and cap=4 → peak concurrency reaches 2.
        assert_eq!(r.peak.load(Ordering::SeqCst), 2);
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 4)]
    async fn concurrency_cap_one_serializes() {
        let p = diamond();
        let r = std::sync::Arc::new(probe());
        let _ = run_plan(&p, r.clone(), 1).await.unwrap();
        // cap=1 → never more than one in flight, even in the 2-wide layer.
        assert_eq!(r.peak.load(Ordering::SeqCst), 1);
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 4)]
    async fn synthesis_subagent_sees_prior_layer_results() {
        let p = diamond();
        let r = std::sync::Arc::new(probe());
        let _ = run_plan(&p, r.clone(), 4).await.unwrap();
        // d depends on b,c → by the time d runs, prior = {a, b, c} = 3 results.
        assert_eq!(r.prior_for_d.load(Ordering::SeqCst), 3);
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn cyclic_plan_errors_without_running() {
        let p = ResearchPlan {
            objective: "x".to_string(),
            sub_questions: vec![sq("a", &["b"]), sq("b", &["a"])],
        };
        let r = std::sync::Arc::new(probe());
        let err = run_plan(&p, r.clone(), 4).await.unwrap_err();
        assert_eq!(err, DeepResearchError::CyclicDependency);
        assert_eq!(r.peak.load(Ordering::SeqCst), 0); // nothing ran
    }
}
