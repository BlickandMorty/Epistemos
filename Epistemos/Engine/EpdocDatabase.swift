import Foundation

// MARK: - EpdocDatabase
//
// Wave 7.13 (continued) of the Extended Program Plan.
//
// In-memory query engine for `.epdoc` collections treated as
// Notion-style databases. Each `EpdocDatabaseRow` pairs a manifest
// + its decoded property values; the database itself owns the
// schema (`PropertyDef` list) the rows conform to.
//
// V1 surface:
//   - rows           — flat array of (manifest, properties)
//   - filter(_:)     — predicate-based projection
//   - sorted(by:asc:)— in-memory sort by a property id
//   - groupBy(_:)    — group rows by select / multiSelect values
//   - schemaUnion()  — derive the active schema from the rows
//                      (handy when the explicit schema is missing)
//
// The schema CAN be supplied explicitly; otherwise it's inferred
// from the property values present in `rows`. A future commit reads
// the canonical schema from a `database.json` file at the workspace
// root.
//
// Threading: actor-isolated. `EpdocDatabase` owns mutable state
// (schema + rows). Read accessors return value-typed snapshots;
// mutation goes through `add` / `update` / `remove`. UI surfaces
// (the Notion-table view, V2) bind to a `@MainActor` publisher
// that snapshots the database on every change.

nonisolated public struct EpdocDatabaseRow: Sendable, Hashable {
    public let manifest: EpdocManifest
    /// Property id → typed value. Decoded from `manifest.metadata`
    /// at construction time.
    public let properties: [String: EpdocPropertyValue]

    public init(manifest: EpdocManifest) {
        self.manifest = manifest
        self.properties = EpdocPropertyMetadata.properties(in: manifest)
    }

    public init(manifest: EpdocManifest, properties: [String: EpdocPropertyValue]) {
        self.manifest = manifest
        self.properties = properties
    }

    /// Convenience: read a single property value.
    public func value(forPropertyID id: String) -> EpdocPropertyValue? {
        properties[id]
    }
}

public actor EpdocDatabase {

    private(set) public var schema: [PropertyDef]
    private(set) public var rows: [EpdocDatabaseRow]

    public init(schema: [PropertyDef] = [], rows: [EpdocDatabaseRow] = []) {
        self.schema = schema
        self.rows = rows
    }

    // MARK: - Mutators

    public func setSchema(_ defs: [PropertyDef]) {
        self.schema = defs
    }

    public func add(_ row: EpdocDatabaseRow) {
        rows.append(row)
    }

    public func add(manifest: EpdocManifest) {
        rows.append(EpdocDatabaseRow(manifest: manifest))
    }

    /// Replace the row whose `manifest.id` matches; appends if absent.
    public func upsert(_ row: EpdocDatabaseRow) {
        if let idx = rows.firstIndex(where: { $0.manifest.id == row.manifest.id }) {
            rows[idx] = row
        } else {
            rows.append(row)
        }
    }

    /// Remove the row with the given doc id. No-op if not present.
    @discardableResult
    public func remove(manifestID: String) -> Bool {
        if let idx = rows.firstIndex(where: { $0.manifest.id == manifestID }) {
            rows.remove(at: idx)
            return true
        }
        return false
    }

    // MARK: - Queries

    /// Filter rows by an arbitrary predicate. The predicate sees the
    /// fully-decoded row (manifest + properties) so callers can
    /// combine title / kind / property values freely.
    public func filtered(where predicate: @Sendable (EpdocDatabaseRow) -> Bool) -> [EpdocDatabaseRow] {
        rows.filter(predicate)
    }

    /// Sort rows by a single property id in ascending or descending
    /// order. Rows missing the property sort LAST (deterministic).
    public func sorted(byPropertyID id: String, ascending: Bool = true) -> [EpdocDatabaseRow] {
        rows.sorted { lhs, rhs in
            let lv = lhs.properties[id]
            let rv = rhs.properties[id]
            switch (lv, rv) {
            case (nil, nil): return false
            case (nil, _):   return false  // missing values sort last
            case (_, nil):   return true
            case let (l?, r?):
                let order = compare(l, r)
                return ascending ? order < 0 : order > 0
            }
        }
    }

    /// Group rows by the *string* projection of a select-style
    /// property. multiSelect values produce one row per tag; date /
    /// number values render through their canonical string form.
    /// Rows missing the property sort under the empty-string key.
    public func grouped(byPropertyID id: String) -> [String: [EpdocDatabaseRow]] {
        var bucket: [String: [EpdocDatabaseRow]] = [:]
        for row in rows {
            let keys = stringProjections(of: row.properties[id])
            for key in keys {
                bucket[key, default: []].append(row)
            }
        }
        return bucket
    }

    /// Derive the active schema from the property values present in
    /// `rows`. Useful when the explicit schema is missing or out of
    /// sync. Returns one PropertyDef per discovered id, with
    /// `name = id` and the kind inferred from the first value seen.
    public func schemaUnion() -> [PropertyDef] {
        var seen: [String: PropertyKind] = [:]
        for row in rows {
            for (id, value) in row.properties where seen[id] == nil {
                seen[id] = value.kind
            }
        }
        return seen
            .sorted { $0.key < $1.key }
            .map { (id, kind) in
                PropertyDef(id: id, name: id, kind: kind)
            }
    }

    // MARK: - Comparison + projection helpers

    /// Total ordering across EpdocPropertyValue cases. Numbers compare
    /// numerically; strings (incl. dates) lexicographically; bools
    /// false < true. Cross-kind comparisons preserve PropertyKind's
    /// `CaseIterable` order.
    private func compare(_ lhs: EpdocPropertyValue, _ rhs: EpdocPropertyValue) -> Int {
        if lhs.kind != rhs.kind {
            // Different kinds — fall back to deterministic kind order
            // so the sort never produces a non-deterministic result.
            let order = PropertyKind.allCases
            let li = order.firstIndex(of: lhs.kind) ?? 0
            let ri = order.firstIndex(of: rhs.kind) ?? 0
            return li < ri ? -1 : (li > ri ? 1 : 0)
        }
        switch (lhs, rhs) {
        case let (.select(a), .select(b)):
            return lexicographicCompare(a, b)
        case let (.multiSelect(a), .multiSelect(b)):
            return lexicographicCompare(a.joined(separator: ","), b.joined(separator: ","))
        case let (.date(a), .date(b)):
            // ISO-8601 strings sort lexicographically for ascending
            // chronological order.
            return lexicographicCompare(a, b)
        case let (.number(a), .number(b)):
            return a < b ? -1 : (a > b ? 1 : 0)
        case let (.checkbox(a), .checkbox(b)):
            // false (0) < true (1)
            let l = a ? 1 : 0
            let r = b ? 1 : 0
            return l - r
        case let (.url(a), .url(b)):
            return lexicographicCompare(a, b)
        case let (.email(a), .email(b)):
            return lexicographicCompare(a, b)
        case let (.text(a), .text(b)):
            return lexicographicCompare(a, b)
        default:
            return 0
        }
    }

    /// Stringified projections for grouping. multiSelect explodes to
    /// N rows; nil collapses to the empty string.
    private func stringProjections(of value: EpdocPropertyValue?) -> [String] {
        guard let value else { return [""] }
        switch value {
        case .select(let s):       return [s]
        case .multiSelect(let xs): return xs.isEmpty ? [""] : xs
        case .date(let s):         return [s]
        case .number(let d):       return [String(d)]
        case .checkbox(let b):     return [b ? "true" : "false"]
        case .url(let s):          return [s]
        case .email(let s):        return [s]
        case .text(let s):         return [s]
        }
    }
}

// MARK: - Lexicographic compare helper
//
// String.compare(_:) on Foundation is @MainActor-isolated under the
// project default. We need a nonisolated arithmetic comparator inside
// the EpdocDatabase actor's `compare(_:_:)`. Inlining the < / > pair
// avoids both the isolation hop and the Foundation dependency.
nonisolated private func lexicographicCompare(_ lhs: String, _ rhs: String) -> Int {
    if lhs < rhs { return -1 }
    if lhs > rhs { return 1 }
    return 0
}
