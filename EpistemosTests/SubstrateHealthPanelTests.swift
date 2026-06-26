import Foundation
import Testing

@testable import Epistemos

// W6 (Terminal 1 WRV mission) test. Verifies the unified Substrate
// Health panel:
//
//   - Mounts the legacy substrate health rows plus the Terminal D
//     unified floor rows.
//   - Mounts the T14 UAS plane-placement row so the cluster surfaces
//     live per-plane DAG counts from the Rust FFI snapshot.
//   - Is wired into `SettingsView` exactly once and replaces the
//     scattered per-row mounts that used to live in
//     General → Diagnostics.

@Suite("Substrate Health Panel (W6)")
struct SubstrateHealthPanelTests {

    @Test("SubstrateHealthPanel mounts the WRV substrate rows")
    func substrateHealthPanelMountsSubstrateRows() throws {
        let panel = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SubstrateHealthPanel.swift"
        )

        #expect(panel.contains("EidosHealthRow()"))
        #expect(panel.contains("VaultRecallHealthRow()"))
        #expect(panel.contains("LatticeWBOHealthRow()"))
        #expect(panel.contains("FUlpHealthRow()"))
        #expect(panel.contains("ACSAdmissionHealthRow()"))
        #expect(panel.contains("FalsifierArtifactsHealthRow()"))
        #expect(panel.contains("AnswerPacketHealthRow()"))
        #expect(panel.contains("EmlObservatoryHealthRow()"))
        #expect(panel.contains("UasAcsHealthRow()"))
        #expect(panel.contains("CognitiveDagCountsHealthRow()"))
        #expect(panel.contains("CognitiveWeightClassHealthRow()"))
        #expect(panel.contains("SubstrateDriftMonitorHealthRow()"))
    }

    @Test("SubstrateHealthPanel mounts the UAS plane-placement witness row")
    func substrateHealthPanelMountsPlanePlacementRow() throws {
        let panel = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SubstrateHealthPanel.swift"
        )
        let row = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/PlanePlacementHealthRow.swift"
        )

        #expect(panel.contains("PlanePlacementHealthRow()"))
        #expect(panel.contains("F-ACS-AnchorLookup_2026_05_24.md"))
        #expect(row.contains("SubstrateHealthUnifiedClient.snapshot()"))
        #expect(row.contains("return p.planeFieldsWired ? \"read-only counts\""))
        #expect(row.contains("state=\\(p.stateCount) episodic=\\(p.episodicCount) assembly=\\(p.assemblyCount)"))
    }

    @Test("D-prime rows keep chip strips and W-30 badges conservative")
    func dPrimeRowsKeepChipStripsConservative() throws {
        let answerPacket = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/AnswerPacketHealthRow.swift"
        )
        let planePlacement = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/PlanePlacementHealthRow.swift"
        )
        let cognitiveWeight = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/CognitiveWeightClassHealthRow.swift"
        )
        let components = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SettingsSurfaceComponents.swift"
        )
        let bridge = try loadMirroredSourceTextFile("agent_core/src/bridge.rs")

        // "session ring only" → "session ring + durable log": Phase 2 (64196c4a8) added the durable
        // JSONL persistence log, so the honest substrate string now lists both. Conservatism is still
        // asserted by falsifierPassed: false below (the falsifier hasn't passed).
        #expect(answerPacket.contains("session ring + durable log"))
        #expect(answerPacket.contains("falsifierPassed: false"))
        #expect(planePlacement.contains("falsifierPassed: false"))
        #expect(components.contains("private var substrateTint: Color"))
        #expect(components.contains("return productionWired ? .orange : .secondary"))
        #expect(cognitiveWeight.contains("badge only"))
        #expect(bridge.contains("\"class\": \"policy_grade\", \"range\": \"0.86-1.00\", \"policy_authority\": false"))
    }

    @Test("UAS ACS row reads measured artifact gates without turning runtime adapter green")
    func uasAcsRowReadsMeasuredArtifactGatesConservatively() throws {
        let row = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/UasAcsHealthRow.swift"
        )

        #expect(row.contains("UasAcsGateSnapshot.load()"))
        #expect(row.contains("artifacts/falsifiers/uas_copy_count/result.json"))
        #expect(row.contains("artifacts/falsifiers/acs_anchor_lookup/result.json"))
        #expect(row.contains("F-UAS-CopyCount"))
        #expect(row.contains("F-ACS-AnchorLookup"))
        #expect(row.contains("MAS runtime adapter pending"))
        #expect(!row.contains("harness passed; production registry adapter pending"),
                "Measured artifact PASS should be distinct from production adapter wiring.")
    }

    @Test("Gemma official QAT acquisition helper stays quarantine and receipt only")
    func gemmaOfficialQATAcquisitionHelperStaysQuarantineAndReceiptOnly() throws {
        let helper = try loadMirroredSourceTextFile(
            "Tools/falsifiers/acquire_gemma_official_qat_gguf.py"
        )
        let wrapper = try loadMirroredSourceTextFile(
            "Tools/falsifiers/acquire_gemma_official_qat_gguf.sh"
        )

        #expect(helper.contains("hf_hub_download("))
        #expect(helper.contains("ModelQuarantine"))
        #expect(helper.contains("local_dir=str(dest_dir)"))
        #expect(helper.contains("local_dir_use_symlinks=False"))
        #expect(helper.contains("verify_file(path, lane)"))
        #expect(helper.contains("lane.byte_count"))
        #expect(helper.contains("lane.sha256"))
        #expect(helper.contains("materialize_gemma_owner_approved_local_artifact_receipt.sh"))
        #expect(helper.contains("owner_approved_hf_snapshot_download_to_quarantine"))
        #expect(helper.contains("Gemma 4 E2B QAT GGUF first proof"))
        #expect(helper.contains("Gemma 4 E4B QAT GGUF balanced lane"))
        #expect(helper.contains("Gemma 4 12B QAT GGUF Pro flagship candidate"))
        #expect(helper.contains("3_349_514_112"))
        #expect(helper.contains("5_154_939_136"))
        #expect(helper.contains("6_975_877_728"))
        #expect(helper.contains("3646b4c147cd235a44d91df1546d3b7d8e29b547dbe4e1f80856419aa455e6fd"))
        #expect(helper.contains("e8b6a059ba86947a44ace84d6e5679795bc41862c25c30513142588f0e9dba1d"))
        #expect(helper.contains("faff1a63667fac17ac5e777f47114688fcefea96e220e211aaa8d62c2c4561f1"))
        #expect(!helper.contains("llama-server"))
        #expect(!helper.contains("llama-cli -hf"))
        #expect(wrapper.contains("python3 Tools/falsifiers/acquire_gemma_official_qat_gguf.py"))
    }

    @Test("Gemma first runtime proof scripts preserve lane-specific artifacts")
    func gemmaFirstRuntimeProofScriptsPreserveLaneSpecificArtifacts() throws {
        let helper = try loadMirroredSourceTextFile(
            "Tools/falsifiers/gemma_first_runtime_paths.sh"
        )
        let wrappers = [
            "Tools/falsifiers/materialize_gemma_owner_approved_local_artifact_receipt.sh",
            "Tools/falsifiers/run_gemma_first_runtime_execution_probe.sh",
            "Tools/falsifiers/materialize_gemma_first_runtime_quality_packet.sh",
            "Tools/falsifiers/run_gemma_first_runtime_quality_observation_replay.sh",
            "Tools/falsifiers/execute_gemma_first_runtime_quality_replay.sh",
            "Tools/falsifiers/materialize_gemma_first_runtime_runtime_router_admission_packet.sh",
            "Tools/falsifiers/materialize_gemma_first_runtime_system_g_dry_run_route_packet.sh",
            "Tools/falsifiers/materialize_gemma_first_runtime_route_answer_packet_visibility.sh",
            "Tools/falsifiers/materialize_gemma_first_runtime_settings_diagnostics_wrv.sh",
        ]

        #expect(helper.contains("gemma_proof_lane()"))
        #expect(helper.contains("EPI_GEMMA_PROOF_LANE"))
        #expect(helper.contains("e2b|e4b|12b"))
        #expect(helper.contains("gemma_lane_prefix"))
        #expect(helper.contains("if [[ \"$lane\" == \"e2b\" ]]"))
        #expect(helper.contains("gemma_owner_approved_local_artifact_receipt_materializer/${prefix}receipt.redacted.json"))
        #expect(helper.contains("gemma_direct_harness_first_runtime_execution_probe/${prefix}receipt.redacted.json"))
        #expect(helper.contains("gemma_direct_harness_first_runtime_quality_packet/${prefix}packet.redacted.json"))
        #expect(helper.contains("gemma_direct_harness_first_runtime_quality_replay/${prefix}result.redacted.json"))
        #expect(helper.contains("gemma_direct_harness_first_runtime_runtime_router_admission/${prefix}admission.redacted.json"))
        #expect(helper.contains("gemma_direct_harness_first_runtime_system_g_dry_run_route/${prefix}system_g_dry_run.redacted.json"))
        #expect(helper.contains("gemma_direct_harness_first_runtime_route_answer_packet_visibility/${prefix}visibility.redacted.json"))
        #expect(helper.contains("gemma_direct_harness_first_runtime_settings_diagnostics_wrv/${prefix}wrv.redacted.json"))

        for wrapperPath in wrappers {
            let wrapper = try loadMirroredSourceTextFile(wrapperPath)
            #expect(wrapper.contains("source Tools/falsifiers/gemma_first_runtime_paths.sh"))
            #expect(wrapper.contains("gemma_configure_first_runtime_paths"))
        }
    }

    @Test("Gemma quality observation replay helper deletes raw temporary output")
    func gemmaQualityObservationReplayHelperDeletesRawTemporaryOutput() throws {
        let helper = try loadMirroredSourceTextFile(
            "Tools/falsifiers/run_gemma_first_runtime_quality_observation_replay.py"
        )
        let wrapper = try loadMirroredSourceTextFile(
            "Tools/falsifiers/run_gemma_first_runtime_quality_observation_replay.sh"
        )

        #expect(helper.contains("--offline"))
        #expect(helper.contains("--single-turn"))
        #expect(helper.contains("--no-display-prompt"))
        #expect(helper.contains("extract_candidate_output(raw_stdout, prompt, task[\"task_family\"])"))
        #expect(helper.contains("re.search(r\"\\{.*\\}\", candidate"))
        #expect(helper.contains("model_path.is_file()"))
        #expect(helper.contains("NamedTemporaryFile("))
        #expect(helper.contains("temp_path.unlink(missing_ok=True)"))
        #expect(helper.contains("execute_gemma_first_runtime_quality_replay.sh"))
        #expect(helper.contains("candidate_output"))
        #expect(helper.contains("cache_deleted_before_replay\": True"))
        #expect(helper.contains("contamination_check_passed\": True"))
        #expect(helper.contains("dry_run=true; no model execution, raw output, replay, or route mutation"))
        #expect(helper.contains("at least 15 words"))
        #expect(helper.contains("include the exact "))
        #expect(helper.contains("citation marker [A]"))
        #expect(helper.contains("exactly one bare compact JSON object"))
        #expect(helper.contains("no markdown or prose"))
        #expect(!helper.contains("llama-server"))
        #expect(!helper.contains("llama-cli -hf"))
        #expect(wrapper.contains("python3 Tools/falsifiers/run_gemma_first_runtime_quality_observation_replay.py"))
    }

    @Test("Release audit distribution focused evidence stays digest-only and non-promoting")
    func releaseAuditDistributionFocusedEvidenceStaysDigestOnlyAndNonPromoting() throws {
        let helper = try loadMirroredSourceTextFile(
            "agent_core/src/bin/materialize_release_audit_distribution_focused_evidence.rs"
        )
        let wrapper = try loadMirroredSourceTextFile(
            "Tools/falsifiers/materialize_release_audit_distribution_focused_evidence.sh"
        )

        #expect(helper.contains("F-ReleaseAuditDistributionFocusedEvidence"))
        #expect(helper.contains("release_audit_distribution_focused_evidence/result.json"))
        #expect(helper.contains("DEFAULT_APPSTORE_BUILD_LOG"))
        #expect(helper.contains("DEFAULT_DISTRIBUTION_TEST_LOG"))
        #expect(helper.contains("** BUILD SUCCEEDED **"))
        #expect(helper.contains("** TEST SUCCEEDED **"))
        #expect(helper.contains("Suite \\\"Phase S -- App Store hardening\\\" passed"))
        #expect(helper.contains("Suite \\\"Release Script Audit\\\" passed"))
        #expect(helper.contains("Suite \\\"Core/MAS Boundary Source Guard\\\" passed"))
        #expect(helper.contains("Test run with 70 tests in 3 suites passed"))
        #expect(helper.contains("raw_log_content_not_embedded"))
        #expect(helper.contains("notarization_or_review_not_claimed"))
        #expect(helper.contains("distribution_compliance_not_claimed"))
        #expect(helper.contains("ship_call_not_authorized"))
        #expect(helper.contains("gemma_route_not_promoted"))
        #expect(helper.contains("appstore_build_log_sha256"))
        #expect(helper.contains("distribution_focused_tests_log_sha256"))
        #expect(!helper.contains("product_green_claimed"))
        #expect(!helper.contains("ship_call_authorized"))
        #expect(wrapper.contains("--bin materialize_release_audit_distribution_focused_evidence"))
        #expect(wrapper.contains("falsifier_validator"))
    }

    @Test("Release audit distribution compliance review binds privacy entitlement and review evidence")
    func releaseAuditDistributionComplianceReviewBindsPrivacyEntitlementAndReviewEvidence() throws {
        let helper = try loadMirroredSourceTextFile(
            "agent_core/src/bin/materialize_release_audit_distribution_compliance_review.rs"
        )
        let wrapper = try loadMirroredSourceTextFile(
            "Tools/falsifiers/materialize_release_audit_distribution_compliance_review.sh"
        )
        let axes = try loadMirroredSourceTextFile("agent_core/src/falsifier_artifacts/axes.rs")

        #expect(helper.contains("F-ReleaseAuditDistributionComplianceReview"))
        #expect(helper.contains("release_audit_distribution_compliance_review/result.json"))
        #expect(helper.contains("Epistemos/Resources/PrivacyInfo.xcprivacy"))
        #expect(helper.contains("Epistemos/Epistemos-AppStore.entitlements"))
        #expect(helper.contains("Epistemos-AppStore-Info.plist"))
        #expect(helper.contains("docs/legal/privacy-policy.md"))
        #expect(helper.contains("docs/release/MAS_APP_REVIEW_NOTES.md"))
        #expect(helper.contains("scripts/release/build_release_app.sh"))
        #expect(helper.contains("scripts/release/create_release_dmg.sh"))
        #expect(helper.contains("scripts/release/notarize_release_dmg.sh"))
        #expect(helper.contains("NSPrivacyTracking"))
        #expect(helper.contains("NSPrivacyCollectedDataTypes"))
        #expect(helper.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
        #expect(helper.contains("ITSAppUsesNonExemptEncryption"))
        #expect(helper.contains("com.apple.security.app-sandbox"))
        #expect(helper.contains("com.apple.security.cs.disable-library-validation"))
        #expect(helper.contains("distribution_compliance_review_passed"))
        #expect(helper.contains("notarization_or_review_not_claimed"))
        #expect(helper.contains("ship_call_not_authorized"))
        #expect(helper.contains("gemma_route_not_promoted"))
        #expect(helper.contains("raw_file_content_not_embedded"))
        #expect(helper.contains("release_audit_zero_fail_pass_ledger"))
        #expect(!helper.contains("ZERO_FAIL_LEDGER"))
        #expect(!helper.contains("upstream_zero_fail_ledger_passed"))
        #expect(!helper.contains("ship_call_authorized"))
        #expect(!helper.contains("live_gemma_claim"))
        #expect(wrapper.contains("--bin materialize_release_audit_distribution_compliance_review"))
        #expect(wrapper.contains("falsifier_validator"))
        #expect(axes.contains("RELEASE_AUDIT_DISTRIBUTION_COMPLIANCE_REVIEW_AXES"))
    }

    @Test("Release audit zero-fail pass ledger is cumulative without release promotion")
    func releaseAuditZeroFailPassLedgerIsCumulativeWithoutReleasePromotion() throws {
        let helper = try loadMirroredSourceTextFile(
            "agent_core/src/bin/materialize_release_audit_zero_fail_pass_ledger.rs"
        )
        let wrapper = try loadMirroredSourceTextFile(
            "Tools/falsifiers/materialize_release_audit_zero_fail_pass_ledger.sh"
        )

        #expect(helper.contains("F-ReleaseAuditZeroFailPassLedger"))
        #expect(helper.contains("release_audit_zero_fail_pass_ledger/result.json"))
        #expect(helper.contains("AUTOMATED_CHECKS"))
        #expect(helper.contains("LOG_EVIDENCE"))
        #expect(helper.contains("MANUAL_RUNTIME"))
        #expect(helper.contains("CAPABILITY_CLOSEOUT"))
        #expect(helper.contains("DISTRIBUTION_FOCUSED"))
        #expect(helper.contains("DISTRIBUTION_COMPLIANCE_REVIEW"))
        #expect(helper.contains("all_required_artifacts_passed"))
        #expect(helper.contains("distribution_compliance_not_claimed"))
        #expect(helper.contains("distribution_compliance_review_passed"))
        #expect(helper.contains("ship_call_not_authorized"))
        #expect(helper.contains("gemma_route_not_promoted"))
        #expect(helper.contains("source_state_signature"))
        #expect(helper.contains("source_state_change_resets_counter"))
        #expect(helper.contains("duplicate_pass_signature_not_counted"))
        #expect(helper.contains("previous_zero_fail_pass_count"))
        #expect(helper.contains("zero_fail_pass_count"))
        #expect(helper.contains("remaining_zero_fail_pass_count"))
        #expect(helper.contains("release_completion_still_required"))
        #expect(helper.contains("release_ready_not_claimed"))
        #expect(helper.contains("zero_fail_pass_signature"))
        #expect(helper.contains("gemma_product_capability_recheck_after_release_audit"))
        #expect(helper.contains("read_previous_ledger()"))
        #expect(helper.contains("git"))
        #expect(helper.contains("ls-files"))
        #expect(!helper.contains("release_ready_claimed = true"))
        #expect(wrapper.contains("--bin materialize_release_audit_zero_fail_pass_ledger"))
        #expect(wrapper.contains("falsifier_validator"))
    }

    @Test("SettingsView mounts SubstrateHealthPanel exactly once in Diagnostics")
    func settingsViewMountsSubstrateHealthPanel() throws {
        let settings = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SettingsView.swift"
        )

        let mountCount = settings.components(separatedBy: "SubstrateHealthPanel()").count - 1
        #expect(mountCount == 1, "SubstrateHealthPanel must be mounted exactly once")
    }

    @Test("Inference settings surfaces Gemma QAT proof lanes without route promotion")
    func inferenceSettingsSurfacesGemmaQATProofLanesWithoutRoutePromotion() throws {
        let settings = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SettingsView.swift"
        )
        let infrastructure = try loadMirroredSourceTextFile(
            "Epistemos/Engine/LocalModelInfrastructure.swift"
        )

        #expect(settings.contains("GemmaQATProofLaneSummary()"))
        #expect(settings.contains("Gemma QAT proof lanes"))
        #expect(settings.contains("E2B / E4B / 12B QAT GGUF only"))
        #expect(settings.contains("GemmaQATRuntimeLadder.candidates"))
        #expect(settings.contains("@State private var capabilityCeiling = CapabilityCeilingHealthSnapshot.load()"))
        #expect(settings.contains("capabilityCeiling.gemmaLocalArtifactStatus(for: candidate)"))
        #expect(settings.contains("capabilityCeiling.gemmaProofStatus(for: candidate)"))
        #expect(settings.contains("capabilityCeiling.gemmaCompletedProofLaneSummary"))
        #expect(settings.contains("capabilityCeiling.gemmaProductRouteIntegrationDetail"))
        #expect(infrastructure.contains("scale route integration pending"))
        #expect(infrastructure.contains("Pro route integration pending"))
        #expect(settings.contains("capabilityCeiling = CapabilityCeilingHealthSnapshot.load()"))
        #expect(settings.contains("not picker rows"))
        #expect(settings.contains("do not mutate chat defaults or claim live Gemma routing"))
        #expect(!settings.contains("DiffusionGemma"))
        #expect(!settings.contains("Gemma 4 26"))
        #expect(!settings.contains("Gemma 4 31"))
        #expect(infrastructure.contains("google/gemma-4-E2B-it-qat-q4_0-gguf"))
        #expect(infrastructure.contains("google/gemma-4-E4B-it-qat-q4_0-gguf"))
        #expect(infrastructure.contains("google/gemma-4-12B-it-qat-q4_0-gguf"))
    }

    @Test("SettingsView no longer mounts the substrate rows individually outside the panel")
    func settingsViewDoesNotDoubleMountSubstrateRows() throws {
        let settings = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SettingsView.swift"
        )

        // Each of these rows must now be mounted *only* through the
        // panel — not via a direct invocation in SettingsView.
        let directMounts: [String] = [
            "                EidosHealthRow()",
            "                VaultRecallHealthRow()",
            "                LatticeWBOHealthRow()",
            "                FUlpHealthRow()",
            "                ACSAdmissionHealthRow()",
            "                AnswerPacketHealthRow()",
        ]
        for direct in directMounts {
            #expect(!settings.contains(direct),
                    "SettingsView still mounts \(direct.trimmingCharacters(in: .whitespaces)) outside the panel — duplicate render hazard")
        }
    }
}
