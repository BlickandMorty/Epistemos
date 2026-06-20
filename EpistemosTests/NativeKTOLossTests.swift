import Testing
import Foundation

@testable import Epistemos

// SS-LS slice 1b brick 1 — the pure KTO loss math (clean-room from the KTO
// definition), unit-witnessed without a model. The full native training loop wires
// this into LoRATrain in a later slice; KTOTrainer's existing path is untouched
// until then (no regression, no fake).
@Suite("Native KTO loss (SS-LS 1b)")
struct NativeKTOLossTests {

    @Test("sigmoid(0) is 0.5; the KL baseline floors at 0")
    func primitives() {
        #expect(abs(NativeKTOLoss.sigmoid(0) - 0.5) < 1e-12)
        let kto = NativeKTOLoss(beta: 0.1)
        #expect(kto.klBaseline(logratios: []) == 0)
        // mean log-ratio negative ⇒ β·mean negative ⇒ clamped to 0.
        #expect(kto.klBaseline(logratios: [-1, -3]) == 0)
        // mean log-ratio positive ⇒ β·mean (0.1 * 3 = 0.3).
        #expect(abs(kto.klBaseline(logratios: [2, 4]) - 0.3) < 1e-12)
    }

    @Test("hand-computed per-example loss matches the KTO definition")
    func handComputed() {
        let kto = NativeKTOLoss(beta: 1.0)  // β=1 for clean arithmetic
        // desirable, logratio=0, z=0 ⇒ 1·(1−σ(0)) = 0.5
        #expect(abs(kto.perExampleLoss(logratio: 0, desirable: true, klBaseline: 0) - 0.5) < 1e-9)
        // undesirable, logratio=0, z=0 ⇒ 1·(1−σ(0)) = 0.5
        #expect(abs(kto.perExampleLoss(logratio: 0, desirable: false, klBaseline: 0) - 0.5) < 1e-9)
        // desirable, logratio=2, z=0 ⇒ 1−σ(2)
        #expect(
            abs(kto.perExampleLoss(logratio: 2, desirable: true, klBaseline: 0)
                - (1 - NativeKTOLoss.sigmoid(2))) < 1e-12
        )
    }

    @Test("the loss rewards desirable-aligned and penalizes undesirable-aligned shifts")
    func directionality() {
        let kto = NativeKTOLoss(beta: 0.5)
        // Raising the prob of a DESIRABLE response (logratio>0) ⇒ LESS loss than lowering it.
        let desUp = kto.perExampleLoss(logratio: 3, desirable: true, klBaseline: 0)
        let desDown = kto.perExampleLoss(logratio: -3, desirable: true, klBaseline: 0)
        #expect(desUp < desDown)
        // Raising the prob of an UNDESIRABLE response ⇒ MORE loss than lowering it.
        let undUp = kto.perExampleLoss(logratio: 3, desirable: false, klBaseline: 0)
        let undDown = kto.perExampleLoss(logratio: -3, desirable: false, klBaseline: 0)
        #expect(undUp > undDown)
    }

    @Test("batchLoss averages per-example loss and guards empty/mismatched input")
    func batch() {
        let kto = NativeKTOLoss(beta: 1.0)
        #expect(kto.batchLoss(logratios: [], labels: []) == 0)
        #expect(kto.batchLoss(logratios: [1, 2], labels: [true]) == 0) // mismatched length
        // Two examples at logratio=0 (batch mean 0 ⇒ z=0): each loss 0.5 ⇒ mean 0.5.
        #expect(abs(kto.batchLoss(logratios: [0, 0], labels: [true, false]) - 0.5) < 1e-9)
    }
}
