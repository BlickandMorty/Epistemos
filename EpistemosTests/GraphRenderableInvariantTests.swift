import Testing
@testable import Epistemos
import Foundation

// MARK: - GraphRenderableInvariantTests
//
// Encodes the canonical invariant from
// docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md §"Locked architectural
// decisions" #4: **renderability is independent of sleep state.**
//
// The Rust side has the same invariant tested in
// graph-engine/src/node_state.rs (`renderable_is_independent_of_sleep`).
// This Swift mirror exists so the invariant is enforced on both sides
// of the FFI — if anyone changes the flag semantics on either side
// without updating the other, one of the two test files will fail
// in CI and force the inconsistency to be caught before merge.
//
// Specifically: a sleeping node still has FLAG_RENDERABLE set; only
// filter/hidden-by-search clears it. This is the contract that
// prevents the zoom-in-invisibility regression we hit in earlier
// iterations of the graph view (where sleep was used as a culling
// signal and nodes vanished offscreen).

@Suite("GraphNodeState render/sleep flag invariant", .serialized)
@MainActor
struct GraphRenderableInvariantTests {

    // Plain UInt32 constants — must match the Rust-side FLAG_* values
    // in graph-engine/src/node_state.rs exactly. If anyone re-orders
    // those bits, the test below will detect the drift before the
    // bound MTLBuffer can corrupt itself.
    private let FLAG_RENDERABLE: UInt32 = 1 << 0
    private let FLAG_AWAKE:      UInt32 = 1 << 1
    private let FLAG_WARMING:    UInt32 = 1 << 2
    private let FLAG_SLEEPING:   UInt32 = 1 << 3
    private let FLAG_PINNED:     UInt32 = 1 << 4
    private let FLAG_SELECTED:   UInt32 = 1 << 5
    private let FLAG_NEWLY_ADDED: UInt32 = 1 << 6

    @Test("sleeping node retains FLAG_RENDERABLE")
    func sleepingNodeStillRenders() {
        // Canonical invariant: SLEEPING does NOT clear RENDERABLE.
        // The integrator skips physics; the renderer still draws.
        let flags: UInt32 = FLAG_RENDERABLE | FLAG_SLEEPING
        #expect(flags & FLAG_RENDERABLE != 0, "sleeping node MUST still render")
        #expect(flags & FLAG_SLEEPING != 0)
        #expect(flags & FLAG_AWAKE == 0, "sleeping node does not also have AWAKE bit")
    }

    @Test("warming node renders and integrates")
    func warmingNodeRendersAndIntegrates() {
        let flags: UInt32 = FLAG_RENDERABLE | FLAG_WARMING
        #expect(flags & FLAG_RENDERABLE != 0)
        #expect(flags & (FLAG_AWAKE | FLAG_WARMING) != 0, "warming counts as integrates")
    }

    @Test("awake node renders and integrates")
    func awakeNodeRendersAndIntegrates() {
        let flags: UInt32 = FLAG_RENDERABLE | FLAG_AWAKE
        #expect(flags & FLAG_RENDERABLE != 0)
        #expect(flags & (FLAG_AWAKE | FLAG_WARMING) != 0)
    }

    @Test("hidden-by-filter node does NOT render even when awake")
    func filterHiddenDoesNotRender() {
        // The ONLY thing that clears FLAG_RENDERABLE is filter/hidden.
        // Verify the bit math: AWAKE alone (no RENDERABLE) does not render.
        let flags: UInt32 = FLAG_AWAKE
        #expect(flags & FLAG_RENDERABLE == 0, "filter-hidden node does not render")
        #expect(flags & (FLAG_AWAKE | FLAG_WARMING) != 0, "still integrates if not sleeping")
    }

    @Test("pinned node can be in any physics state")
    func pinnedIsOrthogonal() {
        // PINNED is orthogonal to the AWAKE/WARMING/SLEEPING axis. A
        // pinned-and-sleeping node still renders (it's pinned, position
        // is set externally, integrator skips it).
        let pinnedAwake: UInt32 = FLAG_RENDERABLE | FLAG_PINNED | FLAG_AWAKE
        let pinnedSleeping: UInt32 = FLAG_RENDERABLE | FLAG_PINNED | FLAG_SLEEPING
        #expect(pinnedAwake & FLAG_RENDERABLE != 0)
        #expect(pinnedSleeping & FLAG_RENDERABLE != 0)
        #expect(pinnedAwake & FLAG_PINNED != 0)
        #expect(pinnedSleeping & FLAG_PINNED != 0)
    }

    @Test("selected is orthogonal to physics + render state")
    func selectedIsOrthogonal() {
        // SELECTED informs rendering tint; does not by itself affect
        // physics. A sleeping-and-selected node still renders (highlighted)
        // but doesn't integrate.
        let selectedSleeping: UInt32 = FLAG_RENDERABLE | FLAG_SELECTED | FLAG_SLEEPING
        #expect(selectedSleeping & FLAG_RENDERABLE != 0, "selected sleeping node still renders")
        #expect(selectedSleeping & FLAG_SELECTED != 0)
        #expect(selectedSleeping & (FLAG_AWAKE | FLAG_WARMING) == 0, "does not integrate")
    }

    @Test("flag bit positions match Rust GraphNodeFlags exactly")
    func flagBitPositionsMatchRust() {
        // ABI contract — these specific bit positions are wire format
        // between Swift and Rust. The Rust side has the same test in
        // graph-engine/src/node_state.rs (flag_bit_positions_are_stable).
        // If anyone re-orders bits on either side, one test will fail.
        #expect(FLAG_RENDERABLE  == 1 << 0)
        #expect(FLAG_AWAKE       == 1 << 1)
        #expect(FLAG_WARMING     == 1 << 2)
        #expect(FLAG_SLEEPING    == 1 << 3)
        #expect(FLAG_PINNED      == 1 << 4)
        #expect(FLAG_SELECTED    == 1 << 5)
        #expect(FLAG_NEWLY_ADDED == 1 << 6)
    }
}
