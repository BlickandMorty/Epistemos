#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
import AppKit
import Foundation
import SwiftUI

struct VaultMCPServerSettingsRow: View {
    let vaultRoot: URL?

    @State private var registration: WorkNativeMCPRegistration?
    @State private var isStarting = false
    @State private var statusMessage: String?
    @State private var didCopyConfig = false
    @State private var vaultNoteCount: Int?

    private var isRunning: Bool {
        registration != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Enable read-only vault MCP server", isOn: Binding(
                get: { isRunning },
                set: { enabled in
                    if enabled {
                        start()
                    } else {
                        stop()
                    }
                }
            ))
            .disabled(vaultRoot == nil || isStarting)

            Text("Expose the connected markdown vault as a bearer-protected local MCP endpoint for external tools. The server advertises read-only vault and graph tools only.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let registration {
                LabeledContent("URL") {
                    Text(registration.url)
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                LabeledContent("Token") {
                    Text(VaultMCPTokenStore.masked(registration.token))
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            HStack(spacing: 8) {
                statusPill

                Spacer()

                Button("Rotate") {
                    rotate()
                }
                .disabled(!isRunning || isStarting || vaultRoot == nil)
                .controlSize(.small)

                Button(didCopyConfig ? "Copied" : "Copy MCP client config") {
                    copyClientConfig()
                }
                .disabled(registration == nil)
                .controlSize(.small)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task(id: vaultRoot?.path) {
            VaultMCPHost.shared.stopIfCurrentVaultDiffers(from: vaultRoot)
            registration = VaultMCPHost.shared.currentRegistration(for: vaultRoot)
            if registration == nil {
                vaultNoteCount = nil
            } else {
                await refreshVaultNoteCount(for: vaultRoot)
            }
            didCopyConfig = false
            statusMessage = nil
        }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        guard vaultRoot != nil else { return "No vault connected" }
        if isStarting { return "Starting" }
        guard isRunning else { return "Stopped" }
        if vaultNoteCount == 0 { return "Running (vault empty)" }
        return "Running"
    }

    private var statusColor: Color {
        guard vaultRoot != nil else { return .secondary }
        if isStarting { return .orange }
        return isRunning ? .green : .secondary
    }

    private func start() {
        guard let vaultRoot else {
            statusMessage = "Connect a vault before starting the MCP server."
            return
        }
        isStarting = true
        statusMessage = nil
        Task {
            let result = await VaultMCPHost.shared.start(vaultRoot: vaultRoot)
            registration = result
            isStarting = false
            statusMessage = result == nil ? "The MCP server did not become ready." : nil
            if result == nil {
                vaultNoteCount = nil
            } else {
                await refreshVaultNoteCount(for: vaultRoot)
            }
        }
    }

    private func stop() {
        VaultMCPHost.shared.stop()
        registration = nil
        vaultNoteCount = nil
        isStarting = false
        statusMessage = "Stopped."
    }

    private func rotate() {
        guard let vaultRoot else { return }
        isStarting = true
        didCopyConfig = false
        statusMessage = nil
        Task {
            let result = await VaultMCPHost.shared.rotateTokenAndRestart(vaultRoot: vaultRoot)
            registration = result
            isStarting = false
            statusMessage = result == nil ? "Token rotated, but the MCP server did not restart." : "Token rotated."
            if result == nil {
                vaultNoteCount = nil
            } else {
                await refreshVaultNoteCount(for: vaultRoot)
            }
        }
    }

    private func refreshVaultNoteCount(for root: URL?) async {
        guard let root else {
            vaultNoteCount = nil
            return
        }
        let path = root.path
        let count = await Task.detached(priority: .utility) {
            VaultMCPCore.markdownRelPaths(vaultRoot: root).count
        }.value
        guard !Task.isCancelled, vaultRoot?.path == path else { return }
        vaultNoteCount = count
    }

    private func copyClientConfig() {
        guard let registration else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.clientConfigJSON(for: registration), forType: .string)
        didCopyConfig = true
    }

    static func clientConfigJSON(for registration: WorkNativeMCPRegistration) -> String {
        let object: [String: Any] = [
            "type": "http",
            "url": registration.url,
            "headers": ["Authorization": "Bearer \(registration.token)"],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return #"{"type":"http","url":"\#(registration.url)","headers":{"Authorization":"Bearer \#(registration.token)"}}"#
        }
        return string
    }
}
#endif
