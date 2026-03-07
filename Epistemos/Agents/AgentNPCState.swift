import Foundation
import simd

// MARK: - AgentNPCState
// Tracks the visual state of an agent NPC in the knowledge graph.
// Drives animation: position, glow, trail, and attachment.

@MainActor @Observable
final class AgentNPCState {

    // MARK: - Animation State

    enum AnimState: Equatable, Sendable {
        case idle
        case moving(progress: Float)
        case attached(angle: Float)
        case working(pulsePhase: Float)
    }

    // MARK: - Properties

    let agentId: AgentID
    var position: SIMD3<Float> = .zero
    var targetNodeId: String?
    var animState: AnimState = .idle
    var glowIntensity: Float = 0.3
    private(set) var trailPoints: [SIMD3<Float>] = []

    private let maxTrailLength = 20

    // MARK: - Init

    init(agentId: AgentID) {
        self.agentId = agentId
    }

    // MARK: - Glow Color

    nonisolated var glowColor: SIMD4<Float> {
        switch agentId {
        case .triage:    SIMD4<Float>(0.95, 0.95, 0.95, 1.0)  // white
        case .librarian: SIMD4<Float>(0.30, 0.50, 0.95, 1.0)  // blue
        case .writer:    SIMD4<Float>(0.20, 0.78, 0.35, 1.0)  // green
        case .builder:   SIMD4<Float>(0.95, 0.60, 0.10, 1.0)  // orange
        }
    }

    // MARK: - Updates

    func moveTo(_ target: SIMD3<Float>) {
        animState = .moving(progress: 0)
        addTrailPoint(position)
        position = target
    }

    func attachTo(nodeId: String, at position: SIMD3<Float>) {
        targetNodeId = nodeId
        self.position = position
        animState = .attached(angle: 0)
        glowIntensity = 0.6
    }

    func startWorking() {
        animState = .working(pulsePhase: 0)
        glowIntensity = 0.8
    }

    func returnToIdle() {
        animState = .idle
        targetNodeId = nil
        glowIntensity = 0.3
        trailPoints.removeAll()
    }

    private func addTrailPoint(_ point: SIMD3<Float>) {
        trailPoints.append(point)
        if trailPoints.count > maxTrailLength {
            trailPoints.removeFirst(trailPoints.count - maxTrailLength)
        }
    }
}
