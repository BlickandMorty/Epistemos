import Foundation
import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free MAS performance-budget policy tests must compile in the App Store target.")
#endif

@Suite("Free MAS performance budget policy")
struct FreeV1PerformanceBudgetPolicyTests {
    @Test("the Free gate measures only retained product boundaries")
    func freeGateExcludesRetiredAgentRuntimeBudgets() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let budget = try String(
            contentsOf: repositoryRoot.appendingPathComponent("docs/perf-budgets.toml"),
            encoding: .utf8
        )
        let parser = try String(
            contentsOf: repositoryRoot.appendingPathComponent("scripts/check-perf-budgets.sh"),
            encoding: .utf8
        )

        for retiredIdentifier in [
            "libagent_core_mb_max",
            "libomega_mcp_mb_max",
            "libomega_ax_mb_max",
            "libsubstrate_rt_mb_max",
            "mcp_invoke_ms_p99",
            "[agent_surface]",
            "[experimental_surface]",
        ] {
            #expect(!budget.contains(retiredIdentifier))
            #expect(!parser.contains(retiredIdentifier))
        }

        for retainedIdentifier in [
            "libepistemos_core_mb_max",
            "appstore_bundle_mb_max",
            "cold_start_ms_p99",
            "keelstone_search_first_search_ready_p95_ms",
            "KEELSTONE_SEED_PERF_REGRESSION",
        ] {
            #expect(budget.contains(retainedIdentifier) || parser.contains(retainedIdentifier))
        }

        #expect(budget.contains("perf-budgets-free-mas-runtime.json"))
        #expect(parser.contains("perf-budgets-free-mas-runtime.json"))
        #expect(!parser.contains("binary_skipped"))
        #expect(!parser.contains("raw_required"))
        #expect(parser.contains("::error::${dylib} not found"))
    }
}
