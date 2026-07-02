---
id: 6AEFC20B-A6AA-43DD-80DF-646A86DDDF46
title: SETTINGS-SIMPLIFICATION + ROBUSTNESS + INTEGRATION — Research Hub (2026-06-19)
---

# SETTINGS-SIMPLIFICATION + ROBUSTNESS + INTEGRATION — Research Hub (2026-06-19)

**Why (owner 2026-06-19):** *"robust ways to simplify setup + further settings for ALL the
things I'm adding to my app — and even my app's own settings parts that can be further simplified,
and parts of the other (cloned) settings that can be simplified + made more robust + connect better
with my app in full. Endless research on all these parts — make sure it touches all the things that
will be added / repaired."* GOVERNING BALANCE (from the ledger): **simplify the PRESENTATION +
automate the defaults; preserve ALL the FUNCTIONALITY. Progressive-disclosure (collapsed-but-
reachable) ≠ hiding/deleting. Never amputate.** Feeds the build loop (read after MASTER_SYNTHESIS).

> [!INFO]
> **Cross-reference:** `SESSION_COVERAGE_MATRIX_2026_06_19.md` maps EVERY owner concern (pre-compaction + thread) → ledger + slice + status (129 items, all verified present).

> [!INFO]
> **▶ EPDOC BUILD ORDER:** `EPDOC_MD_V2_BUILD_SEQUENCE_2026_06_20.md` — the 7-phase dependency-ordered build plan consolidating SS-O/EM/FM/IR/P (repair→serializer→canonical-flip→frontmatter→recall→rich-UI→backlinks). Read before coding any Epdoc item.**▶ CODE-NEXT ORDER:** `IMPLEMENTATION_SEQUENCE_2026_06_19.md` — the highest-leverage ready-to-code [S] wins across ALL slices, tiered (Tier 0 model-install/run → Tier 4 hardening). Read it to pick what to build next.

## Methodology — iterative deepen + broaden (rotate each pass)

Each pass: persist completed agents' findings into a slice doc + this hub's findings log + commit;
then advance the next slice (broaden) or deepen a done one. Cross-link new docs into the main hub.

## Slice backlog


| #     | Slice                                                                                                                                                                                                                                                                                   | Status                                                                   |
| ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| SS-A  | Cloned-app setup/settings simplification + robustness + integration                                                                                                                                                                                                                     | ✅ done → SS-A_CLONED_APP_SETTINGS_SIMPLIFY                               |
| SS-B  | Epistemos's OWN settings — simplify the sprawl                                                                                                                                                                                                                                          | ✅ done → SS-B_APP_SETTINGS_SIMPLIFY                                      |
| SS-C  | SETUP / ONBOARDING flow — first-run + per-feature auto-config for everything added (models/engines/MCP/voice/logos): the "it just works" path                                                                                                                                           | ✅ done → SS-C_ONBOARDING_SETUP                                           |
| SS-D  | Settings INTEGRATION — one coherent settings model: how clone settings + app settings + new-feature settings (model stack, MCP-install, per-engine sections) cohere + share state                                                                                                       | ✅ done → SS-D_SETTINGS_INTEGRATION                                       |
| SS-E  | DEFAULTS &amp; AUTOMATION audit — everywhere the app asks the owner to configure something it could derive/default; make it auto                                                                                                                                                        | ✅ done → SS-E_DEFAULTS_AUTOMATION                                        |
| SS-F  | ROBUSTNESS of settings — persistence, honest gating, validation, no-fake, witness; settings that silently fail or don't apply                                                                                                                                                           | ✅ done → SS-F_SETTINGS_ROBUSTNESS                                        |
| SS-G  | The MODEL-INSTALL setup specifically (owner's #1 blocker) — the simplest robust click-to-installed path                                                                                                                                                                                 | ✅ done → SS-G_MODEL_INSTALL_PATH                                         |
| SS-H  | CROSS-ENGINE native tool/skill SHARING (owner 2026-06-19) — Osaurus/Goose/OpenClaw access the app's native tools+skills via the shared registry; skills/tools/"superpowers" work for BOTH local AND cloud models in chat                                                                | ✅ done → SS-H_CROSS_ENGINE_TOOL_SKILL_SHARING                            |
| SS-I  | EXTERNAL SKILL ECOSYSTEMS — Anthropic/Vercel/Google                                                                                                                                                                                                                                     | ✅ done → SS-I_EXTERNAL_SKILL_ECOSYSTEMS                                  |
| SS-J  | BROWSER-USE in ALL surfaces (owner 2026-06-19) — the actual github browser-use available across Act/Work/Osaurus + chat; make the app useful in those locations                                                                                                                         | ✅ done → SS-J_BROWSER_USE_EVERYWHERE                                     |
| SS-K  | VOICE-MODEL PICKER (owner 2026-06-19) — choose voice models in Settings + a chat-surface TTS picker that only fires on TTS; robust + minimal                                                                                                                                            | ✅ done → SS-K_VOICE_MODEL_PICKER                                         |
| SS-L  | OpenAI + Cursor skills/tools/superpowers + PROVIDER AGENTS on chat (owner 2026-06-19) — OpenAI skills, Cursor skills, and OpenAI/Google/Claude AGENTS available on the chat surfaces                                                                                                    | ✅ done → SS-L_PROVIDER_AGENTS_OPENAI_CURSOR                              |
| SS-M  | OBSCURA browser + AGENT-SCRAPER + PRIVACY via WebKit (owner 2026-06-19) — research+harden the Obscura WebKit browser + web scraping + privacy stack                                                                                                                                     | ✅ done → SS-M_OBSCURA_SCRAPER_PRIVACY                                    |
| SS-N  | SENSITIVE-INFO REDACTION MODEL (owner 2026-06-19) — the OpenAI open-source model that detects/redacts sensitive info (PII); research + add + harden, on-device privacy                                                                                                                  | ✅ done → SS-N_SENSITIVE_INFO_REDACTION                                   |
| SS-O  | EPDOC REPAIR (owner 2026-06-19) — root-cause the glitchy/demo-ish WKWebView/Tiptap Epdoc editor (autosave/JS-bridge/render race) + harden + bring Notion/Tolaria-style rich UI/UX; NEVER touch TK2/Prose                                                                                | ✅ done → SS-O_EPDOC_REPAIR                                               |
| SS-P  | v2 WEBKIT MD EDITOR (owner 2026-06-19) — optional SECOND md editor cloned from Tolaria on WebKit, pixel-art minimal + macOS-26 style + fonts; standalone or fused with Epdoc; never touch TK2/Prose                                                                                     | ✅ done → SS-P_TOLARIA_V2_MD_EDITOR                                       |
| SS-Q  | VOICE CLONING + BITCRUSH DSP (owner 2026-06-19) — Apple Personal Voice cloning (macOS-26 viability) + a bitcrush AVAudioEngine effect over any voice + custom branded system voice; premium-default                                                                                     | ✅ done → SS-Q_VOICE_CLONING_BITCRUSH                                     |
| SS-R  | MORE LOCAL MODELS (owner 2026-06-19) — LFM2/ternary-BitNet/Bonsai/SmolLM/Gemma3n/Phi/Granite/MiniCPM; Apple-Silicon-runnable, install-any, advertise-canon, verify-runtime no-fake                                                                                                      | ✅ done → SS-R_MORE_LOCAL_MODELS                                          |
| SS-S  | VULNERABILITY AUDIT techniques (owner 2026-06-19) — robust security+correctness sweep (injection/SSRF/secret-leak/unsafe-unwrap/subprocess/MAS-escape/silent-fail/FFI-deadlock); repair-before-add gating discipline                                                                    | ✅ done → SS-S_VULNERABILITY_AUDIT                                        |
| SS-T  | PDF LIVE NATIVE VIEWER + MAX-OUT APPLE-NATIVE FRAMEWORKS (owner 2026-06-19) — PDFKit live viewer + QuickLook + sweep VisionKit/Translation/PencilKit/AppIntents/etc., integrate the high-value MAS-safe ones                                                                            | ✅ done → SS-T_PDF_VIEWER_APPLE_NATIVE                                    |
| SS-U  | DARK/LIGHT MODE CRASH (owner 2026-06-19) — root-cause the appearance-switch crash (WKWebView colorScheme re-render/teardown race, theme CSS re-inject, force-unwraps) + harden the crashing surfaces                                                                                    | ✅ done → SS-U_DARK_LIGHT_MODE_CRASH                                      |
| SS-V  | AGGRESSIVE CODE-CHECKER ("nuclear …") (owner 2026-06-19) — identify the Cursor aggressive-review tool + wire an equivalent adversarial static-analysis checkpoint at MULTIPLE plan points                                                                                               | ✅ done → SS-V_NUCLEAR_CODE_CHECKER                                       |
| SS-W  | RECENT CRASH + LOG STUDY (owner 2026-06-19) — study DiagnosticReports + app logs (llama-completion inference crashes + any others), root-cause + add fixes to plan                                                                                                                      | ✅ done → SS-W_CRASH_LOG_STUDY                                            |
| SS-X  | CHAT MESSAGE-BAR STILL MESSY (owner 2026-06-19) — the bottom chat bar still shows think/pro/tools old options on chat surfaces; simplify/demuddify (the picker-simplification didn't fully reach the message bar) + robust teardown/memory transitions                                  | ✅ done → SS-X_CHAT_MESSAGE_BAR_SIMPLIFY                                  |
| SS-Y  | HYPERDYNAMIC DETERMINISM / deterministic schema for LOCAL agents (owner 2026-06-19) — make local agents MORE useful than cloud via deterministic-schema/constrained-decoding + robust agent-loop upgrades; the "playground to make local models better"                                 | ✅ done → SS-Y_HYPERDYNAMIC_DETERMINISM                                   |
| SS-Z  | PER-MODEL BESPOKE ENGINEERING FRAMEWORK (owner 2026-06-19) — modernized per-model (local+cloud) tuning (context window, tool-call dialect like LFM, prompt format) that does NOT clash; every model utilizes the app's skills; chat-first, Act/Work only non-clashing additions         | ✅ done → SS-Z_PER_MODEL_ENGINEERING_FRAMEWORK                            |
| SS-AA | GITHUB PER-MODEL ENGINEERING STUDY (owner 2026-06-19; extends SS-Z) — harvest proven per-model patterns (prompt/template/tool-dialect/context/sampling/adapters) from llama.cpp/Ollama/vLLM/SGLang/LiteLLM/Outlines/XGrammar/Aider/etc.                                                 | ✅ done → SS-AA_GITHUB_PER_MODEL_ENGINEERING                              |
| SS-AB | MODEL CAPABILITY PROFILE — DEFINITIVE hardened combo + per-model profiles/descriptions + picker use-case copy (owner 2026-06-19)                                                                                                                                                        | ✅ done → SS-AB_MODEL_CAPABILITY_PROFILE_DEFINITIVE                       |
| SS-P+ | TOLARIA FULL PORT + DYNAMIC HTML-WORKSPACE-DOM + best-of-GitHub-MD + agent-MD (owner 2026-06-19; expands SS-P) — full Tolaria WebKit port MD-first, GitHub-grade dynamic HTML/DOM visuals, harvest best features from popular + agent MD editors; builds on SS-O; never touch TK2/Prose | ✅ folded into SS-P (graft-not-clone; GitHub-DOM + agent-MD in SS-P plan) |


## FINDINGS LOG (appended each pass)

**SS-A CLONED-APP SETTINGS** → the machinery already ships (`SettingsDisclosureSection` = the literal 'Advanced' container; GateStatus+HealthRow triad; native absorbers ModelStack/Authority/Skills). Pattern = a reusable `EngineSettingsSection` (curated native simple front: model→stack, perms→Authority, skills→Skills, MCP→ONE consolidated panel) + a `… · Advanced` disclosure with the full surface. Per clone: auto-default the plumbing (ports/dirs/keys/sandbox), surface ~3-5 knobs simply, full settings under Advanced. **OpenClaw (33-section config) = reskin its config-form via CSS injection + keep it under `OpenClaw · Advanced` — never hide it (reverses S3).** Top move = consolidate MCP-install into one panel. Full: SS-A doc.
**SS-B APP'S-OWN SETTINGS** → 70 files/23.5K lines; the #1 sprawl = ~46 health rows across THREE diagnostics homes → merge into ONE default-collapsed `DiagnosticsPanel` (3 at-a-glance rows + collapsed groups). 'Models' is a label not a home → collapse 4 sections into ONE Models home (Night Brain toggle dupes; .cognitive caption mismatch). MCP scattered across 3 components → ONE 'MCP &amp; Tools' home. Co-locate flag toggles with their witness rows. New 'Engines' section for per-engine cards. 6 cats/19 sections → 5/~10; never delete (progressive-disclose). Full: SS-B doc.
**SS-I EXTERNAL ECOSYSTEMS** → the hard parts EXIST (Epistemos speaks SKILL.md + has the quarantine/ProvenanceGate `skill_manage` install path + MCP stdio/URL connectors + the FineTunePack marketplace template). **Anthropic Agent Skills = the ONLY true importable SKILL.md ecosystem** (Apache ones direct_import; doc-skills proprietary→quarantine). Vercel = NO skill packs (UI only) → MCP. Google = NO SKILL.md catalog → MCP. Needs: unify the 4 skill dirs (Phase-0 #5, prereq), a ½-day frontmatter compat shim, honor allowed-tools, a skill-marketplace UI cloned from FineTunePack. Full: SS-I doc.
**SS-G MODEL-INSTALL PATH (owner's #1 blocker)** → the engine pipeline is ROBUST (download→verify→atomic→
resume, live progress, ungated download); the blocker is pure UX + a MISSING per-model Install button. Owner's
named models (Gemma/LFM2/VibeThinker) are GGUF foundation models NOT in the MLX `curated/optionalBaseline`
lists the "advanced" disclosure renders — and `ModelStackSettingsView` lists them but only with an advertise
toggle, NO Install. The engine already supports per-GGUF `install(modelID:)` (the one-tap package proves it).
**Fix ≈ 1 slice: (1) add a per-row Install/Installing/Installed control to `ModelStackSettingsView` wired to
`install(modelID:)`+`presentationState`+`ModelInstallProgressDisplay` [#1 visible win] · (2) promote the
install surface out of the modal sheet, rename Inference→Models · (3) de-dup the MLX-only disclosure · (4)
label the verify phase + bounded retry.** Install ALWAYS downloads; gating shows on selectable-state not the
Install button. Full: SS-G doc.
**SS-L PROVIDER AGENTS + OpenAI/Cursor skills** → answers the owner's "at what LEVEL is an agent created":
**NOT a file-structure / installable-skill / new agent-type** — an agent = `(mode=.agent)×(provider)` on the
in-process loop that ALREADY exists (`agent_loop.rs:151`, cloud-only gate `:166`). ~80% built. Why it failed
before = provider not agent-tier'd + hosted tools not wired + no agent label, NOT a missing agent format.
NEW (all small): wire OpenAI hosted web_search (highest leverage), promote Google to agent-tier, add an
agent-identity picker label (greys non-agent providers), Cursor `.mdc`→SKILL.md shim. REJECT hosted
Managed-Agent containers + importing Agents-SDK/ADK (no-sidecar). Only Anthropic is a true SKILL.md source;
OpenAI=hosted tools, Cursor=config. Full: SS-L doc. (Slices SS-C/D/E/F/J/K/M/N still queued.)
**SS-H CROSS-ENGINE TOOL/SKILL SHARING** → the shared `ToolRegistry` + `ToolTier` ladder is REAL and **already
serves BOTH local and cloud chat** (each engine binds its own tier-instance via the `ToolTierBridge`→
`list_tools_for_tier`/`execute_tool_call` FFI; skills flow from ONE `~/.epistemos/skills/` dir — Anthropic/
Vercel/Google SKILL.md files drop straight in). **TWO gaps:** (1) KEYSTONE — local chat drops to a tool-less/
skill-less stream when the model's `canRunLocalAgentLoop==false` + no agent-capable backup fits memory
(`PipelineService.swift:342-388`); (2) the cloned engines are INERT — Osaurus (`ActOsaurusBridge`) + Goose
(`WorkBackend`) never bind the registry; omega-mcp has a true duplicate registry. **Fix (smallest first):
inject the ChatLite skills catalog into local chat even when not looping [S]; bind Osaurus [S] + Goose [M] to
the registry via `ToolTierBridge`; auto-route to a fitting agent-capable model when the small one can't loop
[M]; unify omega-mcp [L].** Sharing = shared registry-by-value + shared memory, never shared logic. Honest
gating preserved (local-never-agent-tier, MAS Pro compile-out). Full: SS-H doc.
**SS-J BROWSER-USE EVERYWHERE** → ~70% exists: a real hardened Pro-gated 11-tool `browser.*` family + the
`BrowserEngine` trait (Mock-only; WebKit/Obscura adapters are doc comments) + the computer-use AX/vision loop
(`DeviceAgentService`) which IS browser-use's loop. **Honesty flag: the current `browser.rs` path SPAWNS the
foreign `agent-browser` CLI → violates no-sidecar.** App-native answer = build the in-process `WebKitBrowser Engine` (WKWebView + `evaluateJavaScript` DOM→`PageSnapshot` + synthetic events) = the ONLY MAS-safe browser
path. One tool registers once (`registry.rs:2672`), reaches all engines via the tier ladder + `ToolTierBridge`.
*Plan: surface existing browser. to Chat [S]; build WebKitBrowserEngine + re-route off the CLI + add to
coreAppStoreAllowedToolNames [M]; widen DeviceActionType DSL [M]; Obscura Pro adapter [L].** Lift browser-use
v0.13's ClickableElementDetector clean-room (MIT); Playwright/Chromium subprocess is the un-portable part.
Full: SS-J doc.
**SS-K VOICE-MODEL PICKER** → MOSTLY EXISTS: real Apple-native TTS stack + per-model voice picker grouped by
quality tier (`ModelVoicePickerSection`) + Settings home (Cognitive) + chat speaker button (`ReadAloudButton`
on `MessageBubble:407`) + Pro-gated `say` agent tool. **The owner's "plain/low-def voice" = a ~2-line fallback
bug:** `preferredVoice()` (`EpistemosSpeechSynthesizer.swift:227`) falls to the macOS-26-regressing
`AVSpeechSynthesisVoice(language:)` path (returns Compact even when premium installed); AND `MessageBubble`
passes no `voiceIdentifier` so chat read-aloud always hits that fallback. **Fix (all [S]): scan speechVoices()
for highest-quality match instead of `(language:)`; pass a voiceIdentifier from a new global @AppStorage default;
add a "Voice…" submenu to the speaker button's context menu (the contextual chat picker, zero new chrome).**
Higher-def: Apple premium/enhanced (local, MAS-safe, the right default) → Personal Voice [L]; NO cloud/neural
TTS now (local-first). Full: SS-K doc.
**SS-M OBSCURA + AGENT-SCRAPER + PRIVACY** → privacy primitives + a real HTTP scraper EXIST (`web.fetch/extract/ crawl`, MAS-safe, SSRF-guarded BFS; `nonPersistent()` WKWebView stores ×5); Obscura the stealth engine + the
*agentic* scraper do NOT. Obscura = a trait stub returning `NotConfigured` (`browser_engine/mod.rs:319-363`; no
`obscura-*`/`deno_core` deps). NO LLM extract-to-schema loop (web_crawl is goal-blind BFS). ZERO
anti-fingerprinting (no UA spoof, no `WKContentRuleList`, no canvas/WebGL overrides). **Plan: WKContentRuleList
tracker-block + customUserAgent (MAS-safe, pure WebKit, no entitlement) [S]; agentic scraper = web_crawl frontier

- LLM extract-to-schema head (grammar-bound) [M]; WebKitBrowserEngine for SPA pages (=SS-J's [M]) [M]; Obscura
deno_core stealth engine Pro+sign-off [L].** Local-first; stubs honestly NotConfigured. Full: SS-M doc.
**SS-N SENSITIVE-INFO REDACTION** → mostly-new. Secret/credential redaction EXISTS (regex `PIIRedactor` scoped
to FeedbackLogger; Rust `redact_credentials`; error-string redactors) + the NER primitives EXIST (NLTagger
`.nameType`, NSDataDetector) but are wired to note-insight NOT redaction; NO PII model at the cloud-egress seam.
**The owner's "OpenAI model" is REAL = OpenAI Privacy Filter (Apr 2026, Apache-2.0, gpt-oss-derived, on-device,
8 PII categories) — BUT ONNX/safetensors only, no MLX/GGUF → not drop-in today.** Honest mapping: ship Apple
NLTagger NER + NSDataDetector + Rust regex (MAS-safe, default-on, covers 6/8 categories) NOW; gate Privacy-Filter
as Pro/Research pending an MLX/CoreML port. **Plan: shared `SensitiveInfoRedactor` + flagged pre-egress hook at
`claude.rs:284` (+openai/gemini) [S]; wire existing NER in [S]; reversible tokenize→restore + settings toggles
[M]; Privacy-Filter/local-LLM embed [L/Pro].** NEVER cloud-detect PII; witness with egress no-PII test. Full:
SS-N doc.
**SS-O EPDOC REPAIR** → Epdoc is a REAL complete Tiptap 3.24 WKWebView editor (built+staged `editor.js.br`
259KB, NOT a demo bundle); the "glitches/fails" are concrete roots: (1) floating panels (slash/bubble/KaTeX)
use hardcoded pixel offsets with **NO viewport→window coord translation** (`EpdocEditorChromeView.swift:417,431, 442`) — the dominant visible glitch; (2) **JS errors fail SILENTLY** — no WKNavigationDelegate, no
window.onerror, empty Swift `.error` break (`:304`); (3) window-close drops the in-flight keystroke
(`shutdown()` doesn't `flushNow()` before detach, `:774-788`); (4) lossy markdown round-trip (no md-out
serializer). **Repair (NOT touching TK2/Prose): surface JS errors [S]; flush-on-close [S]; fix panel coords
[M]; harden ready-handshake + watchdog [M]; WKNavigationDelegate + process-termination reload [M]; Epdoc health
row [M].** Tolaria-class rich UI = SS-P. Full: SS-O doc.
**SS-U DARK/LIGHT MODE CRASH** → VERIFIED-from-code root: `HTMLWorkspacePreviewView` has `.id(previewRender Identity)` keyed on the **theme hash** (`HTMLWorkspaceEditorView.swift:340,617`) + `onChange(colorScheme)`
re-stamps (`:33-35`) → every appearance flip **destroys+rebuilds the WKWebView mid-render** (`dismantleNSView`→
`makeNSView`), the classic WebKit fault window; fires every toggle while the workspace preview is open =
"often crashes." Root #2: `.id` recreation races the message-handler attach/detach. Root #3 (lower): Hologram
Overlay KVO→`setLightMode` re-entering Metal mid-teardown (`:2276` missing the `==nil` guard `:934` has). CLEARED:
no force-unwraps in color path, no `.sync` in callbacks, Epdoc/KaTeX WebViews hardened+not-recreated, WKProcess
Pool-swap hypothesis STALE (removed). **Fix: drop the theme hash from the `.id` + push theme via `updateNSView`
[S] — removes roots #1+#2, tiny change; re-entrancy-safe teardown [M]; HologramOverlay guard [M]; UI test [L].**
Crash MECHANISM needs runtime repro (no `.ips` captured; only unrelated llama-completion inference crashes
2026-06-16 present). Full: SS-U doc.
**SS-T PDF VIEWER + APPLE-NATIVE MAX** → NO live PDF viewer exists (PDFKit is extract-only in `VaultParser .swift:239`, never `PDFView`); PDF is export-only (`HTMLWorkspacePDFExporter`) + import-to-markdown (LiteParse,
honestly `.notWired`). App ALREADY uses a rich native stack (CoreSpotlight, AppIntents/Shortcuts, Vision OCR,
Speech, **Translation** `.translationPresentation`, WidgetKit, CryptoKit, CoreML); **ABSENT: QuickLook,
QuickLookThumbnailing, VisionKit Live Text, PencilKit, PhotosUI, MapKit, EventKit.** **Plan: PDFView viewer
surface (NSViewRepresentable + thumbnails/outline/find/selection, reuse `PDFDocument(url:)`) [S, the #1 ask];
QuickLook universal preview [S]; QLThumbnailGenerator [S]; OCR-over-PDF→RRF search [M]; VisionKit Live Text [M];
send-selection-to-chat + AppIntents [M]; PencilKit/PDFAnnotation [L].** All MAS-safe, no new entitlements for
the PDF/QuickLook/OCR path. Integrate via vault+SearchIndexService+ToolTierBridge seams. Full: SS-T doc.
(Slices SS-C/D/E/F + SS-P/Q/R/S/V queued.)
**SS-W RECENT CRASH** → the captured crashes = `llama-completion` SIGABRT ×2 (2026-06-16) on llama.cpp
`common_chat_templates_apply` (uncaught throw → abort) = the GGUF model's chat template can't be applied (the
Pro local GGUF CLI lane). Fix: classify the subprocess exit at the Epistemos boundary (never crash/wedge the
app) + pass an explicit per-model `--chat-template`/`--jinja` with chatml fallback + pre-flight validation + pin
llama.cpp + add an in-app crash recorder (app-level crashes like dark/light SS-U aren't being captured as
`.ips`). Full: SS-W doc.
**SS-Z PER-MODEL FRAMEWORK** → per-model config is scattered across ≥4 places + split into TWO disconnected
universes: MLX `LocalTextModelID` (rich `switch` ladders — ctx `:708`, reasoning cap, tool tier) vs GGUF
`GemmaQATRuntimeCandidate` (**ZERO inference config** — the actual Chat local path incl. new LFM2.5/VibeThinker/
MoE). **The SS-W crash falls right out of this:** `gguf_cli.rs:244-270` passes NO `--chat-template`/`--jinja`
(relies on the embedded template that throws); ctx hardcoded 4096 for ALL models (`:32`); the per-model dialect
map `NativeToolGrammar` (`LocalToolGrammar.swift:27`) is DEAD code (never wired, no Gemma/LFM2 cases); skills
reach models only via prompt + the GGUF lane bypasses the loop. **Design: ONE `ModelCapabilityProfile`
(ctx/promptFormat/toolCallDialect/sampling/tier/skills) both universes resolve to; use llama.cpp's
`--jinja --chat-template-file` (the `.jinja` is already downloaded) to fix the crash [S]; keep GBNF
`--json-schema` as the primary tool-call (SS-Y) — forced-valid-JSON makes dialect moot; wire the dead dialect
map [S]; unify tiers+skills gate [M]; collapse the two universes [L].** Chat-first; non-clashing/additive. Full:
SS-Z doc.
**SS-Y HYPERDYNAMIC DETERMINISM (local&gt;cloud)** → the thesis is architecturally reachable but UNWIRED on the live
lane. Edge = guaranteed-valid + reproducible tool calls (GGUF `--json-schema`+`--seed 0`, `gguf_cli.rs:111-159`)
that cloud CAN'T promise. **TWO built-but-dark levers:** (1) the live MLX generator only does SOFT EOS penalties,
NOT hard masking (`MLXConstrainedGenerator.swift:16-18`) — but the project ALREADY vendors a real
`GrammarMaskedLogitProcessor` that NO product code references → wiring it = guaranteed-valid local tool calls
[S, highest leverage]; (2) the `HyperdynamicLoop` repair engine is built+tested+falsifier-proven but ORPHANED
(`gate_*_through_loop` zero callers `mission_run.rs:331`; `HyperdynamicLoopMetrics.ingest` zero callers). **Plan:
wire the vendored masked processor + flip isFullyConstraining [S]; connect LoopCounters→health row [S]; route
LocalAgentLoop's 5 ad-hoc repairs through the bounded HyperdynamicLoop under hard mask [M]; confidence-weighted
Best-of-N (NOT naive majority — weak for small models) [M]; evaluate vendored XGrammar backend [L].** Per-model
dialects (SS-Z) bind to the masked decode. Full: SS-Y doc.
**SS-X CHAT MESSAGE-BAR** → ROOT: the main-chat bar passes `preferSplitToolbarControls:true` (`ChatInputBar .swift:967`) which renders the legacy "Think/Code/Tools/Effort/Native" SPLIT toolbar, and `usesSplitToolbar Controls` (`RootView.swift:660`) is NOT gated on `simplifiedLineupActive` — so the simplification flag never
reached the bar. Result: TWO model pickers on the main bar (flat `inlineRuntimePickerTrigger` + the split row);
MiniChat + Landing already use the single flat picker. **Fix: drop `preferSplitToolbarControls:true` at
ChatInputBar.swift:967 [S, the direct fix] + add `.onDisappear` to cancel the recall debounce task (mirror
MiniChat:1080, teardown gap) [S] + gate `usesSplitToolbarControls` on `!simplifiedLineupActive` [M] + fold
Effort/Native into the popover's Advanced disclosure (never delete) [M].** No WKWebView on chat bubbles (SS-U
teardown doesn't extend here). Full: SS-X doc.
**SS-Q VOICE CLONING + BITCRUSH** → mostly ASSEMBLY: USE existing Personal Voice = YES (`requestPersonalVoice Authorization` + `.isPersonalVoice` trait, macOS 14+); TRAIN in-app = NO (System Settings only — deep-link). The
bitcrush DSP ALREADY EXISTS in-repo (`AmbientFrequencyLivePlayer.swift:687-702` quantize+sample-rate-hold) — only
new work is routing `AVSpeechSynthesizer.write`→`AVAudioEngine`(player→crush→output) with int16→float32 convert.
**Plan: extract shared `BitcrushKernel` + `VoiceEffect` enum + pixel-art preset [S]; Personal Voice auth+filter +
picker group [S]; the write→engine effect lane on `EpistemosSpeechSynthesizer` behind optional effect param,
no-effect fast path preserved [M]; branded system voice = base+bitcrush preset [M].** All on-device, MAS-safe,
no cloud. Full: SS-Q doc.
**SS-AA GITHUB PER-MODEL STUDY** → 6+ leading projects (Ollama/LiteLLM/Aider/LocalAI/Cline/vLLM) INDEPENDENTLY
converged on SS-Z's exact design: per-model profile = DATA keyed by model id + constrained decoding as the
tool-call equalizer. **Best tools to adopt: llguidance** (MIT, Rust, native in llama.cpp via
`-DLLAMA_LLGUIDANCE=ON` AND droppable into Epistemos's Rust core via the existing UniFFI boundary → ONE grammar
engine across GGUF+MLX); **LiteLLM's capability table** (cloud half, bundled offline JSON, MAS-safe); **Ollama
Modelfile** data shape (add the MISSING per-model `stop` array); **Aider override-layering**; **llama.cpp
`--chat-template-file`** resolution. **SS-W crash root CONFIRMED = llama.cpp issue #11400** (template-apply exits
instead of reverting to chatml). **CRITICAL: Gemma — the model the GGUF lane actually runs — has NO native tool
dialect → constrained decoding is MANDATORY for it.** Plan: chatTemplate required+resolved + `--chat-template-file`
- per-model stop [S]; bundled ModelCapabilityProfile JSON [S]; template-driven dialect auto-detect [M]; GGUF
constrained-decoding v1 [M]; unify on llguidance [L]. Full: SS-AA doc.
**SS-R MORE LOCAL MODELS** → honest shortlist for 16GB Apple Silicon. **Cleanest adds (Apache-2.0 + MLX
in-process):** Qwen3 (0.6/1.7/4B, think-toggle+tools), SmolLM3-3B (hybrid reasoning+native tools), SmolLM2-360M
(ultra-Fast), Gemma 4 E2B/E4B QAT (already in catalog, "Gemma 4" is REAL not an alias), Granite 4 Nano; Phi-4-mini
- R1-Distill-1.5B are MIT. **LFM2/2.5 now has MLX (BOTH lanes) — license catch: free commercial only ≤$10M
revenue (flag legal); tool-dialect = pythonic.** **Bonsai + BitNet are HONESTLY research/Pro-only** (Bonsai
base-only+16-bit, Ternary-Bonsai GGUF fails to load "ggml type 41", BitNet needs the separate bitnet.cpp fork) —
never on the Fast/Think happy path. VibeThinker-1.5B (owner pick, top tiny math reasoning) KEEP but verify
license. Each maps to SS-AA ModelCapabilityProfile (ctx/template/toolDialect). Full: SS-R doc.
**SS-F SETTINGS ROBUSTNESS** → persistence mostly honest (the @AppStorage + *Flags.userDefaultsKey single-source
pattern is real; Eidos/VaultRecall/SystemG/ACS/FUlp/PromptTree have verified readers). **3 concrete holes
simplification skipped:** (1) FAKE toggle `EPISTEMOS_GRAPH_INDEX_CHATS` (`SettingsView.swift:1386`) — ZERO
runtime readers (no-fake violation, self-admitted "status-only"); (2) REAL default-drift BUG — `summaryInterval`
settings @State defaults 15m but the service defaults 5m (`WorkspaceSummaryService.swift:24`) → fresh install
shows 15m while engine runs 5m; (3) two orphan HealthRows (`CognitiveDagHealthRow`/`HyperdynamicLoopHealthRow`)
never instantiated. Plus the raw-@State cluster (`:772-783`, stale-read) + flag↔witness split (graphIndexChats/
rrfFusion/powerUserMode have no co-located proof). **Fix: summaryInterval default + convert 3 raw-@State to
@AppStorage [S]; demote the fake toggle to a disabled 'reserved' row OR wire it [M]; re-home/gate orphan rows
[M]; co-locate flag→witness chips [M].** All harden, never delete. Full: SS-F doc.
**SS-AB MODEL CAPABILITY PROFILE (DEFINITIVE)** → the once-and-for-all hardened combo (synthesis of Z/AA/R): ONE
data-driven `ModelCapabilityProfile` (Ollama-Modelfile shape + LiteLLM capability table + Aider override-layering)
both universes resolve to; **llguidance as the SINGLE grammar engine across GGUF+MLX (build loop ALREADY added
the dep)** = guaranteed-valid tool calls (mandatory for Gemma = no native dialect); **llama.cpp
`--chat-template-file` resolution makes the SS-W crash structurally unreachable**; per-model `stop` array + ctx
(replaces hardcoded 4096). EVERY model gets a deep capability profile + benefitsDescription + a short
`pickerUseCase` shown on the picker (best advertised, all installable, no-fake). Plan: chatTemplate+stop+ctx [S];
bundled JSON + descriptions [S]; llguidance both lanes + dialect auto-detect [M]; surface pickerUseCase + profiles
[M]; unify tiers/skills [M]; collapse universes [L]; tests-at-end (no-empty-template falsifier). Full: SS-AB doc.
**SS-C ONBOARDING/SETUP** → a 4-step wizard EXISTS (`SetupAssistantView` welcome→vault→model→cloud→done, honest+
persistent) but TWO gaps: (1) the #1 blocker — **local-model install — is OFF-FLOW**: the model step punts to
"Open Settings → Inference" (`:202`) instead of installing; (2) the default-vault auto-config
(`FirstRunBootstrap.defaultVaultURL → ~/Documents/Epistemos` + scaffold, `:58-133`) is **DEAD CODE, zero
callers** — the wizard always asks via NSOpenPanel. Plus no reusable "feature ready/needs-setup/one-tap-enable"
card (closest = `CloudProviderSetupCard`); two overlapping welcome surfaces (SS-B). **Fix: wire defaultVaultURL
as a "Use Default Vault" button [S]; replace the model-step punt with an in-wizard "Install Recommended AI"
calling the existing `installEpistemosFoundationPackage()` (RAM-tiered, SS-AB) [S]; extract a reusable
FeatureSetupCard [M]; lazy point-of-use permissions [L].** Setup state persists honestly (SS-F). Full: SS-C doc.
**SS-D SETTINGS INTEGRATION** → HALF-integrated: the IA skeleton is already coherent (ONE `SettingsSection` enum
- ONE `safeDetailSelection` MAS-firewall/deep-link chokepoint `:181-194` — everything routes through it), but
content is scattered. **`AgentAuthorityStore` (@Observable, file-backed, one shared instance) is the ONE
correctly-consolidated state = the TEMPLATE to copy.** Drift/dup points: Night Brain toggled in 2 views (same
key, 2 homes); `AdvertisedModelStore` has a `@State advertisedIDs` mirror (2 instances, drift surface); MCP/tools
across 3 state owners. Violations: Models across 4 sections; MCP×3; ~46 diagnostics rows ×3 homes; flags↔witness
split. **Target (into the existing enum, NO new sidebar): ONE Models home (SS-AB profile SOT) + ONE MCP&amp;Tools +
ONE Diagnostics + an Engines section (SS-A EngineSettingsSection — doesn't exist yet, must build) + Privacy +
Advanced.** Plan: de-dupe Night Brain [S]; single Diagnostics home [S]; one Models detail + AdvertisedModelStore
→ @Observable [M]; one MCP&amp;Tools registry [M]; Engines section [L]. Full: SS-D doc.
**SS-E DEFAULTS &amp; AUTOMATION** → reassuring: the runtime engine is ALREADY strongly derive-first (idle-unload by
RAM band, model-fit gate, complexity auto-sizing Fast→E2B/E4B/12B ON by default, per-model ctx + sampling, routing
.auto — owner never sets them). ~80% of inference config is DERIVE. **The gap is ONBOARDING (converges with
SS-C):** the 2 highest-value asks — vault path + first model — could auto-default but don't (dead
`defaultVaultURL` + model-step punt). **Plan: wire `installEpistemosFoundationPackage` into onboarding [S];
default vault to `~/Documents/Epistemos` (revive dead code) [S]; read GGUF n_ctx instead of 8192 fallback [M];
reconsider heartbeat/ssm AC-gated default-ON [M].** Ports/dirs/caches already auto-defaulted (SS-A pattern).
Flag-ON≠wired clones stay honest-inert (don't auto-ON). Full: SS-E doc. (Settings cluster A/B/C/D/E/F COMPLETE.)
**SS-P TOLARIA v2 MD EDITOR (covers SS-P+)** → **Tolaria's "Notion editor" IS BlockNote** (Tauri/React/Rust,
AGPL-3.0); its creator **started in Swift, hit MD-editor limits, switched to a web editor** — validating
Epistemos's WebKit-Tiptap choice. **Recommendation (honesty-saving): do NOT clone Tolaria (AGPL-3.0 ✗ closed MAS)
and do NOT add a 2nd WebKit surface — GRAFT Tolaria-class rich UI onto the SS-O-repaired Epdoc/Tiptap (single
surface), harvest PATTERNS from MIT/Apache editors** (Tiptap's own Notion template, Novel Apache, Milkdown MIT,
CodeMirror-6). Agent-MD pattern = **Tiptap AI Toolkit** (JSON doc + insert/replace/diff/stream tools, BYO-LLM)
wired to agent_core+MCP. Pixel-art + macOS-26 Liquid-Glass both ride the EXISTING `EpdocEditorThemeStyle` CSS
injector (MAS-safe). GitHub-grade DOM via Tiptap custom NodeViews (collapsibles/Mermaid/code-pills/ToC). **AVOID
for closed code: Tolaria AGPL + BlockNote-XL GPL.** Prereq: land SS-O roots #2/#3 first. Plan: Notion template +
DragHandle [S]; pixel skin [S]; agent editing commands [M]; Liquid-Glass [M]; GitHub-DOM [M]; CodeMirror source
toggle + md serializer [L]. Full: SS-P doc. (EDITOR cluster SS-O/P/P+ COMPLETE.)
**SS-S VULNERABILITY AUDIT** → posture STRONG, NO High-severity in the first pass: zero `try!`/`as!`/`main.sync`
in Swift prod; robust SSRF guard (`web_fetch::validate_url`); subprocess hardening applied; `.bufferingNewest(256)`;
secrets in Keychain. **MEDIUM: M1** — MAS network tools (`media`/`communication`/`browser`/`web_fetch`) gated by
DENYLIST not allowlist (`registry.rs:59`) → reachable in MAS unless risk_level/pro-build gates them; flip to
fail-closed allowlist. **M2** — 6k+ Rust `unwrap`/`expect` not proven test-only; an `unwrap` panic on the FFI
boundary (`bridge.rs`) aborts the app → wire clippy `unwrap_used` + triage prod sites. LOW: regex
`preconditionFailure` (OutlineNavigatorView:163) if user-free-text; rest are intentional tripwires/false-pos.
**Discipline (gate before add, composes with SS-V): grep gate → clippy/cargo-audit/cargo-geiger/SwiftLint tool
gate → adversarial-skeptic → MAS fail-closed → provenance log.** Full: SS-S doc. **ALL backlog slices A–Z+AA/AB
COMPLETE.**
**SS-LI LIVING-INDEX + LATTICE (the indefinite tail, researched last)** → the SUBSTRATE exists: the shadow index
is genuinely "living" (file-watcher + 500ms debounce → live incremental updates, `ShadowIndexingService`+
`VaultSyncService.swift:3573`); the Cognitive DAG has resonance propagation (library-complete but NOT live-driven
— scaffold/replay only); rich Metal/Hologram graph views + `CognitiveDagVisualizerPanel` (embryonic status
surface). **MISSING (the open frontier): no `LivingIndex` orchestrator, no concept-lattice/FCA engine, no
lattice-explorer UI.** "Lattice" names are false friends (`LatticeWBO` = oplog accountant; the HTML explainer =
unwired doc; concept-lattice = aspirational N3 doctrine only). Correctly sequenced LAST (indefinite, depends on
the rest). **Bounded first step (finite, T4-able): extend `CognitiveDagVisualizerPanel` into a read-only "Living
Index status" surface — surface what's already living (shadow liveness + DAG counts) BEFORE any lattice engine.**
Full: SS-LI doc. **ENTIRE research corpus now complete — including the indefinite tail.**
**SS-EM EPDOC FORMAT CONVERGENCE (md-canonical, projections)** → today Epdoc is **JSON-canonical** (`content.pm .json`) with markdown as a lossy write-only shadow + NO stored HTML (render-only); the package doc-comment even
says "Markdown is DERIVED, never canonical" — the flip inverts this. **KEY FINDING (answers the owner): the HTML
Workspace is a SEPARATE document type (`com.epistemos.html-workspace`), opened BLANK from a starter template,
ZERO data flow from Epdoc — it MIRRORS NOTHING.** De-risker: Tiptap 3.24 (repo's version) ships a first-party
Markdown extension + MarkdownManager (since 3.7.0) → real md↔JSON serializer is an in-version dep add.
**Recommended: ONE-WAY DERIVE + serialize-back (NOT CRDT — CRDT inverts the truth model).** content.md = REQUIRED
truth; content.pm.json = derived cache; HTML = pure render; Pandoc for exports only. Hash-pinned drift detection;
HTML-in-markdown fallback for rich-only blocks (nothing dropped); FAIL-LOUD on parse error (end silent-degrade).
**HTML Workspace → make it a true opt-in projection** (seed index.html from a StaticRenderer projection of the
doc + pixel-art CSS). **Plan: add @tiptap/extension-markdown + bridge getMarkdown [S]; round-trip test suite
[S]; flip canonical + migration + drift-detector [M]; real md parser on load [M]; HTML-workspace projection [L].**
Pixel-art kept + theme-token-driven (more dynamic, native). Full: SS-EM doc.
**SS-PERF PERFORMANCE + MEMORY (recursive 'super-optimized' pass)** → app is ALREADY well-optimized (2 prior perf
waves); this is polish. **Top gains: (1) ~18 health-row 1Hz polling timers in `SubstrateHealthPanel` all fire at
once while Settings is open (`.onDisappear` doesn't fire for scrolled-off rows) → collapse to ONE shared
TimelineView clock [M, #1 gain×effort]; (2) MLX KV cache only freed reactively → proactively bound by token
length [M, 256-512MB]; (3) verify ShadowVault crawl is mtime/incremental not full re-read each launch [M];
(4) agent_loop response_blocks.clone() grows O(turns) → move-not-clone + mid-loop token-budget compaction [M];
(5) defer PowerGuard/EventStore into the deferred-services block [S, few ms].** Already-optimized (don't redo):
memory-pressure FFI chain, WKProcessPool sharing, MLX idle-unload, FTS PRAGMAs, ShadowIndexing debounce, tokio
minimal, to_string JSON. All MB figures are static estimates (no Instruments run). Full: SS-PERF doc.
**SS-UMA INSTANT-RECALL via UMA ZERO-COPY (flagship, honest)** → the sidebar is fast via 2 in-process engines
(FTS5 BM25 + epistemos-shadow tantivy/usearch/RRF k=60) + InstantRecallService (&lt;3ms). **THE GAP: the local
model does NOT use any of them** — `vault_recall`/`eidos.query` use a SEPARATE VaultStore + an in-memory semantic
index (the shadow/HNSW backing is NOT-STARTED, W-51), so the model queries a colder DUPLICATE index. UMA
honesty: zero-copy is real for MLX weights/KV but zero-copy of retrieved TEXT into the model's KV is NOT
achievable today (MLX-Swift takes `prompt:String`, no borrowed-buffer API). And the real bottleneck is token
GENERATION (100s ms-sec), not retrieval (already sub-10ms) — so the honest win is QUALITY (model finally
queries the warm RRF/HNSW = sidebar parity) + MEMORY (one tantivy index not two, ~15MB), NOT a dramatic speedup.
**Design: ONE warm shadow handle, two consumers; implement the W-51 shadow-backed VaultBackend adapter so model
recall hits the same RRF/HNSW fusion (Rust-&gt;Rust, no JSON round-trip); cloud keeps the tool interface.** Plan:
provenance tag [S]; share shadow handle [S]; W-51 adapter behind a flag [M]; bench before/after [M]; zero-copy-KV
= research-only/aspirational. Do NOT touch vault/graph/TK2-Prose. Full: SS-UMA doc.
**SS-SH SUBSTRATE HEALTH GLITCH (owner bug, root found)** → VERIFIED ROOT: ~15 health rows each run their own
1Hz timer doing a **SYNCHRONOUS Rust FFI round-trip ON THE MAINACTOR** + a SwiftUI invalidation, every second,
even while their section is collapsed (collapse doesn't fire `.onDisappear` reliably in a Form) → ~15 blocking
FFI/sec + ~15 invalidations/sec on one panel = main-thread contention → freeze/beachball/stutter (violates
CLAUDE.md "never block @MainActor"). One slow FFI call freezes the whole panel. Panel STRUCTURE is clean (Form +
3 Sections, no broken ForEach/EmptyView, not flag-gated); error handling is per-row honest. **FIX (= SS-PERF #1):
collapse all per-row `startTimer()` loops into ONE shared `TimelineView(.periodic)` clock that fetches
`SubstrateHealthUnifiedClient.snapshot()` OFF the MainActor (background actor → hop back to set @State) + fans to
rows; ~15 FFI/sec→1.** Plus retire the 2 orphan rows (SS-F). Precedent: ApprovalModalView already converted to
TimelineView. Full: SS-SH doc.
**SS-FM FRONTMATTER/TAGS/SIDE-PANELS (md-v2 Epdoc)** → BIG positive: Epistemos ALREADY OWNS a complete Notion-style
typed-property model + query engine for .epdoc (`EpdocProperty.swift` 8 kinds, `EpdocDatabase.swift` sort/group/
schema-union, manifest-backed) — but ZERO property/inspector UI + no YAML frontmatter parse. Plus a reusable
`WikilinkResolver` (backlink resolution) + Halo shadow index for `[[note]]`. So the feature is ~95% REUSE + a
panel, not a build-from-scratch. **Design (Tolaria-style right inspector rail, pixel-art): (a) Properties panel
rendering EpdocPropertyMetadata read/write through the existing writer→autosave; (b) frontmatter↔manifest.metadata
bridge (net-new, gated on SS-EM md-flip); (c) tags = frontmatter multiSelect (free tag index via EpdocDatabase
.grouped) + an inline #tag Tiptap node; (d) clickable [[note|note]] + backlinks panel reusing WikilinkResolver + shadow
index; (e) right rail w/ exclusive Properties/Backlinks/Tags/TOC tabs, Cmd+Shift+I.** Agent edits go through the
SAME property writer (SS-EM one-writer). Plan: read-only Properties panel + frontmatter parse [S]; editable props
- tags + tag-index [M]; wikilinks + backlinks + full inspector [L]. Never touch TK2/vault/graph. Full: SS-FM doc.
**SS-AL AGENT LOOP ROBUSTNESS (central engine deepening)** → cloud loop is SOLID (clean ReAct, real token
streaming, thinking-block preservation, 3 compaction triggers, honest error-obs feedback, parallel tool calls,
retries). **Local loop is where the gains are.** Confirms SS-Y with exact lines: **all local repair/structured
generations use a no-op token sink `{ _ in }` (masked decode)** (`LocalAgentLoop:1083,1132`) → self-correction is
invisible, user sees a stall — #1 fix = stream the repair tokens [low effort, high value]. **NEW high-value gap:
mid-stream SSE errors are NOT retried** (`claude.rs:309` with_retry wraps only the SEND; a transport drop mid-stream
aborts the whole agent run — `agent_loop:343`) → #2 fix = retry/resume mid-stream + thread the loop cancel.
Confirms the SS-PERF `response_blocks.clone()` waste (L535/557/693). **CORRECTION: SS-PERF's 'no in-loop
compaction' is partly WRONG — 3 in-loop triggers exist** (proactive 80% L296, reactive L660, MaxTokens L694).
Also: 5 fragmented local repair builders → unify via HyperdynamicLoop (SS-Y); tool-call parser only accepts
`<tool_call>`/JSON (SS-Z) → broaden; no outbound tool-INPUT redaction (SS-S ext). Ranked top fixes in the doc.
Full: SS-AL doc.
**SS-IR INSTANT-RECALL POPUP REDESIGN** → KEY FINDING: there are TWO recall surfaces. **Surface A (W8 Halo:
`HaloButton`+`ShadowPanel` NSPanel)** is already editor-scoped + native + click-gated = NEAR the target. **Surface
B (Contextual Shadows V0: `ContextualShadowsButton`+`ContextualShadowsPanel`)** is a SwiftUI overlay box that
AUTO-SHOWS while typing on chat/landing/mini-chat = **THE "weird pixel box that overlays things."** Owner's
complaint = Surface B (auto-shows on type `ContextualShadowsState.swift:465`; SwiftUI overlay inside the host
layout, no AppKit reposition; 520-740px). **Redesign: (1) stop B auto-showing — bubble lights, box doesn't open
[S]; (2) remove B from chat/landing/mini-chat [S]; (3) glow ring on HaloButton [S]; (4) slim ShadowPanelContent /
NSPopover anchored to bubble, .transient [M]; (5) accuracy-tune (longer debounce + wider limit + dual-domain RRF
merge — SS-UMA) [M]; (6) add bubble+popover to Epdoc via HaloEditorBridge.feed off the autosave hook [L]; (7)
unify the two recall systems [L].** TK2 already non-invasive (sibling NSHostingView, not in the NSTextView).
Accuracy-first confirmed (lean on warm RRF/HNSW). Full: SS-IR doc.

