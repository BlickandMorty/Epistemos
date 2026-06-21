import Testing
import Foundation

@testable import Epistemos

// SS-2S async image load (SS-FOLLOWON, owner 2026-06-20): the inline-image render now loads images
// asynchronously + downsampled through ProseInlineImageCache instead of a synchronous, full-res
// NSImage(contentsOf:) on the draw path. These pin the cache's pure surface — the draw path can only
// read it synchronously and must never block on a network fetch, and the editor relies on a stable
// notification name to re-layout when a load completes. (The async load itself runs real I/O via
// NoteImageProcessor and is owner-verified at runtime with the render flag on.)
@Suite("SS-2S — async inline image cache")
struct SS2SInlineImageCacheTests {

    @Test("only local file URLs are eligible — the draw path never blocks on a network fetch")
    func eligibilityIsFileOnly() {
        #expect(ProseInlineImageCache.isEligible(URL(fileURLWithPath: "/vault/assets/cat.png")))
        #expect(ProseInlineImageCache.isEligible(URL(fileURLWithPath: "/abs/x.png")))
        if let remote = URL(string: "https://example.com/y.png") {
            #expect(!ProseInlineImageCache.isEligible(remote))
        }
        if let http = URL(string: "http://example.com/y.png") {
            #expect(!ProseInlineImageCache.isEligible(http))
        }
    }

    @Test("an uncached URL reads nil — the fragment draws nothing until the async load populates it")
    func uncachedReadsNil() {
        let url = URL(fileURLWithPath: "/tmp/ss2s-never-loaded-\(UUID().uuidString).png")
        #expect(ProseInlineImageCache.image(for: url) == nil)
    }

    @Test("the load notification name is stable (the editor observes it to re-layout)")
    func notificationNameStable() {
        #expect(ProseInlineImageCache.didLoadNotification.rawValue
                == "com.epistemos.prose.inlineImageDidLoad")
    }
}
