import Foundation
import Testing

@testable import Epistemos

@MainActor
private final class AgentGrepAgentEventSink {
    private(set) var events: [AgentProvenanceEvent] = []

    func append(_ event: AgentProvenanceEvent) -> Bool {
        events.append(event)
        return true
    }
}

/// Wave 9.9 source-guard for the agent-grep API.
@MainActor
@Suite("AgentGrepService (Wave 9.9 base)")
struct AgentGrepServiceTests {

    private func makeVault() -> (URL, () -> Void) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("epistemos-grep-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return (tmp, { try? FileManager.default.removeItem(at: tmp) })
    }

    private static let agentProvenance = CodeProvenance(
        producer: .agent,
        derivedFrom: [EpdocArtifactRef(id: "thought-1", kind: .rawThought, title: "kant duty")],
        generatedByRun: "run-9999",
        originatedFromThoughtIndex: 4,
        toolId: "create_code_file",
        toolUseId: "tu-zzz"
    )

    private func makeService() -> (AgentGrepService, CodeFileService, InMemoryCodeIndexClient, () -> Void) {
        let (vault, cleanup) = makeVault()
        let files = CodeFileService(vaultRoot: vault)
        let index = InMemoryCodeIndexClient()
        let svc = AgentGrepService(index: index, files: files)
        return (svc, files, index, cleanup)
    }

    // MARK: - search

    @Test("search returns backend hits enriched with sidecar provenance")
    func searchEnrichesProvenance() throws {
        let (svc, files, _, cleanup) = makeService()
        defer { cleanup() }
        let url = try files.createCodeFile(
            relativeDirectory: "Sources",
            name: "Hello",
            kind: .swift,
            body: "func hello() { print(\"kant on duty\") }\n",
            provenance: Self.agentProvenance
        )
        try svc.indexDocument(at: url)

        let hits = try svc.search(query: "kant")
        #expect(hits.count == 1)
        #expect(hits[0].vaultRelativePath == "Sources/Hello.swift")
        #expect(hits[0].kind == .swift)
        #expect(hits[0].provenance != nil,
                "search hits MUST carry sidecar provenance — that's the agent-grep value-add")
        #expect(hits[0].provenance?.toolId == "create_code_file")
        #expect(hits[0].provenance?.generatedByRun == "run-9999")
        #expect(hits[0].provenance?.originatedFromThoughtIndex == 4)
        #expect(hits[0].source == "in-memory-substring")
    }

    @Test("Code index fallback provenance labels are honest")
    func codeIndexFallbackProvenanceLabelsAreHonest() throws {
        let checkedPaths = [
            "epistemos-code-index/src/state.rs",
            "epistemos-code-index/src/lib.rs",
            "epistemos-code-index/Cargo.toml",
            "Epistemos/Engine/AgentGrepService.swift",
        ]

        for path in checkedPaths {
            let source = try loadMirroredSourceTextFile(path)
            #expect(!source.contains("stub-substring"), "\(path) must not emit stale stub provenance")
            #expect(!source.contains("W9.7 stub"), "\(path) must not label code-index fallback as shipped backend")
            #expect(!source.contains("stub backend"), "\(path) must use fallback wording")
            #expect(!source.contains("codeindex.stub"), "\(path) must use fallback wording")
            #expect(!source.contains("StubCodeIndexClient"), "\(path) must use behavior-based fallback naming")
        }

        let rustState = try loadMirroredSourceTextFile("epistemos-code-index/src/state.rs")
        let swiftService = try loadMirroredSourceTextFile("Epistemos/Engine/AgentGrepService.swift")

        #expect(rustState.contains("source: \"in-memory-substring\""))
        #expect(swiftService.contains("source: \"in-memory-substring\""))
        #expect(swiftService.contains("com.epistemos.codeindex.inmemory"))
    }

    @Test("search filters by CodeArtifactKind")
    func searchFiltersByKind() throws {
        let (svc, files, _, cleanup) = makeService()
        defer { cleanup() }
        let urlSwift = try files.createCodeFile(
            relativeDirectory: "",
            name: "A",
            kind: .swift,
            body: "kant body",
            provenance: Self.agentProvenance
        )
        let urlRust = try files.createCodeFile(
            relativeDirectory: "",
            name: "B",
            kind: .rust,
            body: "kant body",
            provenance: Self.agentProvenance
        )
        try svc.indexDocument(at: urlSwift)
        try svc.indexDocument(at: urlRust)

        let swiftOnly = try svc.search(query: "kant", kindFilter: .swift)
        let rustOnly = try svc.search(query: "kant", kindFilter: .rust)
        #expect(swiftOnly.count == 1)
        #expect(rustOnly.count == 1)
        #expect(swiftOnly.first?.kind == .swift)
        #expect(rustOnly.first?.kind == .rust)
    }

    @Test("limit caps the backend hit count")
    func limitCaps() throws {
        let (svc, files, _, cleanup) = makeService()
        defer { cleanup() }
        for i in 0..<10 {
            let url = try files.createCodeFile(
                relativeDirectory: "",
                name: "F\(i)",
                kind: .swift,
                body: "kant body \(i)",
                provenance: Self.agentProvenance
            )
            try svc.indexDocument(at: url)
        }
        let limited = try svc.search(query: "kant", limit: 3)
        #expect(limited.count == 3)
    }

    @Test("empty query returns empty results")
    func emptyQuery() throws {
        let (svc, _, _, cleanup) = makeService()
        defer { cleanup() }
        #expect(try svc.search(query: "").isEmpty)
        #expect(try svc.search(query: "   ").isEmpty)
    }

    @Test("search backend errors surface as ServiceError.backendFailure")
    func backendErrorSurfaces() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let files = CodeFileService(vaultRoot: vault)
        let bomb = ThrowingCodeIndexClient()
        let svc = AgentGrepService(index: bomb, files: files)
        do {
            _ = try svc.search(query: "anything")
            #expect(Bool(false), "must throw when backend throws")
        } catch let error as AgentGrepService.ServiceError {
            switch error {
            case .backendFailure: break
            }
        }
    }

    @Test("search records sanitized AgentEvents")
    func searchRecordsSanitizedAgentEvents() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let files = CodeFileService(vaultRoot: vault)
        let index = InMemoryCodeIndexClient()
        let sink = AgentGrepAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 111 },
            persist: { event in sink.append(event) }
        )
        let svc = AgentGrepService(
            index: index,
            files: files,
            agentProvenanceRecorder: recorder
        )
        let url = try files.createCodeFile(
            relativeDirectory: "Sources",
            name: "Secret",
            kind: .swift,
            body: "func secret() { print(\"private snippet\") }\n",
            provenance: Self.agentProvenance
        )
        try svc.indexDocument(at: url)

        let hits = try svc.search(query: "private", kindFilter: .swift, limit: 5)

        #expect(hits.count == 1)
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallCompleted
        ])
        #expect(Set(sink.events.map(\.runID)).count == 1)
        #expect(sink.events.first?.runID.hasPrefix("agent-grep-") == true)
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "agent_grep.search" })
        #expect(sink.events.allSatisfy { $0.tool?.toolCallID == "agent-grep-search:1" })
        #expect(sink.events.allSatisfy { $0.metadata["source"] == "agent_grep_service" })
        #expect(sink.events.allSatisfy { $0.metadata["kind_filter"] == CodeArtifactKind.swift.rawValue })
        #expect(sink.events.allSatisfy { $0.metadata["limit"] == "5" })
        #expect(sink.events.last?.tool?.durationMs != nil)
        #expect(sink.events.last?.tool?.resultJSON?.contains("hit_count") == true)

        for event in sink.events {
            let tool = try #require(event.tool)
            #expect(!tool.argumentsJSON.contains("private"))
            #expect(!tool.argumentsJSON.contains("Secret.swift"))
            #expect(!tool.argumentsJSON.contains("Sources"))
            #expect(!(tool.resultJSON ?? "").contains("private snippet"))
            #expect(!(tool.resultJSON ?? "").contains("Secret.swift"))
            #expect(!(tool.resultJSON ?? "").contains("run-9999"))
            #expect(!(tool.resultJSON ?? "").contains("tu-zzz"))
        }
    }

    @Test("search records sanitized backend failure AgentEvents")
    func searchRecordsSanitizedBackendFailureAgentEvents() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let files = CodeFileService(vaultRoot: vault)
        let sink = AgentGrepAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 222 },
            persist: { event in sink.append(event) }
        )
        let svc = AgentGrepService(
            index: ThrowingCodeIndexClient(),
            files: files,
            agentProvenanceRecorder: recorder
        )

        do {
            _ = try svc.search(query: "private", kindFilter: .rust, limit: 7)
            Issue.record("Expected backend search failure.")
        } catch let error as AgentGrepService.ServiceError {
            switch error {
            case .backendFailure: break
            }
        }

        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallFailed
        ])
        #expect(sink.events.last?.tool?.status == .failed)
        #expect(sink.events.last?.tool?.durationMs != nil)
        #expect(sink.events.last?.metadata["failure_class"] == "backend_failure")

        for event in sink.events {
            let tool = try #require(event.tool)
            #expect(!tool.argumentsJSON.contains("private"))
            #expect(tool.resultJSON == nil)
        }
    }

    // MARK: - indexDocument

    @Test("indexDocument routes vault-relative path + kind into the backend")
    func indexDocumentRoutesPath() throws {
        let (svc, files, stub, cleanup) = makeService()
        defer { cleanup() }
        let url = try files.createCodeFile(
            relativeDirectory: "Sources/Modules",
            name: "Foo",
            kind: .rust,
            provenance: Self.agentProvenance
        )
        try svc.indexDocument(at: url)
        // The hit comes back with the same vault-relative path.
        let hits = try stub.search(query: "foo", kindFilter: nil, limit: 5)
        #expect(hits.contains { $0.vaultRelativePath == "Sources/Modules/Foo.rs" })
    }

    // MARK: - unindex

    @Test("unindex removes the document from the backend")
    func unindexRemoves() throws {
        let (svc, files, stub, cleanup) = makeService()
        defer { cleanup() }
        let url = try files.createCodeFile(
            relativeDirectory: "",
            name: "Removable",
            kind: .swift,
            body: "kant body",
            provenance: Self.agentProvenance
        )
        try svc.indexDocument(at: url)
        try svc.unindex(vaultRelativePath: "Removable.swift")
        #expect(try stub.search(query: "kant", kindFilter: nil, limit: 5).isEmpty)
    }

    // MARK: - InMemoryCodeIndexClient

    @Test("InMemoryCodeIndexClient rejects empty path on upsert")
    func inMemoryRejectsEmptyPath() {
        let index = InMemoryCodeIndexClient()
        let doc = AgentGrepDocument(
            vaultRelativePath: "",
            kind: .swift,
            body: "x",
            contentHash: "x"
        )
        do {
            try index.upsert(document: doc)
            #expect(Bool(false), "must throw")
        } catch {
            // expected
        }
    }
}

private final class ThrowingCodeIndexClient: CodeIndexClient, @unchecked Sendable {
    func upsert(document: AgentGrepDocument) throws {
        throw NSError(domain: "ThrowingCodeIndexClient", code: 0)
    }
    func remove(vaultRelativePath: String) throws {
        throw NSError(domain: "ThrowingCodeIndexClient", code: 0)
    }
    func search(query: String, kindFilter: CodeArtifactKind?, limit: Int) throws -> [AgentGrepBackendHit] {
        throw NSError(domain: "ThrowingCodeIndexClient", code: 99)
    }
}
