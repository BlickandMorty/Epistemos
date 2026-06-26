import SwiftUI

// Native QUESTION card (the agent asks the user) — sibling of WorkPermissionCardView, for a WorkQuestionRequest.
// Flat/compact OpenCode-TUI minimal: boxy, theme tokens, monospace, no donor chrome. Renders each prompt's header +
// question + options (single-select per `!multiple`, multi per `multiple`) + an optional free-text field per `custom`.
// Collects selections internally; "Submit" emits one answer ([String]) per prompt (ordered by prompt.id) →
// WorkOpenGUISupervisor.respondQuestion; "Skip" → rejectQuestion.
struct WorkQuestionCardView: View {
    let request: WorkQuestionRequest
    var theme: EpistemosTheme = .nativeDefault
    var onAnswer: ([[String]]) -> Void = { _ in }
    var onReject: () -> Void = {}

    @State private var selections: [Int: Set<String>] = [:]   // prompt.id → chosen option labels
    @State private var customText: [Int: String] = [:]        // prompt.id → free-text custom answer

    private var accent: Color { theme.resolved.accent.color }
    private var cardBackground: Color { WorkSurfaceStyle.background(for: theme, role: .toolCard) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.bubble")
                    .font(.system(size: 11))
                    .foregroundStyle(accent)
                    .frame(width: 14, height: 14)
                Text("question").font(WorkPixelFont.body(11, weight: .semibold)).foregroundStyle(.primary)
                Spacer(minLength: 0)
                Button { onReject() } label: {
                    Image(systemName: "xmark").font(.system(size: 11))
                }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.mutedForeground)
                    .frame(width: 18, height: 18)
                    .help("Skip question")
            }
            ForEach(request.prompts) { prompt in promptView(prompt) }
            HStack {
                Spacer(minLength: 0)
                Button { onAnswer(assembledAnswers()) } label: {
                    Text("Submit")
                        .font(WorkPixelFont.body(11, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .foregroundStyle(theme.isDark ? Color.black : Color.white)
                        .background(accent)
                        .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(accent.opacity(0.6), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(accent.opacity(0.6), lineWidth: 0.9))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func promptView(_ prompt: WorkQuestionPrompt) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !prompt.header.isEmpty {
                Text(prompt.header).font(WorkPixelFont.body(9, weight: .semibold)).foregroundStyle(theme.textTertiary)
            }
            Text(prompt.question).font(WorkPixelFont.body(12)).foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(prompt.options) { option in optionRow(prompt, option) }
            if prompt.custom {
                TextField("custom answer", text: customBinding(prompt.id))
                    .textFieldStyle(.plain)
                    .font(WorkPixelFont.body(12))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(theme.border, lineWidth: 0.6))
            }
        }
    }

    private func optionRow(_ prompt: WorkQuestionPrompt, _ option: WorkQuestionOption) -> some View {
        let selected = selections[prompt.id]?.contains(option.label) ?? false
        return Button { toggle(prompt, option.label) } label: {
            HStack(spacing: 6) {
                Image(systemName: indicatorSymbol(multiple: prompt.multiple, selected: selected))
                    .font(.system(size: 11))
                    .foregroundStyle(selected ? accent : theme.mutedForeground)
                    .frame(width: 14, height: 14)
                Text(option.label)
                    .font(WorkPixelFont.body(12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let description = option.description, !description.isEmpty {
                    Text(description)
                        .font(WorkPixelFont.body(10))
                        .foregroundStyle(theme.mutedForeground)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func indicatorSymbol(multiple: Bool, selected: Bool) -> String {
        if multiple { return selected ? "checkmark.square.fill" : "square" }
        return selected ? "largecircle.fill.circle" : "circle"
    }

    // MARK: selection

    private func toggle(_ prompt: WorkQuestionPrompt, _ label: String) {
        var set = selections[prompt.id] ?? []
        if prompt.multiple {
            if set.contains(label) { set.remove(label) } else { set.insert(label) }
        } else {
            set = set.contains(label) ? [] : [label]   // single-select: replace
        }
        selections[prompt.id] = set
    }

    private func customBinding(_ id: Int) -> Binding<String> {
        Binding(get: { customText[id] ?? "" }, set: { customText[id] = $0 })
    }

    /// One answer ([String]) per prompt, ordered by prompt.id: chosen labels + a non-empty custom string if provided.
    private func assembledAnswers() -> [[String]] {
        request.prompts.sorted { $0.id < $1.id }.map { prompt in
            let selected = selections[prompt.id] ?? []
            var answer = prompt.options.map(\.label).filter { selected.contains($0) }
            let custom = (customText[prompt.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !custom.isEmpty { answer.append(custom) }
            return answer
        }
    }
}

#Preview {
    WorkQuestionCardView(request: WorkQuestionRequest(
        id: "q1", harnessID: nil, sessionID: "s",
        prompts: [WorkQuestionPrompt(
            id: 0, question: "Which framework?", header: "Framework",
            options: [WorkQuestionOption(label: "SwiftUI", description: "native"),
                      WorkQuestionOption(label: "AppKit", description: nil)],
            multiple: false, custom: true)],
        toolCallID: nil))
        .frame(width: 360).padding()
}
