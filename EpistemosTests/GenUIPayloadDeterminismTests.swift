import Foundation
import Testing

@testable import Epistemos

/// GenUI determinism contracts.
///
/// Per `docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` §6 + the
/// salvaged `QUICK_CAPTURE_IMPLEMENTATION_PLAN.md` §1.4 (no-LLM-first /
/// deterministic variant ladder discipline), the GenUI surface must be
/// deterministic in three places:
///
/// 1. **Content equality is content-based, not identity-based.** Two
///    payloads with identical (schema, title, body, metadata) must
///    compare `==` even if they have distinct `id` UUIDs and different
///    `createdAt` timestamps. Without this, SwiftUI re-renders on
///    every emit and replay tooling sees false drift.
/// 2. **Hashing is deterministic across runs.** Swift's Dictionary
///    iteration is randomized per-process per-launch, so hashing
///    `metadata` directly would produce different hashes for identical
///    content across runs. The custom `hash(into:)` iterates sorted
///    metadata keys to fix this.
/// 3. **Canonical JSON encoding is byte-stable.** The canonical
///    `JSONEncoder` uses `.sortedKeys + .prettyPrinted` so snapshot
///    tests and the FallbackGenUIView surface produce identical bytes
///    across runs.
@Suite("GenUI payload determinism (Stage A.2)")
struct GenUIPayloadDeterminismTests {

    @Test("Identical content compares equal even with different id + createdAt")
    func identicalContentEquatableIgnoresIdAndTimestamp() {
        let a = GenUIPayload.keyValueTable(
            title: "Status",
            [("model", "claude_sonnet"), ("mode", "agent")],
            id: "id-a",
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
        let b = GenUIPayload.keyValueTable(
            title: "Status",
            [("model", "claude_sonnet"), ("mode", "agent")],
            id: "id-b",
            createdAt: Date(timeIntervalSinceReferenceDate: 1_000_000)
        )

        #expect(a == b, """
            Two payloads with identical content but different id/createdAt \
            must compare equal. id and createdAt are instance metadata, \
            not content — without this contract SwiftUI re-renders on \
            every emit and replay tooling sees spurious drift.
            """)
        #expect(a.id != b.id, "Sanity check — these instances do have distinct ids")
    }

    @Test("Different content compares unequal")
    func differentContentEquatableTrips() {
        let a = GenUIPayload.keyValueTable(title: "Status", [("model", "claude")])
        let b = GenUIPayload.keyValueTable(title: "Status", [("model", "kimi")])
        #expect(a != b, "Different body content must produce inequality")

        let c = GenUIPayload.keyValueTable(title: "Tokens", [("model", "claude")])
        #expect(a != c, "Different title must produce inequality")
    }

    @Test("Hashing is deterministic across runs (sorted metadata keys)")
    func hashingIsDeterministicAcrossMetadataKeyOrder() {
        // Both payloads have the same metadata content, but the
        // dictionary literals could iterate in different orders. The
        // custom hash(into:) sorts keys to make hashes stable.
        let a = GenUIPayload(
            schema: .keyValueTable,
            title: "x",
            body: .keyValues([GenUIKeyValue("k", "v")]),
            metadata: ["b": "2", "a": "1", "c": "3"]
        )
        let b = GenUIPayload(
            schema: .keyValueTable,
            title: "x",
            body: .keyValues([GenUIKeyValue("k", "v")]),
            metadata: ["c": "3", "a": "1", "b": "2"]
        )
        #expect(a == b, "Same metadata in different literal order must compare equal")
        #expect(a.hashValue == b.hashValue, "Same metadata in different literal order must hash equal")
    }

    @Test("Canonical JSON encoding is byte-stable")
    func canonicalJSONEncodingIsByteStable() throws {
        let payload = GenUIPayload.keyValueTable(
            title: "Config",
            [("model", "claude"), ("mode", "agent"), ("incognito", "false")],
            id: "fixed-id",
            metadata: ["query": "status", "session": "abc123"],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
        let encoder = GenUIPayload.canonicalJSONEncoder()
        let bytes1 = try encoder.encode(payload)
        let bytes2 = try encoder.encode(payload)
        #expect(bytes1 == bytes2, "Canonical encoder must produce byte-identical output across calls")

        let text = String(data: bytes1, encoding: .utf8) ?? ""
        // sortedKeys puts createdAt before id before metadata before schema before title
        // (alphabetical by JSON key). This is the contract the snapshot tests rely on.
        let createdAtPos = text.range(of: "\"createdAt\"")?.lowerBound
        let idPos = text.range(of: "\"id\"")?.lowerBound
        let schemaPos = text.range(of: "\"schema\"")?.lowerBound
        let titlePos = text.range(of: "\"title\"")?.lowerBound

        #expect(createdAtPos != nil && idPos != nil && schemaPos != nil && titlePos != nil,
                "Encoded payload must contain all top-level fields")
        if let createdAtPos, let idPos, let schemaPos, let titlePos {
            #expect(createdAtPos < idPos && idPos < schemaPos && schemaPos < titlePos,
                    "sortedKeys must produce alphabetical JSON key order")
        }
    }

    @Test("Dispatcher.registeredSchemas is sorted (stable iteration)")
    @MainActor
    func dispatcherRegisteredSchemasIsSorted() {
        let schemas = GenUIDispatcher.shared.registeredSchemas
        let sortedRawValues = schemas.map(\.rawValue)
        let resorted = sortedRawValues.sorted()
        #expect(sortedRawValues == resorted,
                "registeredSchemas must return a sorted array (NOT a Set) so iteration is replayable")
    }

    @Test("Dispatcher covers every GenUISchema case (no missing branch)")
    @MainActor
    func dispatcherCoversEverySchemaCase() {
        let registered = Set(GenUIDispatcher.shared.registeredSchemas)
        let allCases = Set(GenUISchema.allCases)
        #expect(registered == allCases,
                "GenUIDispatcher.render switch must have a branch for every GenUISchema case")
    }

    @Test("Every GenUISchema case has at least one canonical body pairing")
    func everySchemaCaseHasACanonicalBodyPairing() {
        // The `canonicalBody(_:)` switch routes each GenUISchema to
        // its expected GenUIBody case. Adding a new schema variant
        // without updating canonicalBody would silently fall through
        // to `default` → return false → every payload of that schema
        // would render as FallbackGenUIView with no surface-side
        // signal that the schema-body pairing was forgotten.
        //
        // Pin: every schema case has SOME body that returns true so
        // the pairing isn't omitted. We don't need to enumerate the
        // exact body each schema expects (the existing source-guard
        // tests cover individual mappings); the cross-coverage check
        // here is the only thing that fails for "added a new schema,
        // forgot the canonicalBody arm".
        let candidateBodies: [GenUIBody] = [
            .raw(""),
            .rows(headers: [], cells: []),
            .keyValues([]),
            .actions([]),
            .error(title: "x", detail: "", hint: nil, options: []),
            .progress(label: "x", total: 1.0, value: 0.0),
            .provenanceChain([]),
            .clarify(question: "q", choices: [], allowFreeText: true),
        ]
        for schema in GenUISchema.allCases {
            let hasAtLeastOnePairing = candidateBodies
                .contains { schema.canonicalBody($0) }
            #expect(hasAtLeastOnePairing,
                    "GenUISchema.\(schema) has no canonical body pairing — adding it requires updating `GenUISchema.canonicalBody(_:)`")
        }
    }
}
