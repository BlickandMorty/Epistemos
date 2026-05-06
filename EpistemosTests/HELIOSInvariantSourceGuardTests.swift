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
