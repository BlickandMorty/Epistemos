# Biometric Lock Doctrine - 2026-05-17

Status: Phase 0 doctrine only. Implementation gate is closed until §4.A, §4.E/F, and §4.C audit pass each have a landed PR on `main`.

Scope lock: this document is the only allowed Phase 0 artifact for T8. Phase B code surfaces remain locked.

## Source Stack

- User seed doctrine: `~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md`, read cover-to-cover on 2026-05-17.
- Local prompt: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.D.
- Local rules: `CLAUDE.md`, especially Keychain-only credentials and single in-process substrate constraints.
- Apple LocalAuthentication: <https://developer.apple.com/documentation/localauthentication>
- Apple LAContext: <https://developer.apple.com/documentation/localauthentication/lacontext>
- Apple LAPolicy: <https://developer.apple.com/documentation/localauthentication/lapolicy>
- Apple `LAPolicy.deviceOwnerAuthenticationWithBiometrics`: <https://developer.apple.com/documentation/localauthentication/lapolicy/deviceownerauthenticationwithbiometrics>
- Apple SecAccessControl flags: <https://developer.apple.com/documentation/security/secaccesscontrolcreateflags>
- Apple `biometryCurrentSet`: <https://developer.apple.com/documentation/security/secaccesscontrolcreateflags/biometrycurrentset>
- Apple Secure Enclave: <https://support.apple.com/guide/security/secure-enclave-sec59b0b31ff/web>
- Apple Keychain data protection: <https://support.apple.com/guide/security/keychain-data-protection-secb0694df1a/web>
- Apple biometric security: <https://support.apple.com/guide/security/biometric-security-sec067eb0c9e/web>

## §5.0 Reconciliation Snapshot

Verified in the live T8 worktree before writing:

- `Epistemos/Sovereign/SovereignGate.swift` is the current single LocalAuthentication owner: `LAContext` is created there, with `.deviceOwnerAuthenticationWithBiometrics` and `.deviceOwnerAuthentication` policy routing.
- `agent_core/src/research/biometric_gate.rs` exists as a two-tier `BiometricWriteGate` research substrate for high-stakes writes, not as a content-lock system.
- `agent_core/src/cognitive_dag/macaroons.rs` exists and supports caveats through `AdditionalContext`, but there is no first-class `LockedContentGate` caveat yet.
- `Epistemos/Models/SDPage.swift` already has `isLocked: Bool`, but `rg isLocked` shows no production readers outside the model declaration.
- `SDChat` and `SDMessage` have no lock-state fields yet.
- `SearchIndexService`, `ShadowSearchService`, `SpotlightIndexer`, and `NoteEntitySpotlightIndexer` currently do not filter or deindex locked content.

## §1 Threat Model

Skeleton:

- Defend against casual local disclosure: shoulder surfing, shared device use, and accidental list/search previews.
- Defend against agent-context leakage: locked notes, chats, code blocks, vault entries, and provenance rows must not be serialized into local or cloud model prompts unless explicitly unlocked for the current session.
- Defend against index leakage: locked content must be absent from FTS5, Halo shadow, and Spotlight surfaces unless unlocked under a bounded capability.
- Defend against biometric overclaiming: biometric authenticates the device owner and gates key access; it does not itself encrypt content.
- Non-goal: biometric lock is not a defense against an already-compromised user session with arbitrary code execution. The doctrine still reduces blast radius through Keychain/Secure Enclave-bound material and index isolation.

## §2 Crypto Floor

Skeleton:

- Use Secure Enclave / Keychain integration for non-exportable or Keychain-protected wrapping material.
- Use `SecAccessControl` with `biometryCurrentSet` where enrollment-change invalidation is required.
- Use `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` for strict biometric unlocks and `.deviceOwnerAuthentication` only for documented recovery or accessibility fallback paths.
- Store credentials and recovery secrets in Keychain only. Never UserDefaults.
- Content encryption must use standard authenticated encryption; biometric gates unwrap or key access, not ciphertext semantics.

## §3 What Can Be Locked

Skeleton:

- Notes: `SDPage` and Epdoc documents, including code-block embeds.
- Chats: `SDChat` threads and `SDMessage` content.
- Code: Epdoc code blocks, generated artifacts, and code-answer snippets.
- Ambient session logs: capture-derived private memory and replayable run traces.
- Provenance rows: rows whose payload would reveal locked content or sensitive actions.
- Vault entries: individual vault files and entire vaults as workspace-level locks.

## §4 Session Model

Skeleton:

- Default: per-item unlock with a sticky five-minute reveal window scoped to that item and surface.
- Fresh biometric required for changing lock state, exporting locked content, or granting agent/session reveal.
- Recovery or device-password fallback must be explicit, audited, and visibly weaker than strict biometric unlock.
- Unlock tokens are capabilities, not global UI flags.

## §5 Agent Isolation

Skeleton:

- Locked content never enters `AgentLoop`, prompt builders, tool outputs, memory search results, or cloud payloads unless the user unlocks it and grants a per-session reveal.
- The T2 macaroon layer must gain a `LockedContentGate` constraint or equivalent first-class caveat.
- Agent reveal grants must bind at least: entity id, content kind, requester, model boundary, session id, issue time, expiry, and purpose string.
- Any missing or stale lock-state lookup fails closed.

## §6 Indexing Isolation

Skeleton:

- `SearchIndexService` must consult lock state before inserting into `indexed_pages`, `indexed_blocks`, `page_search`, `block_search`, and `readable_blocks`.
- `fusedSearch` and `fusedSearchAsync` must filter locked rows even if stale indexed rows exist.
- `ShadowSearchService` and the Rust shadow backend must exclude locked material from lexical, vector, and RRF result paths.
- `SpotlightIndexer` and `NoteEntitySpotlightIndexer` must deindex locked content and must not donate locked `NoteEntity` rows.
- Lock toggles trigger immediate deindex, cache purge, and later reindex only after unlock or unlock-scoped indexing is explicitly allowed.

## §7 UI/UX

Skeleton:

- Every lockable row needs a lock affordance and locked-state badge.
- Lists should show a count or placeholder for hidden locked items without exposing titles, snippets, tags, or embeddings.
- Unlock sheet uses the central biometric authority path, not ad hoc `LAContext` calls.
- Biometric failure is graceful and retryable, preserving user flow without leaking the protected item.
- The UI must differentiate "not found" from "locked items hidden" without revealing item identity.

## §8 Recovery

Skeleton:

- Recovery code must provide at least 128 bits of entropy.
- Recovery secrets live in Keychain / iCloud Keychain when enabled, with a printed recovery code option.
- Device replacement and biometric enrollment changes require re-establishing trust and rewrapping keys.
- Recovery operations are audited and cannot silently unlock agent, search, or Spotlight exposure.

## §9 Open Theorems

Skeleton:

- Prove locked content cannot reach `AgentLoop` context under all prompt-building and tool-output paths.
- Prove locked content cannot appear in FTS5, Halo shadow, or Spotlight under concurrent edits and lock toggles.
- Prove stale index rows are removed or filtered before any user-visible result can expose them.
- Prove biometric failure paths are retryable and non-leaking.
- Prove recovery-code entropy is at least 128 bits and that recovery does not bypass lock-state audit.
