import Testing
import Foundation

@testable import Epistemos

// SS-PERF2 #2/#4 (owner 2026-06-20 deep-research): SDMessage's per-message accessors no
// longer allocate a fresh JSONDecoder()/JSONEncoder() on every call — they share one
// default-configured pair. Correctness claim under test: the shared coders are
// behaviourally identical to the fresh default instances they replaced, so persisted
// blobs decode/encode byte-for-byte unchanged. Pure (no SwiftData context needed).
@Suite("SS-PERF2 shared SDMessage coders")
struct SSPERF2SharedCodersTests {

    private struct Sample: Codable, Equatable {
        let a: Int
        let b: [String]
        let c: Double
        let d: Bool
    }

    @Test("the shared encoder output is byte-identical to a fresh default JSONEncoder")
    func sharedEncoderByteIdentical() throws {
        let value = Sample(a: 7, b: ["alpha", "beta"], c: 1.5, d: true)
        let shared = try SDMessage.sharedEncoder.encode(value)
        let fresh = try JSONEncoder().encode(value)
        #expect(shared == fresh)
    }

    @Test("the shared decoder round-trips what the shared encoder wrote")
    func sharedDecoderRoundTrips() throws {
        let value = Sample(a: -3, b: [], c: 0, d: false)
        let data = try SDMessage.sharedEncoder.encode(value)
        let back = try SDMessage.sharedDecoder.decode(Sample.self, from: data)
        #expect(back == value)
    }

    @Test("the shared decoder reads blobs a fresh default encoder produced (no drift)")
    func sharedDecoderReadsFreshEncoderBlob() throws {
        let value = Sample(a: 42, b: ["x"], c: 3.14159, d: true)
        // A blob written by the OLD path (fresh default encoder) must still decode.
        let legacyBlob = try JSONEncoder().encode(value)
        let back = try SDMessage.sharedDecoder.decode(Sample.self, from: legacyBlob)
        #expect(back == value)
    }
}
