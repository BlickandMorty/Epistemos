import Foundation
import Testing
@testable import Epistemos

// Wiring #6 (T18B ACS dispatch admission gate) Swift integration test.
// Status-read only per HIGH RISK guidance — no production gating
// invoked from this test.

@Suite("ACS Admission Wiring #6")
struct ACSAdmissionWiringTests {

    @Test("ACSAdmissionBridge.strictPolicySummary returns canonical shape")
    func acsAdmissionBridgeReturnsPolicy() throws {
        ACSAdmissionMetrics.shared.reset()

        let summary = ACSAdmissionBridge.strictPolicySummary()
        #if canImport(agent_coreFFI)
        let requiredSummary = try #require(summary)
        #expect(requiredSummary.policyId == "acs-strict-default")
        #expect(requiredSummary.version >= 1)
        #expect(requiredSummary.capabilityRulesCount >= 5,
                "strict default must require at least 5 capabilities")
        #expect(requiredSummary.canonicalVerdicts.count == 5)
        #expect(requiredSummary.canonicalVerdicts.contains("allow"))
        #expect(requiredSummary.canonicalVerdicts.contains("reject"))
        #else
        #expect(summary == nil)
        #expect(ACSAdmissionMetrics.shared.snapshot().lastErrorDescription != nil)
        #endif
    }

    @Test("ACSAdmissionMetrics records the read")
    func acsAdmissionMetricsRecordsRead() throws {
        ACSAdmissionMetrics.shared.reset()
        let summary = ACSAdmissionBridge.strictPolicySummary()
        let snap = ACSAdmissionMetrics.shared.snapshot()
        #if canImport(agent_coreFFI)
        _ = try #require(summary)
        #expect(snap.totalReads == 1)
        #expect(snap.lastPolicy != nil)
        #expect(snap.lastReadAt != nil)
        #else
        #expect(summary == nil)
        #expect(snap.totalReads == 0)
        #expect(snap.lastPolicy == nil)
        #expect(snap.lastErrorDescription != nil)
        #endif
    }

    @Test("ACSAdmissionFlags reads UserDefaults + env fallback")
    func acsAdmissionFlagsToggle() {
        let saved = UserDefaults.standard.bool(forKey: ACSAdmissionFlags.userDefaultsKey)
        defer { UserDefaults.standard.set(saved, forKey: ACSAdmissionFlags.userDefaultsKey) }
        UserDefaults.standard.set(false, forKey: ACSAdmissionFlags.userDefaultsKey)
        let envIsSet = ProcessInfo.processInfo.environment[ACSAdmissionFlags.userDefaultsKey] == "1"
        if !envIsSet {
            #expect(!ACSAdmissionFlags.isEnabled)
        }
        UserDefaults.standard.set(true, forKey: ACSAdmissionFlags.userDefaultsKey)
        #expect(ACSAdmissionFlags.isEnabled)
    }
}
