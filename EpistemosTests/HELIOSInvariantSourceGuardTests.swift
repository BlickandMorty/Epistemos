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
}
