//! TRINITY orchestrator — slice 2b: the heuristic `TrinityRoleExecutor` (owner 2026-06-22). Ties the loop
//! (slice 1) to the heuristic role→tier selection (slice 2) by building each role's prompt, routing it to the
//! selected `CapabilityTier`, and parsing the Verifier's ACCEPT/REPAIR verdict. The actual model call is an
//! INJECTED generator `(tier, prompt) -> String` — so this stays pure + cargo-testable; the call site supplies
//! the real generator over the OpenAI-compat provider boundary (slice 2c) + the heuristic→learned router drop-in.

use crate::model_profile::CapabilityTier;

use super::trinity_loop::{TrinityRole, TrinityRoleExecutor, VerifierVerdict};
use super::trinity_routing::select_role_tier;

/// Build the THINKER prompt: plan the approach for `objective`, incorporating the prior round's verifier
/// `feedback` (empty on round 1) so the loop actually self-corrects.
pub fn thinker_prompt(objective: &str, feedback: &str) -> String {
    if feedback.trim().is_empty() {
        format!("Plan a concise, correct approach to this task. Output only the plan.\n\nTask: {objective}")
    } else {
        format!(
            "Revise the plan to fix the verifier's feedback. Output only the revised plan.\n\nTask: {objective}\n\nVerifier feedback: {feedback}"
        )
    }
}

/// Build the WORKER prompt: execute `plan` into a final answer.
pub fn worker_prompt(plan: &str) -> String {
    format!(
        "Execute this plan and produce the final answer. Output only the answer.\n\nPlan: {plan}"
    )
}

/// Build the VERIFIER prompt: judge `work` against `objective`; must reply ACCEPT or REPAIR.
pub fn verifier_prompt(work: &str, objective: &str) -> String {
    format!(
        "Judge whether the answer correctly and completely satisfies the task. Reply with exactly \"ACCEPT\" if \
         it does, otherwise \"REPAIR: <what to fix>\".\n\nTask: {objective}\n\nAnswer: {work}"
    )
}

/// Parse the Verifier's output into a verdict + feedback. CONSERVATIVE / HONEST: ACCEPT only on an explicit
/// accept verdict (the first non-empty line is exactly "ACCEPT", case-insensitive) — anything else (REPAIR,
/// ambiguous, or garbled) is a REPAIR so a confused verifier can never FALSE-ACCEPT a wrong answer. The feedback
/// is the text after a "REPAIR:" marker, else the whole output.
pub fn parse_verifier_verdict(output: &str) -> (VerifierVerdict, String) {
    let trimmed = output.trim();
    let first_line = trimmed.lines().next().unwrap_or("").trim();
    if first_line.eq_ignore_ascii_case("accept") {
        return (VerifierVerdict::Accept, String::new());
    }
    let feedback = trimmed
        .split_once(':')
        .filter(|(head, _)| head.trim().eq_ignore_ascii_case("repair"))
        .map(|(_, tail)| tail.trim().to_string())
        .unwrap_or_else(|| trimmed.to_string());
    (VerifierVerdict::Repair, feedback)
}

/// A heuristic-routed `TrinityRoleExecutor` over an injected generator. `generate(tier, prompt)` performs the
/// real model call (slice 2c wires it to the provider boundary); kept generic so the loop is unit-testable here.
pub struct HeuristicTrinityExecutor<G: FnMut(CapabilityTier, &str) -> String> {
    objective: String,
    generate: G,
}

impl<G: FnMut(CapabilityTier, &str) -> String> HeuristicTrinityExecutor<G> {
    pub fn new(objective: impl Into<String>, generate: G) -> Self {
        Self {
            objective: objective.into(),
            generate,
        }
    }
}

impl<G: FnMut(CapabilityTier, &str) -> String> TrinityRoleExecutor for HeuristicTrinityExecutor<G> {
    fn think(&mut self, objective: &str, feedback: &str) -> String {
        let tier = select_role_tier(TrinityRole::Thinker, objective);
        (self.generate)(tier, &thinker_prompt(objective, feedback))
    }
    fn work(&mut self, plan: &str) -> String {
        // Worker tier is selected from the OBJECTIVE (code/complexity), not the plan text.
        let tier = select_role_tier(TrinityRole::Worker, &self.objective);
        (self.generate)(tier, &worker_prompt(plan))
    }
    fn verify(&mut self, work: &str, objective: &str) -> (VerifierVerdict, String) {
        let tier = select_role_tier(TrinityRole::Verifier, objective);
        let out = (self.generate)(tier, &verifier_prompt(work, objective));
        parse_verifier_verdict(&out)
    }
}

#[cfg(test)]
mod tests {
    use super::super::trinity_loop::run_trinity_loop;
    use super::*;

    #[test]
    fn verdict_parsing_accepts_only_explicit_accept() {
        assert_eq!(parse_verifier_verdict("ACCEPT").0, VerifierVerdict::Accept);
        assert_eq!(
            parse_verifier_verdict("  accept  ").0,
            VerifierVerdict::Accept
        );
        assert_eq!(
            parse_verifier_verdict("Accept\n(looks good)").0,
            VerifierVerdict::Accept
        );
        // anything non-explicit is a REPAIR (never false-accept a confused/garbled verifier).
        assert_eq!(parse_verifier_verdict("").0, VerifierVerdict::Repair);
        assert_eq!(
            parse_verifier_verdict("hmm not sure").0,
            VerifierVerdict::Repair
        );
        assert_eq!(
            parse_verifier_verdict("I accept this is wrong").0,
            VerifierVerdict::Repair
        ); // not a bare ACCEPT
    }

    #[test]
    fn repair_extracts_feedback_after_the_marker() {
        let (verdict, feedback) =
            parse_verifier_verdict("REPAIR: add the edge case for empty input");
        assert_eq!(verdict, VerifierVerdict::Repair);
        assert_eq!(feedback, "add the edge case for empty input");
    }

    #[test]
    fn prompts_carry_objective_plan_and_feedback() {
        assert!(thinker_prompt("sum a list", "").contains("sum a list"));
        assert!(thinker_prompt("sum a list", "handle empty").contains("handle empty"));
        assert!(worker_prompt("step 1").contains("step 1"));
        assert!(verifier_prompt("42", "sum a list").contains("ACCEPT"));
    }

    #[test]
    fn executor_drives_a_real_loop_to_accept_via_the_generator() {
        // A scripted generator: the Verifier (its prompt contains "ACCEPT") accepts on round 2.
        let mut verifier_calls = 0;
        let generate = |_tier: CapabilityTier, prompt: &str| -> String {
            if prompt.contains("Reply with exactly") {
                verifier_calls += 1;
                if verifier_calls >= 2 {
                    "ACCEPT".into()
                } else {
                    "REPAIR: tighten it".into()
                }
            } else if prompt.starts_with("Execute this plan") {
                "the answer".into()
            } else {
                "a plan".into()
            }
        };
        let mut exec = HeuristicTrinityExecutor::new("write a function", generate);
        let out = run_trinity_loop("write a function", 5, &mut exec);
        assert!(out.accepted);
        assert_eq!(out.rounds, 2);
        assert_eq!(out.final_answer, "the answer");
    }
}
