import Testing
import Foundation
@testable import Epistemos

/// V2.3 Stage D — end-to-end tests for the RustLSPTransport.
///
/// Proves the architectural seam works end-to-end:
///   Swift LSPClient → Swift RustLSPTransport → Rust FFI
///   → Rust LspKernel → initialize handshake roundtrip
///
/// Covers the semantic LSP path: tower-lsp response payloads on the Rust
/// side plus tree-sitter-backed document sync, hover, and same-file
/// definition lookup. This is the canonical replacement for the deleted
/// subprocess transport.
@Suite("RustLSPTransport end-to-end (V2.3 Stage D)")
struct RustLSPTransportTests {

    @Test("RustLSPTransport satisfies LSPTransport protocol")
    func transportSatisfiesProtocol() async {
        let transport = RustLSPTransport()
        let _: any LSPTransport = transport
        await transport.shutdown()
    }

    @Test("LSPClient against RustLSPTransport completes initialize handshake")
    func clientAgainstRustTransportInitializes() async throws {
        #if canImport(agent_coreFFI)
        let transport = RustLSPTransport()
        await transport.startPolling()

        let client = LSPClient(transport: transport)
        await client.startRouting()

        // The Rust LspKernel returns capabilities + serverInfo on
        // initialize. The Swift LSPClient.initialize unwraps that
        // into LSPInitializeResult.
        let result = try await client.initialize(
            workspaceRoot: URL(fileURLWithPath: "/tmp/test-workspace")
        )
        // The Rust side declares textDocumentSync + hoverProvider +
        // definitionProvider; the result.capabilities is round-tripped
        // through LSPJSONValue, so just sanity-check the encoding.
        let json = try JSONEncoder().encode(result.capabilities)
        let str = String(data: json, encoding: .utf8) ?? ""
        #expect(str.contains("textDocumentSync"), "expected capabilities to include textDocumentSync; got: \(str)")
        #expect(str.contains("hoverProvider"), "expected capabilities to include hoverProvider")
        #expect(str.contains("definitionProvider"), "expected capabilities to include definitionProvider")

        await transport.shutdown()
        #else
        // FFI not linked — the stub init throws on send, so we just
        // verify the type-check succeeds + shutdown is a no-op.
        let transport = RustLSPTransport()
        await transport.shutdown()
        #endif
    }

    @Test("RustLSPTransport surfaces lifecycle state via FFI")
    func transportLifecycleState() async {
        let transport = RustLSPTransport()
        // Diagnostic accessor is `nonisolated` so callable without await.
        let state = transport.lifecycleStateDebug()
        // Either the live FFI returns a state string OR the stub
        // returns "ffi_unavailable". Either way, the call succeeds.
        #expect(!state.isEmpty)
        await transport.shutdown()
    }

    @Test("RustLSPTransport rejects send after shutdown")
    func transportRejectsSendAfterShutdown() async {
        let transport = RustLSPTransport()
        await transport.shutdown()
        do {
            try await transport.send(.notification(method: "anything", params: nil))
            Issue.record("expected RustLSPTransportError on send-after-shutdown")
        } catch RustLSPTransportError.transportShutdown {
            // expected
        } catch RustLSPTransportError.ffiCallFailed {
            // also acceptable: stub mode throws ffiCallFailed because
            // FFI isn't linked.
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test("RustLSPTransport shutdown is idempotent")
    func transportShutdownIsIdempotent() async {
        let transport = RustLSPTransport()
        await transport.shutdown()
        await transport.shutdown() // second call must not crash
        // No assertion needed beyond "this didn't throw or hang."
    }

    @Test("RustLSPTransport returns tree-sitter hover and definition")
    func rustTransportReturnsSemanticHoverAndDefinition() async throws {
        #if canImport(agent_coreFFI)
        let transport = RustLSPTransport(pollIntervalNanos: 1_000_000)
        await transport.startPolling()

        let client = LSPClient(transport: transport)
        await client.startRouting()
        _ = try await client.initialize(
            workspaceRoot: URL(fileURLWithPath: "/tmp/semantic-workspace")
        )

        let uri = URL(fileURLWithPath: "/tmp/semantic.rs")
        let text = "fn answer() -> i32 { 42 }\nfn main() { answer(); }\n"
        try await client.didOpen(
            uri: uri,
            languageId: "rust",
            version: 1,
            text: text
        )

        let hover = try await client.hover(uri: uri, line: 1, character: 12)
        #expect(hover?.contents.contains("answer") == true)
        #expect(hover?.contents.contains("function_item") == true)
        #expect(hover?.contents.contains("fn answer()") == true)

        let definitions = try await client.definition(uri: uri, line: 1, character: 12)
        #expect(definitions.first?.uri == uri.absoluteString)
        #expect(definitions.first?.range.start.line == 0)
        #expect(definitions.first?.range.start.character == 3)

        await transport.shutdown()
        #else
        let transport = RustLSPTransport()
        await transport.shutdown()
        #endif
    }
}
