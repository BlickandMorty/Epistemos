//! TRINITY orchestrator loop — System G native port, slice 1: the flat ≤5-round Thinker/Worker/Verifier loop
//! core (owner 2026-06-22, addendum "TRINITY BUILD PATH — heuristic-route FIRST"). Faithful to the verified
//! mechanics of the open `trinity_coordinator` reference (see TRINITY_COORDINATOR_PORT_SPEC): a FLAT (NOT
//! recursive) loop that runs Thinker → Worker → Verifier rounds, terminating on the Verifier's ACCEPT verdict,
//! bounded by a turn budget. The learned 1024→10 coordination head + the MLX hidden-state tap are LATER slices;
//! the orchestrator LOOP + roles + verdict + JSONL trace ship now via HEURISTIC routing (no license/MLX block).
//!
//! This slice is the PURE loop core: role sequencing, ACCEPT-termination, budget, and the trace event stream.
//! The real model calls plug in through `TrinityRoleExecutor` (injected) — so the loop is provider-free here and
//! unit-testable; slice 2 wires the OpenAI-compat provider boundary + heuristic RuntimeRouter selection into the
//! executor, and slice 3 streams the trace into the Swift `TraceCollector`.

use serde::{Deserialize, Serialize};

/// The three TRINITY roles. The numeric indices match the reference coordination-head logits
/// (0=Worker, 1=Thinker, 2=Verifier) so a later learned-router slice maps head outputs → roles directly.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum TrinityRole {
    Worker,
    Thinker,
    Verifier,
}

impl TrinityRole {
    /// Coordination-head logit index (verified from the reference: 0=Worker, 1=Thinker, 2=Verifier).
    pub const fn role_index(self) -> u8 {
        match self {
            Self::Worker => 0,
            Self::Thinker => 1,
            Self::Verifier => 2,
        }
    }

    pub const fn wire_tag(self) -> &'static str {
        match self {
            Self::Worker => "worker",
            Self::Thinker => "thinker",
            Self::Verifier => "verifier",
        }
    }
}

/// The Verifier's per-round decision: ACCEPT ends the loop with the current work as the answer; REPAIR loops
/// back to another Thinker/Worker round (until the turn budget is exhausted).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum VerifierVerdict {
    Accept,
    Repair,
}

/// Default turn budget — the reference's flat ≤5-turn cap.
pub const DEFAULT_MAX_ROUNDS: u32 = 5;

/// One JSONL trace event (schema_version 1). The 8 event kinds mirror the reference trace; the loop emits them
/// in order so the run is honest + replayable, and a later slice forwards them to the Swift TraceCollector.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "event", rename_all = "snake_case")]
pub enum TrinityEvent {
    LoopStarted {
        schema_version: u32,
        objective_hash: String,
        max_rounds: u32,
    },
    ThinkerTurn {
        round: u32,
    },
    WorkerTurn {
        round: u32,
    },
    VerifierTurn {
        round: u32,
    },
    VerifierAccept {
        round: u32,
    },
    VerifierRepair {
        round: u32,
    },
    BudgetExhausted {
        rounds: u32,
    },
    LoopCompleted {
        accepted: bool,
        rounds: u32,
    },
}

/// Outcome of a flat TRINITY loop run.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TrinityLoopOutcome {
    /// True iff a Verifier ACCEPT terminated the loop within budget.
    pub accepted: bool,
    /// Rounds executed (1-based; ≤ max_rounds).
    pub rounds: u32,
    /// The Worker output from the final round (the answer when accepted; the best-effort when budget-exhausted).
    pub final_answer: String,
    /// The ordered JSONL trace.
    pub trace: Vec<TrinityEvent>,
}

/// The injected role implementations. Slice 1 keeps the loop provider-free + testable; slice 2 supplies a real
/// executor that calls the heuristic-selected models over the OpenAI-compat provider boundary.
pub trait TrinityRoleExecutor {
    /// Thinker: plan the approach for `objective`, given the prior round's verifier feedback (empty on round 1).
    fn think(&mut self, objective: &str, feedback: &str) -> String;
    /// Worker: produce work from the Thinker's `plan`.
    fn work(&mut self, plan: &str) -> String;
    /// Verifier: judge the Worker's `work` against `objective` → (verdict, feedback-for-next-round).
    fn verify(&mut self, work: &str, objective: &str) -> (VerifierVerdict, String);
}

/// Drive the flat ≤`max_rounds` Thinker→Worker→Verifier loop. Terminates on the first Verifier ACCEPT (the
/// answer = that round's Worker output) or when the round budget is exhausted (honest: accepted=false, the last
/// Worker output is the best-effort answer). Pure orchestration over the injected `exec`; emits the full trace.
pub fn run_trinity_loop(
    objective: &str,
    max_rounds: u32,
    exec: &mut dyn TrinityRoleExecutor,
) -> TrinityLoopOutcome {
    let max_rounds = max_rounds.clamp(1, DEFAULT_MAX_ROUNDS);
    let mut trace = Vec::new();
    trace.push(TrinityEvent::LoopStarted {
        schema_version: 1,
        objective_hash: blake3::hash(objective.as_bytes()).to_hex().to_string(),
        max_rounds,
    });

    let mut feedback = String::new();
    let mut final_answer = String::new();
    let mut round = 0;
    let mut accepted = false;

    while round < max_rounds {
        round += 1;

        trace.push(TrinityEvent::ThinkerTurn { round });
        let plan = exec.think(objective, &feedback);

        trace.push(TrinityEvent::WorkerTurn { round });
        final_answer = exec.work(&plan);

        trace.push(TrinityEvent::VerifierTurn { round });
        let (verdict, next_feedback) = exec.verify(&final_answer, objective);
        match verdict {
            VerifierVerdict::Accept => {
                trace.push(TrinityEvent::VerifierAccept { round });
                accepted = true;
                break;
            }
            VerifierVerdict::Repair => {
                trace.push(TrinityEvent::VerifierRepair { round });
                feedback = next_feedback;
            }
        }
    }

    if !accepted {
        trace.push(TrinityEvent::BudgetExhausted { rounds: round });
    }
    trace.push(TrinityEvent::LoopCompleted {
        accepted,
        rounds: round,
    });

    TrinityLoopOutcome {
        accepted,
        rounds: round,
        final_answer,
        trace,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A scripted executor: the Verifier accepts on a configured round; counts role calls.
    struct ScriptedExec {
        accept_on_round: u32,
        round: u32,
        think_calls: u32,
        work_calls: u32,
        verify_calls: u32,
    }
    impl ScriptedExec {
        fn new(accept_on_round: u32) -> Self {
            Self {
                accept_on_round,
                round: 0,
                think_calls: 0,
                work_calls: 0,
                verify_calls: 0,
            }
        }
    }
    impl TrinityRoleExecutor for ScriptedExec {
        fn think(&mut self, _o: &str, _f: &str) -> String {
            self.round += 1;
            self.think_calls += 1;
            format!("plan-{}", self.round)
        }
        fn work(&mut self, plan: &str) -> String {
            self.work_calls += 1;
            format!("work-from-{plan}")
        }
        fn verify(&mut self, _w: &str, _o: &str) -> (VerifierVerdict, String) {
            self.verify_calls += 1;
            if self.round >= self.accept_on_round {
                (VerifierVerdict::Accept, String::new())
            } else {
                (VerifierVerdict::Repair, format!("fix round {}", self.round))
            }
        }
    }

    #[test]
    fn role_indices_match_the_reference_coordination_head() {
        assert_eq!(TrinityRole::Worker.role_index(), 0);
        assert_eq!(TrinityRole::Thinker.role_index(), 1);
        assert_eq!(TrinityRole::Verifier.role_index(), 2);
    }

    #[test]
    fn accepts_on_first_round_runs_exactly_one_twv_cycle() {
        let mut exec = ScriptedExec::new(1);
        let out = run_trinity_loop("solve x", DEFAULT_MAX_ROUNDS, &mut exec);
        assert!(out.accepted);
        assert_eq!(out.rounds, 1);
        assert_eq!(out.final_answer, "work-from-plan-1");
        assert_eq!(
            (exec.think_calls, exec.work_calls, exec.verify_calls),
            (1, 1, 1)
        );
        // trace: started, T, W, V, accept, completed.
        assert!(matches!(
            out.trace.first(),
            Some(TrinityEvent::LoopStarted {
                schema_version: 1,
                ..
            })
        ));
        assert!(out
            .trace
            .contains(&TrinityEvent::VerifierAccept { round: 1 }));
        assert!(out.trace.contains(&TrinityEvent::LoopCompleted {
            accepted: true,
            rounds: 1
        }));
        assert!(!out
            .trace
            .iter()
            .any(|e| matches!(e, TrinityEvent::BudgetExhausted { .. })));
    }

    #[test]
    fn repairs_then_accepts_loops_until_accept() {
        let mut exec = ScriptedExec::new(3);
        let out = run_trinity_loop("solve x", DEFAULT_MAX_ROUNDS, &mut exec);
        assert!(out.accepted);
        assert_eq!(out.rounds, 3);
        assert_eq!(exec.verify_calls, 3);
        assert_eq!(
            out.trace
                .iter()
                .filter(|e| matches!(e, TrinityEvent::VerifierRepair { .. }))
                .count(),
            2
        );
    }

    #[test]
    fn never_accepting_exhausts_the_budget_honestly() {
        let mut exec = ScriptedExec::new(99); // never accepts
        let out = run_trinity_loop("solve x", DEFAULT_MAX_ROUNDS, &mut exec);
        assert!(
            !out.accepted,
            "budget-exhausted run is honestly not-accepted"
        );
        assert_eq!(out.rounds, DEFAULT_MAX_ROUNDS);
        assert!(out
            .trace
            .contains(&TrinityEvent::BudgetExhausted { rounds: 5 }));
        assert!(out.trace.contains(&TrinityEvent::LoopCompleted {
            accepted: false,
            rounds: 5
        }));
        assert_eq!(out.final_answer, "work-from-plan-5"); // best-effort last work
    }

    #[test]
    fn max_rounds_is_clamped_to_the_reference_cap() {
        let mut exec = ScriptedExec::new(99);
        let out = run_trinity_loop("x", 100, &mut exec); // asks for 100 → clamped to 5
        assert_eq!(out.rounds, DEFAULT_MAX_ROUNDS);
    }

    #[test]
    fn trace_is_jsonl_serializable_with_schema_version() {
        let mut exec = ScriptedExec::new(1);
        let out = run_trinity_loop("x", 5, &mut exec);
        for event in &out.trace {
            let line = serde_json::to_string(event).expect("event serializes");
            assert!(line.contains("\"event\""), "{line}");
        }
    }
}
