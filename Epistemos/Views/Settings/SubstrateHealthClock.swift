import SwiftUI

// MARK: - SubstrateHealthClock (SS-SH single-clock collapse)
//
// The foundation panel owns one shared poll clock instead of letting every
// health row spin its own timer. Mounted rows observe `tick` via
// `.substrateHealthPoll`; the panel's `.task` gives deterministic teardown when
// Settings leaves the screen. The legacy substrate rows are no longer mounted,
// but the unified snapshot stays here for the remaining rows that still read it.

@MainActor
@Observable
public final class SubstrateHealthClock {
    public nonisolated static let defaultPollInterval: Duration = .seconds(5)

    /// Monotonic shared tick. Rows observe this to re-run their refresh.
    public private(set) var tick: Int = 0

    /// SS-SH dedup: the shared unified substrate-health snapshot. The 6 rows that
    /// previously each called `SubstrateHealthUnifiedClient.snapshotAsync()` every
    /// tick (~6 identical FFI round-trips/sec on one panel) now read this single
    /// snapshot, fetched ONCE per tick by the panel's driver (6 FFI/sec → 1).
    // Internal (not public): `SubstrateHealthUnifiedSnapshot` is an internal type, and
    // the rows that read this are in-module, so `public` isn't needed (and isn't allowed).
    private(set) var unified: SubstrateHealthUnifiedSnapshot

    public init() {
        // One sync fetch at construction so rows show data on first paint; the
        // recurring refresh below runs OFF the MainActor.
        unified = SubstrateHealthUnifiedClient.snapshot()
    }

    /// Advance one tick. Called by the panel's single shared driver.
    public func advance() {
        tick &+= 1
    }

    /// SS-SH dedup: fetch the unified snapshot ONCE per tick OFF the MainActor, then
    /// advance — the single shared replacement for the former 6 per-row
    /// `snapshotAsync()` calls. Set before the tick bumps so a row's tick-driven read
    /// sees the fresh snapshot.
    public func tickWithUnifiedRefresh() async {
        unified = await SubstrateHealthUnifiedClient.snapshotAsync()
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
    /// SS-SH: subscribe this row to the panel's single shared health clock. Runs
    /// `action` once on appear and again on every shared tick — replacing the
    /// row's own per-row `Task.sleep` timer. When no clock is in the environment
    /// (standalone/preview) it simply refreshes once and does not poll.
    func substrateHealthPoll(_ action: @escaping () -> Void) -> some View {
        modifier(SubstrateHealthPollModifier(action: action))
    }
}
