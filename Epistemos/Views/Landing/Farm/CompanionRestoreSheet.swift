import SwiftUI

/// Trash + restore sheet. Shows every archived companion and offers
/// per-row Restore (Trivial — no Sovereign Gate) and Purge Forever
/// (Destructive — Sovereign Gate every-time, no grace) per doctrine
/// §A.7 action class matrix.
struct CompanionRestoreSheet: View {
    @Bindable var companionState: CompanionState
    let sovereignGate: SovereignGate
    var theme: EpistemosTheme
    var onDismiss: () -> Void = {}

    @State private var purgingID: String? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.18)
            if companionState.trashed.isEmpty {
                emptyTrash
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(companionState.trashed) { entry in
                            row(entry)
                            Divider().opacity(0.10)
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.resolved.accent.color.opacity(0.85))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
            }
            Divider().opacity(0.18)
            footer
        }
        .frame(width: 520)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.resolved.accent.color.opacity(0.20), lineWidth: 0.6)
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.resolved.accent.color)
            Text("Trash")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
            Text("· \(companionState.trashed.count) companion\(companionState.trashed.count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textTertiary.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func row(_ entry: CompanionRosterEntry) -> some View {
        HStack(spacing: 14) {
            CompanionView(entry: entry, size: 56)
                .opacity(0.7)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                if let archivedAt = entry.archivedAt {
                    Text("Archived \(archivedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
            Button {
                companionState.restore(entry.id)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward.circle")
                    Text("Restore")
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(theme.resolved.accent.color.opacity(0.10)))
                .foregroundStyle(theme.resolved.accent.color)
            }
            .buttonStyle(.plain)

            Button {
                Task { await purge(entry) }
            } label: {
                HStack(spacing: 4) {
                    if purgingID == entry.id {
                        ProgressView().controlSize(.small).scaleEffect(0.7)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text("Purge")
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.red.opacity(0.12)))
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .disabled(purgingID != nil)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private var emptyTrash: some View {
        VStack(spacing: 6) {
            Image(systemName: "trash")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(theme.textTertiary.opacity(0.4))
                .padding(.bottom, 4)
            Text("Trash is empty")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            Button("Done") { onDismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    @MainActor
    private func purge(_ entry: CompanionRosterEntry) async {
        purgingID = entry.id
        errorMessage = nil
        defer { purgingID = nil }

        // Destructive action — every-time biometric, NO grace, per
        // doctrine §A.7. Routes through the canonical SovereignGate.
        let outcome = await sovereignGate.confirm(
            .deviceOwnerAuthentication,
            reason: "Permanently delete companion '\(entry.name)'"
        )

        switch outcome {
        case .allowed:
            companionState.purge(entry.id)
        case .denied(let reason):
            switch reason {
            case .missingReason:
                errorMessage = "Sovereign Gate: missing reason."
            case .authenticationFailed:
                errorMessage = "Authentication failed; companion not purged."
            }
        }
    }
}
