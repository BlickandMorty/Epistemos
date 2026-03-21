import SwiftUI

struct TypewriterHeading: View {
    let text: String
    let role: AppHeadingRole
    let color: Color
    var animateOnAppear: Bool? = nil
    var animationKey: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(UIState.self) private var ui
    @State private var displayText = ""
    @State private var animationRun = 0

    private var taskID: String {
        "\(animationKey ?? text)|\(reduceMotion)|\(animationRun)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            Text(displayText)
                .font(role.font)
                .foregroundStyle(color)
        }
        .onAppear {
            animationRun += 1
        }
        .onChange(of: text) { _, newText in
            guard animationKey != nil else { return }
            displayText = newText
        }
        .task(id: taskID) {
            await animateIfNeeded()
        }
    }

    @MainActor
    private func animateIfNeeded() async {
        let shouldAnimate = animateOnAppear ?? role.animatesOnFirstAppearance
        guard shouldAnimate, !reduceMotion, !ui.displayMode.reducesASCIIAnimations else {
            displayText = text
            return
        }

        displayText = ""
        try? await Task.sleep(for: .milliseconds(50))

        for character in text {
            guard !Task.isCancelled else { return }
            displayText.append(character)
            try? await Task.sleep(for: .milliseconds(25))
        }

        guard !Task.isCancelled else { return }
        try? await Task.sleep(for: .milliseconds(500))
    }
}

// MARK: - Flow Layout
// Reusable flow layout for concept badges and tags.

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .init(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
