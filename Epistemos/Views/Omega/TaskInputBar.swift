import SwiftUI

// MARK: - Task Input Bar

/// Retired compatibility view. Task entry now lives in main chat.
struct TaskInputBar: View {
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        EmptyView()
    }
}
