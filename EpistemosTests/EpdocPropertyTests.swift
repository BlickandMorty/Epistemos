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
            options: [
                PropertyOption.newOption(value: "todo"),
                PropertyOption.newOption(value: "doing"),
                PropertyOption.newOption(value: "done"),
            ],
            defaultValueJSON: #"{"kind":"select","value":"todo"}"#
        )
        let data = try JSONEncoder().encode(def)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains("\"default_value_json\""),
                "PropertyDef wire keys MUST be snake_case; got \(json)")
        #expect(json.contains("\"options_v2\""),
                "PropertyDef MUST encode the W7.13.c canonical options_v2 key; got \(json)")
        #expect(!json.contains("\"options\":"),
                "writers MUST NOT emit the legacy options:[String] field")

        let decoded = try JSONDecoder().decode(PropertyDef.self, from: data)
        #expect(decoded == def)
    }

    // MARK: - W7.13.c PropertyOption stable ids

    @Test("PropertyOption.newOption mints a non-empty Crockford-base32 id")
    func newOptionMintsID() {
        let opt = PropertyOption.newOption(value: "doing")
        #expect(!opt.id.isEmpty, "newOption MUST mint a non-empty id; got \(opt.id)")
        #expect(opt.value == "doing")
        // Crockford base32 alphabet: 0–9, A–Z minus I L O U.
        // The id must be entirely within that alphabet.
        let alphabet = Set("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
        for c in opt.id {
            #expect(alphabet.contains(c),
                    "newOption id MUST use Crockford base32 only; got '\(c)' in '\(opt.id)'")
        }
    }

    @Test("Two newOption calls for the same value mint DIFFERENT ids (random, not deterministic)")
    func newOptionIsRandom() {
        let a = PropertyOption.newOption(value: "doing")
        let b = PropertyOption.newOption(value: "doing")
        #expect(a.id != b.id,
                "two newOption calls MUST mint distinct ids so Add Option creates a fresh row")
    }

    @Test("PropertyOption.migratingFromLegacy is deterministic across calls (so two clients converge)")
    func migrationIDIsDeterministic() {
        let a = PropertyOption.migratingFromLegacy("doing")
        let b = PropertyOption.migratingFromLegacy("doing")
        #expect(a.id == b.id,
                "same legacy value MUST produce the same migration id (so two clients reading same JSON converge); got \(a.id) vs \(b.id)")
        #expect(a.value == "doing")

        let c = PropertyOption.migratingFromLegacy("done")
        #expect(c.id != a.id,
                "different legacy values MUST produce different ids; got \(c.id) == \(a.id)")
    }

    @Test("PropertyDef effectiveOptions auto-migrates legacy [String] options on read")
    func effectiveOptionsAutoMigrates() throws {
        // Construct a legacy-shaped JSON (pre-W7.13.c writer)
        let legacyJSON = #"""
        {
            "id": "prop-1",
            "name": "Status",
            "kind": "select",
            "options": ["todo", "doing", "done"]
        }
        """#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PropertyDef.self, from: legacyJSON)
        let effective = decoded.effectiveOptions
        #expect(effective?.count == 3)
        #expect(effective?.map(\.value) == ["todo", "doing", "done"],
                "effectiveOptions MUST preserve display values; got \(effective?.map(\.value) ?? [])")
        // Migration ids are deterministic → re-decoding the same JSON
        // produces identical ids. Spot-check the first entry against
        // the canonical migration helper.
        let expectedFirstID = PropertyOption.migratingFromLegacy("todo").id
        #expect(effective?.first?.id == expectedFirstID,
                "auto-migrated id MUST match PropertyOption.migratingFromLegacy(_:); got \(effective?.first?.id ?? "nil")")
    }

    @Test("PropertyDef encoder upgrades legacy options to options_v2 on the next write (write-time migration)")
    func encodeUpgradesLegacyShape() throws {
        let legacyJSON = #"""
        {
            "id": "prop-1",
            "name": "Status",
            "kind": "select",
            "options": ["todo", "doing"]
        }
        """#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PropertyDef.self, from: legacyJSON)
        let reEncoded = try JSONEncoder().encode(decoded)
        let reJSON = String(data: reEncoded, encoding: .utf8) ?? ""
        #expect(reJSON.contains("\"options_v2\""),
                "next write MUST emit options_v2; got \(reJSON)")
        #expect(!reJSON.contains("\"options\":"),
                "next write MUST drop the legacy options:[String] field")
    }

    @Test("PropertyOption.color round-trips through Codable when set + omits when nil")
    func colorOptionalRoundTrip() throws {
        let withColor = PropertyOption(id: "x", value: "todo", color: "#3a86ff")
        let dataC = try JSONEncoder().encode(withColor)
        let backC = try JSONDecoder().decode(PropertyOption.self, from: dataC)
        #expect(backC == withColor)

        let plain = PropertyOption(id: "x", value: "todo")
        let dataP = try JSONEncoder().encode(plain)
        let backP = try JSONDecoder().decode(PropertyOption.self, from: dataP)
        #expect(backP == plain)
        #expect(backP.color == nil)
    }
}
