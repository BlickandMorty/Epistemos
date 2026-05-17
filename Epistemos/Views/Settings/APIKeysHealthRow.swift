import SwiftUI

// MARK: - APIKeysHealthRow
//
// ISSUE-2026-05-10-002 follow-up: read-only diagnostic that shows
// which cloud providers have account or API-key access stored in Keychain.
//
// Why this exists: when a user reports "agents don't work / not
// connected to any provider," the most common cause is that no cloud
// access has been connected. The source-level diagnosis in
// docs/APP_ISSUES_AUTO_FIX.md is that AppBootstrap.withScopedAgentCoreEnvironment
// looks up each provider's Keychain-backed account/API-key entries and
// exports scoped credentials around the Rust agent call. If Keychain
// returns nil for every provider, cloud agents fail auth on first HTTP
// call. The user has no easy way to verify access without scrolling
// through each provider page in Settings.
//
// This row surfaces the state at a glance: per-provider account session
// and/or legacy API-key presence. The actual credential values are never
// displayed.
//
// Read-only. Tapping a row should ideally jump to the provider's
// Settings page; that's a separate UX wiring step.

@MainActor
public struct APIKeysHealthRow: View {

    private struct Probe: Identifiable, Sendable {
        let id: String
        let displayName: String
        let hasAPIKey: Bool
        let hasOAuthSession: Bool

        var hasAccess: Bool {
            hasAPIKey || hasOAuthSession
        }

        var statusText: String {
            switch (hasOAuthSession, hasAPIKey) {
            case (true, true):
                "Account session + API key saved"
            case (true, false):
                "Account session saved"
            case (false, true):
                "API key saved"
            case (false, false):
                "No saved access"
            }
        }
    }

    @State private var probes: [Probe] = []

    @Environment(InferenceState.self) private var inference

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let connected = probes.filter(\.hasAccess)
            if !connected.isEmpty {
                ForEach(connected) { row(probe: $0) }
            } else {
                emptyState
            }
        }
        .onAppear { refresh() }
    }

    /// Re-read every provider's Keychain state. Cheap — nil checks on
    /// account sessions and API keys.
    public func refresh() {
        probes = CloudModelProvider.allCases.map { provider in
            Probe(
                id: provider.rawValue,
                displayName: provider.displayName,
                hasAPIKey: inference.apiKey(for: provider)?.isEmpty == false,
                hasOAuthSession: inference.oauthCredential(for: provider) != nil
            )
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.slash")
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("No provider access stored")
                    .font(.system(size: 13, weight: .medium))
                Text("Agents need at least one cloud account session or API key. Open a provider section in Settings to connect one.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func row(probe: Probe) -> some View {
        HStack(spacing: 10) {
            Image(systemName: probe.hasAccess ? "key.fill" : "key.slash")
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(probe.displayName)
                    .font(.system(size: 13, weight: .medium))
                Text(probe.statusText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: probe.hasAccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(probe.hasAccess ? Color.green : Color.orange)
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(probe.displayName): \(probe.statusText)")
    }
}
