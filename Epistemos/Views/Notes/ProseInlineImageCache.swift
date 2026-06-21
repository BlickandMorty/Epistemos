import AppKit

// SS-2S async image load (SS-FOLLOWON, owner 2026-06-20): the inline-image render's first cut loaded
// the image SYNCHRONOUSLY on the draw path (NSImage(contentsOf:)) — full-resolution and blocking. This
// replaces that with an async, DOWNSAMPLED load via NoteImageProcessor.loadDisplayImage, cached by URL.
//
// Why a cache OUTSIDE the fragment: ProseInlineImageLayoutFragment is a nonisolated, non-Sendable
// NSTextLayoutFragment subclass, so it cannot capture `self` in an async Task ([weak self] on a
// non-Sendable class is illegal). The cache sidesteps that entirely — the draw reads the cache
// synchronously (NSCache is thread-safe), and the async load + a broad layout invalidation happen here,
// never inside the fragment. The whole inline-image render (this included) stays behind the default-off
// EPISTEMOS_PROSE_INLINE_IMAGE_V0 flag, so flag-off is byte-identical to today.
enum ProseInlineImageCache {

    /// Posted on the main thread after an image finishes loading into the cache, so editors can
    /// invalidate layout and let the now-cached image draw. userInfo is empty (broad invalidate).
    static let didLoadNotification = Notification.Name("com.epistemos.prose.inlineImageDidLoad")

    // SAFETY: NSCache is documented thread-safe for concurrent reads/writes. The draw path reads it
    // from a nonisolated context (AppKit's draw, always on the main thread in practice) while the
    // async load below writes it on the MainActor — no data race.
    nonisolated(unsafe) private static let store = NSCache<NSURL, NSImage>()

    /// In-flight URLs so a repeated draw doesn't kick off duplicate loads. MainActor-only.
    @MainActor private static var inFlight = Set<URL>()

    /// Synchronous, nonisolated cache read for the draw + geometry paths. nil → not loaded yet.
    nonisolated static func image(for url: URL) -> NSImage? {
        store.object(forKey: url as NSURL)
    }

    /// Whether this URL is eligible for the async load (local file assets — the common inserted-image
    /// case). Remote http(s) loading is a later increment; kept out so the draw path never blocks on a
    /// network fetch. Pure + testable.
    static func isEligible(_ url: URL) -> Bool {
        url.isFileURL
    }

    /// Kick off a one-time async, downsampled load for `url` if it isn't cached or already loading.
    /// On completion it caches the image and posts `didLoadNotification` so the editor re-lays-out and
    /// the fragment redraws (reading the now-populated cache). Captures only the URL — never a fragment.
    @MainActor static func ensureLoaded(_ url: URL) {
        guard isEligible(url), store.object(forKey: url as NSURL) == nil, !inFlight.contains(url) else {
            return
        }
        inFlight.insert(url)
        Task { @MainActor in
            defer { inFlight.remove(url) }
            guard let payload = await NoteImageProcessor.loadDisplayImage(from: url) else { return }
            let image = NSImage(cgImage: payload.cgImage, size: payload.displaySize)
            store.setObject(image, forKey: url as NSURL)
            NotificationCenter.default.post(name: didLoadNotification, object: nil)
        }
    }
}
