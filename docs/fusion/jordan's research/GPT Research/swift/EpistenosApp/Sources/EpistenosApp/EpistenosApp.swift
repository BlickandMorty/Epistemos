import SwiftUI
import SwiftData

@main
struct EpistenosApp: App {
    var body: some Scene {
        WindowGroup {
            VaultManagerView()
        }
        .modelContainer(for: [Vault.self, VaultFile.self, AgentLog.self])
    }
}
