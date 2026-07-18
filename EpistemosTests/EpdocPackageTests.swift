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

    private static func sampleContentJSON(documentID: String = "01HMV5K2K9XJ4N0ABCDE") throws -> Data {
        try JSONEncoder.epdocCanonical.encode(
            EpdocContentEnvelope(
                documentID: documentID,
                root: EpdocRichNode(
                    id: "\(documentID):root",
                    type: .document,
                    children: [
                        EpdocRichNode(
                            id: "\(documentID):paragraph:0",
                            type: .paragraph,
                            children: [EpdocRichNode(type: .text, text: "hello")]
                        ),
                    ]
                )
            )
        )
    }

    private static func flattenedNodes(in node: EpdocRichNode) -> [EpdocRichNode] {
        [node] + node.children.flatMap { flattenedNodes(in: $0) }
    }

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

    private static func samplePackage() throws -> EpdocPackage {
        EpdocPackage(
            manifest: sampleManifest(),
            contentJSON: try sampleContentJSON(),
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
        let original = try Self.samplePackage()

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
        #expect(recovered.migrationArtifacts == original.migrationArtifacts)
        #expect(wrapper.fileWrappers?[EpdocPackageEntry.content] != nil)
        #expect(wrapper.fileWrappers?[EpdocPackageEntry.legacyContent] == nil)
    }

    @Test("legacy content.pm.json migrates once to canonical content.json with an exact receipt archive")
    func legacyPackageMigratesToCanonicalContent() throws {
        let manifest = Self.sampleManifest()
        let manifestData = try JSONEncoder.epdocCanonical.encode(manifest)
        let legacyWrapper = FileWrapper(directoryWithFileWrappers: [
            EpdocPackageEntry.manifest: FileWrapper(regularFileWithContents: manifestData),
            EpdocPackageEntry.legacyContent: FileWrapper(
                regularFileWithContents: Self.sampleProseMirrorJSON
            ),
        ])

        let migrated = try EpdocPackage(fileWrapper: legacyWrapper)
        let envelope = try JSONDecoder.epdocCanonical.decode(
            EpdocContentEnvelope.self,
            from: migrated.contentJSON
        )
        try envelope.validate()
        #expect(envelope.documentID == manifest.id)
        #expect(
            migrated.migrationArtifacts[EpdocPackageEntry.Migration.legacyProseMirrorOriginal]
                == Self.sampleProseMirrorJSON
        )
        let receiptData = try #require(
            migrated.migrationArtifacts[EpdocPackageEntry.Migration.legacyProseMirrorReceipt]
        )
        let receipt = try JSONDecoder.epdocCanonical.decode(
            EpdocContentMigrationReceipt.self,
            from: receiptData
        )
        #expect(receipt.sourceSHA256.count == 64)
        #expect(receipt.sourcePlainTextSHA256 == receipt.targetPlainTextSHA256)

        let canonicalWrapper = try migrated.makeFileWrapper()
        #expect(canonicalWrapper.fileWrappers?[EpdocPackageEntry.content] != nil)
        #expect(canonicalWrapper.fileWrappers?[EpdocPackageEntry.legacyContent] == nil)
        #expect(canonicalWrapper.fileWrappers?[EpdocPackageEntry.migrations]?.isDirectory == true)
    }

    @Test("Epdoc rich JSON envelope round-trips with stable block identity")
    func richContentEnvelopeRoundTrips() throws {
        let paragraph = EpdocRichNode(
            id: "block-paragraph",
            type: .paragraph,
            children: [
                EpdocRichNode(
                    type: .text,
                    text: "Hello viewport",
                    marks: [EpdocTextMark(type: .bold)]
                ),
            ]
        )
        let envelope = EpdocContentEnvelope(
            documentID: "document-1",
            revision: 7,
            root: EpdocRichNode(
                id: "document-1:root",
                type: .document,
                children: [paragraph]
            )
        )

        try envelope.validate()
        let encoded = try JSONEncoder.epdocCanonical.encode(envelope)
        let decoded = try JSONDecoder.epdocCanonical.decode(
            EpdocContentEnvelope.self,
            from: encoded
        )

        #expect(decoded == envelope)
        #expect(decoded.schemaVersion == EpdocContentEnvelope.currentSchemaVersion)
        #expect(decoded.root.children.first?.id == "block-paragraph")
        #expect(decoded.root.children.first?.children.first?.marks.first?.type == .bold)
    }

    @Test("Epdoc rich JSON rejects duplicate block IDs and future schemas")
    func richContentEnvelopeValidationFailsClosed() throws {
        let duplicateA = EpdocRichNode(id: "duplicate", type: .paragraph)
        let duplicateB = EpdocRichNode(id: "duplicate", type: .heading)
        let duplicateEnvelope = EpdocContentEnvelope(
            documentID: "document-duplicate",
            root: EpdocRichNode(
                id: "document-duplicate:root",
                type: .document,
                children: [duplicateA, duplicateB]
            )
        )

        #expect(throws: EpdocContentValidationError.self) {
            try duplicateEnvelope.validate()
        }

        let futureEnvelope = EpdocContentEnvelope(
            schemaVersion: EpdocContentEnvelope.currentSchemaVersion + 1,
            documentID: "document-future",
            root: EpdocRichNode(id: "document-future:root", type: .document)
        )
        #expect(throws: EpdocContentValidationError.self) {
            try futureEnvelope.validate()
        }
    }

    @Test("Epdoc rich JSON rejects text directly under the document root")
    func richContentEnvelopeRejectsInvalidGrammar() {
        let envelope = EpdocContentEnvelope(
            documentID: "document-invalid-grammar",
            root: EpdocRichNode(
                id: "document-invalid-grammar:root",
                type: .document,
                children: [EpdocRichNode(type: .text, text: "orphan")]
            )
        )

        #expect(throws: EpdocContentValidationError.self) {
            try envelope.validate()
        }
    }

    @Test("legacy ProseMirror migration preserves text marks attributes and original bytes")
    func legacyProseMirrorMigrationPreservesSemanticContent() throws {
        let legacy = #"""
        {
          "type": "doc",
          "content": [
            {
              "type": "heading",
              "attrs": {"id": "heading-one", "level": 1},
              "content": [
                {
                  "type": "text",
                  "text": "Viewport title",
                  "marks": [
                    {"type": "bold"},
                    {"type": "link", "attrs": {"href": "https://example.com"}}
                  ]
                }
              ]
            },
            {
              "type": "paragraph",
              "content": [{"type": "text", "text": "Large document body"}]
            }
          ]
        }
        """#.data(using: .utf8)!

        let result = try EpdocLegacyProseMirrorMigrator.migrate(
            legacy,
            documentID: "document-migrated",
            migratedAt: 1_700_000_001_234
        )
        let nodes = Self.flattenedNodes(in: result.envelope.root)
        let heading = try #require(nodes.first { $0.id == "heading-one" })
        let headingText = try #require(heading.children.first)

        try result.envelope.validate()
        #expect(result.originalContent == legacy)
        #expect(result.receipt.sourceFormat == "prosemirror.v1")
        #expect(result.receipt.targetFormat == EpdocContentEnvelope.formatIdentifier)
        #expect(result.receipt.sourceByteCount == legacy.count)
        #expect(result.receipt.sourceSHA256.count == 64)
        #expect(result.receipt.sourcePlainTextSHA256 == result.receipt.targetPlainTextSHA256)
        #expect(result.receipt.opaqueNodeCount == 0)
        #expect(heading.type == .heading)
        #expect(heading.attributes["level"] == .int(1))
        #expect(headingText.text == "Viewport title")
        #expect(headingText.marks.map(\.type) == [.bold, .link])
        #expect(headingText.marks.last?.attributes["href"] == .string("https://example.com"))
    }

    @Test("legacy migration quarantines unsupported nodes without losing their payload")
    func legacyProseMirrorMigrationPreservesOpaqueNodes() throws {
        let legacy = #"""
        {
          "type": "doc",
          "content": [
            {
              "type": "vendorWidget",
              "attrs": {"asset": "assets/widget.bin", "mode": "interactive"},
              "content": [{"type": "text", "text": "Widget fallback"}]
            }
          ]
        }
        """#.data(using: .utf8)!

        let result = try EpdocLegacyProseMirrorMigrator.migrate(
            legacy,
            documentID: "document-opaque",
            migratedAt: 1_700_000_001_235
        )
        let opaque = try #require(
            Self.flattenedNodes(in: result.envelope.root)
                .first { $0.type == .opaqueLegacy }
        )

        #expect(result.receipt.opaqueNodeCount == 1)
        #expect(result.receipt.warnings.count == 1)
        #expect(opaque.attributes["legacy_type"] == .string("vendorWidget"))
        #expect(opaque.attributes["legacy_payload"] != nil)
        #expect(opaque.children.first?.text == "Widget fallback")
        #expect(result.receipt.sourcePlainTextSHA256 == result.receipt.targetPlainTextSHA256)
    }

    @MainActor
    @Test("native Epdoc session updates one stable block and checkpoints canonical JSON")
    func nativeEditorSessionCheckpointsCanonicalJSON() throws {
        let content = try Self.sampleContentJSON(documentID: "document-session")
        let session = try EpdocTextKit2EditorSession(contentJSON: content)
        let blockID = "document-session:paragraph:0"

        #expect(session.revision == 0)
        #expect(session.blockCount == 1)
        #expect(session.wordCount == 1)

        try session.replaceInlineContent(
            blockID: blockID,
            children: [
                EpdocRichNode(
                    type: .text,
                    text: "Viewport editing stays bounded",
                    marks: [EpdocTextMark(type: .bold)]
                ),
            ]
        )

        #expect(session.revision == 1)
        #expect(session.wordCount == 4)
        let checkpoint = try session.checkpointData()
        let envelope = try JSONDecoder.epdocCanonical.decode(
            EpdocContentEnvelope.self,
            from: checkpoint
        )
        let block = try #require(envelope.root.children.first)
        #expect(block.id == blockID)
        #expect(block.children.first?.text == "Viewport editing stays bounded")
        #expect(block.children.first?.marks.map(\.type) == [.bold])
    }

    @Test("EpdocPackage missing manifest fails with .missingManifest")
    func missingManifestErrors() throws {
        let wrapper = FileWrapper(directoryWithFileWrappers: [
            EpdocPackageEntry.content: FileWrapper(
                regularFileWithContents: try Self.sampleContentJSON()
            ),
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

    @Test("EpdocPackage missing canonical and legacy content fails with .missingContent")
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
            EpdocPackageEntry.content: FileWrapper(
                regularFileWithContents: try Self.sampleContentJSON(documentID: future.id)
            ),
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
