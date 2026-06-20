# SETTINGS-SIMPLIFICATION + ROBUSTNESS + INTEGRATION — Research Hub (2026-06-19)

**Why (owner 2026-06-19):** *"robust ways to simplify setup + further settings for ALL the
things I'm adding to my app — and even my app's own settings parts that can be further simplified,
and parts of the other (cloned) settings that can be simplified + made more robust + connect better
with my app in full. Endless research on all these parts — make sure it touches all the things that
will be added / repaired."* GOVERNING BALANCE (from the ledger): **simplify the PRESENTATION +
automate the defaults; preserve ALL the FUNCTIONALITY. Progressive-disclosure (collapsed-but-
reachable) ≠ hiding/deleting. Never amputate.** Feeds the build loop (read after MASTER_SYNTHESIS).

## Methodology — iterative deepen + broaden (rotate each pass)
Each pass: persist completed agents' findings into a slice doc + this hub's findings log + commit;
then advance the next slice (broaden) or deepen a done one. Cross-link new docs into the main hub.

## Slice backlog
| # | Slice | Status |
|---|---|---|
| SS-A | Cloned-app setup/settings simplification + robustness + integration | ✅ done → SS-A_CLONED_APP_SETTINGS_SIMPLIFY |
| SS-B | Epistemos's OWN settings — simplify the sprawl | ✅ done → SS-B_APP_SETTINGS_SIMPLIFY |
| SS-C | SETUP / ONBOARDING flow — first-run + per-feature auto-config for everything added (models/engines/MCP/voice/logos): the "it just works" path | ☐ |
| SS-D | Settings INTEGRATION — one coherent settings model: how clone settings + app settings + new-feature settings (model stack, MCP-install, per-engine sections) cohere + share state | ☐ |
| SS-E | DEFAULTS & AUTOMATION audit — everywhere the app asks the owner to configure something it could derive/default; make it auto | ☐ |
| SS-F | ROBUSTNESS of settings — persistence, honest gating, validation, no-fake, witness; settings that silently fail or don't apply | ☐ |
| SS-G | The MODEL-INSTALL setup specifically (owner's #1 blocker) — the simplest robust click-to-installed path | ✅ done → SS-G_MODEL_INSTALL_PATH |
| SS-H | CROSS-ENGINE native tool/skill SHARING (owner 2026-06-19) — Osaurus/Goose/OpenClaw access the app's native tools+skills via the shared registry; skills/tools/"superpowers" work for BOTH local AND cloud models in chat | ✅ done → SS-H_CROSS_ENGINE_TOOL_SKILL_SHARING |
| SS-I | EXTERNAL SKILL ECOSYSTEMS — Anthropic/Vercel/Google | ✅ done → SS-I_EXTERNAL_SKILL_ECOSYSTEMS |
| SS-J | BROWSER-USE in ALL surfaces (owner 2026-06-19) — the actual github browser-use available across Act/Work/Osaurus + chat; make the app useful in those locations | ✅ done → SS-J_BROWSER_USE_EVERYWHERE |
| SS-K | VOICE-MODEL PICKER (owner 2026-06-19) — choose voice models in Settings + a chat-surface TTS picker that only fires on TTS; robust + minimal | ✅ done → SS-K_VOICE_MODEL_PICKER |
| SS-L | OpenAI + Cursor skills/tools/superpowers + PROVIDER AGENTS on chat (owner 2026-06-19) — OpenAI skills, Cursor skills, and OpenAI/Google/Claude AGENTS available on the chat surfaces | ✅ done → SS-L_PROVIDER_AGENTS_OPENAI_CURSOR |
| SS-M | OBSCURA browser + AGENT-SCRAPER + PRIVACY via WebKit (owner 2026-06-19) — research+harden the Obscura WebKit browser + web scraping + privacy stack | ✅ done → SS-M_OBSCURA_SCRAPER_PRIVACY |
| SS-N | SENSITIVE-INFO REDACTION MODEL (owner 2026-06-19) — the OpenAI open-source model that detects/redacts sensitive info (PII); research + add + harden, on-device privacy | ✅ done → SS-N_SENSITIVE_INFO_REDACTION |
| SS-O | EPDOC REPAIR (owner 2026-06-19) — root-cause the glitchy/demo-ish WKWebView/Tiptap Epdoc editor (autosave/JS-bridge/render race) + harden + bring Notion/Tolaria-style rich UI/UX; NEVER touch TK2/Prose | ✅ done → SS-O_EPDOC_REPAIR |
| SS-P | v2 WEBKIT MD EDITOR (owner 2026-06-19) — optional SECOND md editor cloned from Tolaria on WebKit, pixel-art minimal + macOS-26 style + fonts; standalone or fused with Epdoc; never touch TK2/Prose | ☐ |
| SS-Q | VOICE CLONING + BITCRUSH DSP (owner 2026-06-19) — Apple Personal Voice cloning (macOS-26 viability) + a bitcrush AVAudioEngine effect over any voice + custom branded system voice; premium-default | ☐ |
| SS-R | MORE LOCAL MODELS (owner 2026-06-19) — LFM2/ternary-BitNet/Bonsai/SmolLM/Gemma3n/Phi/Granite/MiniCPM; Apple-Silicon-runnable, install-any, advertise-canon, verify-runtime no-fake | ☐ |
| SS-S | VULNERABILITY AUDIT techniques (owner 2026-06-19) — robust security+correctness sweep (injection/SSRF/secret-leak/unsafe-unwrap/subprocess/MAS-escape/silent-fail/FFI-deadlock); repair-before-add gating discipline | ☐ |
| SS-T | PDF LIVE NATIVE VIEWER + MAX-OUT APPLE-NATIVE FRAMEWORKS (owner 2026-06-19) — PDFKit live viewer + QuickLook + sweep VisionKit/Translation/PencilKit/AppIntents/etc., integrate the high-value MAS-safe ones | ☐ |
| SS-U | DARK/LIGHT MODE CRASH (owner 2026-06-19) — root-cause the appearance-switch crash (WKWebView colorScheme re-render/teardown race, theme CSS re-inject, force-unwraps) + harden the crashing surfaces | ☐ |
| SS-V | AGGRESSIVE CODE-CHECKER ("nuclear …") (owner 2026-06-19) — identify the Cursor aggressive-review tool + wire an equivalent adversarial static-analysis checkpoint at MULTIPLE plan points | ☐ |
| SS-P+ | TOLARIA FULL PORT + DYNAMIC HTML-WORKSPACE-DOM + best-of-GitHub-MD + agent-MD (owner 2026-06-19; expands SS-P) — full Tolaria WebKit port MD-first, GitHub-grade dynamic HTML/DOM visuals, harvest best features from popular + agent MD editors; builds on SS-O; never touch TK2/Prose | ☐ |

## FINDINGS LOG (appended each pass)
**SS-A CLONED-APP SETTINGS** → the machinery already ships (`SettingsDisclosureSection` = the literal 'Advanced' container; GateStatus+HealthRow triad; native absorbers ModelStack/Authority/Skills). Pattern = a reusable `EngineSettingsSection` (curated native simple front: model→stack, perms→Authority, skills→Skills, MCP→ONE consolidated panel) + a `… · Advanced` disclosure with the full surface. Per clone: auto-default the plumbing (ports/dirs/keys/sandbox), surface ~3-5 knobs simply, full settings under Advanced. **OpenClaw (33-section config) = reskin its config-form via CSS injection + keep it under `OpenClaw · Advanced` — never hide it (reverses S3).** Top move = consolidate MCP-install into one panel. Full: SS-A doc.
**SS-B APP'S-OWN SETTINGS** → 70 files/23.5K lines; the #1 sprawl = ~46 health rows across THREE diagnostics homes → merge into ONE default-collapsed `DiagnosticsPanel` (3 at-a-glance rows + collapsed groups). 'Models' is a label not a home → collapse 4 sections into ONE Models home (Night Brain toggle dupes; .cognitive caption mismatch). MCP scattered across 3 components → ONE 'MCP & Tools' home. Co-locate flag toggles with their witness rows. New 'Engines' section for per-engine cards. 6 cats/19 sections → 5/~10; never delete (progressive-disclose). Full: SS-B doc.
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
foreign `agent-browser` CLI → violates no-sidecar.** App-native answer = build the in-process `WebKitBrowser
Engine` (WKWebView + `evaluateJavaScript` DOM→`PageSnapshot` + synthetic events) = the ONLY MAS-safe browser
path. One tool registers once (`registry.rs:2672`), reaches all engines via the tier ladder + `ToolTierBridge`.
**Plan: surface existing browser.* to Chat [S]; build WebKitBrowserEngine + re-route off the CLI + add to
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
**SS-M OBSCURA + AGENT-SCRAPER + PRIVACY** → privacy primitives + a real HTTP scraper EXIST (`web.fetch/extract/
crawl`, MAS-safe, SSRF-guarded BFS; `nonPersistent()` WKWebView stores ×5); Obscura the stealth engine + the
*agentic* scraper do NOT. Obscura = a trait stub returning `NotConfigured` (`browser_engine/mod.rs:319-363`; no
`obscura-*`/`deno_core` deps). NO LLM extract-to-schema loop (web_crawl is goal-blind BFS). ZERO
anti-fingerprinting (no UA spoof, no `WKContentRuleList`, no canvas/WebGL overrides). **Plan: WKContentRuleList
tracker-block + customUserAgent (MAS-safe, pure WebKit, no entitlement) [S]; agentic scraper = web_crawl frontier
+ LLM extract-to-schema head (grammar-bound) [M]; WebKitBrowserEngine for SPA pages (=SS-J's [M]) [M]; Obscura
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
use hardcoded pixel offsets with **NO viewport→window coord translation** (`EpdocEditorChromeView.swift:417,431,
442`) — the dominant visible glitch; (2) **JS errors fail SILENTLY** — no WKNavigationDelegate, no
window.onerror, empty Swift `.error` break (`:304`); (3) window-close drops the in-flight keystroke
(`shutdown()` doesn't `flushNow()` before detach, `:774-788`); (4) lossy markdown round-trip (no md-out
serializer). **Repair (NOT touching TK2/Prose): surface JS errors [S]; flush-on-close [S]; fix panel coords
[M]; harden ready-handshake + watchdog [M]; WKNavigationDelegate + process-termination reload [M]; Epdoc health
row [M].** Tolaria-class rich UI = SS-P. Full: SS-O doc. (Slices SS-C/D/E/F + SS-P/Q/R/S + new SS-T/U/V queued.)
