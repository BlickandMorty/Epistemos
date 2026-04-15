# Phase 6 — Clark Handoff to Codex

Date: 2026-04-14
From: Clark (audit/verify/harden pass)
To: Codex (continuation agent)
Status: Phase 6 not closed. Blocked on manual runtime verification + three plan-vs-code mismatches that need a product decision.

This document is the canonical record of the Phase 6 audit pass run on 2026-04-14 and the pointer set Codex should use to continue. It is organized so that Codex can read it end-to-end once and have everything needed to either (a) close Phase 6, or (b) update PLAN_V2 to match what actually shipped. Read `PHASE_6_PROTOCOL.md` first if you have not.

---

## 0. TL;DR for Codex

- **Rust side is in good shape.** All six Phase 6 tools (`send_message`, `vision_analyze`, `image_generate`, `text_to_speech`, `imessage`, `imessage_contacts`) are real, tier-gated, credential-redacted, SSRF-protected, and free of `todo!()` / `unimplemented!()` / panic traps.
- **Swift side is wired end-to-end.** `ChannelRegistryState`, `IMessageDriverService`, `IMessageReplyDelegate`, `IMessageDriverSettingsView`, and `AppBootstrap` integration all exist. Polling is real. Reply isolation is enforced. Permission denials are explicit.
- **Automated verification is green.** 471 Rust tests in `agent_core`, 366 Rust tests in `epistemos-core`, xcodebuild build succeeded, 193 focused Swift tests in `DeviceAgentServiceTests` + `ControlPlaneSurfaceTests` + `RuntimeValidationTests` — 0 failures across the board.
- **What blocks closure:** manual runtime verification (credentials + macOS permissions) and three product/plan decisions listed in §6.

---

## 1. Scope reminder

Phase 6 = Communication + Media slice.

Deliverables:
- Rust tools: `send_message`, `vision_analyze`, `image_generate`, `text_to_speech`, `imessage`, `imessage_contacts`
- Swift surfaces: `ChannelRegistryState`, `IMessageDriverService`, `IMessageReplyDelegate`, `IMessageDriverSettingsView`, bootstrap + routing wiring
- Phase 6 is an audit / verify / harden / close pass, not a greenfield build.

Non-goals (hard):
- Phase 7 intelligence
- persistent memory redesign
- marketplace / skill install
- runtime contract rewrite
- adaptation experiments
- anything in the Do-Not-Drift list at the bottom of `PHASE_6_PROTOCOL.md`

---

## 2. Docs Clark read

Tier 0 and 1 in order:
- `AGENTS.md`
- `CLAUDE.md`
- `docs/architecture/README.md`
- `docs/architecture/PHASE_6_PROTOCOL.md`
- `docs/architecture/CODEX_CONTEXT_PACK.md`
- `docs/architecture/RESEARCH_INDEX.md`
- `docs/architecture/PLAN_V2.md`
- `docs/BACKEND_INTERFACE_SPEC_v1.md`
- `docs/architecture/COMPUTE_STEERING_SPEC_v1.md`
- `docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md`
- `docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md`

Tier 2:
- `docs/architecture/PHASE_5_HANDOFF.md`
- `AGENT_COMMAND_CENTER_UX_HANDOFF.md`

Tier 3:
- `docs/SKILL_IMPLEMENTATION_PLAN.md` (Phase 6 sections + file-structure sections)
- `docs/TOOL_TIER_AND_IMESSAGE_INTEGRATION.md`

Deferred (too large for one read, overlap with other docs confirmed): `docs/CODEX_HANDOFF_2026_04_10.md`. The overlap with `TOOL_TIER_AND_IMESSAGE_INTEGRATION.md` is high enough that Clark did not lose evidence by skipping it. Codex should still skim it before a major next phase.

---

## 3. Code audit map — Phase 6 files actually read

### Rust (`agent_core/src/tools/`)

| File | Lines surveyed | Key facts |
|---|---|---|
| `communication.rs` | full file | 8 adapters (slack, telegram, discord, webhook, matrix, whatsapp, signal, email). All use env-var creds at call time. `validate_outbound_url()` at ~line 619 rejects non-HTTP schemes and private IPs except narrowly for signal-cli-rest. 14 unit tests. No panics in any send path. |
| `media.rs` | full file | `vision_analyze` supports claude + openai-gpt4o; local-file path is base64 at 20MB cap. `image_generate` calls `https://fal.run/fal-ai/flux/dev`. `text_to_speech` is `tokio::process::Command::new("say")` with 8000-char cap, 60s timeout. 9 unit tests. |
| `imessage.rs` | full file via subagent | Read path = `rusqlite` SQLite read-only on `~/Library/Messages/chat.db` with env override `EPISTEMOS_IMESSAGE_DB`. Write path = `osascript -e` against Messages.app. Proper AppleScript quoting. Permission failures explicit ("Grant Full Disk Access..."). 13 unit tests. |
| `imessage_contacts.rs` | full file via subagent | SQLite at `~/.epistemos/imessage_contacts.db`. Actions: list/get/set/remove/resolve/record_message. 8 unit tests. Tier validation at set-time. |
| `registry.rs` | lines 440-660 directly | `apply_tier_overrides()` downgrades `vision_analyze` and `text_to_speech` to ChatPro. `send_message` + `imessage` stay at Agent + Destructive. `imessage_contacts` + `channel_contacts` at ChatPro + Modification. `image_generate` stays at Agent. |
| `bridge.rs`, `agent_loop.rs`, `security.rs` | via subagent | `execute_tool_call` FFI entry point double-gates tier. Tool outputs run through `security::redact_credentials` at `agent_loop.rs:805`. Truncation cap 16,384 chars. |

### Swift

| File | Key facts |
|---|---|
| `Epistemos/Omega/Channels/ChannelRegistryState.swift` | `@MainActor @Observable` at lines 206-207. Persists to UserDefaults key `epistemos.channelRegistry.v1` via didSet hooks (line 210-216). Adapter factory `makeAdapter(for:)` at line 254 returns `FallbackDriverChannelAdapter(primary: relay, fallback: IMessageChannelAdapter)` only when pairingState is `.remoteRelay` AND `enableNativeFallback == true` (lines 263-269). Default iMessage config is `.nativeLocal` with `enableNativeFallback: true` — so the *default path* does not hit the fallback adapter at all. |
| `Epistemos/Omega/iMessageDriver/IMessageDriverService.swift` | Real polling loop. `tickOnce()` exposed for manual trigger. Uses `agent_coreFFI` for all iMessage operations via `DriverChannelToolExecutor.execute()` → `executeToolCall()`. Model picker uses hardcoded `modelPresetOptions` at lines 584-600 (qwen, claude, gpt, gemini) instead of reading `ModelRegistryService`. Keep-alive on launch gated by config flag at 1152-1157. |
| `Epistemos/Omega/iMessageDriver/IMessageReplyDelegate.swift` | Per-message delegate. `contactHandle` bound at construction; all sends go through `sendChunkedReply(to: contactHandle)` (lines 110-122) — no fan-out, no recipient override. Explicitly denies `localDataRead`, `localDataWrite`, `destructive` permission classes with a logged warning (lines 167-185). |
| `Epistemos/Views/Settings/IMessageDriverSettingsView.swift` | Reachable via `iMessageDriverDetailView`. Footer surfaces "requires Full Disk Access... Automation permission" at line 94. |
| `Epistemos/App/AppBootstrap.swift` | IMessageDriverService initialized at lines 1132-1151 with vault-path, channel-config, and channel-adapter providers pulled from the shared `ChannelRegistryState`. Auto-start gated by `keepAliveOnLaunch`. |
| `Epistemos/Bridge/StreamingDelegate.swift` | Generic interactive-chat delegate. Not on the Phase 6 driver path. `IMessageReplyDelegate` is a sibling, not a wrapper. |
| `Epistemos/App/ChatCoordinator.swift` | No Phase 6 touch points — the iMessage driver is fully decoupled from the interactive chat coordinator. |

---

## 4. Automated verification — results

Commands and results, exactly as run:

```
$ cargo test --manifest-path agent_core/Cargo.toml
→ 464 pass (lib) + 2 pass (epistemos_channel_relay bin) + 5 pass (epistemos_channel_worker bin) = 471 pass, 0 fail, 0 ignored

$ cargo test --manifest-path epistemos-core/Cargo.toml
→ 366 pass, 0 fail, 0 ignored

$ xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
→ ** BUILD SUCCEEDED **
(SwiftLint failures appear on two vendored CodeEdit* targets — CodeEditSourceEditor and CodeEditTextView. Unrelated to Phase 6.)

$ xcodebuild … build-for-testing
→ succeeded

$ xcodebuild … test-without-building \
    -only-testing:EpistemosTests/DeviceAgentServiceTests \
    -only-testing:EpistemosTests/ControlPlaneSurfaceTests \
    -only-testing:EpistemosTests/RuntimeValidationTests
→ 193 tests in 3 suites pass in 1.276s, 0 fail
```

The existence of two real CLI binaries — `epistemos_channel_relay` and `epistemos_channel_worker` — and their passing tests (`build_send_payload_uses_webhook_for_slack`, `build_send_payload_preserves_email_subject`, `success_ack_request_uses_safe_display_target`) is additional evidence that the channel delivery path is genuinely wired, not stubbed.

---

## 5. Gap matrix

| Deliverable | Code status | Test status | Live-verified | Gap class |
|---|---|---|---|---|
| `send_message` (8 adapters) | real | 14 unit tests pass + worker bin tests pass | **no** | verification only |
| `vision_analyze` (claude + openai) | real | 4 unit tests pass | **no** | verification only |
| `image_generate` (FAL Flux) | real | 3 unit tests pass | **no** | verification + plan mismatch (see §6.2) |
| `text_to_speech` (macOS `say`) | real | 2 unit tests pass | **no** | verification only |
| `imessage` (rusqlite read + osascript send) | real | 13 unit tests pass | **no** (needs FDA + Automation) | verification + minor hardening |
| `imessage_contacts` | real | 8 unit tests pass | N/A (config only) | none |
| `ChannelRegistryState` | real, persisted, default nativeLocal | covered in RuntimeValidationTests | indirect | hardening (telemetry on fallback path) |
| `IMessageDriverService` | real polling, FFI-backed | covered in ControlPlaneSurfaceTests | **no** | hardening (no rate limit, model picker hardcoded) |
| `IMessageReplyDelegate` | real, reply-isolated | covered indirectly | **no** | none |
| `IMessageDriverSettingsView` | reachable, persists | build verified | **no** | cosmetic (model picker) |

No row in this matrix is "architecturally broken" or "implementation missing." Every gap is verification or minor hardening.

---

## 6. Plan-vs-code reconciliation — three real mismatches

Per `PHASE_6_PROTOCOL.md` §Step 2: architecture docs win on constraints, code wins on implementation status. Where the two are in real tension, I am listing it here so Codex (with user input) can choose which side to bend.

### 6.1 PLAN_V2 §3.4 "No silent behavior" vs. `FallbackDriverChannelAdapter`

PLAN_V2 §3.4 reads:

> No silent:
> - backend switching
> - cloud escalation
> - adaptation
> - mask application
> - sidecar activation
> - **fallback**
>
> Everything important must be surfaced in telemetry and summaries.

`PHASE_6_PROTOCOL.md` is narrower — it only calls out "no silent local-to-cloud fallback" for the iMessage route. I originally treated the `FallbackDriverChannelAdapter` (relay → native-local) at `ChannelRegistryState.swift:263-269` as a non-issue because the direction is not local→cloud.

Re-reading PLAN_V2, the broader rule *does* prohibit it:
- if the user configures a remote relay and it fails, native iMessage takes over **without surfacing a telemetry event, audit log entry, or user-visible indicator**
- this is a "silent fallback" under PLAN_V2's own definition

**Recommendation:** add a minimal reroute event at the point of failure. Two options:

- **Option A (minimal):** emit an `os_log` / `Logger.channel` warning inside `FallbackDriverChannelAdapter.send(...)` when the primary fails and the fallback succeeds, and record it on `IMessageDriverService.lastError` as a distinct "reroute" state the settings panel can render.
- **Option B (proper):** add a `DriverChannelRerouteEvent` to the channel registry and plumb it into an inspector surface. Matches PLAN_V2 §4.3 telemetry emission responsibility of the control plane.

Either option is a small, contained edit that keeps Phase 6 scope. I did not make this change because Phase 6 protocol Step 4 requires agreement on the approach before edits. Codex + user should choose.

### 6.2 PLAN_V2 §5.1 / §16 "image generation in MLX sidecar" vs. `image_generate` using cloud FAL.ai

PLAN_V2 is explicit:

> §5.1 MLX permanent role: embeddings, rerankers, classifiers, KAN helper modules, helper models, LoRA / micro-TTT experiments, summarization helpers, memory-compression helpers, **image generation**, Apple-native small models.
>
> §16 Keep image generation in MLX. Do not anchor long-term planning on DiffusionKit because it is archived. Prefer active MLX-Swift paths such as `flux.swift` and similar maintained Apple-native stacks. Default execution mode: sidecar, sequential.

Current `image_generate` in `media.rs:310-422` unconditionally posts to `https://fal.run/fal-ai/flux/dev` with `FAL_API_KEY`. Zero MLX path. That is a direct architectural mismatch with PLAN_V2 §5.1 + §16. It is also a latent violation of the broader "no silent cloud escalation" rule — although in this case the cloud call is explicit (the tool is called by name), so it is not *silent*.

**Recommendation:** I think the right move is to keep FAL as a `remote` mode (it's already good work), but re-add an MLX sidecar as the default, and require an explicit `mode: "remote"` or `provider: "fal"` parameter for the cloud path. Concretely:

- rename current handler to `FalFluxImageGenerateHandler`
- add a new `MlxFluxImageGenerateHandler` that dispatches to Swift via a new `AgentEventDelegate::generate_image(...)` callback
- default `provider` in the schema to `"mlx"` — cloud must be chosen opt-in
- update PLAN_V2 §5.1 / §16 to *explicitly* allow a `remote` image fallback so the two sides agree
- tier stays Agent for the cloud variant; MLX variant can drop to ChatPro because it's fully local

This change is larger than a Phase 6 hardening edit — it crosses the runtime/tool boundary and touches the FFI. My read: **do not make this change inside Phase 6**. Log it as the first Phase 6.1 or a near-term follow-up. Phase 6 can ship today with cloud-only image generation as long as PLAN_V2 §5.1 / §16 is amended to acknowledge that reality explicitly rather than leaving the plan claiming something the code doesn't do.

### 6.3 PLAN_V2 never anticipated iMessage as a driver channel

PLAN_V2 §4.1 talks about the Interface Layer (chat, notes, graph, code/editor, agent command center, future image and voice panels). It never mentions a messaging-channel driver — the idea of "iMessage as the main driver" appears in `docs/TOOL_TIER_AND_IMESSAGE_INTEGRATION.md` and `PHASE_6_PROTOCOL.md`, not in PLAN_V2.

Phase 6 has now landed an entire channel subsystem: `ChannelRegistryState`, 8 send adapters, `IMessageDriverService`, inbound-driver pairing modes (`nativeLocal`, `direct`, `webhook`, `remoteRelay`), and a relay worker binary. None of this is described anywhere in PLAN_V2.

**Recommendation:** add a new PLAN_V2 section — tentatively §4.7 "Messaging / Channel Layer" or a standalone `CHANNEL_SUBSYSTEM_SPEC_v1.md` — that documents:

- the channel registry as a product-state object (not a control-plane object)
- the adapter protocol (`DriverChannelAdapting`)
- the four pairing states and when each is legal
- the fallback policy (which ties back into §6.1 above — define it, require telemetry, never silent)
- the relationship between `send_message` (one-shot tool) and the channel driver (inbound autonomous loop) so future agents don't confuse them
- the tier rules for destructive sends

Without this, the next continuation agent will reverse-engineer Phase 6 from the commit history instead of reading one canonical page.

---

## 7. Non-blocking hardening candidates (specific pointers)

Clark did not make any code edits. The following are concrete, narrowly scoped edits that would materially strengthen Phase 6 without widening scope. Codex can pick these up safely.

1. **Per-contact rate limiting in `IMessageDriverService`.** The driver currently dedups by message ID but has no per-hour send cap. `TOOL_TIER_AND_IMESSAGE_INTEGRATION.md` lines 324-326 suggested 60/hour. Add a rolling window counter keyed by `contactHandle` and short-circuit `handleIncoming()` when the cap is hit. Surface the cap hit in `IMessageDriverService.lastError` so the settings panel shows it.

2. **Model picker backed by `ModelRegistryService`.** Today `IMessageDriverService.swift` lines 584-600 hold a hardcoded preset list. Replace with a computed property that queries `ModelRegistryService` and validates at set-time. Keep presets as a UI hint only.

3. **Reroute telemetry (from §6.1 above).** Either Option A or Option B.

4. **Optional: split `imessage` read and send tools.** `registry.rs:626-627` acknowledges that the whole tool is tagged Destructive because the `action: "send"` arg can fire. A granular split (`imessage_read` at ChatPro, `imessage_send` at Agent) would let ChatPro agents browse conversations without being able to reply. This is explicitly a design trade-off, not a bug — recommend as a small refactor the user should weigh against the added complexity.

5. **Optional: real private-IP test for signal-cli exception.** `communication.rs:448-453` documents that signal-cli-rest is allowed on private IPs by design. Add a test that *asserts* non-signal adapters still reject private IPs, so future refactors can't regress the carve-out.

Each of these is a <200-line contained edit. None of them require any PLAN_V2 change.

---

## 8. Manual runtime verification — the real closure blocker

Clark did not execute any of these. They are the human operator's job because they involve real outbound network calls, real API credentials, and real OS permissions on your actual machine.

| Tool | Requires | What "success" looks like |
|---|---|---|
| `send_message` | at least one test credential — Mailtrap SMTP or a Slack test webhook are fastest | one clean send + one deliberate missing-credential failure with a truthful error |
| `vision_analyze` (claude) | `ANTHROPIC_API_KEY` + one test image | one local-file path + one URL path + one non-trivial analysis |
| `vision_analyze` (openai) | `OPENAI_API_KEY` | same, different provider |
| `image_generate` | `FAL_API_KEY` | returns a non-empty URL that is fetchable |
| `text_to_speech` | Mac with audio output | live playback + one `output_path` file |
| `imessage` read | Full Disk Access on the test binary | reads a known test chat |
| `imessage` send | Automation permission for Messages.app + a safe recipient (yourself) | sends a test message to yourself and you see it appear in Messages.app |
| iMessage driver end-to-end | all of the above + one configured self-contact | send yourself an iMessage from another device; driver detects, agent replies via the assigned local model; verify no silent cloud escalation |

If any of these are blocked (no credential, no permission), the protocol says to document the blocker precisely and move on. Do not fake success.

---

## 9. Pointers / advice for Codex

This is the part the user specifically asked me to include. These are my observations from reading PLAN_V2 carefully against the code, and they are opinionated. Codex should treat them as input, not instructions.

### 9.1 The plan is stronger than the code in one place

PLAN_V2 is very clear about the oversight plane (§4.6, §10) and the agent hierarchy (§11). The code has Rust-side routing and policy, but the *inspectable* oversight surface described in §10.2 and §11.5 — "periodic quality audits", "user-facing transparency about what the system is doing", "every message must be logged with sender / recipient / purpose / evidence / confidence / cost / whether it changed the final result" — is not yet something Phase 6 builds on. Phase 6 adds new action surfaces (send / imessage / media) without yet hooking them into the oversight audit trail.

**Advice:** do not widen Phase 6 to build the oversight plane. That is explicitly deferred in PLAN_V2 §17 Phase 3 and §17 Phase 4. But when you scope Phase 7 or 8, **the first thing the new action surfaces need is the audit trail promised in §11.5**. Sends especially. "An iMessage was sent to contact X by model Y at time Z after reading context C" is exactly the kind of record PLAN_V2 §11.5 is asking for.

### 9.2 The code is stronger than the plan in one place

The **channel subsystem is more sophisticated than PLAN_V2 describes.** Four pairing states, an adapter protocol, a relay worker binary, a contact routing database, per-contact tool tiers, per-contact prompt modes. This is real product-shape architecture that PLAN_V2 never spelled out. It is not "wrong" — it is ahead of the plan.

**Advice:** resist the urge to rip it out or rewrite it to fit the plan. Instead, **write the plan up to match the code** (§6.3 recommendation above). The user wants the plan to be canonical with the code, and in this case the code is further along than the plan.

### 9.3 The Agent Command Center section of PLAN_V2 §4.1 is the aspirational spine

Clark did not audit the Agent Command Center code in this pass — Phase 6 scope did not require it. But reading §4.1 again, it is clear that the command center is *the* delegation surface the user wants to be the canonical way to invoke everything Phase 6 just shipped. Sending a message, generating an image, running a vision analysis, configuring an iMessage contact — all of these should be surfaceable via slash commands (`/send`, `/vision`, `/imessage configure`) in the command center, and their execution should flow into the right-side inspector panel described in §4.1.

**Advice for the next phase (not this one):** audit how many Phase 6 tools are actually reachable from the Agent Command Center today. My suspicion from reading `PHASE_5_HANDOFF.md` is that the command center is still mostly a parser+overlay with limited real control-plane wiring. If that is still true, the next phase should close that gap — not by rebuilding the command center, but by wiring Phase 6 tools into its suggestion source and inspector panel. This is the difference between "we shipped the tools" and "the user can actually use them the way PLAN_V2 §4.1 describes."

### 9.4 Image generation is going to be a user decision, not a plan decision

I flagged the FAL-vs-MLX mismatch in §6.2. Here is my honest read: **the plan says MLX-first, the code says cloud-only, and the product answer is probably "both, user's choice"** — with MLX as the default because it's local and free, and FAL as the opt-in power path.

But this is a product shape question, not an engineering question. The user should decide:
- **(A)** keep FAL as-is and weaken PLAN_V2 §16 to say "local preferred but cloud allowed" — fastest, ships now
- **(B)** do the MLX sidecar integration properly as Phase 6.1 — matches plan, takes real work, introduces a new FFI callback
- **(C)** remove the FAL path and wait for MLX flux.swift to land — most conservative, punishes Phase 6 users

I recommend (A) now and (B) as a near-term follow-up. Do not do (C).

### 9.5 iMessage-as-driver is the most ambitious Phase 6 idea and it needs a safety review before live verification

The iMessage driver is genuinely exciting — the code quality is good, reply isolation is enforced, permission denials are explicit, and the contact DB is clean. But **once you turn `keepAliveOnLaunch` to true, the app will poll iMessage, hand unread messages to a local model, and send replies on the user's behalf while the user is not looking.** That is a very different risk profile from a chat window the user is actively driving.

**Advice before live verification:**
- Start with **one self-contact only** (send yourself iMessages from another device)
- `auto_reply = true`, `auto_approve = false`, `tool_tier = chat_lite`
- Poll interval 10s or higher for the first few runs
- Watch the first N replies by hand before trusting them
- Verify the "STOP AGENT" kill-token idea in `TOOL_TIER_AND_IMESSAGE_INTEGRATION.md` lines 331-333 is actually wired (Clark did not verify this — it may or may not be implemented yet; grep for `STOP AGENT` in the driver service)
- Only then try a trusted second contact, and never without `allowed = true` being explicitly set per-contact

If the kill-token path is not implemented, that is a small follow-up edit worth doing **before** any non-self contact is added.

### 9.6 The doc convention has drifted

`PHASE_5_HANDOFF.md` still says "Phase 6 is still blocked" at lines 56-58. `PHASE_6_PROTOCOL.md` already supersedes it, but someone reading Phase 5 first will get whiplash. Add a one-line banner at the top of `PHASE_5_HANDOFF.md` pointing to `PHASE_6_PROTOCOL.md`, or better, add a pointer *inside* the "Why Phase 6 Is Still Blocked" section saying "This section is historical. See `PHASE_6_PROTOCOL.md`." I noticed `PHASE_5_HANDOFF.md` already has a "historical note" at the top but the scary blocker section below it still reads as authoritative. Tighten the banner.

---

## 10. Files Clark changed

**None.** This was a pure audit pass. Phase 6 protocol Step 1 said "do not implement before this matrix exists" and Step 4 said "fix one surface at a time" — but Clark did not identify any real implementation gap. Everything found is either verification (human operator) or a product decision (user + Codex).

---

## 11. Do-not-drift reminder

When picking up this handoff, Codex must not:

- rebuild Phase 6 from scratch
- start work on Phase 7 intelligence
- redesign the memory system
- redesign the Agent Command Center
- rewrite the runtime contract
- add speech-to-text, audio analysis, or any non-Phase-6 tool
- delete the FAL image_generate path before an MLX replacement exists
- disable the iMessage driver's silent-fallback guard, rate limit, or reply-isolation

Phase 6 scope is: Communication + Media, audit/verify/harden/close. Everything else is somebody else's phase.

---

## 12. One-line verdict

**Phase 6 not ready to close.** Code is sound, automated verification is green, but three decisions need to happen before the plan and the code line up:

1. decide how to surface the relay→native reroute (§6.1)
2. decide what to do about FAL-vs-MLX image generation (§6.2) — most likely: amend PLAN_V2, keep FAL, defer MLX to 6.1
3. document the channel subsystem in PLAN_V2 (§6.3)

Plus the manual runtime verification table in §8.

If the user accepts the recommendations in §6 and §9, Phase 6 can realistically close within one short session of plan edits + one session of live verification with credentials loaded.

---

## 13. Full PLAN_V2 §17 Phase-by-Phase Reconciliation (Phase 1 → Phase 6)

This section exists because the user explicitly asked for a canonical roadmap check, not just a Phase 6 check. The goal is to surface *drift* — places where the code advanced without the plan, where the plan ran ahead of the code, and where phases started out of the intended order.

Method: Clark dispatched a repo-wide audit of evidence for each PLAN_V2 §17 deliverable and cross-referenced against file / line citations. Status markers:

- ✅ **LANDED** — deliverable present, wired, tested
- 🟡 **PARTIAL** — scaffolding present but non-functional, or missing a key wiring step
- ❌ **MISSING** — no evidence in the repo
- ⚠️ **DRIFT** — code diverges from plan intent (ahead, behind, or different shape)

### Phase 1 — Stable runtime foundation — ✅ LANDED

| Deliverable | Status | Evidence |
|---|---|---|
| one real `gguf` primary path | ✅ | `Epistemos/Engine/LocalGGUFClient.swift` defines `LocalGGUFRuntimeAvailability`, `LocalGGUFRequest`, `LocalGGUFRunProfile`. Bridge registers GGUF callback at `bridge.rs:80-163`. |
| `mlx` preserved | ✅ | `Epistemos/Engine/MLXInferenceService.swift` imports MLX/MLXLLM/MLXVLM; thinking-mode active for Qwen, DeepSeek R1, Qwopus. |
| Rust control-plane authority | ✅ | `agent_core/src/routing.rs` owns `CloudProvider`, `LocalTask`, `RoutingDecision` enums. `bridge.rs` owns all FFI entry points with `ffi_guard_sync!`. |
| explicit fallback | ✅ | `routing.rs:33` `LocalWithFallback { local, fallback }` variant. |
| serial invariant / panic safety | ✅ | `bridge.rs:22-46` documents FFI boundary; `panic = "unwind"` + `ffi_guard_sync!` at line 50-63. |
| telemetry | ✅ | `reasoning_metrics.rs` implements `ReasoningTrajectoryMetrics` (displacement, curvature, loop detection). Bridged as `ReasoningTrajectoryMetricsFFI` at `bridge.rs:224-233`. |
| runtime truthfulness | ✅ | `ProviderRoutePreviewFFI` at `bridge.rs:235-242` exposes `requested_provider`, `resolution_kind`, `effective_provider`, `routing_summary`. |

**Verdict:** Phase 1 is fully landed. This is the most solid phase in the repo. No drift.

### Phase 1.5 — Scaffolding and truthfulness — 🟡 PARTIAL

| Deliverable | Status | Evidence / Gap |
|---|---|---|
| capability handshake | 🟡 | `OverseerProtocol.swift:1-25` defines handshake enums but no live pre-execution negotiation step is wired. Scaffolding only. |
| reasoning profiles | ✅ | `LocalGGUFClient` accepts `LocalReasoningMode`; `MLXInferenceService.swift:33-54` implements model-specific thinking-mode templates. |
| execution policy ref | 🟡 | `OverseerProtocol.swift:312-325` and `LocalGuardrailScaffold.swift:1-32` reference `executionPolicyRef`, but verdict is static — no dynamic policy evaluation. |
| **plan trace** | ❌ | **No `plan_trace` / `PlanTrace` type anywhere in agent_core.** This is a named Phase 1.5 deliverable and is not shipped. |
| agent-message protocol scaffolding | 🟡 | `OverseerProtocol.swift:443-546` documents the message shape, but there is no Rust-side router or validator. |
| overseer role scaffolding | 🟡 | `OverseerProtocol.swift` + `LocalGuardrailScaffold.swift` exist. No planner/guardrail overseer loop is active in execution. |
| local guardrail skeleton | ✅ | `LocalGuardrailScaffold.swift:58-60` `evaluate()` returns `LocalGuardrailDecision`. |
| KAN pilot off main path | ❌ | No KAN code in repo. Acceptable — PLAN_V2 says "off main path" — but the pilot itself doesn't exist. |

**Drift:** `plan_trace` is a named deliverable with zero implementation. `capability_handshake` is an unfulfilled contract — `BACKEND_INTERFACE_SPEC_v1.md §7` specifies a full handshake API and it is not wired. Overseer and guardrail are structurally present but functionally dormant.

**Recommendation:** before Phase 7 work begins, close Phase 1.5 by shipping (a) a real `plan_trace` type that accompanies every generation call, (b) the handshake pre-check from `BACKEND_INTERFACE_SPEC_v1.md §7`, and (c) flipping the guardrail scaffold from static to actually-invoked. These are small, contained edits and they unblock the audit trail requirements of §11.5.

### Phase 2 — Compute steering — ❌ MISSING (by design, but watch out)

| Deliverable | Status |
|---|---|
| Compute Steering Spec v1 implementation | ❌ |
| DIET / DIP experiments | ❌ |
| expert budget classes | ❌ |
| KV policy abstraction | 🟡 (enum only in `OverseerProtocol.swift:13-18`, no cache management) |
| mask compiler skeleton | ❌ |

**Drift:** The absence is correct per plan ordering — Phase 2 is gated on Phase 1 stability and Phase 1.5 completion. Phase 1.5 is not complete. So **Phase 2 should stay missing until Phase 1.5 closes**.

**Warning:** The Swift-side `OverseerKVPolicyFlag` enum and `LocalGuardrailScaffold` imports of compute-steering-adjacent concepts suggest someone was sketching Phase 2 UX before the Rust-side spec landed. Do not let the Swift enum harden into load-bearing UX until Rust owns the KV policy.

### Phase 3 — Adaptation + oversight helpers — 🟡 PARTIAL, ⚠️ DRIFT

| Deliverable | Status | Evidence / Gap |
|---|---|---|
| Adaptation Subsystem Spec v1 implementation | 🟡 | `ssm_state.rs` persists Mamba hidden state with session tracking. No LoRA micro-update pipeline. |
| MLX helper-model LoRA adaptation | ❌ | `OverseerLoRABlendCoefficient` at `OverseerProtocol.swift:43-58` is a Swift struct only. Not wired to MLX. |
| anchor / rollback / canary | ❌ | SSM state has save/load, no anchor or canary. |
| local guardrail overseer prototype | ❌ | Scaffold is static, no loop. |
| SSM memory sidecar prototype | 🟡 | `ssm_state.rs` exists; no sidecar invocation or background distillation loop. |

**Drift flagged:** `ssm_state.rs` is *ahead of its phase order*. Phase 3 should not begin until Phase 2 is stable. The SSM state plumbing sits in an odd place: it exists, but it has nothing upstream to feed it and nothing downstream to use it. **This is a classic drift signature — infrastructure that was built because someone had the skill-pack loaded, not because the phase was ready for it.**

**Recommendation:** do not delete `ssm_state.rs`. But mark it explicitly "pre-Phase-3 scaffold, not yet wired" in a code comment, and **do not extend it further** until Phase 2 closes. Otherwise it will quietly accumulate complexity and become load-bearing by accident.

### Phase 4 — Advanced research — ✅ CORRECTLY ABSENT

All five deliverables (IFPruning, stronger planner overseer, richer hierarchy, advanced expert budgeting, main-model adaptation) are absent. This is per plan — Phase 4 is explicitly "only if previous phases are stable." They are not.

**No drift.** This is the discipline you want.

### Phase 5 — Product-level intelligence — 🟡 PARTIAL, ⚠️ DRIFT

This is the phase `PHASE_5_HANDOFF.md` already audited. My Phase 1-5 recheck re-confirms its findings and adds one important observation:

| Deliverable | Status | Evidence / Gap |
|---|---|---|
| persistent memory | 🟡 | `agent_core/src/tools/memory.rs` (ported from Hermes v0.7.0) implements MEMORY.md + USER.md store with threat scanning. Missing: session-start hydrate, session-end consolidation, semantic/episodic/procedural separation, provenance graph. |
| skill accumulation | ✅ | `agent_core/src/tools/skills.rs` — CRUD, YAML frontmatter, directory hierarchy. `skills_list` / `skill_view` / `skill_manage` wired in registry. |
| workspace/profile ontology | 🟡 | `SDWorkspace.swift` persists workspace snapshots. No profile-local memory namespacing. No action-permission boundaries. **UI-level only, not enforced at data model** — PLAN_V2 §19 explicitly says this is not enough. |
| OpenClaw-like executable workspace | ❌ | Workspace snapshots exist; no executable workspace with declared allowed-tools / escalation perms. |
| Hermes-like memory | 🟡 | Code ports Hermes v0.7.0 basics. Missing Hermes' semantic/episodic/procedural distinction and graph integration. |
| dedicated Agent Command Center | ✅ | `AgentCommandCenterView.swift`, `AgentCommandCenterState.swift`, `CommandInputParser.swift`, `CommandCenterRequestCompiler.swift` all present. |
| **Command Center wired to Rust control plane** | ⚠️ **DRIFT** | `CommandCenterRequestCompiler.swift:64-80` produces `CompiledCommandCenterRequest` but **no matching Rust FFI entry point** (e.g., `compile_command_center_request(...)`) was found. The compiler is Swift-only. |
| multimodal sidecars | ❌ | No sidecar lifecycle in inference path. Image generation is a cloud tool, not a sidecar. |
| remote planner escalation with local guardrail | ❌ | No remote planner loop. Local guardrail is static. |

**Major drift observation:**

`PHASE_5_HANDOFF.md` listed six exit criteria for Phase 5 (§Minimum Exit Criteria Before Phase 6):
1. explicit `@` attachments become real execution context — **still ⚠️ partial**
2. requested vs resolved runtime visible — **unverified by Clark**
3. inspector driven by runtime truth — **unverified by Clark**
4. **Rust owns final request compilation / routing / permission truth for the Command Center path** — **NOT MET.** `CommandCenterRequestCompiler` is Swift-only. No Rust FFI for it.
5. hierarchy and execution diagnostics inspectable — **no evidence landed**
6. focused tests for the Command Center contract — **some parser tests, no end-to-end contract**

`PHASE_6_PROTOCOL.md` waived these by saying "Phase 5 is closed enough for Phase 6 to begin." Technically that waiver is in tension with `PHASE_5_HANDOFF.md` §Minimum Exit Criteria. **Phase 6 is executing while Phase 5 exit criterion #4 is unmet.**

**Recommendation:** after Phase 6 closes, the very next piece of work should be closing the real Phase 5 exit criterion #4 — moving Command Center request compilation into Rust. This is the single largest architectural violation in the current code: PLAN_V2 §3.1 says Rust is the sole authority for routing, permission, and request compilation, and `CommandCenterRequestCompiler.swift` is a second control plane in Swift. That violates PLAN_V2 §3.1 and `PHASE_6_PROTOCOL.md`'s rule "No second control plane in Swift."

### Phase 6 — Communication + Media — 🟡 SUBSTANTIALLY COMPLETE

Covered in §5 and §6 above. Summary: code is real, tests pass, three plan-vs-code mismatches and a manual-verification gap remain.

**Meta-observation:** Phase 6 is *not in PLAN_V2 §17 at all*. PLAN_V2's phased roadmap stops at Phase 5. Phase 6 was scoped in `PHASE_6_PROTOCOL.md` as "the Communication + Media slice" without being inserted into the §17 phase ordering. This is its own drift signal — the plan has been extended operationally without being updated canonically. **PLAN_V2 §17 should explicitly list Phase 6 (Communication + Media) and Phase 7 (whatever is next) so that future sessions inherit a single source of truth.**

### Cross-phase drift summary

| Drift | Severity | What to do |
|---|---|---|
| Phase 5 exit criterion #4 unmet (Rust does not own Command Center request compilation) — Phase 6 started anyway | 🔴 High | **Close it after Phase 6.** Plumb `CompiledCommandCenterRequest` through a new Rust FFI entry point. Delete the Swift-side routing logic. |
| Phase 1.5 `plan_trace` deliverable missing | 🟠 Medium | Small contained edit. Required before any Phase 2 work. |
| Phase 1.5 capability handshake not wired | 🟠 Medium | `BACKEND_INTERFACE_SPEC_v1.md §7` specifies the API; implement it. |
| `ssm_state.rs` landed ahead of Phase 3 order | 🟡 Low-Medium | Freeze further work on it until Phase 2 closes. Do not delete. Comment it as pre-phase scaffold. |
| PLAN_V2 §17 never updated to include Phase 6 | 🟡 Low-Medium | Add Phase 6 + intended Phase 7 to §17. |
| PLAN_V2 §5.1 / §16 says image gen is MLX-first sidecar; code is FAL cloud | 🟡 Low-Medium | Amend plan to allow cloud mode explicitly (see §6.2 of this handoff). |
| PLAN_V2 §3.4 forbids silent fallback; `FallbackDriverChannelAdapter` is silent | 🟡 Low-Medium | Add reroute telemetry (see §6.1). |
| PLAN_V2 never anticipated a messaging channel subsystem; code has 8 adapters + relay worker | 🟡 Low-Medium | Write `CHANNEL_SUBSYSTEM_SPEC_v1.md` or add a new §4.7 to PLAN_V2. |
| `OverseerKVPolicyFlag` / `OverseerLoRABlendCoefficient` exist in Swift without Rust implementation | 🟡 Low | Do not harden these in UX until Rust owns them. |

**The biggest single drift risk** is the one I want to be very explicit about: **the Agent Command Center has a Swift-resident request compiler, and that is a second control plane.** PLAN_V2 §3.1 and `PHASE_6_PROTOCOL.md` both forbid it. It needs to be the highest-priority architectural cleanup after Phase 6 closes. Every subsequent phase that adds new tool surfaces will make the Swift compiler harder to retire.

### What "canonical" means for this repo, concretely

When the user says "I want the plan to be canonical," the practical test is:

1. A new agent can read `PLAN_V2.md` + `PHASE_6_PROTOCOL.md` + `BACKEND_INTERFACE_SPEC_v1.md` and correctly predict what the code does.
2. Every PLAN_V2 §17 phase has a corresponding "status" marker that a human can verify in under 15 minutes using the test suite.
3. No major subsystem exists in code without a one-paragraph reference in PLAN_V2 or a sibling spec.
4. No subsystem exists in PLAN_V2 that has zero code.

Right now the repo fails on test (1) for the Command Center and the channel subsystem, fails on test (3) for the channel subsystem, and fails on test (4) for `plan_trace` and capability handshake.

**Closing all four gaps is the definition of "canonical."** It's roughly two sessions of plan edits + one session of small Rust wiring. None of it is Phase 6 scope — but all of it is a natural Phase 6.5 / Phase 7 prelude.

— Clark, 2026-04-14
