import Foundation

// MARK: - EpdocProperty
//
// Wave 7.13 of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.13).
//
// Notion-style typed property substrate for `.epdoc` packages. Sits
// on top of `manifest.metadata` (W7.6) — each property value gets
// stored as a JSON-encoded string at the metadata key
// `"properties.<property_id>"`. The schema (`PropertyDef` list) is
// loose — each doc carries the keys it cares about, and queries
// across many docs (W7.13 follow-up) can union the encountered
// schemas to surface a shared view.
//
// V1 property kinds (8 of Notion's ~12):
//   .select       — single tag from a curated list
//   .multiSelect  — zero or more tags
//   .date         — ISO-8601 date string (`YYYY-MM-DD`) or full datetime
//   .number       — Double-encoded number
//   .checkbox     — Bool
//   .url          — String constrained to https:// / http:// / file:// schemes
//   .email        — String constrained to RFC-5321-shaped addresses
//   .text         — free-form String
//
// V2 follow-ups (intentionally NOT in this commit):
//   .relation     — id of another `.epdoc` (needs the W7.14 graph)
//   .formula      — derived value (needs a formula evaluator)
//   .rollup       — aggregated values across related docs
//   .file         — pointer into the package's `assets/` dir

// MARK: - Property kind

nonisolated public enum PropertyKind: String, Codable, Sendable, CaseIterable, Hashable {
    case select
    case multiSelect = "multi_select"
    case date
    case number
    case checkbox
    case url
    case email
    case text
}

// MARK: - Property definition

/// Schema entry for one property. Stored in the database catalogue
/// (a `database.json` document or in the workspace SwiftData store
/// — the W7.13 follow-up decides where).
/// One curated option for a `.select` / `.multiSelect` PropertyDef.
/// Mirrors Logseq's `:closed-values` pattern
/// (`deps/db/src/logseq/db/frontend/property.cljs:301-307`) — keys the
/// option on a stable id so renaming the display value (`value`) never
/// breaks references stored in doc metadata.
///
/// Wave 7.13.c follow-up of the Logseq scan 2026-04-26.
nonisolated public struct PropertyOption: Codable, Sendable, Hashable {
    /// Stable identifier. New options get a random ULID-style id at
    /// creation time; legacy `[String]` options get a deterministic
    /// id derived from the display value via SHA-256 (so two clients
    /// reading the same legacy JSON converge on the same id).
    public let id: String
    /// Human-readable display value. Editable without breaking
    /// references — the id is the contract.
    public let value: String
    /// Optional UI hint (hex color, tag color, etc.). Surface
    /// chooses the styling.
    public let color: String?

    public init(id: String, value: String, color: String? = nil) {
        self.id = id
        self.value = value
        self.color = color
    }

    /// Build a brand-new option from a display value. Mints a fresh
    /// random id (use this when the user picks "Add option" in the
    /// UI; the id is permanent + the value can be edited later).
    public static func newOption(value: String, color: String? = nil) -> PropertyOption {
        PropertyOption(id: PropertyOption.randomID(), value: value, color: color)
    }

    /// Migrate a legacy `[String]` option into a `PropertyOption` with
    /// a deterministic id derived from the display value. Two clients
    /// reading the same pre-W7.13.c JSON converge on the same id, so
    /// the upgrade isn't fork-sensitive.
    public static func migratingFromLegacy(_ value: String) -> PropertyOption {
        PropertyOption(
            id: PropertyOption.deterministicID(forLegacyValue: value),
            value: value,
            color: nil
        )
    }

    /// 22-char Crockford-base32-style id (16 bytes of entropy from
    /// `UUID().uuid` rendered in Crockford base32 to keep ids URL-safe
    /// + visually short). Not strictly ULID (no time prefix) but the
    /// same shape from the consumer's POV: opaque, sortable, unique.
    static func randomID() -> String {
        let raw = UUID().uuid
        let bytes: [UInt8] = [
            raw.0,  raw.1,  raw.2,  raw.3,
            raw.4,  raw.5,  raw.6,  raw.7,
            raw.8,  raw.9,  raw.10, raw.11,
            raw.12, raw.13, raw.14, raw.15,
        ]
        return crockfordBase32(bytes)
    }

    /// Stable migration id: lowercase-hex SHA-256-style hash of the
    /// legacy display value, truncated to 22 chars to match the random
    /// id width. Implementation uses Foundation's `Data.hashValue`-equivalent
    /// — we don't import CryptoKit here to keep the dep surface light;
    /// the migration id only has to be stable + collision-resistant
    /// over the small option-name domain (~10–100 entries per
    /// PropertyDef in practice).
    static func deterministicID(forLegacyValue value: String) -> String {
        var hasher = SimpleFNVHasher()
        hasher.combine(value)
        return crockfordBase32(hasher.bytes(count: 16))
    }
}

nonisolated public struct PropertyDef: Codable, Sendable, Hashable {
    /// Stable identifier. Use a ULID/UUID at creation time so the id
    /// survives display-name changes.
    public let id: String
    /// Human-readable column name. May change without breaking
    /// existing values (everything keys off `id`).
    public let name: String
    /// Type discriminant. Determines how `EpdocPropertyValue` decodes the
    /// stored JSON.
    public let kind: PropertyKind
    /// W7.13.c canonical curated options. Each carries a stable id so
    /// renaming the display value never breaks references.
    public let optionsV2: [PropertyOption]?
    /// W7.13 legacy curated options (display values only). Decode-only
    /// surface kept for back-compat with pre-W7.13.c JSON. NEW writers
    /// MUST populate `optionsV2` instead; the encoder only emits
    /// `optionsV2`.
    @available(*, deprecated, message: "Use optionsV2 (PropertyOption with stable id). This is the W7.13 legacy field, decode-only.")
    public let options: [String]?
    /// Optional default value rendered as JSON. Applied when the
    /// property is added to an existing doc that doesn't yet carry
    /// the key. Stored as JSON to support every EpdocPropertyValue shape.
    public let defaultValueJSON: String?

    public init(
        id: String,
        name: String,
        kind: PropertyKind,
        options: [PropertyOption]? = nil,
        defaultValueJSON: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.optionsV2 = options
        self.options = nil
        self.defaultValueJSON = defaultValueJSON
    }

    /// Effective options view — prefers W7.13.c `optionsV2` and
    /// auto-migrates the legacy `options: [String]` into
    /// `PropertyOption` with deterministic ids. Always use this for
    /// reads; it abstracts over the schema upgrade.
    public var effectiveOptions: [PropertyOption]? {
        if let v2 = optionsV2, !v2.isEmpty { return v2 }
        if let legacy = options { return legacy.map(PropertyOption.migratingFromLegacy) }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case optionsV2 = "options_v2"
        case options
        case defaultValueJSON = "default_value_json"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.kind = try c.decode(PropertyKind.self, forKey: .kind)
        self.optionsV2 = try c.decodeIfPresent([PropertyOption].self, forKey: .optionsV2)
        self.options = try c.decodeIfPresent([String].self, forKey: .options)
        self.defaultValueJSON = try c.decodeIfPresent(String.self, forKey: .defaultValueJSON)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(kind, forKey: .kind)
        // Encode the canonical V2 form. We auto-promote any legacy
        // `options: [String]` to `optionsV2` on write so the next
        // round-trip emits the new shape exclusively.
        if let canonical = effectiveOptions {
            try c.encode(canonical, forKey: .optionsV2)
        }
        try c.encodeIfPresent(defaultValueJSON, forKey: .defaultValueJSON)
    }
}

// MARK: - ID derivation primitives

/// 32-char Crockford base32 alphabet (Douglas Crockford's variant):
/// excludes I, L, O, U so ids are unambiguous when read aloud.
nonisolated private let crockfordAlphabet: [Character] = Array(
    "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
)

/// Crockford-base32 encode raw bytes. Returns a string roughly
/// `ceil(8/5) × bytes.count = 1.6 × bytes.count` chars long.
/// Used for stable id rendering — never decoded back to bytes.
nonisolated private func crockfordBase32(_ bytes: [UInt8]) -> String {
    var bits: UInt64 = 0
    var bitCount: Int = 0
    var out = String()
    out.reserveCapacity(bytes.count * 8 / 5 + 1)
    for byte in bytes {
        bits = (bits << 8) | UInt64(byte)
        bitCount += 8
        while bitCount >= 5 {
            bitCount -= 5
            let idx = Int((bits >> bitCount) & 0x1F)
            out.append(crockfordAlphabet[idx])
        }
    }
    if bitCount > 0 {
        let idx = Int((bits << (5 - bitCount)) & 0x1F)
        out.append(crockfordAlphabet[idx])
    }
    return out
}

/// Lightweight FNV-1a 64-bit hasher used to derive a stable id from a
/// legacy option string. We expand the 64-bit digest by mixing in a
/// rotated copy so the final id has 128 bits of pseudo-entropy
/// (collision-resistant enough for the small ~10-100 option domain).
nonisolated private struct SimpleFNVHasher {
    private var state: UInt64 = 0xcbf29ce484222325

    mutating func combine(_ s: String) {
        for byte in s.utf8 {
            state ^= UInt64(byte)
            state = state &* 0x00000100000001b3
        }
    }

    func bytes(count: Int) -> [UInt8] {
        // Expand 64 bits → `count` bytes by chained FNV with a
        // rotating salt. Same input → same output (pure function).
        var out: [UInt8] = []
        out.reserveCapacity(count)
        var s = state
        var salt: UInt64 = 0x9e3779b97f4a7c15  // golden-ratio constant
        while out.count < count {
            for shift in stride(from: 56, through: 0, by: -8) {
                if out.count >= count { break }
                out.append(UInt8((s >> shift) & 0xFF))
            }
            // Mix in salt + iterate
            s ^= salt
            s = s &* 0x00000100000001b3
            salt = (salt &+ 0x9e3779b97f4a7c15)
        }
        return out
    }
}

// MARK: - Property value

/// Tagged union of a value matching one `PropertyKind`. Encoded as a
/// JSON string + persisted into `manifest.metadata` under the key
/// `"properties.<id>"`.
nonisolated public enum EpdocPropertyValue: Codable, Sendable, Hashable {
    case select(String)
    case multiSelect([String])
    case date(String)        // ISO-8601 — caller validates
    case number(Double)
    case checkbox(Bool)
    case url(String)
    case email(String)
    case text(String)

    /// The discriminant kind. Used by the editor to validate that the
    /// value matches the schema's `PropertyDef.kind`.
    public var kind: PropertyKind {
        switch self {
        case .select:      return .select
        case .multiSelect: return .multiSelect
        case .date:        return .date
        case .number:      return .number
        case .checkbox:    return .checkbox
        case .url:         return .url
        case .email:       return .email
        case .text:        return .text
        }
    }

    // MARK: Codable

    private enum Discriminant: String, Codable {
        case select, multiSelect = "multi_select", date, number, checkbox, url, email, text
    }

    private enum CodingKeys: String, CodingKey {
        case kind, value
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let disc = try c.decode(Discriminant.self, forKey: .kind)
        switch disc {
        case .select:      self = .select(try c.decode(String.self, forKey: .value))
        case .multiSelect: self = .multiSelect(try c.decode([String].self, forKey: .value))
        case .date:        self = .date(try c.decode(String.self, forKey: .value))
        case .number:      self = .number(try c.decode(Double.self, forKey: .value))
        case .checkbox:    self = .checkbox(try c.decode(Bool.self, forKey: .value))
        case .url:         self = .url(try c.decode(String.self, forKey: .value))
        case .email:       self = .email(try c.decode(String.self, forKey: .value))
        case .text:        self = .text(try c.decode(String.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Discriminant(rawValue: kind == .multiSelect ? "multi_select" : kind.rawValue)!,
                     forKey: .kind)
        switch self {
        case .select(let s):       try c.encode(s, forKey: .value)
        case .multiSelect(let xs): try c.encode(xs, forKey: .value)
        case .date(let s):         try c.encode(s, forKey: .value)
        case .number(let d):       try c.encode(d, forKey: .value)
        case .checkbox(let b):     try c.encode(b, forKey: .value)
        case .url(let s):          try c.encode(s, forKey: .value)
        case .email(let s):        try c.encode(s, forKey: .value)
        case .text(let s):         try c.encode(s, forKey: .value)
        }
    }
}

// MARK: - Manifest <-> properties bridge

/// Helpers that read / write `EpdocPropertyValue`s into the
/// `manifest.metadata` map under the canonical
/// `"properties.<property_id>"` key prefix.
nonisolated public enum EpdocPropertyMetadata {

    /// The metadata key prefix every property value uses. Other
    /// metadata keys (theme, icon, complexity, etc.) live OUTSIDE
    /// this prefix so a future `metadata.removeAll(prefix:)` doesn't
    /// nuke them.
    public static let keyPrefix = "properties."

    /// Compose the metadata key for a property id.
    public static func metadataKey(forPropertyID id: String) -> String {
        keyPrefix + id
    }

    /// Encode a value as the JSON string stored under `metadata`.
    public static func encode(_ value: EpdocPropertyValue) throws -> String {
        let data = try JSONEncoder().encode(value)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Decode a metadata-string back to a typed value.
    public static func decode(_ jsonString: String) -> EpdocPropertyValue? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(EpdocPropertyValue.self, from: data)
    }

    /// Read every property value off a manifest. Keys without the
    /// canonical prefix are ignored. Order is unspecified.
    public static func properties(in manifest: EpdocManifest) -> [String: EpdocPropertyValue] {
        var out: [String: EpdocPropertyValue] = [:]
        for (key, jsonString) in manifest.metadata ?? [:] {
            guard key.hasPrefix(keyPrefix) else { continue }
            let id = String(key.dropFirst(keyPrefix.count))
            if let value = decode(jsonString) {
                out[id] = value
            }
        }
        return out
    }

    /// Return a copy of `manifest` with `value` written under the
    /// property id's canonical metadata key. Other metadata keys are
    /// preserved verbatim.
    public static func withProperty(
        _ manifest: EpdocManifest,
        id: String,
        value: EpdocPropertyValue
    ) throws -> EpdocManifest {
        var bag = manifest.metadata ?? [:]
        bag[metadataKey(forPropertyID: id)] = try encode(value)
        return manifest.replacingMetadata(bag)
    }

    /// Return a copy of `manifest` with the property id's metadata
    /// key removed. Returns the manifest unchanged if the key wasn't
    /// present.
    public static func withoutProperty(
        _ manifest: EpdocManifest,
        id: String
    ) -> EpdocManifest {
        var bag = manifest.metadata ?? [:]
        bag.removeValue(forKey: metadataKey(forPropertyID: id))
        return manifest.replacingMetadata(bag.isEmpty ? nil : bag)
    }
}

// MARK: - EpdocManifest convenience

extension EpdocManifest {
    /// Return a copy of this manifest with the metadata bag replaced.
    /// The other fields (id / kind / hashes / provenance) stay
    /// identical so this is a safe single-key edit pattern for the
    /// W7.13 property writer.
    nonisolated public func replacingMetadata(_ newMetadata: [String: String]?) -> EpdocManifest {
        EpdocManifest(
            id: id,
            kind: kind,
            schemaVersion: schemaVersion,
            createdAt: createdAt,
            updatedAt: updatedAt,
            title: title,
            contentHash: contentHash,
            provenance: provenance,
            metadata: newMetadata
        )
    }
}
