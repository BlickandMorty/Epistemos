// EidosBridge.swift
//
// Terminal A 2026-05-23 — Real Vault Binding (P1 + W-46/W-47).
//
// Extends the `EidosBridge` namespace declared in EidosWiring.swift
// with the production-vault FFI surface:
//
//   - openVaultIndex(signature:)         → calls eidosOpenVaultIndex
//   - insertVaultNote(documentId:body:kind:) → calls eidosVaultIndexInsertNote
//   - retrieve(query:topK:)              → calls eidosRetrieveJson
//   - validateCitation(packet:citation:) → calls eidosValidateCitationJson
//   - validateCitations(packet:sources:) → batch helper (Swift-side fast path)
//   - closeVaultIndex()                  → calls eidosCloseVaultIndex
//
// The existing `EidosBridge.search(query:topK:)` (fixture path) stays
// untouched for back-compat — `QueryRuntime.swift` still calls it. The
// production path is opt-in: agent surfaces call `EidosBridge.retrieve(...)`
// once `AppBootstrap` has opened the
// production vault index.
//
// **7 Laws cited:** Law 2 Address (every hit carries a manifest-bound
// chunk id), Law 4 Lattice-error (forged citations rejected closed),
// Law 7 Witness (closed-citation contract IS the witness).
//
// **§No-Orphan:** the EidosBridge production surface is the seam
// where the Eidos data class (UAS-bound, plane=Verification,
// residency=Hot, WBO=N/A, WRV=product-facing) becomes citable from
// the chat layer. The bridge owns the per-query WRV gate (chip-strip
// flip in EidosHealthRow flips orange→green when `lastBackend == .real`).
//
// **W-row advance:** W-46.1 (real vault binding), W-47 (citation gate).
//
// **Tier:** Tier 1 (MAS-shippable). No legacy surface-flag guard.

import Foundation
import os

nonisolated extension EidosBridge {
    nonisolated private static let prodLog = Logger(subsystem: "com.epistemos", category: "eidos.production")

    /// Outcome of `validateCitation(packet:citation:)`. Mirrors the
    /// Rust `Result<(), CitationError>` wire shape one level up:
    /// `.accepted` if the citation passes the closed-citation
    /// contract; `.rejected(EidosCitationError)` if it does not.
    /// `.bridgeFailure` covers FFI-layer failures (decode error, FFI
    /// error). `bridgeFailure` is distinct from rejection — the chat
    /// layer should fall back / surface diagnostic, NOT silently
    /// continue.
    public enum CitationValidation: Sendable, Equatable {
        case accepted
        case rejected(EidosCitationError)
        case bridgeFailure(String)
    }

    /// Open or replace the process-global production Eidos vault
    /// index. `signature` is typically the SHA-256 of the vault path
    /// or a corpus snapshot identifier — it becomes part of the
    /// manifest_id (`vault-<signature>`), so the backend-honesty
    /// detection in `detectedBackend(from:)` flips to `.real`.
    ///
    /// Returns the typed manifest id on success, or `nil` on
    /// failure (also records the error into EidosMetrics).
    @discardableResult
    nonisolated public static func openVaultIndex(signature: String) -> EidosIndexManifestId? {
        do {
            let raw = try eidosOpenVaultIndex(vaultSignature: signature)
            guard let manifest = EidosIndexManifestId(raw) else {
                let err = NSError(domain: "EidosBridge", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "Rust returned empty manifest_id"
                ])
                EidosMetrics.shared.recordError(err)
                return nil
            }
            prodLog.info(
                "Eidos vault index opened manifest=\(manifest.raw, privacy: .public)"
            )
            return manifest
        } catch {
            EidosMetrics.shared.recordError(error)
            let message = RetrievalDiagnostics.statusMessage(
                for: error,
                fallback: "Eidos openVaultIndex failed"
            )
            prodLog.error("\(message, privacy: .public)")
            return nil
        }
    }

    /// Insert (or replace) one note into the production vault index.
    /// `kind` is the Swift-side EidosSourceKind; this maps to the
    /// Rust variant name on the wire.
    @discardableResult
    nonisolated public static func insertVaultNote(
        documentId: String,
        body: String,
        kind: EidosSourceKind = .note
    ) -> Bool {
        do {
            return try eidosVaultIndexInsertNote(
                documentId: documentId,
                body: body,
                sourceKind: kind.rawValue
            )
        } catch {
            EidosMetrics.shared.recordError(error)
            let message = RetrievalDiagnostics.statusMessage(
                for: error,
                fallback: "Eidos insertVaultNote failed"
            )
            prodLog.error(
                "\(message, privacy: .public)"
            )
            return false
        }
    }

    /// Run a lexical query against the production vault index. Returns
    /// the decoded `EidosContextPacket`, or `nil` if the index is not
    /// open / a decode error occurred. Records into `EidosMetrics`
    /// with backend = detected backend (so the health row chip-strip
    /// surfaces `vault binding active` automatically when retrieval
    /// hits the real index).
    nonisolated public static func retrieve(query: String, topK: UInt32 = 12) -> EidosContextPacket? {
        let started = Date()
        do {
            let raw = try eidosRetrieveJson(query: query, topK: topK)
            guard let data = raw.data(using: .utf8) else {
                let err = NSError(domain: "EidosBridge", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "non-utf8 retrieve JSON"
                ])
                EidosMetrics.shared.recordError(err)
                return nil
            }
            let packet = try JSONDecoder().decode(EidosContextPacket.self, from: data)
            let latencyMs = Date().timeIntervalSince(started) * 1000
            let backend = detectedBackend(from: packet)
            EidosMetrics.shared.record(
                latencyMs: latencyMs,
                citationCount: packet.hits.count,
                backend: backend
            )
            switch backend {
            case .real:
                prodLog.info(
                    "Eidos production vault retrieve query=\"\(query, privacy: .private)\" hits=\(packet.hits.count, privacy: .public) latency_ms=\(latencyMs, privacy: .public) manifest=\(packet.manifestId.raw, privacy: .public)"
                )
            case .fixture:
                prodLog.notice(
                    "Eidos retrieve returned FIXTURE manifest from production FFI — should not happen post-open; manifest=\(packet.manifestId.raw, privacy: .public)"
                )
            case .unknown:
                prodLog.info(
                    "Eidos retrieve returned unknown-backend packet manifest=\(packet.manifestId.raw, privacy: .public)"
                )
            }
            return packet
        } catch {
            EidosMetrics.shared.recordError(error)
            let message = RetrievalDiagnostics.statusMessage(
                for: error,
                fallback: "Eidos retrieve failed"
            )
            prodLog.error(
                "\(message, privacy: .public)"
            )
            return nil
        }
    }

    /// Authoritative single-citation gate. Calls the Rust FFI so the
    /// closed-citation contract is enforced on the Rust side even if
    /// the Swift mirror ever drifts.
    nonisolated public static func validateCitation(
        packet: EidosContextPacket,
        citation: EidosCitation
    ) -> CitationValidation {
        do {
            let enc = JSONEncoder()
            let packetData = try enc.encode(packet)
            let citationData = try enc.encode(citation)
            guard
                let packetJson = String(data: packetData, encoding: .utf8),
                let citationJson = String(data: citationData, encoding: .utf8)
            else {
                return .bridgeFailure("encode produced non-utf8")
            }
            let raw = try eidosValidateCitationJson(
                packetJson: packetJson,
                citationJson: citationJson
            )
            guard let data = raw.data(using: .utf8) else {
                return .bridgeFailure("non-utf8 validation JSON")
            }
            // Wire shape: `{"Ok":null}` on accept,
            // `{"Err": <CitationError JSON>}` on reject.
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if json.keys.contains("Ok") {
                    return .accepted
                }
                if let errPayload = json["Err"] {
                    let errData = try JSONSerialization.data(withJSONObject: errPayload)
                    let err = try JSONDecoder().decode(EidosCitationError.self, from: errData)
                    return .rejected(err)
                }
            }
            return .bridgeFailure("validation JSON shape unrecognized")
        } catch {
            EidosMetrics.shared.recordError(error)
            return .bridgeFailure(
                RetrievalDiagnostics.statusMessage(
                    for: error,
                    fallback: "Eidos citation validation failed"
                )
            )
        }
    }

    /// Batch gate over a list of candidate `EidosChunkId`s. Builds
    /// `EidosCitation` envelopes pinned to `packet.manifestId` and
    /// runs them through the single-call Rust batch validator
    /// (`eidos_validate_citations_json`), which decodes the packet
    /// JSON exactly once per call — substantially cheaper than the
    /// per-citation `validateCitation` loop for large source-id
    /// slices. Returns `.accepted` only if EVERY citation passes;
    /// otherwise returns the first rejection (in input order),
    /// matching Rust `EidosContextPacket::validate_citations`
    /// semantics.
    ///
    /// **W-47 citation gate**: answer commit paths hand the per-answer
    /// `sourceIds` slice here before committing the message. A
    /// rejection MUST drop or rewrite the answer; never ship a chat
    /// row whose source_ids don't validate.
    nonisolated public static func validateCitations(
        packet: EidosContextPacket,
        sourceIds: [EidosChunkId]
    ) -> CitationValidation {
        // Vacuous accept on empty input — matches Rust semantics.
        if sourceIds.isEmpty {
            return .accepted
        }
        do {
            let citations = sourceIds.map {
                EidosCitation(sourceId: $0, manifestId: packet.manifestId)
            }
            let enc = JSONEncoder()
            let packetData = try enc.encode(packet)
            let citationsData = try enc.encode(citations)
            guard
                let packetJson = String(data: packetData, encoding: .utf8),
                let citationsJson = String(data: citationsData, encoding: .utf8)
            else {
                return .bridgeFailure("encode produced non-utf8")
            }
            let raw = try eidosValidateCitationsJson(
                packetJson: packetJson,
                citationsJson: citationsJson
            )
            guard let data = raw.data(using: .utf8) else {
                return .bridgeFailure("non-utf8 batch validation JSON")
            }
            // Wire shape: {"Ok":{"accepted_count":N}} on accept,
            // {"Err":[[i, <CitationError>], ...]} on reject (input
            // order preserved, first failure becomes the surface).
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .bridgeFailure("batch validation JSON shape unrecognized")
            }
            if json.keys.contains("Ok") {
                return .accepted
            }
            if let failures = json["Err"] as? [[Any]],
               let first = failures.first,
               first.count == 2 {
                let errData = try JSONSerialization.data(withJSONObject: first[1])
                let err = try JSONDecoder().decode(EidosCitationError.self, from: errData)
                return .rejected(err)
            }
            return .bridgeFailure("batch validation JSON shape unrecognized")
        } catch {
            EidosMetrics.shared.recordError(error)
            return .bridgeFailure(
                RetrievalDiagnostics.statusMessage(
                    for: error,
                    fallback: "Eidos citation batch validation failed"
                )
            )
        }
    }

    /// Diagnostic status: is the production vault index open, and
    /// what manifest_id is it bound to? Returns nil on FFI failure.
    /// Tier 1 read-only helper — safe to call from a SwiftUI redraw.
    public struct VaultStatus: Sendable, Equatable {
        public let isOpen: Bool
        public let manifestId: EidosIndexManifestId?
    }

    nonisolated public static func vaultStatus() -> VaultStatus? {
        do {
            let raw = try eidosVaultStatusJson()
            guard let data = raw.data(using: .utf8) else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            let open = (json["open"] as? Bool) ?? false
            if open, let mid = json["manifest_id"] as? String, let typed = EidosIndexManifestId(mid) {
                return VaultStatus(isOpen: true, manifestId: typed)
            }
            return VaultStatus(isOpen: false, manifestId: nil)
        } catch {
            EidosMetrics.shared.recordError(error)
            return nil
        }
    }

    /// Drop the process-global production vault index. Primarily for
    /// tests, or for a vault-path change where the manifest signature
    /// must rotate. Returns `true` if an index was actually open.
    @discardableResult
    nonisolated public static func closeVaultIndex() -> Bool {
        do {
            return try eidosCloseVaultIndex()
        } catch {
            EidosMetrics.shared.recordError(error)
            return false
        }
    }
}
