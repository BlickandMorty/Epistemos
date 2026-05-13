import Testing
import Foundation
@testable import Epistemos

/// RCA-P1-017 drift gate — MCP execution truth must match advertisement.
///
/// Acceptance criterion: "No MCP tool is advertised as runnable
/// unless execution exists in the current target."
///
/// Structural reality (verified 2026-05-13):
///   1. `OmegaToolRegistry` derives its catalog from the Rust
///      `omega-mcp::builtinToolsJson()` export. The Swift side is
///      a decoded cache, not an independent inventory.
///   2. `MCPBridge.dispatch(_:)` is the canonical execution path:
///      it routes the JSON-RPC request through the Rust dispatcher
///      after the `ToolSurfacePolicy` gate. There is NO TODO stub
///      in the production path.
///   3. The `ToolSurfacePolicy` gate hides any tool that isn't
///      surfaced for the current distribution (MAS vs Pro), and
///      returns a `-32601 Tool not found` JSON-RPC error if a
///      hidden tool is invoked.
///
/// This suite pins those three invariants so a future refactor that
/// introduces a TODO stub or skips the policy gate trips CI.
@Suite("RCA-P1-017 MCP Execution Truth Guard")
struct MCPExecutionTruthGuardTests {

    @Test("MCPBridge.dispatch routes through the Rust dispatcher, not a TODO stub")
    func dispatchRoutesThroughRustDispatcher() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Omega/MCPBridge.swift"
        )
        // The dispatch function must call into the Rust dispatcher.
        #expect(source.contains("dispatcher?.dispatch(requestJson:"),
            "MCPBridge.dispatch must call into the Rust dispatcher; if you find a TODO stub instead, RCA-P1-017 has regressed")
        // The function must NOT carry an unimplemented TODO marker
        // anywhere inside its body. We search the file for the
        // dangerous `// TODO: implement` pattern that signals a
        // half-wired execution path.
        let dangerousTodoMarkers = [
            "// TODO: implement dispatch",
            "// TODO: wire dispatcher",
            "// TODO: execute MCP",
        ]
        for marker in dangerousTodoMarkers {
            #expect(!source.contains(marker),
                "MCPBridge must not contain `\(marker)` — the audit acceptance for RCA-P1-017 is that execution truth matches advertisement")
        }
    }

    @Test("OmegaToolRegistry sources its catalog from the Rust builtinToolsJson() FFI")
    func registrySourcesFromRustFFI() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Omega/MCPBridge.swift"
        )
        // The Swift-side registry must be a decoded view of the Rust
        // truth. If a future commit replaces this with a hand-curated
        // Swift list, the catalog can drift from the actual executable
        // tools and the audit acceptance fails.
        #expect(source.contains("builtinToolsJson()"),
            "OmegaToolRegistry must derive its catalog from the Rust `builtinToolsJson()` export so advertised tools and executable tools stay in lockstep")
        #expect(source.contains("single source of truth"),
            "OmegaToolRegistry doctrine comment must retain its single-source-of-truth claim — see RCA-P1-017")
    }

    @Test("ToolSurfacePolicy gate fires before dispatch")
    func policyGatePrecedesDispatch() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Omega/MCPBridge.swift"
        )
        // The gate must return early when a tool isn't surfaced in
        // the current distribution. The audit's concern is that a
        // tool advertised in tools/list but hidden by distribution
        // gating could still execute via tools/call. The
        // ToolSurfacePolicy.isSurfacedToolName check defends against
        // that. Pinned by string match here so a future refactor that
        // skips the gate fails the test.
        #expect(source.contains("ToolSurfacePolicy.isSurfacedToolName"),
            "MCPBridge.dispatch must consult ToolSurfacePolicy before reaching the Rust dispatcher — see RCA-P1-017 acceptance")
        // The denial path returns a JSON-RPC error, not silent
        // success. -32601 is the standard "method not found" error
        // code used by JSON-RPC implementations to signal a denied
        // tool call.
        #expect(source.contains("code: -32601"),
            "MCPBridge must return the JSON-RPC -32601 (method not found) error when ToolSurfacePolicy denies a tool call — see RCA-P1-017")
    }
}
