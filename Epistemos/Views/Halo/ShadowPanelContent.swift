import SwiftUI

// MARK: - ShadowPanelContent
//
// Wave 8.5 of the Extended Program Plan
// (cross-ref `ambient/EPISTEMOS_V1_DECISION.md` §"UI" → "Floating panel").
//
// SwiftUI content of the Halo's NSPanel. Per the V1 decision:
//   - 360 × 480 fixed frame (caps blur cost ≤ 2 ms/frame)
//   - `.ultraThinMaterial` background
//   - Notes-only results with hover preview
//   - Lazy results list with hover preview
//   - Esc dismisses (via `.onExitCommand`)
//
// Hover preview plus row actions stay pure-presentation: the panel only
// exposes intent through handlers and never performs retrieval or mutation.

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
    public init(
        onOpenHit: @escaping @MainActor (ShadowHit) -> Void = { _ in },
        onBeginEditNote: @escaping @MainActor (ShadowHit) -> Void = { _ in },
        onCommitEdit: @escaping @MainActor (String, String) -> Void = { _, _ in }
    ) {
        self.onOpenHit = onOpenHit
        self.onBeginEditNote = onBeginEditNote
        self.onCommitEdit = onCommitEdit
    }
}

/// Top-level SwiftUI content for the Halo panel.
public struct ShadowPanelContent: View {

    let controller: HaloController
    let handlers: ShadowPanelHandlers
    let onClose: @MainActor () -> Void
    @Environment(UIState.self) private var ui
    @State private var hoveredID: String?

    private var theme: EpistemosTheme { ui.theme }

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
            graphProjectionRibbon
            Divider()
            resultsList
            if hoveredID != nil {
                Divider()
                hoveredPreview
            }
        }
        .frame(width: 360, height: 480)
        // 2026-05-19: bring Halo into the unified frosted-glass treatment.
        // No corner radius was applied before — preserve the rectangular
        // outline (the panel's window chrome handles any rounding).
        .unifiedFrostedGlass(theme: theme, in: Rectangle())
        .onExitCommand {
            controller.closePanel()
            onClose()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Contextual shadows")
    }

    private var graphProjectionRibbon: some View {
        let report = controller.graphProjectionReport
        return HStack(spacing: 6) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(graphProjectionLabel(for: report))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        // 2026-05-20 single-blur policy: the Halo panel now carries its
        // ONE NSVisualEffectView at the window level (see ShadowPanel.swift).
        // Inner ribbons are theme-tinted overlays only — no nested Material.
        .background(theme.glassBg.opacity(0.55))
        .accessibilityLabel(graphProjectionAccessibilityLabel(for: report))
    }

    /// Returns the recoverable-error message when the controller has
    /// transitioned to `.errorRecoverable(...)` (per RCA13 P5 the Halo
    /// surfaces backend failures here instead of pretending it's an
    /// empty result set).
    private var recoverableErrorMessage: String? {
        if case let .errorRecoverable(message) = controller.state {
            return message
        }
        return nil
    }

    @ViewBuilder
    private var resultsList: some View {
        if let errorMessage = recoverableErrorMessage {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Halo backend unavailable")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                }
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if noteMatches.isEmpty {
            // SS-IR: the resting bubble can open with zero hits — show an honest empty state
            // instead of a blank panel ("I clicked it and nothing's here" → "no matches yet").
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("No matches yet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                }
                Text("Keep typing — related notes surface here as you write.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(noteMatches) { hit in
                        ShadowRow(
                            hit: hit,
                            onHover: { hovering in
                                hoveredID = hovering ? hit.id : nil
                            },
                            onOpen: { handlers.onOpenHit(hit) },
                            onEdit: { handlers.onBeginEditNote(hit) }
                        )
                        .contextMenu {
                            Button("Open") {
                                handlers.onOpenHit(hit)
                            }
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
           let hit = noteMatches.first(where: { $0.id == id }) {
            HoverPreview(hit: hit).frame(height: 180)
        }
    }

    private var noteMatches: [ShadowHit] {
        controller.matches.filter { $0.domain == .notes }
    }

    private func graphProjectionLabel(for report: GraphEventAuditProjectionReport) -> String {
        guard !report.isEmpty else { return "Graph projection idle" }
        return "Graph projection: \(report.eventCount) events / \(report.nodeCount) nodes / \(report.edgeCount) edges"
    }

    private func graphProjectionAccessibilityLabel(for report: GraphEventAuditProjectionReport) -> String {
        guard !report.isEmpty else { return "Graph projection has no durable events yet" }
        return "Graph projection has \(report.eventCount) events, \(report.nodeCount) nodes, and \(report.edgeCount) edges"
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
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(hit.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer()
                // Retrieval confidence is shown directly alongside the score.
                CognitiveWeightBadge(
                    weight: CognitiveWeight(rawScore: hit.score)
                )
                ScoreBar(score: hit.score)
            }
            Text(hit.snippet)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            sourceAndActions
        }
        .padding(8)
        // 2026-05-20: was `.regularMaterial.opacity(0.001)` — a transparent
        // Material is still a blur-kernel allocation. Color.clear gives an
        // identical wide hit area for `.contentShape(Rectangle())` below
        // without any compositor cost. Single-blur policy.
        .background(Color.clear)
        .contentShape(Rectangle())
        .onHover(perform: onHover)
        .onTapGesture { onOpen() }
        .swipeActions { Button("Edit", action: onEdit) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(hit.title), \(CognitiveWeight(rawScore: hit.score).class.shortLabel) weight, score \(Int(hit.score * 100)) percent"
        )
    }

    private var sourceAndActions: some View {
        HStack(spacing: 6) {
            VaultRecallHaloProvenance(hit: hit, theme: theme)
                .accessibilityLabel("Source \(provenanceLabel)")

            Spacer(minLength: 4)
            actionButton(title: "Open", action: onOpen)
            actionButton(title: "Edit", action: onEdit)
        }
    }

    private var provenanceLabel: String {
        hit.source.isEmpty ? "notes" : hit.source
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderless)
            .controlSize(.mini)
            .font(.system(size: 10, weight: .semibold))
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
        // 2026-05-20 single-blur policy: HoverPreview lives inside the
        // Halo panel which already carries its single window-level blur
        // (ShadowPanel.swift). A primary tint reads the existing blur
        // through without allocating a second `.regularMaterial` kernel.
        .background(Color.primary.opacity(0.05))
        .accessibilityLabel("Preview of \(hit.title)")
    }
}

private struct VaultRecallHaloProvenance: View {
    let hit: ShadowHit
    let theme: EpistemosTheme

    private let iconName = "doc.text"

    private var label: String {
        let source = hit.source.trimmingCharacters(in: .whitespacesAndNewlines)
        let vault = hit.originVaultKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (source.isEmpty, vault?.isEmpty == false ? vault : nil) {
        case (true, nil):
            return "notes"
        case (false, nil):
            return source
        case (true, let vault?):
            return vault
        case (false, let vault?):
            return "\(source) / \(vault)"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 9, weight: .semibold))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(theme.glassBg.opacity(theme.isDark ? 0.36 : 0.46), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(theme.border.opacity(theme.isDark ? 0.28 : 0.34), lineWidth: 1)
        )
    }
}
