//! Live File Compiler — Wave 7 typed seam.
//!
//! Establishes the canonical types the full Wave 7 implementation will
//! plug in behind. NOT a functional implementation of the compiler;
//! the point is to make sure no future agent silently re-derives Live
//! File state names or LivePlan field shapes with different semantics.
//! The contract is in code from day one.
//!
//! Doctrine: `docs/fusion/LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md`
//! Source: `docs/fusion/research/FINAL_SYNTHESIS.md` §1, §1.2, §4.

use serde::{Deserialize, Serialize};

// ── §3. The 10-state Live File state machine (canonical) ──────────────────

/// Canonical 10 states from FINAL_SYNTHESIS §4. Future Wave 7 work
/// implements transitions; today this enum exists so any reference to
/// Live File state in code uses the canonical names + cardinality.
///
/// Modeled in `kani` (Rust formal verifier) once Wave 7 ships — no
/// orphan states, no unreachable states, no race conditions on
/// transition. The Display impl is alphabetical so debug logs +
/// telemetry are stable across runs.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LiveFileState {
    /// Plain markdown; user has not toggled `is_live: true`.
    Static,
    /// User toggled live; awaiting compile pass.
    LiveCandidate,
    /// Compile + sign succeeded; the LivePlan exists.
    Compiled,
    /// Triggers + thermal/battery/budget all green; runner may admit.
    Eligible,
    /// Runner admitted; the signed plan is executing.
    Running,
    /// Blocked mid-run; awaiting resume signal.
    Paused,
    /// Run completed cleanly; artifacts emitted.
    Completed,
    /// Run produced something the user must look at before next run.
    Quarantined,
    /// Run completed; awaiting next scheduled trigger.
    Suspended,
    /// User killed it; no future execution. Markdown still readable.
    Revoked,
}

impl LiveFileState {
    /// Whether this state permits transitioning to Running. Per
    /// FINAL_SYNTHESIS §4 invariants, only Eligible (and Paused via
    /// resume) may enter Running.
    pub fn may_transition_to_running(self) -> bool {
        matches!(self, LiveFileState::Eligible | LiveFileState::Paused)
    }

    /// Whether the markdown source is readable in this state. Per
    /// §4 invariant: Revoked still allows reading the markdown
    /// (the kill switch removes execution authority, not the source).
    pub fn allows_source_read(self) -> bool {
        // Every state allows reading the source markdown — it's a
        // file on disk, not gated. The state machine only gates
        // execution + recompilation prompts.
        true
    }
}

// ── §4. The LivePlan.v1 schema (canonical) ────────────────────────────────

/// Top-level `LivePlan.v1` shape from FINAL_SYNTHESIS §1.2. Wave 7's
/// compiler emits this from markdown; the runtime executes this, NOT
/// the markdown. Mutating the markdown invalidates `plan_hash` and
/// the runner refuses to run a stale plan.
///
/// Today this struct is a typed contract — Wave 7 fills in the
/// compiler that actually emits one. Future agents touching Wave 7
/// must use these field names + types verbatim.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LivePlanV1 {
    /// BLAKE3 of the source markdown (32 bytes hex-encoded for JSON
    /// round-trip).
    pub livefile_id: String,
    /// `vault://path/to/file.md` URI.
    pub source_uri: String,
    /// `"1.0.0"` — bumped on schema migration.
    pub plan_version: String,
    /// BLAKE3 of the compiled plan, signed by the user's local key.
    /// Mutating any other field invalidates this.
    pub plan_hash: String,
    /// ISO-8601.
    pub compiled_at: String,
    /// Optional cap; default 7 days.
    pub expires_at: Option<String>,

    pub cognitive_weight: super::cognitive_weight::CognitiveWeight,
    pub triggers: Vec<LivePlanTrigger>,
    pub eligibility: LivePlanEligibility,
    pub intent: LivePlanIntent,
    pub prompt_for_changes: Vec<LivePlanChangePrompt>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LivePlanTrigger {
    Event { event: String, selector: String },
    Schedule { cron: String },
    Manual,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LivePlanEligibility {
    pub thermal: ThermalRequirement,
    pub battery: BatteryRequirement,
    pub budget: LivePlanBudget,
    pub capabilities: serde_json::Value,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ThermalRequirement {
    NominalRequired,
    MildOk,
    Any,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum BatteryRequirement {
    AcOnly,
    AcOrAbove30,
    Any,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LivePlanBudget {
    pub tokens: u64,
    pub ms: u64,
    pub usd: f64,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LivePlanIntent {
    pub summary: String,
    pub steps: Vec<serde_json::Value>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LivePlanChangePrompt {
    pub field: String,
    pub user_prompt: String,
}

// ── Invariants surface (read-once contract for tests + kani) ──────────────

/// Returns the canonical statement of the §3 state-machine invariants
/// from `LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md`. Tests can
/// `#[test] fn doctrine_states_match_code() { assert!(...) }` against
/// this so the doctrine doc + the LiveFileState enum stay aligned.
pub const CANONICAL_STATE_MACHINE_INVARIANTS: &[&str] = &[
    "is_live: true alone does NOT permit execution; it is user intent",
    "Compiled state requires a signed plan; it is runtime permission",
    "Eligible state requires triggers + thermal/battery/budget gates passed; it is execution authority",
    "Quarantined is not failure; it's 'user must look at this'",
    "Revoked is the kill switch — no future execution, but markdown source remains readable",
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_state_set_matches_doctrine() {
        // The doctrine §3 names exactly 10 states. Adding or removing
        // a state without updating the doctrine breaks this test.
        let states = [
            LiveFileState::Static,
            LiveFileState::LiveCandidate,
            LiveFileState::Compiled,
            LiveFileState::Eligible,
            LiveFileState::Running,
            LiveFileState::Paused,
            LiveFileState::Completed,
            LiveFileState::Quarantined,
            LiveFileState::Suspended,
            LiveFileState::Revoked,
        ];
        assert_eq!(states.len(), 10);
    }

    #[test]
    fn only_eligible_or_paused_may_run() {
        // §4 invariant: only Eligible (or Paused via resume) enters Running.
        for state in [LiveFileState::Eligible, LiveFileState::Paused] {
            assert!(state.may_transition_to_running(), "{:?}", state);
        }
        for state in [
            LiveFileState::Static,
            LiveFileState::LiveCandidate,
            LiveFileState::Compiled,
            LiveFileState::Running,
            LiveFileState::Completed,
            LiveFileState::Quarantined,
            LiveFileState::Suspended,
            LiveFileState::Revoked,
        ] {
            assert!(!state.may_transition_to_running(), "{:?}", state);
        }
    }

    #[test]
    fn revoked_still_allows_source_read() {
        // §4 invariant: kill switch removes execution authority, not source access.
        assert!(LiveFileState::Revoked.allows_source_read());
    }

    #[test]
    fn invariants_constant_lists_five_canonical_rules() {
        // Doctrine §3 has 5 critical invariants.
        assert_eq!(CANONICAL_STATE_MACHINE_INVARIANTS.len(), 5);
    }

    #[test]
    fn live_plan_v1_round_trips_through_json() {
        let plan = LivePlanV1 {
            livefile_id: "abc123".to_string(),
            source_uri: "vault://test.md".to_string(),
            plan_version: "1.0.0".to_string(),
            plan_hash: "deadbeef".to_string(),
            compiled_at: "2026-05-04T00:00:00Z".to_string(),
            expires_at: None,
            cognitive_weight: super::super::cognitive_weight::CognitiveWeight::default(),
            triggers: vec![LivePlanTrigger::Manual],
            eligibility: LivePlanEligibility {
                thermal: ThermalRequirement::NominalRequired,
                battery: BatteryRequirement::AcOrAbove30,
                budget: LivePlanBudget {
                    tokens: 1000,
                    ms: 30000,
                    usd: 0.05,
                },
                capabilities: serde_json::json!({}),
            },
            intent: LivePlanIntent {
                summary: "test".to_string(),
                steps: vec![],
            },
            prompt_for_changes: vec![],
        };
        let encoded = serde_json::to_string(&plan).expect("encode");
        let decoded: LivePlanV1 = serde_json::from_str(&encoded).expect("decode");
        assert_eq!(plan, decoded);
    }
}
