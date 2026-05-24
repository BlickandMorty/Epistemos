// ChatCoordinator+EidosCitationGate.swift
//
// Terminal A 2026-05-23 — W-47 closed-citation gate hook for ChatCoordinator.
//
// Exposes a small surface so any emit path in ChatCoordinator can run
// its candidate source_ids through the Rust-authoritative validator
// BEFORE the answer is committed to the chat row + RunEventLog.
//
// Wiring follow-up (documented in
// docs/audits/EIDOS_PRODUCTION_BINDING_2026_05_23.md): the existing
// ChatCoordinator emit paths are NOT yet calling this gate. The 5606-
// line ChatCoordinator file is being decomposed in Terminal B; that
// terminal owns the call-site wiring. This file lands the gate
// surface so Terminal B's wiring is a one-line addition per call
// site, not a cross-terminal contract negotiation.
//
// **Tier:** Tier 1 (MAS).
// **7-Law focus:** Law 4 Lattice-error (forged citations rejected
//   closed), Law 7 Witness (the validation result IS the witness).
// **W-row advance:** W-47.
// **§No-Orphan:** the gate is the seam where the EidosContextPacket
//   data class (UAS-bound, plane=Verification, residency=Hot,
//   WBO=N/A, WRV=product-facing) becomes citable from the chat layer.

import Foundation
import os

extension ChatCoordinator {

    /// Outcome of a chat-emit citation gate run. Higher level than the
    /// raw bridge call: tells the emit path EXACTLY what to do.
    public enum EidosCitationGateOutcome: Sendable {
        /// Every candidate source_id validates against the packet. The
        /// chat row may emit, with the closed-citation envelope sealed.
        case proceed

        /// At least one candidate source_id is forged or
        /// manifest-mismatched. The chat row MUST NOT emit; rewrite or
        /// drop instead. The first offending error is included so
        /// rejection diagnostics can surface a precise message.
        case rejectAndDrop(EidosCitationError)

        /// The bridge failed (decode error, FFI error). Falls back
        /// conservatively — caller decides whether to (a) skip Eidos
        /// validation (closed-citation contract NOT enforced this
        /// answer; surface honestly) or (b) abandon the answer.
        case bridgeUnavailable(String)
    }

    /// Run a candidate source_id list through the Rust-authoritative
    /// closed-citation validator. Call this BEFORE committing the
    /// chat row + appending the answer to RunEventLog.
    ///
    /// Returns `.proceed` only if every candidate validates against
    /// `packet`. Returns `.rejectAndDrop(_)` on the first
    /// `FabricatedSourceId` or `ManifestMismatch`. Returns
    /// `.bridgeUnavailable(_)` if the FFI itself fails (the chat
    /// layer is responsible for deciding whether to abandon the
    /// answer; per the chip-strip honest-language pattern, an
    /// `unavailable` outcome MUST be surfaced — not silently
    /// swallowed).
    nonisolated public static func runEidosCitationGate(
        packet: EidosContextPacket,
        candidateSourceIds: [EidosChunkId]
    ) -> EidosCitationGateOutcome {
        let outcome = EidosBridge.validateCitations(
            packet: packet,
            sourceIds: candidateSourceIds
        )
        switch outcome {
        case .accepted:
            return .proceed
        case .rejected(let err):
            Logger(subsystem: "com.epistemos", category: "eidos.gate")
                .error("Eidos closed-citation gate REJECT — \(String(describing: err), privacy: .public)")
            return .rejectAndDrop(err)
        case .bridgeFailure(let msg):
            Logger(subsystem: "com.epistemos", category: "eidos.gate")
                .notice("Eidos closed-citation gate bridge unavailable — \(msg, privacy: .public)")
            return .bridgeUnavailable(msg)
        }
    }

    /// Convenience: build candidate `EidosChunkId`s from a raw string
    /// list (the legacy chat surface emits source ids as opaque
    /// strings). Skips empty entries.
    nonisolated public static func eidosChunkIds(fromRawStrings raw: [String]) -> [EidosChunkId] {
        raw.compactMap { EidosChunkId($0) }
    }
}
