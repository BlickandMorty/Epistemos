import Testing
import Foundation

@testable import Epistemos

// SS-PERF2 #1 (owner 2026-06-20, explicitly authorized): the tool-definitions JSON that
// ChatCoordinator embeds in the prompt every tool turn is now serialized COMPACT
// (.sortedKeys only, no .prettyPrinted). Pretty whitespace was pure wasted INPUT tokens.
// The model parses the identical structure either way — only whitespace is dropped.
@Suite("SS-PERF2 compact tool-schema JSON")
struct SSPERF2ToolSchemaCompactTests {

    private var sampleSchemas: [[String: Any]] {
        [
            ["name": "search", "type": "object",
             "properties": ["q": ["type": "string"], "limit": ["type": "integer"]]],
            ["name": "write_note", "type": "object",
             "required": ["path", "content"],
             "properties": ["path": ["type": "string"], "content": ["type": "string"]]],
        ]
    }

    @Test("compact serialization is smaller but parses to an identical structure")
    func compactParsesIdentically() throws {
        let pretty = try JSONSerialization.data(
            withJSONObject: sampleSchemas, options: [.prettyPrinted, .sortedKeys])
        let compact = try JSONSerialization.data(
            withJSONObject: sampleSchemas, options: [.sortedKeys])

        // Strictly fewer bytes (the dropped whitespace == saved input tokens).
        #expect(compact.count < pretty.count)

        // Both parse back to the same object → the model sees the same tools. Re-serialize
        // each parsed object with .sortedKeys and compare bytes (a robust deep-equal).
        let prettyObj = try JSONSerialization.jsonObject(with: pretty)
        let compactObj = try JSONSerialization.jsonObject(with: compact)
        let reSerPretty = try JSONSerialization.data(withJSONObject: prettyObj, options: [.sortedKeys])
        let reSerCompact = try JSONSerialization.data(withJSONObject: compactObj, options: [.sortedKeys])
        #expect(reSerPretty == reSerCompact)
    }

    @Test("the tool-definitions serializer no longer pretty-prints")
    func toolDefinitionsSerializerIsCompact() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")
        // The schemas serialization must be compact (.sortedKeys only) — not pretty.
        #expect(src.contains("withJSONObject: schemas,\n        options: [.sortedKeys]"))
        #expect(!src.contains("withJSONObject: schemas,\n        options: [.prettyPrinted, .sortedKeys]"))
    }
}
