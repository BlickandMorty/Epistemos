import Foundation
import Testing

@testable import Epistemos

/// Wave 9.8 follow-up source-guard for the high-level `LSPClient` JSON-
/// RPC layer that sits on top of any `LSPTransport`. These tests pin
/// the parser helpers (Hover / Definition / Range coercion) + the
/// error envelope behavior; an end-to-end live SourceKit-LSP test is a
/// future commit because the build host can't always assume Xcode is
/// installed at a known path.
@Suite("LSPClient (Wave 9.8 follow-up)")
nonisolated struct LSPClientTests {

    // MARK: - Error descriptions

    @Test("Every LSPClientError case formats with a recognisable phrase")
    func errorDescriptions() {
        let server = LSPClientError.serverError(LSPError(code: -32601, message: "Method not found"))
        #expect(server.description.contains("server error"))
        #expect(server.description.contains("-32601"))
        #expect(server.description.contains("Method not found"))

        let decode = LSPClientError.decodeFailed(detail: "missing capabilities")
        #expect(decode.description.contains("decode failed"))
        #expect(decode.description.contains("missing capabilities"))

        #expect(LSPClientError.transportClosed.description.contains("transport finished"))
        #expect(LSPClientError.notInitialized.description.contains("initialize() must complete"))
        #expect(LSPClientError.alreadyInitialized.description.contains("already called"))
    }

    // MARK: - Range parsing

    @Test("parseRange round-trips a well-formed LSP range object")
    func rangeRoundTrip() {
        let json: LSPJSONValue = .object([
            "start": .object(["line": .int(0), "character": .int(4)]),
            "end":   .object(["line": .int(2), "character": .int(9)]),
        ])
        let range = LSPClient.parseRange(json)
        #expect(range != nil)
        #expect(range?.start == LSPPosition(line: 0, character: 4))
        #expect(range?.end == LSPPosition(line: 2, character: 9))
    }

    @Test("parseRange returns nil on malformed inputs")
    func rangeMalformed() {
        // Missing start
        #expect(LSPClient.parseRange(.object([
            "end": .object(["line": .int(0), "character": .int(0)]),
        ])) == nil)

        // start.line is not an int
        #expect(LSPClient.parseRange(.object([
            "start": .object(["line": .string("zero"), "character": .int(0)]),
            "end":   .object(["line": .int(1), "character": .int(0)]),
        ])) == nil)

        // Top-level isn't an object
        #expect(LSPClient.parseRange(.array([])) == nil)
    }

    // MARK: - Hover parsing

    @Test("parseHover handles MarkupContent shape ({kind, value})")
    func hoverMarkupContent() {
        let json: LSPJSONValue = .object([
            "contents": .object([
                "kind":  .string("markdown"),
                "value": .string("**hello**"),
            ]),
            "range": .object([
                "start": .object(["line": .int(0), "character": .int(0)]),
                "end":   .object(["line": .int(0), "character": .int(5)]),
            ]),
        ])
        let hover = LSPClient.parseHover(json)
        #expect(hover != nil)
        #expect(hover?.contents == "**hello**")
        #expect(hover?.range != nil)
    }

    @Test("parseHover handles plain string contents (legacy MarkedString shape)")
    func hoverPlainString() {
        let json: LSPJSONValue = .object([
            "contents": .string("just text"),
        ])
        let hover = LSPClient.parseHover(json)
        #expect(hover?.contents == "just text")
        #expect(hover?.range == nil)
    }

    @Test("parseHover handles MarkedString[] (legacy array form, line-joined)")
    func hoverArray() {
        let json: LSPJSONValue = .object([
            "contents": .array([
                .string("first line"),
                .object(["language": .string("swift"), "value": .string("let x = 1")]),
                .string("third line"),
            ]),
        ])
        let hover = LSPClient.parseHover(json)
        #expect(hover != nil)
        #expect(hover?.contents.contains("first line") == true)
        #expect(hover?.contents.contains("let x = 1") == true)
        #expect(hover?.contents.contains("third line") == true)
    }

    @Test("parseHover returns nil on unrecognised shapes")
    func hoverNil() {
        // No contents key
        #expect(LSPClient.parseHover(.object([:])) == nil)
        // Top-level isn't an object
        #expect(LSPClient.parseHover(.string("nope")) == nil)
    }

    // MARK: - Definition parsing

    @Test("parseDefinition decodes a single Location object")
    func definitionSingleLocation() {
        let json: LSPJSONValue = .object([
            "uri": .string("file:///tmp/foo.swift"),
            "range": .object([
                "start": .object(["line": .int(10), "character": .int(0)]),
                "end":   .object(["line": .int(10), "character": .int(20)]),
            ]),
        ])
        let locs = LSPClient.parseDefinition(json)
        #expect(locs.count == 1)
        #expect(locs.first?.uri == "file:///tmp/foo.swift")
        #expect(locs.first?.range.start.line == 10)
    }

    @Test("parseDefinition decodes Location[]")
    func definitionLocationArray() {
        let json: LSPJSONValue = .array([
            .object([
                "uri": .string("file:///a.swift"),
                "range": .object([
                    "start": .object(["line": .int(0), "character": .int(0)]),
                    "end":   .object(["line": .int(0), "character": .int(5)]),
                ]),
            ]),
            .object([
                "uri": .string("file:///b.swift"),
                "range": .object([
                    "start": .object(["line": .int(1), "character": .int(0)]),
                    "end":   .object(["line": .int(1), "character": .int(5)]),
                ]),
            ]),
        ])
        let locs = LSPClient.parseDefinition(json)
        #expect(locs.count == 2)
        #expect(locs.map(\.uri) == ["file:///a.swift", "file:///b.swift"])
    }

    @Test("parseDefinition returns empty array for null result + other unsupported shapes")
    func definitionNullEmpty() {
        #expect(LSPClient.parseDefinition(.null).isEmpty)
        #expect(LSPClient.parseDefinition(.string("nope")).isEmpty)
        #expect(LSPClient.parseDefinition(.array([])).isEmpty)
        // Malformed entries inside the array are skipped, not fatal.
        let mixed: LSPJSONValue = .array([
            .string("garbage"),
            .object([
                "uri": .string("file:///ok.swift"),
                "range": .object([
                    "start": .object(["line": .int(0), "character": .int(0)]),
                    "end":   .object(["line": .int(0), "character": .int(1)]),
                ]),
            ]),
        ])
        let locs = LSPClient.parseDefinition(mixed)
        #expect(locs.count == 1)
        #expect(locs.first?.uri == "file:///ok.swift")
    }

    // MARK: - Lifecycle (transport-closed handling)

    @Test("All RPC methods refuse to run before initialize() with .notInitialized")
    func notInitializedGuards() async throws {
        // Use the InProcessLSPTransport stub — it returns
        // MethodNotFound for every request, so the client never
        // reaches initialize(). The guards in didOpen / didChange /
        // didClose / hover / definition must therefore all surface
        // .notInitialized.
        let stub = InProcessLSPTransport()
        let client = LSPClient(transport: stub)

        let url = URL(fileURLWithPath: "/tmp/dummy.swift")

        do {
            try await client.didOpen(uri: url, languageId: "swift", version: 1, text: "")
            #expect(Bool(false), "didOpen before initialize MUST throw")
        } catch LSPClientError.notInitialized {
            // expected
        } catch {
            #expect(Bool(false), "expected .notInitialized; got \(error)")
        }

        do {
            try await client.didChange(uri: url, version: 2, fullText: "")
            #expect(Bool(false), "didChange before initialize MUST throw")
        } catch LSPClientError.notInitialized {
            // expected
        } catch {
            #expect(Bool(false), "expected .notInitialized; got \(error)")
        }

        do {
            try await client.didClose(uri: url)
            #expect(Bool(false), "didClose before initialize MUST throw")
        } catch LSPClientError.notInitialized {
            // expected
        } catch {
            #expect(Bool(false), "expected .notInitialized; got \(error)")
        }

        do {
            _ = try await client.hover(uri: url, line: 0, character: 0)
            #expect(Bool(false), "hover before initialize MUST throw")
        } catch LSPClientError.notInitialized {
            // expected
        } catch {
            #expect(Bool(false), "expected .notInitialized; got \(error)")
        }

        do {
            _ = try await client.definition(uri: url, line: 0, character: 0)
            #expect(Bool(false), "definition before initialize MUST throw")
        } catch LSPClientError.notInitialized {
            // expected
        } catch {
            #expect(Bool(false), "expected .notInitialized; got \(error)")
        }

        await stub.shutdown()
    }
}
