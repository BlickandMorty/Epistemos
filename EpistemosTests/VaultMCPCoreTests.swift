import Foundation
import Testing
@testable import Epistemos

@Suite("Vault MCP Core")
struct VaultMCPCoreTests {
    private actor CallRecorder {
        private var calls: [(String, String)] = []

        func record(name: String, argumentsJSON: String) {
            calls.append((name, argumentsJSON))
        }

        func snapshot() -> [(String, String)] {
            calls
        }
    }

    private static let echoExecutor: LocalAgentToolExecutor = { name, argumentsJSON in
        LocalToolResult(
            toolName: name,
            resultJson: #"{"echoed":"\#(name)","args":\#(argumentsJSON)}"#,
            isError: false)
    }

    @Test("tools/list advertises only the Plan 3 read-only vault surface")
    func toolsListAdvertisesReadOnlyVaultSurface() async throws {
        let core = VaultMCPCore(executor: Self.echoExecutor)
        let response = await core.handle(requestJSON: #"{"jsonrpc":"2.0","id":1,"method":"tools/list"}"#)
        let object = try Self.jsonObject(response)
        let result = try #require(object["result"] as? [String: Any])
        let tools = try #require(result["tools"] as? [[String: Any]])
        let names = Set(tools.compactMap { $0["name"] as? String })

        #expect(names == Set(VaultMCPCore.readToolNames))
        #expect(names.contains("vault.search"))
        #expect(names.contains("vault.read"))
        #expect(names.contains("vault.list"))
        #expect(names.contains("eidos.query"))
        #expect(names.contains("vault.backlinks"))
        #expect(names.contains("vault.outlinks"))
        #expect(names.contains("vault.dangling_links"))
        #expect(names.contains("vault.note_links"))
        #expect(names.contains("vault.link_candidates"))
        #expect(names.contains("vault.orphan_notes"))
        #expect(!names.contains("vault.write"))
        #expect(!names.contains("file.write"))
        #expect(!names.contains("vault.patch_note"))
    }

    @Test("tools/call canonicalizes read aliases before executing")
    func toolsCallCanonicalizesReadAliases() async throws {
        let root = try Self.makeVaultRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = CallRecorder()
        let core = VaultMCPCore(vaultRoot: root, executor: { name, argumentsJSON in
            await recorder.record(name: name, argumentsJSON: argumentsJSON)
            return LocalToolResult(toolName: name, resultJson: #"{"ok":true}"#, isError: false)
        })

        let response = await core.handle(
            requestJSON: #"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"read_file","arguments":{"path":"Note.md"}}}"#)
        let object = try Self.jsonObject(response)
        let result = try #require(object["result"] as? [String: Any])
        #expect(result["isError"] as? Bool == false)

        let calls = await recorder.snapshot()
        #expect(calls.count == 1)
        #expect(calls.first?.0 == "vault.read")
        let arguments = try Self.jsonObject(calls.first?.1 ?? "{}")
        #expect(arguments["path"] as? String == "Note.md")
    }

    @Test("tools/call rejects vault read path escapes before executor")
    func toolsCallRejectsVaultReadPathEscapesBeforeExecutor() async throws {
        let root = try Self.makeVaultRoot()
        let outside = try Self.makeVaultRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        try "secret".write(to: outside.appendingPathComponent("Secret.md"), atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("Linked.md"),
            withDestinationURL: outside.appendingPathComponent("Secret.md"))

        let recorder = CallRecorder()
        let core = VaultMCPCore(vaultRoot: root, executor: { name, argumentsJSON in
            await recorder.record(name: name, argumentsJSON: argumentsJSON)
            return LocalToolResult(toolName: name, resultJson: #"{"called":true}"#, isError: false)
        })

        for payload in [
            #"{"name":"file.read","arguments":{"path":"../Secret.md"}}"#,
            #"{"name":"vault.read","arguments":{"path":"/tmp/Secret.md"}}"#,
            #"{"name":"vault.read","arguments":{"path":"Linked.md"}}"#,
        ] {
            let response = await core.handle(
                requestJSON: #"{"jsonrpc":"2.0","id":22,"method":"tools/call","params":\#(payload)}"#)
            let object = try Self.jsonObject(response)
            let error = try #require(object["error"] as? [String: Any])
            #expect(error["code"] as? Int == -32602)
        }

        let calls = await recorder.snapshot()
        #expect(calls.isEmpty)
    }

    @Test("tools/call rejects vault list path escapes before executor")
    func toolsCallRejectsVaultListPathEscapesBeforeExecutor() async throws {
        let root = try Self.makeVaultRoot()
        let outside = try Self.makeVaultRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("LinkedFolder", isDirectory: true),
            withDestinationURL: outside)

        let recorder = CallRecorder()
        let core = VaultMCPCore(vaultRoot: root, executor: { name, argumentsJSON in
            await recorder.record(name: name, argumentsJSON: argumentsJSON)
            return LocalToolResult(toolName: name, resultJson: #"{"called":true}"#, isError: false)
        })

        for payload in [
            #"{"name":"vault.list","arguments":{"path":"../"}}"#,
            #"{"name":"file.list","arguments":{"path_prefix":"/tmp"}}"#,
            #"{"name":"vault.list","arguments":{"prefix":"LinkedFolder"}}"#,
        ] {
            let response = await core.handle(
                requestJSON: #"{"jsonrpc":"2.0","id":23,"method":"tools/call","params":\#(payload)}"#)
            let object = try Self.jsonObject(response)
            let error = try #require(object["error"] as? [String: Any])
            #expect(error["code"] as? Int == -32602)
        }

        let calls = await recorder.snapshot()
        #expect(calls.isEmpty)
    }

    @Test("tools/call rejects write and patch aliases before the executor")
    func toolsCallRejectsWriteAliases() async throws {
        let recorder = CallRecorder()
        let core = VaultMCPCore(executor: { name, argumentsJSON in
            await recorder.record(name: name, argumentsJSON: argumentsJSON)
            return LocalToolResult(toolName: name, resultJson: #"{"called":true}"#, isError: false)
        })

        for toolName in ["vault.write", "write_file", "vault.patch_note", "patch_note"] {
            let response = await core.handle(
                requestJSON: #"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"\#(toolName)","arguments":{"path":"Note.md","content":"x"}}}"#)
            let object = try Self.jsonObject(response)
            let error = try #require(object["error"] as? [String: Any])
            #expect(error["code"] as? Int == -32601)
            #expect((error["message"] as? String)?.contains("read-only vault server") == true)
        }

        let calls = await recorder.snapshot()
        #expect(calls.isEmpty)
    }

    @Test("empty or missing vault lists honest-empty resources")
    func emptyVaultListsHonestEmptyResources() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-vault-mcp-missing-\(UUID().uuidString)", isDirectory: true)
        let core = VaultMCPCore(vaultRoot: missing, executor: Self.echoExecutor)
        let response = await core.handle(requestJSON: #"{"jsonrpc":"2.0","id":4,"method":"resources/list"}"#)
        let object = try Self.jsonObject(response)
        let result = try #require(object["result"] as? [String: Any])
        let resources = try #require(result["resources"] as? [[String: Any]])
        #expect(resources.isEmpty)
    }

    @Test("resources/list exposes markdown notes as vault URIs and skips hidden/non-markdown files")
    func resourcesListExposesMarkdownNotes() async throws {
        let root = try Self.makeVaultRoot()
        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-vault-mcp-outside-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        try "Top".write(to: root.appendingPathComponent("Top.md"), atomically: true, encoding: .utf8)
        try "Needs encoding".write(
            to: root.appendingPathComponent("Space #1.md"),
            atomically: true,
            encoding: .utf8)
        try "Skip".write(to: root.appendingPathComponent("Ignore.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Folder"), withIntermediateDirectories: true)
        try "Nested".write(
            to: root.appendingPathComponent("Folder").appendingPathComponent("Nested.md"),
            atomically: true,
            encoding: .utf8)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".hidden"), withIntermediateDirectories: true)
        try "Hidden".write(
            to: root.appendingPathComponent(".hidden").appendingPathComponent("Hidden.md"),
            atomically: true,
            encoding: .utf8)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let outsideNote = outside.appendingPathComponent("Outside.md")
        try "Outside".write(to: outsideNote, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("LinkedOutside.md"),
            withDestinationURL: outsideNote)
        let json = root.appendingPathComponent("Data.json")
        try #"{"not":"markdown"}"#.write(to: json, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("LinkedJSON.md"),
            withDestinationURL: json)

        let core = VaultMCPCore(vaultRoot: root, executor: Self.echoExecutor)
        let response = await core.handle(requestJSON: #"{"jsonrpc":"2.0","id":5,"method":"resources/list"}"#)
        let object = try Self.jsonObject(response)
        let result = try #require(object["result"] as? [String: Any])
        let resources = try #require(result["resources"] as? [[String: Any]])
        let uris = Set(resources.compactMap { $0["uri"] as? String })
        let names = Set(resources.compactMap { $0["name"] as? String })

        #expect(uris == ["vault:///Folder/Nested.md", "vault:///Space%20%231.md", "vault:///Top.md"])
        #expect(names == ["Folder/Nested.md", "Space #1.md", "Top.md"])
        #expect(Set(resources.compactMap { $0["mimeType"] as? String }) == ["text/markdown"])
    }

    @Test("resources/read returns markdown text, decodes resource URIs, and rejects traversal")
    func resourcesReadReturnsMarkdownDecodesURIsAndRejectsTraversal() async throws {
        let root = try Self.makeVaultRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".hidden"), withIntermediateDirectories: true)
        try "Line one\nLine two".write(
            to: folder.appendingPathComponent("Note.md"),
            atomically: true,
            encoding: .utf8)
        try "Hidden".write(
            to: root.appendingPathComponent(".hidden").appendingPathComponent("Secret.md"),
            atomically: true,
            encoding: .utf8)
        try "Encoded".write(
            to: folder.appendingPathComponent("Space #1.md"),
            atomically: true,
            encoding: .utf8)
        let json = folder.appendingPathComponent("Data.json")
        try #"{"not":"markdown"}"#.write(to: json, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: folder.appendingPathComponent("LinkedJSON.md"),
            withDestinationURL: json)

        let core = VaultMCPCore(vaultRoot: root, executor: Self.echoExecutor)
        let read = await core.handle(
            requestJSON: #"{"jsonrpc":"2.0","id":6,"method":"resources/read","params":{"uri":"vault:///Folder/Note.md"}}"#)
        let readObject = try Self.jsonObject(read)
        let result = try #require(readObject["result"] as? [String: Any])
        let contents = try #require(result["contents"] as? [[String: Any]])
        #expect(contents.first?["uri"] as? String == "vault:///Folder/Note.md")
        #expect(contents.first?["mimeType"] as? String == "text/markdown")
        #expect(contents.first?["text"] as? String == "Line one\nLine two")

        let encoded = await core.handle(
            requestJSON: #"{"jsonrpc":"2.0","id":8,"method":"resources/read","params":{"uri":"vault:///Folder/Space%20%231.md"}}"#)
        let encodedObject = try Self.jsonObject(encoded)
        let encodedResult = try #require(encodedObject["result"] as? [String: Any])
        let encodedContents = try #require(encodedResult["contents"] as? [[String: Any]])
        #expect(encodedContents.first?["text"] as? String == "Encoded")

        let encodedSeparator = await core.handle(
            requestJSON: #"{"jsonrpc":"2.0","id":12,"method":"resources/read","params":{"uri":"vault:///Folder%2FNote.md"}}"#)
        let encodedSeparatorObject = try Self.jsonObject(encodedSeparator)
        let encodedSeparatorError = try #require(encodedSeparatorObject["error"] as? [String: Any])
        #expect(encodedSeparatorError["code"] as? Int == -32602)

        let traversal = await core.handle(
            requestJSON: #"{"jsonrpc":"2.0","id":7,"method":"resources/read","params":{"uri":"vault:///../secret.md"}}"#)
        let traversalObject = try Self.jsonObject(traversal)
        let error = try #require(traversalObject["error"] as? [String: Any])
        #expect(error["code"] as? Int == -32602)
        #expect((error["message"] as? String)?.contains("path traversal") == true)

        let nonMarkdownTarget = await core.handle(
            requestJSON: #"""
            {"jsonrpc":"2.0","id":10,"method":"resources/read","params":{"uri":"vault:///Folder/LinkedJSON.md"}}
            """#)
        let nonMarkdownObject = try Self.jsonObject(nonMarkdownTarget)
        let nonMarkdownError = try #require(nonMarkdownObject["error"] as? [String: Any])
        #expect(nonMarkdownError["code"] as? Int == -32602)
        #expect((nonMarkdownError["message"] as? String)?.contains("only markdown") == true)

        let hidden = await core.handle(
            requestJSON: #"{"jsonrpc":"2.0","id":11,"method":"resources/read","params":{"uri":"vault:///.hidden/Secret.md"}}"#)
        let hiddenObject = try Self.jsonObject(hidden)
        let hiddenError = try #require(hiddenObject["error"] as? [String: Any])
        #expect(hiddenError["code"] as? Int == -32602)
        #expect((hiddenError["message"] as? String)?.contains("hidden vault resources") == true)
    }

    @Test("resources/read rejects oversized markdown before loading it")
    func resourcesReadRejectsOversizedMarkdown() async throws {
        let root = try Self.makeVaultRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let huge = root.appendingPathComponent("Huge.md")
        try Data(repeating: UInt8(ascii: "a"), count: VaultMCPCore.maxResourceReadBytes + 1)
            .write(to: huge, options: .atomic)

        let core = VaultMCPCore(vaultRoot: root, executor: Self.echoExecutor)
        let response = await core.handle(
            requestJSON: #"{"jsonrpc":"2.0","id":9,"method":"resources/read","params":{"uri":"vault:///Huge.md"}}"#)
        let object = try Self.jsonObject(response)
        let error = try #require(object["error"] as? [String: Any])

        #expect(error["code"] as? Int == -32602)
        #expect((error["message"] as? String)?.contains("too large") == true)
    }

    @Test("markdown resource enumeration is capped and sorted")
    func markdownResourceEnumerationIsCappedAndSorted() throws {
        let root = try Self.makeVaultRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["C.md", "A.md", "B.md"] {
            try name.write(to: root.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }

        let paths = VaultMCPCore.markdownRelPaths(vaultRoot: root, limit: 2)

        #expect(paths.count == 2)
        #expect(paths == paths.sorted())
        #expect(VaultMCPCore.markdownRelPaths(vaultRoot: root, limit: 0).isEmpty)
        #expect(VaultMCPCore.maxResourceNotes == 5_000)
    }

    @Test("source guard keeps VaultMCPCore pure and read-only")
    func sourceGuardKeepsCorePureAndReadOnly() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/VaultMCP/VaultMCPCore.swift")
        #expect(source.contains("static let readToolNames"))
        #expect(source.contains("read-only vault server"))
        #expect(source.contains("resources/list"))
        #expect(source.contains("resources/read"))
        #expect(source.contains("maxResourceNotes"))
        #expect(source.contains("maxResourceReadBytes"))
        #expect(source.contains("pathRequiredReadToolNameSet"))
        #expect(source.contains("validatedArgumentsJSON"))
        #expect(source.contains("vaultURI(for:"))
        #expect(source.contains("markdownRelPaths"))
        #expect(source.contains("noteText"))
        #expect(source.contains("Task.detached(priority: .utility)"))
        #expect(source.contains("ResourceReadResult"))
        #expect(!source.contains("Process("))
        #expect(!source.contains("NWListener"))
        #expect(!source.contains("listToolsForTier("))
    }

    private static func makeVaultRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-vault-mcp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func jsonObject(_ string: String) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(string.utf8)) as? [String: Any])
    }
}
