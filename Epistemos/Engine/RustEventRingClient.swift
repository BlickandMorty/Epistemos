import Foundation

// MARK: - RustEventRingClient
//
// Wave 5 follow-up of the Extended Program Plan
// (cross-ref dpp §5.3 — Swift module map + EventDrain actor).
//
// Real `EventRingClient` implementation that calls into the
// substrate-rt FFI via `@_silgen_name`. Gated behind the compile flag
// `EPISTEMOS_LINK_SUBSTRATE_RT` so this file compiles cleanly even
// when the project hasn't yet wired the substrate-rt cdylib into the
// app target's Other Linker Flags.
//
// To activate:
//   - Add `-lsubstrate_rt` to the app target's OTHER_LDFLAGS
//   - Add the substrate-rt build output dir to LIBRARY_SEARCH_PATHS
//   - Add `EPISTEMOS_LINK_SUBSTRATE_RT` to SWIFT_ACTIVE_COMPILATION_CONDITIONS
//
// The above is a project.yml edit — out of scope for this commit
// because the policy is "edit xcodegen, not the .xcodeproj directly"
// and project.yml mutations regenerate the entire pbxproj. The
// W5 follow-up at the project.yml layer is now a single config edit.

#if EPISTEMOS_LINK_SUBSTRATE_RT

@_silgen_name("ering_new")
nonisolated func ering_new(_ capacity: Int) -> UnsafeMutableRawPointer?

@_silgen_name("ering_try_push")
nonisolated func ering_try_push(_ ring: UnsafeMutableRawPointer, _ event: UnsafePointer<GraphEvent>) -> Bool

@_silgen_name("ering_drain")
nonisolated func ering_drain(_ ring: UnsafeMutableRawPointer, _ out: UnsafeMutablePointer<GraphEvent>, _ max: Int) -> Int

@_silgen_name("ering_pending")
nonisolated func ering_pending(_ ring: UnsafeMutableRawPointer) -> Int

@_silgen_name("ering_destroy")
nonisolated func ering_destroy(_ ring: UnsafeMutableRawPointer)

/// Real implementation that calls into substrate-rt's C ABI. The
/// W5 follow-up adds the per-CADisplayLink-tick frame loop that
/// drives `EventDrain.tick(handler:)` once per frame.
nonisolated public final class RustEventRingClient: EventRingClient, @unchecked Sendable {
    private let ringHandle: OpaquePointer

    public init?(capacity: Int) {
        guard capacity > 0 else { return nil }
        guard let raw = ering_new(capacity) else { return nil }
        self.ringHandle = OpaquePointer(raw)
    }

    deinit {
        ering_destroy(UnsafeMutableRawPointer(ringHandle))
    }

    public func tryPush(_ event: GraphEvent) -> Bool {
        var copy = event
        return withUnsafePointer(to: &copy) { ptr in
            ering_try_push(UnsafeMutableRawPointer(ringHandle), ptr)
        }
    }

    public func drain(into buffer: inout [GraphEvent]) -> Int {
        guard !buffer.isEmpty else { return 0 }
        let drained = buffer.withUnsafeMutableBufferPointer { ptr -> Int in
            guard let base = ptr.baseAddress else { return 0 }
            return ering_drain(UnsafeMutableRawPointer(ringHandle), base, ptr.count)
        }
        return drained
    }

    public func pendingApprox() -> Int {
        ering_pending(UnsafeMutableRawPointer(ringHandle))
    }
}

#endif
