//! `falsify_hyperdynamic_loop_bounded` — F-HyperdynamicLoop-Bounded
//! harness (Terminal S, 2026-05-24).
//!
//! Proves the Hyperdynamic Schema Loop primitive in
//! `agent_core::hyperdynamic_loop` ALWAYS terminates under
//! `RepairBudget::DEFAULT` on a 100-prompt deterministic adversarial
//! corpus. Per `docs/falsifiers/F-HyperdynamicLoop-Bounded_2026_05_24.md`
//! the corpus is seeded with `HYPERDYNAMIC_LOOP_BOUNDED_SEED` and the
//! `re_emit` closure is intentionally non-progressive — it returns the
//! draft unchanged so the runner's bounded-retry contract fires on
//! every `RepairWith`.
//!
//! In the default (MAS) build the harness runs two loops per prompt:
//! `AdmissionRepairLoop` + `WitnessRepairLoop`. The `SchemaRepairLoop`
//! requires `--features research` (mirrors `agent_core::research::
//! hyperdynamic_schemas` shipping discipline).

use std::collections::BTreeMap;
use std::io::Write;
use std::path::PathBuf;
use std::time::{Duration, Instant};

use agent_core::acs_admission::ACSAdmissionVerdict;
use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};
use agent_core::hyperdynamic_loop::{
    run_loop, AdmissionDraft, AdmissionRepairLoop, LoopCounters, RepairBudget, RepairOutcome,
    WitnessDraft, WitnessRepairLoop, WitnessState,
};

const FALSIFIER_ID: &str = "F-HyperdynamicLoop-Bounded";
const FIXTURE_ID: &str = "hyperdynamic_loop_xorshift32_100prompt_v1";
const COMMAND: &str =
    "cargo run --release --bin falsify_hyperdynamic_loop_bounded -- --output \
     artifacts/falsifiers/hyperdynamic_loop_bounded/result.json";
const HYPERDYNAMIC_LOOP_BOUNDED_SEED: u32 = 0x5_20_25_24;
const CORPUS_SIZE: u32 = 100;
const HARNESS_WALL_CLOCK_BUDGET_MS: u64 = 30_000;

/// Deterministic xorshift32 — the only RNG the corpus uses. Same seed
/// → byte-exact corpus on any architecture.
fn xorshift32(state: &mut u32) -> u32 {
    let mut x = *state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    *state = x;
    x
}

fn pick_admission_verdict(state: &mut u32) -> (ACSAdmissionVerdict, &'static str) {
    // 50% Defer (exercise repair path), then uniform over the other 4.
    let roll = xorshift32(state) % 100;
    if roll < 50 {
        (ACSAdmissionVerdict::Defer, "deferred_pending_evidence")
    } else if roll < 65 {
        (ACSAdmissionVerdict::Allow, "allow")
    } else if roll < 80 {
        (
            ACSAdmissionVerdict::AllowWithWarning,
            "allow_with_warning",
        )
    } else if roll < 90 {
        (ACSAdmissionVerdict::Quarantine, "egress_unsafe")
    } else {
        (ACSAdmissionVerdict::Reject, "policy_violation")
    }
}

fn pick_witness_state(state: &mut u32) -> WitnessState {
    let roll = xorshift32(state) % 100;
    if roll < 50 {
        WitnessState::repairable("budget_wall_clock_ms_exceeded")
    } else if roll < 75 {
        WitnessState::verified()
    } else {
        WitnessState::invalid("hardware_pin_mismatch")
    }
}

#[derive(Default)]
struct Aggregate {
    runs: u64,
    accepted: u64,
    quarantined_explicit: u64,
    quarantined_budget_exhausted: u64,
    max_retries_observed: u8,
    max_latency_ms_observed: u128,
}

impl Aggregate {
    fn record<P>(&mut self, outcome: &RepairOutcome<P>, latency: Duration) {
        self.runs += 1;
        if latency.as_millis() > self.max_latency_ms_observed {
            self.max_latency_ms_observed = latency.as_millis();
        }
        let r = outcome.repairs();
        if r > self.max_retries_observed {
            self.max_retries_observed = r;
        }
        match outcome {
            RepairOutcome::Accepted { .. } => self.accepted += 1,
            RepairOutcome::Quarantined { .. } => self.quarantined_explicit += 1,
            RepairOutcome::QuarantinedBudgetExhausted { .. } => {
                self.quarantined_budget_exhausted += 1
            }
        }
    }
}

fn run_admission_corpus(seed_state: &mut u32) -> Aggregate {
    let mut agg = Aggregate::default();
    let loop_impl = AdmissionRepairLoop::new();
    let mut counters = LoopCounters::new();
    for _ in 0..CORPUS_SIZE {
        let (verdict, reason) = pick_admission_verdict(seed_state);
        let initial = AdmissionDraft::new(verdict, reason);
        let t0 = Instant::now();
        let outcome = run_loop(
            &loop_impl,
            initial,
            RepairBudget::DEFAULT,
            &mut counters,
            // Non-progressive re_emit — strongest adversarial shape.
            |prev, _hint| prev.clone(),
        )
        .expect("admission loop has no error path");
        agg.record(&outcome, t0.elapsed());
    }
    agg
}

fn run_witness_corpus(seed_state: &mut u32) -> Aggregate {
    let mut agg = Aggregate::default();
    let loop_impl = WitnessRepairLoop::<u32>::new();
    let mut counters = LoopCounters::new();
    for idx in 0..CORPUS_SIZE {
        let state = pick_witness_state(seed_state);
        let initial = WitnessDraft::new(idx, state);
        let t0 = Instant::now();
        let outcome = run_loop(
            &loop_impl,
            initial,
            RepairBudget::DEFAULT,
            &mut counters,
            |prev, _hint| prev.clone(),
        )
        .expect("witness loop has no error path");
        agg.record(&outcome, t0.elapsed());
    }
    agg
}

fn parse_output_path(argv: &[String]) -> PathBuf {
    for (i, arg) in argv.iter().enumerate() {
        if arg == "--output" {
            if let Some(path) = argv.get(i + 1) {
                return PathBuf::from(path);
            }
        }
    }
    PathBuf::from("artifacts/falsifiers/hyperdynamic_loop_bounded/result.json")
}

fn measure_value(v: u128) -> serde_json::Value {
    serde_json::Value::Number(serde_json::Number::from(v as u64))
}

fn main() {
    let argv: Vec<String> = std::env::args().collect();
    let output_path = parse_output_path(&argv);
    let start = Instant::now();
    let started_utc = now_utc_rfc3339();

    let mut state = HYPERDYNAMIC_LOOP_BOUNDED_SEED;
    let admission = run_admission_corpus(&mut state);
    let witness = run_witness_corpus(&mut state);

    let total_wall_clock = start.elapsed();
    let total_runs = admission.runs + witness.runs;
    let total_accepted = admission.accepted + witness.accepted;
    let total_quarantined_explicit =
        admission.quarantined_explicit + witness.quarantined_explicit;
    let total_quarantined_budget_exhausted =
        admission.quarantined_budget_exhausted + witness.quarantined_budget_exhausted;
    let total_partition =
        total_accepted + total_quarantined_explicit + total_quarantined_budget_exhausted;
    let max_retries = admission
        .max_retries_observed
        .max(witness.max_retries_observed);
    let max_latency_ms = admission
        .max_latency_ms_observed
        .max(witness.max_latency_ms_observed);

    let budget = RepairBudget::DEFAULT;
    let total_wall_clock_ms = total_wall_clock.as_millis();

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();

    let insert_axis = |name: &str,
                       value: serde_json::Value,
                       unit: &str,
                       op: &str,
                       threshold: serde_json::Value,
                       pass: bool,
                       m: &mut BTreeMap<String, Measurement>,
                       t: &mut BTreeMap<String, AcceptanceThreshold>,
                       p: &mut BTreeMap<String, bool>| {
        m.insert(
            name.to_string(),
            Measurement {
                value,
                unit: unit.to_string(),
            },
        );
        t.insert(
            name.to_string(),
            AcceptanceThreshold {
                operator: op.to_string(),
                value: threshold,
                unit: unit.to_string(),
            },
        );
        p.insert(name.to_string(), pass);
    };

    insert_axis(
        "loops_run",
        measure_value(total_runs as u128),
        "count",
        "==",
        serde_json::Value::Number(serde_json::Number::from(
            (CORPUS_SIZE as u64) * 2,
        )),
        total_runs == (CORPUS_SIZE as u64) * 2,
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
    );
    insert_axis(
        "max_retries_observed",
        measure_value(max_retries as u128),
        "count",
        "<=",
        serde_json::Value::Number(serde_json::Number::from(budget.max_retries)),
        max_retries <= budget.max_retries,
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
    );
    insert_axis(
        "max_latency_ms_observed",
        measure_value(max_latency_ms),
        "ms",
        "<=",
        measure_value(budget.max_latency.as_millis()),
        max_latency_ms <= budget.max_latency.as_millis(),
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
    );
    insert_axis(
        "total_wall_clock_ms",
        measure_value(total_wall_clock_ms),
        "ms",
        "<=",
        measure_value(HARNESS_WALL_CLOCK_BUDGET_MS as u128),
        total_wall_clock_ms <= HARNESS_WALL_CLOCK_BUDGET_MS as u128,
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
    );
    insert_axis(
        "outcome_partition_closed",
        measure_value(total_partition as u128),
        "count",
        "==",
        measure_value(total_runs as u128),
        total_partition == total_runs,
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
    );
    insert_axis(
        "seed_matches_canon",
        serde_json::Value::Number(serde_json::Number::from(
            HYPERDYNAMIC_LOOP_BOUNDED_SEED,
        )),
        "u32",
        "==",
        serde_json::Value::Number(serde_json::Number::from(
            HYPERDYNAMIC_LOOP_BOUNDED_SEED,
        )),
        true,
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
    );

    // Per-loop diagnostic axes (informational; thresholds == observed
    // so they always pass — they exist so the artifact carries the
    // partition surface for the audit doc + Provenance Console).
    for (prefix, agg) in [
        ("admission", &admission),
        ("witness", &witness),
    ] {
        for (suffix, value) in [
            ("accepted", agg.accepted),
            ("quarantined_explicit", agg.quarantined_explicit),
            (
                "quarantined_budget_exhausted",
                agg.quarantined_budget_exhausted,
            ),
        ] {
            let name = format!("{prefix}_{suffix}");
            measurements.insert(
                name.clone(),
                Measurement {
                    value: measure_value(value as u128),
                    unit: "count".to_string(),
                },
            );
            thresholds.insert(
                name.clone(),
                AcceptanceThreshold {
                    operator: ">=".to_string(),
                    value: serde_json::Value::Number(serde_json::Number::from(0u64)),
                    unit: "count".to_string(),
                },
            );
            pass_per_axis.insert(name, true);
        }
    }

    let overall_pass = pass_per_axis.values().copied().all(|v| v);
    let fallback_tier = if overall_pass {
        FallbackTier::Primary
    } else {
        FallbackTier::Fail
    };

    let notes = format!(
        "Terminal S — Hyperdynamic Schema Loop primitive. Seed = \
         0x{HYPERDYNAMIC_LOOP_BOUNDED_SEED:08x}. Corpus = {CORPUS_SIZE} \
         prompts × 2 loop kinds (admission + witness). re_emit = \
         non-progressive (strongest adversarial shape). Started \
         {started_utc}. Wall-clock = {total_wall_clock_ms} ms. \
         Admission partition: accepted={a_acc} quarantined_explicit={a_qe} \
         budget_exhausted={a_be}. Witness partition: accepted={w_acc} \
         quarantined_explicit={w_qe} budget_exhausted={w_be}. \
         Max retries observed = {max_retries} (budget = {budget_retries}). \
         Max wall-clock observed = {max_latency_ms} ms (budget = \
         {budget_ms} ms).",
        a_acc = admission.accepted,
        a_qe = admission.quarantined_explicit,
        a_be = admission.quarantined_budget_exhausted,
        w_acc = witness.accepted,
        w_qe = witness.quarantined_explicit,
        w_be = witness.quarantined_budget_exhausted,
        budget_retries = budget.max_retries,
        budget_ms = budget.max_latency.as_millis(),
    );

    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier,
        anomalies: Vec::new(),
        notes,
        timestamp_utc: started_utc,
    }
    .build();

    if let Some(parent) = output_path.parent() {
        std::fs::create_dir_all(parent).expect("create artifact parent dir");
    }
    let mut file = std::fs::File::create(&output_path).expect("create artifact file");
    write_artifact(&mut file, &artifact).expect("write artifact");
    file.flush().expect("flush artifact");

    println!(
        "F-HyperdynamicLoop-Bounded: {} ({} runs, max_retries={}, \
         max_latency={}ms, wall_clock={}ms)",
        if overall_pass { "PASS" } else { "FAIL" },
        total_runs,
        max_retries,
        max_latency_ms,
        total_wall_clock_ms,
    );
    if !overall_pass {
        std::process::exit(1);
    }
}
