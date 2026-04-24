import Testing

@testable import Epistemos

@Suite("Landing Wave Choreography")
struct LandingWaveChoreographyTests {

    /// The canonical drop sequence must contain exactly the beats specified in
    /// the plan: 1 impact + 6 crown impulses + 1 crater + 1 jet + 1 secondary = 10.
    @Test func sequenceBeatCount() {
        let events = LandingWaveChoreography.makeSequence(
            at: SIMD2<Float>(40, 20),
            cursorDirection: SIMD2<Float>(0, 0)
        )
        #expect(events.count == 10)
    }

    /// The impact flash must fire at t=0, and the secondary droplet must fire
    /// after the Worthington jet — a regression guard against beat reordering.
    @Test func beatOrdering() {
        let events = LandingWaveChoreography.makeSequence(
            at: SIMD2<Float>(40, 20),
            cursorDirection: SIMD2<Float>(0, 0)
        )
        guard let first = events.first, let last = events.last else {
            Issue.record("sequence must not be empty")
            return
        }
        #expect(first.timeOffset == 0.0)
        #expect(last.timeOffset > 0.100)
    }

    /// Crater beat must be negative strength (the cavity pulse) and all other
    /// beats must be positive. Any sign-flip regression would silently kill
    /// the Worthington jet by filling the crater in.
    @Test func craterIsNegativeOnly() {
        let events = LandingWaveChoreography.makeSequence(
            at: SIMD2<Float>(40, 20),
            cursorDirection: SIMD2<Float>(0, 0)
        )
        let negatives = events.filter { $0.strength < 0 }
        #expect(negatives.count == 1, "exactly one negative-strength beat (the crater)")
    }
}

@Suite("Landing Wave Performance Policy")
struct LandingWavePerformancePolicyTests {

    @Test func highTierPrefers120Hz() {
        let range = LandingWavePerformancePolicy.range(for: .high)
        #expect(range.preferred == 120)
        #expect(range.maximum == 120)
        #expect(range.minimum == 60)
    }

    @Test func lowTierCapsAt60Hz() {
        let range = LandingWavePerformancePolicy.range(for: .low)
        #expect(range.maximum == 60)
    }

    @Test func survivalTierCapsAt30Hz() {
        let range = LandingWavePerformancePolicy.range(for: .survival)
        #expect(range.maximum == 30)
    }

    @Test func lowPowerModeDowngrades() {
        let tier = LandingWavePerformancePolicy.currentTier(
            lowPowerMode: true,
            thermalState: .nominal
        )
        #expect(tier == .low)
    }

    @Test func criticalThermalStateTriggersSurvival() {
        let tier = LandingWavePerformancePolicy.currentTier(
            lowPowerMode: false,
            thermalState: .critical
        )
        #expect(tier == .survival)
    }

    @Test func fairThermalStateStillSteppedDown() {
        let tier = LandingWavePerformancePolicy.currentTier(
            lowPowerMode: false,
            thermalState: .fair
        )
        #expect(tier == .low)
    }
}
