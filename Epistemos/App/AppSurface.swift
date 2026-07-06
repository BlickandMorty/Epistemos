import Foundation

#if EPISTEMOS_APP_STORE && EPISTEMOS_EXPERIMENTAL
#error("""
KEELSTONE: EPISTEMOS_APP_STORE and EPISTEMOS_EXPERIMENTAL are both defined in this target. \
Exactly one surface macro may be active. Check target-scoped SWIFT_ACTIVE_COMPILATION_CONDITIONS \
in project.yml; a surface macro has leaked into shared settings.
""")
#endif

#if !EPISTEMOS_APP_STORE && !EPISTEMOS_EXPERIMENTAL
#error("""
KEELSTONE: neither EPISTEMOS_APP_STORE nor EPISTEMOS_EXPERIMENTAL is defined. There is no \
flag-less base surface. Every shipping app target must define exactly one surface macro.
""")
#endif

enum AppSurface: String, Sendable {
    case appStore
    case experimental

    static let current: AppSurface = {
        #if EPISTEMOS_APP_STORE
        return .appStore
        #elseif EPISTEMOS_EXPERIMENTAL
        return .experimental
        #endif
    }()

    var isSandboxed: Bool { self == .appStore }
    var allowsSubprocessCapabilities: Bool { self == .experimental }
    var rendersCompanionPresence: Bool { self == .experimental }
}
