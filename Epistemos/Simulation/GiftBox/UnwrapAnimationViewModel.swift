//
//  UnwrapAnimationViewModel.swift
//  Simulation Mode S11 — honesty-bound unwrap animation per
//  DOCTRINE §7.4 + I-11.
//
//  CRITICAL per I-11: "Adapter unwrap animation duration ≥
//  adapter apply duration." This view model enforces that
//  contract — the wait phase races the apply branch against a
//  ticker branch in a `TaskGroup`; the success / failure phase
//  ONLY fires after `await applyTask.value` returns. There is
//  no `phase = .success` path that doesn't wait for apply.
//

import Foundation
import Observation

/// Six phases per §7.4. The animation timeline runs:
///
///     idle → approaching (400 ms)
///          → opening     (300 ms)
///          → waiting     (TaskGroup race: apply vs. 500 ms-tick
///                         ticker; ticker shows progress chip
///                         after 8 ticks)
///          → success | failure (1 s each)
///          → idle
public enum UnwrapPhase: String, Sendable, Hashable {
    case idle
    case approaching
    case opening
    case waiting
    case success
    case failure
}

/// Result of one apply call returned from the Rust bridge.
public struct UnwrapOutcome: Sendable {
    public let appliedGiftBox: AppliedGiftBoxFfi?
    public let errorMessage: String?

    public var didSucceed: Bool { appliedGiftBox != nil }
}

/// Race outcome from the wait-phase TaskGroup.
private enum ApplyOrTick: Sendable {
    case applied(AppliedGiftBoxFfi)
    case failed(String)
    case ceilingPassed
}

@MainActor
@Observable
public final class UnwrapAnimationViewModel {
    public private(set) var phase: UnwrapPhase = .idle
    /// `true` after the ticker branch exhausted its 8-tick
    /// ceiling (≈ 4 s). The UI surfaces a progress chip so
    /// the user knows the apply is still in flight.
    public private(set) var progressChipVisible: Bool = false
    /// Last apply's outcome — surfaced to the host so it can
    /// either advance to the chat surface (success) or return
    /// the gift-box to the inbox (failure).
    public private(set) var lastOutcome: UnwrapOutcome?

    /// Per §7.4 timing contract.
    public static let approachingDurationMs: Int = 400
    public static let openingDurationMs: Int = 300
    public static let waitTickDurationMs: Int = 500
    public static let waitTickCeiling: Int = 8
    public static let resolutionDurationMs: Int = 1000

    private let bridge: CompanionRegistryBridge

    public init(bridge: CompanionRegistryBridge) {
        self.bridge = bridge
    }

    /// Run the unwrap animation in lock-step with the Rust
    /// apply call. The animation duration is mathematically
    /// guaranteed ≥ apply duration:
    ///   1. approaching + opening (700 ms minimum)
    ///   2. waiting branch holds until applyTask finishes
    ///      (TaskGroup race; first non-ticker yield wins)
    ///   3. success / failure (1 s each)
    /// → animation_duration ≥ apply_duration whenever apply ≤
    ///   1700 ms; for longer applies, the ticker branch keeps
    ///   the visible animation going until apply returns.
    public func unwrap(
        companionId: CompanionId,
        epboxPath: String
    ) async {
        guard phase == .idle else { return }
        progressChipVisible = false
        lastOutcome = nil

        phase = .approaching
        try? await Task.sleep(for: .milliseconds(Self.approachingDurationMs))

        phase = .opening
        try? await Task.sleep(for: .milliseconds(Self.openingDurationMs))

        phase = .waiting

        let bridge = self.bridge
        let companionId = companionId
        let epboxPath = epboxPath
        let tickCeiling = Self.waitTickCeiling
        let tickMs = Self.waitTickDurationMs

        let result: ApplyOrTick = await withTaskGroup(of: ApplyOrTick.self) { group in
            // Apply branch — eventually yields applied/failed.
            group.addTask {
                do {
                    let applied = try await bridge.applyGiftbox(
                        companionId: companionId, epboxPath: epboxPath
                    )
                    return .applied(applied)
                } catch {
                    return .failed("\(error)")
                }
            }

            // Ticker branch — sleeps tickCeiling × tickMs then
            // signals "ceiling passed" (the host then surfaces
            // the progress chip + waits for apply). After
            // signalling once, idles until cancelled.
            group.addTask {
                for _ in 0..<tickCeiling {
                    try? await Task.sleep(for: .milliseconds(tickMs))
                }
                return .ceilingPassed
            }

            // First yield wins. Most of the time apply is far
            // faster than 4 s and wins immediately; for slow
            // applies the ticker yields .ceilingPassed which
            // the outer code treats as "show chip, keep
            // waiting".
            guard let first = await group.next() else {
                return .failed("no task yielded")
            }
            if case .ceilingPassed = first {
                // Surface the progress chip + wait for apply
                // to finish. The apply branch is still
                // running in the group.
                await MainActor.run { self.progressChipVisible = true }
                guard let second = await group.next() else {
                    return .failed("apply branch never yielded")
                }
                group.cancelAll()
                return second
            }
            group.cancelAll()
            return first
        }

        switch result {
        case .applied(let applied):
            lastOutcome = UnwrapOutcome(appliedGiftBox: applied, errorMessage: nil)
            phase = .success
        case .failed(let msg):
            lastOutcome = UnwrapOutcome(appliedGiftBox: nil, errorMessage: msg)
            phase = .failure
        case .ceilingPassed:
            // Defensive — should never happen because apply
            // branch always eventually yields.
            lastOutcome = UnwrapOutcome(
                appliedGiftBox: nil, errorMessage: "apply timed out"
            )
            phase = .failure
        }
        progressChipVisible = false

        try? await Task.sleep(for: .milliseconds(Self.resolutionDurationMs))
        phase = .idle
    }

    /// Reset the VM mid-animation. Used by the host when the
    /// user cancels the unwrap (e.g. closes the modal). The
    /// in-flight applyTask is NOT cancelled — Rust transactions
    /// are atomic and return an outcome regardless; the UI just
    /// stops observing.
    public func cancel() {
        phase = .idle
        progressChipVisible = false
    }
}

// MARK: - Sendable conformance for UniFFI Records

// AppliedGiftBoxFfi + GiftBoxFfi are POD structs generated by
// UniFFI — every field is itself Sendable (String / u64 / Bool).
// UniFFI doesn't add Sendable conformance automatically; we
// declare it here as @unchecked because the compiler can't see
// the field shapes from outside the generated file.
extension AppliedGiftBoxFfi: @unchecked Sendable {}
extension GiftBoxFfi: @unchecked Sendable {}

// MARK: - Bridge applyGiftbox extension

extension CompanionRegistryBridge {
    /// Async wrapper around the FFI export. The actor-isolation
    /// makes this safe to call from the @MainActor unwrap VM —
    /// the FFI call hops to the bridge actor's executor, and the
    /// returned Sendable value comes back across the boundary.
    public func applyGiftbox(
        companionId: CompanionId, epboxPath: String
    ) async throws -> AppliedGiftBoxFfi {
        try epistemosCompanionsApplyGiftbox(
            handle: handle,
            companionId: companionId.rawValue,
            epboxPath: epboxPath
        )
    }
}
