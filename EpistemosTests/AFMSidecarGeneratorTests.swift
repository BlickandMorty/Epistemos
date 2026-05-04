import Darwin
import Foundation
import Testing
@testable import Epistemos

@Suite("AFM Sidecar Generator")
@MainActor
struct AFMSidecarGeneratorTests {
    @Test("Persisted generated payload writes sidecar fields and model-derived xattr")
    func persistedPayloadWritesSidecarFieldsAndXattr() throws {
        let dir = try Self.tempDirectory(named: "afm-sidecar")
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("dopamine-notes.md")
        try "Dopamine prediction errors shape habit learning.".write(
            to: source,
            atomically: true,
            encoding: .utf8
        )

        try AFMSidecarGenerator.persist(
            payload: AFMSidecarGeneratedPayload(
                summary: "Dopamine prediction errors connect habit learning to basal ganglia loops.",
                tags: ["Neuroscience", "basal-ganglia", "neuroscience"],
                entities: ["Dopamine", "Basal Ganglia"],
                suggestedLinks: [
                    AFMSidecarGeneratedLink(
                        targetId: "note-related",
                        title: "Habit Loops",
                        reason: "Both notes discuss reinforcement learning."
                    ),
                ]
            ),
            for: source
        )

        let restored = try EpistemosSidecarStore.read(for: source)
        let sidecar = try #require(restored)
        #expect(sidecar.schemaVersion == EpistemosSidecar.currentSchemaVersion)
        #expect(sidecar.summary?.contains("Dopamine prediction errors") == true)
        #expect(sidecar.tags == ["neuroscience", "basal-ganglia"])
        #expect(sidecar.entities == ["Dopamine", "Basal Ganglia"])
        #expect(sidecar.suggestedLinks?.first?.targetId == "note-related")
        let sidecarURL = try #require(EpistemosSidecarStore.sidecarURL(for: source))
        #expect(Self.modelDerivedXAttrValue(for: sidecarURL) == "true")
    }

    @Test("Persisted generated payload preserves existing ontology fields")
    func persistedPayloadPreservesExistingOntologyFields() throws {
        let dir = try Self.tempDirectory(named: "afm-sidecar-preserve")
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("compiler-notes.md")
        try "Parser combinators and type inference notes.".write(
            to: source,
            atomically: true,
            encoding: .utf8
        )
        var existing = EpistemosSidecarStore.mintStub(for: source, depth: .coreBelief)
        existing.schemaVersion = EpistemosSidecar.currentSchemaVersion
        existing.parentDomain = "compilers"
        existing.childConcept = "type-inference"
        try EpistemosSidecarStore.write(existing, for: source, modelDerived: true)

        try AFMSidecarGenerator.persist(
            payload: AFMSidecarGeneratedPayload(
                summary: "Compiler notes about parser combinators and type inference.",
                tags: ["compilers"],
                entities: ["Parser Combinators"],
                suggestedLinks: []
            ),
            for: source
        )

        let restored = try EpistemosSidecarStore.read(for: source)
        let sidecar = try #require(restored)
        #expect(sidecar.parentDomain == "compilers")
        #expect(sidecar.childConcept == "type-inference")
        #expect(sidecar.depth == .coreBelief)
        #expect(sidecar.summary == "Compiler notes about parser combinators and type inference.")
    }

    @Test("Generated payload refuses source-code files")
    func generatedPayloadRefusesSourceCodeFiles() throws {
        let dir = try Self.tempDirectory(named: "afm-sidecar-source")
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("Plugin.swift")
        try "struct Plugin {}".write(to: source, atomically: true, encoding: .utf8)

        do {
            try AFMSidecarGenerator.persist(
                payload: AFMSidecarGeneratedPayload(
                    summary: "Should not write.",
                    tags: ["code"],
                    entities: [],
                    suggestedLinks: []
                ),
                for: source
            )
            #expect(Bool(false), "Expected source-code sidecar generation to throw")
        } catch EpistemosSidecarStore.SidecarError.ineligibleSource(_) {
            #expect(EpistemosSidecarStore.sidecarURL(for: source) == nil)
        }
    }

    private static func tempDirectory(named prefix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func modelDerivedXAttrValue(for url: URL) -> String? {
        let attribute = EpistemosSidecarStore.modelDerivedAttributeName
        let size = url.path.withCString { path in
            attribute.withCString { name in
                getxattr(path, name, nil, 0, 0, 0)
            }
        }
        guard size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        let capacity = buffer.count
        let read = url.path.withCString { path in
            attribute.withCString { name in
                buffer.withUnsafeMutableBytes { rawBuffer in
                    getxattr(path, name, rawBuffer.baseAddress, capacity, 0, 0)
                }
            }
        }
        guard read > 0 else { return nil }
        return String(decoding: buffer.prefix(read), as: UTF8.self)
    }
}
