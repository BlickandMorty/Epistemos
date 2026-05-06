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
