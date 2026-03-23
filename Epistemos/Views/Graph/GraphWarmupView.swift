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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
