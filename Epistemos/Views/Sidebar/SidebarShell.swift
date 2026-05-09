import SwiftData
import SwiftUI

struct SidebarShell: View {
    let allPages: [SDPage]
    let allFolders: [SDFolder]

    @State private var modeStore = SidebarModeStore()

    var body: some View {
        VStack(spacing: 0) {
            fixedHeader

            Group {
                switch modeStore.currentMode {
                case .myVault:
                    NotesSidebar(
                        allPages: allPages,
                        allFolders: allFolders,
                        showsModelVaultsSection: false
                    )
                case .modelVaults:
                    ModelVaultsModeView()
                case .system:
                    SystemModeView()
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.18), value: modeStore.currentMode)
        }
    }

    private var fixedHeader: some View {
        VStack(spacing: 6) {
            ModeSwitcherControl(modeStore: modeStore)
            PinnedStripView()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.thinMaterial)
    }
}
