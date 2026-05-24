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
// production path is opt-in: ChatCoordinator + Brain Panel call
// `EidosBridge.retrieve(...)` once `AppBootstrap` has opened the
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
// **Tier:** Tier 1 (MAS-shippable). No `#if PRO_BUILD` guard.

import Foundation
import os

extension EidosBridge {
    private static let prodLog = Logger(subsystem: "com.epistemos", category: "eidos.production")

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
    public static func openVaultIndex(signature: String) -> EidosIndexManifestId? {
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
            prodLog.error("Eidos openVaultIndex failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Insert (or replace) one note into the production vault index.
    /// `kind` is the Swift-side EidosSourceKind; this maps to the
    /// Rust variant name on the wire.
    @discardableResult
    public static func insertVaultNote(
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
            prodLog.error(
                "Eidos insertVaultNote failed doc=\(documentId, privacy: .public): \(String(describing: error), privacy: .public)"
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
    public static func retrieve(query: String, topK: UInt32 = 12) -> EidosContextPacket? {
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
                    "Eidos production vault retrieve query=\"\(query, privacy: .public)\" hits=\(packet.hits.count, privacy: .public) latency_ms=\(latencyMs, privacy: .public) manifest=\(packet.manifestId.raw, privacy: .public)"
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
            prodLog.error(
                "Eidos retrieve failed query=\"\(query, privacy: .public)\": \(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    /// Authoritative single-citation gate. Calls the Rust FFI so the
    /// closed-citation contract is enforced on the Rust side even if
    /// the Swift mirror ever drifts.
    public static func validateCitation(
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
            return .bridgeFailure("validation JSON shape unrecognized: \(raw)")
        } catch {
            EidosMetrics.shared.recordError(error)
            return .bridgeFailure(String(describing: error))
        }
    }

    /// Batch gate over a list of candidate `EidosChunkId`s. Builds
    /// `EidosCitation` envelopes pinned to `packet.manifestId` and
    /// runs each through the Rust validator. Returns `.accepted`
    /// only if EVERY citation passes; otherwise returns the first
    /// rejection (in input order). Matches Rust
    /// `EidosContextPacket::validate_citations` semantics.
    ///
    /// **W-47 citation gate**: ChatCoordinator hands the per-answer
    /// `sourceIds` slice here BEFORE committing the message. A
    /// rejection MUST drop or rewrite the answer; never ship a chat
    /// row whose source_ids don't validate.
    public static func validateCitations(
        packet: EidosContextPacket,
        sourceIds: [EidosChunkId]
    ) -> CitationValidation {
        for chunkId in sourceIds {
            let cite = EidosCitation(sourceId: chunkId, manifestId: packet.manifestId)
            let outcome = validateCitation(packet: packet, citation: cite)
            switch outcome {
            case .accepted: continue
            case .rejected, .bridgeFailure: return outcome
            }
        }
        return .accepted
    }

    /// Drop the process-global production vault index. Primarily for
    /// tests, or for a vault-path change where the manifest signature
    /// must rotate. Returns `true` if an index was actually open.
    @discardableResult
    public static func closeVaultIndex() -> Bool {
        do {
            return try eidosCloseVaultIndex()
        } catch {
            EidosMetrics.shared.recordError(error)
            return false
        }
    }
}
