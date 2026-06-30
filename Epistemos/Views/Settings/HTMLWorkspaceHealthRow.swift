import SwiftUI

// MARK: - HTMLWorkspaceHealthRow
//
// SS-HW (owner 2026-06-20): "the html workspace does not work as well but idk if its marked as such."
// A read-only Settings → Diagnostics row that honestly states the HTML Workspace's real capability
// state — what works (multi-file editing, WKWebView preview, agent chat patches) vs what's still a
// static/deferred seam (app message-bridge, live-DOM inspection, Python, full-surface regenerate) plus
// flag-gated console capture. It reads HTMLWorkspaceCapabilityStatus's static ledger only (no @Environment), so it's
// crash-safe in Settings. Tinted info-blue, not red: the workspace genuinely works as a renderer —
// it's just not the full web-app builder yet, and now says so instead of shipping silently as complete.

@MainActor
public struct HTMLWorkspaceHealthRow: View {

    public init() {}

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe")
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("HTML Workspace")
                    .font(.system(size: 13, weight: .medium))
                Text(HTMLWorkspaceCapabilityStatus.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            // Works-but-partial → an honest info dot (live/deferred count), never a green "complete"
            // check or a red "broken" cross.
            Text("\(HTMLWorkspaceCapabilityStatus.liveCount)/\(HTMLWorkspaceCapabilityStatus.capabilities.count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
