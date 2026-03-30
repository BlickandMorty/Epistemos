import SwiftUI
import MetalKit
import os

private let glowLog = Logger(subsystem: "com.epistemos", category: "ThinkingGlow")

// MARK: - Metal Glow Uniforms

/// Matches ThinkingGlowUniforms in ThinkingGlow.metal.
struct ThinkingGlowUniforms {
    var time: Float
    var intensity: Float
    var center: SIMD2<Float>
    var glowColor: SIMD4<Float>
    var resolution: SIMD2<Float>
}

// MARK: - ThinkingGlowView (SwiftUI wrapper)

/// Animated Metal glow overlay shown during agent thinking/reasoning.
/// Uses TimelineView for smooth animation + Canvas fallback if Metal unavailable.
struct ThinkingGlowView: View {
    let isThinking: Bool
    var glowColor: Color = .blue

    @State private var animationStart = Date.now
    @State private var intensity: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(animationStart)
            Canvas { context, size in
                drawGlow(context: context, size: size, elapsed: elapsed)
            }
            .allowsHitTesting(false)
        }
        .opacity(intensity)
        .onChange(of: isThinking, initial: true) { _, thinking in
            withAnimation(.easeInOut(duration: 0.4)) {
                intensity = thinking ? 1.0 : 0.0
            }
            if thinking {
                animationStart = .now
            }
        }
    }

    /// CoreGraphics fallback glow (used when Metal shader isn't loaded).
    /// Produces the same visual effect as the Metal shader.
    private func drawGlow(context: GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let breathe = 0.5 + 0.5 * sin(elapsed * .pi)
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.3)

        let innerRadius = min(size.width, size.height) * (0.15 + 0.05 * breathe)
        let outerRadius = min(size.width, size.height) * (0.5 + 0.15 * breathe)

        // Outer halo
        let outerGradient = Gradient(colors: [
            glowColor.opacity(0.15 * breathe),
            glowColor.opacity(0.0),
        ])
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - outerRadius,
                y: center.y - outerRadius,
                width: outerRadius * 2,
                height: outerRadius * 2
            )),
            with: .radialGradient(
                outerGradient,
                center: center,
                startRadius: innerRadius,
                endRadius: outerRadius
            )
        )

        // Inner core
        let innerGradient = Gradient(colors: [
            glowColor.opacity(0.4 * breathe),
            glowColor.opacity(0.08),
        ])
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - innerRadius,
                y: center.y - innerRadius,
                width: innerRadius * 2,
                height: innerRadius * 2
            )),
            with: .radialGradient(
                innerGradient,
                center: center,
                startRadius: 0,
                endRadius: innerRadius
            )
        )
    }
}

// MARK: - Metal Pipeline (for advanced usage)

/// Manages the Metal render pipeline for ThinkingGlow.
/// Can be used by MetalGraphView or a standalone MTKView.
final class ThinkingGlowPipeline {
    let device: MTLDevice
    let pipelineState: MTLRenderPipelineState

    init?(device: MTLDevice) {
        self.device = device

        guard let library = device.makeDefaultLibrary() else {
            glowLog.warning("No default Metal library found")
            return nil
        }

        guard let vertexFn = library.makeFunction(name: "thinking_glow_vertex"),
              let fragmentFn = library.makeFunction(name: "thinking_glow_fragment") else {
            glowLog.warning("ThinkingGlow shader functions not found")
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFn
        descriptor.fragmentFunction = fragmentFn
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            glowLog.error("Failed to create ThinkingGlow pipeline: \(error)")
            return nil
        }
    }

    /// Encode a glow draw call into the given render encoder.
    func encode(
        encoder: MTLRenderCommandEncoder,
        time: Float,
        intensity: Float,
        viewportSize: CGSize
    ) {
        var uniforms = ThinkingGlowUniforms(
            time: time,
            intensity: intensity,
            center: SIMD2<Float>(0.5, 0.3),
            glowColor: SIMD4<Float>(0.2, 0.5, 1.0, 1.0), // Blue glow
            resolution: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ThinkingGlowUniforms>.size, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
}

// MARK: - Preview

#Preview("Thinking Glow") {
    ZStack {
        Color.black
        ThinkingGlowView(isThinking: true, glowColor: .blue)
    }
    .frame(width: 400, height: 300)
}
