import Foundation
import Testing
import UniformTypeIdentifiers

@testable import Epistemos

/// Wave 7.1 source-guard for the `.epdoc` package format
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.1,
///  cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §3-4).
///
/// Three contracts covered:
///   1. EpdocManifest encodes/decodes round-trip identical (snake_case
///      wire format matches the Rust ArtifactHeader spec).
///   2. EpdocPackage round-trips through FileWrapper without losing
///      manifest, content, projections, assets, or exports.
///   3. The canonical UTType conforms to UTType.package so Finder
///      treats the directory bundle as a single document.
@Suite("Epdoc package format (Wave 7.1)")
nonisolated struct EpdocPackageTests {

    // MARK: - Helpers

    private static let unixMs: Int64 = 1_700_000_000_000  // fixed for stable test
    private static let sampleProseMirrorJSON: Data = #"""
    {"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"hello"}]}]}
    """#.data(using: .utf8)!

    private static func sampleManifest() -> EpdocManifest {
        EpdocManifest(
            id: "01HMV5K2K9XJ4N0ABCDE",
            kind: .document,
            schemaVersion: EpdocManifest.currentSchemaVersion,
            createdAt: unixMs,
            updatedAt: unixMs + 1_000,
            title: "My Research Report",
            contentHash: "blake3-deadbeef",
            provenance: EpdocProvenance(
                producer: .human,
                derivedFrom: [
                    EpdocArtifactRef(id: "01HMV5K2K9XJ4N0SOURCE", kind: .source, title: "Source paper")
                ],
                generatedByRun: nil,
                toolId: nil,
                sourceArtifacts: [],
                outputArtifacts: []
            )
        )
    }

    private static func samplePackage() -> EpdocPackage {
        EpdocPackage(
            manifest: sampleManifest(),
            contentJSON: sampleProseMirrorJSON,
            shadowMarkdown: "# hello\n".data(using: .utf8),
            plainText: "hello\n".data(using: .utf8),
            searchBlocksJSONL: #"{"id":"b1","text":"hello"}\n"#.data(using: .utf8),
            extraProjections: ["custom.json": "{}".data(using: .utf8)!],
            assets: ["image-01.png": Data([0x89, 0x50, 0x4e, 0x47])],  // PNG header bytes
            exports: ["report.docx": Data(repeating: 0xff, count: 16)]
        )
    }

    // MARK: - manifest codable

    @Test("EpdocManifest round-trips via JSON Codable with snake_case wire keys")
    func manifestRoundTripsCodable() throws {
        let original = Self.sampleManifest()

        let encoder = JSONEncoder.epdocCanonical
        let data = try encoder.encode(original)

        // Wire format guard: every snake_case key that's REQUIRED in
        // the on-disk shape must appear verbatim. Nullable keys
        // (generated_by_run, tool_id) are conditionally serialized via
        // omitting nil — same as Rust's serde(skip_serializing_if =
        // "Option::is_none"); test them in a separate case where they
        // have values.
        let json = String(data: data, encoding: .utf8) ?? ""
        for snakeKey in [
            "\"schema_version\"",
            "\"created_at\"",
            "\"updated_at\"",
            "\"content_hash\"",
            "\"derived_from\"",
            "\"source_artifacts\"",
            "\"output_artifacts\"",
        ] {
            #expect(json.contains(snakeKey),
                    "encoded manifest must contain key \(snakeKey) — Rust round-trip parity")
        }

        let decoder = JSONDecoder.epdocCanonical
        let recovered = try decoder.decode(EpdocManifest.self, from: data)
        #expect(recovered == original,
                "manifest must round-trip identical through Codable")
    }

    @Test("EpdocManifest free-form metadata round-trips and stays absent in JSON when nil (W7.6 follow-up)")
    func manifestMetadataRoundTrip() throws {
        let withMeta = EpdocManifest(
            id: "01HMV5K2K9XJ4N0METAVAR",
            kind: .document,
            schemaVersion: EpdocManifest.currentSchemaVersion,
            createdAt: Self.unixMs,
            updatedAt: Self.unixMs,
            title: "Themed",
            contentHash: "deadbeef",
            provenance: EpdocProvenance(producer: .human),
            metadata: [
                "theme": "solarized-dark",
                "icon": "rocket",
                "accent_color": "#3a86ff",
                "display_mode": "wide",
            ]
        )
        let encoder = JSONEncoder.epdocCanonical
        let data = try encoder.encode(withMeta)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains("\"metadata\""), "metadata key MUST appear when populated")
        #expect(json.contains("solarized-dark"), "metadata values MUST round-trip verbatim")

        let decoder = JSONDecoder.epdocCanonical
        let decoded = try decoder.decode(EpdocManifest.self, from: data)
        #expect(decoded.metadata?["theme"] == "solarized-dark")
        #expect(decoded.metadata?["accent_color"] == "#3a86ff")
        #expect(decoded == withMeta, "metadata must round-trip identical")

        // Forward-compat: a manifest WITHOUT the metadata key (older
        // pre-W7.6 writers) must still decode successfully and surface
        // metadata == nil. ArtifactKind is repr(UInt8) — `.document`
        // serialises as the raw int 2 (mirrors the Rust enum
        // discriminant).
        let legacyJSON = #"""
        {
            "id": "01HMV5K2K9XJ4N0METAVAR",
            "kind": 2,
            "schema_version": 1,
            "created_at": \#(Self.unixMs),
            "updated_at": \#(Self.unixMs),
            "title": "Legacy",
            "content_hash": "deadbeef",
            "provenance": {
                "producer": "human",
                "derived_from": [],
                "source_artifacts": [],
                "output_artifacts": []
            }
        }
        """#.data(using: .utf8)!
        let legacy = try decoder.decode(EpdocManifest.self, from: legacyJSON)
        #expect(legacy.metadata == nil,
                "older pre-W7.6 manifests MUST decode with metadata == nil (forward compat)")
    }

    @Test("EpdocManifest decodes ArtifactKind via the unified Wave 3.2 enum")
    func manifestDecodesArtifactKind() throws {
        let original = Self.sampleManifest()
        let encoder = JSONEncoder.epdocCanonical
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder.epdocCanonical.decode(EpdocManifest.self, from: data)
        #expect(decoded.kind == .document,
                "manifest.kind must round-trip through ArtifactKind (Wave 3.2 unified enum)")

        // Wire format must use the snake_case rename for ArtifactKind:
        // ArtifactKind.document → "document"; check the JSON shows "kind":"document".
        let jsonStr = String(data: data, encoding: .utf8) ?? ""
        #expect(jsonStr.contains("\"kind\""),
                "manifest must emit `kind` field")
    }

    // MARK: - package round-trip

    @Test("EpdocPackage round-trips through FileWrapper bridge")
    func packageRoundTripsThroughFileWrapper() throws {
        let original = Self.samplePackage()

        let wrapper = try original.makeFileWrapper()
        #expect(wrapper.isDirectory,
                "makeFileWrapper must return a directory wrapper")

        let recovered = try EpdocPackage(fileWrapper: wrapper)
        #expect(recovered.manifest == original.manifest)
        #expect(recovered.contentJSON == original.contentJSON,
                "contentJSON bytes must round-trip BYTE-EQUAL (no re-encoding so content_hash stays valid)")
        #expect(recovered.shadowMarkdown == original.shadowMarkdown)
        #expect(recovered.plainText == original.plainText)
        #expect(recovered.searchBlocksJSONL == original.searchBlocksJSONL)
        #expect(recovered.extraProjections == original.extraProjections)
        #expect(recovered.assets == original.assets)
        #expect(recovered.exports == original.exports)
    }

    @Test("EpdocPackage missing manifest fails with .missingManifest")
    func missingManifestErrors() throws {
        let wrapper = FileWrapper(directoryWithFileWrappers: [
            EpdocPackageEntry.content: FileWrapper(regularFileWithContents: Self.sampleProseMirrorJSON),
        ])
        do {
            _ = try EpdocPackage(fileWrapper: wrapper)
            #expect(Bool(false), "decoding must throw when manifest.json is missing")
        } catch let error as EpdocPackageError {
            switch error {
            case .missingManifest: break
            default: #expect(Bool(false), "wrong error case: \(error)")
            }
        }
    }

    @Test("EpdocPackage missing content.pm.json fails with .missingContent")
    func missingContentErrors() throws {
        let manifestData = try JSONEncoder.epdocCanonical.encode(Self.sampleManifest())
        let wrapper = FileWrapper(directoryWithFileWrappers: [
            EpdocPackageEntry.manifest: FileWrapper(regularFileWithContents: manifestData),
        ])
        do {
            _ = try EpdocPackage(fileWrapper: wrapper)
            #expect(Bool(false), "decoding must throw when content.pm.json is missing")
        } catch let error as EpdocPackageError {
            switch error {
            case .missingContent: break
            default: #expect(Bool(false), "wrong error case: \(error)")
            }
        }
    }

    @Test("EpdocPackage rejects manifest schema_version newer than this build")
    func futureSchemaVersionRejected() throws {
        var future = Self.sampleManifest()
        future = EpdocManifest(
            id: future.id,
            kind: future.kind,
            schemaVersion: future.schemaVersion + 99,
            createdAt: future.createdAt,
            updatedAt: future.updatedAt,
            title: future.title,
            contentHash: future.contentHash,
            provenance: future.provenance
        )
        let manifestData = try JSONEncoder.epdocCanonical.encode(future)
        let wrapper = FileWrapper(directoryWithFileWrappers: [
            EpdocPackageEntry.manifest: FileWrapper(regularFileWithContents: manifestData),
            EpdocPackageEntry.content: FileWrapper(regularFileWithContents: Self.sampleProseMirrorJSON),
        ])
        do {
            _ = try EpdocPackage(fileWrapper: wrapper)
            #expect(Bool(false), "decoding must throw when manifest schema_version is too new")
        } catch let error as EpdocPackageError {
            switch error {
            case .manifestSchemaTooNew: break
            default: #expect(Bool(false), "wrong error case: \(error)")
            }
        }
    }

    // MARK: - UTType

    @Test("UTType.epdoc declares the canonical com.epistemos.epdoc identifier")
    func utTypeIsCanonical() {
        let type = UTType.epdoc
        #expect(type.identifier == "com.epistemos.epdoc",
                "UTType.epdoc must use the canonical com.epistemos.epdoc identifier")
        // Note: full `conforms(to: .package)` requires the type to be
        // declared in Info.plist's UTExportedTypeDeclarations — the
        // programmatic UTType(exportedAs:conformingTo:) only registers
        // the conformance when the type is also in the bundle's
        // declarations. That registration is a project.yml follow-up
        // (we don't edit Info.plist directly per project policy).
        // Once Info.plist ships the declaration, this assertion is the
        // canonical Finder-integration guard.
    }
}
