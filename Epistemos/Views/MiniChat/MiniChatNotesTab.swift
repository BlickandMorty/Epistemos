import SwiftUI
import SwiftData

// MARK: - MiniChat Notes Tab
// AI writing assistance: Quick actions (Continue, Summarize, Expand, Rewrite) + freeform input.

struct MiniChatNotesTab: View {
    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(TriageService.self) private var triage
    @Environment(LLMService.self) private var llm
    @Environment(\.modelContext) private var modelContext

    @State private var inputText = ""
    @State private var responseText = ""
    @State private var isGenerating = false
    @State private var generationTask: Task<Void, Never>?

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: 0) {
            contextBar
            if notesUI.activePageId == nil {
                emptyState
            } else {
                askModeView
            }
        }
    }

    // MARK: - Active Page Lookup

    private func activePage() -> SDPage? {
        guard let pageId = notesUI.activePageId else { return nil }
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Context Bar

    private var contextBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "note.text")
                .font(.system(size: 10))
                .foregroundStyle(theme.accent)

            if let page = activePage() {
                Text(page.title.isEmpty ? "Untitled" : page.title)
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            } else {
                Text("No page selected")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(theme.mutedForeground.opacity(0.4))
            Text("Open a note page to use AI writing assistance.")
                .font(.system(size: 12))
                .foregroundStyle(theme.mutedForeground.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Ask Mode

    private var askModeView: some View {
        VStack(spacing: 0) {
            quickActionsBar
            Divider().opacity(0.3)

            // Content area
            ZStack {
                if !responseText.isEmpty || isGenerating {
                    VStack(spacing: 0) {
                        responseArea
                        Spacer(minLength: 0)
                    }
                } else {
                    Text("Ask anything about your notes, or use a quick action above.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.3)
            askInputBar
        }
    }

    private var quickActionsBar: some View {
        let actions: [(id: String, label: String, icon: String, prompt: String)] = [
            ("continue", "Continue", "pencil.line", "Continue writing from where this note left off. Match the tone and style."),
            ("summarize", "Summarize", "doc.text", "Summarize the key points of this note page concisely."),
            ("expand", "Expand", "arrow.up.left.and.arrow.down.right", "Expand on this content with more detail and supporting points."),
            ("rewrite", "Rewrite", "arrow.triangle.2.circlepath", "Rewrite this content to be clearer and more concise."),
        ]

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(actions, id: \.id) { action in
                    Button {
                        runQuickAction(action.prompt, actionId: action.id)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: action.icon)
                                .font(.system(size: 10))
                            Text(action.label)
                                .font(.system(size: 10.5, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.foreground.opacity(0.05), in: Capsule())
                        .overlay(Capsule().stroke(theme.foreground.opacity(0.08), lineWidth: 0.5))
                        .foregroundStyle(isGenerating ? theme.mutedForeground.opacity(0.35) : theme.foreground)
                    }
                    .buttonStyle(.plain)
                    .disabled(isGenerating)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    private var responseArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView {
                Text(responseText + (isGenerating ? " |" : ""))
                    .font(.system(size: 12))
                    .foregroundStyle(theme.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 120)
            .padding(.horizontal, 8)
            .padding(.top, 6)

            if !isGenerating && !responseText.isEmpty {
                HStack(spacing: 4) {
                    // Triage indicator
                    if let decision = triage.lastDecision {
                        HStack(spacing: 3) {
                            Image(systemName: decision.icon)
                                .font(.system(size: 8))
                            Text(decision.label)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(decision.isOnDevice ? Color.green.opacity(0.7) : Color.blue.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                    }

                    Spacer()

                    // Insert into note
                    Button {
                        insertResponse()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.turn.down.left")
                                .font(.system(size: 9))
                            Text("Insert")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.foreground.opacity(0.05), in: Capsule())
                        .overlay(Capsule().stroke(theme.foreground.opacity(0.08), lineWidth: 0.5))
                        .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)

                    // Copy
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(responseText, forType: .string)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                            Text("Copy")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.foreground.opacity(0.05), in: Capsule())
                        .overlay(Capsule().stroke(theme.foreground.opacity(0.08), lineWidth: 0.5))
                        .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
        }
    }

    private var askInputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about your notes...", text: $inputText, axis: .vertical)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .foregroundStyle(theme.foreground)
                .onSubmit { sendAskQuery() }

            if isGenerating {
                Button {
                    cancelGeneration()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            } else {
                let canSend = !inputText.trimmingCharacters(in: .whitespaces).isEmpty
                Button(action: sendAskQuery) {
                    Text("Ask")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(canSend ? .white : theme.textTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            canSend
                                ? AnyShapeStyle(theme.accent)
                                : AnyShapeStyle(.thinMaterial),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func sendAskQuery() {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let page = activePage() else { return }
        inputText = ""
        responseText = ""
        isGenerating = true

        generationTask = Task {
            defer { isGenerating = false }
            do {
                for try await chunk in triage.stream(
                    prompt: "Based on this note:\n\n\(page.body)\n\nUser request: \(query)",
                    systemPrompt: "You are a helpful AI writing assistant. Respond concisely and directly.",
                    operation: .ask(query: query),
                    contentLength: page.body.count,
                    query: query
                ) {
                    responseText += chunk
                }
            } catch {
                if !Task.isCancelled {
                    responseText = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    private func operationForActionId(_ id: String) -> NotesOperation {
        switch id {
        case "continue":  return .continueWriting
        case "summarize": return .summarize
        case "expand":    return .expand
        case "rewrite":   return .rewrite
        default:          return .ask(query: id)
        }
    }

    private func runQuickAction(_ prompt: String, actionId: String = "") {
        guard let page = activePage() else { return }
        responseText = ""
        isGenerating = true

        let operation = operationForActionId(actionId)

        generationTask = Task {
            defer { isGenerating = false }
            do {
                for try await chunk in triage.stream(
                    prompt: "Content:\n\n\(page.body)\n\nTask: \(prompt)",
                    systemPrompt: "You are a helpful AI writing assistant. Respond with the requested content only.",
                    operation: operation,
                    contentLength: page.body.count
                ) {
                    responseText += chunk
                }
            } catch {
                if !Task.isCancelled {
                    responseText = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    private func insertResponse() {
        guard let page = activePage(), !responseText.isEmpty else { return }
        // Append response to page body with separator
        if page.body.isEmpty {
            page.body = responseText
        } else {
            page.body += "\n\n" + responseText
        }
        responseText = ""
    }

    private func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

}
