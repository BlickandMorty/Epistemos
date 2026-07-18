import Foundation
import Dispatch
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
    /// This test uses bounded helper processes for file reads. The Xcode hosted
    /// app test runner can stall inside Foundation URL reads during this suite,
    /// and the release-audit gate needs a fast fail instead of a wedged proof.
@Suite("Cargo Release Profile (Wave 2.4)")
struct CargoReleaseProfileTests {
    /// Crates whose FFI surface relies on `std::panic::catch_unwind`
    /// (directly or via the `ffi_catch_unwind!` / `syntax_catch!` macros)
    /// and therefore MUST stay on `panic = "unwind"`.
    ///
    /// Keep this list in sync with the audit table in dpp §1.1 Task 0.4.
    static let unwindCrates: [String] = [
        "agent_core",
        "graph-engine",
        // "omega-ax" crate removed with cloud-only/Omega removal 2026-07-03
        "syntax-core",
        "substrate-rt",  // Wave 5: its C ABI wraps every entry in catch_unwind
        "epistemos-shadow",  // Wave 8: shadow_* C ABI wraps every entry in catch_unwind
        "epistemos-code-index",  // Wave 9.7: codeindex_* C ABI wraps every entry in catch_unwind
    ]

    /// Crates that have no `catch_unwind` site in their source tree and
    /// MAY use `panic = "abort"` for a smaller dylib (no unwind tables).
    static let abortCrates: [String] = [
        "epistemos-core",
        "omega-mcp",
        "substrate-core",
    ]

    private static func sourceURL(for relativePath: String) throws -> URL {
        let url = try sourceMirrorRootURL().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(
                .fileNoSuchFile,
                userInfo: [NSFilePathErrorKey: url.path]
            )
        }
        return url
    }

    private static func loadCargoToml(crate: String) throws -> String {
        try loadTextFile(at: sourceURL(for: "\(crate)/Cargo.toml"))
    }

    private static func sourceDirectoryExists(_ relativeDirectory: String) throws -> Bool {
        let srcURL = try sourceMirrorRootURL().appendingPathComponent(relativeDirectory)
        var isDirectory = ObjCBool(false)
        return FileManager.default.fileExists(atPath: srcURL.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
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
        for crate in Self.unwindCrates {
            let found = try Self.scanForToken("catch_unwind", under: "\(crate)/src")
            #expect(
                found,
                "\(crate) is on unwindCrates but contains no `catch_unwind` reference under src/ — re-evaluate the split"
            )
        }

        for crate in Self.abortCrates {
            // abort crates may not have a src/ at all (they could be pure
            // re-exports); only enforce when the directory exists.
            guard try Self.sourceDirectoryExists("\(crate)/src") else { continue }
            let found = try Self.scanForToken("catch_unwind", under: "\(crate)/src")
            #expect(
                !found,
                "\(crate) is on abortCrates but contains a `catch_unwind` reference under src/ — must move to unwindCrates"
            )
        }
    }

    private static func scanForToken(
        _ token: String,
        under relativeDirectory: String
    ) throws -> Bool {
        let root = try sourceURL(for: relativeDirectory)
        return try scanReleaseSourceForToken(root: root, token: token)
    }

    private static func loadTextFile(at url: URL) throws -> String {
        try runTool("/bin/cat", arguments: [url.path], timeoutSeconds: 5)
    }

    private static func scanReleaseSourceForToken(root: URL, token: String) throws -> Bool {
        let script = """
        import pathlib
        import sys

        root = pathlib.Path(sys.argv[1])
        token = sys.argv[2]

        def strip_test_modules(text):
            while True:
                cfg = text.find("#[cfg(test)]")
                if cfg < 0:
                    return text
                module = text.find("mod tests", cfg)
                if module < 0:
                    return text
                open_brace = text.find("{", module)
                if open_brace < 0:
                    return text
                depth = 0
                for index in range(open_brace, len(text)):
                    character = text[index]
                    if character == "{":
                        depth += 1
                    elif character == "}":
                        depth -= 1
                        if depth == 0:
                            text = text[:cfg] + text[index + 1:]
                            break
                else:
                    return text

        for path in sorted(root.rglob("*.rs")):
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                text = path.read_text(encoding="utf-8", errors="ignore")
            if token in strip_test_modules(text):
                print("1")
                sys.exit(0)
        print("0")
        """
        let output = try runTool(
            "/usr/bin/python3",
            arguments: ["-c", script, root.path, token],
            timeoutSeconds: 10
        )
        return output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }

    private static func runTool(
        _ executablePath: String,
        arguments: [String],
        timeoutSeconds: TimeInterval
    ) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        try process.run()

        guard semaphore.wait(timeout: .now() + timeoutSeconds) == .success else {
            process.terminate()
            throw ToolFailure.timedOut(executablePath, arguments)
        }

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: stdoutData, encoding: .utf8) ?? ""
        let error = String(data: stderrData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw ToolFailure.failed(
                executablePath,
                arguments,
                process.terminationStatus,
                error.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return output
    }

    private enum ToolFailure: Error, CustomStringConvertible {
        case timedOut(String, [String])
        case failed(String, [String], Int32, String)

        var description: String {
            switch self {
            case let .timedOut(executable, arguments):
                return "\(executable) timed out with arguments \(arguments)"
            case let .failed(executable, arguments, status, stderr):
                return "\(executable) failed with status \(status), arguments \(arguments), stderr: \(stderr)"
            }
        }
    }
}
