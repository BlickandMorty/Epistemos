import Testing
import Foundation

@testable import Epistemos

// SS-LT local multi-tool reliability (owner: "intent recognized... worked once then never"), at the
// ARGUMENT level. A local tool call's arguments are matched to the tool's JSON-schema property names
// by LocalAgentLoop.canonicalizeArguments. It used to match arg keys by lowercase only — so a model
// emitting `file_path` when the schema declares `filePath` would NOT match: the value lands under an
// unknown key while the required property stays missing, and the tool misbehaves or errors. Local
// models vary arg-key separators/casing constantly. These pin the new separator/case-insensitive
// arg-key normalization (a previously untested path) and confirm pass-through + no-schema behavior.
@Suite("LocalAgentLoop.canonicalizeArguments — schema-aware arg-key normalization")
struct CanonicalizeArgumentsTests {

    private let schema = #"{"type":"object","properties":{"filePath":{"type":"string"},"maxResults":{"type":"integer"}}}"#

    @Test("separator + case variants of an arg key map to the schema's canonical key")
    func argKeyVariantsNormalize() {
        for variant in ["file_path", "file-path", "filepath", "FILE_PATH", "FilePath", "filePath"] {
            let out = LocalAgentLoop.canonicalizeArguments([variant: "/notes/x.md"], schemaJson: schema)
            #expect(out["filePath"] as? String == "/notes/x.md", "\(variant) should normalize to filePath")
            #expect(out.count == 1, "\(variant) should produce exactly one (canonical) key")
        }
    }

    @Test("multiple args normalize together; values preserved")
    func multipleArgs() {
        let out = LocalAgentLoop.canonicalizeArguments(
            ["file_path": "/x", "max_results": 5], schemaJson: schema)
        #expect(out["filePath"] as? String == "/x")
        #expect(out["maxResults"] as? Int == 5)
        #expect(out.count == 2)
    }

    @Test("an unknown arg key (not in schema) is passed through unchanged")
    func unknownKeyPassThrough() {
        let out = LocalAgentLoop.canonicalizeArguments(["totally_unknown": 1], schemaJson: schema)
        #expect(out["totally_unknown"] as? Int == 1)
    }

    @Test("no schema / empty properties → arguments returned unchanged")
    func noSchemaPassThrough() {
        let out = LocalAgentLoop.canonicalizeArguments(["anything": "v"], schemaJson: "{}")
        #expect(out["anything"] as? String == "v")
        #expect(out.count == 1)
    }

    // Type coercion: local models frequently quote scalars (`{"limit": "10"}`, `"true"`); coerce a
    // STRING to the schema's declared scalar type so a strict tool executor doesn't reject it.
    private let typedSchema = #"{"type":"object","properties":{"limit":{"type":"integer"},"ratio":{"type":"number"},"recursive":{"type":"boolean"},"query":{"type":"string"}}}"#

    @Test("a quoted integer/number/boolean is coerced to the schema's scalar type (key variant too)")
    func coercesQuotedScalars() {
        let out = LocalAgentLoop.canonicalizeArguments(
            ["limit": "10", "ratio": "0.5", "RECURSIVE": "true"], schemaJson: typedSchema)
        #expect(out["limit"] as? Int == 10)
        #expect(out["ratio"] as? Double == 0.5)
        #expect(out["recursive"] as? Bool == true)  // key normalized (RECURSIVE→recursive) AND value coerced
    }

    @Test("boolean accepts true/false/yes/no/1/0; a string-typed field is left as a string")
    func booleanAndStringHandling() {
        #expect(LocalAgentLoop.canonicalizeArguments(["recursive": "no"], schemaJson: typedSchema)["recursive"] as? Bool == false)
        #expect(LocalAgentLoop.canonicalizeArguments(["recursive": "1"], schemaJson: typedSchema)["recursive"] as? Bool == true)
        // A schema-string field keeps its string value (no coercion).
        #expect(LocalAgentLoop.canonicalizeArguments(["query": "5"], schemaJson: typedSchema)["query"] as? String == "5")
    }

    @Test("an already-typed value and an unparseable string are left unchanged (safe)")
    func unparseableAndAlreadyTypedUntouched() {
        // Already an Int → unchanged.
        #expect(LocalAgentLoop.canonicalizeArguments(["limit": 7], schemaJson: typedSchema)["limit"] as? Int == 7)
        // "ten" can't parse to an integer → left as the original string (no data loss / no crash).
        #expect(LocalAgentLoop.canonicalizeArguments(["limit": "ten"], schemaJson: typedSchema)["limit"] as? String == "ten")
    }
}
