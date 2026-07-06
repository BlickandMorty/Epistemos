// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// EXTENSION DELTA, NOT A REWRITE. The LIVE CompanionModel.swift is 479 lines: @Model with
// id(.unique)/name/tagline/bodyKindRaw/accentHex/identityHash/createdAt/lastInteractedAt/archivedAt
// + the CompanionBodyKind grammar. Lifecycle lives in CompanionState.swift (create/update/archive/
// restore/purge/activate/reloadRoster/seedDefaultIfEmpty). RULES:
//  1. ADD the new fields (personaPreamble, baseModel, provider, vaultMcpScope, boundAuthorities,
//     embodiedEditingOptIn) as OPTIONAL or DEFAULTED properties → SwiftData lightweight migration.
//     Never rename/remove/retype existing fields (no VersionedSchema exists; users have rows —
//     seedDefaultIfEmpty guarantees at least one).
//  2. DOCTRINE AMENDMENT IS EXPLICIT: the live file's v1.6 comment (:7-11, "does not own model,
//     prompt, tool, MCP, approval, or autonomous runtime authority") is DELIBERATELY superseded —
//     rewrite that comment in the same commit to the new bound-vs-gated doctrine (gating.rs).
//  3. Coupled call sites to update: CompanionRosterEntry(from:) (CompanionState.swift:287-297),
//     CompanionCreationFlow.swift:322 preview constructor (file slated for deletion — K7),
//     identityHash recompute (updateCompanion :99), DeterministicPRNG seed contract.
// ════════════════════════════════════════════════════════════════════════════════════════════════
//  CompanionModel.swift
//  EPI-RP-05-KINDRED · D5 creation/management (BINDING)
//
//  Extends the existing SwiftData @Model with the authority doctrine. This is the durable
//  identity of a companion, stable across all four surfaces via `identityHash`. The old
//  CompanionCreationFlow.swift is DELETED; creation/management moves into 1Code (D5).
//
//  Platform hygiene: provider secrets live in Keychain, NEVER in this model / UserDefaults.

#if KINDRED_ENABLED
import SwiftData
import Foundation

@Model
final class CompanionModel {
    // Identity (existing).
    var name: String
    var tagline: String
    var bodyKind: String          // selects the Rive artboard/variant
    var accent: String            // hex accent color
    var identityHash: String      // stable identity across surfaces + sessions

    // Authority doctrine (the evolution from "cosmetic-only v1.6").
    var personaPreamble: String
    var baseModel: String
    var provider: String          // secret is in Keychain, keyed by identityHash
    var vaultMcpScope: String     // persona-scoped READ scope
    var boundAuthoritiesRaw: [String]   // encoded BoundAuthority cases
    var embodiedEditingOptIn: Bool      // D10 opt-in/auto

    // Lifecycle (existing create/archive/trash).
    var createdAt: Date
    var archivedAt: Date?
    var trashedAt: Date?

    init(
        name: String,
        tagline: String,
        bodyKind: String,
        accent: String,
        identityHash: String,
        personaPreamble: String,
        baseModel: String,
        provider: String,
        vaultMcpScope: String
    ) {
        self.name = name
        self.tagline = tagline
        self.bodyKind = bodyKind
        self.accent = accent
        self.identityHash = identityHash
        self.personaPreamble = personaPreamble
        self.baseModel = baseModel
        self.provider = provider
        self.vaultMcpScope = vaultMcpScope
        self.boundAuthoritiesRaw = []
        self.embodiedEditingOptIn = false
        self.createdAt = .now
    }

    var isActive: Bool { archivedAt == nil && trashedAt == nil }

    func archive() { archivedAt = .now }
    func trash()   { trashedAt = .now }

    // TODO: obligation-history relation (reads back from the provenance ledger).
    // TODO: authority-adjustment methods (all gated actions stay per-turn).
}
#endif
