//
//  LandingFarmViewModel.swift
//  Simulation Mode S5 — Landing Farm view-model.
//
//  @MainActor + @Observable per the project's @Observable-not-
//  ObservableObject standard (CLAUDE.md). Holds the current
//  set of CompanionFarmEntry rows + a refresh API. The view
//  reactively redraws on `companions` changes via the
//  Observation framework.
//

import Foundation
import Observation
import OSLog

@MainActor
@Observable
public final class LandingFarmViewModel {
    public private(set) var companions: [CompanionFarmEntry] = []
    public private(set) var isLoading: Bool = false
    public private(set) var lastError: String?

    /// IDs created during this session — used to drive the
    /// rainbow-flash entrance for the most recent batch
    /// (DOCTRINE §3.2 `JustAcquired` row).
    public private(set) var pendingFlashIds: Set<CompanionId> = []

    private let bridge: CompanionRegistryBridge
    private let logger = Logger(
        subsystem: SimSignpost.subsystem, category: "LandingFarmViewModel"
    )

    public init(bridge: CompanionRegistryBridge) {
        self.bridge = bridge
    }

    /// Re-load the Farm view. Called on appear and after
    /// mutating operations.
    public func refresh() async {
        isLoading = true
        defer { isLoading = false }
        let next = await bridge.listActive()
        // Companions in `next` whose ids are NOT in the previous
        // set are new — flag them for the rainbow-flash entrance.
        let priorIds = Set(self.companions.map(\.id))
        let newlyAppeared = next.map(\.id).filter { !priorIds.contains($0) }
        for id in newlyAppeared {
            pendingFlashIds.insert(id)
        }
        self.companions = next
    }

    /// Fire-and-forget: create a Local Helper preset, then
    /// refresh the list. The new companion lands as
    /// `JustAcquired` and the `pendingFlashIds` set picks it
    /// up so the SwiftUI tile triggers the rainbow flash on
    /// first render.
    public func createLocalHelper(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "name is required"
            return
        }
        do {
            _ = try await bridge.createLocalHelper(name: trimmed)
            lastError = nil
            await refresh()
        } catch {
            logger.error("createLocalHelper failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    /// Archive a companion. Removes from `companions` after
    /// the next refresh.
    public func archive(_ id: CompanionId) async {
        do {
            try await bridge.archive(id, reason: nil)
            await refresh()
        } catch {
            logger.error("archive failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    /// Acknowledge that the rainbow-flash entrance for `id`
    /// has played. The view-model removes it from
    /// `pendingFlashIds` so the same companion doesn't flash
    /// again on the next refresh.
    public func acknowledgeFlash(_ id: CompanionId) {
        pendingFlashIds.remove(id)
    }
}
