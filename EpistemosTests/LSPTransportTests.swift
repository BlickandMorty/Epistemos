import Testing
import Foundation
@testable import Epistemos

/// V2.3 — protocol-seam tests for `LSPTransport` and the
/// `InProcessLSPTransport` test double. Proves that:
///
/// 1. `LSPClient` constructed against the in-process test transport can route
///    a request end-to-end and receive the canonical MethodNotFound
///    error response.
/// 2. The test transport's diagnostic send-log records every outgoing message
///    in order — the audit hook the future doctrine linter / debug
///    surface will read.
@Suite("LSP Transport seam (V2.3 first slice)")
struct LSPTransportTests {

    @Test("InProcessLSPTransport test double satisfies LSPTransport")
    func testTransportSatisfiesProtocol() async {
        let transport = InProcessLSPTransport()
        // Type-check: the test transport is assignable to `any LSPTransport`.
        let _: any LSPTransport = transport
        // Initial send count is zero.
        let initial = await transport.sentCount()
        #expect(initial == 0)
    }

    @Test("LSPClient against in-process test transport gets MethodNotFound for any request")
    func clientAgainstTestTransportGetsMethodNotFound() async throws {
        let transport = InProcessLSPTransport()
        let client = LSPClient(transport: transport)
        await client.startRouting()

        // Pick a method the test transport will refuse — `initialize`
        // happens to be the first thing any LSPClient sends in
        // production. This actor returns -32601 (MethodNotFound) for
        // every request.
        do {
            _ = try await client.initialize(workspaceRoot: URL(fileURLWithPath: "/tmp/test"))
            Issue.record("expected test transport to reject initialize with MethodNotFound, but it returned a result")
        } catch let LSPClientError.serverError(error) {
            #expect(error.code == -32601, "test transport must use JSON-RPC MethodNotFound (-32601), got \(error.code)")
            #expect(
                error.message.contains("InProcessLSPTransport test transport"),
                "test transport error message must self-identify; got: \(error.message)"
            )
        }
    }

    @Test("InProcessLSPTransport records every send in the audit log")
    func testTransportRecordsEverySendInAuditLog() async throws {
        let transport = InProcessLSPTransport()
        // Send a notification + a request through the test transport directly
        // (bypassing LSPClient so we can assert raw recording).
        try await transport.send(.notification(method: "test/notif", params: nil))
        try await transport.send(.request(id: .int(42), method: "test/req", params: nil))
        let log = await transport.sentLogSnapshot()
        #expect(log.count == 2)
        // First message is the notification.
        if case .notification(let method, _) = log[0] {
            #expect(method == "test/notif")
        } else {
            Issue.record("expected notification at index 0, got: \(log[0])")
        }
        // Second message is the request.
        if case .request(_, let method, _) = log[1] {
            #expect(method == "test/req")
        } else {
            Issue.record("expected request at index 1, got: \(log[1])")
        }
    }

    @Test("LSP transport source labels the in-process fallback as test-only")
    func inProcessTransportSourceLabelsAreTestOnly() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/LSPTransport.swift")

        #expect(source.contains("InProcessLSPTransport test double"))
        #expect(source.contains("Production callers use `RustLSPTransport`"))
        #expect(source.contains("InProcessLSPTransport test transport"))
        #expect(!source.contains("InProcessLSPTransport stub"))
        #expect(!source.contains("not implemented yet"))
        #expect(!source.contains("tower-lsp Rust transport lands"))
    }

}
