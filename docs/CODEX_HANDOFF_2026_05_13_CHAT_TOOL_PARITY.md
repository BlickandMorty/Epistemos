# Codex Handoff — Chat Tool Parity + MAS Readiness Red-Team
**Date:** 2026-05-13
**Branch:** `codex/research-snapshot-2026-05-08`
**From:** Claude (this session)
**To:** Codex (next session)
**Scope:** Verify everything below, then run an independent red-team pass on MAS readiness.

---

## ⛔ PROTECTED SURFACE — DO NOT TOUCH

> **The graph (`Epistemos/Views/Graph/MetalGraphView.swift`, the Metal SDF
> renderer, node layout, edge geometry, hologram overlay visuals) is
> PROTECTED.** Per user directive 2026-05-13: *"graph looks stunning, it
> should be a protected part of the app, the most perfect thing in the app
> literally."* If you find a bug in the graph itself, **file an issue,
> do not patch**. The ONLY graph-adjacent code that's in-bounds is the
> chat composer inside the inspector sidebar (`HologramSearchSidebar.swift`
> `sendGraphChatMessage` — I changed this; verify it didn't disturb anything).
>
> If anything you do regresses graph rendering, layout, edges, or selection
> highlight, **revert immediately**.

---

## 1. What This Session Shipped

Four commits on `codex/research-snapshot-2026-05-08` (all pushed to remote):

| Commit | Subject | Files | LOC delta |
|---|---|---|---|
| `951a74c38` | `fix(composer): nudge cloud-no-tools providers to OpenAI on agent-intent` | `Epistemos/Views/Chat/ChatInputBar.swift` | +44 −5 |
| `3a43066df` | `fix(note-ask): auto-escalate agent-intent queries to main chat with tools` | `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` | +30 |
| `f5f50d0ac` | `fix(graph-chat): auto-escalate agent-intent inspector queries to main chat with tools` | `Epistemos/Views/Graph/HologramSearchSidebar.swift` | +75 |
| `9b74c615d` | `chore(dead-code): remove TransclusionOverlayView.swift — superseded by EditableTransclusionView` | `Epistemos/Views/Notes/TransclusionOverlayView.swift` (deleted) | −98 |

All four chain off `15e0e2da8` (`fix(agent): USABILITY-001 (extended)` from
the prior session, which routes cloud Fast/Thinking/Pro+OpenAI/Anthropic
through `runRustAgentPath` with the right tier-mapped tool surface).

---

## 2. Theme of the Session — Chat-Surface Tool Parity

User reported in the prior session:

> *"local and cloud agents were not working they either could not use
> tools or the text to action was messed up meaning speaking and asking
> for something would not trigger anything it said it could not read my
> vault or edit any attached things because it doesn't have access yet
> it would literally have read vault access by default."*

The root cause across surfaces was a **system-prompt-vs-runtime disconnect**:
`BASE_SYSTEM_PROMPT` (in `agent_core/src/prompts.rs`) advertises *"You have
access to the user's knowledge vault, shell tooling, and web-backed tools"*
on every cloud turn — but the actual tool dispatch lives only in the Rust
`agent_loop` + Swift `LocalAgentLoop` paths. Several chat surfaces
(main chat Pro+cloud, note ask-bar, graph inspector chat) were falling
through to a toolless `triageService.stream` direct-stream path. The model
would honestly say *"I can't read your vault"* (or hallucinate) because the
runtime didn't have tools wired even though the prompt advertised them.

The fix pattern across all surfaces:
- Classify the user's draft via `ChatCapability.predictIntent(...)`.
- For `.agent` / `.research` intents, route through a tool-capable path
  (Rust agent loop for cloud-with-`supportsAgentTier`, LocalAgentLoop for
  local-with-`canRunLocalAgentLoop`, or auto-escalate to main chat).
- For non-agent intents (rewrite/summarize/explain/expand), keep existing
  inline path unchanged.

---

## 3. Commit-by-Commit Detail

### 3.1 `951a74c38` — Composer banner extension

**File:** `Epistemos/Views/Chat/ChatInputBar.swift`

**Problem:** `pillNeedsCloudWarning` only fired when user was on **local**
provider + agent intent. The banner ("This needs tools. Tap to switch to
OpenAI") didn't fire when user was on **cloud-but-not-`supportsAgentTier`**
(Google / Z.AI / Kimi / MiniMax / DeepSeek), so users on those providers
got silently degraded toolless responses.

**Fix:** Extended `pillNeedsCloudWarning` to also fire when:
```
isCloudSelection && !cloudSurfaceSupportsAgentTier && prediction.predicted ∈ {.agent, .research}
```
Added a new private computed property `cloudSurfaceSupportsAgentTier` that
mirrors `CloudModelProvider.supportsAgentTier` for the currently-selected
chat surface.

**Codex: verify**
- `inference.preferredChatModelSelection` returns the right value for cloud
  selections (specifically `.cloud(let model)` carries `model.provider.supportsAgentTier`)
- The same `needsCloudBanner` UI copy works for both the local→cloud and
  cloud→cloud cases (it does — "This needs tools" is generic)
- No accidental double-fire when user is on local AND on a non-tool-capable cloud (impossible by definition; selection is one-of)

---

### 3.2 `3a43066df` — Note ask-bar auto-escalation

**File:** `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`

**Problem:** The inline note ask-bar at the top of a note workspace routes
through `triageService.stream`, which delivers native cloud tools
(Anthropic/OpenAI `web_search`, Google `google_search`, Anthropic
`web_fetch` + `code_execution`) automatically — but **cannot** dispatch app
tools (`vault.search`, `vault.read`, `vault.write`, `file.*`) because those
only live in the Rust `agent_core` + LocalAgentLoop paths.

So queries like *"find my note about productivity"* in the note ask-bar
hallucinated or refused because there was no vault tool to call.

**Fix:** In `submitToolbarAskInline()`:
1. Classify the trimmed draft via `ChatCapability.predictIntent(text:, isCloudProvider:)`.
2. If predicted intent is `.agent` or `.research`, call `routeToolbarAskToMainChat()`
   instead — that path attaches the current note as a `ContextAttachment`
   and submits via `MainChatSubmissionRouter.submit(...)`, which routes
   through `ChatCoordinator.handleQuery` and picks up the prior session's
   USABILITY-001 fix (Rust agent loop with `chat_pro` or `chat_lite` tier).
3. Non-agent intents (`.rewrite`, `.summarize`, `.expand`, `.simpleAsk`, `.brainstorm`)
   keep existing inline `triageService.stream` path so the fast in-note
   transform UX is unchanged.

**Codex: verify**
- Reach into `Epistemos/Engine/AgentHarness/ChatCapability.swift`
  `predictIntent` and confirm the `agentSignals` list catches phrases like
  *"find my note"*, *"edit my essay"*, *"open my draft"* (lines 181–219
  cover this).
- Confirm `routeToolbarAskToMainChat()` correctly attaches the note as a
  `ContextAttachment` of kind `.note` with the page's targetId/title.
- Confirm the inline path's existing UX (rewrite/summarize/expand) is
  unaffected by the new gate.
- **Edge case**: what happens on the very first character of typing? The
  classifier runs against an effectively-empty draft. `predictIntent` line
  139-144 returns `.cloud` or `.local` for empty/whitespace, so the gate
  falls through to the inline path. ✓ But verify.

---

### 3.3 `f5f50d0ac` — Graph inspector chat auto-escalation

**File:** `Epistemos/Views/Graph/HologramSearchSidebar.swift`

**🛑 GRAPH PROTECTION SCOPE:** I only modified the `sendGraphChatMessage()`
function (the chat composer's send behavior) inside `HologramSearchSidebar.swift`.
The Metal graph view, node layout, edges, selection highlighting, hologram
overlay visuals are **untouched**. **Confirm via `git diff f5f50d0ac~1 f5f50d0ac`
that only `HologramSearchSidebar.swift` lines around `sendGraphChatMessage`
+ a new `graphNodeContextAttachment` property changed.**

**Problem:** Same root-cause as note ask-bar. The Hologram inspector
sidebar's "Ask this node" chat routes through `triage.streamGeneral` (no
app tools). Native cloud tools attach automatically but vault/file tools
don't.

**Fix:** In `sendGraphChatMessage()`:
1. Trim input + check `inspectorState.isChatStreaming` to avoid duplicate sends.
2. Classify via `ChatCapability.predictIntent`.
3. If `.agent` / `.research`, build a `graphNodeContextAttachment` from the
   selected node (only note-typed nodes today — they have `sourceId =
   pageId`) and route via `MainChatSubmissionRouter.submit(...)`.
4. Otherwise keep existing `inspectorState.sendMessage(...)` inline path.

**UX trade-off documented in code comment:** When escalation fires, the
panel switches to `.home` (main chat). Graph state is preserved; the user
can navigate back via the sidebar graph button. Non-note nodes still
escalate but without node-specific context (model gets the user's query
fresh).

**Codex: verify**
- `inspectorState.selectedNode` is non-nil at the time of send (the
  composer should be hidden when no node selected).
- For non-note node types (`folder`, `dialogue`, `entity`, `tag`, etc.),
  `graphNodeContextAttachment` returns `nil` — verify the escalation still
  proceeds cleanly and the model gets the user's query without a confusing
  empty attachment.
- The panel switch (`ui.setActivePanel(.home)`) is the only side effect
  on graph UI. Confirm no graph state is reset / corrupted by the switch.
- **CRITICAL**: confirm `graphState.store` and `inspectorState.selectedNodeId`
  survive the panel switch so the user can return to the same node.

---

### 3.4 `9b74c615d` — Dead code removal

**File:** `Epistemos/Views/Notes/TransclusionOverlayView.swift` (DELETED)

**Why safe:** The file self-documented as DEAD CODE in its own header:
> *"RCA2-P3-001 fix-pass: this view was replaced by `EditableTransclusionView`.
> Grep across the Epistemos Swift sources returns ZERO live call sites: only
> `EditableTransclusionView` references it in its own header comment to
> explain what it superseded. Retained here only so a future commit that
> wants the read-only style can fork it, but it is NOT in any production
> rendering path and should be considered archival."*

**Verified:**
- `grep -rn "TransclusionOverlayView" Epistemos/` outside the file itself
  returns only `EditableTransclusionView.swift` comments.
- The pbxproj uses `syncedFolder` for the `Epistemos` target (see
  `project.yml`); no project file update needed.
- Build verified BUILD SUCCEEDED after deletion.

**Codex: verify**
- `grep -rn "TransclusionOverlayView" .` returns only doc/audit/patch
  references (historical).
- Build still succeeds (BUILD SUCCEEDED).
- `EditableTransclusionView` is the live transclusion-rendering path.

---

## 4. Native Cloud Tool Wiring — Verified Already in Place

The prior-session audit confirmed every cloud stream path already attaches
native server-side tools when user prefs allow:

| Provider | File | Native tools | User pref default |
|---|---|---|---|
| Anthropic | `LLMService.swift::anthropicServerSideTools` | `web_search_20250305`, `web_fetch_20250910`, `code_execution_20250825` | TRUE (all three) |
| OpenAI | `LLMService.swift::openAIToolsConfiguration` | `web_search` | TRUE |
| Google | `LLMService.swift::streamGoogle` | `google_search` (grounding) | TRUE |
| Z.AI / Kimi / DeepSeek | `streamOpenAICompatible` | none (provider lacks shape) | n/a |
| MiniMax | `streamAnthropicCompatible` | none yet | n/a |

So note ask-bar, graph chat, and dialogue chat surfaces ALREADY have native
cloud tools attached for the inline turns that stay on the
`triageService.stream` path. The auto-escalation above adds **app tools**
(`vault.*`, `file.*`) on top by routing to the Rust agent loop.

**Codex: verify** that `InferenceState` defaults at `Epistemos/State/InferenceState.swift`
lines 3286–3321 still set all five tool prefs (`openAIWebSearchEnabled`,
`anthropicWebSearchEnabled`, `anthropicWebFetchEnabled`,
`anthropicCodeExecutionEnabled`, `googleGroundingEnabled`) to `true` via
`Self.boolPreference(..., defaultIfUnset: true)`.

---

## 5. V6.2 Status — What This Session Confirmed

Per `docs/audits/V6_2_SESSION_PROGRESS_2026_05_12.md` "Remaining V6.2 work":

| Item | Status |
|---|---|
| Per-bubble `VRMLabelView` chip | ✅ LANDED via `LatestAnswerPacketSink` + `answerPacketId` binding (`MessageBubble.swift` line 477) |
| WBO substrate hook | ✅ LANDED `42c12b6fd` (`WBOSubstrateObserver` on `RustProvenanceLedgerClient.summary().eventCount`) |
| sheafResidual substrate hook | ✅ LANDED `SheafResidualSubstrateObserver` on `contradicts_edge_count` |
| connectomeAlarm substrate hook | ✅ LANDED `ConnectomeAlarmSubstrateObserver` on routing-stats deltas |
| Rust AnswerPacket production caller | ✅ LANDED `agent_core::scope_rex::produce::produce_turn_completion_packet` + `bridge::produce_answer_packet_json` |
| Manual smoke tests | ⏳ Operator task — needs live vault on M2 Pro |
| 5 research-tier Metal kernels | ⏳ Target-only per canon (NOT blocking ship) — `SemiseparableBlockScan`, `LocalRecallIsland`, `PageGather`, `ControllerKernelPack`, `PacketRouter1bit` |

V6.2 §S3 Migration Stage (production cut) is gated on Stages 0–2 (Lean
verification stack), which haven't been started — that's a separate
research-tier workstream. **MAS Tier-1 ship gate does NOT require Stages 0–2.**

**Codex: spot-check** `Epistemos/Engine/InterruptScoreCpu.swift` line 272–274
to confirm all three substrate observers (`WBOSubstrateObserver`,
`SheafResidualSubstrateObserver`, `ConnectomeAlarmSubstrateObserver`) are
called in `sampleTurnBucket`. If any are stubbed/disabled, flag it.

---

## 6. MAS Release Manifest Verification — Ran This Session

Reference: `docs/MAS_RELEASE_MANIFEST_2026_05_13.md`

Ran the two leak audits from the manifest's "Verification commands" section:

**Step 3 — subprocess path string scan:**
```bash
find "$APP" -type f -print0 | xargs -0 strings 2>/dev/null | \
  grep -E '^(/usr/local/bin/(claude|codex|gemini|kimi)|/usr/bin/osascript|/bin/bash|/bin/sh|/usr/local/bin/docker)$'
```
**Result: ZERO matches** ✓

**Step 4 — Rust dylib symbol scan:**
```bash
nm -gU "$APP/Contents/Frameworks/libagent_core.dylib" 2>/dev/null | \
  grep -iE 'osascript|bash_execute|cli_passthrough|stdio_mcp|browser_subprocess|imessage_send|cronjob|cli_(claude|codex|gemini|kimi)|computer_use|screencap'
```
**Result: ZERO matches** ✓

MAS bundle is clean — no subprocess paths or Pro-only symbols leak into the
App Store binary.

**Codex: re-run both scans** against a fresh
`Epistemos-AppStore` Debug build to independently verify (use
`CODE_SIGNING_ALLOWED=NO` because the user has only a Personal Team
certificate; the App Store cert is added at submission time).

---

## 7. Hardening Audit — Verified

| Defense | File | Status |
|---|---|---|
| Subprocess `env_clear` + canonical allowlist + denylist | `agent_core/src/security.rs::harden_cli_subprocess` | Applied at 10+ sites: `bash`, `sh`, `osascript`×2, `say`, MCP client, claude/codex/gemini/kimi CLI passthrough, tirith, browser |
| MAS preflight forbidden tools | `agent_core/src/tools/registry.rs::mas_forbidden_tool_name` | Blocks `action.bash`, `action.terminal`, `bash_execute`, `run_command`, `run_persistent`, `terminal`, `process`, `system.process`, `cronjob`, `system.cron` |
| MAS bounded internal mutation allowlist | `agent_core/src/tools/registry.rs::mas_allows_bounded_internal_mutation` | Only `memory` (add/replace/remove/read) + `ssm_resume` (save/load/list/prune) |
| API keys in Keychain | `Epistemos/...` (CLAUDE.md mandate) | `SecItemAdd` / `SecItemCopyMatching` — NEVER `UserDefaults` |
| Sandbox entitlement | `Epistemos/Epistemos-AppStore.entitlements` | `app-sandbox = true`, `allow-jit = true`, `files.user-selected.read-write`, `files.bookmarks.app-scope`, `network.client` — minimal MAS-ready set |
| App Group entitlement | `Epistemos-AppStore.entitlements` | TEMPORARILY REMOVED 2026-05-03 because user is on free Personal Team; restoration steps documented in the entitlements file header |
| Subprocess denylist coverage | `agent_core/src/security.rs::SUBPROCESS_DENYLIST` | `LD_PRELOAD`, all `DYLD_*`, `MallocStackLogging*`, `NODE_OPTIONS*`, `PYTHONPATH`/`HOME`/`STARTUP`, `RUBYOPT`/`RUBYLIB`, `PERL5OPT`/`PERL5LIB` — 24 vectors |

**Codex: red-team** the subprocess hardening:
- Is there a code path that calls `tokio::process::Command::new(...)` or
  `std::process::Command::new(...)` WITHOUT calling `harden_cli_subprocess`
  on it? Grep `agent_core/src` for `Command::new` and verify each site
  either applies hardening or is the hardening function itself.
- Is there a way to invoke a forbidden tool through an alias that bypasses
  `mas_forbidden_tool_name`? Inspect `LEGACY_TO_V2_ALIASES` for sneaky
  routings.

---

## 8. Migrations — Status

| Migration | Code side | Tests | Compat shim |
|---|---|---|---|
| Hermes → LocalAgent (`Runtime*` on Rust) | ✅ FULLY PURGED 2026-05-05 | ⏳ 10 test files in `EpistemosTests/Hermes*` still use Hermes typealias names | `Epistemos/LocalAgent/HermesLocalAgentCompatibility.swift` + Hermes block in `LocalAgentGatewayPolicy.swift` lines 190–233 (lives only because tests still reference Hermes types) |
| Tools V2 dotted names | ✅ Registry handles bidirectional aliasing via `LEGACY_TO_V2_ALIASES` + `api_safe_tool_name` (`.` ↔ `__`) | ✅ Pass | n/a |
| Hermes subprocess | ✅ FULLY PURGED — `agent_core::agent_runtime` is the in-process replacement | ✅ Pass | n/a |
| Hermes UI overlay (`HermesBrand`, `HermesShimmeringSigil`, etc.) | ✅ FULLY PURGED 2026-05-05 | n/a | n/a |

**Deferred: Hermes test rename.** Renaming 10 test files +
`HermesLocalAgentCompatibility.swift` + the Hermes block in
`LocalAgentGatewayPolicy.swift` is a substantial cross-cutting change
that deserves its own focused PR. Currently the compat shim lives ONLY
to keep tests green; zero production code references it.

**Codex: confirm** with `grep -rn "Hermes" Epistemos/` (excluding the two
compat-shim files) returns zero matches. If anything appears, it's a
real regression.

---

## 9. Audit Register Status — THE BIG RESEARCH-DRIVEN BACKLOG

This is **the giant research backlog the user asked you to check**. It's
the canonical "did Claude actually fix what the research drops surfaced"
ledger. **Read it cover-to-cover** before you stamp anything green.

### Primary file

**`docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`** — 14,680
lines, ~216 items across Research Drops 1–13 + RCA2–13 + UIX-2026-05-09.

The audit register is the **living truth** for whether the app is
release-ready. Headline as of 2026-05-13 (Claude's thirteenth-pass):

| Status | Count | Meaning |
|---|---|---|
| `PATCHED` (base + variants) | ~206 | Structural fix shipped, often pinned by a drift-gate test |
| `PATCHED PARTIAL` | ~31 | Structural fix in place; manual smoke/profiling deferred |
| `CONFIRMED` | 17 | Observational entries; not action items |
| `DEFERRED` | 3 | Architecture lane / hardware-gated / SwiftData reproducibility |
| `OPEN` | 1 | `RCA11-P1-002` graph fullscreen perf — runtime profiling task, not a code fix |
| `TODO` | 0 (the Claude session closed the last 109 in 2 days) |

### Pair file (Codex's existing prompt for the same register)

**`docs/audits/CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md`** — 430-line
terminal prompt with the recursive fix protocol the user originally
wrote for Codex. Phase 0 (repo state inspection), required fix order
(P0 vault lifecycle → CodeFileService containment → ... → finalization),
hard rules ("never trust docs as runtime proof", "test-first", "minimal
fixes only").

**Read both files before you do anything else in §10.**

### Companion canon files referenced by the audit register

These are listed inside the Codex prompt at lines 29–42 — the supporting
research/audit/canon sources that gave rise to register entries. Codex
should pull these on a "need-to-know-for-the-entry-you're-verifying" basis,
not all up front:

- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` — the research-corpus index
- `docs/KNOWN_ISSUES_REGISTER.md` — the older 19-bug registry that fed into the audit
- `docs/audits/V1_RELEASE_AUDIT_2026_05_07.md`
- `docs/audits/V1_DEEP_INTERACTION_AUDIT_2026_05_08.md`
- `docs/audits/PERFORMANCE_CONCURRENCY_AUDIT.md`
- `docs/audits/PRIVACY_APP_STORE_AUDIT.md`
- `docs/audits/USER_WIRING_CAPABILITY_MAP.md`
- `docs/audits/DATA_PERSISTENCE_INDEXING_AUDIT.md`
- `docs/audits/PRE_HELIOS_FEATURE_AUDIT_2026_05_06.md`
- `docs/CLI_CONFIG_COMPILATION_RESEARCH.md`
- `docs/future-work-audit.md`

### The 22 verbatim research packets

`docs/audits/codebase-verbatim-packets-2026-05-09/00_INDEX.md` through
`22_CODE_PACKET.md`. These are the literal source dumps the audit register
was built against. Use them when verifying a PATCHED item's evidence
chain reaches "I can see the code from the packet matches the code on
disk today."

### What Codex should actually do with the register

1. **Read the register top-to-bottom once.** Skim if you have to, but
   notice the cadence — every entry has a `Status:` line, a `Subsystem:`
   line, a `Research signal:` line (what the research drop reported), and
   then evidence (file paths, line numbers, commit hashes, command
   outputs).

2. **Sample 10 random PATCHED items.** For each, walk the cited evidence:
   - Open the file at the cited line(s).
   - Confirm the fix described is actually present in the current code.
   - Run the cited test/grep/command and confirm it returns the cited result.
   - If any of these three fail, the PATCHED status is drift — flag the
     entry by name in your assessment doc and recommend reopening it.

3. **Pay special attention to these PATCHED categories**, which the user
   has been burned by in prior sessions:
   - **"Structural fix landed but manual smoke pending"** — the drift gate
     test passes but no human has actually exercised the feature on real
     hardware. The audit register marks these as `PATCHED PARTIAL` or
     `FOCUSED AUTOMATED GREEN / MANUAL SMOKE PENDING`. Skim 5 of these
     and assess whether the remaining manual smoke is plausible to do in
     this session via computer-use (see §10.4 of this handoff).
   - **"Doc claims X is wired, but I cannot find the call chain"** — the
     classic drift mode. The register has a `RCA12 Pre-Build Recursive
     Fix Order` section that lists items where Claude couldn't reach the
     evidence; verify those are now reachable.
   - **"OBSOLETE" closures** — entries marked OBSOLETE should have a
     specific reason (feature retracted, doctrine changed, supersedure
     by a different fix). Confirm the cited reason still holds.

4. **Specifically verify the `Finalization Plan` at the bottom of the
   register** (lines 14649–14694). Five steps:
   1. Manual smoke pass on every PATCHED PARTIAL "remaining risk" line
   2. App Store CI smoke (Epistemos-AppStore scheme builds + tests pass)
   3. MAS binary submission (Xcode Organizer → Archive → Distribute)
   4. AI disclaimer audit (footer renders in all 4 tiers + light/dark)
   5. Pro release (follows MAS reviewer feedback)

5. **The register explicitly defers** these items to post-v1.0; do not
   try to close them in this session:
   - `RCA-P1-002` (.epdoc save heaviness) — needs Instruments profiling
   - `RCA-P1-024` (Apple Intelligence main-actor) — needs macOS 26+ hardware
   - `RCA13-P1-002` (CLI discovery + install prompts) — Pro-only feature
   - All P2/P3 items in research drops 2–13 — long-tail tech debt

### Codex acceptance bar for the register (in addition to §10 below)

- Wrote at least 10-sample audit verification result into your
  assessment doc with file paths + line numbers + result.
- Flagged any drift between PATCHED status and reachable evidence.
- Confirmed the `Finalization Plan` 5 steps are still the correct
  release-prep sequence (no missing step, no obsolete step).
- Re-rolled-up the count at the top of the register if your sample
  surfaces any reopens (do this in a follow-up commit so the count is
  honest).

---

## 10. What Codex Should Do (Acceptance Bar)

### 10.1 Verify this session's commits

For each of the four commits in §3, confirm:
1. The cited file changes exist on `codex/research-snapshot-2026-05-08`
   (`git show <hash>` and inspect the diff).
2. The build still succeeds:
   ```bash
   xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
   ```
3. The `Epistemos-AppStore` scheme also builds (with `CODE_SIGNING_ALLOWED=NO`).
4. Existing tests still pass:
   ```bash
   swift test
   cargo test --manifest-path agent_core/Cargo.toml --lib
   cargo test --manifest-path epistemos-research/Cargo.toml --features research
   ```

### 10.2 Re-run the MAS leak audit

The two `strings`/`nm` scans from §6. Both must return ZERO matches. If
either returns a non-empty result, that's a release blocker — halt and
audit.

### 10.3 Red-team the chat-tool-parity fixes

- **Adversarial intent classification:** Can a user phrase an agent-intent
  query that the classifier misses? Try things like *"is there a doc
  about X"* (no "find" / "look up" verbs), *"what's the gist of my notes
  on Y"*. Each should ideally escalate but the heuristic in
  `ChatCapability.swift` lines 181–219 might not catch them. If you find
  misses, file an audit issue with examples — don't widen the regex
  inline; that's a heuristics tuning pass.
- **Cyclic escalation:** Could the note ask-bar's escalation, on entering
  main chat, re-detect the same intent and re-escalate somewhere else?
  Walk the call chain: `submitToolbarAskInline` → `routeToolbarAskToMainChat` →
  `MainChatSubmissionRouter.submit` → `ChatState.submitQuery` →
  `.querySubmitted` event → `ChatCoordinator.handleQuery`. There's no
  re-entry into `submitToolbarAskInline` so the loop is bounded.
- **Empty selected node:** In `HologramSearchSidebar.sendGraphChatMessage`,
  what if `inspectorState.selectedNode == nil`? The composer should be
  hidden in that state, but verify the guard rails.
- **Graph state corruption:** Submit an agent-intent query from the graph
  inspector chat. After main chat answers, navigate back to the graph.
  Confirm:
  - Same node is still selected
  - Graph layout is unchanged
  - Edges are unchanged
  - Camera position is unchanged
  - Hologram overlay is unchanged
  - **IF ANY GRAPH STATE IS DISTURBED, REVERT `f5f50d0ac` IMMEDIATELY.**

### 10.4 Use computer use to verify MAS readiness live

Per user directive: *"I want it to use computer use to check all the things
it can, etc."*

Use the `computer-use` MCP tools to:
1. **Launch the freshly built `Epistemos.app`** from
   `~/Library/Developer/Xcode/DerivedData/Epistemos-*/Build/Products/Debug/`.
2. **Open Settings** → confirm:
   - Diagnostics rows render (AnswerPacket, runtime truth, shadow search,
     editor bundle, etc.)
   - HELIOS V5 settings show with all toggles default OFF
   - Cognitive DAG row shows
3. **Open a chat** and try:
   - Plain "hi" → response streams, no errors
   - "find my note about productivity" on Pro+Anthropic → should hit Rust
     agent loop with `chat_pro` tier + `vault.search` available
   - Same query on a fresh Google/Gemini selection → should show the new
     "switch to OpenAI" banner from `951a74c38`
4. **Open a note workspace** and try in the inline ask-bar:
   - "rewrite this paragraph" → inline transform path
   - "find my other note on Z" → should escalate to main chat with the
     current note attached (banner / status indicates main chat is being
     used)
5. **Open the graph** and the inspector for a note-typed node:
   - "summarize this node" → inline graph chat path
   - "find related notes" → should escalate to main chat with the node
     attached (panel switches to home; graph view stays in background; user
     can navigate back)
   - **Then navigate back to graph** and confirm the rendering, layout,
     selection, and overlay are pixel-identical to before. Screenshot
     before-and-after if possible.
6. **Take a final screenshot** of the running app to confirm the build is
   clean.

### 10.5 Audit register sanity sample — the big research-driven check

Per §9, read **`docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`**
(14,680 lines) and **`docs/audits/CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md`**
(the paired Codex prompt) cover-to-cover, then:

1. Sample **10** PATCHED items at random — for each, verify the cited
   evidence (file paths, line numbers, commit hashes, command outputs)
   matches the current code. Flag drift.
2. Sample **3** PATCHED PARTIAL items — for each, assess whether the
   remaining manual smoke is plausible to do in this session via
   computer-use (§10.4 of this handoff). If so, do it.
3. Sample **2** OBSOLETE items — confirm the cited supersedure reason
   still holds.
4. Verify the `Finalization Plan` at the bottom of the register (lines
   14649–14694) — 5-step release-prep sequence — is still correct.
5. Record all findings in `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md`
   with explicit file/line citations.

If your sample uncovers drift (PATCHED status with broken evidence), do a
follow-up commit on `codex/research-snapshot-2026-05-08` that:
- Reopens the entry by changing `Status: PATCHED` to `Status: REOPENED-2026-05-13 <reason>`
- Adjusts the rollup counts at the top of the register
- Adds the new findings to your assessment doc

### 10.6 Independent assessment of MAS readiness

Write a one-page assessment to
`docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md` covering:
- What you verified independently
- What you found unchanged from the manifest
- Any red flags or follow-ups
- A go/no-go recommendation for MAS submission with explicit
  prerequisites (e.g., "yes once paid Apple Developer Program signing
  is configured + 24h soak test passes")

---

## 11. Build Commands (Quick Reference)

```bash
# Regular dev build (Epistemos scheme, Pro feature set)
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify

# MAS build (no signing needed for verification)
xcodebuild -scheme Epistemos-AppStore -destination 'platform=macOS' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | xcbeautify

# Swift tests
swift test

# Rust agent_core tests (default = mas-build features for MAS parity check)
cargo test --manifest-path agent_core/Cargo.toml --lib

# Rust agent_core with pro-build (Pro tool surface)
cargo test --manifest-path agent_core/Cargo.toml --lib --features pro-build

# Rust research crate (V6.x falsifier substrate)
cargo test --manifest-path epistemos-research/Cargo.toml --features research

# MAS bundle leak audit (path strings)
APP=/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app
find "$APP" -type f -print0 | xargs -0 strings 2>/dev/null | \
  grep -E '^(/usr/local/bin/(claude|codex|gemini|kimi)|/usr/bin/osascript|/bin/bash|/bin/sh|/usr/local/bin/docker)$'

# MAS dylib leak audit (Rust symbols)
nm -gU "$APP/Contents/Frameworks/libagent_core.dylib" 2>/dev/null | \
  grep -iE 'osascript|bash_execute|cli_passthrough|stdio_mcp|browser_subprocess|imessage_send|cronjob|cli_(claude|codex|gemini|kimi)|computer_use|screencap'
```

---

## 12. Files You'll Want Open

### Mandatory read-firsts (in this order)

1. **`CLAUDE.md`** — project rules + non-negotiable constraints
2. **`AGENTS.md`** — Codex-specific guardrails
3. **`docs/audits/CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md`** — your
   existing recursive-fix protocol (430 lines)
4. **`docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`** —
   the giant ~216-item research-driven audit register (14,680 lines)
5. **`docs/MAS_RELEASE_MANIFEST_2026_05_13.md`** — authoritative MAS feature inventory
6. **`docs/audits/V6_2_SESSION_PROGRESS_2026_05_12.md`** — V6.2 substrate progress
7. **`docs/fusion/helios v6.2.md`** — V6.2 canon (architecture / falsifiers / Tier-Map)
8. **`docs/fusion/EPISTEMOS_V6_2_CANON_INTAKE_2026_05_07.md`** — V6.2 intake (load-bearing deltas)
9. **`docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`** — research-corpus index (pull from here as needed for §9 audit-entry verification)

### Companion audit/canon files (pull on demand)

Listed in the Codex prompt at lines 29–42:
- `docs/KNOWN_ISSUES_REGISTER.md` — older 19-bug registry that fed into the audit
- `docs/audits/V1_RELEASE_AUDIT_2026_05_07.md`
- `docs/audits/V1_DEEP_INTERACTION_AUDIT_2026_05_08.md`
- `docs/audits/PERFORMANCE_CONCURRENCY_AUDIT.md`
- `docs/audits/PRIVACY_APP_STORE_AUDIT.md`
- `docs/audits/USER_WIRING_CAPABILITY_MAP.md`
- `docs/audits/DATA_PERSISTENCE_INDEXING_AUDIT.md`
- `docs/audits/PRE_HELIOS_FEATURE_AUDIT_2026_05_06.md`
- `docs/CLI_CONFIG_COMPILATION_RESEARCH.md`
- `docs/future-work-audit.md`

### Verbatim research packets (the raw source dumps the audit register was built against)

`docs/audits/codebase-verbatim-packets-2026-05-09/00_INDEX.md` and
`01_CODE_PACKET.md`–`22_CODE_PACKET.md`. Use these for "I can see the
packet code matches the on-disk code today" verification of PATCHED
items.

Touched this session:
- `Epistemos/Views/Chat/ChatInputBar.swift` (951a74c38)
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` (3a43066df)
- `Epistemos/Views/Graph/HologramSearchSidebar.swift` (f5f50d0ac) — **review carefully for graph protection**
- `Epistemos/Views/Notes/TransclusionOverlayView.swift` — DELETED (9b74c615d)

Tightly-coupled with the fixes:
- `Epistemos/Engine/AgentHarness/ChatCapability.swift` — `predictIntent` heuristic
- `Epistemos/State/ChatState.swift` — `MainChatSubmissionRouter` (line 1557)
- `Epistemos/App/ChatCoordinator.swift` — `handleQuery` + `runRustAgentPath` (line 2328)
- `Epistemos/State/InferenceState.swift` — `supportsAgentTier` (line 1212), native cloud tool prefs (line 3286)

---

## 13. Acceptance Bar (TL;DR for Codex)

✅ All four commits build clean (`Epistemos` + `Epistemos-AppStore` schemes)
✅ Both MAS leak audits return ZERO matches (strings + nm)
✅ Existing Swift + Rust tests pass (`swift test`, `cargo test` on both
   `agent_core` and `epistemos-research`)
✅ Graph rendering / layout / edges / selection unchanged by `f5f50d0ac`
   (screenshot before/after navigation away+back)
✅ At least one live computer-use smoke pass against the running app
   covering main chat, note ask-bar, graph chat
✅ **Read `RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` cover-to-cover**
✅ **Read `CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md` cover-to-cover**
✅ Random sample of **10 PATCHED + 3 PATCHED-PARTIAL + 2 OBSOLETE** audit
   items verified against current code
✅ `Finalization Plan` 5-step sequence verified still correct
✅ Any drift surfaced → reopened entries + count rollup updated +
   findings recorded
✅ Written assessment doc at
   `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md` with explicit
   file/line citations and go/no-go recommendation

If any of the above fails, **halt and escalate** before continuing.

---

## 14. Anti-Patterns to Avoid

- **DO NOT touch graph rendering, layout, edges, selection, hologram
  overlay visuals, or Metal SDF code.** Chat surfaces inside the inspector
  sidebar are the only graph-adjacent code you're allowed to modify.
- **DO NOT widen `ChatCapability.predictIntent` heuristics inline** — if you
  find missed intents, file an audit issue with examples and let a
  dedicated heuristic-tuning pass handle it.
- **DO NOT delete the Hermes compat-shim files** (`HermesLocalAgentCompatibility.swift`
  + Hermes block in `LocalAgentGatewayPolicy.swift`) until the 10 test
  files are renamed — that's a separate focused migration PR.
- **DO NOT auto-fix audit items without verifying the cited fix actually
  shipped** — drift between the audit register and the codebase is a real
  hazard and the user has called it out before.
- **DO NOT amend or force-push any of the four commits** — they're already
  on the remote and any consumer (the user's Codex session, this session's
  loop) may have pulled them.

---

*— Generated by Claude (Opus 4.7, 1M context) — handoff to Codex 2026-05-13*
