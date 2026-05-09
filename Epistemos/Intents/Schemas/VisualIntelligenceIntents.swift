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
// this: "Trigger surface still iPhone-only Sep 2025"; v1 keeps the
// bridge source-preserved for forward compatibility without exposing it
// as shipped macOS visual search.
//
// v1 ships the macOS side as an honest deferred facade only. The
// system AppIntent bridge is additionally gated behind the custom
// `EPISTEMOS_ENABLE_VISUAL_INTELLIGENCE_INTENT` build condition so an
// experimental iOS target cannot accidentally expose visual search
// before pixel-buffer conversion and image-note retrieval are real.

nonisolated private let visualLog = Logger(
    subsystem: "com.epistemos",
    category: "VisualIntelligenceIntents"
)

// MARK: - macOS deferred facade

/// Minimal Mac-side facade so the rest of the codebase can refer to
/// "image-based note search" without conditional compilation. On
/// macOS this is unavailable and returns no results; it must not be
/// presented as shipped visual search until a real image pipeline is
/// wired.
nonisolated public enum NoteVisualSearchService {
    nonisolated static let unavailableOnMacOSMessage =
        "Visual Intelligence semanticContentSearch is unavailable on macOS; image-note search is deferred."

    /// Forward-compat search hook. macOS v1 returns an empty set and
    /// logs the unavailable status rather than pretending image-note
    /// search ran.
    static func search(imageData: Data?) async -> [NoteEntity] {
        #if os(iOS) && EPISTEMOS_ENABLE_VISUAL_INTELLIGENCE_INTENT
        return await iOSImageSearchHook(imageData: imageData)
        #elseif os(iOS)
        visualLog.warning("Visual Intelligence intent bridge is compile-time disabled — returning [].")
        return []
        #else
        visualLog.warning("\(Self.unavailableOnMacOSMessage, privacy: .public)")
        return []
        #endif
    }

    #if os(iOS) && EPISTEMOS_ENABLE_VISUAL_INTELLIGENCE_INTENT
    /// iOS-only delegate target — populated by the
    /// SearchEpistemosByImageQuery below as the system fires
    /// `values(for:)` per camera capture / screenshot search.
    static var iOSImageSearchHook: (Data?) async -> [NoteEntity] = { _ in [] }
    #endif
}

// MARK: - iOS-only @AppIntent + IntentValueQuery

#if os(iOS) && canImport(VisualIntelligence) && EPISTEMOS_ENABLE_VISUAL_INTELLIGENCE_INTENT

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
            imageData: await ImageBufferConversion.dataFromBuffer(content.pixelBuffer)
        )
        return .result(value: results)
    }
}

#endif

// MARK: - Image conversion helper (deferred on macOS)

nonisolated public enum ImageBufferConversion {
    /// Convert a CVPixelBuffer (from SemanticContentDescriptor) into
    /// JPEG `Data` suitable for the existing image-search pipeline.
    /// Deferred on macOS today: the pixelBuffer arg is iOS-only on the
    /// gated Visual Intelligence path; macOS code paths pass `nil` and
    /// get `nil` back.
    public static func dataFromBuffer(_ buffer: Any?) async -> Data? {
        return nil
    }
}
