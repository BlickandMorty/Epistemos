import AppKit
import os
import SwiftUI

nonisolated enum CloudProviderSetupDiagnostics {
    static let maxLogMessageCharacters = 240

    static func logMessage(for error: Error, fallback: String) -> String {
        let nsError = error as NSError
        return logMessage(
            "\(fallback) (domain=\(safeDomain(nsError.domain)) code=\(nsError.code))",
            fallback: fallback
        )
    }

    static func logMessage(_ message: String, fallback: String = "Cloud provider setup failed") -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        guard trimmed.count > maxLogMessageCharacters else { return trimmed }

        let suffix = "..."
        let end = trimmed.index(
            trimmed.startIndex,
            offsetBy: max(0, maxLogMessageCharacters - suffix.count)
        )
        return String(trimmed[..<end]) + suffix
    }

    private static func safeDomain(_ domain: String) -> String {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Error" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Error"
        }
        guard trimmed.count <= 80 else {
            let end = trimmed.index(trimmed.startIndex, offsetBy: 80)
            return String(trimmed[..<end])
        }
        return trimmed
    }
}

@MainActor
enum CloudProviderSetupAutomation {
    private nonisolated static let logger = Logger(subsystem: "Epistemos", category: "CloudProviderSetupAutomation")
    private nonisolated static let googleOAuthClientConfigKeychainKey = "epistemos.google.oauthClientConfig"
    private nonisolated static let googleOAuthClientFilenameDefaultsKey = "epistemos.google.oauthClientFilename"
    private nonisolated static let googleOAuthProjectIDDraftDefaultsKey = "epistemos.google.oauthProjectIDDraft"

    static func clipboardKeyCandidate() -> String? {
        guard let rawValue = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return nil
        }
        return rawValue
    }

    @discardableResult
    static func pasteAndSave(
        provider: CloudModelProvider,
        inference: InferenceState
    ) async -> Bool {
        guard let clipboardValue = clipboardKeyCandidate() else {
            _ = inference.recordCloudProviderValidationFailure(
                for: provider,
                message: provider.missingClipboardCredentialMessage
            )
            return false
        }
        inference.setActiveAIProvider(AIProviderSelection(cloudProvider: provider))
        let didSave = inference.setAPIKey(clipboardValue, for: provider)
        guard didSave else { return false }
        _ = await inference.validateAPIKey(for: provider)
        return true
    }

    static func loadGoogleOAuthClientConfigData() -> Data? {
        guard let rawValue = Keychain.load(for: googleOAuthClientConfigKeychainKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return nil
        }
        guard let data = Data(base64Encoded: rawValue) else {
            logger.error("Stored Google OAuth client configuration could not be decoded from base64.")
            return nil
        }
        return data
    }

    static func loadGoogleOAuthClientFilename() -> String {
        UserDefaults.standard.string(forKey: googleOAuthClientFilenameDefaultsKey) ?? ""
    }

    static func loadGoogleOAuthProjectIDDraft() -> String {
        UserDefaults.standard.string(forKey: googleOAuthProjectIDDraftDefaultsKey) ?? ""
    }

    @discardableResult
    static func persistGoogleOAuthClientConfig(data: Data, filename: String) -> Bool {
        guard Keychain.save(data.base64EncodedString(), for: googleOAuthClientConfigKeychainKey) else {
            logger.error("Failed to save Google OAuth client configuration to Keychain.")
            return false
        }
        UserDefaults.standard.set(filename, forKey: googleOAuthClientFilenameDefaultsKey)
        return true
    }

    static func clearGoogleOAuthClientConfig() {
        Keychain.delete(for: googleOAuthClientConfigKeychainKey)
        UserDefaults.standard.removeObject(forKey: googleOAuthClientFilenameDefaultsKey)
    }

    static func persistGoogleOAuthProjectIDDraft(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: googleOAuthProjectIDDraftDefaultsKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: googleOAuthProjectIDDraftDefaultsKey)
        }
    }

    static func storedGoogleOAuthClientConfiguration(
        projectIDOverride: String? = nil
    ) -> GoogleOAuthClientConfiguration? {
        guard let configData = loadGoogleOAuthClientConfigData() else {
            return nil
        }
        let parsedConfiguration: GoogleOAuthClientConfiguration
        do {
            parsedConfiguration = try GoogleOAuthClientConfiguration.parse(from: configData)
        } catch {
            let message = CloudProviderSetupDiagnostics.logMessage(
                for: error,
                fallback: "Failed to parse stored Google OAuth client configuration"
            )
            logger.error("\(message, privacy: .public)")
            return nil
        }
        let resolvedProjectID = normalizedDraft(projectIDOverride)
            ?? normalizedDraft(loadGoogleOAuthProjectIDDraft())
            ?? normalizedDraft(parsedConfiguration.projectID)
        guard let resolvedProjectID else { return nil }
        return GoogleOAuthClientConfiguration(
            clientID: parsedConfiguration.clientID,
            clientSecret: parsedConfiguration.clientSecret,
            projectID: resolvedProjectID
        )
    }

    static func hasStoredGoogleOAuthClientConfig() -> Bool {
        loadGoogleOAuthClientConfigData() != nil
    }

    static func hasStoredGoogleOAuthProjectID() -> Bool {
        normalizedDraft(loadGoogleOAuthProjectIDDraft()) != nil
    }

    private static func normalizedDraft(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct CloudProviderAccountConnectionRow: View {
    let summary: CloudProviderAccountConnectionSummary
    let theme: EpistemosTheme
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            indicator
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(titleColor)
                Text(summary.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var indicator: some View {
        switch summary.state {
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .connected, .pendingVerification, .failure, .disconnected:
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
        }
    }

    private var indicatorColor: Color {
        switch summary.state {
        case .connected:
            theme.success
        case .pendingVerification:
            theme.resolved.accent.color
        case .failure:
            theme.warning
        case .disconnected:
            Color.secondary
        case .checking:
            theme.resolved.accent.color
        }
    }

    private var titleColor: Color {
        switch summary.state {
        case .connected:
            theme.success
        case .failure:
            theme.warning
        case .pendingVerification, .checking, .disconnected:
            Color.primary
        }
    }
}

struct CloudProviderGuidanceRow: View {
    let text: String
    let theme: EpistemosTheme
    var systemImage = "info.circle.fill"
    var tint: Color? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint ?? theme.resolved.accent.color)
                .frame(width: 14, height: 14)

            Text(text)
                .font(.caption)
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct OpenAIDeviceAuthorizationSheet: View {
    let authorization: OpenAIDeviceAuthorization
    let onDismiss: () -> Void

    @State private var copiedCode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("OpenAI Verification Code")
                .font(.title3.weight(.semibold))

            Text("Use this code on OpenAI's verification page. Epistemos keeps checking automatically while you finish the browser step.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(authorization.userCode)
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .tracking(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )

            HStack(spacing: 8) {
                Button(copiedCode ? "Copied" : "Copy Code") {
                    copyDeviceCode()
                }
                .buttonStyle(.borderedProminent)

                Button("Open Verification Page") {
                    NSWorkspace.shared.open(authorization.verificationURL)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(minWidth: 460)
    }

    private func copyDeviceCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(authorization.userCode, forType: .string)
        copiedCode = true
    }
}
