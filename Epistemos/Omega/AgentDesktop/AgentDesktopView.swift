import SwiftUI

// MARK: - Agent Desktop PiP View

/// Picture-in-Picture view showing the agent's isolated desktop.
///
/// Renders the ScreenCaptureKit feed from AgentDesktopCapture as a live
/// image. The user can watch the agent work without the agent stealing
/// focus from their active workspace.
struct AgentDesktopView: View {
    let manager: AgentDesktopManager

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text("Agent Desktop")
                    .font(.caption.bold())
                Spacer()
                if manager.state == .active {
                    Text("Live")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.15), in: Capsule())
                }
                Text("\(manager.capture.frameCount) frames")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)

            // Video feed
            if let frame = manager.capture.latestFrame {
                Image(decorative: frame, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(.black)
            } else {
                Rectangle()
                    .fill(.black)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "desktopcomputer")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text(statusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }

            // Status bar
            if let error = manager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    private var statusColor: Color {
        switch manager.state {
        case .idle: .secondary
        case .creatingSpace: .yellow
        case .ready: .blue
        case .active: .green
        case .tearingDown: .orange
        case .error: .red
        }
    }

    private var statusText: String {
        switch manager.state {
        case .idle: "No agent desktop active"
        case .creatingSpace: "Setting up agent desktop..."
        case .ready: "Desktop ready, waiting for agent"
        case .active: "Agent working..."
        case .tearingDown: "Cleaning up..."
        case .error: "Error"
        }
    }
}
