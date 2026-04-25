import Foundation
import Testing

/// Source-guard for the Wave 2.2 Tools/Performance.instrpkg
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md`,
///  cross-ref dpp §1.1 Task 0.2).
///
/// The .instrpkg materialises the six OSSignposter categories declared
/// in Sig.swift (Wave 2.1) as Instruments.app tables. If the file
/// drifts out of sync with Sig.swift's category list, developers see
/// stale category names in Instruments — silent loss of observability.
///
/// This guard:
///   1. Confirms the file exists at the canonical path
///   2. Parses it as valid XML
///   3. Asserts every Sig category appears as an os-signpost-interval-schema
///   4. Asserts the canonical subsystem is referenced
///   5. Asserts every category from Sig.swift is mirrored here
///      (cross-checks both files via #filePath)
@Suite("Performance.instrpkg (Wave 2.2)")
nonisolated struct PerformanceInstrPkgTests {

    /// Sig.swift's six canonical OSSignposter categories. Mirror of
    /// `Epistemos/Telemetry/Sig.swift` — the test below confirms the
    /// mirror is exact.
    static let canonicalCategories: [String] = [
        "render", "mcp", "graph", "ffi", "storage", "inference",
    ]

    static let canonicalSubsystem = "io.epistemos.core"

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // EpistemosTests/
            .deletingLastPathComponent() // repo root
    }

    private static func loadText(_ relative: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relative, isDirectory: false)
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - file presence

    @Test("Performance.instrpkg exists at the canonical path")
    func instrPkgExists() {
        let url = Self.repoRoot()
            .appendingPathComponent("Tools", isDirectory: true)
            .appendingPathComponent("Performance.instrpkg", isDirectory: false)
        #expect(FileManager.default.fileExists(atPath: url.path),
                "Tools/Performance.instrpkg must exist (Wave 2.2 deliverable)")
    }

    // MARK: - XML well-formedness

    @Test("Performance.instrpkg parses as well-formed XML")
    func instrPkgIsWellFormedXML() throws {
        let url = Self.repoRoot()
            .appendingPathComponent("Tools", isDirectory: true)
            .appendingPathComponent("Performance.instrpkg", isDirectory: false)
        // Use xmllint via Process — fast, deterministic, and doesn't try
        // to resolve external entities the way XMLDocument can. xmllint
        // ships with macOS so this works on any developer machine and on
        // the macos-15 GitHub Actions runner.
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xmllint")
        proc.arguments = ["--noout", "--nonet", url.path]
        let stderr = Pipe()
        proc.standardError = stderr
        proc.standardOutput = Pipe()
        try proc.run()
        proc.waitUntilExit()
        let errData = (try? stderr.fileHandleForReading.readToEnd()) ?? Data()
        let errText = String(data: errData ?? Data(), encoding: .utf8) ?? ""
        #expect(proc.terminationStatus == 0,
                "Tools/Performance.instrpkg must parse as well-formed XML — xmllint exit \(proc.terminationStatus)\n\(errText)")
    }

    // MARK: - canonical surface

    @Test("Performance.instrpkg references the canonical subsystem")
    func instrPkgReferencesCanonicalSubsystem() throws {
        let xml = try Self.loadText("Tools/Performance.instrpkg")
        #expect(xml.contains("\"\(Self.canonicalSubsystem)\""),
                "Tools/Performance.instrpkg must reference subsystem \"\(Self.canonicalSubsystem)\" (matches Sig.swift)")
    }

    @Test("Performance.instrpkg declares an interval schema for every Sig category")
    func instrPkgCoversEverySigCategory() throws {
        let xml = try Self.loadText("Tools/Performance.instrpkg")
        for category in Self.canonicalCategories {
            #expect(xml.contains("\"\(category)\""),
                    "Tools/Performance.instrpkg must reference category \"\(category)\"")
            #expect(xml.contains("io.epistemos.core.\(category)-intervals"),
                    "Tools/Performance.instrpkg must declare an interval schema id 'io.epistemos.core.\(category)-intervals'")
        }
    }

    /// Cross-check: every category we expect here MUST be the same set
    /// Sig.swift declares. Drift in either direction (a Sig category
    /// without an instrpkg schema, or vice versa) breaks the test.
    @Test("Performance.instrpkg category list matches Sig.swift category list exactly")
    func instrPkgCategoriesMatchSigSwift() throws {
        let sigSource = try Self.loadText("Epistemos/Telemetry/Sig.swift")
        for category in Self.canonicalCategories {
            #expect(sigSource.contains("static let \(category)"),
                    "Sig.swift must declare canonical category '\(category)' — mirror of PerformanceInstrPkgTests.canonicalCategories")
        }
        // Also assert there is no EXTRA `static let X = OSSignposter(`
        // declaration in Sig.swift beyond our six. Cheap regex-y check
        // by counting OSSignposter inits.
        let signposterInitCount = sigSource.components(separatedBy: "OSSignposter(subsystem:").count - 1
        #expect(signposterInitCount == Self.canonicalCategories.count,
                "Sig.swift must declare exactly \(Self.canonicalCategories.count) OSSignposter instances; found \(signposterInitCount). Add the new category to Tools/Performance.instrpkg AND to PerformanceInstrPkgTests.canonicalCategories.")
    }
}

