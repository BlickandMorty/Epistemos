import SwiftUI

// MARK: - SubstrateHealthClock (SS-SH single-clock collapse)
//
// The substrate-health panel used to run ~17 independent per-row 1 Hz
// `Task.sleep` timers — each waking the scheduler every second for the life of
// the panel (even while its section was collapsed) and each needing its own
// `.onDisappear` cancellation (which collapsed `Section`s don't fire reliably).
// This collapses them onto ONE shared clock: the panel owns a single
// `SubstrateHealthClock`, drives it from a single `.task` loop, and injects it
// into the environment. Rows observe `tick` via `.substrateHealthPoll` and run
// their own (already off-MainActor) `refresh()` on each tick instead of owning
// a timer. One timer instead of ~17, deterministic teardown (the panel's
// `.task` auto-cancels when the panel leaves), and no change to any row's fetch.
//
// Slice 1 wires the infra + the 3 byte-identical unified-snapshot rows
// (EmlObservatory / CognitiveDagCounts / SubstrateDriftMonitor). The remaining
// timer rows migrate onto the same clock in follow-up slices.

@MainActor
@Observable
public final class SubstrateHealthClock {
    /// Monotonic 1 Hz tick. Rows observe this to re-run their refresh.
    public private(set) var tick: Int = 0

    public init() {}

    /// Advance one tick. Called once per second by the panel's single driver.
    public func advance() {
        tick &+= 1
    }
}

private struct SubstrateHealthPollModifier: ViewModifier {
    // Optional: rows are also mounted standalone (e.g. SwiftUI #Preview) where
    // no clock is injected — there they refresh once on appear and don't poll,
    // never crashing on a missing environment value.
    @Environment(SubstrateHealthClock.self) private var clock: SubstrateHealthClock?
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear { action() }
            .onChange(of: clock?.tick) { _, _ in action() }
    }
}

extension View {
    /// SS-SH: subscribe this row to the panel's single shared 1 Hz clock. Runs
    /// `action` once on appear and again on every shared tick — replacing the
    /// row's own per-row `Task.sleep` timer. When no clock is in the environment
    /// (standalone/preview) it simply refreshes once and does not poll.
    func substrateHealthPoll(_ action: @escaping () -> Void) -> some View {
        modifier(SubstrateHealthPollModifier(action: action))
    }
}
