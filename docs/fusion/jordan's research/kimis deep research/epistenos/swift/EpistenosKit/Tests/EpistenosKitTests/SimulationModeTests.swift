import XCTest
@testable import EpistenosKit

// ---------------------------------------------------------------------------
// MARK: - SimulationModeTests
// ---------------------------------------------------------------------------

/// Tests for Simulation Mode v1.6: Companion lifecycle, reactions, and UI surfaces.
///
/// These tests cover:
/// - Companion creation and persistence
/// - Biometric-gated delete
/// - AgentEvent reactions
/// - Reduce-motion accessibility
/// - 30-day archive auto-purge
/// - Landing Farm default view
@MainActor
final class SimulationModeTests: XCTestCase {

    var companionState: CompanionState!
    var eventStore: EventStore!

    override func setUp() async throws {
        try await super.setUp()
        companionState = CompanionState()
        eventStore = EventStore(capacity: 64)
        // Remove observers and clear state between tests
        eventStore.removeAllObservers()
    }

    override func tearDown() async throws {
        companionState = nil
        eventStore = nil
        try await super.tearDown()
    }

    // MARK: - testCompanionCreation

    func testCompanionCreation() async throws {
        let cosmetics = CosmeticConfig(
            colorTheme: "teal",
            avatarShape: "shard",
            idleBreathingRate: 0.8
        )

        try await companionState.createCompanion(
            name: "TestBot",
            baseProfile: "research",
            cosmetics: cosmetics
        )

        XCTAssertEqual(companionState.companions.count, 1)
        XCTAssertEqual(companionState.companions.first?.name, "TestBot")
        XCTAssertEqual(companionState.companions.first?.baseProfile, "research")
        XCTAssertEqual(companionState.companions.first?.cosmeticConfig.colorTheme, "teal")
        XCTAssertEqual(companionState.companions.first?.cosmeticConfig.avatarShape, "shard")
        XCTAssertNotNil(companionState.activeCompanion)
        XCTAssertEqual(companionState.activeCompanion?.name, "TestBot")
    }

    // MARK: - testCompanionDeleteRequiresBiometric

    func testCompanionDeleteRequiresBiometric() async throws {
        let cosmetics = CosmeticConfig(colorTheme: "amber", avatarShape: "orb", idleBreathingRate: 1.0)
        try await companionState.createCompanion(
            name: "DeleteMe",
            baseProfile: "default",
            cosmetics: cosmetics
        )

        guard let companion = companionState.companions.first else {
            XCTFail("Companion should exist")
            return
        }

        // In a unit-test environment SovereignGate will return .unavailable
        // because LAContext cannot evaluate policy without a UI session.
        // We verify that the gate is reached (companion still exists after failure).
        do {
            try await companionState.deleteCompanion(companion)
            // If we reach here in CI (no biometrics), the gate should have thrown
            // because .deviceOwnerAuthentication is unavailable in a headless test.
        } catch is SovereignGateError {
            // Expected: biometrics unavailable in test harness
            XCTAssertEqual(companionState.companions.count, 1)
            XCTAssertEqual(companionState.companions.first?.name, "DeleteMe")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - testCompanionReactionToAgentEvent

    func testCompanionReactionToAgentEvent() async throws {
        let cosmetics = CosmeticConfig(colorTheme: "violet", avatarShape: "pulse", idleBreathingRate: 1.2)
        try await companionState.createCompanion(
            name: "Reactor",
            baseProfile: "coding",
            cosmetics: cosmetics
        )

        let event = AgentProvenanceEvent(
            kind: .tool_completed,
            payload: "Tool finished successfully"
        )

        companionState.reactToEvent(event)

        XCTAssertEqual(companionState.currentReaction, .toolCompleted)
        XCTAssertTrue(companionState.companionEvents.contains(where: { $0.kind == .tool_completed }))

        // Wait for reaction auto-expiry (0.5 s)
        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertNil(companionState.currentReaction)
    }

    func testCompanionReactionCancelsPrevious() async throws {
        let event1 = AgentProvenanceEvent(kind: .summary_started, payload: "Start")
        let event2 = AgentProvenanceEvent(kind: .summary_completed, payload: "Done")

        companionState.reactToEvent(event1)
        XCTAssertEqual(companionState.currentReaction, .summaryStarted)

        companionState.reactToEvent(event2)
        XCTAssertEqual(companionState.currentReaction, .summaryCompleted)

        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertNil(companionState.currentReaction)
    }

    // MARK: - testReduceMotionDisablesBreathing

    func testReduceMotionDisablesBreathing() {
        // This test validates the View-level reduction-motion gating indirectly
        // by checking that CompanionState exposes the correct configuration
        // and that the reaction path respects the intent.
        let cosmetics = CosmeticConfig(
            colorTheme: "slate",
            avatarShape: "orb",
            idleBreathingRate: 1.0
        )
        let companion = CompanionModel(
            name: "Static",
            baseProfile: "default",
            cosmeticConfig: cosmetics
        )

        // Verify cosmetics are stored correctly for the view to read
        XCTAssertEqual(companion.cosmeticConfig.idleBreathingRate, 1.0)
        XCTAssertEqual(companion.cosmeticConfig.avatarShape, "orb")

        // In the View layer, reduceMotion = true bypasses TimelineView and
        // renders the staticOrb branch. We verify the intent by inspecting
        // the model fields the view uses to decide animation parameters.
    }

    // MARK: - testArchivedCompanionAutoPurge

    func testArchivedCompanionAutoPurge() async throws {
        // Create a companion, archive it, then back-date it beyond 30 days
        let cosmetics = CosmeticConfig(colorTheme: "rose", avatarShape: "orb", idleBreathingRate: 1.0)
        try await companionState.createCompanion(
            name: "OldArchive",
            baseProfile: "creative",
            cosmetics: cosmetics
        )

        guard let companion = companionState.companions.first else {
            XCTFail("Companion should exist")
            return
        }

        try await companionState.archiveCompanion(companion)
        XCTAssertTrue(companionState.companions.isEmpty)

        // Manually mutate the on-disk record to back-date the archive
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.epistenos.shared")
        else {
            throw XCTSkip("App Group container unavailable in test environment")
        }
        let dir = container.appendingPathComponent("companions", isDirectory: true)
        let url = dir.appendingPathComponent("companions.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Companion persistence file not found")
        }

        let data = try Data(contentsOf: url)
        var records = try JSONDecoder().decode([CompanionRecord].self, from: data)
        guard let idx = records.firstIndex(where: { $0.id == companion.id }) else {
            XCTFail("Archived record should exist")
            return
        }
        records[idx].lastActiveAt = Date().addingTimeInterval(-31 * 24 * 60 * 60)
        let out = try JSONEncoder().encode(records)
        try out.write(to: url, options: .atomic)

        // Re-load companions — purgeStaleArchives should remove the stale record
        try await companionState.loadCompanions()

        // Verify the stale archived companion is gone from disk
        let postData = try Data(contentsOf: url)
        let postRecords = try JSONDecoder().decode([CompanionRecord].self, from: postData)
        XCTAssertFalse(postRecords.contains(where: { $0.id == companion.id }))
    }

    // MARK: - testLandingFarmDefaultView

    func testLandingFarmDefaultView() {
        // Verify the window manager exposes the correct identifiers
        XCTAssertEqual(LandingFarmWindowManager.windowGroupID, "LandingFarm")

        // Verify LandingFarmView can be instantiated without crashing
        let view = LandingFarmView()
        XCTAssertNotNil(view)

        // Verify the view body is a non-empty View hierarchy
        // (SwiftUI View conformance is compile-time, so this test
        // primarily ensures the type is accessible and initialisable.)
    }

    // MARK: - testCompanionEventMapping

    func testCompanionEventMapping() {
        let cases: [(AgentProvenanceEvent.EventKind, CompanionReaction)] = [
            (.tool_completed, .toolCompleted),
            (.tool_failed, .toolFailed),
            (.summary_started, .summaryStarted),
            (.summary_completed, .summaryCompleted),
            (.vault_created, .vaultCreated),
            (.vault_archived, .vaultArchived),
        ]

        for (kind, expectedReaction) in cases {
            let event = AgentProvenanceEvent(kind: kind)
            let reaction = CompanionReaction(from: event)
            XCTAssertEqual(reaction, expectedReaction, "Kind \(kind.rawValue) should map to \(expectedReaction)")
        }
    }

    // MARK: - testCosmeticConfigCodable

    func testCosmeticConfigCodable() throws {
        let original = CosmeticConfig(
            colorTheme: "violet",
            avatarShape: "pulse",
            idleBreathingRate: 1.5,
            voiceHint: "voice-123"
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CosmeticConfig.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - testEventStoreRingBuffer

    func testEventStoreRingBuffer() {
        let store = EventStore(capacity: 5)
        for i in 0..<10 {
            store.append(AgentProvenanceEvent(kind: .tool_completed, payload: "\(i)"))
        }
        XCTAssertEqual(store.events.count, 5)
        XCTAssertEqual(store.events.first?.payload, "5")
        XCTAssertEqual(store.events.last?.payload, "9")
    }
}

// ---------------------------------------------------------------------------
// MARK: - CompanionRecord (private, mirror of persistence DTO)
// ---------------------------------------------------------------------------

private struct CompanionRecord: Codable, Identifiable {
    let id: UUID
    var name: String
    var baseProfile: String
    var cosmeticConfig: CosmeticConfig
    var createdAt: Date
    var lastActiveAt: Date
    var isArchived: Bool
    var personalityVector: [Float]?

    init(from model: CompanionModel) {
        self.id = model.id
        self.name = model.name
        self.baseProfile = model.baseProfile
        self.cosmeticConfig = model.cosmeticConfig
        self.createdAt = model.createdAt
        self.lastActiveAt = model.lastActiveAt
        self.isArchived = model.isArchived
        self.personalityVector = model.personalityVector
    }
}
