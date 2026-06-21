# Osaurus addendum (2026-06-21) — "Epistemos Picks" model section + harden-after

**Owner (verbatim, 2026-06-21):** *"we can just add my models to the osaurus stack as a section that
says epistemos picks or whatever a clever name so i don't lose my custom hardened models and such. i
would just need to start hardening all the things that exist after the osaurus clone."*

## DESIGN DECISION — "Epistemos Picks" curated section in the Osaurus/act model stack
- When Osaurus is cloned in, its model stack/picker gets a dedicated section (working name **"Epistemos
  Picks"** — owner open to a cleverer name) that surfaces the owner's CUSTOM HARDENED models (the QAT
  GGUF ladder, MLX picks, etc.) sourced from the EXISTING standalone catalog
  `Epistemos/Engine/LocalModelInfrastructure.swift` / LocalModelCatalog / GemmaQATRuntimeLadder.
- This is how the owner's models are PRESERVED + PORTED (per the quarantine guard): not lost, not
  re-imported — the same catalog, surfaced as a curated, top-billed section inside the Osaurus act UI.
- Osaurus already drives "the same on-device models the app routes to" (`LocalModelServer.swift`), so
  this is a UI/section + wiring task over an existing model layer, not a model re-build.
- Honest selection in this section: NO silent Qwen substitute; too-large = honest message (the old chat
  fallback requirement lands HERE, in the new act stack — not as a patch to the quarantined chat).

## SEQUENCING (reaffirmed): Osaurus full clone FIRST → wire "Epistemos Picks" + port IP → THEN harden
ALL existing things on the cloned surface. Hardening the everything-that-exists happens AFTER the clone,
per owner. Cross-ref CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md (never delete the quarantined
chat) + OSAURUS_P3_IMPORT_PLAN_2026_06_19.md (full-clone strategy + 2026-06-21 directive).

## 🆕 SURFACE-WIRING RULE (owner 2026-06-21, verbatim)
*"every osaurus surface is linked to a real front-end part of my app because i don't want things to not
work since they are already proven to work."* EVERY Osaurus surface (settings, model stack, server,
tools, transcript, etc.) MUST be wired to an EXISTING, already-PROVEN app front-end — no dead or
disconnected surfaces. For each surface: map Osaurus-surface → the real app view it drives BEFORE wiring,
then prove it works (real-state test / launch-smoke). Reuse the proven chat front-end as act's UI.

## 🆕 ALL CHAT SURFACES GET THE CHAT→ACT/OSAURUS UPGRADE (owner 2026-06-21)
**Owner (verbatim):** *"the minichat, graph chat, note chat and other chats — any other chat should also
have the upgraded osaurus powers. the note chat etc, rn it has the tools icon and the model picker so
just so its good i want to make sure that all chats have the full chat→act transition."*

EVERY chat surface in the app gets the SAME act/Osaurus capabilities (tools, model picker incl.
"Epistemos Picks", honest no-fallback selection, streaming/thinking fidelity) — not just the main chat.
Known surfaces (enumerate + verify none missed):
- **Main chat** — `Epistemos/Views/Chat/ChatView.swift` (+ ChatInputBar, ChatBrainPickerMenu, ChatSidebarView).
- **MiniChat** — `Epistemos/Views/MiniChat/MiniChatView.swift` (+ MiniChatWindowController).
- **Note chat** — `Epistemos/Views/Notes/NoteChatSidebar.swift` (+ NoteDetailWorkspaceView) — already has
  the tools icon + model picker; bring it to full act parity.
- **Graph chat** — `Epistemos/Views/Graph/Hologram*` (HologramController/Overlay/SearchSidebar) + MetalGraphView.
- Plus any other chat entry point found in a sweep — none left behind.

IMPLEMENTATION INTENT: factor the act/Osaurus composer + capability set into a SHARED component reused by
every surface (one source of truth → no per-surface drift), each wired to its real proven front-end per
the surface-wiring rule. The chat→act transition applies uniformly; no chat surface stays on the old path.

## 🆕 CONFLICT-RESOLUTION: FAVOR OSAURUS (owner 2026-06-21, verbatim)
**Owner (verbatim):** *"if my IP clashes or anything my app clash favor the osaurus please
and simply cherry pick my IP or parts of my app that work with the osaurus but of course
still make sure the front end is the minimal epistemos style."*

BINDING RULE for all wiring/porting (S3+): on ANY clash between the owner's IP / existing
app and Osaurus, **Osaurus wins** — adopt Osaurus's engine/structure. From the owner's side,
**cherry-pick only the IP / app parts that work WITH Osaurus** and port them onto the Osaurus
engine (don't force-fit incompatible app logic). The **front-end stays minimal Epistemos
pixel-art native style** — reskin Osaurus views to app chrome; build new pixel-art front-ends
only for surfaces the app lacks. This refines (does not weaken) the never-delete-chat guard:
the quarantined chat's compatible IP is ported; retire only after the 4-part bar + owner OK.
NOTE: this "cherry-pick the owner's compatible IP" is the COMPLEMENT of "zero cherry-pick of
Osaurus" — Osaurus is vendored whole; the owner's side is what gets selectively integrated.

## 🆕 FULL CLONE LANDED (2026-06-21)
The entire `osaurus-ai/osaurus` repo is vendored at `LocalPackages/osaurus/` (pinned
`ae3a3c5d…`, MIT `direct_import`, `.git` stripped = take-control). Source-on-disk only —
NOT yet linked into the Xcode build. Next slice = S3 (xcodegen-link OsaurusCore, Pro-gated).
See `LocalPackages/osaurus/VENDOR.md` + `scripts/update-osaurus.sh` (one-command re-vendor).

## 🆕 COMPLETENESS / DISCOVERY-SWEEP MANDATE (owner 2026-06-21)
**Owner (verbatim):** *"i want to make sure that even things i'm not mentioning are taken into account
because there may be other surfaces affected — make sure the plan reasons about this as well."*

The enumerated lists in this plan (chat surfaces, Osaurus surfaces, IP pieces) are STARTING POINTS, NOT
exhaustive. Before + during the act/Osaurus build, run a SYSTEMATIC DISCOVERY SWEEP and reason about
second-order effects — do not rely only on named items:
- **Find every consumer** of the chat backend / inference resolution / model picker / tools / capability
  pills / streaming, by code search (e.g. grep `InferenceState`, `EpistemosRuntimePicker`,
  `setPreferredChatModelSelection`, runtime/brain pickers, tool icons, capability pills, any view that
  sends a prompt). Each is a candidate surface for the chat→act upgrade or the quarantine/porting cycles.
- **Any surface that touches the old chat path** must be explicitly accounted for: upgraded to act, or
  quarantined+ported, or deliberately marked out-of-scope with a reason — never silently missed.
- **Reason about ripple effects:** settings, onboarding/landing, command palette, sidebars, widgets,
  notifications, deep links, tests/fixtures, and anything depending on removed/changed chat behavior.
- **Standing rule:** treat completeness as a first-class acceptance gate — a "completeness critic" pass
  each cycle asks "what surface/consumer did we miss?" and adds findings to the ledger. Nothing the owner
  didn't name should fall through the cracks.

## 🆕 AGENT-STACK CONVERGENCE — ALL CLONED LOGIC MUST DEEPLY SERVE THE APP (owner 2026-06-21)
**Owner:** keep researching OpenClaw / Hermes-agent / Goose / OpenCode + how to CONVERGE them in the app;
all logic we clone/pull (agent loop + engine code + each app's specific benefits) must DEEPLY serve the
app — no dead clones, no clashes. Osaurus already ~landed; deeply clone Goose + OpenCode; OpenClaw = pull
only the hardening patterns Osaurus/Goose don't already give (rewrite in Swift), not a full clone.
ROLES (confirm/correct in research): act = Osaurus; work = Goose/OpenCode; OpenClaw = selective runtime
hardening; Hermes = existing in-process runtime. STANDING: maintain ONE agent-loop/runtime of record;
dedup capabilities (don't clone the same thing twice); favor Osaurus on clashes; fix the dual-MLX clash
(vmlx-swift vs mlx-swift-lm). Living research: docs/research/AGENT_STACK_CONVERGENCE_RESEARCH_2026_06_21.md
(a background agent is generating it). Recurring deep-research is part of the cycle — keep it current.

## 🆕 OPENCODE = FULL CLONE WORK SHELL (owner 2026-06-21) — CORRECTS the convergence research
**Owner:** loves OpenCode's UI/UX (was going to theme it to match the app — "perfect"); wants to FULLY
clone it because it's MORE CAPABLE than Osaurus/Goose; **OpenCode is the work APP that Goose runs INSIDE
of**; willing to be LENIENT on Swift/Rust-only to get it. Owner confirmed YES to the other 6 convergence
decisions; OpenCode is the exception to "pattern-source only."

CORRECTION to AGENT_STACK_CONVERGENCE_RESEARCH_2026_06_21.md: OpenCode is NOT pattern-source-only. It is
the **work-mode SHELL of record**, full-cloned + themed to the app's pixel-art native look, with **Goose
as an engine inside it** + the owner's IP brain wired in. The "can't vendor TS into agent_core (Rust)"
fact stands, BUT since MAS is no longer a hard constraint (notarized direct-distribution), OpenCode ships
as a bundled in-app runtime (Bun/Node), not a Cargo crate. Lenient on Swift/Rust purity for this.
OPEN RISK to validate EARLY: can OpenCode's TS UI be themed to feel TRULY pixel-art native, or must its
best UX be rebuilt natively? Decide after the feasibility deep-dive (docs/research/OPENCODE_FULL_CLONE_
FEASIBILITY_2026_06_21.md). Other 6 convergence decisions = YES (favor-Osaurus, dedup, IP-on-top,
existing-LSP-into-work, vmlx migration, OpenClaw skip-list).

## 🆕 CRYSTALLIZED TWO-MODE ARCHITECTURE (owner 2026-06-21) — AUTHORITATIVE
**Owner:** *"openclaw, hermes and goose would FUSE INTO the OpenCode work. while Osaurus and all of its
parts would be ACT. add the RustLSP to whatever it needs to go to (or decide if it's even needed)."*
MAS is NOT a constraint — goal is a ROBUST, highly-capable app; do not cut features for sandbox strictness.

### The two modes
- **ACT = Osaurus (full, all its parts).** Vendored clone → OsaurusCore + server + tools + VM sandbox +
  MCP + plugins + privacy filter. Reskinned pixel-art native. (Already ~landed; finish dual-MLX → link.)
- **WORK = OpenCode (full-clone shell, themed native) into which GOOSE + HERMES + OpenClaw FUSE.**
  - OpenCode = the work SHELL + UI/UX (themed to app).
  - Goose = the work ENGINE inside OpenCode.
  - Hermes (legacy in-process runtime) = the owner IP brain + its 4 unique lifts, fused into work.
  - OpenClaw = selective hardening patterns (checkpoint/resume, depth limiter, zero-config) fused in —
    skip what Osaurus/Goose already cover.
  → One fused work stack, not 4 parallel ones. Dedup capabilities; single runtime of record per mode.

### RustLSP + similar existing logic — what to do
- **RustLSP** = your EXISTING in-process Rust LSP (`agent_core::lsp_runtime`, tree-sitter Rust/Swift;
  Swift bridge `Epistemos/Engine/RustLSPTransport.swift`). DO NOT import OpenCode's LSP. WIRE the existing
  RustLSP into the WORK stack as agent code-intelligence TOOLS (hover/definition/diagnostics/edit), so the
  work agent gets real code understanding. It's already built — reuse, don't rebuild or double up.
- **Similar existing logic = your substrate/IP that rides on top of BOTH modes (reuse, never rebuild):**
  Eidos/recall, cognitive DAG, provenance ledger, Halo/Shadow search, RRF fusion, AnswerPacket, System G,
  RuntimeRouter. These are the brain/substrate beneath act+work; engines (Osaurus/OpenCode) are swappable
  executors under them. Inventory each existing capability → wire to whichever mode benefits; clone only
  what you don't already have.

### Directive to the build agent/loop
Update the QUEUE/plan walk to this two-mode target and WORK IT: (1) finish Osaurus act (dual-MLX → link →
Act turn → shared composer across all chats), (2) build the WORK shell = OpenCode full-clone + fuse
Goose+Hermes+OpenClaw + wire RustLSP, (3) reuse-not-rebuild the existing substrate/IP into both, (4)
substrate-health + IP-porting cycles later-but-certain, never delete quarantined chat. Pending feasibility:
docs/research/OPENCODE_FULL_CLONE_FEASIBILITY_2026_06_21.md + AGENT_STACK_CONVERGENCE_RESEARCH_2026_06_21.md.

## 🔒 SET IN STONE — MAS NON-RESTRICTIVE + SWIFT/RUST LENIENCY (GLOBAL, owner 2026-06-21)
**Owner:** MAS is NOT a restrictive constraint — the goal is a ROBUST, highly-capable app with a LOT in
it. Do NOT cut features, "lose the cloned app's essence," or hallucinate a "MAS sandbox" excuse to
corner-cut. Not strict about keeping everything Swift/Rust. **This applies to EVERY repo/fusion — agent
AND non-agent** (e.g. **Talaria + the Epdoc fuse**, and all other clones/integrations), not just
Osaurus/OpenCode. App ships **notarized direct-distribution (non-sandboxed)** so it can carry full
capability (incl. things MAS would block, e.g. the VM sandbox). **SUPERSEDES** the MAS/Pro-gating "NON-
NEGOTIABLE CONSTRAINTS" in CLAUDE.md for product scope — treat that section as historical; this directive
wins. (Still honest: REAL APIs only, no hidden fallbacks, no fake capability — leniency is about
MAS/sandbox/language purity, NOT about honesty.)

## 🆕 OPENCODE MUST BE FULLY THEME-RESPONSIVE (owner 2026-06-21)
OpenCode (work) must match EVERY app theme AND respond LIVE to theme changes — including the user's CUSTOM
themes. Whatever integration form Work takes, theme-responsiveness (incl. custom-theme live updates) is a
HARD requirement, wired to the app's theme system. NOTE: this strengthens the case for a NATIVE shell
(naturally theme-responsive via the app's theme tokens); a bundled web/Electron UI would require explicit
theme-bridging to honor custom themes live. Decide the work-UI form per OPENCODE_FULL_CLONE_FEASIBILITY_
2026_06_21.md (open fork: native shell over OpenCode engine vs embed OpenCode's own UI).

## ✅ RESOLVED — OPENCODE UI DECISION + WORK/ACT UX (owner 2026-06-21, AUTHORITATIVE)
RESOLVES the open fork in OPENCODE_FULL_CLONE_FEASIBILITY: owner wants **Option A — keep OpenCode's REAL
UI**, NOT a native rebuild. The earlier "can't feel pixel-art native" concern is MOOT: the owner LIKES the
**minimal terminal look** — that IS the desired aesthetic. Only requirement: **match the app's color +
palette** (palette-aware text), live incl. custom themes (OpenCode TUI is truecolor-themeable). Embedding
OpenCode's real UI requires its bundled runtime — FINE now (MAS non-restrictive, set in stone).

### Naming
- **ACT** = Osaurus, reskinned pixel-art native, named **"act"** (or "Epistemos chat" — owner's choice).
- **WORK** = OpenCode, real terminal UI kept + palette-matched, renamed **"work"** (never shows "OpenCode").

### Where WORK (OpenCode UI) goes
Add the real OpenCode UI to **main chat, minichat, graph chat, and all places it can go — EXCLUDING the
NOTE chat.** (Note chat does NOT get work/OpenCode.) Chat surfaces thus offer act AND work (except note = act only).

### Transition model
Open search + type → it transitions (instead of to chat/act) to **work** (the OpenCode UI), color/palette-
matched, text palette-aware, labeled "work."

### Landing pages + toggles (keep BOTH)
- "Press anywhere to start a convo" → auto-transition to the **Osaurus landing page, Epistemos-reskinned**.
- A **toggle on that page instantly switches to the OpenCode landing page**. BOTH landing pages are kept
  (Osaurus reskinned; OpenCode real, palette-matched, named "work").
- Two toggles overall = act / work.

### Implication for the build
Work = embed OpenCode's actual UI (terminal/TUI look) palette-bridged to the app theme system (live, incl.
custom themes), with Goose+Hermes+OpenClaw fused into the OpenCode engine beneath it + RustLSP wired in.
This supersedes the feasibility doc's native-rebuild recommendation — owner chose keep-the-real-UI.

### Landing-page BLUR transitions (owner 2026-06-21)
- Initial landing → **press anywhere → BLUR animates → Osaurus (act) landing page** (Epistemos reskin).
- On that page, **selecting the toggle → BLUR animates → OpenCode (work) landing page.**
- The two landing pages are kept visually **separated enough** (distinct), with the blur animation as the
  transition between them. Blur is the signature transition for landing → act, and act-landing ↔ work-landing.

## 🆕 EPDOC MD-V2 (reaffirmed, owner 2026-06-21) — stays on plan
EPDOC_MD_V2: **Markdown is the REAL, robust source of truth**; HTML / JSON / any other formats are
DYNAMIC PROJECTIONS of the md (the md carries the good code/structure). The HTML workspace on Epdoc must
actually mirror the md (hardened/repaired/robust). Keep the UI **pixel-art native** as it is now, just more
dynamic. This is a real plan item (not dropped) — owner-facing, do it. Cross-ref the existing EPDOC md-first
plan + SS-EDGE bar.

## 🆕 SUBSTRATE + IP ARE CERTAIN — "LOWER IN ORDER", NOT "DEFERRED" (owner 2026-06-21)
Owner: my substrate + IP MUST get done. Code AS MUCH AS POSSIBLE now; only the EXCESS goes **lower in the
walk order so it isn't done too early** — but it stays fully ON THE PLAN and **is NOT labeled "deferred."**
"Deferred" reads as droppable/forgotten (same failure mode as WIP/stash) — DO NOT use it for these. Treat
every "deferred but certain" mention in these docs as **"sequenced lower, CERTAIN, not droppable."** The
substrate-health + IP-repair cocktail + EPDOC MD-V2 + porting cycles are all CERTAIN deliverables, just
positioned later in the order — never quietly dropped, never marked optional. Build maximally; push only the
true excess down the list, still guaranteed.

## 🆕 ACT RESKIN = RESPECT THE CURRENT CHAT UI (owner 2026-06-21) — visual north star
Owner LOVES the current chat UI. When reskinning Osaurus into ACT: **take the DISCIPLINE + style of the
current chat UI and apply it carefully to Osaurus** — add ALL of Osaurus's capability, but render it in the
current chat's look so it feels **really Epistemos-like**. UI + themes (incl. custom) must drive Osaurus too.
REFERENCE SCREENSHOTS (the target aesthetic — look at these before reskinning):
`docs/research/ui-reference/current-chat-ui-act-northstar-1.png` + `-2.png`.
Design language to preserve (see shots for exact look): warm cream/beige palette; clean minimal; **monospace
pixel-art-style section headers** (TOOLS THIS TURN, ATTACHMENT CONTRACT, WORKSPACE AWARENESS, EXECUTION PLAN,
EVIDENCE INTAKE); right-side **provenance/context inspector** (Summary / Runtime / Model / Mode / Captured /
Request); vault-retrieval chips (real path · vault-chat-context-v1 · lexical); composer "Ask anything… @ for
notes or chats" with Fast / Local / token chips; rounded window, soft shadow, palette-aware text.
NOTE: the screenshots also show the LIVE Qwen fallback ("You picked Gemma 4 E2B QAT GGUF, but it's too large
… running Qwen 3 4B instead") — confirms the P0; in act, use the owner's pick honestly, no silent substitute.

### ACT reskin — typography + component design tokens (owner 2026-06-21)
Apply ALL of the current chat's design discipline to Osaurus/act (owner hasn't seen Osaurus's UI yet — the
CURRENT CHAT design wins, Osaurus capability is added underneath it):
- **User message bubble = MONOSPACE font**, in the rounded coral/salmon bubble (as in current chat).
- **Assistant/answer text = Anthropic Sans** (or the best-fit clean sans) — readable answer font.
- **Message bar / composer = flat but still DISTINCT** design (subtle but defined, as current).
- Plus everything already specced: warm cream palette, monospace pixel-art section headers, provenance
  inspector, vault chips, rounded window + soft shadow, palette-aware text, live theme (incl. custom).
- "All of it" — match the current chat's look/feel end-to-end; carefully port that discipline onto Osaurus.
NOTE on reference screenshots: owner's 2 current-chat screenshots (2026-06-21 3.49 PM) were iCloud-offloaded
so NOT copied into the repo. To add: open them once on Desktop (downloads), then cp into
docs/research/ui-reference/. Until then, this written spec + the LIVE app's current chat are the reference.

### ACT reskin — PRESERVE the model picker + command palette + agent-tools UI (owner 2026-06-21)
Owner loves these; keep + preserve ALL of it through the reskin (this is where "Epistemos Picks" lives):
- **MODEL PICKER** with REAL model LOGOS per model; tiers **FAST / THINK**; rows show name + subtitle
  ("Fastest on-device · everyday chat"), **install state** ("Not installed — tap to install"), **memory
  needs** ("Needs ~16 GB (5 GB free)"), **context badge** (128K / 32K), **checkmark on selected**,
  download affordance; header "Install local AI — Download Epistemos AI — Gemma · VibeThinker · coder";
  "N models · scroll for all"; Apple Intelligence row ("Not available on this Mac"). → the owner's custom
  hardened models surface here as the "Epistemos Picks" section; honest selection, no silent Qwen swap.
- **COMMAND PALETTE / LAUNCHER:** **Fast / Tools / Agent** tabs; "Ask anything… Type @ for notes or chats ·
  Auto-routes…" search + esc + send arrow; top toggles gear / Aa (typography) / sidebar; bottom command
  GRID: search, quick capture, workspaces, save workspace, time machine, notes, new note, mini chat, new
  doc, new code, html workspace, home graph.
- **AGENT TOOLS PANEL:** "Agent tools — N of N on — All on / All off"; sectioned (RUST, …); per-tool
  toggles with **"asks first"** badges on sensitive tools (e.g. Chunk reduce, Communication channel/imessage
  contacts, Discovery mcp/model-catalog, Eidos query); footer "Local models chat + reason; multi-step tool
  runs use a cloud model or the Pro harness. Turning a tool off removes it from this chat's agent turns."
Preserve this chrome end-to-end in act; add Osaurus capability beneath it. (Reference screenshots were
ephemeral/iCloud + couldn't be saved to repo — this spec + the LIVE app are the reference.)
