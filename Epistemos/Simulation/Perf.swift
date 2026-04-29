//
//  Perf.swift
//  Simulation Mode signpost helpers (S0)
//
//  Wraps `OSLog` + `os_signpost` for the simulation subsystem
//  (`com.epistemos.simulation`) so the Swift side of the renderer,
//  view-models, and FFI bridge can emit Instruments-readable timing
//  events. Categories follow `epistemos.simulation.<slice>.<operation>`
//  per IMPLEMENTATION.md §7 cross-slice invariant 10.
//
//  This file is the S0 deliverable; subsequent slices add measurements
//  via the helpers below without modifying this surface.
//

import OSLog

// MARK: - Subsystem and category definitions

/// Canonical signpost categories for the simulation subsystem.
/// Each row corresponds to a slice's required instrumentation in
/// IMPLEMENTATION.md §5. A slice that needs an additional category
/// adds it here and updates §5 in the same commit.
enum SimSignpost {
    static let subsystem = "com.epistemos.simulation"

    static let theater    = OSLog(subsystem: subsystem, category: "theater")
    static let companions = OSLog(subsystem: subsystem, category: "companions")
    static let events     = OSLog(subsystem: subsystem, category: "events")
    static let audit      = OSLog(subsystem: subsystem, category: "audit")
    static let ffi        = OSLog(subsystem: subsystem, category: "ffi")
    static let hermes     = OSLog(subsystem: subsystem, category: "hermes")
    static let landing    = OSLog(subsystem: subsystem, category: "landing")
}

// MARK: - Interval helpers

/// Wraps `body` in a paired `os_signpost(.begin)` / `os_signpost(.end)`
/// for the given log + name. Returns whatever the body returns and
/// rethrows any error. The end signpost fires even on a thrown error
/// thanks to `defer`, so intervals never leak across an early return.
@inline(__always)
func signpostInterval<T>(
    _ log: OSLog,
    _ name: StaticString,
    _ body: () throws -> T
) rethrows -> T {
    let id = OSSignpostID(log: log)
    os_signpost(.begin, log: log, name: name, signpostID: id)
    defer { os_signpost(.end, log: log, name: name, signpostID: id) }
    return try body()
}

/// Async variant of `signpostInterval`. Same begin/end pairing, with
/// `defer` ensuring the end fires when the awaited body returns or
/// throws.
@inline(__always)
func signpostInterval<T>(
    _ log: OSLog,
    _ name: StaticString,
    _ body: () async throws -> T
) async rethrows -> T {
    let id = OSSignpostID(log: log)
    os_signpost(.begin, log: log, name: name, signpostID: id)
    defer { os_signpost(.end, log: log, name: name, signpostID: id) }
    return try await body()
}

/// Emits an instantaneous signpost event. Use for points-in-time
/// (delta drained, frame presented, hysteresis transition) where there
/// is no paired begin / end semantic.
@inline(__always)
func signpostEvent(_ log: OSLog, _ name: StaticString) {
    os_signpost(.event, log: log, name: name)
}
