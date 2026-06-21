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
}
