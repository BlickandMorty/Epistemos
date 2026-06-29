//! Multi-agent deep-research orchestration (owner go-ahead 2026-06-18 — the
//! R-DEERFLOW gap, docs/RESEARCH_DEERFLOW_2026_06_18.md). Built NATIVELY in Rust
//! on the existing agent_core substrate (loop + tools + compaction + schema gate
//! + Eidos citations), NOT a Python/LangGraph sidecar (NO-SIDECAR).
//!
//! The DeerFlow loop: a lead agent DECOMPOSES a question into sub-questions →
//! PARALLEL sub-agents (isolated contexts) research each → the lead SYNTHESIZES.
//!
//! # Slice 1 — the plan + the parallel-batch layering (this module)
//! [`ResearchPlan`] is the planner's typed output (validated by the P8.1 schema
//! gate before use). [`ResearchPlan::execution_layers`] is the heart of the
//! fan-out: it groups sub-questions into dependency-ordered LAYERS, where every
//! sub-question in a layer can run CONCURRENTLY (all its dependencies are
//! satisfied by earlier layers). The orchestrator (later slice) runs each layer
//! as a batch of concurrent agent_core sub-agent loops, waits, then the next.
//!
//! Inert until the orchestrator wires it behind a Research/Work-mode flag —
//! single-agent stays the default. No behavior change from this slice.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

pub mod orchestrator;
pub mod planner;
pub mod reporter;
pub mod researcher;
pub mod run;

/// Opt-in flag for the multi-agent deep-research run (default OFF — single-agent
/// stays the default until explicitly enabled). Same truth table as the other
/// substrate gates (1/true/yes/on). Always-compiled so a visible surface can
/// read it honestly, even on the MAS build (where the live run is Pro-gated).
pub fn deep_research_enabled() -> bool {
    deep_research_flag_value(std::env::var("EPISTEMOS_DEEP_RESEARCH_V0").ok().as_deref())
}

/// Pure truth-table for the flag (testable without mutating process env).
pub fn deep_research_flag_value(raw: Option<&str>) -> bool {
    matches!(
        raw.map(str::trim).map(str::to_ascii_lowercase).as_deref(),
        Some("1") | Some("true") | Some("yes") | Some("on")
    )
}

/// The result of researching one sub-question (the orchestrator collects these
/// per layer). `findings` is the sub-agent's structured output; later slices add
/// a filesystem artifact path + citation grounding.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SubResult {
    pub id: String,
    pub findings: String,
}

/// A single decomposed research sub-question. `depends_on` lists the ids of
/// sub-questions whose results this one needs first (e.g. a synthesis step that
/// depends on two parallel fact-finding steps).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SubQuestion {
    pub id: String,
    pub question: String,
    #[serde(default)]
    pub depends_on: Vec<String>,
}

/// The lead planner's typed output: an objective decomposed into sub-questions
/// with an explicit dependency DAG. Validated before any sub-agent runs.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResearchPlan {
    pub objective: String,
    pub sub_questions: Vec<SubQuestion>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum DeepResearchError {
    EmptyObjective,
    EmptySubQuestions,
    DuplicateSubQuestionId(String),
    UnknownDependency {
        sub_question: String,
        depends_on: String,
    },
    CyclicDependency,
}

impl std::fmt::Display for DeepResearchError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DeepResearchError::EmptyObjective => write!(f, "research plan objective is empty"),
            DeepResearchError::EmptySubQuestions => {
                write!(f, "research plan has no sub-questions")
            }
            DeepResearchError::DuplicateSubQuestionId(id) => {
                write!(f, "duplicate sub-question id '{id}'")
            }
            DeepResearchError::UnknownDependency {
                sub_question,
                depends_on,
            } => write!(
                f,
                "sub-question '{sub_question}' depends on unknown id '{depends_on}'"
            ),
            DeepResearchError::CyclicDependency => {
                write!(
                    f,
                    "research plan has a cyclic dependency (no valid execution order)"
                )
            }
        }
    }
}

impl std::error::Error for DeepResearchError {}

impl ResearchPlan {
    /// Validate the plan BEFORE any sub-agent runs: non-empty objective + at
    /// least one sub-question, unique ids, every `depends_on` references a real
    /// id, and the dependency graph is acyclic. Returns the first violation.
    pub fn validate(&self) -> Result<(), DeepResearchError> {
        if self.objective.trim().is_empty() {
            return Err(DeepResearchError::EmptyObjective);
        }
        if self.sub_questions.is_empty() {
            return Err(DeepResearchError::EmptySubQuestions);
        }

        let mut ids: BTreeSet<&str> = BTreeSet::new();
        for sq in &self.sub_questions {
            if !ids.insert(sq.id.as_str()) {
                return Err(DeepResearchError::DuplicateSubQuestionId(sq.id.clone()));
            }
        }

        for sq in &self.sub_questions {
            for dep in &sq.depends_on {
                if !ids.contains(dep.as_str()) {
                    return Err(DeepResearchError::UnknownDependency {
                        sub_question: sq.id.clone(),
                        depends_on: dep.clone(),
                    });
                }
            }
        }

        // Acyclicity: layering fails iff there is a cycle (deps are valid here).
        self.execution_layers().map(|_| ())
    }

    /// Group sub-questions into dependency-ordered LAYERS for parallel fan-out.
    /// Every sub-question in `layers[i]` has all dependencies in `layers[<i]`, so
    /// the orchestrator can run each layer as a CONCURRENT batch. Deterministic:
    /// within a layer, order follows the plan's declaration order.
    ///
    /// Assumes dependencies reference valid ids (call [`Self::validate`] first);
    /// an unknown dependency surfaces here as `CyclicDependency` (never resolves).
    pub fn execution_layers(&self) -> Result<Vec<Vec<&SubQuestion>>, DeepResearchError> {
        let mut resolved: BTreeSet<&str> = BTreeSet::new();
        let mut remaining: Vec<&SubQuestion> = self.sub_questions.iter().collect();
        let mut layers: Vec<Vec<&SubQuestion>> = Vec::new();

        while !remaining.is_empty() {
            let (ready, not_ready): (Vec<&SubQuestion>, Vec<&SubQuestion>) = remaining
                .into_iter()
                .partition(|sq| sq.depends_on.iter().all(|d| resolved.contains(d.as_str())));

            if ready.is_empty() {
                return Err(DeepResearchError::CyclicDependency);
            }
            for sq in &ready {
                resolved.insert(sq.id.as_str());
            }
            layers.push(ready);
            remaining = not_ready;
        }

        Ok(layers)
    }

    /// Peak concurrency the orchestrator needs — the widest parallel layer. The
    /// orchestrator caps actual concurrency (M2 Pro 16 GB: small N) but uses this
    /// to size the fan-out. 0 on a cyclic/empty plan.
    pub fn max_parallel_width(&self) -> usize {
        self.execution_layers()
            .map(|layers| layers.iter().map(Vec::len).max().unwrap_or(0))
            .unwrap_or(0)
    }

    pub fn len(&self) -> usize {
        self.sub_questions.len()
    }

    pub fn is_empty(&self) -> bool {
        self.sub_questions.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sq(id: &str, deps: &[&str]) -> SubQuestion {
        SubQuestion {
            id: id.to_string(),
            question: format!("question {id}"),
            depends_on: deps.iter().map(|s| s.to_string()).collect(),
        }
    }

    fn plan(sub_questions: Vec<SubQuestion>) -> ResearchPlan {
        ResearchPlan {
            objective: "investigate X".to_string(),
            sub_questions,
        }
    }

    fn layer_ids(plan: &ResearchPlan) -> Vec<Vec<String>> {
        plan.execution_layers()
            .unwrap()
            .iter()
            .map(|layer| layer.iter().map(|sq| sq.id.clone()).collect())
            .collect()
    }

    #[test]
    fn independent_subquestions_form_one_parallel_layer() {
        let p = plan(vec![sq("a", &[]), sq("b", &[]), sq("c", &[])]);
        assert!(p.validate().is_ok());
        assert_eq!(layer_ids(&p), vec![vec!["a", "b", "c"]]);
        assert_eq!(p.max_parallel_width(), 3);
    }

    #[test]
    fn a_linear_chain_forms_n_layers_of_one() {
        let p = plan(vec![sq("a", &[]), sq("b", &["a"]), sq("c", &["b"])]);
        assert!(p.validate().is_ok());
        assert_eq!(layer_ids(&p), vec![vec!["a"], vec!["b"], vec!["c"]]);
        assert_eq!(p.max_parallel_width(), 1);
    }

    #[test]
    fn a_diamond_fans_out_then_synthesizes() {
        // a → (b, c) → d : two parallel researchers feeding a synthesis step.
        let p = plan(vec![
            sq("a", &[]),
            sq("b", &["a"]),
            sq("c", &["a"]),
            sq("d", &["b", "c"]),
        ]);
        assert!(p.validate().is_ok());
        assert_eq!(layer_ids(&p), vec![vec!["a"], vec!["b", "c"], vec!["d"]]);
        assert_eq!(p.max_parallel_width(), 2);
    }

    #[test]
    fn empty_objective_or_subquestions_is_invalid() {
        let mut p = plan(vec![sq("a", &[])]);
        p.objective = "   ".to_string();
        assert_eq!(p.validate(), Err(DeepResearchError::EmptyObjective));

        let empty = plan(vec![]);
        assert_eq!(empty.validate(), Err(DeepResearchError::EmptySubQuestions));
    }

    #[test]
    fn duplicate_ids_are_rejected() {
        let p = plan(vec![sq("a", &[]), sq("a", &[])]);
        assert_eq!(
            p.validate(),
            Err(DeepResearchError::DuplicateSubQuestionId("a".to_string()))
        );
    }

    #[test]
    fn unknown_dependency_is_rejected_with_specifics() {
        let p = plan(vec![sq("a", &["ghost"])]);
        assert_eq!(
            p.validate(),
            Err(DeepResearchError::UnknownDependency {
                sub_question: "a".to_string(),
                depends_on: "ghost".to_string(),
            })
        );
    }

    #[test]
    fn a_cycle_is_rejected() {
        let p = plan(vec![sq("a", &["b"]), sq("b", &["a"])]);
        assert_eq!(p.validate(), Err(DeepResearchError::CyclicDependency));
        assert_eq!(
            p.execution_layers(),
            Err(DeepResearchError::CyclicDependency)
        );
        assert_eq!(p.max_parallel_width(), 0);
    }

    #[test]
    fn plan_round_trips_through_json() {
        let p = plan(vec![sq("a", &[]), sq("b", &["a"])]);
        let json = serde_json::to_string(&p).unwrap();
        let back: ResearchPlan = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }

    #[test]
    fn deep_research_flag_truth_table_defaults_off() {
        for on in ["1", "true", "TRUE", "Yes", "on", " on "] {
            assert!(
                super::deep_research_flag_value(Some(on)),
                "{on} should enable"
            );
        }
        for off in ["0", "false", "no", "off", "", "2", "enable"] {
            assert!(
                !super::deep_research_flag_value(Some(off)),
                "{off} should be off"
            );
        }
        assert!(
            !super::deep_research_flag_value(None),
            "unset → off (default)"
        );
    }
}
