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
    /// Curated options for `.select` / `.multiSelect` kinds. Stored
    /// in declaration order — the UI surface usually preserves it.
    /// `nil` for kinds that don't take options.
    public let options: [String]?
    /// Optional default value rendered as JSON. Applied when the
    /// property is added to an existing doc that doesn't yet carry
    /// the key. Stored as JSON to support every EpdocPropertyValue shape.
    public let defaultValueJSON: String?

    public init(
        id: String,
        name: String,
        kind: PropertyKind,
        options: [String]? = nil,
        defaultValueJSON: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.options = options
        self.defaultValueJSON = defaultValueJSON
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case options
        case defaultValueJSON = "default_value_json"
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
