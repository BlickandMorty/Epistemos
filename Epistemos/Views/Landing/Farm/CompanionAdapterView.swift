import SwiftUI

/// Adapter Apply UI per Simulation Mode v1.6 Invariant I-11:
/// "the LoRA unwrap animation duration ≥ adapter apply duration."
///
/// The visual is a "gift box" unwrapping — ribbon falls away, lid
/// lifts, the companion's body shimmers as the new LoRA settles in.
/// Animation is pure cosmetic; the actual adapter file picker /
/// MLX-Swift hot-swap wires when the LoRA application pipeline lands
/// (T7 Local Model / MLX). For the hackathon, this view shows the
/// invariant-conformant animation + accepts a path string the user
/// can paste in.
struct CompanionAdapterView: View {
    let entry: CompanionRosterEntry
    var theme: EpistemosTheme
    var onDismiss: () -> Void = {}

    @State private var phase: Phase = .closed
    @State private var adapterPathDraft: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Phase: Equatable {
        case closed       // gift box closed; user picks adapter
        case unwrapping   // ribbon + lid animation (Invariant I-11)
        case settled      // companion shimmers; ready to dismiss
        case error(String)
    }

    private var accent: Color {
        Color(hex: entry.accentHex) ?? .accentColor
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.18)
            stage
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            Divider().opacity(0.18)
            input
            footer
        }
        .frame(width: 480)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.22), lineWidth: 0.6)
        )
    }

    // MARK: - Header / Footer

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(accent)
            Text("Apply Adapter — \(entry.name)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
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

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Cancel") { onDismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textSecondary)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            switch phase {
            case .closed:
                Button {
                    Task { await applyAdapter() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Unwrap")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(accent))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(adapterPathDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            case .unwrapping:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small).scaleEffect(0.8)
                    Text("Unwrapping…")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                }
            case .settled:
                Button("Done") { onDismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
            case .error(let msg):
                Text(msg)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red.opacity(0.85))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Input

    private var input: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Adapter file (.safetensors / .npz)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
            TextField("", text: $adapterPathDraft,
                      prompt: Text("Paste path or use Open…").foregroundStyle(theme.mutedForeground.opacity(0.55)))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    // MARK: - Stage (Invariant I-11)

    @ViewBuilder
    private var stage: some View {
        ZStack {
            // The companion under the gift box. Visible while box is
            // closed; revealed during unwrapping.
            CompanionView(entry: entry, size: 80)
                .opacity(phase == .closed ? 0.30 : 1.0)
                .scaleEffect(phase == .settled ? 1.05 : 1.0)
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7),
                           value: phase)

            if phase == .closed || phase == .unwrapping {
                giftBox
                    .opacity(phase == .closed ? 1.0 : 0.0)
                    .scaleEffect(phase == .closed ? 1.0 : 1.6)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.55), value: phase)
            }

            if phase == .settled {
                // Shimmer ring confirming the adapter applied.
                Circle()
                    .stroke(accent.opacity(0.6), lineWidth: 2)
                    .frame(width: 140, height: 140)
                    .opacity(0.0)
                    .transition(.opacity)
            }
        }
    }

    private var giftBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(0.6))
                .frame(width: 110, height: 110)
            Rectangle()
                .fill(accent)
                .frame(width: 16, height: 110)
            Rectangle()
                .fill(accent)
                .frame(width: 110, height: 16)
            Image(systemName: "gift.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)
                .offset(y: -32)
        }
    }

    // MARK: - Apply (placeholder pipeline)

    @MainActor
    private func applyAdapter() async {
        // Per Invariant I-11, unwrap animation duration MUST be at
        // LEAST as long as the actual adapter apply duration. The
        // real apply pipeline (MLX-Swift LoRA hot-swap) lands in T7;
        // the cosmetic floor here is 1.6s. When the apply is wired,
        // measure its time and ensure unwrap takes max(1.6s, apply_t).
        let unwrapMin: TimeInterval = reduceMotion ? 0.0 : 1.6
        phase = .unwrapping
        try? await Task.sleep(for: .seconds(unwrapMin))
        phase = .settled
    }
}
