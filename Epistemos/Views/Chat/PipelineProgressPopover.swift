import SwiftUI

// MARK: - Pipeline Progress Popover
// Glass popover showing the 10-stage analytical pipeline with live status indicators.
// Mirrors ConceptMiniMap's styling — glassBg + glassBorder + compact layout.
// Data source: PipelineState.pipelineStages, activeStage, currentProgress.

struct PipelineProgressPopover: View {
    @Environment(UIState.self) private var ui
    @Environment(PipelineState.self) private var pipeline

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.accent.opacity(0.6))
                Text("PIPELINE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.accent.opacity(0.5))
                    .tracking(0.4)

                Spacer()

                Text("\(Int(pipeline.currentProgress * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.accent)
                    .contentTransition(.numericText())
            }

            // Stage list
            VStack(alignment: .leading, spacing: 3) {
                ForEach(PipelineStage.allCases, id: \.self) { stage in
                    stageRow(stage)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.foreground.opacity(0.06))
                    Capsule()
                        .fill(theme.accent.opacity(0.7))
                        .frame(width: geo.size.width * pipeline.currentProgress)
                        .animation(Motion.smooth, value: pipeline.currentProgress)
                }
            }
            .frame(height: 3)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.glassBg.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.glassBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Stage Row

    @ViewBuilder
    private func stageRow(_ stage: PipelineStage) -> some View {
        let result = pipeline.pipelineStages.first(where: { $0.stage == stage })
        let status = result?.status ?? .idle
        let isActive = pipeline.activeStage == stage

        HStack(spacing: 8) {
            // Status indicator
            statusDot(status)
                .frame(width: 8, height: 8)

            // Stage name
            Text(stage.displayName)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundStyle(
                    isActive ? theme.accent :
                    status == .completed ? theme.foreground.opacity(0.7) :
                    theme.mutedForeground.opacity(0.4)
                )

            Spacer()

            // Description for active stage
            if isActive {
                Text(stage.stageDescription)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.mutedForeground.opacity(0.5))
                    .lineLimit(1)
            }

            // Duration badge for completed stages
            if let ms = result?.durationMs, status == .completed {
                Text("\(ms)ms")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.success.opacity(0.7))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            isActive ? theme.accent.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
        )
        .animation(Motion.micro, value: status)
    }

    // MARK: - Status Dot

    @ViewBuilder
    private func statusDot(_ status: StageStatus) -> some View {
        switch status {
        case .idle:
            Circle()
                .fill(theme.mutedForeground.opacity(0.15))
        case .pending:
            Circle()
                .fill(theme.mutedForeground.opacity(0.25))
        case .running:
            Circle()
                .fill(theme.accent)
                .overlay(
                    Circle()
                        .strokeBorder(theme.accent.opacity(0.4), lineWidth: 2)
                        .scaleEffect(1.6)
                )
                .symbolEffect(.pulse, isActive: true)
        case .completed:
            Circle()
                .fill(theme.success)
        case .failed:
            Circle()
                .fill(theme.error)
        case .skipped:
            Circle()
                .fill(Color(hex: 0xD4A843).opacity(0.6))
        }
    }
}
