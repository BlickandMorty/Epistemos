#if !EPISTEMOS_APP_STORE
import Darwin
import Foundation

typealias ProAgentChildRecord = AgentSurfaceChildRecord

enum ProAgentChildLedger {
    static func ledgerURL(
        appSupport: URL? = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    ) -> URL? {
        AgentSurfaceChildLedger.ledgerURL(appSupport: appSupport)
    }

    static func processStartTimeSeconds(pid: pid_t) -> Int64? {
        AgentSurfaceChildLedger.processStartTimeSeconds(pid: pid)
    }

    static func processStartTime(pid: pid_t) -> (sec: Int64, usec: Int64)? {
        AgentSurfaceChildLedger.processStartTime(pid: pid)
    }

    static func record(pid: pid_t, name: String) {
        AgentSurfaceChildLedger.record(pid: pid, name: name)
    }

    static func forget(pid: pid_t) {
        AgentSurfaceChildLedger.forget(pid: pid)
    }

    static func clear() {
        AgentSurfaceChildLedger.clear()
    }

    static func sweepStaleChildren(
        graceNanoseconds: UInt64 = 1_500_000_000,
        diagnostics: (String) -> Void = { _ in }
    ) async {
        await AgentSurfaceChildLedger.sweepStaleChildren(
            graceNanoseconds: graceNanoseconds,
            diagnostics: diagnostics
        )
    }
}
#endif
