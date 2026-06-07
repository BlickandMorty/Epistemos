//! `falsifier_validator` — T23B Phase 2 Terminal F stub artifact validator.
//!
//! Per `docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md` §Terminal F step 4
//! ("Validate via T23B artifact schema (epistemos-shadow-validator
//! binary is still TBD per W-46 T23B block — write a stub validator if
//! needed)") and the canonical
//! `docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md`.
//!
//! Scope of this stub:
//! - Checks the 18 required top-level fields named in the schema's
//!   frontmatter table.
//! - Checks the M2 Pro `hardware_pin` constants are correct.
//! - Checks `command_digest` and `result_digest` are
//!   `sha256:<64 hex>` lowercase.
//! - Checks `falsifier_id` is one of the canonical falsifier IDs +
//!   `commit_sha` is full 40-char lowercase hex.
//! - Checks `schema_version` matches the canonical version
//!   `2026-05-18.2`.
//! - Checks `artifact_kind`, `fallback_tier`, `pass_per_axis` /
//!   `acceptance_thresholds` / `measurements` cross-reference axes.
//! - Checks `timestamp_utc` is RFC 3339 with a `Z` suffix.
//!
//! Out-of-scope (defer to the full W-46 `epistemos-shadow-validator`):
//! - The full JSON Schema draft 2020-12 `$ref` resolution.
//! - The `notes`-length cap + token allowlist + reviewer sentinel rules.
//! - The `fixture_lineage` / `provider_receipts` / `runner_environment`
//!   sub-schemas at typed-pattern strictness.
//! - The negative-example catalog
//!   (`docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md`).
//!
//! Exit codes (mirrors `epistemos_trace verify`):
//! - `0` — artifact passes the stub validator's checks.
//! - `1` — usage error (wrong args, missing path).
//! - `2` — IO error reading artifact.
//! - `3` — JSON parse error.
//! - `4` — schema-conformance violation (see stderr for which axes).

use std::path::PathBuf;

const CANONICAL_SCHEMA_VERSION: &str = "2026-05-18.2";
const CANONICAL_FALSIFIER_IDS: &[&str] = &[
    "F-Eidos-ClosedCitation",
    "F-VaultRecall-50",
    "F-PageGather-Baseline",
    "F-PageGather-Scatter",
    "F-PageGather-M2Pro",
    "F-PageGather-Packetized-Caller",
    "F-PageGather-Packetized-Policy-Acceptance",
    "F-UAS-CopyCount",
    "F-UAS-ZeroCopy-Spine",
    "F-UAS-ACS-MmapResidency",
    "F-ResidencyPlan-DryRun",
    "F-ResidencyConstructionGraph",
    "F-CoactivationTile-Prefetch",
    "F-ProofCarryingResidencyLease",
    "F-ColdAssemblyPlan-70B-Lite",
    "F-LatticeStateController",
    "F-ReasoningStateContinuity",
    "F-ColdMissLedger",
    "F-SwiftLM-SourceIntake",
    "F-MetaBreakthrough-CardRegistry",
    "F-ProofCarryingRouteCard",
    "F-RustRouteKernel-ModelCheck",
    "F-BrainRouteCard-MultiModel",
    "F-KVPageControl-QueryAware",
    "F-NeuralControlCard-Ablation",
    "F-VerifierRegretLedger",
    "F-RouteScoutSSM-Baseline",
    "F-TwoStageRouteScout-Abstain",
    "F-BudgetedUncertaintyEscalator",
    "F-SparseWakeProposal-Budget",
    "F-VerifierBudgetAuction",
    "F-KVPageSketchIndex",
    "F-KVPageBloomSketch-Coverage",
    "F-QueryAwareKVSelector",
    "F-SparseWakeCertificate-AnswerPacket",
    "F-LayerKVJointLease",
    "F-ConstructionSearchTournament",
    "F-RouteDistillationTournament",
    "F-ProofSearchSignal-RouteFeedback",
    "F-ProofPressureSignal",
    "F-VerifierRegretFastWeights",
    "F-FastWeightQuarantine",
    "F-DepthLease-Checkpoint",
    "F-ShadowWakeOracle",
    "F-AblationShadowRun",
    "F-AxiomAxiomatic-SourceDistinction",
    "F-SparseRoute-NoHiddenAuthority",
    "F-ColdStream-NoHiddenAuthority",
    "F-LargeModelProviderReference-DeferredByMlxRoute",
    "F-ProviderRoute-CopySourceGuard",
    "F-TransportTrace-AnswerPacket",
    "F-SSD-WearBudget",
    "F-ColdStream-vs-Mmap",
    "F-SlabArena-CopyCount",
    "F-MetalIO-FeatureGate",
    "F-CodecStage-Latency",
    "F-TransportCancellation",
    "F-CachePolicy-Pollution",
    "F-ColdPanicFallback",
    "F-ProductRouteReview",
    "F-SmallModelRuntimeHarnessSafetyPlan",
    "F-SmallModelRuntimeHarnessDryRunWitness",
    "F-SmallModelRuntimeHarnessOwnerApprovedProbe",
    "F-SmallModelRuntimeHarnessAbortableRuntimeProbe",
    "F-SmallModelRuntimeHarnessLoggedRuntimeSmoke",
    "F-SmallModelRuntimeHarnessFirstTokenRuntimeProbe",
    "F-SmallModelRuntimeHarnessAnswerPacketRuntimeProbe",
    "F-SmallModelRuntimeHarnessProductWrvProbe",
    "F-SmallModelRuntimeHarnessProductAnswerPacketLiveProbe",
    "F-SmallModelRuntimeHarnessProductRouteCapabilityRecheck",
    "F-SmallModelRuntimeHarnessFreshProductRuntimeSafetyLease",
    "F-SmallModelRuntimeHarnessFreshProductRuntimeLiveProbe",
    "F-SmallModelRuntimeHarnessFreshProductRuntimeAnswerPacketProbe",
    "F-SmallModelRuntimeHarnessFreshProductRuntimeWrvProbe",
    "F-SmallModelRuntimeHarnessFreshProductRuntimeCapabilityRecheck",
    "F-SmallModelRuntimeHarnessFreshProductRuntimeL3LogCorrelationProbe",
    "F-SmallModelRuntimeHarnessFreshProductRuntimeL3ManualRuntimeVerificationProbe",
    "F-SmallModelRuntimeHarnessFreshProductRuntimeL3CapabilityCloseoutProbe",
    "F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditPreflightProbe",
    "F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditZeroFailProbe",
    "F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditAutomatedChecksProbe",
    "F-AppColdStore-Layout",
    "F-SourceSignalGraph-Intake",
    "F-ModelInventory-ZeroByteCandidateCards",
    "F-ProprietaryCompression-ProvenanceGate",
    "F-CompressedModelSourceCard-Intake",
    "F-KVRuntimeSourceCard",
    "F-KVSourceCard-ForkAndDaemonBoundary",
    "F-HardwareTieredModelCatalog-SourceCard",
    "F-MoEActiveParamsMemoryTruth",
    "F-ExoticQuantQuarantineRouteCard",
    "F-ExoticQuantSourcePinAndByteBudgetPreflight",
    "F-ExoticQuantRuntimeLaneOwnerApprovalGate",
    "F-ExoticQuantLoaderCompatibilityModelPathGate",
    "F-LiteRTLM-NativeSwiftAdmission",
    "F-Gemma4-MTP-DrafterCompatibilityCard",
    "F-RuntimePlural-QATLaneTournamentPlan",
    "F-TurboVec-Eidos-CompressedIndex-Plan",
    "F-TurboVec-UASAddressStableExternalIds",
    "F-TurboVec-FilterBeforeRankPrivacyGate",
    "F-TurboVec-CrashSafePersistentIndex",
    "F-TurboVec-RecallQualityExactBaseline",
    "F-TurboVec-LatencyMemoryAbstention",
    "F-TurboVec-RuntimeShadowBenchmarkPlan",
    "F-TurboVec-QuarantineAdapterMicrobenchProbe",
    "F-TurboVec-RealAdapterOwnerApprovalProbe",
    "F-TurboVec-RealAdapterSourcePinProbe",
    "F-TurboVec-RealAdapterDependencyEnvelopeProbe",
    "F-TurboVec-RealAdapterSandboxLayoutProbe",
    "F-TurboVec-RealAdapterFetchLeaseProbe",
    "F-TurboVec-RealAdapterSourceByteManifestProbe",
    "F-TurboVec-RealAdapterSourceInspectionPolicyProbe",
    "F-TurboVec-RealAdapterMotifExtractionCardProbe",
    "F-TurboVec-RealAdapterCleanRoomAdapterPlanProbe",
    "F-TurboVec-RealAdapterExactBaselineShadowReplayProbe",
    "F-TurboVec-RealAdapterProductGraphNoContaminationProbe",
    "F-TurboVec-RealAdapterNativeLinkAbsencePreflightProbe",
    "F-TurboVec-RealAdapterOwnerApprovedNativeDryRunProbe",
    "F-GemmaQAT-LocalRuntimeCandidateCard",
    "F-QAT-ModelRouteCard-MemoryPreflight",
    "F-CompressedRoute-AnswerPacket-DryRun",
    "F-SmallCompressedModel-LiveHarnessPreflight",
    "F-SmallCompressedModel-OwnerApprovalRuntimeGate",
    "F-SmallCompressedModel-LocalRuntimeCommandCard",
    "F-SmallCompressedModel-ModelPathReadinessCard",
    "F-SmallCompressedModel-RuntimeProbeProofEnvelope",
    "F-TaskWorkingSetQuery-Determinism",
    "F-SemanticWorkingSetPlan-Budget",
    "F-ResidencyPageTable-Addressability",
    "F-MmapResidencyFence-CopyCount",
    "F-PrefetchWindow-ColdMiss",
    "F-KVByteBudgetCard",
    "F-SourceToResidency-NoPoison",
    "F-ColdFaultTrace-Learning",
    "F-WorkingSetOracle-Baseline",
    "F-ProviderReferenceManifest-DryRun",
    "F-ProviderReferencePromptLevel-Readiness",
    "F-WeightBlockRangeHash-DryRun",
    "F-ACS-AnchorLookup",
    "F-ACS-Anchor-Addressing",
    "F-InterruptScore-CPU",
    "F-PacketRouter1bit",
    "F-ControllerKernelPack",
    "F-SemiseparableBlockScan",
    "F-LocalRecallIsland",
    "F-KV-Direct-Gate",
    "F-WBO-DriftLedger",
    "F-ULP-Oracle",
    "F-70B-Local-Cocktail-Lite",
    "F-Agent-Local-Model-Runtime-Bridge",
    "F-LocalToolUse",
    "F-ShadowFirst-PageEscalation",
    "F-ActiveAssembly-Minimal",
    "F-Sparse-Runtime-Split",
    "F-Eidos-Bridge-RoundTrip",
    "F-T21-RetrievalContract-Capstone",
    "F-Eidos-NeuralRoute-Prior",
    "F-ParamRouteCard-Admission",
    "F-ResidencyPatternBoost-NoHiddenAuthority",
    "F-DynamicCompute-Checkpoint",
    "F-Capability-Ceiling-Evaluation-Kernel",
    "F-Architecture-Pending-Work-Guard",
];
const CANONICAL_ARTIFACT_KINDS: &[&str] =
    &["primary_witness", "fallback_witness", "failure_report"];
const CANONICAL_FALLBACK_TIERS: &[&str] = &["Primary", "Fallback", "Fail"];
const REQUIRED_TOP_FIELDS: &[&str] = &[
    "falsifier_id",
    "schema_version",
    "artifact_kind",
    "hardware_pin",
    "command",
    "command_digest",
    "runner_environment",
    "commit_sha",
    "fixture_id",
    "timestamp_utc",
    "result_digest",
    "measurements",
    "acceptance_thresholds",
    "pass_per_axis",
    "overall_pass",
    "fallback_tier",
    "anomalies",
    "notes",
];

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 2 {
        eprintln!(
            "usage: {} <path-to-artifact-json>\n\n\
             Validates a T23B falsifier artifact against the stub of \
             docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md \
             (18 required fields + hardware pin + canonical IDs + \
             digest format). Returns 0 on pass, 4 on conformance \
             violation.",
            args.first()
                .map(String::as_str)
                .unwrap_or("falsifier_validator")
        );
        std::process::exit(1);
    }
    let path = PathBuf::from(&args[1]);
    let bytes = match std::fs::read(&path) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("io error reading {}: {e}", path.display());
            std::process::exit(2);
        }
    };
    let value: serde_json::Value = match serde_json::from_slice(&bytes) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("json parse error in {}: {e}", path.display());
            std::process::exit(3);
        }
    };

    let mut violations: Vec<String> = Vec::new();
    let obj = match value.as_object() {
        Some(o) => o,
        None => {
            eprintln!("artifact is not a JSON object");
            std::process::exit(4);
        }
    };

    // -- Required top-level fields ---------------------------------
    for f in REQUIRED_TOP_FIELDS {
        if !obj.contains_key(*f) {
            violations.push(format!("missing required field `{f}`"));
        }
    }

    // -- falsifier_id is canonical ---------------------------------
    if let Some(id) = obj.get("falsifier_id").and_then(|v| v.as_str()) {
        if !CANONICAL_FALSIFIER_IDS.contains(&id) {
            violations.push(format!("falsifier_id `{id}` not in canonical row set"));
        }
    }

    // -- schema_version pinned -------------------------------------
    if let Some(v) = obj.get("schema_version").and_then(|v| v.as_str()) {
        if v != CANONICAL_SCHEMA_VERSION {
            violations.push(format!(
                "schema_version `{v}` != canonical `{CANONICAL_SCHEMA_VERSION}`"
            ));
        }
    }

    // -- artifact_kind canonical -----------------------------------
    if let Some(v) = obj.get("artifact_kind").and_then(|v| v.as_str()) {
        if !CANONICAL_ARTIFACT_KINDS.contains(&v) {
            violations.push(format!("artifact_kind `{v}` not in canonical set"));
        }
    }

    // -- fallback_tier canonical -----------------------------------
    if let Some(v) = obj.get("fallback_tier").and_then(|v| v.as_str()) {
        if !CANONICAL_FALLBACK_TIERS.contains(&v) {
            violations.push(format!("fallback_tier `{v}` not in canonical set"));
        }
    }

    // -- hardware_pin pinned to M2 Pro 16 GB -----------------------
    if let Some(hp) = obj.get("hardware_pin").and_then(|v| v.as_object()) {
        check_const_str(hp, "machine", "M2 Pro 14-inch 2023", &mut violations);
        check_const_str(hp, "cpu", "12-core CPU", &mut violations);
        check_const_str(hp, "gpu", "19-core GPU", &mut violations);
        check_const_num(hp, "unified_memory_gb", 16, &mut violations);
        check_const_num(hp, "memory_bandwidth_gb_s", 200, &mut violations);
    }

    // -- command_digest, result_digest = sha256:<64 hex> -----------
    for field in ["command_digest", "result_digest"] {
        if let Some(v) = obj.get(field).and_then(|v| v.as_str()) {
            if !is_sha256_lower_hex(v) {
                violations.push(format!("{field} `{v}` not `sha256:<64 lowercase hex>`"));
            }
        }
    }

    // -- commit_sha = 40-char lowercase hex (or 40 zeros placeholder) --
    if let Some(s) = obj.get("commit_sha").and_then(|v| v.as_str()) {
        if s.len() != 40
            || !s
                .chars()
                .all(|c| c.is_ascii_hexdigit() && !c.is_uppercase())
        {
            violations.push(format!("commit_sha `{s}` not 40-char lowercase hex"));
        }
    }

    // -- timestamp_utc = RFC 3339 with Z suffix --------------------
    if let Some(s) = obj.get("timestamp_utc").and_then(|v| v.as_str()) {
        if !looks_like_rfc3339_z(s) {
            violations.push(format!("timestamp_utc `{s}` not RFC 3339 UTC `Z` form"));
        }
    }

    // -- axis cross-reference: pass_per_axis ⊆ measurements ∩ thresholds --
    let m_axes = axis_set(obj.get("measurements"));
    let t_axes = axis_set(obj.get("acceptance_thresholds"));
    let p_axes = axis_set(obj.get("pass_per_axis"));
    for axis in &p_axes {
        if !m_axes.contains(axis) {
            violations.push(format!(
                "pass_per_axis axis `{axis}` missing from measurements"
            ));
        }
        if !t_axes.contains(axis) {
            violations.push(format!(
                "pass_per_axis axis `{axis}` missing from acceptance_thresholds"
            ));
        }
    }

    // -- overall_pass agrees with pass_per_axis -------------------
    if let (Some(overall), Some(pa)) = (
        obj.get("overall_pass").and_then(|v| v.as_bool()),
        obj.get("pass_per_axis").and_then(|v| v.as_object()),
    ) {
        let all_pass = pa.values().all(|v| v.as_bool().unwrap_or(false));
        if overall != all_pass {
            violations.push(format!(
                "overall_pass={overall} disagrees with pass_per_axis.all == {all_pass}"
            ));
        }
    }

    // -- anomalies is an array (may be empty) ----------------------
    if let Some(a) = obj.get("anomalies") {
        if !a.is_array() {
            violations.push("anomalies must be an array".to_string());
        }
    }

    if violations.is_empty() {
        println!("OK {}", path.display());
        std::process::exit(0);
    } else {
        eprintln!("VIOLATIONS ({}) in {}:", violations.len(), path.display());
        for v in violations {
            eprintln!("  - {v}");
        }
        std::process::exit(4);
    }
}

fn check_const_str(
    obj: &serde_json::Map<String, serde_json::Value>,
    field: &str,
    expected: &str,
    violations: &mut Vec<String>,
) {
    match obj.get(field).and_then(|v| v.as_str()) {
        Some(s) if s == expected => {}
        Some(s) => violations.push(format!(
            "hardware_pin.{field} `{s}` != canonical `{expected}`"
        )),
        None => violations.push(format!("hardware_pin missing field `{field}`")),
    }
}

fn check_const_num(
    obj: &serde_json::Map<String, serde_json::Value>,
    field: &str,
    expected: u64,
    violations: &mut Vec<String>,
) {
    match obj.get(field).and_then(|v| v.as_u64()) {
        Some(n) if n == expected => {}
        Some(n) => violations.push(format!(
            "hardware_pin.{field} = {n} != canonical {expected}"
        )),
        None => violations.push(format!("hardware_pin missing or non-numeric `{field}`")),
    }
}

fn is_sha256_lower_hex(s: &str) -> bool {
    if let Some(rest) = s.strip_prefix("sha256:") {
        rest.len() == 64
            && rest
                .chars()
                .all(|c| c.is_ascii_digit() || ('a'..='f').contains(&c))
    } else {
        false
    }
}

fn looks_like_rfc3339_z(s: &str) -> bool {
    // Minimal: YYYY-MM-DDTHH:MM:SSZ (20 chars). Allows fractional
    // seconds before Z (e.g. YYYY-MM-DDTHH:MM:SS.NNNZ).
    if !s.ends_with('Z') {
        return false;
    }
    if s.len() < 20 {
        return false;
    }
    let bytes = s.as_bytes();
    bytes[4] == b'-'
        && bytes[7] == b'-'
        && bytes[10] == b'T'
        && bytes[13] == b':'
        && bytes[16] == b':'
}

fn axis_set(v: Option<&serde_json::Value>) -> std::collections::BTreeSet<String> {
    let mut out = std::collections::BTreeSet::new();
    if let Some(serde_json::Value::Object(map)) = v {
        for key in map.keys() {
            out.insert(key.clone());
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::CANONICAL_FALSIFIER_IDS;

    #[test]
    fn canonical_route_falsifier_ids_are_accepted() {
        for id in [
            "F-Eidos-NeuralRoute-Prior",
            "F-ParamRouteCard-Admission",
            "F-ResidencyPatternBoost-NoHiddenAuthority",
            "F-DynamicCompute-Checkpoint",
        ] {
            assert!(
                CANONICAL_FALSIFIER_IDS.contains(&id),
                "{id} should be accepted by the stub validator"
            );
        }
    }
}
