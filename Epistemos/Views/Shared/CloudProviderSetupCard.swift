import AppKit
import os
import SwiftUI

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
            logger.error("Failed to parse stored Google OAuth client configuration: \(error.localizedDescription, privacy: .public)")
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

struct CloudProviderSetupCard: View {
    @Environment(UIState.self) private var ui
    @Environment(InferenceState.self) private var inference

    let provider: CloudModelProvider
    var title: String? = nil
    var message: String? = nil
    var footer: String? = nil
    var compact = false
    var showsPasteAndSave = true
    var showsOpenSettings = true
    var showsDismissTip = true

    @State private var isSavingClipboardKey = false
    @State private var isRunningAccountAction = false
    @State private var showsManualSetup = false
    @State private var openAIDeviceAuthorization: OpenAIDeviceAuthorization?

    private var theme: EpistemosTheme { ui.theme }
    private var validationState: CloudProviderValidationState { inference.cloudValidationState(for: provider) }
    private var canPasteAndSave: Bool { CloudProviderSetupAutomation.clipboardKeyCandidate() != nil }
    private var usesManualPrimarySetup: Bool { !provider.supportsAccountConnection }
    private var oauthCredential: CloudProviderOAuthCredential? { inference.oauthCredential(for: provider) }
    private var hasSavedAPIKey: Bool {
        guard let apiKey = inference.apiKey(for: provider)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !apiKey.isEmpty
    }
    private var accountConnectionSummary: CloudProviderAccountConnectionSummary? {
        provider.accountConnectionSummary(
            oauthCredential: oauthCredential,
            hasSavedAPIKey: hasSavedAPIKey,
            validationState: validationState
        )
    }
    private var hasConfiguredAccess: Bool {
        oauthCredential != nil || hasSavedAPIKey
    }
    private var inlineGuidanceText: String? {
        if provider == .google, !hasSavedAPIKey, oauthCredential == nil {
            if !CloudProviderSetupAutomation.hasStoredGoogleOAuthClientConfig() {
                return "Open Inference Settings to choose the Google OAuth client JSON you downloaded from Google Cloud Console for a Desktop app before connecting your account."
            }
            if CloudProviderSetupAutomation.storedGoogleOAuthClientConfiguration() == nil {
                return "Open Inference Settings to enter the Google Cloud project ID for the same Gemini-enabled project before connecting your account."
            }
        }
        if let providerGuidance = provider.accountGuidanceText(validationState: validationState) {
            return providerGuidance
        }
        if !validationState.isVerified {
            return "Verify live access before making this provider active."
        }
        return nil
    }

    private var resolvedTitle: String {
        if let title { return title }
        if compact {
            return provider.accountSetupTitle
        }
        return inference.shouldShowCloudSetupHint ? "Quick Setup" : "Setup \(provider.displayName)"
    }

    private var resolvedMessage: String {
        if let message { return message }
        if compact {
            return provider.accountSetupHelpText
        }
        return provider.automationHintText
    }

    private var resolvedFooter: String? {
        if let footer { return footer }
        guard inference.shouldShowCloudSetupHint else { return nil }
        if usesManualPrimarySetup {
            return "This provider uses the direct API route in Epistemos today. Open the provider portal, create a key, then use Paste + Save."
        }
        return compact
            ? "Account access stays primary here. Legacy API keys only show up if you expand Legacy API Key."
            : "Use provider accounts first. Legacy API keys only remain for explicit fallback and recovery."
    }

    private var manualSetupSubtitle: String {
        switch validationState {
        case .valid:
            "Saved and validated"
        case .unchecked:
            "Saved locally"
        case .checking:
            "Checking saved access"
        case .invalid:
            "Needs attention"
        case .missing:
            canPasteAndSave
                ? "Clipboard ready"
                : (usesManualPrimarySetup ? "Create a key to continue" : "Use only if browser setup needs a key")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: inference.shouldShowCloudSetupHint ? "wand.and.stars" : "person.crop.circle.badge.checkmark")
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
                    .frame(width: 14, height: 14)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(resolvedTitle)
                        .font(.system(size: compact ? 11.5 : 12, weight: .semibold))
                    Text(resolvedMessage)
                        .font(.system(size: compact ? 10 : 10.5))
                        .foregroundStyle(theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let resolvedFooter {
                        Text(resolvedFooter)
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if compact {
                if usesManualPrimarySetup {
                    directKeyPrimarySetup
                } else {
                    Button(provider.accountActionTitle) {
                        Task { await performPrimaryAccountAction() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isRunningAccountAction)

                    accountRecoverySection

                    DisclosureGroup(
                        isExpanded: $showsManualSetup,
                        content: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(provider.automationHintText)
                                    .font(.caption)
                                    .foregroundStyle(theme.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: 6) {
                                    if let url = provider.documentationURL {
                                        Button(provider.documentationActionTitle) {
                                            NSWorkspace.shared.open(url)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }

                                    if showsOpenSettings {
                                        Button("Open Inference Settings") {
                                            openInferenceSettings()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }

                                HStack(spacing: 6) {
                                    if showsPasteAndSave {
                                        Button("Paste + Save") {
                                            Task { await pasteAndSaveClipboardKey() }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        .disabled(isSavingClipboardKey || !canPasteAndSave)
                                    }

                                    if showsDismissTip && inference.shouldShowCloudSetupHint {
                                        Button("Dismiss Tip") {
                                            inference.markCloudSetupHintShown()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }

                                validationRow
                            }
                            .padding(.top, 4)
                        },
                        label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.manualCredentialTitle)
                                    .font(.system(size: 11.5, weight: .semibold))
                                Text(manualSetupSubtitle)
                                    .font(.system(size: 10))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                    )
                }
            } else {
                if usesManualPrimarySetup {
                    directKeyPrimarySetup
                } else {
                    HStack(spacing: 6) {
                        Button(provider.accountActionTitle) {
                            Task { await performPrimaryAccountAction() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isRunningAccountAction)

                        if hasConfiguredAccess {
                            Button(validationState.isVerified ? "Re-check Access" : "Check Access") {
                                Task { _ = await inference.validateCloudAccess(for: provider) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(validationState.isChecking || isRunningAccountAction)
                        }

                        if let url = provider.documentationURL {
                            Button(provider.documentationActionTitle) {
                                NSWorkspace.shared.open(url)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    HStack(spacing: 6) {
                        if showsPasteAndSave {
                            Button("Paste + Save") {
                                Task { await pasteAndSaveClipboardKey() }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(isSavingClipboardKey || !canPasteAndSave)
                        }

                        if showsOpenSettings {
                            Button("Open Inference Settings") {
                                openInferenceSettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if showsDismissTip && inference.shouldShowCloudSetupHint {
                            Button("Dismiss Tip") {
                                inference.markCloudSetupHintShown()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    accountRecoverySection
                }
            }
        }
        .padding(compact ? 10 : 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.card.opacity(theme.isDark ? 0.82 : 0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.border.opacity(theme.isDark ? 0.6 : 0.75), lineWidth: 0.8)
        )
        .sheet(item: $openAIDeviceAuthorization) { authorization in
            OpenAIDeviceAuthorizationSheet(
                authorization: authorization,
                onDismiss: { openAIDeviceAuthorization = nil }
            )
        }
    }

    private var validationRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: validationState.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor(for: validationState))
                .frame(width: 14, height: 14)
            Text(validationState.statusText)
                .font(.caption)
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var accountRecoverySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let accountConnectionSummary {
                CloudProviderAccountConnectionRow(
                    summary: accountConnectionSummary,
                    theme: theme
                )
            }

            validationRow

            if let inlineGuidanceText {
                CloudProviderGuidanceRow(
                    text: inlineGuidanceText,
                    theme: theme
                )
            }

            if hasConfiguredAccess {
                Button(validationState.isVerified ? "Re-check Access" : "Check Access") {
                    Task { _ = await inference.validateCloudAccess(for: provider) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(validationState.isChecking || isRunningAccountAction)
            }

            if provider == .openAI, case .invalid = validationState {
                Button("Retry OpenAI Sign In") {
                    Task { await performPrimaryAccountAction() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isRunningAccountAction)
            }

            if provider == .anthropic, case .invalid = validationState {
                Button("Retry Claude Code Import") {
                    Task { await performPrimaryAccountAction() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isRunningAccountAction)
            }

            if provider == .google, case .invalid = validationState {
                Button("Retry Google OAuth") {
                    openInferenceSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isRunningAccountAction)
            }
        }
    }

    @ViewBuilder
    private var directKeyPrimarySetup: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 6) {
                if let url = provider.credentialManagementURL {
                    Button(provider.accountActionTitle) {
                        openProviderURL(url)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                if let url = provider.documentationURL {
                    Button(provider.documentationActionTitle) {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack(spacing: 6) {
                if showsPasteAndSave {
                    Button("Paste + Save") {
                        Task { await pasteAndSaveClipboardKey() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isSavingClipboardKey || !canPasteAndSave)
                }

                if showsOpenSettings {
                    Button("Open Inference Settings") {
                        openInferenceSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if showsDismissTip && inference.shouldShowCloudSetupHint {
                    Button("Dismiss Tip") {
                        inference.markCloudSetupHintShown()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            validationRow
        }
    }

    private func openProviderURL(_ url: URL) {
        inference.setActiveAIProvider(AIProviderSelection(cloudProvider: provider))
        NSWorkspace.shared.open(url)
    }

    private func openInferenceSettings() {
        UtilityWindowManager.shared.show(.settings)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func pasteAndSaveClipboardKey() async {
        guard !isSavingClipboardKey else { return }
        isSavingClipboardKey = true
        defer { isSavingClipboardKey = false }

        let didSave = await CloudProviderSetupAutomation.pasteAndSave(
            provider: provider,
            inference: inference
        )
        if didSave && inference.shouldShowCloudSetupHint {
            inference.markCloudSetupHintShown()
        }
    }

    private func performPrimaryAccountAction() async {
        guard !isRunningAccountAction else { return }
        isRunningAccountAction = true
        defer { isRunningAccountAction = false }

        inference.setActiveAIProvider(AIProviderSelection(cloudProvider: provider))
        let result: ConnectionTestResult
        switch provider {
        case .openAI:
            openAIDeviceAuthorization = nil
            result = await inference.signInToOpenAI { authorization in
                openAIDeviceAuthorization = authorization
            }
            openAIDeviceAuthorization = nil
        case .anthropic:
            result = await inference.importAnthropicAccount()
        case .google:
            if let configuration = CloudProviderSetupAutomation.storedGoogleOAuthClientConfiguration() {
                result = await inference.signInToGoogle(configuration: configuration)
            } else {
                let message: String
                if !CloudProviderSetupAutomation.hasStoredGoogleOAuthClientConfig() {
                    message = "Choose a Google Desktop OAuth client JSON file in Inference Settings before connecting Google OAuth."
                } else {
                    message = "Enter a Google Cloud project ID in Inference Settings before connecting Google OAuth."
                }
                result = inference.recordCloudProviderValidationFailure(
                    for: .google,
                    message: message
                )
                openInferenceSettings()
            }
        case .zai, .kimi, .minimax, .deepseek:
            if let url = provider.credentialManagementURL {
                openProviderURL(url)
            }
            return
        }

        if result.success && inference.shouldShowCloudSetupHint {
            inference.markCloudSetupHintShown()
        }
    }

    private func statusColor(for validationState: CloudProviderValidationState) -> Color {
        switch validationState.tintColor {
        case .accent:
            theme.resolved.accent.color
        case .secondary:
            .secondary
        case .success:
            theme.success
        case .warning:
            theme.warning
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
