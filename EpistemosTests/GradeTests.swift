import Testing
@testable import Epistemos

@Suite("Evidence Grading")
@MainActor
struct GradeTests {

    @Test("grade A for high confidence")
    func gradeA() {
        #expect(AppBootstrap.gradeFromConfidence(0.90) == .a)
        #expect(AppBootstrap.gradeFromConfidence(0.85) == .a)
        #expect(AppBootstrap.gradeFromConfidence(1.0) == .a)
    }

    @Test("grade B for moderate-high confidence")
    func gradeB() {
        #expect(AppBootstrap.gradeFromConfidence(0.84) == .b)
        #expect(AppBootstrap.gradeFromConfidence(0.70) == .b)
    }

    @Test("grade C for moderate confidence")
    func gradeC() {
        #expect(AppBootstrap.gradeFromConfidence(0.69) == .c)
        #expect(AppBootstrap.gradeFromConfidence(0.50) == .c)
    }

    @Test("grade D for low confidence")
    func gradeD() {
        #expect(AppBootstrap.gradeFromConfidence(0.49) == .d)
        #expect(AppBootstrap.gradeFromConfidence(0.30) == .d)
    }

    @Test("grade F for very low confidence")
    func gradeF() {
        #expect(AppBootstrap.gradeFromConfidence(0.29) == .f)
        #expect(AppBootstrap.gradeFromConfidence(0.0) == .f)
    }

    @Test("negative confidence gets F")
    func negativeConfidence() {
        #expect(AppBootstrap.gradeFromConfidence(-0.5) == .f)
    }

    @Test("boundary at exactly 0.85 is grade A")
    func boundaryA() {
        #expect(AppBootstrap.gradeFromConfidence(0.85) == .a)
    }

    @Test("boundary at exactly 0.70 is grade B")
    func boundaryB() {
        #expect(AppBootstrap.gradeFromConfidence(0.70) == .b)
    }

    @Test("boundary at exactly 0.50 is grade C")
    func boundaryC() {
        #expect(AppBootstrap.gradeFromConfidence(0.50) == .c)
    }

    @Test("boundary at exactly 0.30 is grade D")
    func boundaryD() {
        #expect(AppBootstrap.gradeFromConfidence(0.30) == .d)
    }

    @Test("just below 0.30 is grade F")
    func justBelowD() {
        #expect(AppBootstrap.gradeFromConfidence(0.2999) == .f)
    }
}
