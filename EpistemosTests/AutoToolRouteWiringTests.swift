import Testing
import Foundation
@testable import Epistemos

/// Tools/skills part 2 — AUTO-ROUTE live-wiring (owner 2026-06-19): the deterministic
/// Rust tool-need detector (`schema_auto_tool_route_json`, flag `EPISTEMOS_AUTO_TOOL_ROUTE_V0`)
/// is now consulted by `PipelineService.shouldUseToolLoop` for a plain query (no execution
/// plan) so "find my note about X" keeps the tool loop (vault.search) while pure chat
/// direct-streams. These tests pin the pure Swift marshaling + parsing surface of that
/// wiring deterministically — no FFI, no env flag, no in-app run (the detector's own
/// selection logic is covered by the Rust unit tests in tool_preflight.rs).
@Suite("Auto-route tool-need wiring")
struct AutoToolRouteWiringTests {

    private func tool(_ name: String, _ description: String) -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: name,
            agent: "rust",
            description: description,
            argumentsExample: "{}",
            schemaJson: "{}",
            destructive: false,
            requiresConfirmation: false
        )
    }

    @Test("candidate JSON carries name + description for each tool, in Rust PreflightToolInput shape")
    func candidatesJSONShape() throws {
        let tools = [
            tool("vault.search", "Search the user's notes vault"),
            tool("web.search", "Search the web for information"),
        ]
        let json = try #require(PipelineService.autoRouteCandidatesJSON(tools: tools))
        let data = try #require(json.data(using: .utf8))
        let parsed = try #require(
            try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        )
        #expect(parsed.count == 2)
        #expect(parsed.first?["name"] as? String == "vault.search")
        #expect(parsed.first?["description"] as? String == "Search the user's notes vault")
        // keywords present (default empty) so the Rust serde shape matches exactly.
        #expect(parsed.first?["keywords"] as? [String] == [])
    }

    @Test("empty catalog yields nil candidate JSON (caller keeps its existing decision)")
    func candidatesJSONEmpty() {
        #expect(PipelineService.autoRouteCandidatesJSON(tools: []) == nil)
    }

    @Test("verdict parser reads needs_tools true")
    func verdictTrue() {
        #expect(
            PipelineService.parseAutoRouteVerdict(
                "{\"needs_tools\":true,\"tools\":[\"vault.search\"]}"
            ) == true
        )
    }

    @Test("verdict parser reads needs_tools false")
    func verdictFalse() {
        #expect(
            PipelineService.parseAutoRouteVerdict(
                "{\"needs_tools\":false,\"tools\":[]}"
            ) == false
        )
    }

    @Test("verdict parser returns nil for malformed / missing-key payloads (keeps existing decision)")
    func verdictMalformed() {
        #expect(PipelineService.parseAutoRouteVerdict("not json at all") == nil)
        #expect(PipelineService.parseAutoRouteVerdict("{\"other\":1}") == nil)
        #expect(PipelineService.parseAutoRouteVerdict("") == nil)
    }

    @Test("flag is OFF by default → the tool-loop decision is unchanged")
    func flagDefaultsOff() {
        // Default process environment has no EPISTEMOS_AUTO_TOOL_ROUTE_V0 → armed == false,
        // so shouldUseToolLoop never loads candidates / consults the detector.
        if ProcessInfo.processInfo.environment["EPISTEMOS_AUTO_TOOL_ROUTE_V0"] == nil {
            #expect(PipelineService.autoToolRouteArmed == false)
        }
    }

    // MARK: - GGUF-Gemma grammar tool-call dispatch (part 2b Swift input builder)

    @Test("GGUF dispatch candidate JSON carries name + description + keywords + embedded schema object")
    func ggufDispatchCandidatesShape() throws {
        let tools = [
            OmegaToolDefinition(
                name: "vault.search",
                agent: "rust",
                description: "Search the notes vault",
                argumentsExample: "{}",
                schemaJson: "{\"type\":\"object\",\"properties\":{\"query\":{\"type\":\"string\"}}}",
                destructive: false,
                requiresConfirmation: false
            )
        ]
        let json = try #require(PipelineService.ggufDispatchCandidatesJSON(tools: tools))
        let data = try #require(json.data(using: .utf8))
        let parsed = try #require(
            try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        )
        #expect(parsed.first?["name"] as? String == "vault.search")
        // The schema is embedded as a real JSON OBJECT (not a string) so the Rust
        // PreflightToolWithSchemaInput.schema deserializes to an object schema.
        let schema = try #require(parsed.first?["schema"] as? [String: Any])
        #expect(schema["type"] as? String == "object")
        #expect(parsed.first?["keywords"] as? [String] == [])
    }

    @Test("GGUF dispatch builder falls back to an empty object schema for malformed schemaJson")
    func ggufDispatchMalformedSchemaFallsBack() throws {
        let tools = [
            OmegaToolDefinition(
                name: "noop",
                agent: "rust",
                description: "no params",
                argumentsExample: "{}",
                schemaJson: "not valid json",
                destructive: false,
                requiresConfirmation: false
            )
        ]
        let json = try #require(PipelineService.ggufDispatchCandidatesJSON(tools: tools))
        let data = try #require(json.data(using: .utf8))
        let parsed = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let schema = try #require(parsed.first?["schema"] as? [String: Any])
        #expect(schema["type"] as? String == "object")
        #expect(schema["additionalProperties"] as? Bool == false)
    }

    @Test("empty tool catalog yields nil GGUF dispatch candidates JSON")
    func ggufDispatchEmpty() {
        #expect(PipelineService.ggufDispatchCandidatesJSON(tools: []) == nil)
    }

    @Test("GGUF tool-grammar flag is OFF by default → no dispatch schema computed")
    func ggufFlagDefaultsOff() {
        if ProcessInfo.processInfo.environment["EPISTEMOS_GGUF_TOOL_GRAMMAR_V0"] == nil {
            #expect(PipelineService.ggufToolGrammarArmed == false)
            // Flag off → ggufToolDispatchSchema short-circuits to nil regardless of tools.
            let tools = [
                OmegaToolDefinition(
                    name: "vault.search", agent: "rust", description: "Search",
                    argumentsExample: "{}", schemaJson: "{}", destructive: false,
                    requiresConfirmation: false
                )
            ]
            #expect(PipelineService.ggufToolDispatchSchema(query: "find my note", tools: tools) == nil)
        }
    }
}
