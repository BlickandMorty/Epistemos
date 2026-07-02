import Foundation
import SwiftUI

struct HTMLWorkspaceRegenerateSheet: View {
    @Binding var instruction: String
    @Binding var streamedText: String
    @Binding var contextQuery: String
    let workspaceID: String
    let expectedContentHash: String
    let errorText: String?
    let contextStatusText: String?
    let isRegenerating: Bool
    let isRefreshingContext: Bool
    let hasPendingPreview: Bool
    let hasVaultContext: Bool
    let contextItems: [HTMLWorkspaceRegenerateContextItem]
    let canRestorePreviousSurface: Bool
    let restoreSnapshotName: String?
    let onCancel: () -> Void
    let onCopyPrompt: () -> Void
    let onRefreshContext: () -> Void
    let onClearContext: () -> Void
    let onRequestContextShortcut: (HTMLWorkspaceRegenerateContextShortcut) -> Void
    let onFocusContextItem: (HTMLWorkspaceRegenerateContextItem) -> Void
    let onRunPreset: (HTMLWorkspaceRegeneratePreset) -> Void
    let onSubmit: () -> Void
    let onApplyPreview: () -> Void
    let onPreviewStream: () -> Void
    let onApplyStream: () -> Void
    let onRestorePreview: () -> Void
    let onRestorePreviousSurface: () -> Void

    @State private var advancedFallbackVisible = false
    @State private var contextVisible = false

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme {
        ui.theme
    }

    private var sheetBackground: Color {
        MarkdownPreviewSurfaceStyle.flatBackground(for: theme.surfaceVariant(.other))
    }

    private var fieldBackground: Color {
        theme.resolved.card.color.opacity(theme.isDark ? 0.42 : 0.64)
    }

    private var streamBackground: Color {
        theme.resolved.card.color.opacity(theme.isDark ? 0.30 : 0.52)
    }

    private var mutedText: Color {
        theme.resolved.mutedForeground.color
    }

    private var pixelCaptionFont: Font {
        .system(size: 11, weight: .semibold, design: .monospaced)
    }

    private var pixelControlFont: Font {
        .system(size: 11, weight: .medium, design: .monospaced)
    }

    private var pixelMicroFont: Font {
        .system(size: 10, weight: .semibold, design: .monospaced)
    }

    private var instructionIsEmpty: Bool {
        instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    chatPrompt
                    targetStatusRow

                    if contextVisible {
                        contextSection
                    }

                    DisclosureGroup(isExpanded: $advancedFallbackVisible) {
                        advancedFallback
                    } label: {
                        Label("Recovery response fallback", systemImage: "terminal")
                            .font(pixelCaptionFont)
                            .foregroundStyle(mutedText)
                    }

                    if let errorText, !errorText.isEmpty {
                        Text(errorText)
                            .font(.caption)
                            .foregroundStyle(theme.error)
                            .lineLimit(3)
                    }
                }
                .padding(14)
            }

            actionFooter
        }
        .background(sheetBackground)
    }

    private var sheetHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "wand.and.sparkles")
                .foregroundStyle(theme.resolved.accent.color)
            VStack(alignment: .leading, spacing: 2) {
                Text("Regenerate Surface")
                    .font(.headline)
                    .foregroundStyle(theme.resolved.foreground.color)
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(hasPendingPreview ? theme.resolved.accent.color : mutedText)
            }
            Spacer(minLength: 0)
            Button(action: onCancel) {
                Label("Cancel", systemImage: "xmark.circle")
            }
            .keyboardShortcut(.cancelAction)
        }
        .buttonStyle(.plain)
        .padding(14)
    }

    private var chatPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Describe the rebuild", systemImage: "bubble.left.and.text.bubble.right")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                presetMenu
                Button {
                    contextVisible.toggle()
                } label: {
                    Label(contextVisible ? "Hide context" : "Context", systemImage: "tray.full")
                }
                .disabled(isRegenerating || isRefreshingContext)
            }

            TextField("Tell Epistemos what to change, add, simplify, or rebuild.", text: $instruction, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(theme.resolved.foreground.color)
                .lineLimit(4...8)
                .disabled(isRegenerating)

            HStack(spacing: 8) {
                Button(action: onSubmit) {
                    Label(isRegenerating ? "Generating" : "Generate preview", systemImage: "wand.and.sparkles")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isRegenerating || isRefreshingContext || instructionIsEmpty)
                if isRefreshingContext {
                    Label("Adding context", systemImage: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(mutedText)
                }
                Spacer(minLength: 0)
                if hasPendingPreview {
                    Label("Preview ready", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.resolved.accent.color)
                }
            }
        }
        .foregroundStyle(theme.resolved.foreground.color)
        .buttonStyle(.plain)
        .padding(14)
        .background(fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.12), lineWidth: 0.75)
        }
    }

    private var presetMenu: some View {
        Menu {
            ForEach(HTMLWorkspaceRegeneratePreset.Family.allCases, id: \.self) { family in
                Section(family.rawValue) {
                    ForEach(HTMLWorkspaceRegeneratePreset.presets(in: family)) { preset in
                        Button(preset.title, systemImage: preset.systemImage) {
                            onRunPreset(preset)
                        }
                        .disabled(isRegenerating || isRefreshingContext)
                        .help(preset.helpText)
                    }
                }
            }
        } label: {
            Label("Presets", systemImage: "square.grid.2x2")
        }
    }

    private var targetStatusRow: some View {
        HStack(spacing: 10) {
            Label("Target", systemImage: "scope")
            Text("\(workspaceID.prefix(10)) / \(expectedContentHash.prefix(10))")
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Label(statusLabel, systemImage: statusSymbol)
                .foregroundStyle(hasPendingPreview ? theme.resolved.accent.color : mutedText)
        }
        .font(pixelControlFont)
        .foregroundStyle(mutedText)
    }

    private var actionFooter: some View {
        HStack(spacing: 8) {
            Button(action: onRestorePreview) {
                Label("Current", systemImage: "eye")
            }
            .disabled(isRegenerating)
            Button(action: onRestorePreviousSurface) {
                Label("Revert", systemImage: "clock.arrow.circlepath")
            }
            .disabled(isRegenerating || !canRestorePreviousSurface)
            .help(restoreSnapshotHelpText)
            Spacer(minLength: 0)
            Button(action: onApplyPreview) {
                Label("Apply Preview", systemImage: "checkmark.circle")
            }
            .disabled(isRegenerating || !hasPendingPreview)
        }
        .font(pixelControlFont)
        .buttonStyle(.plain)
        .foregroundStyle(theme.resolved.foreground.color)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(fieldBackground.opacity(0.68))
    }

    private var statusLabel: String {
        if hasPendingPreview {
            return "Preview ready"
        }
        if isRegenerating {
            return "Streaming into preview"
        }
        return "Preview first, then apply"
    }

    private var statusSymbol: String {
        if hasPendingPreview {
            return "checkmark.circle.fill"
        }
        if isRegenerating {
            return "dot.radiowaves.left.and.right"
        }
        return "eye"
    }

    private var restoreSnapshotHelpText: String {
        guard let restoreSnapshotName, !restoreSnapshotName.isEmpty else {
            return "No named restore snapshot available"
        }
        return "Revert to snapshot \(restoreSnapshotName)"
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Workspace Context", systemImage: "tray.full")
                    .font(pixelCaptionFont)
                    .foregroundStyle(mutedText)
                Spacer(minLength: 0)
                if hasVaultContext {
                    Label("Attached", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(theme.resolved.accent.color)
                }
            }

            HStack(spacing: 8) {
                TextField("Search notes, PDFs, folders, captures, clips, chats, graph, claims", text: $contextQuery)
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.resolved.foreground.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .disabled(isRegenerating || isRefreshingContext)
                Button(action: onRefreshContext) {
                    Label(isRefreshingContext ? "Searching" : "Add Context", systemImage: "magnifyingglass.circle")
                }
                .disabled(isRegenerating || isRefreshingContext || contextQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(action: onClearContext) {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .disabled(isRegenerating || isRefreshingContext || !hasVaultContext)
            }
            .font(.caption)
            .buttonStyle(.plain)

            FlowLayout(spacing: 6) {
                ForEach(HTMLWorkspaceRegenerateContextShortcut.all) { shortcut in
                    Button {
                        onRequestContextShortcut(shortcut)
                    } label: {
                        Label(shortcut.title, systemImage: shortcut.systemImage)
                            .font(pixelMicroFont)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.resolved.foreground.color)
                    .disabled(isRegenerating || isRefreshingContext)
                    .help(shortcut.helpText)
                }
            }

            if let contextStatusText, !contextStatusText.isEmpty {
                Text(contextStatusText)
                    .font(.caption2)
                    .foregroundStyle(mutedText)
                    .lineLimit(2)
            }

            if !contextItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(contextItems.prefix(5)) { item in
                        contextItemButton(item)
                    }
                }
            }
        }
    }

    private func contextItemButton(_ item: HTMLWorkspaceRegenerateContextItem) -> some View {
        Button {
            onFocusContextItem(item)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: item.systemImage)
                    .frame(width: 14)
                    .foregroundStyle(theme.resolved.accent.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(pixelCaptionFont)
                        .foregroundStyle(theme.resolved.foreground.color)
                        .lineLimit(1)
                    Text(item.contextDescriptor)
                        .font(pixelMicroFont)
                        .foregroundStyle(mutedText)
                        .lineLimit(1)
                    Text(item.provenanceDescriptor)
                        .font(pixelMicroFont)
                        .foregroundStyle(mutedText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isRegenerating || isRefreshingContext)
        .help(item.promptPayload)
    }

    private var advancedFallback: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onCopyPrompt) {
                    Label("Copy Recovery Prompt", systemImage: "doc.on.doc")
                }
                .disabled(isRegenerating || instructionIsEmpty)
                Button(action: onPreviewStream) {
                    Label("Preview Recovery Response", systemImage: "eye")
                }
                .disabled(isRegenerating || streamedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(action: onApplyStream) {
                    Label("Apply Recovery Response", systemImage: "checkmark.circle")
                }
                .disabled(isRegenerating || streamedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .font(pixelControlFont)
            .buttonStyle(.plain)

            ZStack(alignment: .topLeading) {
                if streamedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(isRegenerating ? "Streaming response..." : "Paste a saved regenerate response only if live streaming failed.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(mutedText)
                        .padding(12)
                }
                TextEditor(text: $streamedText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.resolved.foreground.color)
                    .disabled(isRegenerating)
                    .scrollContentBackground(.hidden)
                    .padding(4)
            }
            .frame(maxWidth: .infinity, minHeight: 132, maxHeight: 180)
            .background(streamBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.top, 8)
    }
}
