import SwiftUI
import SwiftData
import AppKit

struct VaultManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var vaults: [Vault]
    @State private var selection: Vault?
    @State private var showCompanions = true

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(vaults) { vault in
                    Label(vault.name, systemImage: vault.locked ? "lock.fill" : "lock.open.fill")
                        .tag(vault as Vault?)
                }
            }
            .toolbar {
                Button("Add Vault", systemImage: "folder.badge.plus") { addVault() }
                Button("Companions", systemImage: "person.3.sequence") { showCompanions.toggle() }
            }
        } detail: {
            if let selection {
                VaultDetailView(vault: selection)
            } else {
                SimulationLandingFarmView()
            }
        }
        .sheet(isPresented: $showCompanions) {
            CompanionManagerView()
        }
    }

    private func addVault() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                do {
                    let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    modelContext.insert(Vault(name: url.lastPathComponent, bookmarkData: bookmark))
                } catch {
                    NSLog("Failed to create security-scoped bookmark: \(error.localizedDescription)")
                }
            }
        }
    }
}
