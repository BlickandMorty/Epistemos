import Foundation

enum SystemAppearanceState {
    nonisolated static func isDark(
        globalDomain: [String: Any]? = FoundationSafety.runtimeUserDefaults.persistentDomain(
            forName: UserDefaults.globalDomain
        )
    ) -> Bool {
        (globalDomain?["AppleInterfaceStyle"] as? String) == "Dark"
    }
}
