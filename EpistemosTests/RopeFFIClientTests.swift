import Foundation
import Testing
@testable import Epistemos

// MARK: - W9.26 PR3 — RopeFFIClient FFI roundtrip smoke tests
//
// Validates that Swift RopeFFIClient correctly drives
// agent_core/src/rope_handle.rs across the FFI boundary. The
// Rust-side correctness is already covered by 6 unit tests in
// rope_handle.rs; these tests exercise the @_silgen_name binding
// + Swift wrapper logic.

@Suite("RopeFFIClient FFI roundtrip")
struct RopeFFIClientTests {

    @Test("empty rope reports zero lengths and snapshots to empty string")
    func emptyRope() async throws {
        let rope = RopeFFIClient()
        #expect(rope != nil)
        guard let rope else { return }
        #expect(rope.byteLength == 0)
        #expect(rope.utf16Length == 0)
        #expect(rope.snapshot() == "")
    }

    @Test("seeded rope reports correct UTF-8 + UTF-16 lengths")
    func seededRopeLengths() async throws {
        let rope = RopeFFIClient(text: "Hello, world!")
        #expect(rope != nil)
        guard let rope else { return }
        #expect(rope.byteLength == 13)
        #expect(rope.utf16Length == 13)
        #expect(rope.snapshot() == "Hello, world!")
    }

    @Test("insert + snapshot roundtrip")
    func insertRoundtrip() async throws {
        let rope = RopeFFIClient()
        guard let rope else { return }

        let ok1 = rope.insert("Hello, ", atByteOffset: 0)
        #expect(ok1 == true)

        let ok2 = rope.insert("world!", atByteOffset: 7)
        #expect(ok2 == true)

        #expect(rope.snapshot() == "Hello, world!")
        #expect(rope.byteLength == 13)
    }

    @Test("delete shrinks the rope")
    func deleteShrinks() async throws {
        let rope = RopeFFIClient(text: "Hello, world!")
        guard let rope else { return }

        rope.delete(byteFrom: 5, to: 7)
        #expect(rope.snapshot() == "Helloworld!")
        #expect(rope.byteLength == 11)
    }

    @Test("UTF-16 offsets match WKWebView selection semantics")
    func utf16Offsets() async throws {
        // ä is 2 UTF-8 bytes / 1 UTF-16 unit.
        let rope = RopeFFIClient(text: "aäb")
        guard let rope else { return }

        #expect(rope.byteLength == 4)
        #expect(rope.utf16Length == 3)
        // ä starts at byte 1, utf16 unit 1
        #expect(rope.byteOffset(forUTF16: 1) == 1)
        #expect(rope.byteOffset(forUTF16: 2) == 3)
        #expect(rope.utf16Offset(forByte: 3) == 2)
    }

    @Test("retainSibling shares the same underlying document")
    func retainSibling() async throws {
        let rope = RopeFFIClient(text: "shared")
        guard let rope else { return }

        let sibling = rope.retainSibling()

        // Mutating via either client must be visible through both —
        // they refcount the same Arc<RopeDocument>.
        rope.insert("!", atByteOffset: 6)
        #expect(rope.snapshot() == "shared!")
        #expect(sibling.snapshot() == "shared!")
        #expect(sibling.byteLength == 7)

        // When `rope` deinits at end of scope, the document is still
        // alive via `sibling`. When `sibling` deinits, refcount hits
        // zero. If lifetime were broken, the second snapshot above
        // would UAF (TSan / sanitizer would catch).
    }
}
