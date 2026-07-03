# Big-Plan Curation — what to KEEP / MERGE / DEFER / CUT (2026-06-28)

> 🟡 **PARTIAL-SUPERSEDE 2026-07-02 (OpenChamber pivot).** Curation KEEP/MERGE/DEFER/CUT calls largely stand, but any "reskin Goose / Goose-as-surface / Option 1 / Goose-only" item is re-scoped: Agent surface = OpenChamber (Pro) / June+goose-in-process (MAS); goose = one engine. arXiv/Obscura kept dedicated (Obscura automation-vs-browser = open owner flag). Canon: memory `project_ui_base_pivot_openchamber_2026_07_02`.

> ⚠️ **SUPERSEDED on key points by the 2026-06-28 owner decisions:** Goose-only (three-engine Chat/Act/Work + Osaurus-as-Act = CUT) · ColBERT = CUT · Obscura = CUT (→ browser-use) · local model-management (HF/BYOM/stack/vision/DeerFlow) = CUT. This doc is the historical 4,498-line ledger inventory; for the LIVE scope read the 3 plans (Goose / EDITOR_CANONICAL_PLAN / PLAN_3_CAPABILITIES).


> Source = `OWNER_REQUESTS_LEDGER_2026_06_18.md` (4,498 lines, ~150 items), inventoried in full.
> Legend: ✅ already done · 🟢 KEEP (build it) · 🟡 MERGE→ (fold into another plan) · ⚪ DEFER (good, not now) · 🔴 CUT (drop)
> Tick/cross each line to curate. Editor items fold into `EDITOR_CANONICAL_PLAN_2026_06_27.md`.

## ★ MY HONEST OPINION (the TL;DR)
The big plan is **excellent but enormous** — way more than one person ships in a reasonable window. ~60% is genuinely worth keeping; the leverage is **cutting the speculative full-ports and deferring the heavy Pro-only subsystems**, then sequencing the rest behind a few P0 fixes. The single best move: **fix the chat-routing / launch-crash P0s first** (the app literally crashes / mis-routes today), then build the **editor canonical plan** + **Goose surface** (already in flight), and treat everything else as a curated backlog. Don't try to build all 150 at once — build the ~25 that matter and the rest follow or fall away.

**What I'd CUT outright (8):** fieldtheory full-port (AGPL+Electron), kuku port, OpenClaw full-WebKit port, Obscura in-app browser, stealth browsing, Holo computer-use vision lane, native ColBERT encoder, the pixel-art scroll-arrow gimmick.
**What I'd DEFER (10):** R-SYNC multi-device, overnight wikilink auto-research, Metal streaming overlay, voice cloning/bitcrush extras, data/finetune marketplace, R-AGENTFW, living-index indefinite loop, terminal/console, Tier-2/3 primitive byte-residency, R-LITELLM-CP.
**Everything else = KEEP or already DONE.**

---

## §1 — P0 / BROKEN (fix FIRST; all 🟢)
- 🟢 **Chat "credentials rejected" — local picks mis-route to cloud** (the real root: `sanitizedInteractiveLocalTextModelID` returns nil → auto-cloud → reject). #1 priority; chat is broken on-device.
- 🟢 **P0 launch crash on open** — SIGTRAP via SS-IR health-diagnostic `stats()` FFI before shadow backend ready. App won't open = absolute blocker.
- 🟢 **Model selection not honored** — runtime pins Qwen-3-4B regardless of pick; root = built-but-unwired RuntimeRouter + 4 duplicate dead routers to collapse.
- 🟢 **Model download/install broken** — only foundation package installs; progress/resume/integrity broken. Gates ALL in-app testing.
- 🟢 **Default = Qwen 4B** (should be a foundation Fast Gemma) — located bug, contradicts the lineup pivot.
- 🟢 **12B memory blocker** — add "run anyway" override + fix over-conservative estimate (use free+reclaimable).
- 🟢 **Dark/light toggle crash** + **theme-switch hang** (uncached `resolved` on MainActor) + **theme regression** (custom theme needs ~3 edits to apply).
- 🟢 **Blank Substrate-Health panel** — `Section(isExpanded:)` without `.formStyle(.grouped)`; one-line fix.

## §2 — Model routing / picker / install (mostly 🟢, several ✅)
- ✅ Per-model vaults · popover→inline picker · install progress/CTA · effort hints · Apple Intelligence route · tool-toggles real gating · mini/note/graph parity (all re-audited done).
- 🟢 **Mini-chat = main chat (full parity)** + Chat/Act/Work mode toggles in picker + search-page click regression + session-as-native-tab.
- 🟢 **Picker simplify + mode-scope** (name + uses + RAM only; effort/routing out) — the conscious reversal of "add everything."
- 🟢 **Qwen 8B re-selectable** · **vault "best essay" ranked answer** · **local tools actually run from chat** (verify, not just docs).
- 🟡 Provider/brand logos everywhere → collapse the ~15 staged slices into one "logo coverage" task. Lower priority.

## §3 — EDITOR & DOCUMENTS → `EDITOR_CANONICAL_PLAN` (🟡 merge; unique keepers 🟢)
Surface decisions are superseded by the canonical plan. **Unique feature ideas worth preserving inside it:**
- 🟢 **Markdown-first + auto-mirror (LOCKED)** — md = source of truth; md↔JSON↔HTML projection hardened against drift/corruption. (= the canonical plan's L1.)
- 🟢 **Rich↔raw note toggle** (one `.md`, Epdoc=rich / CoreEditor=raw) — now planned (matches Tolaria, richer).
- 🟢 **Frontmatter / tags / backlinks side panels** + **agent-can-edit-the-doc** chat integration.
- 🟢 **Wikilink parser/resolver/backlinks + typed edges onto the graph.** (⚪ DEFER the *overnight auto-research* runner.)
- 🟢 **HTML Workspace = AI-artifact surface** (chat rewrites whole surface into a website/explainer; mini-chat drives) — and **route hand-editing to code-editor v2** (fixes the blank-editor bug for free). [your idea ✅]
- 🟢 **Native PDF viewer (PDFKit)** + QuickLook/VisionKit framework max-out.
- 🟢 **PDF→Markdown import (R-LITEPARSE)** — done bar signed-build PDFium bundling. Core PKM ingest.
- 🟢 **Web clipper → clean-markdown note (R-WEBCLIP)** — real Obsidian-supersession win.
- 🟢 **Instant-recall / Halo popup scoped to the editors** + bubble→native NSPopover redesign + discoverable resting bubble.
- 🟢 **Two-surface fidelity / no data loss** — fix the 2 real data-loss bugs (Prose image drop, Epdoc lossy shadow.md).
- 🟢 **Graph inline-edit of document nodes** (no detached window) in both graphs.
- 🟢 **Home-graph tunnel** to Epdoc + HTML-workspace inline.
- 🟢 **EPDOC "take over Obsidian/Logseq/Notion/Roam"** = the acceptance bar (Notion-parity blocks, block-refs/transclusion, Bases views, import/export).
- 🟢 **Cold-box AI/user separation** for inline note-AI. (🔴 CUT the pixel-art scroll-down arrow.)
- 🟢 **Code-editor dropdown-arrow cleanup** (`.menuIndicator(.hidden)`) — trivial visual fix.
- 🟢 **Prose (TK2): frontmatter + non-invasive hardening + keep the name "Prose"** (frozen otherwise).
- ⚪ DEFER: **Metal streaming overlay for "Ask this note"** (pure polish).

## §4 — Agent engines: Chat / Act / Work (🟢 core; ⚪ heavy ports)
- 🟢 **Three modes: Chat=Epistemos · Act=Osaurus · Work=Goose**, code-isolated, connected via memory + capability superset. The central architecture directive.
- 🟢 **R-GOOSE engine extraction** (Apache-2.0 Rust → agent_core via UniFFI) — actively building, 9 slices landed. + its guardrail.
- 🟢 **Osaurus = Act full import** (MIT) — S2–S4 landed.
- 🟢 **Surface the already-built browser-use** tools into Act/Work (cheap; just unreachable today).
- 🟢 **AI memory sharing / Vault-MCP-server** — expose vault/KC/Eidos as a read-only local endpoint for external agents (Keychain-token, localhost, toggled). The moat made outward-facing.
- 🟢 **Right-side "agent cockpit" panel** (context/plan/tools/skills/tasks) for Act.
- 🟢 **Provider-specific agent on chat** (OpenAI/Google/Claude) — owner flags SENSITIVE (failed before); research the *level* first.
- ⚪ DEFER: **OpenClaw full-WebKit port** (heavy TS app; cherry-pick native patterns instead) · **Hermes fuse** (4 small clean-room lifts — low priority).

## §5 — Capability & extensibility (🟢 high-value)
- 🟢 **Skill/tool/MCP install + management in Settings** (GitHub + Smithery/mcp.so/glama) — real extensibility; scope a v0 (browse/install/persist).
- 🟢 **Best-of preset** — curated default power-set, one-tap. Pairs with the above.
- 🟢 **Harness systems** — port best-in-class RAG/memory/context/compaction/tool-plumbing into Chat/Act/Work. (The thing that makes chat *good* — scope tightly.)
- 🟢 **In-app HuggingFace + GitHub model marketplace** (absorbs bring-your-own-model) + **arXiv pull**.
- 🟢 **Skills/tools fire for local AND cloud everywhere** + cross-engine native sharing + import Anthropic/Vercel/Google skill ecosystems.
- 🟢 **Meeting/lecture note** — record → on-device STT → Epdoc note + AI summary.

## §6 — Models to add (🟢 concrete, fit 16GB)
- 🟢 Unsloth **Gemma 4 12B 2-bit GGUF** · **Gemma 4 26B-A4B QAT GGUF** (Pro) · **LiquidAI LFM2.5-8B-A1B** · BitNet/ternary, Bonsai, SmolLM catalog expansion (honest gating).
- 🟢 **On-device vision runtime (mlx-vlm)** for VLMs.
- 🔴 CUT: **Holo-3.1-4B computer-use** wiring + the **Pro vision GGUF lane** — too far out; depends on a net-new Pro subsystem.

## §7 — Voice (🟢 core; ⚪ extras)
- ✅ Voice picker + premium-voice honesty on quick capture (done). Auto-default to best installed (mostly done).
- 🟢 **Premium Apple voice default + macOS-26 voice-by-language regression fix + Kokoro-82M Pro voice + SSML prosody.**
- ⚪ DEFER: Personal-Voice cloning, real-time bitcrush DSP, brand voice, full read-screen stack.

## §8 — Substrate / determinism / provenance (🟢)
- 🟢 **Deterministic Schema Engine (P8.2)** — founding "local > cloud" thesis; ~10 slices shipped.
- 🟢 **Finish substrate to T4+** (Cognitive DAG, provenance, KC, Halo, GenUI, XPC, Eidos, EML) — absorbs P5.H + "substrate finished."
- 🟢 **Eidos→chat wiring** (closed-citation gate + "Retrieved by Eidos" panel) + the EML/REG local-routing research bundle.
- 🟢 **Provenance moat = the visible #1 differentiator** — AND fix the synthetic "verified" chips (a real honesty bug). [your strongest moat]
- 🟢 **Mine System G logic** (AnswerPacket/SovereignGate/router) into app parts without arming the gated 70B.
- 🟢 **Instant-recall via accuracy-first recall for local models** (zero-copy UMA path; quality > speed).
- 🟢 **Kill the MoLoRA/QLoRA Python subprocess** → in-process MLX-Swift (NO-SIDECAR constraint; ~80% done).
- ⚪ DEFER: **First-domino `research/` compile decision** (owner sign-off gate) · Tier-2/3 byte-residency primitives.

## §9 — Training (🟢 apply-gap; ⚪ rest)
- 🟢 **MLX-LoRA-Studio embed + fuse** — close the NativeAdapterApply→inference "use right after" gap (the real blocker). Scope to that first.
- 🟢 **Model Vault staleness + per-model file injection** — local models currently read ZERO vault context; real broken feature.
- ⚪ DEFER: native MLX training pipeline at large + data/finetune-pack **marketplace** + Night Brain idle training.

## §10 — DEFER (good, not now)
R-SYNC multi-device (176KB blast radius) · Obscura in-app browser · stealth browsing · OpenClaw full-port · R-AGENTFW frameworks survey · living-index indefinite loop · terminal/console (Pro) · R-LITELLM-CP (pattern-only) · R-CUA VM sandbox (lift only MAS-safe slices) · overnight wikilink runner · Metal streaming overlay.

## §11 — CUT (my recommended drops)
- 🔴 **fieldtheory full-port** — AGPL-3.0 + Electron, ~80% already native; keep only the clean-room "context launcher" pattern.
- 🔴 **kuku port** — off-hand AGPL repo; verdict already says SKIP code, adopt 2 patterns (memory-sharing + meeting-note, both kept above).
- 🔴 **OpenClaw full-WebKit port**, **Obscura browser**, **stealth browsing** — heavy, Pro-only, non-v1 (in DEFER if you disagree).
- 🔴 **Native ColBERT encoder (R-COLBERT)** — honest verdict says enhancement-not-gap; RRF + EML rerank already serve it.
- 🔴 **Holo computer-use vision lane** — speculative Pro subsystem.
- 🔴 **Pixel-art scroll-down arrow** gimmick.

## §12 — Process / governance rules (🟢 keep as doctrine, not features)
Harden-before→add→re-harden · app-native-by-embedding · no-sidecar · deletion guardrail (never delete new/in-progress) · **R-CODEREVIEW "thermonuclear" recurring review** · main-only no-worktree (data-loss guard) · commit-before-edit savepoint · **PROVEN-DONE 5-criterion doctrine + re-audit all `[x]`** · recurring owner-coverage/nuance sweeps · perf gate before+after · cleanliness gate · honest-no-hidden-fallback. These are the rails that keep everything else honest — keep them all.

## §13 — Duplicates to collapse (housekeeping)
R-APPS ×3 → one · R-GOOSE/R-OPENCLAW/R-HERMES restated → one each · bring-your-own-model → HF marketplace · SS-Z/SS-AA/item-48 → **ModelCapabilityProfile (SS-AB)** (foundation already landed) · P6.4c → Deep Settings Repair · "substrate finished" → P5.H/T4+ · R-CUA → Osaurus sandbox · R-JSONRENDER → GenUI.
