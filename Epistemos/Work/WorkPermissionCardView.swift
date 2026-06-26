import SwiftUI

// Native PERMISSION card (visual-target item "native permission/tool cards") for an engine permission.requested
// (WorkPermissionRequest). Flat/compact OpenCode-TUI minimal: boxy (cornerRadius 0), theme-aware tokens, monospace, no
// donor chrome, no raw JSON. Shows the permission/tool + the specific thing being permitted (request.detail) and the
// three decisions. The host (WorkEngineSurfaceView) shows it above the input when a request is pending and routes the
// decision to WorkOpenGUISupervisor.respondPermission (→ "once"/"always"/"reject").
struct WorkPermissionCardView: View {
    let request: WorkPermissionRequest
    var theme: EpistemosTheme = .nativeDefault
    var onDecision: (WorkPermissionDecision) -> Void = { _ in }

    private var accent: Color { theme.resolved.accent.color }
    private var cardBackground: Color { WorkSurfaceStyle.background(for: theme, role: .toolCard) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 11))
                    .foregroundStyle(accent)
                    .frame(width: 14, height: 14)
                Text("permission · \(request.permission)")
                    .font(WorkPixelFont.body(11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            if !request.detail.isEmpty {
                Text(request.detail)
                    .font(WorkPixelFont.body(12))
                    .foregroundStyle(theme.mutedForeground)
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) {
                decisionButton("Allow once", .allowOnce, filled: true)
                decisionButton("Always", .allowAlways, filled: false)
                Spacer(minLength: 0)
                decisionButton("Deny", .reject, filled: false, destructive: true)
            }
        }
        .padding(10)
        .background(cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(accent.opacity(0.6), lineWidth: 0.9))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func decisionButton(
        _ label: String, _ decision: WorkPermissionDecision, filled: Bool, destructive: Bool = false
    ) -> some View {
        let tint = destructive ? theme.mutedForeground : accent
        return Button { onDecision(decision) } label: {
            Text(label)
                .font(WorkPixelFont.body(11, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .foregroundStyle(filled ? (theme.isDark ? Color.black : Color.white) : tint)
                .background(filled ? tint : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(tint.opacity(0.6), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WorkPermissionCardView(request: WorkPermissionRequest(
        id: "perm_1", harnessID: nil, sessionID: "ses_x", permission: "bash",
        patterns: ["rm -rf build"], alwaysOptions: ["bash"], toolCallID: "call_7"))
        .frame(width: 360).padding()
}
