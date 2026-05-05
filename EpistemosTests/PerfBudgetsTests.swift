import Foundation
import Testing

/// Source-guard for the canonical performance budget surface introduced
/// in Wave 2.5 of the Extended Program Plan
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md`,
///  cross-ref dpp §1.1 Task 0.5).
///
/// Three artefacts MUST stay in lock-step:
///   1. `docs/perf-budgets.toml`           — single source of truth for budgets
///   2. `scripts/check-perf-budgets.sh`    — parser + CI gate consumer
///   3. `.github/workflows/ci.yml`         — invokes the script as a step
///
/// Drift in any of those silently disables the perf gate, so this test
/// reads each file from the bundled SourceMirror and asserts the canonical
/// keys are present at the expected location.
@Suite("Perf Budgets (Wave 2.5)")
nonisolated struct PerfBudgetsTests {

    private static func loadText(_ relative: String) throws -> String {
        try loadMirroredSourceTextFile(relative)
    }

    // MARK: - perf-budgets.toml

    /// Every canonical key from dpp §1.1 Task 0.5 MUST be present and
    /// MUST live under the documented section. Using `[section] ... key =`
    /// proximity is too loose for a single contains() check, so we walk
    /// the file line by line and track the active section header.
    @Test("perf-budgets.toml ships every canonical key under the documented section")
    func perfBudgetsTomlHasAllCanonicalKeys() throws {
        let text = try Self.loadText("docs/perf-budgets.toml")
        let observed = try Self.parseSimpleToml(text)

        // [binary] — per-dylib regression gates
        for key in [
            "libagent_core_mb_max",
            "libepistemos_core_mb_max",
            "libomega_mcp_mb_max",
            "libomega_ax_mb_max",
            "libsubstrate_rt_mb_max",
        ] {
            #expect(
                observed["binary"]?[key] != nil,
                "docs/perf-budgets.toml must declare [binary].\(key)"
            )
        }

        // [appstore] — Patch 9 ceiling, recorded for one-document visibility
        #expect(
            observed["appstore"]?["appstore_bundle_mb_max"] != nil,
            "docs/perf-budgets.toml must declare [appstore].appstore_bundle_mb_max"
        )

        // [runtime] — dpp §1.1 Task 0.5 verbatim values
        #expect(observed["runtime"]?["cold_start_ms_p99"] == "800",
                "[runtime].cold_start_ms_p99 must be the dpp-canonical 800")
        #expect(observed["runtime"]?["frame_ms_p99"] == "8.3",
                "[runtime].frame_ms_p99 must be the dpp-canonical 8.3")
        #expect(observed["runtime"]?["mcp_invoke_ms_p99"] == "2.0",
                "[runtime].mcp_invoke_ms_p99 must be the dpp-canonical 2.0")
        #expect(observed["runtime"]?["ffi_hot_path_us_p99"] == "5.0",
                "[runtime].ffi_hot_path_us_p99 must be the dpp-canonical 5.0")

        // [meta] — runtime measurement file pointer (consumed by the
        // bash parser; pinning it here prevents accidental rename).
        #expect(observed["meta"]?["runtime_results_path"] != nil,
                "[meta].runtime_results_path must be present (used by check-perf-budgets.sh)")
    }

    // MARK: - check-perf-budgets.sh

    @Test("check-perf-budgets.sh exists and is executable")
    func parserScriptExistsAndIsExecutable() throws {
        let url = try sourceMirrorURL(for: "scripts/check-perf-budgets.sh")
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: url.path),
                "scripts/check-perf-budgets.sh must exist (Wave 2.5 CI gate)")
        let attrs = try fm.attributesOfItem(atPath: url.path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        #expect((perms & 0o111) != 0,
                "scripts/check-perf-budgets.sh must be executable (chmod +x)")
    }

    @Test("check-perf-budgets.sh consumes every canonical [binary] key")
    func parserScriptKnowsAllBinaryTargets() throws {
        let script = try Self.loadText("scripts/check-perf-budgets.sh")
        for key in [
            "libagent_core_mb_max",
            "libepistemos_core_mb_max",
            "libomega_mcp_mb_max",
            "libomega_ax_mb_max",
            "libsubstrate_rt_mb_max",
        ] {
            #expect(script.contains(key),
                    "scripts/check-perf-budgets.sh must reference [binary].\(key) — otherwise the budget is silently ignored")
        }
    }

    // MARK: - CI wiring

    @Test("ci.yml invokes the perf-budgets script as a step")
    func ciYmlInvokesPerfBudgetsScript() throws {
        let yml = try Self.loadText(".github/workflows/ci.yml")
        #expect(
            yml.contains("./scripts/check-perf-budgets.sh"),
            ".github/workflows/ci.yml must run scripts/check-perf-budgets.sh — otherwise Wave 2.5 ships without enforcement"
        )
    }

    // MARK: - tiny TOML reader

    /// A minimal table-of-tables TOML reader sufficient for
    /// `docs/perf-budgets.toml`. No nested tables, no array values, no
    /// multi-line strings — that file is intentionally flat so the bash
    /// parser can read it without dependencies, and the Swift guard
    /// matches that constraint.
    ///
    /// Returns `[section: [key: rawValue]]` with values stripped of
    /// surrounding quotes and trailing comments.
    private static func parseSimpleToml(_ source: String) throws -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]
        var current: String? = nil
        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = String(rawLine)
            if let hashIdx = line.firstIndex(of: "#") {
                line = String(line[..<hashIdx])
            }
            line = line.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                let inner = line.dropFirst().dropLast()
                current = String(inner).trimmingCharacters(in: .whitespaces)
                if let c = current, result[c] == nil { result[c] = [:] }
                continue
            }

            guard let section = current else { continue }
            guard let eqIdx = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eqIdx]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            result[section, default: [:]][key] = value
        }
        return result
    }
}
