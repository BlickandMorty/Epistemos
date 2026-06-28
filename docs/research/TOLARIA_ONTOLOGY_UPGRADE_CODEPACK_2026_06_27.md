# Tolaria Ontology → Epistemos — 1:1 Upgrade CODE PACK (2026-06-27)

> Pass-4a deliverable: actual Swift/Rust code that upgrades each Tolaria ontology subsystem onto
> Epistemos's real types. **Clean-room** — every snippet is NEW Epistemos code written against
> [VERIFIED-CODE] signatures in this repo; no AGPL Tolaria source reproduced (behavior matched per
> `TOLARIA_SUPERSEDE_RESEARCH_2026_06_27.md` Pass 2a, then superseded). Companion: the running tracker.

**Repo anchors used:** `VaultIndexActor.parseFrontMatter` (`Epistemos/Sync/VaultIndexActor.swift:1804`),
`SDPage` (`@Model`, `frontMatter:[String:String]`, `wikilinkReferences`, `loadBody()`),
`GraphStore.addNode/addEdge/removeEdge/edges(for:)` + `GraphEdgeRecord`/`GraphEdgeType`,
`WikilinkResolver.extractDestinations/canonicalDestination`, `RRFFusionQuery`/`SearchIndexService.fusedSearchAsync`
(`K_RRF=60`), `readable_blocks` table, `ShadowSearchService.search`, `ShadowVaultBootstrapper`.
**Repo facts shaping design:** NO Yams dep (Views use a tiny hand-rolled reader); NO existing
`_width`/`ViewDefinition`/`TypeRegistry` (all green-field); `parseFrontMatter` is flat `[String:String]`
with zero `type:`/`_`-key/typed-kind handling — the gap each subsystem fills.

---

## 1. Frontmatter + title parsing — `NEW Epistemos/Sync/NoteOntologyParser.swift`
Tolaria: title = first H1 → `title:` → humanized filename; `type:` canonical (legacy `Is A`/`is_a`, list→first);
kinds string/number/bool/null/scalar-array/date. **Upgrade:** typed parser LAYERED over the existing flat
parser (legacy path keeps working; reuses the hardened BOM/quote/bracket/comment handling).

```swift
nonisolated public enum FMValue: Sendable, Hashable {
    case string(String); case number(Double); case bool(Bool)
    case date(String); case scalarArray([String]); case null
    case wikilinks([String])   // canonical dests — feeds subsystem 2
}
nonisolated public struct ParsedNote: Sendable, Hashable {
    public let title: String
    public let type: String?
    public let properties: [String: FMValue]    // non-reserved, non-`_`
    public let systemProps: [String: String]    // `_`-prefixed, canonicalized (subsystem 3)
    public let relationships: [String: [String]] // field -> canonical wikilink dests (subsystem 2)
    public let body: String
}
nonisolated public enum NoteOntologyParser {
    public static func parse(content: String, filePath: URL?) -> ParsedNote {
        let (flat, body) = VaultIndexActor.parseFrontMatter(content)            // [VERIFIED-CODE]
        let title = firstH1(in: body)
            ?? flat["title"].flatMap { $0.isEmpty ? nil : $0 }
            ?? humanizedFilename(filePath)
        let typeRaw = flat["type"] ?? flat["Is A"] ?? flat["is_a"]
        let type = typeRaw.map { firstScalar(of: classifyScalarArray($0)) }
        var props: [String:FMValue] = [:], system: [String:String] = [:], rels: [String:[String]] = [:]
        for (key, raw) in flat {
            if SystemKeys.isSystemKey(key) { system[SystemKeys.canonicalize(key)] = raw; continue }
            if ["title","type","Is A","is_a"].contains(key) { continue }
            let dests = WikilinkResolver.extractDestinations(from: raw)         // [VERIFIED-CODE]
            if !dests.isEmpty { rels[key] = dests; props[key] = .wikilinks(dests) }
            else { props[key] = classify(raw) }
        }
        return ParsedNote(title: title, type: type, properties: props,
                          systemProps: system, relationships: rels, body: body)
    }
    static func classify(_ raw: String) -> FMValue {
        let v = raw.trimmingCharacters(in: .whitespaces)
        if v.isEmpty || v == "null" || v == "~" { return .null }
        if v == "true" { return .bool(true) }; if v == "false" { return .bool(false) }
        if let d = Double(v) { return .number(d) }
        if isISODate(v) { return .date(v) }
        let arr = classifyScalarArray(v); return arr.count > 1 ? .scalarArray(arr) : .string(v)
    }
    static func classifyScalarArray(_ v: String) -> [String] {
        v.split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"'")) }
         .filter { !$0.isEmpty }
    }
    static func firstScalar(of a: [String]) -> String { a.first ?? "" }
    static func firstH1(in body: String) -> String? {
        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("# ") { return String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
            if !t.isEmpty && !t.hasPrefix("#") { break }
        }
        return nil
    }
    static func humanizedFilename(_ url: URL?) -> String {
        guard let s = url?.deletingPathExtension().lastPathComponent, !s.isEmpty else { return "Untitled" }
        return s.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ").capitalized
    }
    static func isISODate(_ s: String) -> Bool { s.wholeMatch(of: #/^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}(:\d{2})?)?/#) != nil }
}
```
**Better:** parse ONCE into typed `ParsedNote` (routes `_`-keys + wikilink fields + kinds), reusing the
hardened flat parser instead of a 2nd YAML reader.

## 2. Dynamic [[wikilink]] relationships + inverses — `NEW Epistemos/Graph/FrontmatterRelationshipReconciler.swift`
Tolaria: any wikilink-valued field = edge keyed by field name; inverses **recomputed in renderer**.
**Upgrade:** persist forward+inverse typed edges into `GraphStore`, diffed/idempotent on rescan.

```swift
@MainActor public enum FrontmatterRelationshipReconciler {
    static func edgeID(src: String, field: String, dst: String, inverse: Bool) -> String {
        "fmrel:\(inverse ? "inv:" : "")\(src)::\(field)::\(dst)"
    }
    static func edgeType(forField f: String) -> GraphEdgeType {
        switch f.lowercased() {
        case "cites","citation","references": return .cites          // [VERIFIED-CODE]
        case "mentions": return .mentions
        case "contains","has","children": return .contains
        default: return .related
        }
    }
    public static func reconcile(noteID: String, parsed: ParsedNote, store: GraphStore,
                                 resolveID: (String) -> String?) {
        var desired: [String: GraphEdgeRecord] = [:]; let now = Date()
        for (field, dests) in parsed.relationships {
            let type = edgeType(forField: field)
            for raw in dests {
                guard let canon = WikilinkResolver.canonicalDestination(raw),
                      let dstID = resolveID(canon) else { continue }            // dangling -> skip
                let fwd = edgeID(src: noteID, field: field, dst: dstID, inverse: false)
                desired[fwd] = GraphEdgeRecord(id: fwd, sourceNodeId: noteID, targetNodeId: dstID,
                                               type: type, weight: 1.0, createdAt: now)
                let inv = edgeID(src: dstID, field: field, dst: noteID, inverse: true)
                desired[inv] = GraphEdgeRecord(id: inv, sourceNodeId: dstID, targetNodeId: noteID,
                                               type: type, weight: 0.5, createdAt: now)
            }
        }
        let current = store.edges(for: noteID).filter { $0.id.hasPrefix("fmrel:") }
        for e in current where desired[e.id] == nil { store.removeEdge(e.id) }
        let existing = Set(current.map(\.id))
        for (id, e) in desired where !existing.contains(id) { store.addEdge(e) }
    }
}
```
Wire-in (one line at the save/import seam after the note's node exists):
```swift
FrontmatterRelationshipReconciler.reconcile(
    noteID: page.id,
    parsed: NoteOntologyParser.parse(content: rawMD, filePath: page.filePath.map(URL.init(fileURLWithPath:))),
    store: graphStore, resolveID: { graphStore.firstNode(matchingTitle: $0)?.id })
```
**Better:** persisted forward+inverse typed edges → multi-hop queries, centrality, O(1) backlinks; diff-upsert = idempotent rescans.

## 3. `_`-system-properties — `NEW Epistemos/Sync/SystemKeys.swift`
Tolaria: `_`-prefixed = app-managed, hidden from Properties UI, excluded from search/relationship/indexing;
write canonical `_key`, read legacy aliases.
```swift
nonisolated public enum SystemKeys {
    public static let aliases: [String: Set<String>] = [
        "_archived":["archived","is_archived"], "_icon":["icon"], "_order":["order","sort_order"],
        "_width":["width","note_width"], "_favorite":["favorite","favourite"], "_organized":["organized"],
        "_sort":["sort"], "_display":["display"] ]
    public static func isSystemKey(_ k: String) -> Bool { k.hasPrefix("_") || aliases.values.contains { $0.contains(k) } }
    public static func canonicalize(_ k: String) -> String {
        if k.hasPrefix("_") { return k }
        for (c, legacy) in aliases where legacy.contains(k) { return c }; return k
    }
    public static func isIndexable(propertyKey k: String) -> Bool { !isSystemKey(k) }
}
```
Filters at 3 call sites: Properties UI (`BlockPropertySheet.swift` → `filter { SystemKeys.isIndexable... }`),
shadow crawler (`ShadowVaultBootstrapper.loadDocument(.notes)` → index body + non-system props only),
RRF body projection (`ReadableBlocksProjector` → skip `_`-keyed blocks). **Better:** one alias-aware table
enforced across FTS+HNSW+graph; legacy-read/canonical-write, no rewrite churn.

## 4. Views (all/any filter tree) — `NEW Epistemos/Sync/ViewDefinition.swift` + `ViewEvaluator.swift`
Tolaria: `.yml` in-vault, recursive all(AND)/any(OR) of `{field,op,value}`, ops equals/contains/any_of/
before/after + NL relative dates, **client array scan**. **Upgrade:** compile the SAME tree to indexed GRDB
SQL over `readable_blocks`, add a `semantic:` op via shadow HNSW fused with RRF.
```swift
public indirect enum FilterNode: Codable, Sendable { case all([FilterNode]); case any([FilterNode]); case cond(Condition) }
public struct Condition: Codable, Sendable { public let field: String; public let op: FilterOp; public let value: String }
public enum FilterOp: String, Codable, Sendable {
    case equals; case notEquals="not_equals"; case contains; case notContains="not_contains"
    case anyOf="any_of"; case noneOf="none_of"; case isEmpty="is_empty"; case isNotEmpty="is_not_empty"
    case before; case after; case semantic   // Epistemos-only superset (HNSW)
}
public struct ViewDefinition: Codable, Sendable { public let name: String; public let filter: FilterNode; public let sort: String? }

public enum ViewCompiler {  // -> (sqlWhere, args) over readable_blocks
    public static func compileSQL(_ n: FilterNode, now: Date = Date()) -> (String, StatementArguments) {
        switch n {
        case .all(let k): let p = k.map { compileSQL($0, now: now) }
            return ("(" + p.map(\.0).joined(separator: " AND ") + ")", p.reduce(StatementArguments()){ $0 + $1.1 })
        case .any(let k): let p = k.map { compileSQL($0, now: now) }
            return ("(" + p.map(\.0).joined(separator: " OR ") + ")", p.reduce(StatementArguments()){ $0 + $1.1 })
        case .cond(let c): return compileCond(c, now: now)
        }
    }
    static func col(_ f: String) -> String { f == "title" ? "title_path" : (f == "updated" ? "updated_at" : "body") }
    static func compileCond(_ c: Condition, now: Date) -> (String, StatementArguments) {
        let col = col(c.field)
        switch c.op {
        case .equals: return ("\(col) = ?", [c.value]); case .notEquals: return ("\(col) <> ?", [c.value])
        case .contains: return ("\(col) LIKE ?", ["%\(c.value)%"]); case .notContains: return ("\(col) NOT LIKE ?", ["%\(c.value)%"])
        case .anyOf: let it = c.value.split(separator: ",").map{ String($0).trimmingCharacters(in:.whitespaces) }
            return ("(" + it.map{_ in "\(col) LIKE ?"}.joined(separator:" OR ") + ")", StatementArguments(it.map{"%\($0)%"}))
        case .noneOf: let it = c.value.split(separator: ",").map{ String($0).trimmingCharacters(in:.whitespaces) }
            return ("(" + it.map{_ in "\(col) NOT LIKE ?"}.joined(separator:" AND ") + ")", StatementArguments(it.map{"%\($0)%"}))
        case .isEmpty: return ("(\(col) IS NULL OR \(col) = '')", []); case .isNotEmpty: return ("(\(col) IS NOT NULL AND \(col) <> '')", [])
        case .before: return ("\(col) < ?", [RelativeDate.resolveISO(c.value, now: now)])
        case .after: return ("\(col) > ?", [RelativeDate.resolveISO(c.value, now: now)])
        case .semantic: return ("1=1", [])   // handled out-of-band in evaluate()
        }
    }
}
public enum RelativeDate {  // "3 days ago"/"today" -> ISO
    public static func resolveISO(_ phrase: String, now: Date) -> String {
        let iso = ISO8601DateFormatter(); let p = phrase.lowercased().trimmingCharacters(in:.whitespaces)
        if p == "today" { return iso.string(from: Calendar.current.startOfDay(for: now)) }
        if let m = p.firstMatch(of: #/(\d+)\s+(day|week|month)s?\s+ago/#), let n = Int(m.1) {
            let comp: Calendar.Component = m.2 == "week" ? .day : (m.2 == "day" ? .day : .month)
            let back = m.2 == "week" ? -n*7 : -n
            if let d = Calendar.current.date(byAdding: comp, value: back, to: now) { return iso.string(from: d) }
        }
        return p
    }
}
```
Evaluator fuses structured SQL IDs with an optional `semantic:` HNSW query via `fusedSearchAsync` (RRF k=60).
Canonical on-disk form `<vault>/.epcache/views/*.yml` (git-syncs like Tolaria's `.laputa/views/`).
**Better:** indexed SQL + a `semantic:` op no Tolaria view can express, RRF-fused; NL dates → real ISO bounds.

## 5. Note-width toggle — `NEW Epistemos/Views/Notes/NoteWidthMode.swift`
Tolaria: binary normal/wide; toolbar + Settings default; persist to `_width` **only if frontmatter exists**.
```swift
public enum NoteWidthMode: String, Sendable { case normal, wide }
@MainActor public final class NoteWidthResolver {
    private var session: [String: NoteWidthMode] = [:]
    var settingsDefault: NoteWidthMode { NoteWidthMode(rawValue: UserDefaults.standard.string(forKey:"note_width_mode") ?? "normal") ?? .normal }
    public func resolve(noteID: String, parsed: ParsedNote) -> NoteWidthMode {
        if let s = session[noteID] { return s }
        if let raw = parsed.systemProps["_width"], let m = NoteWidthMode(rawValue: raw) { return m }
        return settingsDefault
    }
    /// THE GUARD: persist into frontmatter only if the note already HAS frontmatter; else transient.
    public func setWidth(_ mode: NoteWidthMode, noteID: String, rawMarkdown: String) -> String? {
        session[noteID] = mode
        guard hasFrontmatterBlock(rawMarkdown) else { return nil }
        return upsertFrontmatterKey("_width", value: mode.rawValue, in: rawMarkdown)
    }
    func hasFrontmatterBlock(_ md: String) -> Bool {
        let c = md.hasPrefix("\u{FEFF}") ? String(md.dropFirst()) : md
        return c.hasPrefix("---\n") || c.hasPrefix("---\r\n")
    }
}
```
**Better:** `_width` is a first-class `SystemKeys` entry (auto-hidden/excluded everywhere); pure testable resolver.

## 6. Types as md files — `NEW Epistemos/Graph/TypeRegistry.swift`
Tolaria: a `type: Type` note declares `_icon`/`color`/`template`/`_order`; defaults at creation only; no enforcement.
**Upgrade:** in-memory registry derived from `SDPage` (NO new SwiftData entity) + ADVISORY schema-light validation.
```swift
public struct TypeDefinition: Sendable, Hashable {
    public let name: String; public let icon: String?; public let color: String?
    public let template: String?; public let order: Int?
    public let declaredKinds: [String: PropertyKind]   // reuses EXISTING PropertyKind
}
@MainActor public final class TypeRegistry {
    private(set) var byName: [String: TypeDefinition] = [:]
    public func rebuild(from pages: [SDPage]) {                              // [VERIFIED-CODE: SDPage]
        var map: [String: TypeDefinition] = [:]
        for page in pages {
            let p = NoteOntologyParser.parse(content: page.loadBody(),
                       filePath: page.filePath.map(URL.init(fileURLWithPath:)))
            guard p.type == "Type" else { continue }
            map[p.title] = TypeDefinition(name: p.title, icon: p.systemProps["_icon"],
                color: p.properties["color"].flatMap(stringValue), template: p.properties["template"].flatMap(stringValue),
                order: p.systemProps["_order"].flatMap{ Int($0) }, declaredKinds: inferDeclaredKinds(p))
        }
        byName = map
    }
    public func defaults(forType t: String) -> [String:String] {            // AT CREATION ONLY
        guard let d = byName[t] else { return [:] }; var out: [String:String] = [:]
        if let i = d.icon { out["_icon"] = i }; return out
    }
    public func validate(_ p: ParsedNote) -> [ValidationHint] {             // ADVISORY — never blocks
        guard let t = p.type, let d = byName[t] else { return [] }
        return d.declaredKinds.compactMap { (k, declared) in
            guard let actual = p.properties[k], !kindMatches(actual, declared) else { return nil }
            return ValidationHint(key: k, message: "‘\(k)’ expects \(declared.rawValue)")
        }
    }
}
public struct ValidationHint: Sendable, Hashable { public let key: String; public let message: String }
```
**Better:** zero-migration in-memory projection + gentle typed-editor hints (reuses existing `PropertyKind`); retype = still just rewriting `type:`.

## 7. Git-aware incremental rescan — `EXTEND Epistemos/Engine/ShadowVaultBootstrapper.swift`
Tolaria: same-HEAD `git status` / diff-HEAD / full walkdir; `CACHE_VERSION=14` full-rebuild on bump.
**Upgrade:** per-note content-hash deltas into GRDB+shadow+graph; additive (no version-bump wipe).
```swift
extension ShadowVaultBootstrapper {
    public struct ScanDelta: Sendable { public let added:[URL]; public let modified:[URL]; public let removed:[String] }
    public func incrementalCrawl(priorHashes: [String:String]) async -> ScanDelta {
        let files = discover(domain: .notes)
        var added:[URL]=[], modified:[URL]=[], seen=Set<String>(), newHashes:[String:String]=[:]
        for url in files {
            guard let docID = Self.vaultRelativeDocId(for: url, vaultRoot: vaultRoot),
                  let body = try? Self.loadMarkdownBodyPrefix(from: url) else { continue }
            seen.insert(docID); let h = SDPage.bodyHash(body); newHashes[docID] = h   // [VERIFIED-CODE] SHA256
            switch priorHashes[docID] {
            case .none: added.append(url)
            case .some(let p) where p != h: modified.append(url)
            default: break }   // unchanged -> skip all 3 engines
        }
        let removed = priorHashes.keys.filter { !seen.contains($0) }
        for url in added + modified {
            guard let dto = await loadDocument(url: url, domain: .notes) else { continue }
            await indexer.enqueueInsert(dto)   // shadow HNSW+BM25
            let parsed = NoteOntologyParser.parse(content:(try? Self.loadMarkdownBodyPrefix(from:url)) ?? "", filePath:url)
            await onDelta?(url, parsed)         // host wires GRDB upsert + reconciler(2)
        }
        for id in removed { indexer.enqueueRemove(docId: id) }
        await onRemoved?(removed)
        return ScanDelta(added: added, modified: modified, removed: removed)
    }
}
```
Optional git fast-path narrows the file set first (`git status --porcelain` / `git diff --name-only`) via the
EXISTING hardened subprocess helpers (`agent_core/src/security.rs harden_cli_subprocess_std`). Prior hashes in a
small GRDB `note_scan_hash` table (vs `~/.laputa/cache/<hash>.json`).
**Better:** per-note deltas into 3 engines at once + additive migrations + replayable via DAG/ledger.

---

## File-by-file map
| # | Snippet | Path | Add/Extend |
|---|---|---|---|
| 1 | `NoteOntologyParser`/`FMValue`/`ParsedNote` | `Epistemos/Sync/NoteOntologyParser.swift` | Add (reuses `parseFrontMatter`) |
| 2 | `FrontmatterRelationshipReconciler` | `Epistemos/Graph/FrontmatterRelationshipReconciler.swift` (+1 call in `VaultSyncService`) | Add |
| 3 | `SystemKeys` | `Epistemos/Sync/SystemKeys.swift` (+filters in BlockPropertySheet/ShadowVaultBootstrapper/ReadableBlocksProjector) | Add+Extend |
| 4 | `ViewDefinition`/`ViewCompiler`/`RelativeDate`/`ViewEvaluator` | `Epistemos/Sync/ViewDefinition.swift` + `ViewEvaluator.swift` | Add |
| 5 | `NoteWidthMode`/`NoteWidthResolver` | `Epistemos/Views/Notes/NoteWidthMode.swift` (+toolbar/Settings) | Add |
| 6 | `TypeRegistry`/`TypeDefinition`/`ValidationHint` | `Epistemos/Graph/TypeRegistry.swift` (+hints in BlockPropertySheet) | Add |
| 7 | `incrementalCrawl`/`ScanDelta` | `Epistemos/Engine/ShadowVaultBootstrapper.swift` | Extend |

**Net:** keep Tolaria's files-are-truth/no-enforcement/`_`-convention axioms; upgrade the DERIVED layer into 3
real indices (GRDB FTS `readable_blocks` + shadow HNSW + typed `GraphStore`) unified by `RRFFusionQuery`
(k=60), with persisted bidirectional typed relationships, a `semantic:` view op, per-note incremental reindex,
and advisory schema-light validation. Only [INFERRED] judgment calls: note-width design (no `_width` today)
and the field→`GraphEdgeType` mapping.
