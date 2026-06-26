import SwiftUI

// Native QueueList (clone-map #5 UI) — a flat, compact, OpenCode-minimal list of pending prompts bound to
// WorkPromptQueue. Mirrors OpenGUI QueueList ops (send-now, reorder top/bottom, remove) + the mode badge
// (interrupt / steer). NO donor chrome. Embeds above the input in WorkEngineSurfaceView (wired in the integration
// pass). The host supplies `onSendNow` (it pulls the prompt out of the queue + sends immediately).
struct WorkQueueListView: View {
    let queue: WorkPromptQueue
    var theme: EpistemosTheme = .nativeDefault
    /// Called with a prompt the user chose to send immediately (already removed from the queue by this view).
    var onSendNow: (WorkQueuedPrompt) -> Void = { _ in }
    /// Called when the user chooses "Interrupt" — the host aborts the running turn so this prompt sends ASAP.
    var onInterrupt: (WorkQueuedPrompt) -> Void = { _ in }
    /// Called when the user chooses after-part steering — the host waits for a live part boundary, then aborts + drains.
    var onAfterPart: (WorkQueuedPrompt) -> Void = { _ in }

    @State private var editingPromptID: String?
    @State private var editingText: String = ""

    private var accent: Color { theme.resolved.accent.color }

    var body: some View {
        if !queue.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("queued · \(queue.count)")
                        .font(WorkPixelFont.body(10, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                    Spacer(minLength: 0)
                    Button { queue.clear() } label: {
                        Image(systemName: "trash").font(.system(size: 11))
                    }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.mutedForeground)
                        .frame(width: 18, height: 18)
                        .help("Clear queue")
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 1)
                ForEach(queue.pending) { prompt in row(prompt) }
            }
            .padding(8)
        }
    }

    private func row(_ prompt: WorkQueuedPrompt) -> some View {
        HStack(spacing: 6) {
            let isEditing = editingPromptID == prompt.id
            if !isEditing, let label = modeBadgeLabel(prompt.mode) {
                Text(label)
                    .font(WorkPixelFont.body(9, weight: .semibold))
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .foregroundStyle(accent)
                    .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(accent.opacity(0.5), lineWidth: 0.6))
            }
            if isEditing {
                TextField("queued prompt", text: $editingText)
                    .textFieldStyle(.plain)
                    .font(WorkPixelFont.body(12))
                    .foregroundStyle(theme.resolved.foreground.color)
                    .onSubmit { commitEdit(id: prompt.id) }
                Button { commitEdit(id: prompt.id) } label: {
                    Image(systemName: "checkmark").font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(accent)
                .frame(width: 18, height: 18)
                .help("Save edit")
                Button { cancelEdit() } label: {
                    Image(systemName: "xmark").font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.mutedForeground)
                .frame(width: 18, height: 18)
                .help("Cancel edit")
            } else {
                Text(prompt.text)
                    .font(WorkPixelFont.body(12))
                    .lineLimit(1)
                    .foregroundStyle(theme.mutedForeground)
                Spacer(minLength: 0)
                Button { if let taken = queue.takeNow(id: prompt.id) { onSendNow(taken) } } label: {
                    Image(systemName: "arrow.up.circle").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(accent)
                .frame(width: 18, height: 18)
                .help("Send now")
                Menu {
                    Button("Edit") { beginEdit(prompt) }
                    Button("Move to top") { queue.moveToTop(id: prompt.id) }
                    Button("Move to bottom") { queue.moveToBottom(id: prompt.id) }
                    if prompt.mode == .interrupt {
                        Button("Queue (cancel interrupt)") { queue.setMode(id: prompt.id, .queue) }
                    } else {
                        Button("Interrupt (abort + send next)") { onInterrupt(prompt) }
                    }
                    if prompt.mode == .afterPart {
                        Button("Queue (cancel steer)") { queue.setMode(id: prompt.id, .queue) }
                    } else {
                        Button("Steer after current part") { onAfterPart(prompt) }
                    }
                    Button("Remove", role: .destructive) { queue.remove(id: prompt.id) }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 11))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .foregroundStyle(theme.mutedForeground)
                .frame(width: 18, height: 18)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(theme.border.opacity(0.5), lineWidth: 0.6))
        .contentShape(Rectangle())
    }

    private func beginEdit(_ prompt: WorkQueuedPrompt) {
        editingPromptID = prompt.id
        editingText = prompt.text
    }

    private func commitEdit(id: String) {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            queue.edit(id: id, text: trimmed)
        }
        cancelEdit()
    }

    private func cancelEdit() {
        editingPromptID = nil
        editingText = ""
    }

    private func modeBadgeLabel(_ mode: WorkQueueMode) -> String? {
        switch mode {
        case .queue: return nil
        case .interrupt: return "interrupt"
        case .afterPart: return "steer"
        }
    }
}

#Preview {
    let q = WorkPromptQueue()
    q.enqueue("refactor the parser")
    q.enqueue("add tests", mode: .interrupt)
    return WorkQueueListView(queue: q).frame(width: 320, height: 160)
}
