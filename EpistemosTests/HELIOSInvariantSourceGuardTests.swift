import Testing

/// HELIOS V5 theorem-invariant source-text guards — Stage 0 skeleton.
///
/// **Convention.** Per HELIOS V5 Canon Lock v2 §F + DOC 0 §0.7, every
/// theorem invariant landed by a W-slice MUST add a Swift source-text guard
/// here that asserts:
///
/// 1. The invariant's canonical Rust / Swift source file exists.
/// 2. That file's body contains the canonical comment marker
///    using the form: two slashes, a space, the literal token
///    "HELIOS" + dash + the theorem id (e.g. E4, H7, PCF-2),
///    a space, then "guard". Examples are intentionally NOT
///    inlined here so this skeleton file is not counted as a
///    real guard by `scripts/check-helios-invariants.sh`.
/// 3. (Optional, when the invariant is testable in MAS) the invariant
///    produces the expected output on a deterministic fixture.
///
/// **Stage 0 scope** (this skeleton): asserts DOC 0 INDEX surfaces all
/// 34 theorem ids and DOC FINALIZE specifies the E1-E7 / H1-H17 / PCF
/// mappings. Per-invariant guards land in the W-slice that introduces
/// the invariant — see DOC 0 §0.2 for the full id list.
///
/// **CI gate B5** (`scripts/check-helios-invariants.sh`) reads guard
/// counts from this directory; a slice that lands an invariant without
/// adding the corresponding guard fails B5 once thresholds are enforced
/// (currently skeleton, no minimum).
///
/// **Cross-references:**
/// - `docs/HELIOS_V5_DOC_0_INDEX.md` §0.2 (theorem status table)
/// - `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §C (E1-E7),
///   §D (H1-H17), §B (PCF-1…PCF-10)
/// - `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` §1 (WRV per slice)
@Suite("HELIOS V5 Theorem-Invariant Source Guards (Stage 0 skeleton)")
struct HELIOSInvariantSourceGuardTests {
    private static let canonicalTheoremIds: [String] = [
        // E1-E7 Epistemos Core Theorems (substrate-foundational)
        "E1", "E2", "E3", "E4", "E5", "E6", "E7",
        // H1-H17 Helios Operational Claims (build/canon claims; H1 = WBO-7)
        "H1", "H2", "H3", "H4", "H5", "H6", "H7", "H8", "H9",
        "H10", "H11", "H12", "H13", "H14", "H15", "H16", "H17",
        // PCF-1..PCF-10 Parameter Connectome Family (Goodfire VPD integration)
        "PCF-1", "PCF-2", "PCF-3", "PCF-4", "PCF-5",
        "PCF-6", "PCF-7", "PCF-8", "PCF-9", "PCF-10",
    ]

    @Test("DOC 0 INDEX surfaces all 34 theorem ids in §0.2 status table")
    func doc0SurfacesAllTheoremIds() throws {
        let source = try loadMirroredSourceTextFile("docs/HELIOS_V5_DOC_0_INDEX.md")

        for id in Self.canonicalTheoremIds {
            // Bold marker pattern: **<id>** (markdown bold inside table cell).
            #expect(
                source.contains("**\(id)**"),
                "DOC 0 INDEX must surface theorem id '\(id)' as **\(id)** in §0.2 status table"
            )
        }
    }

    @Test("DOC 0 frontmatter pins lock phrase + verified floor")
    func doc0FrontmatterPinsLockPhrase() throws {
        let source = try loadMirroredSourceTextFile("docs/HELIOS_V5_DOC_0_INDEX.md")

        #expect(source.contains("verified_floor: ac8c6d28"))
        #expect(source.contains("lock_phrase: \"Five lanes, three tiers, seven-plus-three-plus-seven, one Monday\""))
        #expect(source.contains("state: canon"))
    }

    @Test("DOC FINALIZE maps E1-E7 to substrate hooks")
    func docFinalizeMapsE1ThroughE7() throws {
        let source = try loadMirroredSourceTextFile("docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md")

        // E-tier load-bearing: each must appear in §C.
        for id in ["E1", "E2", "E3", "E4", "E5", "E6", "E7"] {
            #expect(
                source.contains("**\(id)") || source.contains("\(id) "),
                "DOC FINALIZE §C must map theorem '\(id)' to substrate"
            )
        }
    }

    @Test("DOC FINALIZE maps H1-H17 to build/canon claims (H1 = WBO-7)")
    func docFinalizeMapsH1ThroughH17() throws {
        let source = try loadMirroredSourceTextFile("docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md")

        // H1 = WBO-7 Master Inequality canonical anchor.
        #expect(source.contains("WBO-7"))
        for n in 1...17 {
            let id = "H\(n)"
            #expect(
                source.contains("**\(id)**"),
                "DOC FINALIZE §D must map operational claim '\(id)'"
            )
        }
    }

    @Test("DOC FINALIZE maps PCF-1..PCF-10 to Lane 3 / Lane 5 insertion sites")
    func docFinalizeMapsPCF() throws {
        let source = try loadMirroredSourceTextFile("docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md")

        for n in 1...10 {
            let id = "PCF-\(n)"
            #expect(
                source.contains("**\(id)**"),
                "DOC FINALIZE §B must map PCF entry '\(id)'"
            )
        }
    }

    @Test("Canon promotion protocol pins WRV state machine")
    func canonHardeningProtocolPinsWRVStateMachine() throws {
        let source = try loadMirroredSourceTextFile("docs/CANON_HARDENING_PROTOCOL_2026_05_05.md")

        // WRV ladder per §1.
        for state in ["research", "implemented", "wired", "reachable", "visible", "verified", "released"] {
            #expect(
                source.contains("**\(state)**"),
                "Canon Hardening Protocol §1 must define WRV state '\(state)'"
            )
        }

        // Canon promotion lifecycle per §2.
        for state in ["research", "candidate", "canon", "superseded", "historical", "rejected"] {
            #expect(
                source.contains("**\(state)**"),
                "Canon Hardening Protocol §2 must define lifecycle state '\(state)'"
            )
        }

        // No-date-gates rule per §3 — six valid gate types only.
        for gate in ["capability", "verification", "distribution", "entitlement", "licensing", "doctrine"] {
            #expect(
                source.contains("**\(gate)**"),
                "Canon Hardening Protocol §3 must list valid gate type '\(gate)'"
            )
        }
    }

    @Test("Preservation-First Audit Policy is canon-tagged")
    func preservationFirstAuditPolicyIsCanonTagged() throws {
        let source = try loadMirroredSourceTextFile("docs/PRESERVATION_FIRST_AUDIT_POLICY_2026_05_05.md")

        #expect(source.contains("state: canon"))
        // The three required conditions for any audit-and-delete action.
        #expect(source.contains("Proven-dead chain"))
        #expect(source.contains("Superseded-by replacement"))
        #expect(source.contains("Explicit user OR Codex sign-off"))
    }

    @Test("HELIOS V5 source-of-truth docs persisted in repo (not just iCloud)")
    func sourceOfTruthDocsPersistedInRepo() throws {
        // Per HELIOS_V5_SESSION_START_PROMPT_2026_05_05.md §2 reading order:
        // both v5 source-of-truth docs MUST live under docs/fusion/.
        _ = try loadMirroredSourceTextFile("docs/fusion/helios v5 first.md")
        _ = try loadMirroredSourceTextFile("docs/fusion/helios v5 updated.md")
    }

    // ----------------------------------------------------------------
    // Per-W-slice guards — W1 / W2 / W3 (the first three live guards)
    // ----------------------------------------------------------------

    @Test("W1: AnswerPacket Rust substrate exists with canonical guard marker")
    func w1AnswerPacketRustSubstrateExists() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/scope_rex/answer_packet.rs")
        // Canonical guard marker — read by scripts/check-helios-invariants.sh.
        #expect(source.contains("HELIOS-W1 guard"))
        // The five required field names land per `docs/fusion/helios v5 first.md` DOC 1 §1.2.
        for field in [
            "pub id: AnswerPacketId",
            "pub claims: Vec<Claim>",
            "pub residency_signals: Vec<ResidencySignal>",
            "pub ui_label: VrmLabel",
            "pub witnessed_state_ref: WitnessedStateId",
            "pub semantic_delta_ref: Option<SemanticDeltaId>",
            "pub mutation_envelope_ref: MutationEnvelopeId",
        ] {
            #expect(
                source.contains(field),
                "AnswerPacket struct must declare field: \(field)"
            )
        }
    }

    @Test("W1: scope_rex module is registered in agent_core/src/lib.rs")
    func w1ScopeRexModuleRegisteredInLib() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/lib.rs")
        #expect(source.contains("pub mod scope_rex"))
    }

    @Test("W2: ClaimKind 5-arm enum present with canonical guard marker")
    func w2ClaimKindFiveArmEnumPresent() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/provenance/ledger.rs")
        // Canonical guard marker.
        #expect(source.contains("HELIOS-W2 guard"))
        // 5-arm enum closure — exact arm names match the v5 spec.
        #expect(source.contains("pub enum ClaimKind"))
        for arm in [
            "Empirical",
            "Mathematical",
            "CodeInvariant",
            "Causal",
            "Speculative",
        ] {
            #expect(
                source.contains(arm),
                "ClaimKind enum must declare arm: \(arm)"
            )
        }
        // Backward-compat invariant: `kind` field is `serde(default)`
        // so v1 archives without `kind` deserialize cleanly.
        #expect(source.contains("#[serde(default)]"))
    }

    @Test("W2: Swift mirror in AnswerPacket.swift carries the same 5 arms")
    func w2SwiftMirrorMatchesRustClaimKind() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Models/AnswerPacket.swift")
        #expect(source.contains("HELIOS-W2 guard"))
        #expect(source.contains("public enum ClaimKind"))
        for arm in [
            "case empirical",
            "case mathematical",
            "case codeInvariant = \"code_invariant\"",
            "case causal",
            "case speculative",
        ] {
            #expect(
                source.contains(arm),
                "Swift ClaimKind mirror must declare: \(arm)"
            )
        }
    }

    @Test("W3: VRMLabelView Swift surface exists with canonical guard marker")
    func w3VRMLabelViewSwiftSurfaceExists() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/VRMLabelView.swift")
        #expect(source.contains("HELIOS-W3 guard"))
        // The view must surface all four labels per `docs/HELIOS_V5_DOC_0_INDEX.md` §0.6.
        #expect(source.contains("public struct VRMLabelView"))
        for caseName in [".verified", ".plausibleButUnverified", ".speculative", ".blocked"] {
            #expect(
                source.contains(caseName),
                "VRMLabelView must handle case: \(caseName)"
            )
        }
    }

    @Test("W3: VRMLabel default never silently promotes unverified to verified")
    func w3VRMLabelDefaultIsSafeOption() throws {
        // Critical safety invariant — the missing-field decode must
        // not produce `.verified`. Anti-drift: locked at the Swift
        // mirror + Rust source levels.
        let swiftSource = try loadMirroredSourceTextFile("Epistemos/Models/AnswerPacket.swift")
        #expect(swiftSource.contains("public static let `default`: VRMLabel = .plausibleButUnverified"))

        let rustSource = try loadMirroredSourceTextFile("agent_core/src/scope_rex/answer_packet.rs")
        #expect(rustSource.contains("Self::PlausibleButUnverified"))
    }

    @Test("W4: Residency Governor pure function exists with all 9 arms")
    func w4ResidencyGovernorExists() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/scope_rex/residency.rs")
        // Canonical guard marker.
        #expect(source.contains("HELIOS-W4 guard"))
        // 9-variant taxonomy must be exhaustive — locked at the source.
        #expect(source.contains("pub enum Residency"))
        for arm in [
            "TransientContext",
            "RetrievalMemory",
            "FeatureRule",
            "HarnessRule",
            "GrpoPrior",
            "PsoftAdapter",
            "OsftCore",
            "CloudDistilled",
            "Quarantine",
        ] {
            #expect(
                source.contains(arm),
                "Residency enum must declare arm: \(arm)"
            )
        }
        // The route function must be declared.
        #expect(source.contains("pub fn route(signal: &ResidencySignal) -> Residency"))
        // Threshold ordering must be locked: Quarantine wins over
        // TransientContext wins over FeatureRule.
        #expect(source.contains("safety_risk > 0.7"))
        #expect(source.contains("privacy > 0.9"))
        #expect(source.contains("verification_score < 0.5"))
        #expect(source.contains("repeat_count < 3"))
    }

    @Test("W6: Active-Support Atlas indexing (Tier-1 ULP-equivalent matmul)")
    func w6ActiveSupportAtlasExists() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/scope_rex/metal/asa_index.rs")
        #expect(source.contains("HELIOS-W6 guard"))
        // Public API surface: AsaIndex + dense_matmul + asa_matmul.
        #expect(source.contains("pub struct AsaIndex"))
        #expect(source.contains("pub fn dense_matmul"))
        #expect(source.contains("pub fn asa_matmul"))
        // H3 monotonicity invariants are codified.
        #expect(source.contains("pub fn merge"))
        #expect(source.contains("pub fn split"))
        #expect(source.contains("monotone non-decreasing"))
        #expect(source.contains("monotone non-increasing"))
        // Tier-1 ULP-equivalence claim is at the source level.
        #expect(source.contains("ULP-equivalent"))
        #expect(source.contains("Conservative-mask invariant"))
    }

    @Test("W7: Half-softmax post-not-pre rewrite (Tier-1 ≤ 2 ULP)")
    func w7HalfSoftmaxPostExists() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/scope_rex/metal/softmax.rs")
        #expect(source.contains("HELIOS-W7 guard"))
        #expect(source.contains("pub fn reference_softmax"))
        #expect(source.contains("pub fn half_softmax_post"))
        // The numerical-stability rewrite is documented at source.
        #expect(source.contains("max-subtraction"))
        #expect(source.contains("Babai lattice closure"))
        // ≤ 2 ULP acceptance is documented.
        #expect(source.contains("\u{2264} 2 ULP"))
    }

    @Test("Stage 21: SCOPE-Rex Omega state-witness + ontology + observatory substrate exists")
    func stage21WitnessedStateOntologyObservatoryExist() throws {
        // WitnessedState — 8-tuple state representation per scope_rex_omega.md
        let witnessed = try loadMirroredSourceTextFile("agent_core/src/scope_rex/witnessed_state.rs")
        #expect(witnessed.contains("HELIOS-WITNESSED-STATE guard"))
        #expect(witnessed.contains("pub struct StateRoot"))
        #expect(witnessed.contains("pub struct WitnessedState"))
        #expect(witnessed.contains("pub struct SemanticDeltaEvent"))
        // 8-tuple notation present.
        #expect(witnessed.contains("S_t = (h_t, z_t, g_t, p_t, m_t, w_t"))
        // Genesis / op_count contracts present.
        #expect(witnessed.contains("pub fn genesis"))
        #expect(witnessed.contains("pub fn op_count"))

        // OntologyValidator — V(a) ontology-violation cost surface
        let ontology = try loadMirroredSourceTextFile("agent_core/src/scope_rex/ontology.rs")
        #expect(ontology.contains("HELIOS-ONTOLOGY guard"))
        #expect(ontology.contains("pub trait OntologyValidator"))
        #expect(ontology.contains("pub struct VerificationReport"))
        #expect(ontology.contains("pub enum OntologyViolationSeverity"))
        // 4-arm severity taxonomy aligned with H1-H17 invariants.
        #expect(ontology.contains("Warn"))
        #expect(ontology.contains("Degrade"))
        #expect(ontology.contains("Quarantine"))
        #expect(ontology.contains("Halt"))
        #expect(ontology.contains("pub struct NoOpOntologyValidator"))

        // FeatureObservatory — F(a) feature-target match (Qwen-Scope SAE inspection)
        let observatory = try loadMirroredSourceTextFile("agent_core/src/scope_rex/feature_observatory.rs")
        #expect(observatory.contains("HELIOS-OBSERVATORY guard"))
        #expect(observatory.contains("pub trait FeatureObservatory"))
        #expect(observatory.contains("pub struct FeatureSignal"))
        #expect(observatory.contains("pub struct FeatureEdit"))
        #expect(observatory.contains("pub enum SteeringMode"))
        // 4-arm steering mode taxonomy.
        #expect(observatory.contains("ReadOnly"))
        #expect(observatory.contains("Amplify"))
        #expect(observatory.contains("Suppress"))
        #expect(observatory.contains("Steer"))
        #expect(observatory.contains("pub struct NoOpFeatureObservatory"))

        // mod.rs registers all three new submodules
        let mod = try loadMirroredSourceTextFile("agent_core/src/scope_rex/mod.rs")
        #expect(mod.contains("pub mod witnessed_state"))
        #expect(mod.contains("pub mod ontology"))
        #expect(mod.contains("pub mod feature_observatory"))
    }

    @Test("Stage 20: W12/W13/W14 Tier-2 Metal Shading Language kernels exist")
    func stage20Tier2MetalKernelsExist() throws {
        let tmac = try loadMirroredSourceTextFile("Epistemos/Shaders/tmac_lut.metal")
        #expect(tmac.contains("HELIOS-W12-METAL guard"))
        #expect(tmac.contains("kernel void tmacTernaryGemm"))
        #expect(tmac.contains("kernel void validateTernaryWeights"))
        // Wei et al. citation present.
        #expect(tmac.contains("2407.00088"))

        let bitnet = try loadMirroredSourceTextFile("Epistemos/Shaders/bitnet_b158.metal")
        #expect(bitnet.contains("HELIOS-W13-METAL guard"))
        #expect(bitnet.contains("kernel void bitnetAbsmeanQuantize"))
        #expect(bitnet.contains("kernel void bitnetB158Gemm"))
        // Ma et al. + Microsoft 2B4T citations.
        #expect(bitnet.contains("2402.17764"))
        #expect(bitnet.contains("2504.12285"))

        let stg = try loadMirroredSourceTextFile("Epistemos/Shaders/sparse_ternary_gemm.metal")
        #expect(stg.contains("HELIOS-W14-METAL guard"))
        #expect(stg.contains("kernel void sparseTernaryGemm"))
        #expect(stg.contains("kernel void sparseTernaryFootprint"))
        #expect(stg.contains("BIT-IDENTICAL"))
        // Lipshitz et al. citation.
        #expect(stg.contains("2510.06957"))
    }

    @Test("Stage 19: PCF-1..PCF-10 Lean stubs enriched with VPD acceptance criteria")
    func stage19PcfLeanStubsEnriched() throws {
        let pcf1 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/PCF-1.lean")
        #expect(pcf1.contains("VpdExtraction"))
        #expect(pcf1.contains("reconstruction_mse"))
        #expect(pcf1.contains("2506.20790"))

        let pcf2 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/PCF-2.lean")
        #expect(pcf2.contains("QkEdgeAnchor"))
        #expect(pcf2.contains("Frobenius"))

        let pcf3 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/PCF-3.lean")
        #expect(pcf3.contains("AttributionEdge"))

        let pcf4 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/PCF-4.lean")
        #expect(pcf4.contains("DEFERRED"))

        let pcf5 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/PCF-5.lean")
        #expect(pcf5.contains("ActiveSubcomponent"))
        #expect(pcf5.contains("Vault only"))

        let pcf6 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/PCF-6.lean")
        #expect(pcf6.contains("driftUpperBound"))

        let pcf7 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/PCF-7.lean")
        #expect(pcf7.contains("DualConnectomeTrace"))

        let pcf8 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/PCF-8.lean")
        #expect(pcf8.contains("ConnectomeSheaf"))
        #expect(pcf8.contains("2202.04579"))

        let pcf9 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/PCF-9.lean")
        #expect(pcf9.contains("output_model_sha256"))
        #expect(pcf9.contains("passesAcceptance"))

        let pcf10 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/PCF-10.lean")
        #expect(pcf10.contains("InterpretabilityTransfer"))
        #expect(pcf10.contains("acceptanceMet"))
    }

    @Test("Stage 18: H8-H17 Lean stubs enriched with cross-tradition citations")
    func stage18H8ThroughH17LeanStubsEnriched() throws {
        let h8 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H8.lean")
        for op in ["bind", "unbind", "gate", "route", "commit", "reorder", "merge", "split", "quarantine"] {
            #expect(h8.contains("| \(op)"), "H8 must declare OSPC op: \(op)")
        }

        let h9 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H9.lean")
        #expect(h9.contains("transformer"))
        #expect(h9.contains("parn"))
        #expect(h9.contains("ternaryMorph"))
        #expect(h9.contains("Buzs\u{00E1}ki"))

        let h10 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H10.lean")
        #expect(h10.contains("masBuild"))
        #expect(h10.contains("lane4Oracle"))
        #expect(h10.contains("mutexHolds"))

        let h11 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H11.lean")
        #expect(h11.contains("2202.04579"))
        #expect(h11.contains("NOT 2206.04386"))

        let h12 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H12.lean")
        #expect(h12.contains("Berry"))
        #expect(h12.contains("BerryPhase"))

        let h13 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H13.lean")
        #expect(h13.contains("klBridgeFactor"))
        #expect(h13.contains("FisherInformation"))

        let h14 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H14.lean")
        #expect(h14.contains("localGlobalConjectureIsFalse"))
        #expect(h14.contains("2307.02749"))
        #expect(h14.contains("H14_NEGATIVE_RESULT_ACKNOWLEDGED"))

        let h15 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H15.lean")
        #expect(h15.contains("MadhavaSeries"))
        #expect(h15.contains("2405.11134"))

        let h16 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H16.lean")
        #expect(h16.contains("CrtRoute"))
        #expect(h16.contains("Chinese Remainder"))

        let h17 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H17.lean")
        #expect(h17.contains("HopfieldStore"))
        #expect(h17.contains("capacityBound"))
        #expect(h17.contains("2008.02217"))
    }

    @Test("Stage 17: H1-H7 Lean stubs enriched with operational claim content")
    func stage17H1ThroughH7LeanStubsEnriched() throws {
        let h1 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H1.lean")
        #expect(h1.contains("active-support penalty"))
        #expect(h1.contains("WBO-6"))
        #expect(h1.contains("structure SamplerTrajectory"))

        let h2 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H2.lean")
        #expect(h2.contains("softmaxLipschitzConstant"))
        #expect(h2.contains("babaiClosurePreserved"))

        let h3 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H3.lean")
        #expect(h3.contains("merge_non_decreasing"))
        #expect(h3.contains("split_non_increasing"))
        #expect(h3.contains("merge_idempotent"))
        #expect(h3.contains("split_idempotent"))

        let h4 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H4.lean")
        #expect(h4.contains("structure BabaiBound"))
        #expect(h4.contains("ldl_trace"))
        #expect(h4.contains("layerWiseErrorBoundTight"))

        let h5 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H5.lean")
        #expect(h5.contains("structure MorphTrace"))
        #expect(h5.contains("trace_hash"))

        let h6 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H6.lean")
        #expect(h6.contains("linearAttention"))
        #expect(h6.contains("stateSpaceModel"))
        #expect(h6.contains("fastWeightProgrammer"))
        #expect(h6.contains("onlineLearner"))
        #expect(h6.contains("softmaxAttention"))

        let h7 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H7.lean")
        #expect(h7.contains("inductive MemoryTier"))
        #expect(h7.contains("l0Register"))
        #expect(h7.contains("lSe"))
        #expect(h7.contains("MemoryTier.ord"))
    }

    @Test("Stage 16: E4/E5/E6/E7 Lean stubs enriched with v2.0-hardened formal statements")
    func stage16E4ThroughE7LeanStubsEnriched() throws {
        let e4 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/E4.lean")
        // E4 v2.0 dual-inequality form (pre-softmax additive + post-softmax half-contraction).
        #expect(e4.contains("preSoftmaxAdditiveBound"))
        #expect(e4.contains("postSoftmaxHalfContraction"))
        #expect(e4.contains("tsErrorTermSeparation"))
        // Acknowledge v1 conflation correction.
        #expect(e4.contains("v1 fused inequality conflated"))

        let e5 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/E5.lean")
        // E5 hard-branch + soft-branch architecture.
        #expect(e5.contains("HARD branch"))
        #expect(e5.contains("SOFT branch"))
        #expect(e5.contains("fusedErrorBound"))
        // Mamba-3 separation (audit Patch 6).
        #expect(e5.contains("mamba3IsSidecarNotTheorem"))

        let e6 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/E6.lean")
        // E6 5 specific source formalisms (NOT generic).
        #expect(e6.contains("paraLens"))
        #expect(e6.contains("eml"))
        #expect(e6.contains("atlas"))
        #expect(e6.contains("nestedLearningCmsX"))
        #expect(e6.contains("stoneWeierstrass"))
        // Anti-overclaim guard (audit Patch 7).
        #expect(e6.contains("isNotSameInfinityClaim"))

        let e7 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/E7.lean")
        // E7 strong form C distinction + dependency direction lock.
        #expect(e7.contains("strongFormIsConjecture"))
        #expect(e7.contains("t7SitsOnTopOfT1ThroughT6"))
        // F7e falsifier reference.
        #expect(e7.contains("F7e"))
    }

    @Test("Stage 15: E1/E2/E3 Lean stubs enriched with v2.0-hardened formal statements")
    func stage15E1E2E3LeanStubsEnriched() throws {
        let e1 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/E1.lean")
        // E1 v2.0 hardened content: AnnularSector + AMorphGenerator + fullGeneratorList.
        #expect(e1.contains("structure AnnularSector"))
        #expect(e1.contains("inductive AMorphGenerator"))
        #expect(e1.contains("fullGeneratorList"))
        // The v2.0 P-scope distinction (full generators only).
        #expect(e1.contains("density_with_full_generators"))
        // EML-alone density is C (open) — must be documented.
        #expect(e1.contains("EML-alone density"))

        let e2 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/E2.lean")
        // E2 v2.0 hardened: PatchGraph + Stalk + CellularSheaf structures.
        #expect(e2.contains("structure PatchGraph"))
        #expect(e2.contains("structure Stalk"))
        #expect(e2.contains("structure CellularSheaf"))
        // Bound constants per v2.0 §T2.
        #expect(e2.contains("maxPatchNodes"))
        #expect(e2.contains("maxPatchEdges"))
        #expect(e2.contains("maxStalkDim"))

        let e3 = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/E3.lean")
        // E3 v2.0 hardened: split into telescoping (P) + memory corollary (EB).
        #expect(e3.contains("Telescoping bound (P)"))
        #expect(e3.contains("Memory corollary (EB)"))
        #expect(e3.contains("structure LayerLipschitz"))
        #expect(e3.contains("cumulativeErrorBound"))
    }

    @Test("Stage 14: falsifier.sh registry has 4-column per-crate dispatch + 21 entries")
    func stage14FalsifierRegistryDispatchesAcrossCrates() throws {
        let source = try loadMirroredSourceTextFile("Tools/falsifier/falsifier.sh")
        // 4-column registry header.
        #expect(source.contains("id|crate|features|cargo_test_filter"))
        // PCF entries dispatch to research / vault crates.
        #expect(source.contains("PCF-1|epistemos-research|research|vpd::extract"))
        #expect(source.contains("PCF-5|epistemos-vault|vault|runtime::active_rank_one"))
        #expect(source.contains("PCF-9|epistemos-vault|vault|distill::connectome"))
        // Original agent_core entries preserved.
        #expect(source.contains("E3|agent_core|default|storage::vault"))
        #expect(source.contains("H17|agent_core|default|scope_rex::retrieval::hopfield"))
        #expect(source.contains("W14|agent_core|default|scope_rex::kernels::sparse_ternary_gemm"))
        // run_one cd's into the registered crate (not hardcoded agent_core).
        #expect(source.contains("cd \"${REPO_ROOT}/${crate}\""))
        // feature flag wiring.
        #expect(source.contains("feature_arg=\"--features ${features}\""))
    }

    @Test("Stage 13: W25 PCF-1..PCF-10 falsifier YAML protocols exist")
    func stage13PcfFalsifierProtocolsExist() throws {
        for n in 1...10 {
            let path = "Tools/falsifier/protocols/PCF-\(n).yaml"
            let yaml = try loadMirroredSourceTextFile(path)
            #expect(yaml.contains("id: PCF-\(n)"))
            #expect(yaml.contains("class: candidate"))
            #expect(yaml.contains("state: candidate"))
            #expect(yaml.contains("acceptance:"))
            #expect(yaml.contains("stage_0_proxy:"))
            #expect(yaml.contains("insertion_site:"))
        }
    }

    @Test("Stage 12: W6/W7/W8 Metal Shading Language kernels exist")
    func stage12W6W7W8MetalKernelsExist() throws {
        let asa = try loadMirroredSourceTextFile("Epistemos/Shaders/active_support_atlas.metal")
        #expect(asa.contains("HELIOS-W6-METAL guard"))
        #expect(asa.contains("kernel void asaMaskedMatmul"))
        #expect(asa.contains("BIT-IDENTICAL"))

        let softmax = try loadMirroredSourceTextFile("Epistemos/Shaders/half_softmax_post.metal")
        #expect(softmax.contains("HELIOS-W7-METAL guard"))
        #expect(softmax.contains("kernel void halfSoftmaxPost"))
        #expect(softmax.contains("\u{2264} 2 ULP"))
        #expect(softmax.contains("max-subtraction"))

        let kv = try loadMirroredSourceTextFile("Epistemos/Shaders/kv_direct_gate.metal")
        #expect(kv.contains("HELIOS-W8-METAL guard"))
        #expect(kv.contains("kernel void kvDirectQkRow"))
        #expect(kv.contains("BIT-IDENTICAL"))
    }

    @Test("Stage 10: ci.yml exercises epistemos-research + epistemos-vault crates")
    func stage10CiYamlExercisesNewCrates() throws {
        let source = try loadMirroredSourceTextFile(".github/workflows/ci.yml")
        // Both crates listed in rust-cache workspaces.
        #expect(source.contains("epistemos-research -> target"))
        #expect(source.contains("epistemos-vault -> target"))
        // Build + test steps wired with feature flags.
        #expect(source.contains("Build epistemos-research (Lane 3 research feature)"))
        #expect(source.contains("Test epistemos-research (Lane 3 research feature)"))
        #expect(source.contains("Build epistemos-vault (Lane 5 vault feature)"))
        #expect(source.contains("Test epistemos-vault (Lane 5 vault feature)"))
        // Clippy steps pinned with explicit feature flags.
        #expect(source.contains("Clippy epistemos-research (research feature)"))
        #expect(source.contains("Clippy epistemos-vault (vault feature)"))
        // rustfmt step extended to include the new crates.
        #expect(source.contains("for crate in graph-engine epistemos-core omega-ax omega-mcp agent_core epistemos-research epistemos-vault"))
        // Pro+Research compose surface explicitly tested.
        #expect(source.contains("Test agent_core (Pro + Research compose surface)"))
        #expect(source.contains("--features pro-build,research"))
    }

    @Test("Stage 8 / W24: Lean repo skeleton exists with mathlib4 pin")
    func stage8LeanRepoSkeletonExists() throws {
        let lakefile = try loadMirroredSourceTextFile("lean/Epistemos/lakefile.lean")
        #expect(lakefile.contains("package «epistemos»"))
        #expect(lakefile.contains("require mathlib"))
        #expect(lakefile.contains("v4.16.0"))   // tagged release pin per Q4

        let toolchain = try loadMirroredSourceTextFile("lean/Epistemos/lean-toolchain")
        #expect(toolchain.contains("leanprover/lean4:v4.16.0"))

        let entry = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos.lean")
        for n in 1...7 {
            #expect(
                entry.contains("import Epistemos.E\(n)"),
                "Epistemos.lean must import E\(n)"
            )
        }
    }

    @Test("Stage 8 / W24: every E1-E7 stub carries HELIOS-E<n> guard")
    func stage8E1ThroughE7LeanStubsExist() throws {
        for n in 1...7 {
            let path = "lean/Epistemos/Epistemos/E\(n).lean"
            let source = try loadMirroredSourceTextFile(path)
            #expect(
                source.contains("HELIOS-E\(n) guard"),
                "\(path) missing canonical HELIOS-E\(n) guard"
            )
            #expect(source.contains("namespace Epistemos.E\(n)"))
            #expect(source.contains("end Epistemos.E\(n)"))
        }
    }

    @Test("Stage 9 / W24: H1-H17 Lean stubs exist with HELIOS-H<n> guards")
    func stage9H1ThroughH17LeanStubsExist() throws {
        for n in 1...17 {
            let path = "lean/Epistemos/Epistemos/H\(n).lean"
            let source = try loadMirroredSourceTextFile(path)
            #expect(
                source.contains("HELIOS-H\(n) guard"),
                "\(path) missing canonical HELIOS-H\(n) guard"
            )
            #expect(source.contains("namespace Epistemos.H\(n)"))
        }
    }

    @Test("Stage 9 / W24: PCF-1..PCF-10 Lean stubs exist with HELIOS-PCF-<n> guards")
    func stage9PcfLeanStubsExist() throws {
        for n in 1...10 {
            let path = "lean/Epistemos/Epistemos/PCF-\(n).lean"
            let source = try loadMirroredSourceTextFile(path)
            #expect(
                source.contains("HELIOS-PCF-\(n) guard"),
                "\(path) missing canonical HELIOS-PCF-\(n) guard"
            )
            // Namespace uses `PCFn` (no hyphen) since Lean rejects
            // hyphens in identifiers.
            #expect(source.contains("namespace Epistemos.PCF\(n)"))
        }
    }

    @Test("Stage 9 / W24: aggregate sorry count matches per DOC 6")
    func stage9AggregateSorryCountMatchesDOC6() throws {
        // Per DOC 6 §1+§2+§3 budgets:
        //   E1-E7 stubs: 8 sorries (E1=1, E2=1, E3=0, E4=2, E5=2, E6=1, E7=1)
        //   H1-H17 stubs: 17 sorries (1 each)
        //   PCF-1..10 stubs: 10 sorries (1 each)
        // Total: 35.
        var total = 0
        for n in 1...7 {
            let s = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/E\(n).lean")
            total += countSorries(in: s)
        }
        for n in 1...17 {
            let s = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/H\(n).lean")
            total += countSorries(in: s)
        }
        for n in 1...10 {
            let s = try loadMirroredSourceTextFile("lean/Epistemos/Epistemos/PCF-\(n).lean")
            total += countSorries(in: s)
        }
        #expect(total == 35, "aggregate sorry count = \(total), expected 35 per DOC 6")
    }

    private func countSorries(in source: String) -> Int {
        // Match the awk pattern in Tools/sorry-budget/sorry-budget.sh:
        //   ^[[:space:]]*sorry[[:space:]]*(--.*)?$
        var count = 0
        for line in source.split(whereSeparator: { $0.isNewline }) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "sorry" || trimmed.hasPrefix("sorry --") {
                count += 1
            }
        }
        return count
    }

    @Test("Stage 8 / W24: ci.yml runs sorry-budget tracker as a CI step")
    func stage8SorryBudgetCiStepExists() throws {
        let source = try loadMirroredSourceTextFile(".github/workflows/ci.yml")
        #expect(source.contains("./Tools/sorry-budget/sorry-budget.sh"))
        #expect(source.contains("W24 — Lean sorry-budget tracker"))
    }

    @Test("Stage 8 / W24: sorry-budget tracker uses awk + DOC-6-aligned budgets")
    func stage8SorryBudgetUsesAwkAndAlignedBudgets() throws {
        let source = try loadMirroredSourceTextFile("Tools/sorry-budget/sorry-budget.sh")
        #expect(source.contains("awk '/^[[:space:]]*sorry"))
        // DOC 6 alignment: E3 + E6 are ≤ 1 (not ≤ 2 like the others).
        #expect(source.contains("E3|1"))
        #expect(source.contains("E6|1"))
        #expect(source.contains("E1|2"))
        #expect(source.contains("E7|2"))
    }

    @Test("Stage 7 / W25: M2 Max protocol YAML files exist for every registered id")
    func stage7W25ProtocolYamlsExist() throws {
        // Every registered cargo_test_filter id from falsifier.sh
        // has a corresponding YAML protocol manifest.
        for id in [
            "E3", "H2", "H3", "H7", "H17",
            "W1", "W5", "W8", "W12", "W13", "W14",
        ] {
            let yaml = try loadMirroredSourceTextFile("Tools/falsifier/protocols/\(id).yaml")
            #expect(
                yaml.contains("id: \(id)"),
                "Tools/falsifier/protocols/\(id).yaml must declare 'id: \(id)'"
            )
            // Each protocol must declare acceptance + insertion_site keys
            // (the load-bearing schema fields).
            #expect(yaml.contains("acceptance:"))
            #expect(yaml.contains("insertion_site:"))
            #expect(yaml.contains("stage_0_proxy:"))
        }
    }

    @Test("Stage 7 / W25: protocols/README.md catalogs all protocols")
    func stage7W25ProtocolsReadmeExists() throws {
        let source = try loadMirroredSourceTextFile("Tools/falsifier/protocols/README.md")
        #expect(source.contains("state: canon"))
        #expect(source.contains("Currently authored protocols"))
        // Every protocol id appears in the catalog table.
        for id in ["E3", "E4", "H2", "H3", "H7", "H17", "W6", "W8"] {
            #expect(source.contains("`\(id).yaml`"), "README must list \(id).yaml")
        }
    }

    @Test("Stage 7 / W25: falsifier.sh has --protocols mode")
    func stage7W25ProtocolsMode() throws {
        let source = try loadMirroredSourceTextFile("Tools/falsifier/falsifier.sh")
        #expect(source.contains("--protocols)"))
        #expect(source.contains("yaml_protocol"))
        // Cross-references registered ids vs YAML files.
        #expect(source.contains("orphan"))
    }

    @Test("Stage 6 / W3.b: MessageBubble wires VRMLabelView under VRM toggle")
    func stage6MessageBubbleWiresVrmLabel() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/MessageBubble.swift")
        #expect(source.contains("HELIOS-W3b guard"))
        // The toggle key matches the W9 AppStorage key — same source of truth.
        #expect(source.contains("@AppStorage(\"epistemos.helios.v5.verifiedResearchMode\")"))
        // Critical safety invariant: the placeholder label is never .verified.
        #expect(source.contains("VRMLabelView(.plausibleButUnverified, compact: true)"))
        #expect(!source.contains("VRMLabelView(.verified"))
    }

    @Test("Stage 6 / W5.b: BTMView Swift surface exists, never tensor")
    func stage6BTMViewExists() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/BTMView.swift")
        #expect(source.contains("HELIOS-W5b guard"))
        #expect(source.contains("public struct BTMView"))
        #expect(source.contains("public struct SemanticDeltaView"))
        // The W5 contract — semantic only, never tensors — is locked
        // at the Swift mirror level too.
        #expect(source.contains("Semantic only — never tensors"))
        // CodingKeys mirror the Rust wire format snake_case.
        #expect(source.contains("case addedClaims = \"added_claims\""))
        #expect(source.contains("case modifiedClaims = \"modified_claims\""))
        #expect(source.contains("case removedClaimIds = \"removed_claim_ids\""))
    }

    @Test("Stage 6 / W9-W11.b: HELIOS V5 wired into main SettingsView")
    func stage6HeliosV5WiredInSettingsView() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        // New SettingsSection enum case.
        #expect(source.contains("case heliosV5 = \"HELIOS V5\""))
        // Routed to the HELIOSv5SettingsView in the detail builder.
        #expect(source.contains("case .heliosV5: HELIOSv5SettingsView()"))
        // Listed in visibleSections so it appears in the sidebar.
        #expect(source.contains(".heliosV5,"))
    }

    @Test("Stage 6 / Σ: Pro + Research compose functions exist")
    func stage6SigmaComposeFunctionsExist() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/resonance/mod.rs")
        #expect(source.contains("pub fn compute_signature_pro"))
        #expect(source.contains("pub fn compute_signature_research"))
        #expect(source.contains("pub fn compute_signature_full"))
        #expect(source.contains("pub struct ResonanceSignaturePro"))
        #expect(source.contains("pub struct ResonanceSignatureResearch"))
        #expect(source.contains("pub struct ResonanceSignatureFull"))
        // Full Σ is gated on BOTH features per the v2 plan.
        #expect(source.contains("#[cfg(all(feature = \"pro-build\", feature = \"research\"))]"))
    }

    @Test("Stage 5 / DOC 6: master Theorem Canon doc exists with all 34 ids")
    func stage5Doc6TheoremCanonExists() throws {
        let source = try loadMirroredSourceTextFile("docs/HELIOS_V5_DOC_6_THEOREM_CANON.md")
        // §1 + §2 + §3 each present.
        #expect(source.contains("## §1 — Foundational Seven (E1–E7)"))
        #expect(source.contains("## §2 — Helios Operational Claims (H1–H17)"))
        #expect(source.contains("## §3 — Parameter Connectome Family (PCF-1..PCF-10)"))
        // Status table consolidation.
        #expect(source.contains("## §4 — Status table consolidation"))
        // Every theorem id surfaced as a canonical heading (### E<n> ...
        // ### H<n> ... ### PCF-<n> ...).
        for id in [
            "### E1", "### E2", "### E3", "### E4", "### E5", "### E6", "### E7",
            "### H1", "### H2", "### H3", "### H4", "### H5", "### H6",
            "### H7", "### H8", "### H9", "### H10", "### H11", "### H12",
            "### H13", "### H14", "### H15", "### H16", "### H17",
            "### PCF-1", "### PCF-2", "### PCF-3", "### PCF-4", "### PCF-5",
            "### PCF-6", "### PCF-7", "### PCF-8", "### PCF-9", "### PCF-10",
        ] {
            #expect(
                source.contains(id),
                "DOC 6 must surface theorem heading '\(id)'"
            )
        }
        // Verified Floor + lock phrase pinned in frontmatter.
        #expect(source.contains("verified_floor: ac8c6d28"))
    }

    @Test("DOC 0 anchor table includes DOC 6 row")
    func doc0IncludesDoc6AnchorRow() throws {
        let source = try loadMirroredSourceTextFile("docs/HELIOS_V5_DOC_0_INDEX.md")
        #expect(source.contains("docs/HELIOS_V5_DOC_6_THEOREM_CANON.md"))
        #expect(source.contains("20ae3421bf274c8bdbc191390fc520124655b20e4a22e757b4a74e82d75b296e"))
    }

    @Test("Stage 4: epistemos-vault crate exists with vault feature gate")
    func stage4VaultCrateExists() throws {
        let cargo = try loadMirroredSourceTextFile("epistemos-vault/Cargo.toml")
        #expect(cargo.contains("name = \"epistemos-vault\""))
        #expect(cargo.contains("vault = []"))
        let lib = try loadMirroredSourceTextFile("epistemos-vault/src/lib.rs")
        #expect(lib.contains("#[cfg(feature = \"vault\")]"))
        #expect(lib.contains("pub mod surgery"))
        #expect(lib.contains("pub mod runtime"))
        #expect(lib.contains("pub mod cache"))
        #expect(lib.contains("pub mod distill"))
    }

    @Test("W20: ModelSurgeryEnvelope substrate exists with safety bound")
    func w20ModelSurgeryEnvelopeExists() throws {
        let source = try loadMirroredSourceTextFile("epistemos-vault/src/surgery/envelope.rs")
        #expect(source.contains("HELIOS-W20 guard"))
        #expect(source.contains("pub struct ModelSurgeryEnvelope"))
        #expect(source.contains("pub fn validate"))
        #expect(source.contains("pub s_max"))
        #expect(source.contains("pub ppl_drift_max"))
    }

    @Test("W21: Active Rank-One Runtime substrate exists with τ-threshold selection")
    func w21ActiveRankOneRuntimeExists() throws {
        let source = try loadMirroredSourceTextFile("epistemos-vault/src/runtime/active_rank_one.rs")
        #expect(source.contains("HELIOS-W21 guard"))
        #expect(source.contains("pub struct ActiveSubcomponent"))
        #expect(source.contains("pub struct ActiveStep"))
        #expect(source.contains("pub fn select_above_threshold"))
        #expect(source.contains("pub tau"))
    }

    @Test("W22: HCache + KVCrush experimental tier substrate exists")
    func w22HCacheKvCrushExists() throws {
        let hcache = try loadMirroredSourceTextFile("epistemos-vault/src/cache/hcache.rs")
        #expect(hcache.contains("HELIOS-W22-HCACHE guard"))
        #expect(hcache.contains("pub struct HCacheEntry"))
        #expect(hcache.contains("pub enum HCacheCompression"))

        let kvcrush = try loadMirroredSourceTextFile("epistemos-vault/src/cache/kvcrush.rs")
        #expect(kvcrush.contains("HELIOS-W22-KVCRUSH guard"))
        #expect(kvcrush.contains("pub struct TernaryKvCell"))
        #expect(kvcrush.contains("pub struct KvCrushFootprint"))
    }

    @Test("W16: Pro-tier T-MAC + Atlas joint path gated `pro-build`")
    func w16ProJointPathExists() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/scope_rex/pro_joint.rs")
        #expect(source.contains("HELIOS-W16 guard"))
        #expect(source.contains("#![cfg(feature = \"pro-build\")]"))
        #expect(source.contains("pub fn pro_joint_matmul"))
        #expect(source.contains("BIT-IDENTICAL"))

        // Wired into scope_rex/mod.rs under pro-build cfg.
        let modSource = try loadMirroredSourceTextFile("agent_core/src/scope_rex/mod.rs")
        #expect(modSource.contains("pub mod pro_joint"))
    }

    @Test("PCF-9: Connectome Distillation substrate exists in vault")
    func pcf9ConnectomeDistillationExists() throws {
        let source = try loadMirroredSourceTextFile("epistemos-vault/src/distill/connectome.rs")
        #expect(source.contains("HELIOS-PCF9 guard"))
        #expect(source.contains("pub struct ConnectomeDistillation"))
        #expect(source.contains("output_model_sha256"))
        #expect(source.contains("pub fn passes_acceptance"))
    }

    @Test("Stage 3: epistemos-research crate exists with research feature gate")
    func stage3ResearchCrateExists() throws {
        let cargo = try loadMirroredSourceTextFile("epistemos-research/Cargo.toml")
        #expect(cargo.contains("name = \"epistemos-research\""))
        #expect(cargo.contains("research = []"))
        let lib = try loadMirroredSourceTextFile("epistemos-research/src/lib.rs")
        #expect(lib.contains("#[cfg(feature = \"research\")]"))
        #expect(lib.contains("pub mod vpd"))
        #expect(lib.contains("pub mod theorems"))
        #expect(lib.contains("pub mod acs"))
    }

    @Test("W17: VPD extract pipeline + ParamComponent rank-1 form")
    func w17VpdExtractExists() throws {
        let source = try loadMirroredSourceTextFile("epistemos-research/src/vpd/extract.rs")
        #expect(source.contains("HELIOS-W17 guard"))
        #expect(source.contains("pub struct ParamComponent"))
        #expect(source.contains("pub fn reconstruct"))
        #expect(source.contains("alive: bool"))
        // SPD/APD ancestry citations.
        #expect(source.contains("2506.20790") || source.contains("2501.14926"))
    }

    @Test("W18: ParamAnchor library + frozen anchor entries")
    func w18ParamAnchorExists() throws {
        let source = try loadMirroredSourceTextFile("epistemos-research/src/vpd/anchor.rs")
        #expect(source.contains("HELIOS-W18 guard"))
        #expect(source.contains("pub struct ParamAnchor"))
        #expect(source.contains("pub struct ParamAnchorLibrary"))
    }

    @Test("W19: Dual Connectome Trace (parameter + activation)")
    func w19DualConnectomeTraceExists() throws {
        let source = try loadMirroredSourceTextFile("epistemos-research/src/vpd/dual_trace.rs")
        #expect(source.contains("HELIOS-W19 guard"))
        #expect(source.contains("pub struct DualTraceSample"))
        #expect(source.contains("pub struct DualConnectomeTrace"))
        #expect(source.contains("param_activations"))
        #expect(source.contains("act_activations"))
    }

    @Test("Stage 3 / E1-E7: substrate types present with HELIOS-E<n> guards")
    func stage3E1ThroughE7Exists() throws {
        for (file, marker) in [
            ("epistemos-research/src/theorems/e1_density.rs", "HELIOS-E1 guard"),
            ("epistemos-research/src/theorems/e2_sheaf_gluing.rs", "HELIOS-E2 guard"),
            ("epistemos-research/src/theorems/e3_morph_field.rs", "HELIOS-E3 guard"),
            ("epistemos-research/src/theorems/e4_wbo7.rs", "HELIOS-E4 guard"),
            ("epistemos-research/src/theorems/e5_duplex_fusion.rs", "HELIOS-E5 guard"),
            ("epistemos-research/src/theorems/e6_epi_epsilon.rs", "HELIOS-E6 guard"),
            ("epistemos-research/src/theorems/e7_kernel_identity.rs", "HELIOS-E7 guard"),
        ] {
            let source = try loadMirroredSourceTextFile(file)
            #expect(source.contains(marker), "\(file) missing canonical \(marker)")
        }
    }

    @Test("Stage 3 / ACS / CMS-X: substrate lifted from helios v4 source_docs")
    func stage3AcsCmsXExists() throws {
        let source = try loadMirroredSourceTextFile("epistemos-research/src/acs.rs")
        #expect(source.contains("HELIOS-ACS guard"))
        #expect(source.contains("pub struct AcsAnchor"))
        #expect(source.contains("pub struct CmsXField"))
    }

    @Test("Stage 3 / SCOPE-Rex Pro: δ + ρ substrate gated `pro-build`")
    func stage3ScopeRexProExists() throws {
        let modSource = try loadMirroredSourceTextFile("agent_core/src/resonance/mod.rs")
        #expect(modSource.contains("#[cfg(feature = \"pro-build\")]"))
        #expect(modSource.contains("pub mod delta"))
        #expect(modSource.contains("pub mod rho"))

        let delta = try loadMirroredSourceTextFile("agent_core/src/resonance/delta.rs")
        #expect(delta.contains("HELIOS-DELTA guard"))
        #expect(delta.contains("pub enum DeltaOp"))
        #expect(delta.contains("UpwardGeneralization"))
        #expect(delta.contains("DownwardSpecialization"))
        #expect(delta.contains("LateralResonance"))

        let rho = try loadMirroredSourceTextFile("agent_core/src/resonance/rho.rs")
        #expect(rho.contains("HELIOS-RHO guard"))
        #expect(rho.contains("pub struct ResonanceScore"))
        #expect(rho.contains("pub fn rho_from_evidence_overlap"))
    }

    @Test("Stage 3 / SCOPE-Rex Research: κ + η substrate gated `research`")
    func stage3ScopeRexResearchExists() throws {
        let modSource = try loadMirroredSourceTextFile("agent_core/src/resonance/mod.rs")
        #expect(modSource.contains("#[cfg(feature = \"research\")]"))
        #expect(modSource.contains("pub mod kappa"))
        #expect(modSource.contains("pub mod eta"))

        let kappa = try loadMirroredSourceTextFile("agent_core/src/resonance/kappa.rs")
        #expect(kappa.contains("HELIOS-KAPPA guard"))
        #expect(kappa.contains("pub struct KamStabilityScore"))
        #expect(kappa.contains("pub fn kappa_from_deviation"))

        let eta = try loadMirroredSourceTextFile("agent_core/src/resonance/eta.rs")
        #expect(eta.contains("HELIOS-ETA guard"))
        #expect(eta.contains("pub enum EvidenceSupremacy"))
        #expect(eta.contains("pub fn eta_classify"))
    }

    @Test("W23: Forensic citation registry tool exists + has full id namespace")
    func w23ForensicCiteToolExists() throws {
        let source = try loadMirroredSourceTextFile("Tools/forensic-cite/forensic-cite.sh")
        #expect(source.contains("HELIOS-W23 guard"))
        // Full id namespace coverage: at least 1 entry per major
        // group (E / H / PCF).
        for id in ["E1|", "E7|", "H1|", "H17|", "PCF-1|", "PCF-10|"] {
            #expect(
                source.contains(id),
                "forensic-cite registry must include row for \(id)"
            )
        }
    }

    @Test("W24: Sorry-budget tracker exists with v5.2 hardened budgets")
    func w24SorryBudgetTrackerExists() throws {
        let source = try loadMirroredSourceTextFile("Tools/sorry-budget/sorry-budget.sh")
        #expect(source.contains("HELIOS-W24 guard"))
        // Budget values per v5.2 §F:
        //   E*: 2 (substrate-foundational)
        //   H1-H10: 4 (architectural)
        //   H11-H17 + PCF: 7 (cross-tradition / candidate)
        #expect(source.contains("E1|2"))
        #expect(source.contains("H1|4"))
        #expect(source.contains("H17|7"))
        #expect(source.contains("PCF-1|7"))
    }

    @Test("W25: Hardware falsifier rig exists with 11 protocol rows")
    func w25FalsifierRigExists() throws {
        let source = try loadMirroredSourceTextFile("Tools/falsifier/falsifier.sh")
        #expect(source.contains("HELIOS-W25 guard"))
        // Each of the W1-W15 substrates we built has a falsifier
        // protocol row.
        for entry in [
            "E3|storage::vault",
            "H2|scope_rex::metal::softmax",
            "H3|scope_rex::metal::asa_index",
            "H7|scope_rex::residency",
            "H17|scope_rex::retrieval::hopfield",
            "W1|scope_rex::answer_packet",
            "W5|scope_rex::btm_semantic",
            "W8|scope_rex::kv::direct_gate",
            "W12|scope_rex::kernels::t_mac",
            "W13|scope_rex::kernels::bitnet",
            "W14|scope_rex::kernels::sparse_ternary_gemm",
        ] {
            #expect(
                source.contains(entry),
                "falsifier registry must include protocol row '\(entry)'"
            )
        }
    }

    @Test("W26: §2.5.2 compliance audit exists + checks 7 Tier-2 toggle defaults")
    func w26AppReviewAuditExists() throws {
        let source = try loadMirroredSourceTextFile("Tools/app-review-audit/app-review-audit.sh")
        #expect(source.contains("HELIOS-W26 guard"))
        // Every Tier-2 toggle from W9/W10/W11 is in the required-OFF
        // assertion list.
        for key in [
            "epistemos.helios.v5.verifiedResearchMode",
            "epistemos.helios.v5.hopfieldRetrieval",
            "epistemos.helios.v5.connectomeBrowser",
            "epistemos.helios.v5.experimentalMetalKernels",
            "epistemos.helios.v5.kernel.tMac",
            "epistemos.helios.v5.kernel.bitnet",
            "epistemos.helios.v5.kernel.sparseTernaryGEMM",
        ] {
            #expect(
                source.contains(key),
                "§2.5.2 audit must require key '\(key)' to default OFF"
            )
        }
    }

    @Test("W26: §2.5.2 audit wired as ci.yml step")
    func w26WiredInCiYaml() throws {
        let source = try loadMirroredSourceTextFile(".github/workflows/ci.yml")
        #expect(source.contains("./Tools/app-review-audit/app-review-audit.sh"))
        #expect(source.contains("App Review §2.5.2 compliance audit"))
    }

    @Test("W12: T-MAC LUT reference exists with ternary type + reference fn")
    func w12TmacReferenceExists() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/scope_rex/kernels/t_mac.rs")
        #expect(source.contains("HELIOS-W12 guard"))
        #expect(source.contains("pub struct TernaryWeight"))
        #expect(source.contains("pub fn t_mac_reference"))
        #expect(source.contains("pub fn validate_ternary_weights"))
    }

    @Test("W13: BitNet b1.58 absmean quant exists with QuantizedBitnet + GEMM")
    func w13BitnetExists() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/scope_rex/kernels/bitnet.rs")
        #expect(source.contains("HELIOS-W13 guard"))
        #expect(source.contains("pub fn absmean_quantize"))
        #expect(source.contains("pub fn bitnet_b158_gemm"))
        #expect(source.contains("pub struct QuantizedBitnet"))
        // Cite the canonical BitNet b1.58 paper (corrected per v5.2).
        #expect(source.contains("2402.17764") || source.contains("2504.12285"))
    }

    @Test("W14: Sparse Ternary GEMM exists with sparse matrix + bit-identical contract")
    func w14SparseTernaryGemmExists() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/scope_rex/kernels/sparse_ternary_gemm.rs")
        #expect(source.contains("HELIOS-W14 guard"))
        #expect(source.contains("pub struct SparseTernaryEntry"))
        #expect(source.contains("pub struct SparseTernaryRow"))
        #expect(source.contains("pub struct SparseTernaryMatrix"))
        #expect(source.contains("pub fn sparse_ternary_gemm"))
        #expect(source.contains("BIT-IDENTICAL"))
        // Canonical Lipshitz et al. citation present.
        #expect(source.contains("2510.06957"))
    }

    @Test("W15: Modern Hopfield retrieval substrate exists with update + cosine")
    func w15ModernHopfieldExists() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/scope_rex/retrieval/hopfield.rs")
        #expect(source.contains("HELIOS-W15 guard"))
        #expect(source.contains("pub fn modern_hopfield_update"))
        #expect(source.contains("pub fn cosine_similarity"))
        // Update-rule formula present in docs.
        #expect(source.contains("softmax"))
        // Canonical Ramsauer et al. citation.
        #expect(source.contains("2008.02217"))
    }

    @Test("W9: Verified Research Mode Settings toggle exists default OFF")
    func w9VerifiedResearchModeToggleExists() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/HELIOSv5SettingsView.swift")
        #expect(source.contains("HELIOS-W9 guard"))
        // Toggle key matches the AppStorage key spec.
        #expect(source.contains("epistemos.helios.v5.verifiedResearchMode"))
        #expect(source.contains("private var vrmEnabled = false"))
        // VRM parent → Hopfield child wiring.
        #expect(source.contains("Modern Hopfield retrieval"))
    }

    @Test("W10: Connectome Browser Settings toggle + bundled atlas exist")
    func w10ConnectomeBrowserToggleExists() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/HELIOSv5SettingsView.swift")
        #expect(source.contains("HELIOS-W10 guard"))
        #expect(source.contains("epistemos.helios.v5.connectomeBrowser"))
        #expect(source.contains("private var connectomeBrowserEnabled = false"))

        // Bundled atlas JSON ships with the .app per §2.5.2 (not downloaded).
        let atlas = try loadMirroredSourceTextFile("Epistemos/Resources/connectome_atlas_v1.json")
        #expect(atlas.contains("connectome-atlas-v1-stub-2026-05-06"))
        #expect(atlas.contains("\"verified_floor\": \"ac8c6d28\""))
        #expect(atlas.contains("\"tier\": 2"))
    }

    @Test("W11: Experimental Metal Kernels Settings parent + 3 children exist")
    func w11ExperimentalMetalKernelsToggleExists() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/HELIOSv5SettingsView.swift")
        #expect(source.contains("HELIOS-W11 guard"))
        #expect(source.contains("epistemos.helios.v5.experimentalMetalKernels"))
        #expect(source.contains("private var metalKernelsEnabled = false"))
        // 3 children: T-MAC, BitNet, Sparse Ternary GEMM.
        #expect(source.contains("epistemos.helios.v5.kernel.tMac"))
        #expect(source.contains("epistemos.helios.v5.kernel.bitnet"))
        #expect(source.contains("epistemos.helios.v5.kernel.sparseTernaryGEMM"))
        // All three default false per §2.5.2 Tier-2 compliance.
        #expect(source.contains("private var tMacEnabled = false"))
        #expect(source.contains("private var bitnetEnabled = false"))
        #expect(source.contains("private var sparseTernaryEnabled = false"))
    }

    @Test("W8: KV-Direct gate (Tier-1 round-trip equality)")
    func w8KvDirectGateExists() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/scope_rex/kv/direct_gate.rs")
        #expect(source.contains("HELIOS-W8 guard"))
        // Public API: KvLayout + KvDispatch + route + reference / direct.
        #expect(source.contains("pub struct KvLayout"))
        #expect(source.contains("pub struct KvPair"))
        #expect(source.contains("pub enum KvDispatch"))
        #expect(source.contains("pub fn route"))
        #expect(source.contains("pub fn reference_qk_row"))
        #expect(source.contains("pub fn direct_qk_row"))
        // Eligibility predicate documented.
        #expect(source.contains("direct_path_eligible"))
        // Round-trip equality contract.
        #expect(source.contains("BIT-IDENTICAL"))
    }

    @Test("W5: Semantic Brain Time Machine V1.5 substrate exists, never tensor")
    func w5SemanticBTMSubstrateExists() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/scope_rex/btm_semantic.rs")
        // Canonical guard marker.
        #expect(source.contains("HELIOS-W5 guard"))
        // Three required deltas paths.
        #expect(source.contains("pub struct SemanticDelta"))
        #expect(source.contains("pub added_claims"))
        #expect(source.contains("pub modified_claims"))
        #expect(source.contains("pub removed_claim_ids"))
        // Public API shape.
        #expect(source.contains("pub fn apply_delta"))
        #expect(source.contains("pub fn replay"))
        #expect(source.contains("pub fn rewind"))
        // Load-bearing W5 contract: NEVER carries tensor weights.
        #expect(!source.contains("pub weights:"))
        #expect(!source.contains("pub tensors:"))
        #expect(!source.contains("pub checkpoint:"))
        // Doc-comment lock on the W5 V1.5 vs Pro tensor split.
        #expect(source.contains("V1.5"))
        #expect(source.contains("NEVER tensor checkpoints"))
    }

    @Test("W4: Swift Residency mirror declares all 9 arms with snake_case raw values")
    func w4ResidencySwiftMirrorMatchesRust() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Models/AnswerPacket.swift")
        #expect(source.contains("HELIOS-W4 guard"))
        #expect(source.contains("public enum Residency"))
        for caseName in [
            "case transientContext = \"transient_context\"",
            "case retrievalMemory = \"retrieval_memory\"",
            "case featureRule = \"feature_rule\"",
            "case harnessRule = \"harness_rule\"",
            "case grpoPrior = \"grpo_prior\"",
            "case psoftAdapter = \"psoft_adapter\"",
            "case osftCore = \"osft_core\"",
            "case cloudDistilled = \"cloud_distilled\"",
            "case quarantine",
        ] {
            #expect(
                source.contains(caseName),
                "Swift Residency mirror must declare: \(caseName)"
            )
        }
    }

    @Test("W1: Rust + Swift mirror enums use snake_case wire format for parity")
    func w1RustSwiftMirrorParity() throws {
        let rustSource = try loadMirroredSourceTextFile("agent_core/src/scope_rex/answer_packet.rs")
        // Rust side declares snake_case rename for the enum.
        #expect(rustSource.contains("#[serde(rename_all = \"snake_case\")]"))

        let swiftSource = try loadMirroredSourceTextFile("Epistemos/Models/AnswerPacket.swift")
        // Swift side must declare CodingKeys / raw values matching
        // the snake_case wire format. Spot-check a few edges:
        #expect(swiftSource.contains("case codeInvariant = \"code_invariant\""))
        #expect(swiftSource.contains("case plausibleButUnverified = \"plausible_but_unverified\""))
        #expect(swiftSource.contains("case residencySignals = \"residency_signals\""))
        #expect(swiftSource.contains("case witnessedStateRef = \"witnessed_state_ref\""))
        #expect(swiftSource.contains("case mutationEnvelopeRef = \"mutation_envelope_ref\""))
    }
}
