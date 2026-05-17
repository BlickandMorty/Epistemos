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

Agent isolation is stricter than human UI reveal. An item open on screen is not automatically available to an agent, tool, local model, cloud provider, background job, or session compactor. Agent access requires a separate reveal grant.

### Current Agent Ingress Points

- `AgentLoop` preloads vault context into `context_notes` and then builds the system prompt with that material.
- `knowledge_index.md` can be read from the vault and injected into the system prompt.
- `vault_recall` returns paths, snippets, scores, and tags.
- `session_search` scans `<vault>/sessions/*/transcript.jsonl` and returns session metadata.
- Tool results can re-enter the next model turn as context.
- Provider dispatch can cross from local inference to cloud inference depending on routing and mode.

Every one of those ingress points needs a lock check before plaintext or sensitive derived metadata is serialized.

### Required Dispatch Gate

- Add a first-class `LockedContentGate` macaroon constraint in the T2 capability layer. `AdditionalContext` can express opaque policy today, but §4.D needs a typed caveat so tests can prove it cannot be omitted or misspelled.
- The gate checks entity id, entity kind, vault id, lock generation, requester, model boundary, and expiry before any tool or prompt path touches locked content.
- The gate must run before retrieval output formatting. Returning a locked snippet and hoping the prompt builder filters it later is a leak.
- The gate must run again at provider dispatch. A grant for local-only reveal does not authorize cloud egress.
- The gate must run in compaction/summarization. A transcript summary cannot retain facts from content whose reveal grant expired.

### Agent Reveal Classes

- **No reveal:** default. Agent sees only aggregate placeholders such as locked item counts.
- **Local ephemeral reveal:** local model/tool path may read one entity for one app session and TTL.
- **Cloud ephemeral reveal:** explicit, separate grant that includes provider family and purpose.
- **Tool-output reveal:** allows a tool to return locked content to the human UI but not to the next model turn unless model context is also granted.
- **Background reveal:** normally disallowed. Any future NightBrain/background path needs its own wake-safe grant with a short TTL and audit reason.

### Fail-Closed Rules

- Missing lock table, missing Keychain item, stale generation, expired grant, unsupported entity kind, unknown provider boundary, or lookup timeout all resolve to "locked".
- Denials return structured placeholders, not raw errors that include titles, paths, snippets, tags, or transcript text.
- Provenance may record that a locked reveal was requested, allowed, denied, or expired, but the provenance row must not include locked arguments/results unless it is itself locked.
- Delegated/sub-agent context inherits the narrowest parent grant. Delegation can only reduce scope.

## §6 Indexing Isolation

Index isolation is a write-time and read-time invariant. Write-time exclusion prevents new leaks. Read-time filtering handles stale rows, migration gaps, crash recovery, and older databases that predate lock support.

### Current Index Planes

- **In-app FTS:** `SearchIndexService` writes `indexed_pages`, `indexed_blocks`, `page_search`, and `block_search`.
- **Readable block projection:** `ReadableBlocksIndex` writes `readable_blocks` and `readable_blocks_fts`, which can expose block text independently of page FTS.
- **Fused retrieval:** `RRFFusionQuery` combines page, block, and readable-block hits; `fusedSearch` and `fusedSearchAsync` must not trust source tables to be clean.
- **Shadow/Halo search:** `ShadowSearchService` and the Rust shadow backend can hold lexical text, vector payloads, RRF candidates, and panel snippets.
- **Spotlight:** `SpotlightIndexer` donates legacy `CSSearchableItem` payloads; `NoteEntitySpotlightIndexer` donates typed App Intents entities on newer macOS.

### Write-Time Exclusion

- A locked payload is never inserted into `indexed_pages`, `indexed_blocks`, `page_search`, `block_search`, `readable_blocks`, `readable_blocks_fts`, shadow lexical/vector stores, or Spotlight donation queues.
- Locking an entity is a purge operation before it is a UI state change: delete FTS rows, delete readable-block rows, remove shadow entries, delete Spotlight identifiers, clear snippet caches, and only then report the lock toggle as committed.
- Parent locks purge child projections. Child locks purge parent-derived snippets, summaries, title paths, and graph edges that would reveal the child.
- Index workers treat missing lock state, unreadable lock state, migration mismatch, lookup timeout, or Keychain unavailability as locked.
- Background bootstrappers, including shadow bootstrap, must run the same lock filter as foreground indexing. Initial crawl is not a privileged bypass.

### Read-Time Filtering

- Every search query path joins or consults the lock table immediately before returning rows. This includes FTS hits, RRF candidates, shadow results, app entity donations, "recent" panels, autocomplete, and related-note lists.
- Stale indexed rows are expected during migration and crash recovery; user-visible result assembly must filter them even if the underlying FTS table still contains plaintext.
- Denied rows collapse to aggregate placeholders such as "3 locked results hidden." They do not expose title, path, tag, timestamp, snippet, score, embedding cluster, or provenance summary.
- Unlocking a visible result requires an item-scoped reveal grant. A search-scoped grant may reveal existence counts, but not plaintext snippets unless the result entity itself is revealed.
- Spotlight is stricter than in-app search: persistent system search should not receive locked plaintext even during a reveal window unless Phase B explicitly adds a separately audited, temporary, and revocable donation mode. Default doctrine is no persistent Spotlight indexing for locked content.

### Derived Data Isolation

- Embeddings, summaries, keywords, tags, highlights, semantic clusters, graph edges, backreferences, title paths, and ranking features inherit the strongest lock of their source material.
- A derived row from multiple sources is locked if any source is locked and the row cannot be safely decomposed into unlocked facts.
- Provenance generated by indexing may record counts and purge status, but not locked path names, titles, snippets, or payload hashes that function as lookup handles.
- Exported indexes, debug dumps, telemetry envelopes, and migration logs follow the same rule as live indexes.

### Reindex and Recovery Protocol

- Lock toggles enqueue an idempotent purge job keyed by entity id, entity kind, vault id, and lock generation. The app resumes unfinished purge jobs before accepting search or Spotlight queries after restart.
- Unlock does not automatically make content indexable. Persistent reindexing requires an explicit policy decision for that entity class; the safer default is human-readable reveal without persistent derived rows.
- Re-locking increments lock generation and invalidates all pending index jobs and stale reveal-scoped rows from the prior generation.
- Crash recovery scans for locked entities with residual index rows and purges them before rebuilding ordinary search.
- Acceptance tests must seed stale FTS, readable-block, shadow, and Spotlight rows and prove that all user-visible retrieval paths either purge or filter before returning results.

## §7 UI/UX

The UI contract is simple: locked content is visible as a state, never as plaintext. The app may show that private material exists when the user is already in a relevant workspace, but it must not reveal names, snippets, paths, tags, previews, embeddings, or inferred relationships without a reveal grant.

### Primary UI Surfaces

- **Notes sidebar:** `FileRow` and `SearchResultRow` need locked badges, disabled previews, and context-menu actions for lock/unlock. Search rows must not show snippets or tags for locked matches.
- **Note editor:** `NoteDetailWorkspaceView` / Prose editor surfaces show a locked placeholder until the item reveal grant exists. The editor must not initialize editable text storage with locked plaintext before authorization.
- **Chat sidebar:** `SidebarChatRow` currently renders title, assistant preview, linked-note glyphs, and relative timestamps. Locked chats require redacted row text and no assistant preview.
- **Chat transcript:** `MessageBubble`, context attachment badges, thinking trails, source references, and attachment previews must all respect message/artifact lock state independently of the parent chat.
- **Artifact cards:** `ArtifactBlockView` copy/export/expand controls require fresh authorization for locked artifacts; collapsed headers cannot reveal artifact titles or languages if those fields derive from locked content.
- **Epdoc:** `EpdocEditorToolbar`, block gutters, slash/bubble menus, attached-thought badges, and complexity meters must not expose locked block text or derived metrics.
- **Graph and Halo:** `HologramSearchSidebar`, node inspectors, pinned inspectors, relationship browsers, and graph labels must redact locked nodes and edges according to §6 derived-data isolation.
- **Session browser:** `SessionListView` and session detail summaries must treat agent runs and summaries as lockable payloads, not merely logs.

### Visual States

- **Unlocked:** normal title/body/snippet rendering while the item-scoped reveal grant is valid.
- **Locked hidden:** list/search surfaces show an aggregate placeholder or generic locked row without title, emoji, tag, snippet, path, timestamp precision, or graph neighborhood.
- **Locked selected:** editor/transcript/detail panes show a generic locked-items placeholder with a single unlock affordance.
- **Unlock pending:** sheet is active; underlying content remains redacted.
- **Unlock failed:** same redacted view, with retry available. Failure text must not include protected titles, paths, or snippets.
- **Unavailable/recovery needed:** same redaction, plus a recovery entry point when Keychain item, biometric enrollment, or device trust changed.

### Unlock Flow

- All unlock UI calls the central biometric authority path. No view, row, toolbar, context menu, or AppKit bridge creates its own `LAContext`.
- The unlock sheet mints a scoped reveal grant with entity id, entity kind, vault id, surface, requester, lock generation, policy, and TTL. The view updates only after grant verification.
- A UI reveal grant is not an agent reveal grant. Opening a locked note on screen does not authorize `AgentLoop`, retrieval, summarization, graph chat, export, copy, Spotlight donation, or cloud dispatch.
- Copy, export, share, file edit materialization, lock toggle, recovery reset, and key rotation require fresh authentication, even if the body is already visible.
- Unlock prompts are user-initiated. Background indexers, graph refresh, hover previews, and search typing cannot surprise-prompt for biometrics.

### Failure and Accessibility

- Biometric failure is graceful and retryable. The user remains on the same locked placeholder; no navigation side effect should imply whether a specific hidden row matched.
- Cancellation is a normal denial, not an error toast containing protected metadata.
- Device-owner fallback is labeled as fallback/recovery and audited separately from strict biometric unlock.
- VoiceOver labels and accessibility values use generic locked text. Accessibility APIs must not receive the hidden title or snippet as an offscreen label.
- Reduced-motion and keyboard-only flows must reach lock/unlock actions without relying on hover-only controls.

### "Not Found" vs "Locked Hidden"

- Search and graph surfaces may say that locked results are hidden as an aggregate count when the query ran in a workspace where such a count is already authorized.
- Detail navigation to a known id may show "locked" instead of "missing" after the caller proves it already had that id.
- Public/global search, Spotlight, autocomplete, and provider-facing tool results should prefer "not available" over existence disclosure unless a reveal grant covers existence.
- Empty states must avoid teaching the user sensitive facts through timing, counts, sort gaps, or section labels.

## §8 Recovery

Recovery is a second authority path for key rewrapping, not a hidden global unlock. It exists because strict `biometryCurrentSet` locks can become unavailable after biometric enrollment changes, hardware replacement, Keychain loss, or accessibility fallback. The recovery path must be explicit, auditable, and narrower than normal unlock.

### Current Substrate Constraint

- `Epistemos/Engine/Keychain.swift` is credential-focused and stores ordinary generic-password items with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- There is no existing biometric-lock recovery service, recovery-code generator, recovery-code verifier, or lock-key rewrap flow in the live tree.
- Existing UUID and ULID-style helpers are identity generators, not recovery secrets. Recovery codes need dedicated CSPRNG bytes and tests that measure entropy directly.

### Recovery Secret Floor

- A printed or copied recovery code contains at least 128 bits of entropy. Minimum raw form: 16 CSPRNG bytes before checksum/encoding. Preferred operational floor: 20 or 32 random bytes to allow grouping and checksum without ambiguity.
- Recovery code generation uses system CSPRNG (`SecRandomCopyBytes` or an equivalent audited system source), never `UUID`, timestamps, usernames, vault paths, or model-derived randomness.
- Encoded codes use human-resistant formatting such as grouped Crockford Base32 with checksum. Formatting characters and checksum do not count toward the entropy floor.
- The app stores only a verifier or wrapped recovery secret, not the display recovery code. Verifiers live in Keychain or an encrypted lock metadata envelope and are bound to vault id, lock generation, and recovery version.
- Recovery attempts are rate-limited and audited, but logs must not store the code, verifier, locked title, path, or content hash.

### Trust Re-Establishment

- **Biometric enrollment changed:** strict `biometryCurrentSet` Keychain items may become inaccessible. Recovery can unwrap the vault/entity recovery key, require device-owner authentication, then rewrap content keys under the new biometric set.
- **Device replacement:** recovery proves possession of the recovery code, then establishes a new device trust binding and rewraps keys. The old device binding is not assumed valid.
- **No-biometry or accessibility path:** `.deviceOwnerAuthentication` may mint fallback grants, but the UI labels them as fallback and the audit trail records the lower assurance.
- **Keychain unavailable:** content remains locked until recovery succeeds. Missing Keychain item is not treated as "decrypt with cached plaintext."
- **Recovery reset:** changing the recovery code requires fresh biometric or existing recovery proof, rotates recovery material, increments recovery version, and invalidates pending recovery grants.

### Recovery Grant Limits

- Recovery may authorize key rewrap, lock-state repair, and one human reveal needed to verify success.
- Recovery does not automatically authorize agent reveal, cloud egress, search snippets, persistent reindex, Spotlight donation, export, or share.
- After recovery, all derived planes remain in locked/purged state until the user explicitly unlocks or opts into reindexing under the normal rules.
- A recovery grant is short-lived, item/vault-scoped, and bound to the recovery version and lock generation.
- Recovery should be possible offline for local-first use. Any optional iCloud Keychain sync improves availability but is not a required trust anchor.

### Audit and UX

- The app records recovery start, success, failure, cancellation, rate-limit, key rewrap, and recovery reset as structured events with non-sensitive ids.
- Recovery UI must explain the consequence precisely: it restores access or rewraps keys; it does not weaken future biometric requirements unless the user explicitly chooses a fallback policy.
- Failed recovery is retryable after rate limits without leaking whether a specific locked item exists.
- When recovery succeeds after biometric enrollment change, the user should be prompted to rotate affected lock keys if rewrap did not already do so.

### Tests

- Property tests generate many recovery codes and assert raw entropy is at least 128 bits before encoding/checksum.
- Tests reject UUID-derived, timestamp-derived, short, reused, malformed, and checksum-invalid recovery codes.
- Enrollment-change tests simulate inaccessible `biometryCurrentSet` items and prove recovery rewraps without exposing plaintext to search, Spotlight, or agent context.
- Device-replacement tests prove new trust binding does not accept stale reveal grants from the prior device.

## §9 Open Theorems

Skeleton:

- Prove locked content cannot reach `AgentLoop` context under all prompt-building and tool-output paths.
- Prove locked content cannot appear in FTS5, Halo shadow, or Spotlight under concurrent edits and lock toggles.
- Prove stale index rows are removed or filtered before any user-visible result can expose them.
- Prove biometric failure paths are retryable and non-leaking.
- Prove recovery-code entropy is at least 128 bits and that recovery does not bypass lock-state audit.
