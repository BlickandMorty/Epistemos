import Foundation

enum SystemAppearanceState {
    nonisolated static func isDark(
        globalDomain: [String: Any]? = UserDefaults.standard.persistentDomain(
            forName: UserDefaults.globalDomain
        )
    ) -> Bool {
        (globalDomain?["AppleInterfaceStyle"] as? String) == "Dark"
    }
}
