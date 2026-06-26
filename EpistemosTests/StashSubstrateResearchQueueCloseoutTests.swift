import Foundation
import Testing

@Suite("Stash Substrate / Research Queue Closeout")
struct StashSubstrateResearchQueueCloseoutTests {
    private var repoRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func repoFileExists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(
            atPath: repoRootURL.appendingPathComponent(relativePath).path
        )
    }

    @Test("closeout records no active product recovery stash rows")
    func closeoutRecordsNoActiveProductRecoveryStashRows() throws {
        let closeout = try loadMirroredSourceTextFile(
            "docs/audits/STASH_SUBSTRATE_RESEARCH_QUEUE_CLOSEOUT_2026_05_26.md"
        )
        let ledger = try loadMirroredSourceTextFile(
            "docs/audits/STASH_RECOVERY_LEDGER_2026_05_26.md"
        )
        let recoveryStatus = try loadMirroredSourceTextFile(
            "docs/audits/MAIN_ARCHITECTURE_RECOVERY_STATUS_2026_05_26.md"
        )

        for row in ["stash@{2}", "stash@{5}", "stash@{7}", "stash@{8}", "stash@{9}", "stash@{13}", "stash@{14}", "stash@{18}"] {
            #expect(closeout.contains(row))
        }
        #expect(closeout.contains("No stash was popped, dropped, checked out, or bulk-applied."))
        #expect(ledger.contains("No active product-recovery stash rows remain."))
        #expect(!ledger.contains("recover after UI and graph-visible work"))
        #expect(!ledger.contains("Classification: very important, very large. Split into multiple branches."))
        #expect(recoveryStatus.contains("STASH_SUBSTRATE_RESEARCH_QUEUE_CLOSEOUT_2026_05_26.md"))
    }

    @Test("ACS stash deltas are represented without dishonest Settings green")
    func acsStashDeltasAreRepresentedWithoutDishonestSettingsGreen() throws {
        let lib = try loadMirroredSourceTextFile("agent_core/src/lib.rs")
        let missionRun = try loadMirroredSourceTextFile("agent_core/src/agent_runtime_v2/mission_run.rs")
        let scopeRexProof = try loadMirroredSourceTextFile("agent_core/src/scope_rex/admission_proof.rs")
        let healthRow = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ACSAdmissionHealthRow.swift")
        let decision = try loadMirroredSourceTextFile(
            "docs/audits/DECISION_RESOLVED_ACS_ANCHOR_ADDRESSING_2026_05_24.md"
        )

        #expect(lib.contains("pub mod acs_admission;"))
        #expect(missionRun.contains("pub fn admit_and_record_tool_call"))
        #expect(missionRun.contains("ACSRunEventLogSink"))
        #expect(scopeRexProof.contains("pub struct SCOPERexAdmissionProof"))
        #expect(decision.contains("Option 2 - Re-scope Terminal E") || decision.contains("Option 2 — Re-scope Terminal E"))

        #expect(healthRow.contains("substrate: \"substrate-only · gate not witnessed\""))
        #expect(healthRow.contains("productionWired: false"))
        #expect(healthRow.contains("Settings has not observed a production ACSRunEventLogSink admission witness."))
        #expect(!healthRow.contains("substrateTint: .green"))

        let appSource = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")
        #expect(!appSource.contains("CloudKnowledgeDistillationService"))
    }

    @Test("research and runtime doctrine pins from stashes are present")
    func researchAndRuntimeDoctrinePinsFromStashesArePresent() throws {
        let witness = try loadMirroredSourceTextFile("agent_core/src/research/eml_ir/witness.rs")
        let capability = try loadMirroredSourceTextFile("agent_core/src/agent_runtime_v2/capability.rs")

        #expect(witness.contains("fn replay_rejects_operation_gate_tier_type_before_raw_overflow()"))
        #expect(witness.contains("operation gate tier type drift must fail before raw overflow"))
        #expect(capability.contains("fn restrict_appends_caveat_at_end_preserving_existing_order_byte_for_byte()"))
        #expect(capability.contains("newest caveat must land at end"))
    }

    @Test("lattice WBO stash hunk is superseded by decomposed module")
    func latticeWBOStashHunkIsSupersededByDecomposedModule() throws {
        let facade = try loadMirroredSourceTextFile("agent_core/src/lattice_wbo/mod.rs")
        let serdeRoundtrip = try loadMirroredSourceTextFile("agent_core/src/lattice_wbo/tests/serde_roundtrip.rs")

        #expect(facade.contains("mod accounting;"))
        #expect(facade.contains("mod register;"))
        #expect(facade.contains("pub use accounting::{ActiveSupportBudget"))
        #expect(serdeRoundtrip.contains("fn active_support_budget_round_trips_json()"))
        #expect(serdeRoundtrip.contains("ActiveSupportBudget::new("))
        #expect(repoFileExists("agent_core/src/lattice_wbo/tests/active_support_side_info.rs"))
    }
}
