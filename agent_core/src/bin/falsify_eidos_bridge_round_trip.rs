//! `falsify_eidos_bridge_round_trip` — Phase 2 Terminal F' (Round 2)
//! harness for F-Eidos-Bridge-RoundTrip.
//!
//! Drives the production-vault Eidos FFI surface in-process and emits a
//! schema-conformant artifact recording five round-trip axes:
//!
//! 1. **vault_manifest_prefix** — `eidos_open_vault_index` returns a
//!    manifest id starting with `vault-`.
//! 2. **retrieve_hits_present** — `eidos_retrieve_json` against an
//!    inserted note returns at least one hit whose `source_id` came
//!    from the manifest the packet declares.
//! 3. **closed_citation_membership** — every emitted hit's
//!    `source_id` validates through `eidos_validate_citation_json`.
//! 4. **forged_citation_rejection** — a hand-forged `source_id`
//!    (`forged::lex`) is rejected with `FabricatedSourceId`.
//! 5. **manifest_mismatch_rejection** — a citation pointing at a
//!    different manifest is rejected with `ManifestMismatch`.
//!
//! The shape mirrors `bridge::eidos_production_ffi_tests`'s
//! `round_trip_open_insert_retrieve_validate` /
//! `forged_citation_is_rejected` / `manifest_mismatch_is_rejected`
//! triplet (8/8 PASS on M2 Pro per the F-Eidos-Bridge-RoundTrip doc)
//! but persists a `primary_witness` artifact so the F-N counter on the
//! Substrate Health panel can flip without re-running `cargo test`.
//!
//! Emits to `artifacts/falsifiers/eidos_bridge_round_trip/result.json`.

use std::collections::BTreeMap;

use agent_core::bridge::{
    eidos_close_vault_index, eidos_open_vault_index, eidos_retrieve_json,
    eidos_validate_citation_json, eidos_vault_index_insert_note,
};
use agent_core::eidos::{
    EidosChunkId, EidosCitation, EidosContextPacket, EidosIndexManifestId,
};
use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-Eidos-Bridge-RoundTrip";
const FIXTURE_ID: &str = "eidos_production_ffi_in_process_v1";
const COMMAND: &str = "cargo run --release --bin falsify_eidos_bridge_round_trip";
const SIGNATURE: &str = "fprime-2026-05-24";

fn main() {
    let started_utc = now_utc_rfc3339();
    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();
    let mut anomalies: Vec<serde_json::Value> = Vec::new();

    let _ = eidos_close_vault_index();

    let manifest = match eidos_open_vault_index(SIGNATURE.to_string()) {
        Ok(m) => m,
        Err(e) => {
            return write_setup_failure(format!("eidos_open_vault_index: {e:?}"), started_utc);
        }
    };
    let manifest_prefix_ok = manifest.starts_with("vault-");
    insert_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "vault_manifest_prefix",
        manifest_prefix_ok,
        Some(serde_json::Value::String(manifest.clone())),
    );

    let notes = [
        ("note-tropical", "Tropical semirings make optimization convex.", "Note"),
        ("note-residency", "Residency governance tier compression matters.", "Note"),
        ("note-mamba", "Mamba SSM cache architecture notes for the lab.", "Note"),
        ("note-falsifier", "Falsifier handbook M2 Pro hardware floor 16 GB.", "Note"),
        ("note-acs", "ACS anchor lookup over typed anchor registry.", "Note"),
    ];
    for (id, body, kind) in notes.iter() {
        if let Err(e) = eidos_vault_index_insert_note(
            id.to_string(),
            body.to_string(),
            kind.to_string(),
        ) {
            let _ = eidos_close_vault_index();
            return write_setup_failure(
                format!("eidos_vault_index_insert_note({id}): {e:?}"),
                started_utc,
            );
        }
    }

    let packet_json = match eidos_retrieve_json("tropical".to_string(), 8) {
        Ok(s) => s,
        Err(e) => {
            let _ = eidos_close_vault_index();
            return write_setup_failure(
                format!("eidos_retrieve_json(tropical): {e:?}"),
                started_utc,
            );
        }
    };
    let packet: EidosContextPacket = match serde_json::from_str(&packet_json) {
        Ok(p) => p,
        Err(e) => {
            let _ = eidos_close_vault_index();
            return write_setup_failure(
                format!("packet decode: {e}"),
                started_utc,
            );
        }
    };

    let retrieve_hits_present = !packet.hits.is_empty()
        && packet.manifest_id.as_str().starts_with("vault-");
    insert_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "retrieve_hits_present",
        retrieve_hits_present,
        Some(serde_json::json!({
            "hit_count": packet.hits.len(),
            "manifest_id": packet.manifest_id.as_str(),
        })),
    );

    let mut all_validated = true;
    let mut validation_details: Vec<serde_json::Value> = Vec::new();
    for hit in packet.hits.iter() {
        let citation = EidosCitation {
            source_id: hit.source_id.clone(),
            manifest_id: packet.manifest_id.clone(),
        };
        let citation_json = match serde_json::to_string(&citation) {
            Ok(s) => s,
            Err(e) => {
                anomalies.push(serde_json::json!({
                    "kind": "citation_encode_failure",
                    "error": e.to_string(),
                }));
                all_validated = false;
                continue;
            }
        };
        match eidos_validate_citation_json(packet_json.clone(), citation_json) {
            Ok(s) => {
                let ok = s == "{\"Ok\":null}";
                if !ok {
                    all_validated = false;
                }
                validation_details.push(serde_json::json!({
                    "source_id": hit.source_id.as_str(),
                    "result": s,
                }));
            }
            Err(e) => {
                all_validated = false;
                validation_details.push(serde_json::json!({
                    "source_id": hit.source_id.as_str(),
                    "error": format!("{e:?}"),
                }));
            }
        }
    }
    insert_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "closed_citation_membership",
        all_validated && !packet.hits.is_empty(),
        Some(serde_json::Value::Array(validation_details)),
    );

    let forged_chunk = match EidosChunkId::new("forged::lex") {
        Ok(c) => c,
        Err(e) => {
            anomalies.push(serde_json::json!({
                "kind": "forged_chunk_id_construct_failure",
                "error": format!("{e:?}"),
            }));
            EidosChunkId::new("forged-lex").expect("fallback forged chunk id")
        }
    };
    let forged = EidosCitation {
        source_id: forged_chunk,
        manifest_id: packet.manifest_id.clone(),
    };
    let forged_json = serde_json::to_string(&forged).expect("forged json");
    let forged_result = eidos_validate_citation_json(packet_json.clone(), forged_json);
    let forged_rejected = match &forged_result {
        Ok(s) => s.contains("FabricatedSourceId"),
        Err(_) => false,
    };
    insert_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "forged_citation_rejection",
        forged_rejected,
        Some(serde_json::json!({
            "result": format!("{forged_result:?}"),
        })),
    );

    let other_manifest = match EidosIndexManifestId::new("vault-some-other") {
        Ok(m) => m,
        Err(e) => {
            anomalies.push(serde_json::json!({
                "kind": "manifest_id_construct_failure",
                "error": format!("{e:?}"),
            }));
            return finalize(
                FALSIFIER_ID,
                measurements,
                thresholds,
                pass_per_axis,
                anomalies,
                started_utc,
                "manifest-mismatch construct failure".to_string(),
            );
        }
    };
    let mismatch_citation = if let Some(first) = packet.hits.first() {
        EidosCitation {
            source_id: first.source_id.clone(),
            manifest_id: other_manifest,
        }
    } else {
        EidosCitation {
            source_id: EidosChunkId::new("filler::lex").expect("filler chunk id"),
            manifest_id: other_manifest,
        }
    };
    let mismatch_json = serde_json::to_string(&mismatch_citation).expect("mismatch json");
    let mismatch_result = eidos_validate_citation_json(packet_json.clone(), mismatch_json);
    let mismatch_rejected = match &mismatch_result {
        Ok(s) => s.contains("ManifestMismatch"),
        Err(_) => false,
    };
    insert_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "manifest_mismatch_rejection",
        mismatch_rejected,
        Some(serde_json::json!({
            "result": format!("{mismatch_result:?}"),
        })),
    );

    let _ = eidos_close_vault_index();

    finalize(
        FALSIFIER_ID,
        measurements,
        thresholds,
        pass_per_axis,
        anomalies,
        started_utc,
        format!(
            "Phase 2 Terminal F' Round 2 in-process Eidos FFI round-trip across {} inserted notes.",
            notes.len()
        ),
    );
}

fn insert_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    passed: bool,
    payload: Option<serde_json::Value>,
) {
    let value = payload.unwrap_or(serde_json::Value::Bool(passed));
    measurements.insert(
        name.to_string(),
        Measurement {
            value,
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), passed);
}

fn finalize(
    falsifier_id: &str,
    measurements: BTreeMap<String, Measurement>,
    thresholds: BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: BTreeMap<String, bool>,
    anomalies: Vec<serde_json::Value>,
    started_utc: String,
    notes: String,
) {
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
        falsifier_id: falsifier_id.to_string(),
        artifact_kind,
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier,
        anomalies,
        notes,
        timestamp_utc: started_utc,
    };
    let artifact = builder.build();
    write_to_disk(&artifact);
    println!("{}", serde_json::to_string_pretty(&artifact).expect("serialize"));
}

fn write_to_disk(artifact: &agent_core::falsifier_artifacts::FalsifierArtifact) {
    let out_dir = std::path::PathBuf::from("artifacts/falsifiers/eidos_bridge_round_trip");
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

fn write_setup_failure(reason: String, started_utc: String) {
    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();
    measurements.insert(
        "harness_setup_error".to_string(),
        Measurement {
            value: serde_json::Value::String(reason.clone()),
            unit: "error".to_string(),
        },
    );
    thresholds.insert(
        "harness_setup_error".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::String(String::new()),
            unit: "error".to_string(),
        },
    );
    pass_per_axis.insert("harness_setup_error".to_string(), false);
    let builder = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::FailureReport,
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Fail,
        anomalies: vec![serde_json::json!({
            "kind": "harness_setup_failure",
            "reason": reason,
        })],
        notes: "harness setup error; no FFI round-trip performed".to_string(),
        timestamp_utc: started_utc,
    };
    let artifact = builder.build();
    write_to_disk(&artifact);
    eprintln!("{}", reason);
}
