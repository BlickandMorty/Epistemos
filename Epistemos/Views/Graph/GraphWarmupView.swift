import SwiftUI

/// Lightweight loading indicator shown while the Metal engine compiles shaders
/// on first launch. Fades out once `GraphState.isWarmed` becomes true.
struct GraphWarmupView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Warming up")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        // 2026-05-20 single-blur policy: the graph window already carries
        // one NSVisualEffectView (HologramOverlay.swift). This warmup
        // indicator sits on top — primary tint reads the existing blur
        // through without stacking a `.ultraThinMaterial` kernel.
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
        )
    }
}
