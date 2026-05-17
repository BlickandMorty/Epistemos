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

The lock boundary defends a local-first personal knowledge workspace against accidental, ambient, and agentic disclosure. It is not a magic word for absolute secrecy. The invariant is narrower and testable: once an entity is locked, plaintext must not be visible to normal UI, search, Spotlight, model-context, export, sync, or provenance surfaces until a valid unlock capability exists for that exact entity and session.

### In-Scope Attacks

- **Shoulder surfing and shared-device browsing.** Lists, recents, search snippets, Spotlight previews, chat transcript rows, and editor chrome must not reveal locked titles, bodies, code snippets, tags, embeddings, or generated summaries. Apple LocalAuthentication is the user-presence check; Epistemos still owns the UI redaction policy.
- **Accidental agent-context leakage.** `agent_core/src/agent_loop.rs` currently preloads vault context and builds the system prompt with `context_notes`; locked material must be filtered before preload, retrieval, tool result serialization, prompt hooks, and cloud escalation. If any lock-state lookup is unavailable, the agent path fails closed.
- **Index leakage.** `SearchIndexService` has page/block/readable-block FTS paths, `ShadowSearchService` delegates to Halo shadow search, and Spotlight has both legacy `CSSearchableItem` and `NoteEntity` donation paths. A locked entity must be absent from all four user-visible retrieval planes: in-app FTS, fused search, Halo/shadow, and macOS Spotlight.
- **Device sharing while the macOS account is already unlocked.** FileVault and system login protect the device before account unlock; §4.D protects Epistemos content after the account is open and someone else can touch the app.
- **Subpoena and forensic posture, bounded.** Locking should reduce plaintext-at-rest, index, and provenance exposure by keeping locked payload keys behind Keychain/Secure Enclave policy and by excluding derivative indexes. It does not create legal privilege, and it cannot hide content that was exported or synced in plaintext before locking.
- **iCloud Drive or backup snapshot leakage.** `SDPage` uses `filePath` and sidecar markdown storage today. Phase B must ensure locked payloads are encrypted or replaced with non-sensitive placeholders before any iCloud-backed or user-visible file export path sees them.
- **Biometric prompt spoofing and prompt fatigue.** Only the central biometric authority path may invoke `LAContext`. UI leaves must request a scoped unlock or reveal grant; they must not instantiate their own LocalAuthentication prompt.

### Out-of-Scope Attacks

- Arbitrary code execution inside the user account, kernel compromise, or malicious assistive tooling with full disk and process memory access.
- A device owner who intentionally unlocks and exports content outside Epistemos.
- Plaintext that already escaped into previous indexes, backups, logs, screenshots, or cloud requests before the lock was applied. Phase B must include purge/reindex tests, but retroactive external deletion is not guaranteed.
- Social/legal compulsion. The system can make access auditable and scoped; it cannot decide whether the user should comply.

### Trust Boundary

Apple's frameworks supply hardware-rooted user authentication and Keychain access-control enforcement. Epistemos supplies every application-level invariant around content selection, lock state, prompt assembly, indexing, and recovery. Therefore "locked" means both conditions hold:

1. The user or recovery holder has passed an allowed LocalAuthentication / Keychain access-control path for this entity and session.
2. Every Epistemos surface that could expose plaintext recognizes the entity's lock state and either redacts, filters, deindexes, or refuses to serialize it.

If either condition is missing, the entity remains locked.

## §2 Crypto Floor

The cryptographic floor is deliberately boring: standard authenticated encryption for content, Keychain access control for key release, and LocalAuthentication for user-presence proof. Biometric is an authorization gate over key access. It is not an encryption algorithm.

### Current Substrate Constraint

`Epistemos/Engine/Keychain.swift` stores credential strings through Security.framework and prefers the Data Protection keychain, but its item shape uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and does not yet use `SecAccessControl` or `.biometryCurrentSet`. That helper remains valid for API credentials. Locked-content keys need a new Phase B service so the content-lock contract is not silently downgraded to ordinary credential storage.

### Required Key Hierarchy

- Each lockable payload gets a random content-encryption key, generated with system CSPRNG and never derived from the biometric itself.
- Payload plaintext is encrypted with authenticated encryption. The associated data binds at least entity id, entity kind, vault id, schema version, lock generation, and created/updated timestamp.
- Content keys are wrapped or stored as Keychain secrets with access control requiring biometric release. For strict biometric locks, use `SecAccessControl` with `biometryCurrentSet` so adding/removing enrolled biometrics invalidates the item.
- Vault-level locks may use a vault wrapping key that wraps per-entity content keys. Per-entity lock toggles still need independent lock state so a vault unlock cannot become a global invisible bypass.
- The app never stores raw biometric data, templates, or assertions. Apple's LocalAuthentication result is a Boolean/authentication outcome; Epistemos stores only scoped capability facts and audit rows.

### Policy Split

- **Strict biometric unlock:** `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` plus Keychain access control for key release. This is the default for normal locked content.
- **Device-owner fallback:** `.deviceOwnerAuthentication` is allowed only for documented recovery, accessibility, or no-biometry hardware paths. Any fallback path is visibly labeled and audited.
- **Fresh biometric:** required for locking/unlocking an entity, exporting locked plaintext, granting agent reveal, rotating a lock key, changing recovery settings, or reindexing previously locked content into a derived plane.
- **No prompt cache for destructive crypto changes:** cached reveal windows may cover reading an already-unlocked item, but key rotation, recovery reset, and permanent decryption/export require fresh authentication.

### Persistence Rules

- Credential secrets and lock recovery material live in Keychain only. UserDefaults may store nonsensitive preferences and UI state, never content keys, recovery codes, OAuth secrets, API keys, or plaintext lock metadata.
- Locked content must not remain as plaintext sidecar markdown, cached snippets, searchable body columns, Spotlight payloads, provenance JSON, or crash-report strings.
- Encryption failure, missing Keychain item, biometric enrollment change, or corrupted associated data all fail closed as "locked/unavailable", never as "show stale plaintext."
- Key rotation creates a new lock generation and re-encrypts the payload before old key material is deleted. Reindexing waits until the new lock state is committed.
- Memory zeroization is best-effort in Swift/Rust. The security boundary is at-rest encryption plus index/prompt exclusion, not a claim that process memory cannot contain plaintext while an item is open.

## §3 What Can Be Locked

Lock targets are typed entities, not arbitrary UI rows. A UI row may be a projection of several lock targets, and the safest outcome is always the most restrictive target in that projection.

### Primary Lock Targets

- **Note page:** `SDPage` plus its vault markdown sidecar and graph/search projections. Existing `SDPage.isLocked` is only a dormant flag until it has readers, encryption, and index behavior.
- **Epdoc document:** `.epdoc` package content, manifest, projections, assets, and exports. Code blocks inside ProseMirror JSON are lockable either through the parent document or as addressable blocks when block identity exists.
- **Chat thread:** `SDChat` metadata and membership. Locking a thread hides the row, title, linked note id, and message count except for aggregate locked placeholders.
- **Chat message:** `SDMessage.content`, `contentBlocksData`, `thinkingTrace`, attachments, artifacts, loaded-note/context attachment metadata, and analysis fields that summarize private content.
- **Chat artifact:** `Artifact` rows stored in `SDMessage.artifactsData`, including JSON/YAML/CSV/code/table/markdown/file-edit payloads. Code artifacts may also materialize as files and must inherit the lock.
- **Typed artifact route:** `ArtifactKind` cases: `proseNote`, `document`, `rawThought`, `source`, `code`, `run`, and `output`. Any route that can open or preview payload text is lock-aware.
- **Code file/artifact:** `CodeArtifactKind`-classified files, code fences extracted by `ArtifactExtractor`, Epdoc code blocks, generated file edits, and terminal/build outputs.
- **Agent run/session:** `SessionFolder` under `vault_root/sessions/`, including `session.json`, `transcript.jsonl`, `trace.json`, artifacts, summaries, reasoning metrics, and compacted context.
- **Provenance event:** `AgentProvenanceEvent` and `AgentToolProvenance` rows when arguments, results, metadata, trace ids, or tool names reveal locked payloads or the existence of a sensitive operation.
- **Vault entry:** any vault-relative file or directory reachable through `VaultStore`, plus workspace-level vault locks that make every child target locked by inheritance.

### Derived Surfaces That Inherit Locks

- Search rows and snippets: `indexed_pages`, `indexed_blocks`, `readable_blocks`, FTS tables, RRF results.
- Shadow/Halo payloads: lexical text, vector embeddings, RRF candidates, and panel snippets.
- Spotlight payloads: `CSSearchableItem` attributes and `NoteEntity` donations.
- Graph surfaces: nodes, edges, title paths, vault filters, backlinks, wikilinks, and semantic clusters that would reveal locked text or sensitive relationship structure.
- Summaries and generated labels: AI summaries, evidence grades, confidence notes, provenance summaries, and session summaries derived from locked content.
- Export/copy/share surfaces: markdown export, `.epdoc` export, file edits, clipboard actions, share links, and provider payloads.

### Inheritance Rules

- A parent lock hides every child unless a more specific child has its own explicit unlock grant.
- A child lock forces parent projections to redact derived text, counts, snippets, labels, and relationship hints that would reveal the child.
- Duplicated material inherits the strongest source lock. Example: a code fence extracted from a locked chat into a code artifact remains locked.
- Deleting a lock target must delete or tombstone its unlock grants before deleting payload bytes, so no stale grant can later bind to a reused id.

## §4 Session Model

The current Sovereign Gate has a 15-minute category grace for sensitive actions and clears that grace on app/system lifecycle boundaries. Biometric lock uses the same central authority pattern but a narrower reveal contract: item-scoped, shorter, and never interpreted as a general-purpose sensitive-action approval.

### Default Reveal Window

- Default reveal: one item, one user session, five minutes.
- The reveal window binds to entity id, entity kind, vault id, app session id, requesting surface, and lock generation.
- Revealing a note does not reveal its linked chat. Revealing a chat thread does not reveal extracted code artifacts unless those artifacts are children covered by the same lock generation.
- A vault-level unlock may reveal children for navigation, but child-level export, agent reveal, or reindex still requires a child-scoped capability check.

### Authentication Cadence

- **Per-view read:** may reuse the five-minute item reveal while the same app session and lock generation remain valid.
- **Per-search reveal:** search may show that locked hits exist only as aggregate placeholders. Showing titles/snippets requires item reveal, not a global "search unlocked" state.
- **Per-agent reveal:** agent access is separate from human UI reveal. The user must approve an agent/session reveal grant even if the item is currently open in the UI.
- **Every-time operations:** lock toggle, key rotation, recovery reset, plaintext export, share link, destructive delete of locked payload, and provider/cloud send require fresh authentication.
- **Fallback operations:** `.deviceOwnerAuthentication` is allowed for recovery/accessibility paths only and must mint a grant labeled as fallback, not strict biometric.

### Expiry and Revocation

- Reveal grants expire on TTL, lock generation change, vault switch, app relaunch, app hide/resign, system sleep, session resign, screen sleep, biometric enrollment change, or manual "Lock Now."
- `SovereignGate.clearGrace()` is not enough for §4.D. Phase B needs an independent lock-session revocation path that clears item reveal grants, agent reveal grants, decrypted body caches, search snippets, and Spotlight donation queues.
- Clock rollback fails closed. Existing biometric grace tests already reject rollback for SovereignGate; lock reveal grants must carry the same monotonic/absolute-time discipline.
- A failed biometric attempt grants no grace and leaves all previous locked placeholders unchanged.

### Capability Shape

Reveal state is a signed capability, not a UI boolean. Minimum fields:

- `grant_id`
- `entity_id`
- `entity_kind`
- `vault_id`
- `lock_generation`
- `surface`
- `requester` (`human_ui`, `agent_loop`, `search`, `export`, etc.)
- `issued_at`
- `expires_at`
- `policy` (`biometric_current_set`, `device_owner_fallback`, `recovery_code`)
- `purpose`

Any field mismatch means the grant does not apply.

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
