import Foundation
import Testing

/// Source-guard for the Wave 2.6 morning-session bench
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md`,
///  cross-ref dpp §1.1 Task 0.6).
///
/// The bench is a Rust binary in `bench/` that writes runtime measurements
/// to `build/perf-budgets-runtime.json` for the Wave 2.5 perf-budgets gate
/// to consume. Three artefacts MUST stay in lock-step:
///
///   1. `bench/Cargo.toml`               — declares the bench crate
///   2. `bench/src/morning_session.rs`   — emits all 4 canonical metric keys
///   3. `scripts/run-morning-session.sh` — wrapper used by CI
///   4. `.github/workflows/ci.yml`       — invokes the wrapper before perf gate
///
/// Drift in any of those silently disables runtime budget enforcement,
/// so this test reads each file via `#filePath` and asserts the
/// canonical wiring is present.
@Suite("Morning Session Bench (Wave 2.6)")
nonisolated struct MorningSessionBenchTests {

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // EpistemosTests/
            .deletingLastPathComponent() // repo root
    }

    private static func loadText(_ relative: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relative, isDirectory: false)
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - bench/Cargo.toml

    @Test("bench/Cargo.toml declares the morning-session bin and depends on omega-mcp")
    func benchManifestIsCanonical() throws {
        let cargo = try Self.loadText("bench/Cargo.toml")
        #expect(cargo.contains("name = \"epistemos-bench\""),
                "bench/Cargo.toml must declare package name 'epistemos-bench'")
        #expect(cargo.contains("name = \"morning-session\""),
                "bench/Cargo.toml must declare a [[bin]] named 'morning-session'")
        #expect(cargo.contains("path = \"src/morning_session.rs\""),
                "bench/Cargo.toml must point the morning-session bin at src/morning_session.rs")
        #expect(cargo.contains("omega-mcp = { path = \"../omega-mcp\" }"),
                "bench/Cargo.toml must depend on the local omega-mcp crate (path dep)")
    }

    // MARK: - bench/src/morning_session.rs

    @Test("morning_session.rs writes all 4 canonical runtime metric keys")
    func benchEmitsAllCanonicalMetricKeys() throws {
        let source = try Self.loadText("bench/src/morning_session.rs")
        // The Rust binary serialises a struct with these field names —
        // serde renames are not used, so the JSON keys equal the field names.
        for key in [
            "cold_start_ms_p99",
            "frame_ms_p99",
            "mcp_invoke_ms_p99",
            "ffi_hot_path_us_p99",
        ] {
            #expect(source.contains(key),
                    "bench/src/morning_session.rs must emit the canonical runtime key '\(key)' (consumed by check-perf-budgets.sh)")
        }
    }

    @Test("morning_session.rs writes to build/perf-budgets-runtime.json")
    func benchWritesToCanonicalPath() throws {
        let source = try Self.loadText("bench/src/morning_session.rs")
        #expect(source.contains("perf-budgets-runtime.json"),
                "bench/src/morning_session.rs must write 'perf-budgets-runtime.json' (the path expected by docs/perf-budgets.toml [meta].runtime_results_path)")
        #expect(source.contains("env!(\"CARGO_MANIFEST_DIR\")"),
                "bench/src/morning_session.rs must resolve the output path via env!(CARGO_MANIFEST_DIR) so an already-built binary writes to the repo root, not cwd")
    }

    // MARK: - scripts/run-morning-session.sh

    @Test("run-morning-session.sh exists, is executable, and builds the bench")
    func wrapperScriptIsCanonical() throws {
        let url = Self.repoRoot()
            .appendingPathComponent("scripts", isDirectory: true)
            .appendingPathComponent("run-morning-session.sh", isDirectory: false)
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: url.path),
                "scripts/run-morning-session.sh must exist (Wave 2.6 wrapper)")
        let attrs = try fm.attributesOfItem(atPath: url.path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        #expect((perms & 0o111) != 0,
                "scripts/run-morning-session.sh must be executable (chmod +x)")

        let script = try String(contentsOf: url, encoding: .utf8)
        #expect(script.contains("cargo build --release") && script.contains("--bin morning-session"),
                "scripts/run-morning-session.sh must build the morning-session bin in release mode")
        #expect(script.contains("perf-budgets-runtime.json"),
                "scripts/run-morning-session.sh must reference the canonical output filename")
    }

    // MARK: - CI wiring

    @Test("ci.yml invokes the morning-session wrapper before the perf-budgets check")
    func ciYmlInvokesWrapperBeforeGate() throws {
        let yml = try Self.loadText(".github/workflows/ci.yml")
        #expect(
            yml.contains("./scripts/run-morning-session.sh"),
            ".github/workflows/ci.yml must invoke scripts/run-morning-session.sh as a step"
        )

        // The runner must come BEFORE the gate; otherwise the gate gracefully
        // skips runtime budgets and the bench's measurements never matter.
        let runner = "./scripts/run-morning-session.sh"
        let gate = "./scripts/check-perf-budgets.sh"
        guard let runnerRange = yml.range(of: runner),
              let gateRange = yml.range(of: gate) else {
            #expect(Bool(false), "ci.yml must reference both wrapper and gate steps")
            return
        }
        #expect(runnerRange.lowerBound < gateRange.lowerBound,
                "ci.yml must invoke run-morning-session.sh BEFORE check-perf-budgets.sh — otherwise runtime budgets are reported as 'no measurement yet'")
    }

    // MARK: - omega-mcp rlib output

    @Test("omega-mcp ships rlib so the bench can depend on it")
    func omegaMcpExportsRlib() throws {
        let cargo = try Self.loadText("omega-mcp/Cargo.toml")
        #expect(cargo.contains("\"rlib\""),
                "omega-mcp/Cargo.toml must include 'rlib' in [lib].crate-type — required for bench/ path dep (Wave 2.6)")
    }
}
