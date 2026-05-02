import Foundation
import Darwin
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

    private static func xattrValue(_ name: String, for url: URL) -> String? {
        let size = url.path.withCString { path in
            name.withCString { attrName in
                getxattr(path, attrName, nil, 0, 0, 0)
            }
        }
        guard size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        let read = buffer.withUnsafeMutableBytes { rawBuffer in
            url.path.withCString { path in
                name.withCString { attrName in
                    getxattr(path, attrName, rawBuffer.baseAddress, rawBuffer.count, 0, 0)
                }
            }
        }
        guard read > 0 else { return nil }
        return String(decoding: buffer.prefix(read), as: UTF8.self)
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
        sidecar.childConcept = "basal-ganglia"
        sidecar.interpretationDirective = "Treat as a working hypothesis until confirmed by lab notes."
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

    @Test("Sidecar JSON encodes interpretation_directive as an additive machine-readable key")
    func interpretationDirectiveEncodesSnakeCase() throws {
        let sidecar = EpistemosSidecar(
            entityId: "01HMV5TESTDIRECTIVE000000001",
            depth: .synthesized,
            interpretationDirective: "Use as a model-facing summary, not a replacement for Markdown."
        )
        let encoded = try JSONEncoder().encode(sidecar)
        let text = try #require(String(data: encoded, encoding: .utf8))
        #expect(text.contains("\"interpretation_directive\""))
        #expect(!text.contains("interpretationDirective"))
    }

    @Test("Schema v3 is current but v2 sidecars without interpretation_directive still decode")
    func v2SidecarsDecodeWithoutInterpretationDirective() throws {
        #expect(EpistemosSidecar.currentSchemaVersion == 3)
        let json = """
        {
          "annotations": [],
          "cognitive_meta": {
            "access_count": 0
          },
          "depth": "surface",
          "derived_from": [],
          "entity_id": "01HMV5TESTV2COMPAT00000001",
          "schema_version": 2
        }
        """
        let decoded = try JSONDecoder().decode(
            EpistemosSidecar.self,
            from: Data(json.utf8)
        )
        #expect(decoded.schemaVersion == 2)
        #expect(decoded.interpretationDirective == nil)
    }

    @Test("Generic sidecar writes are not marked model-derived")
    func genericWriteDoesNotMarkModelDerived() throws {
        let dir = try Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("human-note.md")
        try "body".write(to: source, atomically: true, encoding: .utf8)
        let sidecar = EpistemosSidecarStore.mintStub(for: source)

        try EpistemosSidecarStore.write(sidecar, for: source)
        let sidecarURL = try #require(EpistemosSidecarStore.sidecarURL(for: source))
        #expect(Self.xattrValue(EpistemosSidecarStore.modelDerivedAttributeName, for: sidecarURL) == nil)
    }

    @Test("Model-derived sidecar writes are xattr-marked for audit visibility")
    func modelDerivedWriteMarksXattr() throws {
        let dir = try Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("afm-note.md")
        try "body".write(to: source, atomically: true, encoding: .utf8)
        let sidecar = EpistemosSidecarStore.mintStub(for: source)

        try EpistemosSidecarStore.write(sidecar, for: source, modelDerived: true)
        let sidecarURL = try #require(EpistemosSidecarStore.sidecarURL(for: source))
        #expect(Self.xattrValue(EpistemosSidecarStore.modelDerivedAttributeName, for: sidecarURL) == "true")
    }

    @Test("Model-derived detector reports only explicit AFM sidecar xattrs")
    func modelDerivedDetectorReportsOnlyExplicitXattrs() throws {
        let dir = try Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let humanSource = dir.appendingPathComponent("human-note.md")
        try "human".write(to: humanSource, atomically: true, encoding: .utf8)
        try EpistemosSidecarStore.write(
            EpistemosSidecarStore.mintStub(for: humanSource),
            for: humanSource
        )

        let afmSource = dir.appendingPathComponent("afm-note.md")
        try "afm".write(to: afmSource, atomically: true, encoding: .utf8)
        try EpistemosSidecarStore.write(
            EpistemosSidecarStore.mintStub(for: afmSource),
            for: afmSource,
            modelDerived: true
        )

        #expect(!EpistemosSidecarStore.isModelDerived(for: humanSource))
        #expect(EpistemosSidecarStore.isModelDerived(for: afmSource))
    }

    @Test("Model-derived detector fails closed for missing or ineligible sidecars")
    func modelDerivedDetectorFailsClosedForMissingOrIneligibleSidecars() throws {
        let dir = try Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let missingSidecarSource = dir.appendingPathComponent("draft-note.md")
        try "draft".write(to: missingSidecarSource, atomically: true, encoding: .utf8)
        let ineligibleSource = dir.appendingPathComponent("Plugin.swift")
        try "struct Plugin {}".write(to: ineligibleSource, atomically: true, encoding: .utf8)

        #expect(!EpistemosSidecarStore.isModelDerived(for: missingSidecarSource))
        #expect(!EpistemosSidecarStore.isModelDerived(for: ineligibleSource))
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

    // MARK: - Cache / prefetch bounds

    @Test("prefetchAll honors maxSidecars and warms only bounded cache entries")
    func prefetchAllHonorsMaxSidecars() async throws {
        let dir = try Self.tempDir()
        defer {
            SidecarCache.shared.reset()
            try? FileManager.default.removeItem(at: dir)
        }

        for i in 0..<5 {
            let source = dir.appendingPathComponent("note-\(i).md")
            try "body \(i)".write(to: source, atomically: true, encoding: .utf8)
            let sidecar = EpistemosSidecarStore.mintStub(for: source)
            try EpistemosSidecarStore.write(sidecar, for: source)
        }

        SidecarCache.shared.reset()
        let warmed = await EpistemosSidecarStore.prefetchAll(under: dir, maxSidecars: 2)

        #expect(warmed == 2, "prefetchAll must not warm more than the requested bound")
        #expect(SidecarCache.shared.count == 2, "SidecarCache should contain only the bounded warmed entries")
    }

    @Test("prefetchAll with zero max sidecars is a no-op")
    func prefetchAllZeroLimitIsNoOp() async throws {
        let dir = try Self.tempDir()
        defer {
            SidecarCache.shared.reset()
            try? FileManager.default.removeItem(at: dir)
        }
        let source = dir.appendingPathComponent("note.md")
        try "body".write(to: source, atomically: true, encoding: .utf8)
        try EpistemosSidecarStore.write(EpistemosSidecarStore.mintStub(for: source), for: source)

        SidecarCache.shared.reset()
        let warmed = await EpistemosSidecarStore.prefetchAll(under: dir, maxSidecars: 0)

        #expect(warmed == 0)
        #expect(SidecarCache.shared.count == 0)
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
