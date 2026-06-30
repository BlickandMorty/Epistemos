#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
import AppKit
import Foundation
import SwiftUI

struct VaultMCPServerSettingsRow: View {
    let vaultRoot: URL?

    @State private var registration: WorkNativeMCPRegistration?
    @State private var pendingVaultPath: String?
    @State private var statusMessage: String?
    @State private var didCopyConfig = false
    @State private var vaultNoteCount: Int?

    private var isStarting: Bool {
        pendingVaultPath != nil
    }

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
        .task(id: vaultRoot.map(Self.canonicalVaultPath)) {
            reconcilePendingOperationWithCurrentVault()
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
        let vaultPath = Self.canonicalVaultPath(vaultRoot)
        pendingVaultPath = vaultPath
        statusMessage = nil
        Task {
            guard isPendingOperationCurrent(for: vaultPath) else { return }
            let result = await VaultMCPHost.shared.start(vaultRoot: vaultRoot)
            guard completePendingOperation(for: vaultPath) else { return }
            registration = result
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
        pendingVaultPath = nil
        statusMessage = "Stopped."
    }

    private func rotate() {
        guard let vaultRoot else { return }
        let vaultPath = Self.canonicalVaultPath(vaultRoot)
        pendingVaultPath = vaultPath
        didCopyConfig = false
        statusMessage = nil
        Task {
            guard isPendingOperationCurrent(for: vaultPath) else { return }
            let result = await VaultMCPHost.shared.rotateTokenAndRestart(vaultRoot: vaultRoot)
            guard completePendingOperation(for: vaultPath) else { return }
            registration = result
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
        let path = Self.canonicalVaultPath(root)
        let count = await Task.detached(priority: .utility) {
            VaultMCPCore.markdownRelPaths(vaultRoot: root).count
        }.value
        guard !Task.isCancelled, currentVaultPath == path else { return }
        vaultNoteCount = count
    }

    private var currentVaultPath: String? {
        vaultRoot.map(Self.canonicalVaultPath)
    }

    private func reconcilePendingOperationWithCurrentVault() {
        guard pendingVaultPath != currentVaultPath else { return }
        pendingVaultPath = nil
    }

    private func isPendingOperationCurrent(for vaultPath: String) -> Bool {
        pendingVaultPath == vaultPath && currentVaultPath == vaultPath
    }

    private func completePendingOperation(for vaultPath: String) -> Bool {
        guard pendingVaultPath == vaultPath else { return false }
        guard currentVaultPath == vaultPath else {
            pendingVaultPath = nil
            return false
        }
        pendingVaultPath = nil
        return true
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

    private static func canonicalVaultPath(_ url: URL) -> String {
        VaultMCPHost.canonicalVaultPath(url)
    }
}
#endif
