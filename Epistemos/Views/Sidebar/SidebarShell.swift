import SwiftData
import SwiftUI

struct SidebarShell: View {
    let allPages: [SDPage]
    let allFolders: [SDFolder]

    var body: some View {
        NotesSidebar(
            allPages: allPages,
            allFolders: allFolders
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial)
    }
}
