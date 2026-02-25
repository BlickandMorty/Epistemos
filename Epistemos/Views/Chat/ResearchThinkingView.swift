import SwiftUI

// MARK: - Research Thinking View
// Gemini-style simulated thinking accordion for research mode.
// Shows pipeline stages advancing with realistic timings and an elapsed timer.
// Toggleable — tap to expand/collapse the stage list.
//
// Stage advancement is purely time-based from ChatState.researchStartTime.
// When enrichment completes (detected by caller), this view stops being shown.

struct ResearchThinkingView: View {
    /// Whether the research is still running (live) or completed (on a message).
    let isLive: Bool
    /// Final duration — set when research completes, nil while live.
    let finalDuration: Double?

    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @State private var isExpanded: Bool

    private var theme: EpistemosTheme { ui.theme }

    init(isLive: Bool = true, finalDuration: Double? = nil) {
        self.isLive = isLive
        self.finalDuration = finalDuration
        self._isExpanded = State(initialValue: isLive)
    }

    // MARK: - Simulated Pipeline Stages
    // Maps to the real 10-stage pipeline + 6-pass enrichment.
    // Timings compressed to fit within the streaming window (~15-25s for Pass 1).
    // After streaming completes, the thinking view stays visible on the message
    // and continues advancing through enrichment stages until enrichment finishes.

    private static let stages: [(name: String, icon: String, startsAt: Double)] = [
        ("Triage & classification",       "line.3.horizontal.decrease.circle",  0),
        ("Memory retrieval",              "brain.head.profile",                 1),
        ("Statistical analysis",          "chart.bar.xaxis",                    2.5),
        ("Causal inference",              "arrow.triangle.branch",              4),
        ("Meta-analysis (I²)",            "square.stack.3d.up",                 6),
        ("Bayesian updating (BF₁₀)",     "function",                           8),
        ("Synthesis & integration",       "arrow.triangle.merge",              10),
        ("Adversarial stress-testing",    "shield.lefthalf.filled.slash",      12),
        ("Confidence calibration",        "dial.medium",                       14),
        ("Generating research analysis",  "text.document",                     17),
        ("Reflection & self-critique",    "arrow.2.squarepath",                22),
        ("Multi-engine arbitration",      "person.3.fill",                     28),
        ("Truth assessment",              "checkmark.seal",                    35),
    ]

    /// Current elapsed seconds since research started.
    private var elapsed: Double {
        if let dur = finalDuration { return dur }
        guard let start = chat.researchStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    /// Index of the currently active stage (last stage whose startsAt <= elapsed).
    private func activeStageIndex(at elapsed: Double) -> Int {
        var idx = 0
        for (i, stage) in Self.stages.enumerated() {
            if elapsed >= stage.startsAt { idx = i }
        }
        return idx
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: isLive ? 0.5 : 60)) { context in
            let now = elapsed
            let currentIdx = activeStageIndex(at: now)

            VStack(alignment: .leading, spacing: 0) {
                // Header — tap to toggle
                headerRow(elapsed: now, currentStage: Self.stages[currentIdx].name)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(Motion.quick) { isExpanded.toggle() }
                    }

                // Expanded stage list
                if isExpanded {
                    Rectangle()
                        .fill(theme.glassBorder)
                        .frame(height: 0.5)
                        .padding(.horizontal, Spacing.sm)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(Self.stages.enumerated()), id: \.offset) { index, stage in
                                stageRow(
                                    stage: stage,
                                    index: index,
                                    currentIdx: currentIdx,
                                    elapsed: now
                                )
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                    }
                    .frame(maxHeight: 320)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.glassBg.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isLive ? theme.accent.opacity(0.2) : theme.glassBorder,
                        lineWidth: 0.5
                    )
            )
            .animation(Motion.smooth, value: isExpanded)
            .animation(Motion.quick, value: currentIdx)
        }
    }

    // MARK: - Header

    private func headerRow(elapsed: Double, currentStage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isLive ? "sparkles" : "sparkles")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isLive ? theme.accent : theme.mutedForeground.opacity(0.6))
                .symbolEffect(.pulse.wholeSymbol, options: .repeating, isActive: isLive)

            if isLive {
                Text("Researching")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.foreground.opacity(0.8))
            } else {
                Text("Research Complete")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.mutedForeground.opacity(0.7))
            }

            // Elapsed timer badge
            Text(formatElapsed(elapsed))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(isLive ? theme.accent.opacity(0.8) : theme.mutedForeground.opacity(0.5))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(isLive ? theme.accent.opacity(0.1) : theme.glassBg))

            if isLive {
                Spacer()
                // Current stage label
                Text(currentStage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.mutedForeground.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.mutedForeground.opacity(0.4))
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
    }

    // MARK: - Stage Row

    private func stageRow(
        stage: (name: String, icon: String, startsAt: Double),
        index: Int,
        currentIdx: Int,
        elapsed: Double
    ) -> some View {
        let isComplete = index < currentIdx
        let isActive = index == currentIdx && isLive
        let isPending = index > currentIdx

        return HStack(spacing: 10) {
            // Status indicator
            ZStack {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.success.opacity(0.7))
                } else if isActive {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(theme.accent.opacity(0.3), lineWidth: 2)
                                .frame(width: 14, height: 14)
                        )
                } else {
                    Circle()
                        .fill(theme.mutedForeground.opacity(0.15))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 16, height: 16)

            // Icon
            Image(systemName: stage.icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(
                    isComplete ? theme.success.opacity(0.6) :
                    isActive ? theme.accent :
                    theme.mutedForeground.opacity(0.3)
                )
                .frame(width: 14)

            // Name
            Text(stage.name)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundStyle(
                    isComplete ? theme.foreground.opacity(0.5) :
                    isActive ? theme.foreground.opacity(0.9) :
                    theme.mutedForeground.opacity(0.35)
                )

            Spacer()

            // Duration for completed stages
            if isComplete, index + 1 < Self.stages.count {
                let stageDuration = Self.stages[index + 1].startsAt - stage.startsAt
                Text(formatStageDuration(stageDuration))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.mutedForeground.opacity(0.3))
            }
        }
        .padding(.vertical, 3)
        .opacity(isPending ? 0.5 : 1)
    }

    // MARK: - Formatters

    private func formatElapsed(_ seconds: Double) -> String {
        let s = Int(seconds)
        let mins = s / 60
        let secs = s % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(secs)s"
    }

    private func formatStageDuration(_ seconds: Double) -> String {
        if seconds < 1 { return "<1s" }
        return String(format: "%.0fs", seconds)
    }
}
