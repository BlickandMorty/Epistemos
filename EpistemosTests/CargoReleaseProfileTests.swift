import Foundation
import Testing

/// Source-guard for the canonical Cargo release profile applied in
/// Wave 2.4 of the Extended Program Plan
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md`,
///  cross-refs `docs/EPISTEMOS_DETERMINISTIC_PERF_PLAN.md` §1.1 Task 0.4).
///
/// The canonical block tightens link-time optimisation, single-codegen-unit
/// builds, symbol stripping, opt-level 3, and disables overflow checks
/// across every Rust crate in the workspace.
///
/// The crates that own `std::panic::catch_unwind` FFI macros MUST also
/// keep `panic = "unwind"` so the macros remain functional; the others
/// MAY use `panic = "abort"` for the smallest dylib footprint.
///
/// This test reads the live `Cargo.toml` files via `#filePath` (same
/// pattern as `SigTests.sigSourceFileExistsAndHasCanonicalCategories`)
/// rather than depending on a `SourceMirror` bundle, so any new crate
/// whose Cargo.toml drifts from the canonical block fails CI immediately
/// — no manual mirror refresh required.
@Suite("Cargo Release Profile (Wave 2.4)")
nonisolated struct CargoReleaseProfileTests {
    /// Crates whose FFI surface relies on `std::panic::catch_unwind`
    /// (directly or via the `ffi_catch_unwind!` / `syntax_catch!` macros)
    /// and therefore MUST stay on `panic = "unwind"`.
    ///
    /// Keep this list in sync with the audit table in dpp §1.1 Task 0.4.
    static let unwindCrates: [String] = [
        "agent_core",
        "graph-engine",
        "omega-ax",
        "syntax-core",
    ]

    /// Crates that have no `catch_unwind` site in their source tree and
    /// MAY use `panic = "abort"` for a smaller dylib (no unwind tables).
    static let abortCrates: [String] = [
        "epistemos-core",
        "omega-mcp",
        "substrate-core",
    ]

    // MARK: - Repo-relative file resolution

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // EpistemosTests/
            .deletingLastPathComponent() // repo root
    }

    private static func cargoTomlURL(crate: String) -> URL {
        repoRoot()
            .appendingPathComponent(crate, isDirectory: true)
            .appendingPathComponent("Cargo.toml", isDirectory: false)
    }

    private static func loadCargoToml(crate: String) throws -> String {
        try String(contentsOf: cargoTomlURL(crate: crate), encoding: .utf8)
    }

    /// TOML comments routinely reference the *forbidden* alternative
    /// (e.g. agent_core's SAFETY block explains why `panic = "abort"`
    /// would break `catch_unwind`). Negative assertions like
    /// `!cargo.contains("panic = \"abort\"")` would false-positive on
    /// those comments, so we strip comment tails before asserting
    /// absence. The TOML spec treats `#` as the line-comment marker.
    private static func stripTomlComments(_ source: String) -> String {
        source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                guard let hashIndex = line.firstIndex(of: "#") else {
                    return String(line)
                }
                return String(line[..<hashIndex])
            }
            .joined(separator: "\n")
    }

    // MARK: - Tests

    @Test("every crate ships the canonical release profile fields")
    func everyCrateHasCanonicalReleaseProfile() throws {
        for crate in Self.unwindCrates + Self.abortCrates {
            let cargo = try Self.loadCargoToml(crate: crate)
            let code = Self.stripTomlComments(cargo)
            #expect(
                code.contains("[profile.release]"),
                "\(crate)/Cargo.toml must declare a [profile.release] section"
            )
            #expect(
                code.contains("lto = \"fat\""),
                "\(crate)/Cargo.toml must set lto = \"fat\""
            )
            #expect(
                code.contains("codegen-units = 1"),
                "\(crate)/Cargo.toml must set codegen-units = 1"
            )
            #expect(
                code.contains("strip = \"symbols\""),
                "\(crate)/Cargo.toml must set strip = \"symbols\""
            )
            #expect(
                code.contains("opt-level = 3"),
                "\(crate)/Cargo.toml must set opt-level = 3"
            )
            #expect(
                code.contains("overflow-checks = false"),
                "\(crate)/Cargo.toml must set overflow-checks = false"
            )
            #expect(
                code.contains("debug = false"),
                "\(crate)/Cargo.toml must set debug = false"
            )
            #expect(
                !code.contains("lto = \"thin\""),
                "\(crate)/Cargo.toml must not retain the legacy thin LTO setting"
            )
            #expect(
                !code.contains("opt-level = \"z\""),
                "\(crate)/Cargo.toml must not retain the legacy size-only opt-level"
            )
        }
    }

    @Test("crates with catch_unwind FFI keep panic = unwind")
    func unwindCratesPreservePanicUnwind() throws {
        for crate in Self.unwindCrates {
            let cargo = try Self.loadCargoToml(crate: crate)
            let code = Self.stripTomlComments(cargo)
            #expect(
                code.contains("panic = \"unwind\""),
                "\(crate)/Cargo.toml must keep panic = \"unwind\" — its FFI macros call std::panic::catch_unwind"
            )
            #expect(
                !code.contains("panic = \"abort\""),
                "\(crate)/Cargo.toml must NOT use panic = \"abort\" — it would make catch_unwind a no-op"
            )
        }
    }

    @Test("crates without catch_unwind take panic = abort for smaller dylibs")
    func abortCratesUsePanicAbort() throws {
        for crate in Self.abortCrates {
            let cargo = try Self.loadCargoToml(crate: crate)
            let code = Self.stripTomlComments(cargo)
            #expect(
                code.contains("panic = \"abort\""),
                "\(crate)/Cargo.toml may use panic = \"abort\" — confirm it has no catch_unwind sites"
            )
            #expect(
                !code.contains("panic = \"unwind\""),
                "\(crate)/Cargo.toml is on the abort list — must not also declare panic = \"unwind\""
            )
        }
    }

    /// Audit guard: prove the unwind/abort split is grounded in source.
    /// Walks each crate's `src/` tree for textual `catch_unwind` references
    /// and asserts the crate landed on the correct list.
    ///
    /// Why a textual scan is enough: the macros that own catch_unwind
    /// (`ffi_catch_unwind!`, `syntax_catch!`) all expand to a call that
    /// contains the literal token `catch_unwind`, so a grep-style scan
    /// catches both raw and macro-wrapped sites.
    @Test("catch_unwind site audit matches the unwind/abort split")
    func catchUnwindAuditMatchesSplit() throws {
        let fm = FileManager.default
        let root = Self.repoRoot()

        for crate in Self.unwindCrates {
            let srcURL = root.appendingPathComponent(crate, isDirectory: true)
                .appendingPathComponent("src", isDirectory: true)
            let found = try Self.scanForToken("catch_unwind", under: srcURL, fileManager: fm)
            #expect(
                found,
                "\(crate) is on unwindCrates but contains no `catch_unwind` reference under src/ — re-evaluate the split"
            )
        }

        for crate in Self.abortCrates {
            let srcURL = root.appendingPathComponent(crate, isDirectory: true)
                .appendingPathComponent("src", isDirectory: true)
            // abort crates may not have a src/ at all (they could be pure
            // re-exports); only enforce when the directory exists.
            guard fm.fileExists(atPath: srcURL.path) else { continue }
            let found = try Self.scanForToken("catch_unwind", under: srcURL, fileManager: fm)
            #expect(
                !found,
                "\(crate) is on abortCrates but contains a `catch_unwind` reference under src/ — must move to unwindCrates"
            )
        }
    }

    private static func scanForToken(
        _ token: String,
        under directory: URL,
        fileManager: FileManager
    ) throws -> Bool {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }
        while let item = enumerator.nextObject() as? URL {
            guard item.pathExtension == "rs" else { continue }
            let text = try String(contentsOf: item, encoding: .utf8)
            if text.contains(token) { return true }
        }
        return false
    }
}
