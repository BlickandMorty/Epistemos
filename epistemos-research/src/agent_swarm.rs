//! HELIOS V5 — VaultGatedSwarm + Hermes Gateway substrate
//! (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-AGENT-SWARM guard
//!
//! Per HELIOS v4 preservation `source_docs/epistenos_build_prompt.md`
//! §2.4 (`src/agent.rs`) + §3.4 (Hermes Gateway wiring).
//!
//! ## Components
//!
//! - **VaultGatedSwarm** — biometrically secured multi-agent
//!   system. Each agent has signature + capabilities; messages
//!   are Ed25519-signed and capability-granted.
//! - **Hermes Gateway** — quarantined cloud sidecar with shared
//!   mmap arena + mach-port signaling. Cloud responses are
//!   Resonance-Gate-classified before promotion.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// One canonical task-budget axis. Per the build-prompt §2.4
/// `TaskBudget` struct.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TaskBudgetAxis {
    /// Maximum number of tokens to consume.
    MaxTokens,
    /// Maximum cost in dollars.
    MaxCost,
    /// Maximum wall-clock time allowed.
    MaxTime,
    /// Minimum acceptable Resonance score for the result.
    MinResonance,
    /// Hard deadline (UTC timestamp).
    Deadline,
}

/// All five task-budget axes in canonical order.
pub const FIVE_BUDGET_AXES: [TaskBudgetAxis; 5] = [
    TaskBudgetAxis::MaxTokens,
    TaskBudgetAxis::MaxCost,
    TaskBudgetAxis::MaxTime,
    TaskBudgetAxis::MinResonance,
    TaskBudgetAxis::Deadline,
];

/// Outcome of the Hermes Gateway Resonance-Gate classification
/// applied to a cloud response. Per the build-prompt §3.4 wiring.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HermesVerificationOutcome {
    /// τ = 0 → promote to L3-L5 residency.
    VerifiedPromote,
    /// Edge claim → trigger Evidence Supremacy Protocol.
    EdgeTriggerEsp,
    /// Contradicted → quarantine the response.
    ContradictedQuarantine,
}

/// Canonical shared-mmap arena size for the Hermes Gateway, in
/// bytes. Per the build-prompt §3.4 ("~200KB").
pub const HERMES_ARENA_BYTES: usize = 200 * 1024;

/// Cryptographic signature scheme for inter-agent messages per
/// the build-prompt §2.4: "Ed25519 signed, capability-granted,
/// resonance-classified."
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentMessageSignature {
    /// Ed25519 — canonical for inter-agent message integrity.
    Ed25519,
}

/// Three properties every AgentMessage must satisfy per the
/// build-prompt §2.4. The struct is a doctrinal manifest, not an
/// implementation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct AgentMessageContract {
    /// Cryptographic signature on the message bytes.
    pub signature: AgentMessageSignature,
    /// True when the sender's capability grant authorizes the
    /// requested operation.
    pub capability_granted: bool,
    /// True when the message has been Resonance-Gate classified.
    pub resonance_classified: bool,
}

impl AgentMessageContract {
    /// Returns true when ALL three contract requirements hold.
    pub fn satisfies_canonical_contract(&self) -> bool {
        self.capability_granted && self.resonance_classified
    }
}

/// Three Hermes verification outcomes in canonical order.
pub const THREE_HERMES_OUTCOMES: [HermesVerificationOutcome; 3] = [
    HermesVerificationOutcome::VerifiedPromote,
    HermesVerificationOutcome::EdgeTriggerEsp,
    HermesVerificationOutcome::ContradictedQuarantine,
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn five_budget_axes_in_canonical_order() {
        assert_eq!(FIVE_BUDGET_AXES.len(), 5);
        assert_eq!(FIVE_BUDGET_AXES[0], TaskBudgetAxis::MaxTokens);
        assert_eq!(FIVE_BUDGET_AXES[4], TaskBudgetAxis::Deadline);
    }

    #[test]
    fn five_budget_axes_are_distinct() {
        let set: std::collections::HashSet<TaskBudgetAxis> =
            FIVE_BUDGET_AXES.iter().copied().collect();
        assert_eq!(set.len(), 5);
    }

    #[test]
    fn hermes_arena_size_is_200kb() {
        // Per build-prompt §3.4: shared mmap arena ~200KB.
        assert_eq!(HERMES_ARENA_BYTES, 200 * 1024);
    }

    #[test]
    fn three_hermes_outcomes_in_canonical_order() {
        assert_eq!(THREE_HERMES_OUTCOMES.len(), 3);
        assert_eq!(THREE_HERMES_OUTCOMES[0], HermesVerificationOutcome::VerifiedPromote);
        assert_eq!(
            THREE_HERMES_OUTCOMES[2],
            HermesVerificationOutcome::ContradictedQuarantine
        );
    }

    #[test]
    fn three_hermes_outcomes_are_distinct() {
        let set: std::collections::HashSet<HermesVerificationOutcome> =
            THREE_HERMES_OUTCOMES.iter().copied().collect();
        assert_eq!(set.len(), 3);
    }

    #[test]
    fn agent_message_contract_satisfies_canon_when_all_three_hold() {
        let c = AgentMessageContract {
            signature: AgentMessageSignature::Ed25519,
            capability_granted: true,
            resonance_classified: true,
        };
        assert!(c.satisfies_canonical_contract());
    }

    #[test]
    fn agent_message_contract_fails_when_capability_not_granted() {
        let c = AgentMessageContract {
            signature: AgentMessageSignature::Ed25519,
            capability_granted: false,
            resonance_classified: true,
        };
        assert!(!c.satisfies_canonical_contract());
    }

    #[test]
    fn agent_message_contract_fails_when_not_resonance_classified() {
        let c = AgentMessageContract {
            signature: AgentMessageSignature::Ed25519,
            capability_granted: true,
            resonance_classified: false,
        };
        assert!(!c.satisfies_canonical_contract());
    }

    #[test]
    fn task_budget_axis_serializes_in_snake_case() {
        for (axis, expected) in [
            (TaskBudgetAxis::MaxTokens, "\"max_tokens\""),
            (TaskBudgetAxis::MaxCost, "\"max_cost\""),
            (TaskBudgetAxis::MaxTime, "\"max_time\""),
            (TaskBudgetAxis::MinResonance, "\"min_resonance\""),
            (TaskBudgetAxis::Deadline, "\"deadline\""),
        ] {
            assert_eq!(serde_json::to_string(&axis).unwrap(), expected);
        }
    }

    #[test]
    fn hermes_outcome_serializes_in_snake_case() {
        for (outcome, expected) in [
            (HermesVerificationOutcome::VerifiedPromote, "\"verified_promote\""),
            (HermesVerificationOutcome::EdgeTriggerEsp, "\"edge_trigger_esp\""),
            (
                HermesVerificationOutcome::ContradictedQuarantine,
                "\"contradicted_quarantine\"",
            ),
        ] {
            assert_eq!(serde_json::to_string(&outcome).unwrap(), expected);
        }
    }

    #[test]
    fn round_trip_through_json() {
        for axis in FIVE_BUDGET_AXES {
            let json = serde_json::to_string(&axis).unwrap();
            let parsed: TaskBudgetAxis = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, axis);
        }
        for outcome in THREE_HERMES_OUTCOMES {
            let json = serde_json::to_string(&outcome).unwrap();
            let parsed: HermesVerificationOutcome = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, outcome);
        }
        let c = AgentMessageContract {
            signature: AgentMessageSignature::Ed25519,
            capability_granted: true,
            resonance_classified: true,
        };
        let json = serde_json::to_string(&c).unwrap();
        let parsed: AgentMessageContract = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, c);
    }
}
