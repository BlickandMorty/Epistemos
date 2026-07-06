//
//  AppSurface.swift
//  Epistemos — KEELSTONE spine
//
//  The single source of truth for "which product surface am I."
//  This file is the anti-drift keystone: it makes a flag-less base surface
//  impossible to ship, and it makes the two-surface collapse enforceable at
//  compile time rather than by convention.
//
//  Wiring rule (do NOT violate — this is how the ghost third surface comes back):
//  EPISTEMOS_EXPERIMENTAL and EPISTEMOS_APP_STORE live in each TARGET's
//  SWIFT_ACTIVE_COMPILATION_CONDITIONS in project.yml — never in the shared
//  project `base`/`settings` block. Xcode propagates project-level settings to
//  every target via $(inherited); if the macro lives in base, the App Store
//  target inherits it and you resurrect the exact vestigial path this file
//  exists to kill.
//

import Foundation

// MARK: - Compile-time surface guards

// Guard 1 — the two surfaces are mutually exclusive.
#if EPISTEMOS_APP_STORE && EPISTEMOS_EXPERIMENTAL
#error("""
KEELSTONE: EPISTEMOS_APP_STORE and EPISTEMOS_EXPERIMENTAL are both defined in \
this target. Exactly one surface macro may be active. Check \
SWIFT_ACTIVE_COMPILATION_CONDITIONS for this target in project.yml — a macro \
has leaked into shared/base settings.
""")
#endif

// Guard 2 — there is NO flag-less shipping surface. This is the new one, and
// the reason the OpenChamber `#else` branch can never come back by accident.
#if !EPISTEMOS_APP_STORE && !EPISTEMOS_EXPERIMENTAL
#error("""
KEELSTONE: neither EPISTEMOS_APP_STORE nor EPISTEMOS_EXPERIMENTAL is defined. \
There is no flag-less base surface. Every shipping target must declare exactly \
one surface macro in SWIFT_ACTIVE_COMPILATION_CONDITIONS.
""")
#endif

/// The two — and only two — product surfaces Epistemos ships.
///
/// Everything that used to branch three ways in `LandingView`
/// (`#if APP_STORE / #elseif EXPERIMENTAL / #else OpenChamber`) resolves
/// through this single enum instead. There is no `.base` case, on purpose.
public enum AppSurface: String, Sendable {
    /// Mac App Store — codename "June". Sandboxed, hardened runtime, file
    /// access only through security-scoped bookmarks + NSFileCoordinator.
    case appStore

    /// Developer ID — codename "1Code". Notarized, hardened runtime, embeds
    /// the 1Code companion child process. No App Sandbox.
    case experimental

    /// The active surface for this build, resolved from the compile-time macro.
    /// Because of the guards above, exactly one branch is live in any build.
    public static let current: AppSurface = {
        #if EPISTEMOS_APP_STORE
        return .appStore
        #elseif EPISTEMOS_EXPERIMENTAL
        return .experimental
        #endif
    }()

    /// True when this surface runs inside the App Sandbox. Drives file-access
    /// discipline: sandboxed surfaces MUST coordinate all vault IO and MUST NOT
    /// spawn arbitrary subprocesses.
    public var isSandboxed: Bool { self == .appStore }

    /// True when this surface is allowed to host the 1Code companion child
    /// process and the capabilities that require subprocess execution.
    /// This is the honest gate that F2 (capability registry) reads from.
    public var allowsSubprocessCapabilities: Bool { self == .experimental }

    /// True when the companion presence layer (F3) renders. MAS shows features
    /// without the companion; presence is Experimental-only.
    public var rendersCompanionPresence: Bool { self == .experimental }
}
