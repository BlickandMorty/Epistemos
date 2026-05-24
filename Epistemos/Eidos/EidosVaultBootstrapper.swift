// EidosVaultBootstrapper.swift
//
// Terminal A 2026-05-23 — App-level wire-up that opens the production
// Eidos vault index when the user attaches a vault.
//
// Scope-bounded by design: this file ONLY opens the vault index +
// derives a stable signature from the vault path. It does NOT crawl
// notes — that is Terminal B's scope (the W-19/W-20/W-21 Vault Recall
// Trace surface; the crawl loop will piggyback on the existing
// `ShadowVaultBootstrapper` to avoid double-walks). Until the crawl
// lands, `EidosBridge.insertVaultNote(...)` is called per-edit (by
// the EpdocAutosaveCoordinator hook documented in the audit doc).
//
// Why open at all when the index is empty? Two reasons:
//
//   1. The manifest id is `vault-<sig>`, so backend-detection flips
//      to `.real` the moment retrieve runs — closed-citation contract
//      now binds to the production manifest, not the fixture one. The
//      chat layer can call `EidosBridge.retrieve(...)` without first
//      hard-coding a vault open call.
//
//   2. The vault signature is stable across launches for the same
//      vault path, so cached citations remain valid across sessions
//      (manifest equality is the closed-citation membership key).
//
// **7-Law focus:** Law 2 Address, Law 7 Witness.
// **Tier:** Tier 1 (MAS).

import CryptoKit
import Foundation
import os

@MainActor
enum EidosVaultBootstrapper {
    private static let log = Logger(subsystem: "com.epistemos", category: "eidos.bootstrap")

    /// Last signature we opened the production index under. Used to
    /// avoid re-opening (and dropping insertions) when the same vault
    /// URL fires the readiness signal twice.
    private static var lastOpenedSignature: String?

    /// Open (or re-open) the production Eidos vault index for the
    /// given vault URL. Idempotent — re-calling with the same URL is
    /// a no-op once the index is open.
    @discardableResult
    static func openProductionIndexIfReady(vaultURL: URL?) -> EidosIndexManifestId? {
        guard let vaultURL else {
            if lastOpenedSignature != nil {
                log.info("Eidos vault index: closing — no active vault URL")
                EidosBridge.closeVaultIndex()
                lastOpenedSignature = nil
            }
            return nil
        }
        let sig = signature(for: vaultURL)
        if sig == lastOpenedSignature {
            return EidosIndexManifestId("vault-\(sig)")
        }
        guard let manifest = EidosBridge.openVaultIndex(signature: sig) else {
            log.error("Eidos vault index: open failed for signature=\(sig, privacy: .public)")
            return nil
        }
        lastOpenedSignature = sig
        log.info(
            "Eidos vault index: open OK signature=\(sig, privacy: .public) manifest=\(manifest.raw, privacy: .public)"
        )
        return manifest
    }

    /// SHA-256 hex digest of the vault path. Stable across runs for
    /// the same path; changes when the user picks a new vault.
    nonisolated static func signature(for vaultURL: URL) -> String {
        let path = vaultURL.standardizedFileURL.path
        let digest = SHA256.hash(data: Data(path.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Test hook — reset the open-signature cache so tests can
    /// re-exercise the open path without app restart.
    nonisolated static func _resetCacheForTests() {
        Task { @MainActor in
            lastOpenedSignature = nil
        }
    }
}
