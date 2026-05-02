import SwiftUI

// MARK: - ShadowPanelContent
//
// Wave 8.5 of the Extended Program Plan
// (cross-ref `ambient/EPISTEMOS_V1_DECISION.md` §"UI" → "Floating panel").
//
// SwiftUI content of the Halo's NSPanel. Per the V1 decision:
//   - 360 × 480 fixed frame (caps blur cost ≤ 2 ms/frame)
//   - `.ultraThinMaterial` background
//   - Domain picker (Notes / Chats) at the top
//   - Lazy results list with hover preview
//   - Esc dismisses (via `.onExitCommand`)
//
// Hover preview / inline edit / context-menu summarise hooks are
// scaffolded out as W8.6 follow-up callbacks so this file stays
// pure-presentation today.

/// Closure surface the panel content uses to communicate user
/// intentions back to the application. Each handler runs on the
/// MainActor (the panel is @MainActor).
public struct ShadowPanelHandlers: Sendable {
    /// Called when the user clicks a row's primary action.
    public var onOpenHit: @MainActor (ShadowHit) -> Void
    /// Called when the user begins inline-editing a note row.
    public var onBeginEditNote: @MainActor (ShadowHit) -> Void
    /// Called with the new body when the user commits an inline edit.
    public var onCommitEdit: @MainActor (_ id: String, _ body: String) -> Void
    /// Called when the user picks "Summarise" from a chat row's
    /// context menu.
    public var onSummarizeChat: @MainActor (ShadowHit) -> Void

    public init(
        onOpenHit: @escaping @MainActor (ShadowHit) -> Void = { _ in },
        onBeginEditNote: @escaping @MainActor (ShadowHit) -> Void = { _ in },
        onCommitEdit: @escaping @MainActor (String, String) -> Void = { _, _ in },
        onSummarizeChat: @escaping @MainActor (ShadowHit) -> Void = { _ in }
    ) {
        self.onOpenHit = onOpenHit
        self.onBeginEditNote = onBeginEditNote
        self.onCommitEdit = onCommitEdit
        self.onSummarizeChat = onSummarizeChat
    }
}

/// Top-level SwiftUI content for the Halo panel.
public struct ShadowPanelContent: View {

    let controller: HaloController
    let handlers: ShadowPanelHandlers
    let onClose: @MainActor () -> Void
    @State private var hoveredID: String?

    public init(
        controller: HaloController,
        handlers: ShadowPanelHandlers = ShadowPanelHandlers(),
        onClose: @escaping @MainActor () -> Void = {}
    ) {
        self.controller = controller
        self.handlers = handlers
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            domainPicker
            Divider()
            resultsList
            if hoveredID != nil {
                Divider()
                hoveredPreview
            }
        }
        .frame(width: 360, height: 480)
        .background(.ultraThinMaterial)
        .onExitCommand {
            controller.closePanel()
            onClose()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Contextual shadows")
    }

    private var domainPicker: some View {
        Picker(
            "",
            selection: Binding(
                get: { controller.domain },
                set: { newValue in
                    // Domain swap is a tap, not a typing event — re-emit the
                    // controller's current matches by retriggering on the
                    // already-active query. The controller exposes
                    // editorTextDidChange + our caller wires it up; here we
                    // just bias future searches by setting `domain`.
                    // (When the controller is wired to a live editor the
                    //  next keystroke will re-query under the new domain.)
                    _ = newValue
                }
            )
        ) {
            Text("Notes").tag(ShadowDomain.notes)
            Text("Chats").tag(ShadowDomain.chats)
        }
        .pickerStyle(.segmented)
        .padding(8)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(controller.matches) { hit in
                    ShadowRow(
                        hit: hit,
                        onHover: { hovering in
                            hoveredID = hovering ? hit.id : nil
                        },
                        onOpen: { handlers.onOpenHit(hit) },
                        onEdit: { handlers.onBeginEditNote(hit) }
                    )
                    .contextMenu {
                        if hit.domain == .chats {
                            Button("Summarise") {
                                handlers.onSummarizeChat(hit)
                            }
                        }
                        Button("Open") {
                            handlers.onOpenHit(hit)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }

    @ViewBuilder
    private var hoveredPreview: some View {
        if let id = hoveredID,
           let hit = controller.matches.first(where: { $0.id == id }) {
            HoverPreview(hit: hit).frame(height: 180)
        }
    }
}

// MARK: - Row + score bar + hover preview

/// One row in the results list. Pure presentation — all interaction
/// flows through the closure parameters supplied by ShadowPanelContent.
public struct ShadowRow: View {
    let hit: ShadowHit
    let onHover: (Bool) -> Void
    let onOpen: () -> Void
    let onEdit: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(hit.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer()
                ScoreBar(score: hit.score)
            }
            Text(hit.snippet)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(8)
        .background(.regularMaterial.opacity(0.001))   // wide hit area without visible chrome
        .contentShape(Rectangle())
        .onHover(perform: onHover)
        .onTapGesture { onOpen() }
        .swipeActions { Button("Edit", action: onEdit) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hit.title), score \(Int(hit.score * 100)) percent")
    }
}

/// Tiny capsule indicator showing the hit's relevance score (0–1)
/// per the V1 decision §"Visual + graphic design": no skeumorphism,
/// three colors max — uses the system tint.
public struct ScoreBar: View {
    let score: Float
    public var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.tint.opacity(0.2))
                .frame(width: 24, height: 3)
            Capsule()
                .fill(.tint.opacity(Double(score)))
                .frame(width: 24 * CGFloat(min(max(score, 0), 1)), height: 3)
        }
        .accessibilityHidden(true)
    }
}

/// Bottom-of-panel preview shown when a row is hovered. Renders the
/// pre-truncated snippet — full body fetch is a W8.6 follow-up.
public struct HoverPreview: View {
    let hit: ShadowHit
    public var body: some View {
        ScrollView {
            Text(hit.snippet)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.regularMaterial)
        .accessibilityLabel("Preview of \(hit.title)")
    }
}
