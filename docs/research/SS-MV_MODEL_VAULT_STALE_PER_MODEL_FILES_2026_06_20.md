# SS-MV — Model Vault staleness + per-model file injection (granular control) (2026-06-20)

Owner (3 screenshots: knowledge_profile.md note, Models tab "Model Vaults", System tab): *"a lot of issues with the
model + system portion of the note site, particularly the model portion. All the files seem outdated and stale. When I
add files to a model I want it to be able to READ those files so users have granular control of how the model interprets
instructions and the code you give it — it's a subtle but very useful feature and I want to respect it. Harden it after
we clone the other surfaces so they can traverse those too, but right now particularly the chat part + the sidebar for
the System tab + the Models tab. A lot of staleness. The knowledge profile is outdated even if I'm using one model. Make
sure it's all fixed and hardened."* **CONFIRMED bug, code-grounded.** NON-INVASIVE; OUTSIDE the Companion→Osaurus
boundary (this is `Epistemos/KnowledgeFusion/*` + `Views/Sidebar/ModeModelVaults|ModeSystem/*` + `Views/Notes/ModelVaults*`,
NOT `Models/Companion/*`/`ActOsaurus/*`/`LocalModelServer.swift` — verified).

## Three confirmed root causes

### (1) STALENESS — only regenerated at bootstrap + manual button (no refresh on note change)
`KnowledgeProfileStore.save()` (`KnowledgeProfileStore.swift:37-51`) writes knowledge_profile.md / concept_index.md /
active_context.md / instructions.md / meta.json. The ONLY caller that compiles+saves is
`CloudKnowledgeDistillationService` (`compiler.compile(...)` `:102` → `store.save(vault)` `:119`), invoked from just TWO
places: bootstrap `AppBootstrap.swift:2347` (`rebuildAllModelVaults()`, once, behind a guard) + the manual refresh button
`ModelVaultsSettingsView.swift:188`. There is **no periodic / on-note-change / debounced refresh**, so the profile
freezes at its last compile ("last updated 2026-06-19/20" in the screenshot) while the vault's notes change daily — hence
"outdated even with one model." Also the only compiler is `CloudKnowledgeCompiler` (cloud-distillation-shaped); there's no
lightweight local recompute.
**Fix [M]:** add a refresh trigger that's NOT bootstrap-only — e.g. debounced recompile on vault note-count/mtime change
(observe the same signal the Domain Map counts come from), a staleness badge ("last updated… · Refresh") on each model
row, and a max-age auto-refresh (e.g. if older than N hours and the app is active/idle). Keep it cheap: recompute the
note-derived sections (Domain Map / Entity Graph / Writing-Style / concept_index / active_context) without requiring a
cloud round-trip where a local pass suffices. Honest "compiling…/last updated" state in the row.

### (2) LOCAL MODELS NEVER READ THE VAULT — injection is cloud-only (the core "granular control" break)
`KnowledgeProfileStore.augmentedSystemPrompt(existingPrompt:modelID:budget:)` (`:83-101`) prepends the vault context
(instructions + knowledge_profile + concept_index + active_context) to the system prompt. But it is called ONLY at
`LLMService.swift:1359` (cloud) + `AppleIntelligenceService.swift:282` (Apple Intelligence). A grep of the LOCAL MLX path
(`MLXInferenceService.swift`, `LocalAgent/LocalAgentPromptBuilder.swift`, `LocalAgent/LocalAgentLoop.swift`) finds ZERO
calls → **local models (Llama/Qwen/etc.) never receive the per-model vault context.** So "add files → model reads them →
granular control of how it interprets instructions/code" simply does not work for local models (which is most of the
Models tab). This matches the owner's complaint that the model portion isn't working as it should.
**Fix [M], #1 within SS-MV:** inject `augmentedSystemPrompt` into the local inference path too — at the MLX system-prompt
assembly (`MLXInferenceService` chat-prompt build) and/or `LocalAgentPromptBuilder`, mirroring the cloud call sites, with
the `.compact` budget for tight local context windows and `.full` where the window allows. Honor honest capability gating
(no fake agent caps). Cross-ref SS-CR (don't perturb routing). Test: a local-model send for a model with a vault includes
the vault context in the assembled prompt.

### (3) USER-ADDED FILES ARE IGNORED — injection hardcoded to 4 canonical files
`ModelVaultFileInspector.canonicalFiles` (`ModelVaultFileInspector.swift:23-29`) is a fixed list of the 4 compiled files;
`load()`/`augmentedSystemPrompt` only read those. If a user ADDS an arbitrary file to a model's vault dir (the "Internal —
5 items" granular-control affordance in the Models tab), it is NOT injected into the prompt. The owner's literal ask —
"when I add files to a model I want it to read those files" — is unimplemented.
**Fix [M]:** enumerate user-added files in the model vault dir (beyond the 4 canonical + meta.json), and include them in
`augmentedSystemPrompt` under a "# Attached Files" section with per-file size budgeting + ordering + an honest cap
(log/skip oversized, never silently drop). Surface an add/remove-file affordance in the Models tab (`ModelVaultsSidebarSection.swift`)
+ a per-file "include in context" toggle for true granular control. Harden: path-safety (reuse `safePathComponent`),
UTF-8/binary guard (reuse the `preview` bounded-read pattern), atomic writes (`NoteFileStorage.writeTextAtomically`).

## System tab (lower priority — verify, then fix if stale)
`Views/Sidebar/ModeSystem/SystemModeView.swift` (230 lines) shows System Prompts / Chat Transcripts / Doc Chat Exports /
Agent Logs / Skill Outputs; screenshot shows "No files yet" for 3 of 5. Verify whether those are legitimately empty or
the population wiring is stale (e.g. writers not pointed at the dir the view probes). `ChatTranscriptVaultWriter.swift`
feeds Chat Transcripts (8 recent ✓). Audit each category's writer→reader path; fix any that's pointed at a stale/empty
dir. [S-M, after the model-portion fixes.]

## Scope / cross-surface
NOW: chat surface (local + cloud injection) + Models tab + System tab. LATER (owner: "after we clone the other surfaces"):
let the other surfaces traverse the same per-model files — defer until the Companion→Osaurus clone lands (owner's Cursor
domain; do NOT touch it). Cross-ref SS-WL (wikilink auto-research feeds active_context). Order: (2) local injection →
(3) user-added files → (1) staleness refresh+badge → System-tab audit. Each test-backed; single targeted swift build.
