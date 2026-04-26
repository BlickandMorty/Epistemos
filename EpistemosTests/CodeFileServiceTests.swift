import Foundation
import Testing

@testable import Epistemos

/// Wave 9.5 + W9.10 source-guard for CodeFileService — the canonical
/// CRUD surface both the editor UI and the agent tool registry call
/// into. Tests use a temp vault directory so no host filesystem
/// state leaks between cases.
@MainActor
@Suite("CodeFileService (Wave 9.5 + W9.10 base)")
struct CodeFileServiceTests {

    // MARK: - Test helpers

    private func makeVault() -> (URL, () -> Void) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("epistemos-codefile-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return (tmp, { try? FileManager.default.removeItem(at: tmp) })
    }

    private static let agentProvenance = CodeProvenance(
        producer: .agent,
        derivedFrom: [
            EpdocArtifactRef(id: "thought-1", kind: .rawThought, title: "kant duty"),
        ],
        generatedByRun: "run-1234",
        originatedFromThoughtIndex: 0,
        toolId: "create_code_file",
        toolUseId: "tu-aaa",
        sourceArtifacts: []
    )

    // MARK: - Create

    @Test("createCodeFile writes the source file + sidecar with provenance")
    func createWritesSourceAndSidecar() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)

        let url = try service.createCodeFile(
            relativeDirectory: "Sources",
            name: "Hello",
            kind: .swift,
            body: nil,
            provenance: Self.agentProvenance
        )
        #expect(url.lastPathComponent == "Hello.swift",
                "createCodeFile must use kind.primaryExtension when no extension provided")
        #expect(FileManager.default.fileExists(atPath: url.path),
                "source file must be on disk")

        let sidecarURL = CodeSidecarPath.sidecarURL(
            forVaultRoot: vault,
            vaultRelativePath: "Sources/Hello.swift"
        )
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path),
                "sidecar must be written to .epcache/code/")

        let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        #expect(body.contains("Hello.swift"),
                "default body should be the boilerplate template (containing the file name)")
    }

    @Test("createCodeFile uses the custom body when provided")
    func createUsesCustomBody() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)

        let custom = "// hand-written body\nprint(\"hi\")\n"
        let url = try service.createCodeFile(
            relativeDirectory: "",
            name: "Custom",
            kind: .swift,
            body: custom,
            provenance: Self.agentProvenance
        )
        let onDisk = try String(contentsOf: url, encoding: .utf8)
        #expect(onDisk == custom,
                "custom body must be written verbatim (no template substitution)")
    }

    @Test("createCodeFile rejects names with path separators")
    func createRejectsPathSeparators() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)
        do {
            _ = try service.createCodeFile(
                relativeDirectory: "",
                name: "Bad/Name",
                kind: .swift,
                provenance: Self.agentProvenance
            )
            #expect(Bool(false), "must throw on names containing /")
        } catch let error as CodeFileService.ServiceError {
            switch error {
            case .nameContainsPathSeparators: break
            default: #expect(Bool(false), "wrong error case: \(error)")
            }
        }
    }

    @Test("createCodeFile rejects empty name")
    func createRejectsEmptyName() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)
        do {
            _ = try service.createCodeFile(
                relativeDirectory: "",
                name: "   ",
                kind: .swift,
                provenance: Self.agentProvenance
            )
            #expect(Bool(false), "must throw on empty name")
        } catch let error as CodeFileService.ServiceError {
            switch error {
            case .nameIsEmpty: break
            default: #expect(Bool(false), "wrong error case: \(error)")
            }
        }
    }

    @Test("createCodeFile rejects when target file already exists")
    func createRejectsDuplicate() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)
        _ = try service.createCodeFile(
            relativeDirectory: "",
            name: "Dup",
            kind: .swift,
            provenance: Self.agentProvenance
        )
        do {
            _ = try service.createCodeFile(
                relativeDirectory: "",
                name: "Dup",
                kind: .swift,
                provenance: Self.agentProvenance
            )
            #expect(Bool(false), "must throw on duplicate")
        } catch let error as CodeFileService.ServiceError {
            switch error {
            case .fileAlreadyExists: break
            default: #expect(Bool(false), "wrong error case: \(error)")
            }
        }
    }

    @Test("createCodeFile picks the right extension for every CodeArtifactKind")
    func createPicksRightExtensionPerKind() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)
        for kind in CodeArtifactKind.allCases {
            let url = try service.createCodeFile(
                relativeDirectory: kind.rawValue,
                name: "Demo",
                kind: kind,
                provenance: Self.agentProvenance
            )
            #expect(url.pathExtension == kind.primaryExtension,
                    "kind .\(kind) must produce a .\(kind.primaryExtension) file; got .\(url.pathExtension)")
        }
    }

    // MARK: - Read

    @Test("readCodeFile returns body + sidecar for an indexed file")
    func readReturnsBodyAndSidecar() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)
        let url = try service.createCodeFile(
            relativeDirectory: "Sources",
            name: "Indexed",
            kind: .swift,
            body: "// indexed body\n",
            provenance: Self.agentProvenance
        )
        let result = try service.readCodeFile(at: url)
        #expect(result.body == "// indexed body\n")
        #expect(result.sidecar != nil)
        #expect(result.sidecar?.kind == .swift)
        #expect(result.sidecar?.provenance.toolId == "create_code_file")
        #expect(result.sidecar?.provenance.generatedByRun == "run-1234")
    }

    @Test("readCodeFile returns body + nil sidecar for a non-indexed file")
    func readReturnsNilSidecarWhenMissing() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)

        // Drop a hand-created file the indexer never saw.
        let url = vault.appendingPathComponent("Floater.swift")
        try "// hand-dropped\n".data(using: .utf8)!.write(to: url, options: .atomic)
        let result = try service.readCodeFile(at: url)
        #expect(result.body == "// hand-dropped\n")
        #expect(result.sidecar == nil,
                "files the indexer hasn't seen must return nil sidecar (NEVER throw — caller handles by triggering reindex)")
    }

    @Test("readCodeFile throws .fileNotFound when source is missing")
    func readThrowsWhenMissing() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)
        do {
            _ = try service.readCodeFile(at: vault.appendingPathComponent("Missing.swift"))
            #expect(Bool(false), "must throw")
        } catch let error as CodeFileService.ServiceError {
            switch error {
            case .fileNotFound: break
            default: #expect(Bool(false), "wrong error case: \(error)")
            }
        }
    }

    // MARK: - Update

    @Test("updateCodeFile rewrites source + refreshes sidecar contentHash")
    func updateRefreshesContentHash() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)
        let url = try service.createCodeFile(
            relativeDirectory: "",
            name: "Mut",
            kind: .swift,
            body: "// v1\n",
            provenance: Self.agentProvenance
        )
        let firstHash = (try service.readCodeFile(at: url)).sidecar?.contentHash

        try service.updateCodeFile(at: url, body: "// v2 a totally different body\n")
        let secondResult = try service.readCodeFile(at: url)
        #expect(secondResult.body == "// v2 a totally different body\n")
        #expect(secondResult.sidecar?.contentHash != firstHash,
                "contentHash MUST change after the body is rewritten")
    }

    @Test("updateCodeFile preserves prior provenance unless override given")
    func updatePreservesProvenance() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)
        let url = try service.createCodeFile(
            relativeDirectory: "",
            name: "Prov",
            kind: .swift,
            body: nil,
            provenance: Self.agentProvenance
        )
        try service.updateCodeFile(at: url, body: "// touched\n")
        let sidecar = try service.readCodeFile(at: url).sidecar
        #expect(sidecar?.provenance.generatedByRun == Self.agentProvenance.generatedByRun)
        #expect(sidecar?.provenance.toolId == Self.agentProvenance.toolId)
    }

    @Test("updateCodeFile records new provenance when override supplied")
    func updateRecordsOverrideProvenance() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)
        let url = try service.createCodeFile(
            relativeDirectory: "",
            name: "Override",
            kind: .swift,
            body: nil,
            provenance: Self.agentProvenance
        )
        let newProv = CodeProvenance(
            producer: .agent,
            derivedFrom: [],
            generatedByRun: "run-9999",
            toolId: "edit_file"
        )
        try service.updateCodeFile(at: url, body: "// new edit\n", provenanceOverride: newProv)
        let sidecar = try service.readCodeFile(at: url).sidecar
        #expect(sidecar?.provenance.generatedByRun == "run-9999")
        #expect(sidecar?.provenance.toolId == "edit_file")
    }

    @Test("updateCodeFile preserves symbols + cross-references + embeddings (the indexer's columns)")
    func updatePreservesIndexerColumns() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)
        let url = try service.createCodeFile(
            relativeDirectory: "",
            name: "Indexed",
            kind: .swift,
            body: "func a() {}\n",
            provenance: Self.agentProvenance
        )

        // Simulate the W9.7 indexer enriching the sidecar.
        let enriched = try service.readCodeFile(at: url).sidecar!
        let withColumns = CodeArtifactSidecar(
            vaultRelativePath: enriched.vaultRelativePath,
            kind: enriched.kind,
            contentHash: enriched.contentHash,
            indexedAt: enriched.indexedAt,
            provenance: enriched.provenance,
            symbols: [CodeSymbol(name: "a", kind: .function, utf8ByteStart: 5, utf8ByteEnd: 8)],
            crossReferences: [EpdocArtifactRef(id: "Sources/Bar.swift", kind: .code, title: "Bar")],
            embedding: [0.1, 0.2, 0.3]
        )
        let url2 = CodeSidecarPath.sidecarURL(forVaultRoot: vault, vaultRelativePath: enriched.vaultRelativePath)
        try JSONEncoder.epdocCanonical.encode(withColumns).write(to: url2, options: .atomic)

        // Now do a routine body update; indexer columns must survive.
        try service.updateCodeFile(at: url, body: "func a() { return }\n")
        let after = try service.readCodeFile(at: url).sidecar!
        #expect(after.symbols.count == 1, "symbols must survive a body update")
        #expect(after.crossReferences.count == 1, "cross-refs must survive a body update")
        #expect(after.embedding == [0.1, 0.2, 0.3], "embedding must survive a body update")
    }

    // MARK: - List

    @Test("listCodeFiles returns every code file the indexer knows about")
    func listEnumerates() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)
        let urlA = try service.createCodeFile(
            relativeDirectory: "",
            name: "A",
            kind: .swift,
            provenance: Self.agentProvenance
        )
        let urlB = try service.createCodeFile(
            relativeDirectory: "",
            name: "B",
            kind: .rust,
            provenance: Self.agentProvenance
        )
        let listed = try service.listCodeFiles()
        #expect(listed.contains(urlA))
        #expect(listed.contains(urlB))
        #expect(listed.count == 2)
    }

    @Test("listCodeFiles filters by CodeArtifactKind")
    func listFiltersByKind() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)
        _ = try service.createCodeFile(relativeDirectory: "", name: "A", kind: .swift, provenance: Self.agentProvenance)
        _ = try service.createCodeFile(relativeDirectory: "", name: "B", kind: .rust, provenance: Self.agentProvenance)
        let onlySwift = try service.listCodeFiles(kind: .swift)
        let onlyRust = try service.listCodeFiles(kind: .rust)
        #expect(onlySwift.count == 1)
        #expect(onlyRust.count == 1)
        #expect(onlySwift.first?.lastPathComponent == "A.swift")
        #expect(onlyRust.first?.lastPathComponent == "B.rs")
    }

    @Test("listCodeFiles returns empty array when .epcache/code/ doesn't exist")
    func listEmptyWhenNoCache() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let service = CodeFileService(vaultRoot: vault)
        #expect(try service.listCodeFiles().isEmpty)
    }
}
