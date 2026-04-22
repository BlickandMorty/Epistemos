# Claude → Codex handoff · April 22 2026 · live runtime findings + capability-tunnel research

Purpose: capture everything Claude did in this session on top of Codex's
`97adbf83` checkpoint so the next agent can continue without re-doing the
diagnosis, and answer the user's direct question:

> "is there an easy way for the capabilities to just flow through"

Short answer: yes, and ~80% of it is already built. See §6.

Branch: `codex/runtime-input-audit`
Base commit when handoff was written: `97adbf83` (Codex's "live runtime and
model simplification checkpoint")
Worktree at end: clean; no new commits from this session.

---

## 0. Read first

1. `/Users/jojo/Downloads/Epistemos/AGENTS.md`
2. `/Users/jojo/Downloads/Epistemos/.agents/skills/epistemos_release_audit/SKILL.md`
3. `/Users/jojo/Downloads/Epistemos/docs/handoffs/2026-04-22-codex-to-claude-live-runtime-and-architecture-handoff.md`
4. This file

---

## 1. Live walkthrough evidence (what Claude actually saw)

Computer-use session on the fresh Xcode build (PID `10806`, binary mtime
`Apr 22 16:22`, started `16:22:54`). This is the build the user was running
when they returned.

### 1.1 App is currently responsive — no hot-loop reproduced

- CPU `~0.3%`, memory `~157 MB RSS`, state `SX` (sleeping, low priority)
- Mini Chat already showed a finished `read_file` tool call with result
  `tool smoke ok` on `/tmp/epistemos_live_tool_smoke_20260422_…` — i.e. an
  in-vault or explicit-path read working end-to-end
- Main Chat already showed a prior Opus-4.1 outside-vault read that ended
  with "No response received. The tools run ended before a final answer was
  produced." — this is the pre-existing outside-vault blocker from Codex's
  handoff §5.2, not a new regression

The hot-loop from the earlier sample at `/tmp/Epistemos_2026-04-22_155736_eHeO.sample.txt`
was a **different** process (PID `94003` at `15:44`, terminated). The
current build has not hot-looped in this session. Do not over-claim that the
loop is fixed — it has not been stressed enough; see §3 for the root-cause
theory.

### 1.2 Curated cloud surface is live and correct

Verified via the composer model picker on the running build:

- **OpenAI** (checked by default): `GPT-5.4, GPT-5.4 Mini` · `Account setup`
- **Anthropic**: `Claude Opus 4.7, Sonnet 4.6` · `Saved` (key in keychain but no `Check Access` probe has succeeded yet from the app)
- **Google**: `Gemini 3.1 Pro, Gemini 3 Flash` · `Saved`

DeepSeek, Z.AI, Kimi, MiniMax are gone from the normal user surface. Matches
the spec in Codex's §3.1.

After switching the Cloud Provider row to Anthropic, the picker header flipped
from `OpenAI · Account first` to `Anthropic · Active stack`, and the check
moved. No hot-loop, no "Internal inconsistency in menus" log fired during
this switch.

### 1.3 Qwen 3 unified picker did NOT surface — still a problem

The picker shows `Qwen3 4B` (installed, "Tools · Chat 8 GB+") and
`Qwen3 Think 4B` (available to install, "Thinking · Chat 8 GB+") as
**separate rows**. The handoff's §3.2 unified-entry work is present in code
but not visible in the UI — the precondition `qwen3UnifiedPickerPairAvailable`
in `Epistemos/State/InferenceState.swift:3653-3656` requires **both**
`.qwen3_4B4Bit` and `.qwen3_4BThinking25074Bit` to be in
`supportedAvailableLocalTextModels`, and the Thinking variant is not in
that set — it shows as "Available to install" not installed. So the union
fails and the unified picker fallback is the old two-row form.

Root cause most likely: the installation detection only counts one of the
two hub directories as "installed" for Qwen-3. On disk we have both
`models--Qwen--Qwen3-4B-MLX-4bit` and
`models--mlx-community--Qwen3-4B-Thinking-2507-4bit`. The detection logic
in `LocalModelManager` / `releaseSelectableInstalledLocalTextModelIDs`
needs to actually see the Thinking hub dir as installed for the unified
picker to engage.

### 1.4 Local model detection is broken: 2 of 12+ detected

Picker header says `2 installed · 7 available`. Only `Qwen3 4B` and `R1 7B`
are detected as installed. On disk
(`~/Library/Application Support/Epistemos/Models/text/hub`) there are at
least:

- models--Qwen--Qwen3-4B-MLX-4bit ✓ shown
- models--mlx-community--DeepSeek-R1-Distill-Qwen-7B-4bit ✓ shown
- models--mlx-community--Qwen3-4B-Thinking-2507-4bit ✗ shown as available
- models--Qwen--Qwen3-8B-MLX-4bit ✗ shown as available
- models--mlx-community--Qwen3-Coder-Next-4bit ✗ shown as available
- models--mlx-community--Qwen3.5-4B-4bit ✗ not in picker
- models--mlx-community--Qwen3.5-9B-4bit ✗ not in picker
- models--mlx-community--gemma-3-4b-it-qat-4bit ✗ shown as available
- models--mlx-community--gemma-4-e4b-it-4bit ✗ not in picker
- models--mlx-community--gemma-4-26b-a4b-it-4bit ✗ not in picker
- models--dealignai--Gemma-4-31B-JANG_4M-CRACK ✗ not in picker
- models--mlx-community--Llama-3.2-3B-Instruct-4bit ✗ shown as available
- models--mlx-community--Falcon-H1R-7B-4bit ✗ not in picker
- models--prism-ml--Ternary-Bonsai-{4B,8B}-mlx-2bit ✗ shown as "Bonsai"

Two distinct bugs live in this one finding:

1. **Install detection misses hub dirs.** Likely a hub-name ↔ catalog-ID
   mismatch in `LocalModelCatalog` or `LocalModelManager.installRecords`.
   The presence of the blob files in the hub dir is not enough — something
   wants an explicit `install_manifest.json` or a catalog entry to recognize
   the dir as installed.
2. **Some models are filtered out of the picker entirely.** Qwen3.5 4B/9B,
   Gemma-4, Falcon-H1R, Gemma-4-31B are on disk but not listed even as
   "Available to install." Those are likely hidden by
   `isReleaseValidatedForInteractiveChat` or the hardware-fit filter.

Treat these as two separate tickets.

### 1.5 What was not tested live

The user returned, granted access, and Claude verified the surface and a
couple of provider swaps — but did not in this session run:

- Anthropic `Check Access` end-to-end (the Settings → Inference pane was not
  opened; `Cmd+,` and the gear icon both failed to open it; worth checking
  whether Settings routing is broken)
- a fresh Main Chat tool call on Opus 4.7 against the curated surface
- an outside-vault read on Opus 4.7 (the failing case)
- a note-create tool round-trip
- approval deny flow
- local Qwen-3 tool use
- idle memory after model unload

These remain on the runtime-validation matrix. The live walkthrough was cut
short to focus on writing this handoff and the tunnel research the user
explicitly asked for.

---

## 2. What was verified green (non-UI)

- `cargo test` on `agent_core` — **541 passed, 0 failed** in `3.73s` against
  the checkpoint (`97adbf83`). Rust side is stable.
- Build artifact integrity — the running app's binary matches the fresh
  Xcode build (`Apr 22 16:22`, same DerivedData path as in Codex's §4.1).

Xcode's `xcodebuild test` was **not re-run** in this session because the
existing SwiftLint script-phase failures block a clean exit (Codex §5.6)
and the user's priority was the live walkthrough + the tunnel research.

---

## 3. Hot-loop diagnosis (root cause, confidence ~75%)

The sample `/tmp/Epistemos_2026-04-22_155736_eHeO.sample.txt` shows all 5
seconds of samples with main-thread stuck in:
`GraphHost.flushTransactions → ViewGraphRootValueUpdater → StackLayout.sizeThatFits
→ UnaryLayoutEngine.sizeThatFits → _FlexFrameLayout`. The only user-code leaf
visible is `UserBubbleShape.path(in:)`. Console logged repeated
"Internal inconsistency in menus."

### Two confirmed anti-patterns were introduced in `97adbf83` that can drive this loop

**A. Side-effecting lazy-cache reads on `@Observable` state.**

[`Epistemos/State/InferenceState.swift:4285-4305`](Epistemos/State/InferenceState.swift:4285)
— `apiKey(for:)` writes to `missingCloudAPIKeyProviders`,
`cachedCloudAPIKeys`, and `cloudProviderValidationStates` as side effects of
a read. Same in `oauthCredential(for:)` at lines 4307-4327. `hasConfiguredCloudAccess(for:)`
at line 4354 calls both.

`hasConfiguredCloudAccess` is itself called from multiple computed properties
that a SwiftUI `body` reads during layout:
`preferredAutoRouteCloudProvider` (line 4073-4091) iterates all providers;
`configuredCloudProviders` (line 4267-4271) iterates all providers too.

**This is the canonical SwiftUI infinite-layout pattern.** A getter that
mutates `@Observable` state while being read during a view body
evaluation invalidates that view's dependency set, the body re-evaluates,
reads the getter again, mutates again, etc.

In practice it only fires when the caches are out of sync with the missing
sets — e.g. right after the deferred bootstrap's
`applyCloudCredentialSnapshot` replaces all four observable stores. It's
the kind of loop that shows up reliably the first few times the app
launches, then stays quiet once the caches settle.

Minimal fix: **make `apiKey(for:)` and `oauthCredential(for:)` side-effect
free during reads.** Move the missing-set insertion and the validation-state
transition into the explicit refresh/clear paths, or into a post-read
`Task.detached { @MainActor in … }` hop so mutation does not happen inside
the view-body critical section.

**B. Per-row `@Observable` fan-out in `LocalModelToolbarMenu`.**

[`Epistemos/App/RootView.swift:1510-1525`](Epistemos/App/RootView.swift:1510)
— `localModelSubtitle(for:)` now calls
`inference.availableOperatingModes(for: .localMLX(model.id))` for every row
in `installedSelectableModels`, and this chain reads
`latestLocalRuntimeHealth`, `preferredChatModelSelection`, the whole
`supportedAvailableLocalTextModels` set, and in the agent-fit branch calls
`LocalInferenceMemoryPressureMonitor.availableMemoryBytes()` (a mach
`host_statistics64` call).

`installedSelectableModels` (line 369) and `installableSelectableModels`
(line 376) also allocate fresh `Set<String>`/`Array` on every body call.

Under memory pressure, `latestLocalRuntimeHealth` is updated externally on a
timer. That update invalidates every menu row that reads it, causing
wholesale menu re-layout. If the re-layout itself raises pressure (huge view
graph, lots of allocation), the system sees more pressure, updates the health
snapshot, invalidates again. That is a plausible path to 98-100% CPU during
a menu interaction.

Minimal fix: **cache the `availableOperatingModes` per model-ID in the
`LocalModelToolbarMenu` `@State` once per picker open, or move the memory-fit
check out of the per-row path and onto a single cached value read once per
picker session.**

### Confidence

These are the two anti-patterns that demonstrably exist in `97adbf83` and
fit the sample's signature. **Neither is directly proven** to be the
loop driver — the sample has no Epistemos user frames at the leaf, only
`UserBubbleShape.path(in:)` once out of 5 samples. A proper repro-under-
Instruments pass would confirm. Until then, fix A is low-risk and is the
right SwiftUI hygiene change regardless.

---

## 4. Rust + Swift code safety notes from this session

- The `97adbf83` checkpoint deferred cloud credential bootstrap off the main
  thread into a `DispatchQueue.global(qos: .utility).async` block that hops
  back to `@MainActor` via `applyCloudCredentialSnapshot` — that's fine. The
  bug is the lazy-cache pattern that remains on the read side (§3A).
- `AppBootstrap` added SwiftData migration that opens SQLite to add
  `ZSDMESSAGE.ZTHINKINGTRACE` / `ZTHINKINGDURATIONSECONDS` columns. This is
  the right fix for the Codex message-schema drift noted in earlier handoffs.
  Code looks safe; column additions are idempotent.
- `agent_core/src/providers/claude.rs` updated only the Anthropic model IDs
  to the new curated set. 6-line diff. No runtime risk.

---

## 5. What the user also asked in this conversation

Direct quote (re-stated for the next agent):

> "my modlels to be able to use bash ssh shell cli cd ci etc. all of the
> commands all of the runs searches etc. bascialyl all the things claude
> code does and codex does i wnated to see if my app vould be like a tunel
> where the real capapbiltiies of the cloud apis can come through easily
> without me engineerign against it and manually allowing and building
> capabiltiies is there an easy way fpr the capabilitites to just flow
> through"

Direct quote (earlier in the same thread):

> "i wanted to see if my app could be like a tunnel where the real
> capabilities of the cloud apis can come through easily without me
> engineering against it and manually allowing and building capabilities"

So the next agent must treat §6 as a first-class product requirement, not
an optional extension.

---

## 6. Capability-tunnel research — yes, and most of it is built

The user's instinct is correct. You do NOT need to hand-engineer every
capability. There are three layered tunnels that together give
Claude-Code / Codex parity, and Epistemos already has the hard pieces of
each.

### 6.1 Tunnel A — universal shell tool (the Claude-Code pattern)

Claude Code itself does **not** have a rich hand-built tool surface for
"git", "ssh", "ci", "cd". It has **one** `Bash` tool with good approval UX,
and the model decides what to run. Everything else is a thin specialization
(structured file read, structured edit). That's the whole trick.

**Already in Epistemos:**
- [`agent_core/src/tools/terminal.rs`](agent_core/src/tools/terminal.rs) —
  shell execution with working-dir, env sanitization (strips KEY/TOKEN/
  SECRET/PASSWORD/PASSWD/CREDENTIAL/AUTH env vars), timeout, foreground and
  background modes, 200KB rolling stdout+stderr buffer per process, 64
  concurrent cap, 30-minute reap TTL.
- `process` tool for listing / polling / logging / killing / stdin-writing
  background processes (same file).
- `register_bash_execute()` wired into the tool registry at
  [`agent_core/src/tools/registry.rs:448-450`](agent_core/src/tools/registry.rs:448).

**What remains:**
1. Surface the bash/terminal tool to the active capability set on the
   cloud-model Agent mode and honestly disclose it in the composer
   ("this chat can run shell commands").
2. Wire a first-class approval path through the existing
   `Epistemos/Omega/Permissions/` gate so every shell run prompts the user
   with the exact command, working dir, and preview the first time it
   appears in a session.
3. Add a logs/artifacts pane (or reuse the existing tool-execution-preview
   list) that shows stdout+stderr inline with exit code and duration. The
   DB at `~/Library/Application Support/Epistemos/omega_executions.db`
   already persists the execution; just render it.
4. Gate the tool behind a per-chat "this is a worker session" toggle so
   idle chat surfaces cannot silently spawn subprocesses.

**Security reality:** the env sanitizer already hides API keys from the
child process. But: the Mac App Store sandbox will block arbitrary
subprocesses. Epistemos' direct-distribution build needs hardened runtime
+ correct entitlements + user consent. Note this in the README and the
approval copy.

### 6.2 Tunnel B — MCP server passthrough (already half-wired)

Anthropic's Messages API supports a first-party `mcp_servers` parameter:
you hand the API a list of MCP servers and the model will call their tools
natively, without the Swift/Rust side needing to know anything about those
tools.

**Already in Epistemos:**
- The Anthropic provider already emits `mcp_servers` in the request
  payload at
  [`agent_core/src/providers/claude.rs:265,287`](agent_core/src/providers/claude.rs:265).
- Epistemos has a swift-sdk MCP peer bridge
  (`Epistemos/Omega/MCPBridge.swift`) and hosts an MCP server of its own.

**What remains:**
1. Add a UI surface to register external MCP server URLs (community or
   first-party servers: filesystem, git, fetch, time, sequential-thinking,
   etc.). Settings → MCP → Add server (name + URL + auth).
2. Persist the configured servers in GRDB or UserDefaults + keychain for
   auth tokens.
3. Forward the configured list into the Anthropic `mcp_servers` payload
   field on every Agent-mode turn. Same on OpenAI Responses API once
   their equivalent lands.
4. Surface the set of "tools available via MCP" in the composer disclosure
   line.

This one feature alone gives the user filesystem / git / fetch / timers /
structured reasoning / database / web search / anything-someone-wrote-an-
MCP-server-for, **without writing a single Rust tool per capability**.
That is the tunnel the user is asking for.

### 6.3 Tunnel C — Claude Code / Codex CLI passthrough (optional)

Once §6.1's bash tool is surfaced, the user can literally type "install
`claude` CLI and run it on this repo" and the model will do it. The
Claude Code CLI is `npm i -g @anthropic-ai/claude-code`; the Codex CLI
is a similar install. After install, the model can shell out to them.

You don't need to build this; it's a natural consequence of §6.1. It's
worth mentioning in the approval copy so users understand what's possible.

### 6.4 Minimum path to the "tunnel feel" the user wants

Smallest set of code changes to make Epistemos feel like a Claude-Code /
Codex desktop:

- **Phase W0 (half a day):** Make sure the bash tool is enabled for the
  Anthropic Agent path on the main chat. Add a disclosure line in the
  composer. Add per-session approval defaults. Reuse the existing
  tool-execution preview UI to render stdout/stderr.
- **Phase W1 (one-to-two days):** Ship a Settings → MCP page that
  reads/writes a list of external MCP servers. Forward into the Anthropic
  request. No per-tool Swift code.
- **Phase W2 (one-to-two days):** "Worker Session" concept — a chat kind
  where the shell tool plus MCP tunnel plus a persistent working dir + log
  pane are all on by default, and idle chats do not have them. This gives
  the user the distinction between "conversation" and "worker" that the
  Claude Code desktop exhibits.

Do NOT rewrite the agent harness, the Omega runtime, or the chat system.
The worker surface is additive.

### 6.5 Do not pretend to do what the tunnel cannot

Two limitations to be honest about in the approval copy and the composer:

- **SSH keys / local secrets** — the env sanitizer strips `*_KEY` vars
  before subprocess exec. That is the right default. It means `git push`
  over HTTPS with a token env var won't work without an explicit
  override. Document this.
- **Sandbox + notarization** — a notarized direct-distribution build can
  run arbitrary subprocesses if hardened runtime allows it; a Mac App
  Store build cannot. The user's distribution target decides what's
  possible.

---

## 7. Related architecture asks from this conversation that the background agents were still researching

Two Explore agents were still running when this handoff was written. If
their reports land after this doc, please fold them in. They're narrower
follow-ups to the tunnel research.

1. **Worker-mode architecture** — inventory of Epistemos existing tool
   surface (`33 tools` hypothesis), gap vs. Claude-Code/Codex, minimum-
   viable worker-session abstraction, macOS sandbox reality.
2. **App-managed diff / history / authorship** — inventory of existing
   `ConversationPersistence`, `SessionBrowser`, `VaultLifecycleService`,
   `SDMessage` / `SDBlock` / `SDChat` schema, model-vault directory layout
   (`~/Library/Application Support/Epistemos/model_vaults/` already has
   `claude-opus-4-7`, `claude-sonnet-4-6`, `gemini-3-pro-preview` etc.
   directories on disk); minimum field to add for per-block
   `authoredByModelID`; Notes sidebar performance pattern.

The agent IDs in this session's subagent log are
`aae5e8b1a0c300652` (worker-mode) and `ad70ce7125d2395c1` (diff /
authorship). Their outputs will show up in
`/private/tmp/claude-501/-Users-jojo-Downloads-Epistemos/…/tasks/…output`
once done; the next agent can read them directly.

---

## 8. What remains undone in concrete terms

### Runtime validation still open

1. Anthropic `Check Access` inside Settings → Inference, on the fresh
   build, end-to-end
2. Main Chat + Mini Chat tool matrix across all six curated cloud models
3. Main Chat + Mini Chat tool matrix on Qwen-3 4B and DeepSeek R1 7B (the
   two detected-installed local models)
4. Outside-vault tool read on Opus 4.7 (the Codex §5.2 failing case)
5. Note-create end-to-end, verify the note shows up in the vault (Codex
   §5.3 failing case)
6. Approval deny flow
7. Idle memory after a Pro turn with thinking on
8. Qwen-3 unified picker — fix the install-detection so the Thinking hub
   dir counts as installed, then verify the single `Qwen 3` entry surfaces
9. Full `xcodebuild test` once the SwiftLint script-phase failure is sorted
   — treat that failure as a precondition, not as noise

### Code work still open

10. **Hot-loop hygiene fix (Tunnel-independent):**
    - Remove lazy-cache writes from
      [`InferenceState.apiKey(for:)`](Epistemos/State/InferenceState.swift:4285)
      and
      [`InferenceState.oauthCredential(for:)`](Epistemos/State/InferenceState.swift:4307).
      Writes belong in the refresh / set / clear paths. Reads must be
      pure during view body evaluation.
    - Cache `inference.availableOperatingModes(for:)` per-row in
      [`LocalModelToolbarMenu`](Epistemos/App/RootView.swift:315) so the
      memory-fit check does not re-evaluate in a per-row ForEach under
      menu-validation pressure.

11. **Local model install detection (§1.4):**
    - Reconcile `LocalModelCatalog.shippedModelIDs` with the hub directory
      names actually present on disk. A missed mapping is why 10+ models
      look "available to install" instead of "installed."

12. **Qwen-3 unified picker precondition (§1.3):**
    - Once the Thinking variant is counted as installed,
      `qwen3UnifiedPickerPairAvailable` will turn true, and the
      `normalizedReleaseSelectableLocalTextModelID` path will collapse the
      two rows into one. Same ticket as §11, essentially.

13. **Tunnel implementation (§6):**
    - W0 — surface bash tool on Agent mode + approval UX + artifacts render
    - W1 — Settings → MCP servers page + Anthropic passthrough config
    - W2 — Worker Session chat kind

### Architecture asks still open

14. **App-managed diff / history** (Codex §12) — snapshot + diff ledger
    per file/note/chat, authored-change provenance, vault-visible chat
    transcripts, model-vault surfaces in Notes sidebar.
15. **Model authorship memory** — per-model "involvement" view of
    substantive AI-authored blocks.

---

## 9. Commit plan (the user's "commit so nothing regresses" ask)

The tree was clean when this handoff was written. Nothing in this session
modified source files. The only commit this session produces is the
handoff itself.

Recommended staging if the next agent wants to split `97adbf83` into safer
pieces, in order of safety:

1. The new handoff doc (this file) + APP_ISSUES_AUTO_FIX update — pure docs
2. The provider/model simplification slice from `97adbf83`
   (InferenceState model enums + providers/claude.rs + SettingsView bindings)
   — cosmetic, already verified live
3. The `AppBootstrap` SwiftData column repair — well-contained migration
4. The MiniChatView tool-block rendering — isolated
5. The InferenceState lazy-cache hygiene fix (once written, see §10 above)
   and the LocalModelToolbarMenu caching fix — these are new, not from
   `97adbf83`

Do NOT commit §13 (tunnel) or §14/§15 (architecture) without a design
review from the user.

---

## 10. One-line summary for the next agent

The fresh build is responsive, the curated surface is correct, the hot-loop
theory is two anti-patterns in `97adbf83` (§3), the capability tunnel the
user wants is ~80% built (§6), and the runtime-validation matrix in §8 is
the next 2-4 hours of work before anything else ships.

— Claude, 2026-04-22
