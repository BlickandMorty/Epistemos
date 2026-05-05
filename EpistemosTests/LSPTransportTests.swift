import Testing
import Foundation
@testable import Epistemos

/// V2.3 first slice — protocol-seam tests for `LSPTransport` and the
/// `InProcessLSPTransport` stub. Proves that:
///
/// 1. `LSPClient` constructed against the in-process stub can route
///    a request end-to-end and receive the canonical MethodNotFound
///    error response (the stub's terminal behavior until tower-lsp
///    arrives).
/// 2. `LSPServerProcess` satisfies the protocol via the empty
///    extension conformance.
/// 3. The stub's diagnostic send-log records every outgoing message
///    in order — the audit hook the future doctrine linter / debug
///    surface will read.
@Suite("LSP Transport seam (V2.3 first slice)")
struct LSPTransportTests {

    @Test("InProcessLSPTransport stub satisfies LSPTransport")
    func stubSatisfiesProtocol() async {
        let stub = InProcessLSPTransport()
        // Type-check: the stub is assignable to `any LSPTransport`.
        let _: any LSPTransport = stub
        // Initial send count is zero.
        let initial = await stub.sentCount()
        #expect(initial == 0)
    }

    @Test("LSPServerProcess satisfies LSPTransport via empty extension")
    func serverProcessSatisfiesProtocol() {
        let config = LSPServerConfig(
            executableURL: URL(fileURLWithPath: "/usr/bin/false"),
            arguments: [],
            workingDirectory: nil,
            environment: [:]
        )
        let proc = LSPServerProcess(config: config)
        let _: any LSPTransport = proc
        // No assertion needed — the type-check IS the test.
    }

    @Test("LSPClient against in-process stub gets MethodNotFound for any request")
    func clientAgainstStubGetsMethodNotFound() async throws {
        let stub = InProcessLSPTransport()
        let client = LSPClient(transport: stub)
        await client.startRouting()

        // Pick a method the stub will refuse — `initialize` happens to
        // be the first thing any LSPClient sends in production. The
        // stub returns -32601 (MethodNotFound) for every request.
        do {
            _ = try await client.initialize(workspaceRoot: URL(fileURLWithPath: "/tmp/test"))
            Issue.record("expected stub to reject initialize with MethodNotFound, but it returned a result")
        } catch let LSPClientError.serverError(error) {
            #expect(error.code == -32601, "stub must use JSON-RPC MethodNotFound (-32601), got \(error.code)")
            #expect(
                error.message.contains("InProcessLSPTransport stub"),
                "stub error message must self-identify; got: \(error.message)"
            )
        }
    }

    @Test("InProcessLSPTransport records every send in the audit log")
    func stubRecordsEverySendInAuditLog() async throws {
        let stub = InProcessLSPTransport()
        // Send a notification + a request through the stub directly
        // (bypassing LSPClient so we can assert raw recording).
        try await stub.send(.notification(method: "test/notif", params: nil))
        try await stub.send(.request(id: .int(42), method: "test/req", params: nil))
        let log = await stub.sentLogSnapshot()
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

    @Test("LSPClient backward-compat init(process:) still works")
    func backwardCompatProcessInitStillWorks() {
        let config = LSPServerConfig(
            executableURL: URL(fileURLWithPath: "/usr/bin/false"),
            arguments: [],
            workingDirectory: nil,
            environment: [:]
        )
        let proc = LSPServerProcess(config: config)
        // Pre-V2.3 call site: LSPClient(process:). Must still compile
        // and produce a working client whose .process accessor returns
        // the same instance.
        let client = LSPClient(process: proc)
        Task {
            let p = await client.process
            #expect(p === proc)
        }
    }

    @Test("LSPClient.process returns nil when transport is not LSPServerProcess")
    func processAccessorReturnsNilForInProcessTransport() async {
        let stub = InProcessLSPTransport()
        let client = LSPClient(transport: stub)
        let p = await client.process
        #expect(p == nil, "process accessor must return nil for non-LSPServerProcess transports")
    }
}
