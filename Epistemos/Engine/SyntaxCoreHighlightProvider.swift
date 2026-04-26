import AppKit
import CodeEditLanguages
import CodeEditSourceEditor
import CodeEditTextView
import Foundation
import os

/// `HighlightProviding` adapter that bridges `syntax-core` (Rust crate)
/// into the CodeEditSourceEditor highlight pipeline.
///
/// Wave 4.5 / Patch 6a of the Extended Program Plan
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 4.5,
///  cross-ref dpp §4.4 Sprint 3 deep perf).
///
/// V1 left this BLOCKED because the main editor relied on
/// CodeEditSourceEditor's bundled `TreeSitterClient` and there was no
/// production-quality adapter from the syntax-core handle. This class
/// closes that gap by:
///
///   1. Owning a `SyntaxCoreService` per textView (one tree, one parser
///      handle, one rope — no per-keystroke allocation churn).
///   2. Translating CodeEditSourceEditor's UTF-16 NSRange API into the
///      UTF-8 byte ranges syntax-core expects, and back again.
///   3. Mapping syntax-core's capture-name strings (the same set used by
///      our existing inspector preview path) into the editor's
///      `CaptureName` enum so colors flow through the editor's theme.
///
/// Activation gate: the adapter is only constructed when the
/// `EPISTEMOS_USE_SYNTAX_CORE` environment flag is `"1"`. With the flag
/// off, CodeEditorView passes `nil` for `highlightProviders` and the
/// editor uses its bundled TreeSitterClient — guaranteed regression-free
/// on the default code path.
@MainActor
final class SyntaxCoreHighlightProvider {

    private static let log = Logger(subsystem: "com.epistemos.syntax", category: "SyntaxCoreHighlightProvider")

    /// Stable opaque doc id for syntax-core. We mint one per
    /// adapter instance; multiple editor instances on the same source
    /// would each get their own id.
    private static let docIdCounter = OSAllocatedUnfairLock<UInt64>(initialState: 1)

    private let docId: UInt64
    private let language: String
    private var service: SyntaxCoreService?

    init(language: String) {
        self.language = language
        self.docId = Self.docIdCounter.withLock { current in
            let value = current
            current = current &+ 1
            return value
        }
    }

    // MARK: - HighlightProviding

    @MainActor
    func setUp(textView: TextView, codeLanguage: CodeLanguage) {
        let source = textView.string
        service = SyntaxCoreService(docId: docId, language: language, source: source)
        if service?.isValid != true {
            Self.log.warning("SyntaxCoreService failed to initialise for language=\(self.language, privacy: .public); falling back to empty highlights")
        }
    }

    @MainActor
    func willApplyEdit(textView: TextView, range: NSRange) {
        // syntax-core records the edit in applyEdit; nothing to stage here.
    }

    @MainActor
    func applyEdit(
        textView: TextView,
        range: NSRange,
        delta: Int,
        completion: @escaping @MainActor (Result<IndexSet, Error>) -> Void
    ) {
        guard let service, service.isValid else {
            completion(.success(IndexSet()))
            return
        }

        let nsString = textView.string as NSString
        // Convert the post-edit NSRange (UTF-16) to UTF-8 byte offsets.
        // The replaced range in syntax-core's pre-edit space is
        // `range.location ..< range.location + (range.length - delta)`
        // (i.e. the original length before the insert/delete).
        let oldUtf16Length = max(0, range.length - delta)
        let oldEnd16 = range.location + oldUtf16Length
        let oldEnd16Clamped = min(oldEnd16, nsString.length + max(0, oldUtf16Length))

        let byteStart = Self.utf16OffsetToByteOffset(nsString, utf16Offset: range.location)
        let byteOldEnd = Self.utf16OffsetToByteOffset(nsString, utf16Offset: oldEnd16Clamped)
        let byteOldLen = byteOldEnd >= byteStart ? byteOldEnd - byteStart : 0

        // Extract the new text (post-edit) from the textView at this range.
        let safeRange = NSRange(
            location: range.location,
            length: max(0, min(range.length, nsString.length - range.location))
        )
        let newText = (safeRange.length > 0) ? nsString.substring(with: safeRange) : ""

        service.edit(byteStart: UInt64(byteStart), oldLen: UInt64(byteOldLen), newText: newText)

        // Conservatively invalidate the entire visible document so the
        // editor re-queries highlights for the visible viewport. This
        // matches what TreeSitterClient does on a coarse edit; a
        // future refinement can return only the changed-line range.
        let invalidation = IndexSet(integersIn: 0..<nsString.length)
        completion(.success(invalidation))
    }

    @MainActor
    func queryHighlightsFor(
        textView: TextView,
        range: NSRange,
        completion: @escaping @MainActor (Result<[HighlightRange], Error>) -> Void
    ) {
        guard let service, service.isValid else {
            completion(.success([]))
            return
        }

        let nsString = textView.string as NSString
        let clampedLocation = max(0, min(range.location, nsString.length))
        let clampedEnd = max(clampedLocation, min(range.location + range.length, nsString.length))

        let byteStart = Self.utf16OffsetToByteOffset(nsString, utf16Offset: clampedLocation)
        let byteEnd = Self.utf16OffsetToByteOffset(nsString, utf16Offset: clampedEnd)
        let tokens = service.tokensForViewport(byteStart: UInt64(byteStart), byteEnd: UInt64(byteEnd))

        let textRegistry = SyntaxCoreCaptureNameRegistry.shared
        let highlights: [HighlightRange] = tokens.compactMap { token in
            let location = Int(token.utf16_start)
            let length = Int(token.utf16_len)
            guard length > 0 else { return nil }
            guard location >= 0, location + length <= nsString.length else { return nil }
            let nsRange = NSRange(location: location, length: length)
            let capture = textRegistry.captureName(for: token.kind_id)
            return HighlightRange(range: nsRange, capture: capture)
        }
        completion(.success(highlights))
    }

    // MARK: - Protocol conformance

    // The HighlightProviding protocol is imported under @preconcurrency in
    // CodeEditorView. Declaring the conformance via an extension lets us
    // satisfy the strict-concurrency closure-sendability requirements
    // without polluting the class declaration.

    // MARK: - Helpers

    /// Convert a UTF-16 code-unit offset (NSString-native) into a UTF-8
    /// byte offset. `NSString.substring(with:)` + `.utf8.count` keeps the
    /// math correct across surrogate pairs and Unicode normalisation
    /// edge cases without us having to maintain a parallel rope mirror.
    private static func utf16OffsetToByteOffset(_ ns: NSString, utf16Offset: Int) -> Int {
        guard utf16Offset > 0, utf16Offset <= ns.length else { return 0 }
        let prefix = ns.substring(with: NSRange(location: 0, length: utf16Offset))
        return prefix.utf8.count
    }
}

// MARK: - HighlightProviding conformance (FOLLOW-UP)
//
// The `SyntaxCoreHighlightProvider` class above implements every
// HighlightProviding method with the algorithmically correct shape, but
// the protocol's `@escaping @MainActor` closure parameters infer
// `@Sendable` under Swift 6 strict concurrency in CodeEditSourceEditor's
// module while my conforming impl is seen as just `@MainActor` (no
// Sendable inference) — even with `@preconcurrency import` on either
// or both sides, on the conforming class, on the extension, or on the
// individual methods. Tried: class-level @MainActor, method-level
// @MainActor, both, @Sendable on closure, @Sendable@MainActor on
// closure, conformance via @preconcurrency import struct extension —
// all hit the same `sendability of function types ... does not match
// requirement` error.
//
// Wave 4.5 ships the class + tests + the inspector preview path
// (CodeEditorView.swift::applySyntaxCore is unchanged and still drives
// SyntaxCoreService directly behind EPISTEMOS_USE_SYNTAX_CORE). The
// remaining step — declaring `extension SyntaxCoreHighlightProvider:
// HighlightProviding {}` and passing `[provider]` to SourceEditor — is
// a follow-up patch that either:
//   1. Adds `-strict-concurrency=minimal` to this single file via
//      OTHER_SWIFT_FLAGS in the target build settings, OR
//   2. Waits for an upstream CodeEditSourceEditor revision that re-
//      declares the protocol with explicit @Sendable on the closures
//      so cross-module conformance inference matches.
//
// The Wave 4.5 source-guard test exercises the class directly (without
// the protocol cast) so the algorithm is regression-tested today.

// MARK: - Capture name registry

/// Maps syntax-core's `kind_id` (token registry) into the editor's
/// `CaptureName` enum. The kind_id values are stable for the lifetime
/// of a single SyntaxCoreService — but new captures get assigned ids
/// in registration order, so we cache (id → CaptureName) via a thread-
/// safe lookup that re-resolves on cache miss.
///
/// In practice the GENERIC_HIGHLIGHTS_QUERY in syntax-core uses a
/// fixed set of capture names (~12), so the cache fills in the first
/// few queries and stays warm.
@MainActor
final class SyntaxCoreCaptureNameRegistry {
    static let shared = SyntaxCoreCaptureNameRegistry()

    private var nameByKindId: [UInt16: CaptureName?] = [:]

    private init() {}

    /// Maps a syntax-core capture name string → CodeEditSourceEditor's
    /// `CaptureName`. Handles the two strings syntax-core emits that
    /// don't have direct enum cases:
    ///   - "function.def" / "function.call" → .function
    ///   - "constant" → .boolean (closest visual semantic)
    ///   - "escape" → .string (escape sequences live inside strings)
    ///   - "macro" / "attribute" → nil (let the editor render plain)
    nonisolated static func canonicalCaptureName(for raw: String) -> CaptureName? {
        if let direct = CaptureName.fromString(raw) { return direct }
        switch raw {
        case "function.def", "function.call":  return .function
        case "constant":                        return .boolean
        case "escape":                          return .string
        case "macro", "attribute":              return nil
        default:                                return nil
        }
    }

    func captureName(for kindId: UInt16) -> CaptureName? {
        if let cached = nameByKindId[kindId] { return cached }
        // We don't have access to the registry's id→name reverse map
        // from outside SyntaxCoreService; the registry is internal to
        // the Rust crate. As a pragmatic workaround for V1.5, we
        // hard-code the known generic-query capture order, which
        // matches the order syntax-core's GENERIC_HIGHLIGHTS_QUERY
        // declares them. If the query grows, this list needs an entry.
        let knownOrder: [String] = [
            // unknown sentinel
            "",
            "comment", "string", "number", "constant", "escape",
            "type", "variable", "property",
            "function.def", "function.call",
            "macro", "attribute",
        ]
        let idx = Int(kindId)
        let name: CaptureName?
        if idx >= 0, idx < knownOrder.count {
            name = Self.canonicalCaptureName(for: knownOrder[idx])
        } else {
            name = nil
        }
        nameByKindId[kindId] = name
        return name
    }
}
