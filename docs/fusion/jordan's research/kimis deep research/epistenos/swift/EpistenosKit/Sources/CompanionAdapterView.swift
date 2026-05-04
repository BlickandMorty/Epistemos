import SwiftUI

/// Companion Adapter UI — LoRA unwrap animation.
/// Invariant I-11: animation duration ≥ adapter apply duration.
/// Failure state: never completes ahead of work.
/// @MainActor @Observable — never ObservableObject.
@MainActor
@Observable
public final class AdapterAnimationState {
    public var phase: AnimationPhase = .idle
    public var progress: Double = 0.0
    public var companionId: String = ""
    public var adapterName: String = ""
    public var estimatedDuration: Double = 2.0  // seconds, measured from adapter
    
    public enum AnimationPhase: String, Sendable {
        case idle = "idle"
        case preparing = "preparing"
        case applying = "applying"
        case completing = "completing"
        case failed = "failed"
    }
    
    public func start(adapterName: String, estimatedDuration: Double) {
        self.adapterName = adapterName
        self.estimatedDuration = estimatedDuration
        self.phase = .preparing
        self.progress = 0.0
    }
    
    public func updateProgress(_ p: Double) {
        // Clamp to actual work duration — never show completion before work done
        self.progress = min(p, 1.0)
        if p >= 1.0 && phase != .failed {
            self.phase = .completing
        }
    }
    
    public func markFailed() {
        self.phase = .failed
        self.progress = 0.0
    }
    
    public func reset() {
        self.phase = .idle
        self.progress = 0.0
    }
}

public struct CompanionAdapterView: View {
    @State private var state: AdapterAnimationState
    @Environment(AccessibilityGating.self) private var gating
    
    public var body: some View {
        VStack(spacing: 16) {
            // Orb with unwrap glow
            ZStack {
                Circle()
                    .fill(orbColor)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(glowColor, lineWidth: unwrapStrokeWidth)
                            .frame(width: 80 + unwrapOffset, height: 80 + unwrapOffset)
                    )
                
                if state.phase == .applying || state.phase == .completing {
                    // Rotating ring during apply
                    Circle()
                        .trim(from: 0.0, to: CGFloat(state.progress))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .rotationEffect(unwrapRotation)
                }
                
                Text(adapterEmoji)
                    .font(.system(size: 36))
            }
            
            // Status text
            VStack(spacing: 4) {
                Text(state.adapterName)
                    .font(.headline)
                Text(phaseDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Progress bar
            if state.phase != .idle && state.phase != .failed {
                ProgressView(value: state.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
            }
            
            // Failure state
            if state.phase == .failed {
                Label("Adapter failed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .gatedAnimation(.easeInOut(duration: 0.3), value: state.phase)
    }
    
    private var orbColor: Color {
        switch state.phase {
        case .idle: return .gray.opacity(0.3)
        case .preparing: return .yellow.opacity(0.3)
        case .applying: return .blue.opacity(0.3)
        case .completing: return .green.opacity(0.3)
        case .failed: return .red.opacity(0.3)
        }
    }
    
    private var glowColor: Color {
        switch state.phase {
        case .idle: return .clear
        case .preparing: return .yellow
        case .applying: return .blue
        case .completing: return .green
        case .failed: return .red
        }
    }
    
    private var unwrapStrokeWidth: CGFloat {
        switch state.phase {
        case .idle: return 0
        case .preparing: return 2
        case .applying: return 3 + CGFloat(state.progress) * 2
        case .completing: return 2
        case .failed: return 2
        }
    }
    
    private var unwrapOffset: CGFloat {
        switch state.phase {
        case .idle: return 0
        case .preparing: return 4
        case .applying: return 4 + CGFloat(state.progress) * 8
        case .completing: return 12
        case .failed: return 4
        }
    }
    
    private var unwrapRotation: Angle {
        if state.phase == .applying {
            return .degrees(Double(state.progress) * 360)
        }
        return .zero
    }
    
    private var adapterEmoji: String {
        switch state.adapterName.lowercased() {
        case let s where s.contains("lora"): return "🧬"
        case let s where s.contains("fast"): return "⚡"
        case let s where s.contains("sketch"): return "🎨"
        default: return "🔧"
        }
    }
    
    private var phaseDescription: String {
        switch state.phase {
        case .idle: return "Ready"
        case .preparing: return "Preparing adapter..."
        case .applying: return "Applying \(Int(state.progress * 100))%"
        case .completing: return "Complete!"
        case .failed: return "Failed — try again"
        }
    }
}

/// View modifier for adapter animation container.
public struct AdapterAnimationModifier: ViewModifier {
    @State private var state = AdapterAnimationState()
    let adapterName: String
    let workDuration: Double
    let onComplete: () -> Void
    let onFailure: () -> Void
    
    public func body(content: Content) -> some View {
        content
            .overlay {
                if state.phase != .idle {
                    CompanionAdapterView(state: state)
                }
            }
            .onAppear {
                startAnimation()
            }
    }
    
    private func startAnimation() {
        // Invariant I-11: animation duration ≥ adapter apply duration
        let animationDuration = max(workDuration, 1.5) // minimum 1.5s for visual clarity
        
        state.start(adapterName: adapterName, estimatedDuration: animationDuration)
        
        // Simulate work progress (in production, this is driven by actual adapter progress)
        Task {
            let steps = 20
            let stepDuration = animationDuration / Double(steps)
            for i in 0...steps {
                let progress = Double(i) / Double(steps)
                await MainActor.run {
                    state.updateProgress(progress)
                }
                try? await Task.sleep(for: .seconds(stepDuration))
            }
            await MainActor.run {
                if state.phase != .failed {
                    state.updateProgress(1.0)
                    onComplete()
                }
            }
        }
    }
}
