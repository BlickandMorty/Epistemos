import Testing
import Foundation
@testable import Epistemos

/// P8.2 — the live-path RAG preflight tool narrowing seam.
///
/// The load-bearing guarantee is **OFF = passthrough**: with the flag unset (its state in
/// the test host) the local agent turn must see the EXACT tool list it sees today, so
/// wiring the preflight in cannot regress Chat/Act. The remaining tests pin the flag-name
/// parity with Rust and the JSON envelope contract.
@Suite("Schema preflight tool narrowing (P8.2)")
struct SchemaPreflightToolNarrowingTests {

    private func tool(_ name: String, _ description: String) -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: name,
            agent: "test",
            description: description,
            argumentsExample: "{}",
            schemaJson: "{\"type\":\"object\",\"properties\":{}}",
            destructive: false,
            requiresConfirmation: false
        )
    }

    @Test("OFF (default) is a byte-for-byte passthrough — the agent sees every tool")
    func offIsPassthrough() {
        // The flag is unset in the test host, so isEnabled is false.
        #expect(SchemaPreflightToolNarrowing.isEnabled == false)
        let tools = [tool("read_file", "Read a file"),
                     tool("web_search", "Search the web"),
                     tool("vault_search", "Search notes")]
        let narrowed = SchemaPreflightToolNarrowing.narrow(tools, forObjective: "read my file")
        #expect(narrowed.count == tools.count)
        #expect(narrowed.map(\.name) == tools.map(\.name))
    }

    @Test("an empty tool list narrows to empty (never crashes)")
    func emptyToolsIsSafe() {
        #expect(SchemaPreflightToolNarrowing.narrow([], forObjective: "anything").isEmpty)
    }

    @Test("the Swift flag name matches the Rust SCHEMA_PREFLIGHT_FLAG constant")
    func crossRuntimeFlagParity() throws {
        #expect(SchemaPreflightToolNarrowing.flagName == "EPISTEMOS_SCHEMA_PREFLIGHT_V0")
        let rust = try loadMirroredSourceTextFile("agent_core/src/tool_preflight.rs")
        // The Rust constant is the single source of truth; pin Swift to its literal.
        #expect(rust.contains("SCHEMA_PREFLIGHT_FLAG: &str = \"\(SchemaPreflightToolNarrowing.flagName)\""))
    }

    @Test("encodeCandidates emits a name+description array the Rust PreflightToolInput accepts")
    func encodeCandidatesShape() throws {
        let json = try #require(SchemaPreflightToolNarrowing.encodeCandidates([tool("read_file", "Read a file")]))
        let parsed = try #require(
            JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: String]]
        )
        #expect(parsed.first?["name"] == "read_file")
        #expect(parsed.first?["description"] == "Read a file")
    }

    @Test("decodeNames parses a names array and rejects garbage honestly")
    func decodeNamesContract() {
        #expect(SchemaPreflightToolNarrowing.decodeNames("[\"read_file\",\"vault_search\"]") == ["read_file", "vault_search"])
        #expect(SchemaPreflightToolNarrowing.decodeNames("not json") == nil)
        #expect(SchemaPreflightToolNarrowing.decodeNames("{\"oops\":1}") == nil)
    }

    @Test("the narrowing is wired into the live LocalAgentLoop turn at the canonicalization point")
    func wiredIntoLiveLoop() throws {
        let loop = try loadMirroredSourceTextFile("Epistemos/LocalAgent/LocalAgentLoop.swift")
        #expect(loop.contains("SchemaPreflightToolNarrowing.narrow("))
        #expect(loop.contains("AgentToolNameAliases.canonicalizedDefinitions(for: tools)"))
    }
}
