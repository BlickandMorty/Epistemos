import SwiftUI

struct PinnedStripView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Image(systemName: "pin")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)

                Button {
                    // SDSidebarPin storage lands in the next sidebar slice.
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Pin Current")
                .disabled(true)
            }
            .frame(height: 28)
            .padding(.horizontal, 2)
        }
        .accessibilityLabel("Pinned sidebar items")
    }
}
