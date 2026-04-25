import SwiftUI

// MARK: - ContextualShadowsPanel
// Patch 7 / AMBIENT_RECALL_WIRING_PLAN.md §5 — lightweight slide-in panel
// surfaced when the user clicks `ContextualShadowsButton`. Two tabs:
// Notes / Chats. Lists the top-K hits with title + snippet. Click invokes
// the supplied open action so the host (note window or chat shell) stays in
// charge of routing.
//
// Constraints (plan §10 R4):
// - NOT modal, NOT full-width — fixed compact width.
// - Slide-in from the bottom-right at constant size.
// - Respects `reduceMotion`.

struct ContextualShadowsPanel: View {
    @Environment(ContextualShadowsState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Caller-provided open routing — the host knows whether to open in the
    /// current window, push a chat thread, etc. V0 routes to the existing
    /// note/chat open mechanisms in the host scope.
    var onOpen: (ContextualShadowsState.RecallHit) -> Void = { _ in }

    @State private var selectedTab: RecallContextKind = .note

    private var noteHits: [ContextualShadowsState.RecallHit] {
        state.currentResults.filter { $0.kind == .note }
    }

    private var chatHits: [ContextualShadowsState.RecallHit] {
        state.currentResults.filter { $0.kind == .chat }
    }

    var body: some View {
        if state.isEnabled, state.isPanelVisible {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                tabPicker
                Divider()
                content
            }
            .frame(width: 320)
            .frame(maxHeight: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
            .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            Text("Related")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Button {
                state.closePanel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close")
            .accessibilityLabel("Close related panel")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Tabs

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(.note, label: "Notes", count: noteHits.count)
            tabButton(.chat, label: "Chats", count: chatHits.count)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private func tabButton(_ kind: RecallContextKind, label: String, count: Int) -> some View {
        Button {
            selectedTab = kind
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: selectedTab == kind ? .semibold : .regular))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                }
            }
            .foregroundStyle(selectedTab == kind ? Color.primary : Color(nsColor: .secondaryLabelColor))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(selectedTab == kind
                          ? Color(nsColor: .quaternaryLabelColor).opacity(0.6)
                          : Color.clear)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) tab, \(count) results")
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let hits = (selectedTab == .note) ? noteHits : chatHits
        if hits.isEmpty {
            VStack {
                Spacer()
                Text("No matches")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 80)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(hits) { hit in
                        RecallHitRow(hit: hit) {
                            onOpen(hit)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
        }
    }
}

// MARK: - RecallHitRow

private struct RecallHitRow: View {
    let hit: ContextualShadowsState.RecallHit
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(hit.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(String(format: "%.0f%%", min(max(hit.similarity, 0), 1) * 100))
                        .font(.system(size: 9, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                }
                if !hit.snippet.isEmpty {
                    Text(hit.snippet)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.18))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(hit.snippet.isEmpty ? hit.title : hit.snippet)
        .accessibilityLabel("\(hit.title), \(hit.kind.rawValue) result")
        .accessibilityHint("Open this \(hit.kind.rawValue)")
    }
}
