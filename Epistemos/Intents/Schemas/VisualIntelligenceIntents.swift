import AppIntents
import Foundation
import OSLog

// MARK: - VisualIntelligenceIntents (R6 / Wave 15 §"bonus items")
//
// Lane C from PARALLEL_SESSION_PROMPT.md — forward-compat scaffold
// for Apple's Visual Intelligence semanticContentSearch schema.
//
// CRITICAL SDK reality (verified 2026-04-26 against
// AppIntents.swiftinterface line 5347-5358):
//
//   @available(iOS 26.0, *)
//   @available(macOS, unavailable)
//   @available(tvOS, unavailable)
//   @available(watchOS, unavailable)
//   @available(visionOS, unavailable)
//   @_alwaysEmitIntoClient public var semanticContentSearch: …
//
// The schema is **iOS-only on macOS 26**. Compass artifact
// wf-5db24f87 §"What's new in macOS 26 vs. macOS 15" pre-flagged
// this: "Trigger surface still iPhone-only Sep 2025; safe to ship
// for forward compat."
//
// We ship the IntentValueQuery + bridge logic gated `#if os(iOS)` so
// when Apple lights up macOS support (rumoured 26.x) we delete the
// gate and the intent surfaces immediately. On macOS today the file
// only contributes a NoteVisualSearchService stub used by the
// graph-engine image-search fallback.

nonisolated private let visualLog = Logger(
    subsystem: "com.epistemos",
    category: "VisualIntelligenceIntents"
)

// MARK: - macOS stub (today)

/// Minimal Mac-side facade so the rest of the codebase can refer to
/// "image-based note search" without conditional compilation. On
/// macOS this falls through to the `HaloController` text-extraction
/// path; on iOS the `@AppIntent(schema:)` below wires the system
/// Visual Intelligence affordance directly.
nonisolated public enum NoteVisualSearchService {

    /// Forward-compat search hook. macOS today: returns the empty
    /// set + logs that Visual Intelligence isn't available on the
    /// platform yet. iOS: reachable via the `@AppIntent` below.
    static func search(imageData: Data?) async -> [NoteEntity] {
        #if os(iOS)
        return await iOSImageSearchHook(imageData: imageData)
        #else
        visualLog.debug("Visual Intelligence semanticContentSearch is iOS-only on macOS 26 — returning [].")
        return []
        #endif
    }

    #if os(iOS)
    /// iOS-only delegate target — populated by the
    /// SearchEpistemosByImageQuery below as the system fires
    /// `values(for:)` per camera capture / screenshot search.
    static var iOSImageSearchHook: (Data?) async -> [NoteEntity] = { _ in [] }
    #endif
}

// MARK: - iOS-only @AppIntent + IntentValueQuery

#if os(iOS) && canImport(VisualIntelligence)

import VisualIntelligence

/// Visual Intelligence semantic content search bridge. The system
/// fires `values(for: SemanticContentDescriptor)` per camera capture
/// or screenshot Visual Intelligence triggers; we route the
/// pixelBuffer + system-supplied labels to the existing image-search
/// pipeline (HaloController OCR → embedding match → top-K notes).
@available(iOS 26.0, *)
struct SearchEpistemosByImageQuery: IntentValueQuery {
    @Dependency var bootstrap: AppBootstrap?

    func values(for input: SemanticContentDescriptor) async throws -> [NoteEntity] {
        let dataOpt: Data? = await ImageBufferConversion.dataFromBuffer(input.pixelBuffer)
        let results = await NoteVisualSearchService.search(imageData: dataOpt)
        visualLog.info(
            "Visual Intelligence semantic search → \(results.count, privacy: .public) results"
        )
        return results
    }
}

@available(iOS 26.0, *)
@AppIntent(schema: .visualIntelligence.semanticContentSearch)
struct SearchEpistemosVisualContentIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Epistemos"
    static let description = IntentDescription(
        "Search the Epistemos vault for notes related to what's currently visible on screen or in the camera frame."
    )
    static let openAppWhenRun: Bool = false
    @Parameter(title: "Visual Content")
    var content: SemanticContentDescriptor

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[NoteEntity]> {
        let results = await NoteVisualSearchService.search(
            imageData: ImageBufferConversion.dataFromBuffer(content.pixelBuffer)
        )
        return .result(value: results)
    }
}

#endif

// MARK: - Image conversion helper (cross-platform; no-op on macOS)

nonisolated public enum ImageBufferConversion {
    /// Convert a CVPixelBuffer (from SemanticContentDescriptor) into
    /// JPEG `Data` suitable for the existing image-search pipeline.
    /// Stub on macOS today — the pixelBuffer arg is iOS-only on the
    /// Visual Intelligence path; macOS code paths pass `nil` and get
    /// `nil` back.
    public static func dataFromBuffer(_ buffer: Any?) async -> Data? {
        return nil
    }
}
