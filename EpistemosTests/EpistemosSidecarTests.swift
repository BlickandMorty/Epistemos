import Foundation
import Testing

@testable import Epistemos

/// Wave 13 / Phase 12 source-guard for the JSON sidecar layer.
@Suite("EpistemosSidecar (Phase 12)")
nonisolated struct EpistemosSidecarTests {

    private static func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sidecar-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: true
        )
        return url
    }

    // MARK: - Code-file exclusion (master plan §12 safety constraint)

    @Test("Source files (.swift, .rs, .py, .json, .ts) are NEVER eligible for sidecars")
    func codeFilesAreIneligible() {
        for ext in ["swift", "rs", "py", "json", "ts", "tsx", "js", "jsx",
                    "go", "java", "kt", "c", "cpp", "h", "hpp", "metal",
                    "yaml", "toml", "lock", "sh", "ps1", "pbxproj"] {
            let url = URL(fileURLWithPath: "/tmp/example.\(ext)")
            #expect(
                !EpistemosSidecarPolicy.isEligible(url),
                ".\(ext) files must NEVER be sidecar-eligible (would corrupt source)"
            )
        }
    }

    @Test("Markdown / text files are eligible")
    func markdownFilesAreEligible() {
        for ext in ["md", "markdown", "txt", "rst", "org"] {
            let url = URL(fileURLWithPath: "/tmp/note.\(ext)")
            #expect(
                EpistemosSidecarPolicy.isEligible(url),
                ".\(ext) should be sidecar-eligible"
            )
        }
    }

    @Test("Files inside .git, build, target, node_modules etc. are ineligible")
    func excludedDirectoriesAreIneligible() {
        for segment in [".git", ".build", "build", "DerivedData",
                        "target", "node_modules", "__pycache__", ".swiftpm"] {
            let url = URL(fileURLWithPath: "/tmp/\(segment)/note.md")
            #expect(
                !EpistemosSidecarPolicy.isEligible(url),
                "files under /\(segment)/ must be excluded even if extension is .md"
            )
        }
    }

    // MARK: - Sidecar URL conventions

    @Test("Sidecar URL is <stem>.epistemos.json next to the source")
    func sidecarURLConvention() {
        let source = URL(fileURLWithPath: "/tmp/notes/daily-2026-04-26.md")
        let sidecar = EpistemosSidecarStore.sidecarURL(for: source)
        #expect(sidecar?.lastPathComponent == "daily-2026-04-26.epistemos.json")
        #expect(sidecar?.deletingLastPathComponent().path == "/tmp/notes")
    }

    @Test("Sidecar URL is nil for ineligible source files")
    func sidecarURLNilForCodeFiles() {
        let source = URL(fileURLWithPath: "/tmp/MyApp.swift")
        #expect(EpistemosSidecarStore.sidecarURL(for: source) == nil)
    }

    // MARK: - Read / write round-trip

    @Test("Mint stub → write → read round-trips byte-for-byte equal")
    func roundTrip() throws {
        let dir = try Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("first.md")
        try "# Hello".write(to: source, atomically: true, encoding: .utf8)

        var sidecar = EpistemosSidecarStore.mintStub(for: source, depth: .synthesized)
        sidecar.parentDomain = "neuroscience"
        sidecar.cognitiveMeta.classificationConfidence = 0.86
        sidecar.annotations.append(Annotation(
            at: "2026-04-26T10:30:00Z",
            author: "afm",
            body: "auto-classified as neuroscience > basal-ganglia"
        ))

        try EpistemosSidecarStore.write(sidecar, for: source)
        let restored = try EpistemosSidecarStore.read(for: source)
        #expect(restored == sidecar)
    }

    @Test("Mint stub → schemaVersion = 0 (unenriched marker)")
    func mintedStubHasSchemaZero() {
        let source = URL(fileURLWithPath: "/tmp/note.md")
        let sidecar = EpistemosSidecarStore.mintStub(for: source)
        #expect(sidecar.schemaVersion == 0,
                "fresh stubs MUST be schemaVersion 0 so the classifier knows to enrich them")
        #expect(sidecar.entityId.count == 26,
                "ULID is 26 chars (10 time + 16 random) Crockford base32")
    }

    @Test("Read returns nil when sidecar file does not yet exist")
    func readReturnsNilWhenAbsent() throws {
        let dir = try Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("ungenerated.md")
        try "body".write(to: source, atomically: true, encoding: .utf8)
        let sidecar = try EpistemosSidecarStore.read(for: source)
        #expect(sidecar == nil)
    }

    @Test("Write to an ineligible source throws ineligibleSource")
    func writeRejectsIneligibleSource() {
        let stub = EpistemosSidecar(entityId: "01HMV5DUMMY00000000000000A", depth: .surface)
        let source = URL(fileURLWithPath: "/tmp/MyApp.swift")
        do {
            try EpistemosSidecarStore.write(stub, for: source)
            #expect(Bool(false), "should have thrown ineligibleSource")
        } catch EpistemosSidecarStore.SidecarError.ineligibleSource {
            // expected
        } catch {
            #expect(Bool(false), "wrong error: \(error)")
        }
    }

    // MARK: - Schema-version bump survives forward-compat

    @Test("Sidecar with current schemaVersion decodes cleanly")
    func currentSchemaDecodes() throws {
        let dir = try Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("doc.md")
        try "body".write(to: source, atomically: true, encoding: .utf8)
        let sidecar = EpistemosSidecar(
            schemaVersion: EpistemosSidecar.currentSchemaVersion,
            entityId: "01HMV5TESTSCHEMACURRENT0001",
            depth: .coreBelief
        )
        try EpistemosSidecarStore.write(sidecar, for: source)
        let restored = try EpistemosSidecarStore.read(for: source)
        #expect(restored?.schemaVersion == EpistemosSidecar.currentSchemaVersion)
        #expect(restored?.depth == .coreBelief)
    }
}
