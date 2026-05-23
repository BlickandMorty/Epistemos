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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.18), value: modeStore.currentMode)
        }
        // Per user direction 2026-05-15: the entire sidebar shell (all
        // three modes — myVault, modelVaults, system) shares the same
        // `.thinMaterial` blur. Previously only NotesSidebar got the
        // macOS sidebar visual effect via SwiftData/NavigationSplitView
        // inheritance; the modelVaults + system modes (plain VStacks)
        // appeared transparent against the desktop. Applying the
        // material at the shell level guarantees ALL modes inherit it
        // uniformly, regardless of what each mode view does internally.
        // The fixedHeader still has its own `.thinMaterial` so the
        // header's slight contrast against the body stays intact.
        .background(.thinMaterial)
    }

    private var fixedHeader: some View {
        // 2026-05-19: removed PinnedStripView (pin + disabled plus button)
        // per user direction — never wired to real SDSidebarPin storage and
        // the plus button was permanently `.disabled(true)`.
        VStack(spacing: 6) {
            ModeSwitcherControl(modeStore: modeStore)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.thinMaterial)
    }
}
