import SwiftUI

// Read-only Plan 1 diagnostics for the Goose surface.
// Native owns only the rounded frame; Goose WebView owns nav, routes, models,
// settings, and chat. This row reports availability without adding controls.

@MainActor
public struct GooseSurfaceHealthRow: View {
    @State private var availability = GooseSurfaceAvailability.current()
    @State private var nativeFrameEnabled = AgentSurface.isEnabled()

    public init() {}

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack")
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Epistemos Goose")
                    .font(.system(size: 13, weight: .medium))
                Text(Self.detail(for: availability, nativeFrameEnabled: nativeFrameEnabled))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(Self.badge(for: availability))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(availability.isReady ? Color.green : Color.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear(perform: refresh)
    }

    private func refresh() {
        availability = GooseSurfaceAvailability.current()
        nativeFrameEnabled = AgentSurface.isEnabled()
    }

    nonisolated static func detail(
        for availability: GooseSurfaceAvailability,
        nativeFrameEnabled: Bool
    ) -> String {
        guard availability.isReady else {
            return availability.unavailableMessage.isEmpty
                ? "Goose Web UI is not staged."
                : availability.unavailableMessage
        }

        return nativeFrameEnabled
            ? "Ready — native rounded frame only; Goose WebView owns navigation and routes."
            : "Ready — fallback Goose window; Goose WebView owns navigation and routes."
    }

    nonisolated static func badge(for availability: GooseSurfaceAvailability) -> String {
        availability.isReady ? "ready" : "missing"
    }
}
