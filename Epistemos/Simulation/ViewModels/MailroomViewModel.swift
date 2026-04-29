//
//  MailroomViewModel.swift
//  Simulation Mode S11 — observable state for the Mailroom
//  inventory surface (DOCTRINE §7.4 step 1).
//

import Foundation
import Observation

@MainActor
@Observable
public final class MailroomViewModel {
    public private(set) var inbox: [GiftBoxFfi] = []
    public private(set) var refreshError: String?

    private let bridge: CompanionRegistryBridge

    public init(bridge: CompanionRegistryBridge) {
        self.bridge = bridge
    }

    public func refresh(for companion: CompanionId) async {
        do {
            let boxes = try await bridge.listInbox(for: companion)
            self.inbox = boxes
            self.refreshError = nil
        } catch {
            self.refreshError = "\(error)"
        }
    }

    /// Drop a gift-box from the local cache after a successful
    /// unwrap (the underlying directory still exists on disk
    /// until the host moves it to a `consumed/` subfolder, but
    /// the Mailroom UI shouldn't show it again). Caller is
    /// responsible for the disk-side move.
    public func remove(epboxId: String) {
        inbox.removeAll { $0.id == epboxId }
    }
}

extension CompanionRegistryBridge {
    public func listInbox(for companion: CompanionId) throws -> [GiftBoxFfi] {
        try epistemosCompanionsListInbox(
            handle: handle, companionId: companion.rawValue
        )
    }

    public func revertGiftbox(
        for companion: CompanionId, applied: AppliedGiftBoxFfi
    ) throws {
        try epistemosCompanionsRevertGiftbox(
            handle: handle, companionId: companion.rawValue, applied: applied
        )
    }
}
