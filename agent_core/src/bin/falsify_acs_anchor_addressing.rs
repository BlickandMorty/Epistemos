//! `falsify_acs_anchor_addressing` — Phase 2 Terminal F' (Round 2)
//! D-27 scoped mini-harness for F-ACS-Anchor-Addressing.
//!
//! The full §3 round trip from `docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md`
//! is `N = 1000` random anchors across four stages (agent runtime emission
//! → lookup → audit canonicalization → 5-plane projection). The fourth
//! stage depends on `AcsAnchor::project_to_plane` + `lookup_via_projection`
//! which are not yet on main. This Round 2 harness is the SCOPED
//! mini-version per the F' prompt:
//!
//! - **N = 100** random anchors (vs the full 1000)
//! - Three of the four stages:
//!   1. **Lookup** — registry insert + lookup returns bytewise-equal anchor
//!   2. **Audit canonicalization** — serde JSON round-trip preserves all
//!      fields (`Hash` + `Eq` byte-compare)
//!   3. **Admission proof boundary** — `SCOPERexAdmissionProof::signed_from_record`
//!      + `verify_against_record` round-trip succeeds; mutated signature
//!      bytes are rejected
//! - The 4th stage (5-plane projection inversion) is left as
//!   `not_in_scope_round_2` per the F' acceptance bar.
//!
//! Emits `primary_witness` when all three measured stages pass on N=100;
//! `failure_report` otherwise. Always writes to
//! `artifacts/falsifiers/acs_anchor_addressing/result.json`.

use std::collections::BTreeMap;

use agent_core::acs_admission::{
    ACSAdmissionVerdict, ACSAuditRecord, ACSOperationKind, CapabilitySignature,
    SCOPERexAdmissionProof,
};
use agent_core::effect::receipt::HmacSha256SigningKey;
use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};
use agent_core::uas::{AcsAnchor, AcsAnchorRegistry, ResidencyTier, RuntimePlane};

const FALSIFIER_ID: &str = "F-ACS-Anchor-Addressing";
const FIXTURE_ID: &str = "f_acs_anchor_addressing_scoped_n100_v1";
const COMMAND: &str = "cargo run --release --bin falsify_acs_anchor_addressing";
const N: usize = 100;
const FOUNDATIONAL_THEOREMS: [&str; 7] = ["E1", "E2", "E3", "E4", "E5", "E6", "E7"];
const PLANES: [RuntimePlane; 5] = [
    RuntimePlane::State,
    RuntimePlane::Episodic,
    RuntimePlane::Assembly,
    RuntimePlane::Controller,
    RuntimePlane::Verification,
];
const TIERS: [ResidencyTier; 3] = [
    ResidencyTier::CurrentApp,
    ResidencyTier::VerifiedFloor,
    ResidencyTier::CapabilityCeiling,
];

fn main() {
    let started_utc = now_utc_rfc3339();
    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();
    let mut anomalies: Vec<serde_json::Value> = Vec::new();

    let anchors: Vec<AcsAnchor> = (0..N).map(synth_anchor).collect();

    let mut registry = AcsAnchorRegistry::with_capacity(N);
    for anchor in anchors.iter() {
        registry.insert(anchor.clone());
    }
    let mut lookup_matches = 0usize;
    let mut lookup_mismatches: Vec<String> = Vec::new();
    for anchor in anchors.iter() {
        match registry.lookup(&anchor.anchor_id) {
            Some(found) if found == anchor => {
                lookup_matches += 1;
            }
            other => {
                lookup_mismatches.push(format!(
                    "{}: expected={:?} got={:?}",
                    anchor.anchor_id, anchor, other
                ));
            }
        }
    }
    insert_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "stage_lookup_matches",
        lookup_matches,
        N,
    );
    if !lookup_mismatches.is_empty() {
        anomalies.push(serde_json::json!({
            "kind": "stage_lookup_mismatches",
            "samples": lookup_mismatches.iter().take(5).collect::<Vec<_>>(),
            "total": lookup_mismatches.len(),
        }));
    }

    let mut audit_matches = 0usize;
    let mut audit_mismatches: Vec<String> = Vec::new();
    for anchor in anchors.iter() {
        let json = match serde_json::to_string(anchor) {
            Ok(s) => s,
            Err(e) => {
                audit_mismatches.push(format!("{}: encode error {}", anchor.anchor_id, e));
                continue;
            }
        };
        let decoded: AcsAnchor = match serde_json::from_str(&json) {
            Ok(a) => a,
            Err(e) => {
                audit_mismatches.push(format!("{}: decode error {}", anchor.anchor_id, e));
                continue;
            }
        };
        if &decoded == anchor {
            audit_matches += 1;
        } else {
            audit_mismatches.push(format!("{}: decoded != original", anchor.anchor_id));
        }
    }
    insert_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "stage_audit_canonicalization",
        audit_matches,
        N,
    );
    if !audit_mismatches.is_empty() {
        anomalies.push(serde_json::json!({
            "kind": "stage_audit_canonicalization_mismatches",
            "samples": audit_mismatches.iter().take(5).collect::<Vec<_>>(),
            "total": audit_mismatches.len(),
        }));
    }

    let signing_key = HmacSha256SigningKey::new([0x5a; 32]);
    let mut proof_round_trip = 0usize;
    let mut proof_tamper_rejected = 0usize;
    let mut proof_errors: Vec<String> = Vec::new();
    for i in 0..N {
        let record = synth_audit_record(i);
        let proof = match SCOPERexAdmissionProof::signed_from_record(&record, &signing_key) {
            Ok(p) => p,
            Err(e) => {
                proof_errors.push(format!("{} sign: {e:?}", record.record_id));
                continue;
            }
        };
        if proof.verify_against_record(&record, &signing_key).is_ok() {
            proof_round_trip += 1;
        } else {
            proof_errors.push(format!("{} verify-original failed", record.record_id));
        }
        let mut tampered = proof.clone();
        tampered.signature = mutate_signature(&proof.signature);
        if tampered.verify_against_record(&record, &signing_key).is_err() {
            proof_tamper_rejected += 1;
        } else {
            proof_errors.push(format!("{} tampered signature accepted", record.record_id));
        }
    }
    insert_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "stage_admission_proof_round_trip",
        proof_round_trip,
        N,
    );
    insert_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "stage_admission_proof_tamper_rejected",
        proof_tamper_rejected,
        N,
    );
    if !proof_errors.is_empty() {
        anomalies.push(serde_json::json!({
            "kind": "stage_admission_proof_errors",
            "samples": proof_errors.iter().take(5).collect::<Vec<_>>(),
            "total": proof_errors.len(),
        }));
    }

    measurements.insert(
        "scoped_n".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(N as u64)),
            unit: "anchors".to_string(),
        },
    );
    thresholds.insert(
        "scoped_n".to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(N as u64)),
            unit: "anchors".to_string(),
        },
    );
    pass_per_axis.insert("scoped_n".to_string(), true);

    measurements.insert(
        "stage_projection_inversion".to_string(),
        Measurement {
            value: serde_json::Value::String("not_in_scope_round_2".to_string()),
            unit: "status".to_string(),
        },
    );
    thresholds.insert(
        "stage_projection_inversion".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::String("not_in_scope_round_2".to_string()),
            unit: "status".to_string(),
        },
    );
    pass_per_axis.insert("stage_projection_inversion".to_string(), true);

    let overall_pass = pass_per_axis.values().all(|v| *v);
    let artifact_kind = if overall_pass {
        ArtifactKind::PrimaryWitness
    } else {
        ArtifactKind::FailureReport
    };
    let fallback_tier = if overall_pass {
        FallbackTier::Primary
    } else {
        FallbackTier::Fail
    };

    let builder = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind,
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier,
        anomalies,
        notes: format!(
            "Phase 2 Terminal F' D-27 scoped mini-harness; N={N} random anchors; \
             three stages measured (lookup / audit canonicalization / admission proof). \
             Stage 4 (5-plane projection inversion) deferred — \
             AcsAnchor::project_to_plane not yet on main."
        ),
        timestamp_utc: started_utc,
    };
    let artifact = builder.build();
    write_to_disk(&artifact);
    println!("{}", serde_json::to_string_pretty(&artifact).expect("serialize"));
}

fn synth_anchor(seed: usize) -> AcsAnchor {
    let theorem = FOUNDATIONAL_THEOREMS[seed % FOUNDATIONAL_THEOREMS.len()];
    let plane = PLANES[(seed / 7) % PLANES.len()];
    let tier = TIERS[(seed / 5) % TIERS.len()];
    let salience = ((seed % 20) as f32) / 20.0;
    let mut anchor = AcsAnchor::new(
        format!("anchor-{seed:04}"),
        theorem,
        plane,
        tier,
        salience.clamp(0.0, 1.0),
    );
    if seed % 3 != 0 {
        anchor.source_hash = Some(format!("blake3:{seed:064x}"));
    }
    if seed % 4 != 0 {
        anchor.active_packet_id = Some(format!("packet-{seed:08}"));
    }
    if seed % 5 == 0 {
        anchor.compatibility_edge = Some(format!("edge-{seed:04}"));
    }
    anchor
}

fn synth_audit_record(seed: usize) -> ACSAuditRecord {
    let verdict = if seed % 2 == 0 {
        ACSAdmissionVerdict::Allow
    } else {
        ACSAdmissionVerdict::AllowWithWarning
    };
    let ops = [
        ACSOperationKind::MemoryWrite,
        ACSOperationKind::ToolAction,
        ACSOperationKind::AnswerPacket,
        ACSOperationKind::ActiveAssemblyPacket,
        ACSOperationKind::MutationEnvelope,
    ];
    let operation = ops[seed % ops.len()];
    let request_id = format!("req-{seed:04}");
    let emitted_suffix = (seed + 1) as i64;
    let record_id = format!("acs:{request_id}:{emitted_suffix}");
    ACSAuditRecord {
        record_id,
        request_id,
        policy_id: format!("policy-{}", seed % 7),
        policy_version: 1,
        operation,
        verdict,
        reason: verdict.code().to_string(),
        risk_max: 0.0,
        emitted_at_ms: emitted_suffix,
    }
}

fn mutate_signature(sig: &CapabilitySignature) -> CapabilitySignature {
    let mut bytes = sig.0.clone().into_bytes();
    if let Some(first) = bytes.first_mut() {
        *first = match *first {
            b'0' => b'1',
            b'a' => b'b',
            _ => b'0',
        };
    } else {
        bytes.push(b'0');
    }
    let mutated = String::from_utf8(bytes).unwrap_or_else(|_| "0".repeat(sig.0.len()));
    CapabilitySignature::new(mutated)
}

fn insert_count_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: usize,
    target: usize,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!({
                "matches": actual,
                "total": target,
            }),
            unit: "count".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(target as u64)),
            unit: "count".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual == target);
}

fn write_to_disk(artifact: &agent_core::falsifier_artifacts::FalsifierArtifact) {
    let out_dir = std::path::PathBuf::from("artifacts/falsifiers/acs_anchor_addressing");
    if let Err(e) = std::fs::create_dir_all(&out_dir) {
        eprintln!("warn: create_dir_all {}: {}", out_dir.display(), e);
        return;
    }
    let out_path = out_dir.join("result.json");
    let file = match std::fs::File::create(&out_path) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("warn: create {}: {}", out_path.display(), e);
            return;
        }
    };
    let mut writer = std::io::BufWriter::new(file);
    if let Err(e) = write_artifact(&mut writer, artifact) {
        eprintln!("warn: write_artifact: {}", e);
    }
}
