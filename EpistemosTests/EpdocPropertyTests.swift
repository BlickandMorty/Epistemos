import Foundation
import Testing

@testable import Epistemos

/// Wave 7.13 source-guard for the typed-property substrate
/// (`EpdocPropertyValue` + `PropertyDef` + the manifest bridge).
@Suite("EpdocProperty (Wave 7.13)")
nonisolated struct EpdocPropertyTests {

    // MARK: - PropertyKind enum

    @Test("PropertyKind covers the V1 column types")
    func kindEnumComplete() {
        let cases: Set<PropertyKind> = Set(PropertyKind.allCases)
        let expected: Set<PropertyKind> = [
            .select, .multiSelect, .date, .number, .checkbox,
            .url, .email, .text,
        ]
        #expect(cases == expected,
                "PropertyKind MUST cover the 8 V1 cases; got \(cases)")
    }

    @Test("PropertyKind raw values use snake_case for multi_select (Rust parity)")
    func multiSelectRawValue() {
        #expect(PropertyKind.multiSelect.rawValue == "multi_select")
    }

    // MARK: - EpdocPropertyValue Codable

    @Test("Every EpdocPropertyValue case round-trips via Codable")
    func valueRoundTrip() throws {
        let cases: [EpdocPropertyValue] = [
            .select("alpha"),
            .multiSelect(["alpha", "beta"]),
            .date("2026-04-26"),
            .number(3.14),
            .checkbox(true),
            .url("https://example.com"),
            .email("a@b.c"),
            .text("free-form"),
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for original in cases {
            let data = try encoder.encode(original)
            let recovered = try decoder.decode(EpdocPropertyValue.self, from: data)
            #expect(recovered == original,
                    "EpdocPropertyValue \(original) MUST round-trip identical")
        }
    }

    @Test("EpdocPropertyValue.kind exposes the discriminant for schema validation")
    func valueKindDiscriminant() {
        #expect(EpdocPropertyValue.select("a").kind == .select)
        #expect(EpdocPropertyValue.multiSelect([]).kind == .multiSelect)
        #expect(EpdocPropertyValue.date("2026-01-01").kind == .date)
        #expect(EpdocPropertyValue.number(0).kind == .number)
        #expect(EpdocPropertyValue.checkbox(false).kind == .checkbox)
        #expect(EpdocPropertyValue.url("https://x").kind == .url)
        #expect(EpdocPropertyValue.email("a@b").kind == .email)
        #expect(EpdocPropertyValue.text("").kind == .text)
    }

    // MARK: - Manifest <-> properties bridge

    private static func emptyManifest() -> EpdocManifest {
        EpdocManifest(
            id: "01HMV5K2K9PROPID",
            createdAt: 0,
            updatedAt: 0,
            title: "T",
            contentHash: "",
            provenance: EpdocProvenance(producer: .human)
        )
    }

    @Test("withProperty writes the canonical 'properties.<id>' key")
    func writeProperty() throws {
        let m = Self.emptyManifest()
        let withStatus = try EpdocPropertyMetadata.withProperty(
            m,
            id: "status",
            value: .select("doing")
        )
        let key = EpdocPropertyMetadata.metadataKey(forPropertyID: "status")
        #expect(withStatus.metadata?[key] != nil)
    }

    @Test("properties(in:) reads only the keys with the canonical prefix; unrelated keys are ignored")
    func readPropertiesIgnoresUnrelatedMeta() throws {
        let m = Self.emptyManifest()
            .replacingMetadata([
                EpdocPropertyMetadata.metadataKey(forPropertyID: "status"):
                    try EpdocPropertyMetadata.encode(.select("doing")),
                EpdocPropertyMetadata.metadataKey(forPropertyID: "due"):
                    try EpdocPropertyMetadata.encode(.date("2026-04-30")),
                "theme": "dark",
                "icon": "rocket",
            ])
        let props = EpdocPropertyMetadata.properties(in: m)
        #expect(props.count == 2,
                "only `properties.*` keys count as properties; got \(props)")
        #expect(props["status"] == .select("doing"))
        #expect(props["due"] == .date("2026-04-30"))
    }

    @Test("withoutProperty removes only the targeted key + collapses to nil when bag empties")
    func removeProperty() throws {
        let withOne = try EpdocPropertyMetadata.withProperty(
            Self.emptyManifest(),
            id: "status",
            value: .select("done")
        )
        let cleared = EpdocPropertyMetadata.withoutProperty(withOne, id: "status")
        #expect(cleared.metadata == nil,
                "removing the last property key MUST collapse metadata to nil for clean serialization")
    }

    @Test("withProperty preserves OTHER metadata keys (theme, icon, etc.)")
    func writePreservesOtherKeys() throws {
        let themed = Self.emptyManifest().replacingMetadata([
            "theme": "solarized",
            "icon": "rocket",
        ])
        let withStatus = try EpdocPropertyMetadata.withProperty(
            themed,
            id: "status",
            value: .select("review")
        )
        #expect(withStatus.metadata?["theme"] == "solarized",
                "writing a property MUST NOT clobber other metadata keys")
        #expect(withStatus.metadata?["icon"] == "rocket")
    }

    @Test("PropertyDef Codable round-trips with snake_case wire keys")
    func defCodable() throws {
        let def = PropertyDef(
            id: "01HMV5K2K9PROPDEF",
            name: "Status",
            kind: .select,
            options: ["todo", "doing", "done"],
            defaultValueJSON: #"{"kind":"select","value":"todo"}"#
        )
        let data = try JSONEncoder().encode(def)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains("\"default_value_json\""),
                "PropertyDef wire keys MUST be snake_case; got \(json)")

        let decoded = try JSONDecoder().decode(PropertyDef.self, from: data)
        #expect(decoded == def)
    }
}
