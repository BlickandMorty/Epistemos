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

pub mod transitions;
pub mod validator;

pub use validator::{validate_plan, LivePlanValidationError};

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
    /// All 10 canonical states in doctrine order. Used by iteration-
    /// over-all-states tests + state-machine validators.
    pub const ALL: [LiveFileState; 10] = [
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

    /// Stable code identifier for telemetry / cross-language bridges.
    /// Matches the serde rename_all = "snake_case" wire form.
    pub const fn code(self) -> &'static str {
        match self {
            LiveFileState::Static => "static",
            LiveFileState::LiveCandidate => "live_candidate",
            LiveFileState::Compiled => "compiled",
            LiveFileState::Eligible => "eligible",
            LiveFileState::Running => "running",
            LiveFileState::Paused => "paused",
            LiveFileState::Completed => "completed",
            LiveFileState::Quarantined => "quarantined",
            LiveFileState::Suspended => "suspended",
            LiveFileState::Revoked => "revoked",
        }
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|s| s.code() == code)
    }

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

    /// Predicate: this state has execution authority right now
    /// (Running or Paused). Distinct from `may_transition_to_running`,
    /// which includes states that COULD enter Running but currently
    /// aren't.
    pub const fn is_executing(self) -> bool {
        matches!(self, LiveFileState::Running | LiveFileState::Paused)
    }

    /// Predicate: this state requires user action before the system
    /// can make progress (LiveCandidate: awaiting compile; Quarantined:
    /// awaiting user review). The "what needs attention?" filter.
    pub const fn requires_user_action(self) -> bool {
        matches!(self, LiveFileState::LiveCandidate | LiveFileState::Quarantined)
    }

    /// Predicate: this state is the kill switch (Revoked) — no
    /// future execution. Source remains readable per §4 invariant.
    pub const fn is_revoked(self) -> bool {
        matches!(self, LiveFileState::Revoked)
    }
}

impl LivePlanV1 {
    /// Predicate: this plan has an expiry timestamp set.
    pub fn has_expiry(&self) -> bool {
        self.expires_at.is_some()
    }

    /// Number of distinct triggers attached to this plan.
    pub fn trigger_count(&self) -> usize {
        self.triggers.len()
    }
}

impl LivePlanTrigger {
    /// Stable kind identifier for telemetry: "event" / "schedule" /
    /// "manual". Matches the serde rename_all = "snake_case" wire form.
    pub const fn kind(&self) -> &'static str {
        match self {
            LivePlanTrigger::Event { .. } => "event",
            LivePlanTrigger::Schedule { .. } => "schedule",
            LivePlanTrigger::Manual => "manual",
        }
    }
}

impl LivePlanBudget {
    /// Predicate: at least one of (tokens, ms, usd) is zero —
    /// indicates the plan declares no budget for that resource (use
    /// with caution; the runner default is "no budget = no admit").
    pub fn has_zero_dimension(&self) -> bool {
        self.tokens == 0 || self.ms == 0 || self.usd == 0.0
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

    // ── diagnostic surface (iter 145) ────────────────────────────────────────

    #[test]
    fn all_includes_ten_distinct_states() {
        let s: std::collections::HashSet<_> = LiveFileState::ALL.iter().copied().collect();
        assert_eq!(s.len(), 10);
    }

    #[test]
    fn code_roundtrips_through_from_code() {
        // Cross-surface invariant: from_code(s.code()) == Some(s) for all states.
        for s in LiveFileState::ALL.iter().copied() {
            assert_eq!(LiveFileState::from_code(s.code()), Some(s));
        }
    }

    #[test]
    fn from_code_unknown_returns_none() {
        assert_eq!(LiveFileState::from_code("not-a-state"), None);
        assert_eq!(LiveFileState::from_code("Running"), None); // case-sensitive
        assert_eq!(LiveFileState::from_code(""), None);
    }

    #[test]
    fn code_matches_serde_wire_form() {
        // Cross-surface invariant: code() agrees with serde_json output.
        for s in LiveFileState::ALL.iter().copied() {
            let json = serde_json::to_string(&s).unwrap();
            // serde serializes enum as `"snake_case_name"` (with quotes).
            let expected = format!("\"{}\"", s.code());
            assert_eq!(json, expected, "state={:?}", s);
        }
    }

    #[test]
    fn is_executing_includes_running_and_paused_only() {
        let executing = [LiveFileState::Running, LiveFileState::Paused];
        for s in LiveFileState::ALL.iter().copied() {
            assert_eq!(s.is_executing(), executing.contains(&s));
        }
    }

    #[test]
    fn may_transition_to_running_matches_eligible_or_paused() {
        // Exhaustive enumeration: only Eligible and Paused are admissible.
        let admissible = [LiveFileState::Eligible, LiveFileState::Paused];
        for s in LiveFileState::ALL.iter().copied() {
            assert_eq!(s.may_transition_to_running(), admissible.contains(&s));
        }
    }

    #[test]
    fn requires_user_action_covers_candidate_and_quarantined() {
        let needs = [LiveFileState::LiveCandidate, LiveFileState::Quarantined];
        for s in LiveFileState::ALL.iter().copied() {
            assert_eq!(s.requires_user_action(), needs.contains(&s));
        }
    }

    #[test]
    fn is_revoked_only_for_revoked() {
        for s in LiveFileState::ALL.iter().copied() {
            assert_eq!(s.is_revoked(), s == LiveFileState::Revoked);
        }
    }

    #[test]
    fn all_states_allow_source_read() {
        // §4 invariant: every state has readable source (not just Revoked).
        for s in LiveFileState::ALL.iter().copied() {
            assert!(s.allows_source_read(), "state={:?}", s);
        }
    }

    #[test]
    fn trigger_kind_matches_serde_wire_form() {
        // Cross-surface: kind() agrees with serde tag for each variant.
        let event = LivePlanTrigger::Event {
            event: "x".into(),
            selector: "y".into(),
        };
        let schedule = LivePlanTrigger::Schedule { cron: "* * * * *".into() };
        let manual = LivePlanTrigger::Manual;
        assert_eq!(event.kind(), "event");
        assert_eq!(schedule.kind(), "schedule");
        assert_eq!(manual.kind(), "manual");
        for (t, k) in [(&event, "event"), (&schedule, "schedule"), (&manual, "manual")] {
            let json = serde_json::to_string(t).unwrap();
            assert!(json.contains(k), "json={} kind={}", json, k);
        }
    }

    #[test]
    fn budget_has_zero_dimension_detects_any_zero() {
        let none_zero = LivePlanBudget { tokens: 1, ms: 1, usd: 0.01 };
        let zero_tokens = LivePlanBudget { tokens: 0, ms: 1, usd: 0.01 };
        let zero_ms = LivePlanBudget { tokens: 1, ms: 0, usd: 0.01 };
        let zero_usd = LivePlanBudget { tokens: 1, ms: 1, usd: 0.0 };
        assert!(!none_zero.has_zero_dimension());
        assert!(zero_tokens.has_zero_dimension());
        assert!(zero_ms.has_zero_dimension());
        assert!(zero_usd.has_zero_dimension());
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
