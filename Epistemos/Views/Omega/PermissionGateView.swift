import SwiftUI

// MARK: - Permission Gate View

/// Displays TCC permission status and guides users through granting
/// permissions required by the local agent runtime.
///
/// Shows when:
/// - Accessibility permission is needed (AXorcist, omega-ax)
/// - Screen Recording permission is needed (ScreenCaptureKit)
/// - Before first computer use action
struct PermissionGateView: View {
    let permissionState: TCCPermissionState
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "lock.shield")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Agent Runtime Permissions")
                    .font(.headline)
                Spacer()
                if permissionState.allRequiredGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Divider()

            // Permission rows
            permissionRow(
                title: "Accessibility",
                description: "Read UI elements and simulate input",
                status: permissionState.accessibility,
                required: true,
                action: permissionState.requestAccessibility
            )

            permissionRow(
                title: "Screen Recording",
                description: "Capture screenshots for visual verification",
                status: permissionState.screenRecording,
                required: true,
                action: permissionState.openScreenRecordingSettings
            )

            permissionRow(
                title: "Automation",
                description: "Control other apps via Apple Events",
                status: permissionState.automation,
                required: false,
                action: permissionState.openAutomationSettings
            )

            Divider()

            // Actions
            HStack {
                Button("Refresh") {
                    Task { await permissionState.refresh() }
                }
                .buttonStyle(.bordered)

                Spacer()

                if let onDismiss {
                    Button("Done") { onDismiss() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!permissionState.allRequiredGranted)
                }
            }

            if !permissionState.allRequiredGranted {
                Text("Grant the required permissions above, then click Refresh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 400)
        .task {
            await permissionState.refresh()
        }
    }

    @ViewBuilder
    private func permissionRow(
        title: String,
        description: String,
        status: TCCStatus,
        required: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor(status))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    if required {
                        Text("Required")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(status.label)
                .font(.caption)
                .foregroundStyle(status.isGranted ? .green : .red)

            if !status.isGranted {
                Button("Grant") { action() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private func statusColor(_ status: TCCStatus) -> Color {
        switch status {
        case .granted: return .green
        case .denied: return .red
        case .unknown: return .gray
        }
    }
}
