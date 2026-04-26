import Foundation
import Testing

@testable import Epistemos

/// Wave 7.13 source-guard for the in-memory `EpdocDatabase` actor.
@Suite("EpdocDatabase (Wave 7.13)")
nonisolated struct EpdocDatabaseTests {

    private static func manifest(id: String, title: String) -> EpdocManifest {
        EpdocManifest(
            id: id,
            createdAt: 0,
            updatedAt: 0,
            title: title,
            contentHash: "",
            provenance: EpdocProvenance(producer: .human)
        )
    }

    private static func row(id: String, title: String, props: [String: EpdocPropertyValue]) throws -> EpdocDatabaseRow {
        var m = Self.manifest(id: id, title: title)
        for (pid, value) in props {
            m = try EpdocPropertyMetadata.withProperty(m, id: pid, value: value)
        }
        return EpdocDatabaseRow(manifest: m)
    }

    // MARK: - Add / upsert / remove

    @Test("add appends; upsert replaces by manifest id")
    func addUpsertRemove() async throws {
        let db = EpdocDatabase()
        let r1 = try Self.row(id: "a", title: "first", props: ["status": .select("todo")])
        let r2 = try Self.row(id: "b", title: "second", props: ["status": .select("doing")])
        await db.add(r1)
        await db.add(r2)
        await #expect(db.rows.count == 2)

        // Replace r1
        let r1Updated = try Self.row(id: "a", title: "first-renamed", props: ["status": .select("done")])
        await db.upsert(r1Updated)
        await #expect(db.rows.count == 2, "upsert MUST NOT add a duplicate when id matches")

        // Remove r2
        let removed = await db.remove(manifestID: "b")
        #expect(removed)
        await #expect(db.rows.count == 1)
        await #expect(db.rows.first?.manifest.title == "first-renamed")
    }

    // MARK: - Filter

    @Test("filtered(where:) projects rows by predicate over manifest + properties")
    func filterByProperty() async throws {
        let db = EpdocDatabase()
        await db.add(try Self.row(id: "a", title: "alpha", props: ["status": .select("todo")]))
        await db.add(try Self.row(id: "b", title: "beta",  props: ["status": .select("doing")]))
        await db.add(try Self.row(id: "c", title: "gamma", props: ["status": .select("done")]))

        let inProgress = await db.filtered { row in
            row.value(forPropertyID: "status") == .select("doing")
        }
        #expect(inProgress.count == 1)
        #expect(inProgress.first?.manifest.title == "beta")
    }

    // MARK: - Sort

    @Test("sorted(byPropertyID:ascending:) places missing values LAST in both directions (deterministic)")
    func sortMissingValuesLast() async throws {
        let db = EpdocDatabase()
        await db.add(try Self.row(id: "a", title: "has-1", props: ["score": .number(1)]))
        await db.add(try Self.row(id: "b", title: "has-3", props: ["score": .number(3)]))
        await db.add(try Self.row(id: "c", title: "missing", props: [:]))
        await db.add(try Self.row(id: "d", title: "has-2", props: ["score": .number(2)]))

        let asc = await db.sorted(byPropertyID: "score", ascending: true).map(\.manifest.title)
        #expect(asc.dropLast().elementsEqual(["has-1", "has-2", "has-3"]),
                "ascending sort MUST place numeric values 1,2,3; got \(asc)")
        #expect(asc.last == "missing",
                "missing-property rows MUST sort last in ascending order; got \(asc)")

        let desc = await db.sorted(byPropertyID: "score", ascending: false).map(\.manifest.title)
        #expect(desc.dropLast().elementsEqual(["has-3", "has-2", "has-1"]),
                "descending sort MUST place numeric values 3,2,1; got \(desc)")
        #expect(desc.last == "missing",
                "missing-property rows MUST sort last in descending order too; got \(desc)")
    }

    @Test("sorted handles select / date / checkbox kinds with sane orderings")
    func sortMixedKinds() async throws {
        let db = EpdocDatabase()
        await db.add(try Self.row(id: "a", title: "false", props: ["done": .checkbox(false)]))
        await db.add(try Self.row(id: "b", title: "true",  props: ["done": .checkbox(true)]))

        let asc = await db.sorted(byPropertyID: "done", ascending: true).map(\.manifest.title)
        #expect(asc == ["false", "true"], "checkbox false MUST sort before true; got \(asc)")
    }

    // MARK: - Group

    @Test("grouped(byPropertyID:) buckets rows by select value; multiSelect explodes to N buckets")
    func groupBySelectAndMulti() async throws {
        let db = EpdocDatabase()
        await db.add(try Self.row(id: "a", title: "alpha", props: ["tag": .multiSelect(["work", "urgent"])]))
        await db.add(try Self.row(id: "b", title: "beta",  props: ["tag": .multiSelect(["work"])]))
        await db.add(try Self.row(id: "c", title: "gamma", props: ["tag": .multiSelect(["personal"])]))

        let buckets = await db.grouped(byPropertyID: "tag")
        #expect(buckets["work"]?.count == 2,    "two rows tagged 'work'; got \(buckets["work"]?.count ?? -1)")
        #expect(buckets["urgent"]?.count == 1,  "one row tagged 'urgent'; got \(buckets["urgent"]?.count ?? -1)")
        #expect(buckets["personal"]?.count == 1)
    }

    // MARK: - Schema union

    @Test("schemaUnion derives PropertyDefs from observed values when no explicit schema is set")
    func schemaUnion() async throws {
        let db = EpdocDatabase()
        await db.add(try Self.row(id: "a", title: "a", props: [
            "status": .select("doing"),
            "due":    .date("2026-04-30"),
        ]))
        await db.add(try Self.row(id: "b", title: "b", props: [
            "status": .select("done"),
            "score":  .number(0.9),
        ]))

        let derived = await db.schemaUnion()
        let byID = Dictionary(uniqueKeysWithValues: derived.map { ($0.id, $0) })
        #expect(byID["status"]?.kind == .select)
        #expect(byID["due"]?.kind == .date)
        #expect(byID["score"]?.kind == .number)
        #expect(derived.count == 3, "schemaUnion MUST surface every observed property id once")
    }

    // MARK: - End-to-end manifest binding

    @Test("EpdocDatabaseRow init decodes properties off the manifest's metadata bag")
    func rowDecodesPropsFromManifest() throws {
        let m = try EpdocPropertyMetadata.withProperty(
            Self.manifest(id: "row-decode", title: "T"),
            id: "status",
            value: .select("done")
        )
        let row = EpdocDatabaseRow(manifest: m)
        #expect(row.value(forPropertyID: "status") == .select("done"),
                "row init MUST decode every properties.* metadata key into the typed bag")
    }
}
