# LOST ITEMS RECON — features that fell out of canon (2026-06-29)

> **Purpose:** the salvage recon the owner asked for — find features that were planned/built but FELL OUT of the
> current 5-plan canon (like the Tolaria mini-chat did) and route each back. Source = two parallel research agents
> mining `OWNER_REQUESTS_LEDGER_2026_06_18.md` (4.5k lines) + the drift/salvage corpus (PLAN_DRIFT_AUDIT,
> LEDGER_CURATION, STASH_RECOVERY, WORKTREE_SALVAGE, QUICK_CAPTURE_SALVAGE). Deduped + ranked + routed below.
> **Nothing here is lost anymore — it is captured + tracked.** Actual scope-insertion into a plan = owner-confirmed
> (the live plan prompts 1/2/3 are being built RIGHT NOW; do not silently redirect them).
>
> **Headline insight:** the biggest cluster is **Quick Capture** — the Rust substrate (`format/ canon/ grammar/ undo/
> route/ effect/ heal/ nightbrain/` cores) ALREADY LANDED in `agent_core` during the 2026-05-04 recovery, but the
> user-facing Swift UX (capture bar, action trace, 24h undo, review queue, skill-mint, NightBrain bodies) was never
> built. A genuinely-built capability sitting invisible = the highest-leverage, lowest-risk salvage in this list.
>
> Intentionally-CUT items were correctly excluded by both agents (Osaurus/Act/3-engine, ColBERT, model-management
> HF/BYOM/stack/vision, DeerFlow, Obscura-native). AI stays Goose-only.

## CONSOLIDATED SALVAGE TABLE (deduped, ranked by leverage × confidence)
| # | Feature | What it is | Route | Substrate? | Conf |
|---|---|---|---|---|---|
| 1 | **Quick Capture surface** | ⇧⌘Space single-field capture → auto-routes → 2s "filed here" toast | **Plan 6 (NEW)** | ✅ Rust `route/` landed | high |
| 2 | **Universal 24h Undo UX** | every auto-decision reversible ⌘Z within 24h (inverses precomputed) | **Plan 6 (NEW)** | ✅ Rust `undo/` landed | high |
| 3 | **Action Trace UI (⌘?)** | overlay: which tool ran, variant attempts pass/fail, alt-candidates+scores | **Plan 6 (NEW)** (pairs Plan 3 provenance) | partial | high |
| 4 | **Review Queue / triage HUD (⌘.)** | low-confidence captures → keyboard batch-triage HUD | **Plan 6 (NEW)** | ✅ Rust `route/` Variant-D | high |
| 5 | **Dark/Light toggle crash fix** | reproducible crash on appearance switch (likely WKWebView re-render race) | **Plan 7 (NEW)** stability | — | high |
| 6 | **In-app crash recorder** | capture appearance/agent crashes in-app (today only OS DiagnosticReports) | **Plan 7 (NEW)** | — | high |
| 7 | **PII / sensitive-info redaction** | on-device model detects+redacts PII (a *capability*, survives model-mgmt cut) | **Plan 3** (privacy, §6 Apple-native sibling) | — | high |
| 8 | **Vault-as-AI-memory endpoint** | localhost server so EXTERNAL tools (Claude Desktop/Cursor) read your vault as memory | **Plan 3** (sibling of vault-MCP) | — | high |
| 9 | **Skill auto-mint UX** | repeated 3+ tool sequence → drafts `.skill` behind compile-verify-mint + weekly digest | **Plan 3** (§5 extensibility) | ✅ Tier-C `skill_discovery/` | med |
| 10 | **NightBrain task bodies + UX** | idle/thermal/power-gated nightly upkeep: re-route, re-embed, recompute medoids, propose skills | **Plan 6 (NEW)** (D-13 deferred home) | skeleton (949 LOC) | med |
| 11 | **Agent cockpit right-side panel** | live run rail: context, plan/todo DAG, tools selected/in-use, skills, done tasks | **Plan 1** (Goose surface; home "Act" was cut, never re-homed) | reuse LiveActivityStrip | med |
| 12 | **Richer voice** | Personal-Voice cloning + real-time **bitcrush** DSP + custom Epistemos system voice + MOSS read-screen/read-replies/retro filter | **Plan 3** (extends Voice §11 — none shipped) | Apple TTS shipped | med |
| 13 | **Multi-device iCloud vault sync** | local-first sync via iCloud ubiquity, `.md`=SoT, `.epcache` never syncs; Pro git lane | **Plan 7 (NEW)** (high blast radius) | reuse `syncFromVault()` | med |
| 14 | **Context launcher** | global hotkey grabs frontmost-app context → injects into the agent | **Plan 3** (AXorcist/DeviceAgent substrate) | ✅ AX substrate | med |
| 15 | **Per-model capability profile** | correct ctx-window / chat-template / tool-call dialect per model (fixes real crashes) | **Plan 1** (local-inference correctness) | — | med |
| 16 | **llama.cpp chat-template hardening** | per-model `--chat-template`/`--jinja` + chatml fallback + preflight validation | **Plan 1** (GGUF lane) | partial (exit-class landed) | med |
| 17 | **Recurring "nuclear" code-checker gate** | adversarial whole-codebase review at multiple build checkpoints | **Plan 7 (NEW)** / process | partly (thermo skill exists) | med |
| 18 | **Stealth / undetected browsing** | anti-fingerprint option on browser-use (Camoufox/nodriver); Pro/dev-gated | **Plan 3** (Browser §10 "re-confirm") | — | med |
| 19 | **Provider-specific cloud agent** | first-class OpenAI/Google/Claude vendor-native agent mode (gated, SENSITIVE) | **Plan 1** (kept 🟢, orphaned by Act cut) | — | low |
| 20 | **Concept graph / alias canonicalization** | folders→implicit ontology; synonyms→canonical via embedding+medoid | **Plan 6 (NEW)** / Plan 2 wikilinks | ✅ Rust `canon/` landed | low |
| 21 | **MCP connectors that actually connect** | wire ≥1 real Slack/Gmail/Drive/Notion connector (today honest-state stub only) | **Plan 3** (§5) | directory shipped | low |
| 22 | **Self-refreshing live artifacts** | HTMLWorkspace artifact bound to a live vault/RRF feed → patched WKWebView | **Plan 2** (HTML Workspace) | reuse PatchRouter | low |
| 23 | **~/Downloads logo-ingest path** | drop-folder convention → user SVGs staged into Assets.xcassets (fills lobe gaps) | **Plan 4** (icons) | — | low |
| 24 | **AppIntents / Shortcuts / Spotlight for PDFs** | "Open/OCR/Preview file" Siri actions + Spotlight-index imported PDFs | **Plan 3** (§6, flagged not-yet-owned) | — | low |
| 25 | **Hyperdynamic determinism (local>cloud)** | deepen grammar-constrained/schema decoding + HyperdynamicLoop so local+skills beats cloud | **Plan 1** / thesis track | ✅ primitives exist | low |

## ROUTING SUMMARY
- **Fold into LIVE plans (owner-confirm before redirecting the running agents):**
  - Plan 1 (Goose): cockpit panel · provider-specific cloud agent · per-model profile · llama template hardening · hyperdynamic determinism
  - Plan 2 (Editor): self-refreshing live artifacts · (concept canonicalization, if not Plan 6)
  - Plan 3 (Capabilities): PII redaction · vault-as-AI-memory · skill auto-mint · richer voice · context launcher · stealth browsing · MCP connectors-that-connect · AppIntents/Spotlight
  - Plan 4 (Icons): ~/Downloads logo-ingest
- **Two coherent NEW clusters (need an owner call — fold vs new plan):**
  - **PLAN 6 — Quick Capture surfacing** (items 1,2,3,4,10,20): the Rust substrate is BUILT; this is the missing Swift UX. Highest leverage in the list — the hard part is done. *Strong candidate for its own plan.*
  - **PLAN 7 — Stability, Privacy & Sync** (items 5,6,13,17): the dark/light crash + crash recorder + iCloud sync + recurring nuclear gate. *Could be its own plan OR the crash/recorder folded into a hardening pass + sync deferred (high blast radius).*

## DISPOSITIONS (owner-decided 2026-06-29)
- ✅ **Plan 6 — Quick Capture surfacing** DRAFTED + SAVED → `docs/prompts/PROMPT_PLAN_6_QUICKCAPTURE.md` (items 1,2,3,4,10,20). Substrate verified present: agent_core/src/{route,effect,undo,canon,nightbrain,heal,format,grammar}.
- ✅ **Plan 7 — Sync + Quality Gate** DRAFTED + SAVED → `docs/prompts/PROMPT_PLAN_7_SYNC.md` (items 13,17 = iCloud sync + recurring nuclear gate).
- ✅ **Crashes FIX-NOW** (items 5,6: dark/light crash + crash recorder) ROUTED to the LIVE Plan 2 agent as PRIORITY-0 §0 (it owns the editor WebViews where the crash lives) — `docs/prompts/PROMPT_PLAN_2_EDITOR.md`.
- ⏳ **Plan-1/2/3/4 fold-ins** (PII redaction, vault-as-AI-memory, richer voice, context-launcher, stealth, MCP connectors, cockpit, per-model profile, llama template, logo-ingest) — still owner-confirm before redirecting the live agents; held in this ledger.

## ONLINE VALIDATION (primary sources, 2026-06-29 — all CONFIRMED real + viable)
- **PII redaction = OpenAI "Privacy Filter"** — released 2026-04-22, **Apache-2.0**, 1.5B params / 50M active, 128k ctx, **runs on-device** (data never leaves the machine), 96% F1 on PII-Masking-300k, 8 categories. HuggingFace + GitHub. → clean license + MAS-safe + fits the M2-Pro-16GB budget. STRONG GO for the Plan 3 privacy fold-in.
- **Stealth browsing = Camoufox + nodriver** — Camoufox = Firefox fork w/ C++-level stealth, 0% headless detection, **Playwright-compatible API** (slots into browser-use's Playwright lane); nodriver = CDP-driven Chrome (no behavioral faking). Pro/Dev-ID only (Chromium/Firefox automation ≠ MAS). → Plan 3 Browser Pro lane.
- **iCloud vault sync** — Apple-sanctioned + sandbox-safe via the ubiquity container + iCloud entitlement; ALL IO through NSFileCoordinator + a registered NSFilePresenter; temp-write+hard-link-swap; explicit NSFileVersion conflict resolution (no silent last-writer-wins). → baked into Plan 7's hard gates.
- **Bitcrush DSP** — trivially real: an AVAudioUnit/AVAudioEngine effect over any TTS voice; MAS-safe. → Plan 3 voice fold-in.

## WAVE 2 — OWNER-LEDGER DEEP-MINE (2026-06-29; re-run after the first mine was lost mid-run)
> The dedicated mine of `OWNER_REQUESTS_LEDGER_2026_06_18.md` (4498L) failed the first time (process exit). Re-run
> completed: the ledger is OVERWHELMINGLY historical (Osaurus/Tolaria era — most lines are CUT items or already in
> Plans 1-7 / Wave-1). After excluding all of that, **18 genuinely-new, worth-keeping residue items** remain, routed:
| # | Feature | What | Ledger ln | Route | Conf |
|---|---|---|---|---|---|
| 26 | **Frontmatter / Properties side-panel + tags index** | Obsidian/Logseq frontmatter+properties panel, tag index, backlinks on the md editor | L3782, L3842 | Plan 2 | high |
| 27 | **Theme-switch HANG + granular custom colors** | dark↔light toggle *hangs* / colors don't update / needs ~3 toggles + add granular text/accent/surface color slots (distinct from the Wave-1 *crash*) | L4044-48, L4027-31, L4389-98 | **NEW (Theming)** | high |
| 28 | **Homepage→graph blur-replace transition** | replace the squish/fold/flicker home↔graph transition w/ native Apple blur-replace ("really important hardening" — owner) | L3911-13, L3937 | Plan 4 (anim) | high |
| 29 | **App-wide blur-replace animation polish** | sweep 7 LandingView overlays / RootView / sidebar / companion for glitchy transitions → blur-replace house style | L3937-38, L3949-55 | Plan 4 (anim) | med |
| 30 | **Bases-style table/DB views over frontmatter** | Notion/Obsidian-Bases DB views computed over note frontmatter (the "take over Notion" bar) | L4154 | Plan 2 / NEW | med |
| 31 | **Block-refs + transclusion + backlinks** | Logseq/Roam block-level refs + transclusion + backlink panel (beyond wikilink resolve) | L4155, L3782 | Plan 2 | med |
| 32 | **Vault export / backup** | NO export/backup exists today — data-safety gap | L4055-61 (SS-BWB) | **Plan 7** | med |
| 33 | **Raw-thoughts vault visibility** | `RawThoughtsState` captures but never surfaces in the vault — wire-or-honestly-retire | L4360-61 | Plan 6 | med |
| 34 | **Dead graph-appearance toggles** | graph appearance settings set flags `MetalGraphView` never reads — wire or remove (honesty debt) | L4362-63 | **NEW (graph chrome)** | med |
| 35 | **Code-editor white-bar + page-relevant pill** | graph code-editor non-theme white top bar; landing pill persists onto graph (swap to page controls) | L3998-4019 | **NEW (graph chrome)** / Plan 2 | med |
| 36 | **Quick-capture destination presets** | capture hardcoded to a Prose SDPage; add note/Epdoc/chat/code destination presets | L4049-51, L4174 | Plan 6 | med |
| 37 | **Cold-box inline-AI separation + scroll affordance** | inline "Ask this note" + send anim + scroll-down arrow + visually-distinct "cold box" (AI≠user text) | L4177-86 | Plan 2 / Plan 5 | med |
| 38 | **Code-editor icon dropdown-arrow cleanup** | icon-only Menus show a deformed chevron — `.menuIndicator(.hidden)` across 8 files (trivial) | L4091-4100 | Plan 2 | med |
| 39 | **Model-vault staleness + per-model user-file injection** | per-model Knowledge-Fusion vaults stale (bootstrap-only); local models never read the vault; user files ignored | L4101-14 | **NEW (per-model knowledge)** | med |
| 40 | **Wikilink-driven auto-research** | unresolved `[[link]]` → auto-research task feeding the vault (Karpathy LLM-wiki pattern) | L4115-35 | Plan 2 / Plan 6 / NEW | med |
| 41 | **SS-BWB stability backlog** | notify-on-complete · unified `.searchable` surface · standardized error/empty/loading + chat retry · a11y/Dynamic-Type | L4055-61 | Plan 7 / NEW | med |
| 42 | **UMA zero-copy local-recall (accuracy-first)** | local model recall taps the in-process tantivy/usearch/RRF shadow-index (zero-copy) — "make local models better" thesis | L3757-73, L3806-14 | **NEW (local-inference)** | low |
| 43 | **MLX-LoRA-Studio + adapter-testing UX** | native LoRA training dashboard + select-adapter→apply-to-model→TEST (training/adapters — NOT the cut model-mgmt) | L3863-3920 | **NEW (training/adapters)** ⚠️ | low |

### WAVE 2 routing + NEW-home clusters (owner decision)
- **Fold into existing (owner-confirm — Plan 2 is LIVE):** Plan 2 ← 26,30,31,37,38,40 (frontmatter/Bases/block-refs/cold-box/dropdown/wikilink-research) · Plan 4 ← 28,29 (blur-replace transitions) · Plan 6 ← 33,36 (raw-thoughts, capture presets) · Plan 7 ← 32,41 (vault export/backup, SS-BWB backlog).
- **NEW homes proposed:**
  - **Plan 8 — Theming & Appearance** (27 theme-switch hang + granular colors · 34 dead graph toggles · 35 graph white-bar/pill) — a coherent appearance-honesty cluster; theme-hang is HIGH-confidence + grounded.
  - **Plan 9 — Local-model knowledge & adapters** ⚠️ SENSITIVE (39 model-vault staleness · 42 UMA zero-copy recall · 43 LoRA-Studio/adapters) — the "make local models better" thesis. The agent flags these as DISTINCT from the cut model-management (per-model context + training, not HF-browser/BYOM) — but it is adjacent, so **owner must confirm this isn't reviving cut scope** before it gets a plan.
- **Highest-confidence picks:** #26 frontmatter panel · #28 homepage blur-replace · #27 theme-switch hang.

> **Auditor note:** this ledger is now canonical. When the owner picks restorations, route each item into its plan
> doc + (if Plan 6/7 are created) draft their prompts to the same strictness as Plans 1-5. Until then, every item is
> captured here — nothing is lost.
