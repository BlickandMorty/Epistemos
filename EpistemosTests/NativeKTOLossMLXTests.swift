import Testing
import Foundation

@testable import Epistemos

#if !EPISTEMOS_APP_STORE
import MLX

// SS-LS 1b brick 3 — the differentiable MLXArray KTO loss must agree with the pure
// scalar NativeKTOLoss.batchLoss (the oracle) on known inputs. The scalar form is
// independently unit-witnessed (NativeKTOLossTests); this proves the MLX port the
// training loop will backprop through computes the same loss. Runs MLX, so it's
// exercised by Xcode/CI (Swift tests don't run headless), compile-verified here.
@Suite("Native KTO loss — MLX matches scalar oracle (SS-LS 1b)")
struct NativeKTOLossMLXTests {

    @Test("the MLXArray KTO loss equals the scalar NativeKTOLoss.batchLoss on known inputs")
    func mlxMatchesScalar() {
        let cases:
            [(beta: Double, lambdaD: Double, lambdaU: Double, logratios: [Float], labels: [Bool])] = [
                (0.1, 1.0, 1.0, [2.0, -1.0, 0.5, -3.0], [true, false, true, false]),
                (0.5, 1.0, 1.0, [0.0, 0.0], [true, false]),
                (1.0, 1.5, 0.8, [1.2, -2.3, 4.0, 0.1, -0.7], [true, true, false, true, false]),
            ]
        for c in cases {
            let kto = NativeKTOLoss(
                beta: c.beta, lambdaDesirable: c.lambdaD, lambdaUndesirable: c.lambdaU
            )
            let scalar = kto.batchLoss(logratios: c.logratios.map(Double.init), labels: c.labels)
            let mlx = kto.mlxBatchLoss(
                logratios: MLXArray(c.logratios),
                desirable: MLXArray(c.labels.map { $0 ? Float(1) : Float(0) })
            ).item(Float.self)
            #expect(
                abs(Double(mlx) - scalar) < 1e-4,
                "MLX KTO loss \(mlx) != scalar oracle \(scalar) for β=\(c.beta)"
            )
        }
    }
}
#endif
