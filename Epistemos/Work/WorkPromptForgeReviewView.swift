import SwiftUI

enum WorkPromptForgeDelivery: Equatable {
    case send
    case queue
}

struct WorkPromptForgeReview: Identifiable, Equatable {
    let id: UUID
    var result: PromptForgeResult
    var delivery: WorkPromptForgeDelivery
    var model: String?
    var agent: String?
    var retryCount: Int

    init(
        result: PromptForgeResult,
        delivery: WorkPromptForgeDelivery,
        model: String?,
        agent: String?,
        retryCount: Int = 0
    ) {
        self.id = UUID()
        self.result = result
        self.delivery = delivery
        self.model = model
        self.agent = agent
        self.retryCount = retryCount
    }
}

struct WorkPromptForgeReviewView: View {
    let review: WorkPromptForgeReview
    var theme: EpistemosTheme = .nativeDefault
    var onAccept: () -> Void = {}
    var onEdit: () -> Void = {}
    var onRetry: () -> Void = {}
    var onRevert: () -> Void = {}
    var onCancel: () -> Void = {}

    private var accent: Color { theme.resolved.accent.color }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
                Text("Prompt Forge")
                    .font(WorkPixelFont.body(11, weight: .semibold))
                    .foregroundStyle(theme.resolved.foreground.color)
                Text(review.delivery == .queue ? "queue review" : "send review")
                    .font(WorkPixelFont.body(10))
                    .foregroundStyle(theme.textTertiary)
                Spacer(minLength: 0)
                iconButton("checkmark", help: "Accept upgraded prompt", action: onAccept)
                iconButton("pencil", help: "Edit upgraded prompt", action: onEdit)
                iconButton("arrow.clockwise", help: "Retry upgrade", action: onRetry)
                iconButton("arrow.uturn.left", help: "Revert to original", action: onRevert)
                iconButton("xmark", help: "Cancel review", action: onCancel)
            }

            HStack(alignment: .top, spacing: 8) {
                promptBlock(title: "original", text: review.result.originalPrompt)
                promptBlock(title: "upgraded", text: review.result.upgradedPrompt)
            }

            if !review.result.changes.isEmpty {
                Text(review.result.changes.map { "\($0.label): \($0.detail)" }.joined(separator: "  "))
                    .font(WorkPixelFont.body(10))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(2)
            }

            if !review.result.clarifyingQuestions.isEmpty {
                Text("questions: \(review.result.clarifyingQuestions.joined(separator: " / "))")
                    .font(WorkPixelFont.body(10))
                    .foregroundStyle(theme.mutedForeground)
                    .lineLimit(2)
            }

            Text(review.result.groundingStatus)
                .font(WorkPixelFont.body(10))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
        }
        .padding(8)
        .background(WorkSurfaceStyle.background(for: theme, role: .toolCard))
        .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(theme.border, lineWidth: 0.8))
    }

    private func promptBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(WorkPixelFont.body(9, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
            ScrollView {
                Text(text)
                    .font(WorkPixelFont.body(10))
                    .foregroundStyle(theme.resolved.foreground.color)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 96)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(theme.border.opacity(0.55), lineWidth: 0.6))
    }

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName).font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(systemName == "xmark" ? theme.mutedForeground : accent)
        .frame(width: 18, height: 18)
        .help(help)
    }
}
