import Testing
import Foundation

@testable import Epistemos

// SS-AD step 1 (adapter explanations): AdapterRecord carries an optional, human-readable
// `description` (auto-seeded at registration + editable), persisted via updateDescription.
// Additive: legacy records with no `description` key decode to nil. No vault writes.
@Suite("SS-AD adapter description (step 1)")
struct SSADAdapterDescriptionTests {

    private func makeRecord(description: String?) -> AdapterRecord {
        AdapterRecord(
            id: UUID(),
            name: "test",
            type: .style,
            adapterPath: URL(fileURLWithPath: "/tmp/adapter"),
            metadataPath: URL(fileURLWithPath: "/tmp/adapter/training_metadata.json"),
            sourceVault: "vault",
            createdAt: Date(timeIntervalSince1970: 1_000),
            qualityScore: nil,
            isActive: false,
            baseModel: "model",
            loraRank: 8,
            parameterCount: 1,
            trainingExamples: 1,
            description: description
        )
    }

    @Test("description round-trips Codable, and legacy records without the key decode to nil")
    func descriptionAdditiveCodable() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        // With a description → round-trips.
        let withDesc = makeRecord(description: "Style adapter trained on My mind 2")
        let decoded = try decoder.decode(AdapterRecord.self, from: try encoder.encode(withDesc))
        #expect(decoded.description == "Style adapter trained on My mind 2")

        // Simulate a LEGACY record: encode, strip the `description` key, decode → nil.
        let data = try encoder.encode(makeRecord(description: nil))
        var obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        obj.removeValue(forKey: "description")
        let legacy = try JSONSerialization.data(withJSONObject: obj)
        let decodedLegacy = try decoder.decode(AdapterRecord.self, from: legacy)
        #expect(decodedLegacy.description == nil)
    }

    @Test("updateDescription persists the explanation")
    func updateDescriptionPersists() async throws {
        let fm = FileManager.default
        let path = fm.temporaryDirectory.appendingPathComponent("ssad-reg-\(UUID().uuidString).json")
        defer { try? fm.removeItem(at: path) }
        let registry = AdapterRegistry(storagePath: path)

        let rec = makeRecord(description: nil)
        try await registry.register(rec)
        try await registry.updateDescription(rec.id, description: "Explains what it does")
        let fetched = await registry.getAdapter(id: rec.id)
        #expect(fetched?.description == "Explains what it does")
    }
}
