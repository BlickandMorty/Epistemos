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
            domainPicker
            graphProjectionRibbon
            provenanceLedgerRibbon
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

    private var domainPicker: some View {
        Picker(
            "",
            selection: Binding(
                get: { controller.domain },
                set: { newValue in
                    controller.selectDomain(newValue)
                }
            )
        ) {
            Text("Notes").tag(ShadowDomain.notes)
            Text("Chats").tag(ShadowDomain.chats)
        }
        .pickerStyle(.segmented)
        .padding(8)
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

    /// V2 Lane 1 — DAG-authoritative Rust provenance signal surfaced in
    /// the Halo panel as a peer of the GraphEvent projection ribbon. The
    /// legacy ClaimLedger bridge stays available for compatibility, but
    /// the visible ambient signal follows the Cognitive DAG because the
    /// DAG is the provenance ledger after the Phase 8 mirror wiring.
    private var provenanceLedgerRibbon: some View {
        let stats = RustCognitiveDagClient.stats()
        return HStack(spacing: 6) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(provenanceLedgerLabel(for: stats))
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
        .accessibilityLabel(provenanceLedgerAccessibilityLabel(for: stats))
    }

    private func provenanceLedgerLabel(for stats: RustCognitiveDagStats) -> String {
        if stats.isEmpty {
            return "DAG ledger empty"
        }
        return "DAG ledger: \(stats.nodeCount) nodes · \(stats.edgeCount) edges"
    }

    private func provenanceLedgerAccessibilityLabel(for stats: RustCognitiveDagStats) -> String {
        "Rust Cognitive DAG provenance: \(stats.nodeCount) nodes, \(stats.edgeCount) edges, schema version \(stats.schemaVersion)"
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
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(controller.matches) { hit in
                        ShadowRow(
                            hit: hit,
                            onHover: { hovering in
                                hoveredID = hovering ? hit.id : nil
                            },
                            onOpen: { handlers.onOpenHit(hit) },
                            onEdit: { handlers.onBeginEditNote(hit) },
                            onSummarize: { handlers.onSummarizeChat(hit) }
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
    let onSummarize: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(hit.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer()
                // §B.6 W1 wiring: render the 4-tier cognitive-weight
                // badge alongside the existing ScoreBar. Today we
                // derive the weight from `hit.score` (raw retrieval
                // confidence); when EpistemosSidecar metadata flows
                // through the Shadow FFI (sidecar→hit field
                // bridging, separate slice), this switches to a
                // sidecar-sourced CognitiveWeight without changing
                // the badge component. `policyAuthority` stays false
                // here regardless — W1 silent-downgrade is enforced
                // inside `CognitiveWeight.init(rawScore:)`.
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
            Text(provenanceLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                // 2026-05-20 single-blur policy: tiny pill — use a primary
                // tint that adapts to light/dark instead of allocating a
                // `.thinMaterial` blur kernel for a few-pixel capsule.
                .background(
                    Capsule().fill(Color.primary.opacity(0.08))
                )
                .accessibilityLabel("Source \(provenanceLabel)")

            Spacer(minLength: 4)
            actionButton(title: "Open", action: onOpen)
            if hit.domain == .notes {
                actionButton(title: "Edit", action: onEdit)
            }
            if hit.domain == .chats {
                actionButton(title: "Summarise", action: onSummarize)
            }
        }
    }

    private var provenanceLabel: String {
        hit.source.isEmpty ? hit.domain.rawValue : hit.source
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
