import SwiftUI

// MARK: - APIKeysHealthRow
//
// ISSUE-2026-05-10-002 follow-up: read-only diagnostic that shows
// which cloud providers have an API key stored in Keychain.
//
// Why this exists: when a user reports "agents don't work / not
// connected to any provider," the most common cause is that no API
// key has been entered. The source-level diagnosis in
// docs/APP_ISSUES_AUTO_FIX.md is that AppBootstrap.withScopedAgentCoreEnvironment
// looks up each provider's Keychain entry and exports it as an env
// var around the Rust agent call — if the Keychain returns nil for
// every provider, the Rust providers see empty env vars and fail
// auth on first HTTP call. The user has no easy way to verify
// which providers have keys without scrolling through each provider
// page in Settings.
//
// This row surfaces the state at a glance: per-provider ✓ if a key
// is stored, ⚠ if not. The actual key values are never displayed.
//
// Read-only. Tapping a row should ideally jump to the provider's
// Settings page; that's a separate UX wiring step.

@MainActor
public struct APIKeysHealthRow: View {

    private struct Probe: Identifiable, Sendable {
        let id: String
        let displayName: String
        let hasKey: Bool
    }

    @State private var probes: [Probe] = []

    @Environment(InferenceState.self) private var inference

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if probes.contains(where: { $0.hasKey }) {
                ForEach(probes) { row(probe: $0) }
            } else {
                emptyState
            }
        }
        .onAppear { refresh() }
    }

    /// Re-read every provider's Keychain state. Cheap — just a
    /// nil check on `apiKey(for:)`.
    public func refresh() {
        probes = CloudModelProvider.allCases.map { provider in
            Probe(
                id: provider.rawValue,
                displayName: provider.displayName,
                hasKey: inference.apiKey(for: provider)?.isEmpty == false
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
                Text("No provider keys stored")
                    .font(.system(size: 13, weight: .medium))
                Text("Agents need at least one cloud provider's API key. Open the provider section in Settings to add one.")
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
            Image(systemName: probe.hasKey ? "key.fill" : "key.slash")
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(probe.displayName)
                    .font(.system(size: 13, weight: .medium))
                Text(probe.hasKey ? "API key stored" : "No API key — agents using this provider will fail auth")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: probe.hasKey ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(probe.hasKey ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.orange))
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(probe.displayName): \(probe.hasKey ? "API key stored" : "no API key")")
    }
}
