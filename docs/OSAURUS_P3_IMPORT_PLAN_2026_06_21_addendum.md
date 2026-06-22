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
then prove it works (real-state test / launch-smoke). [VOID drift-addition — ACT = the OSAURUS UI clone reskinned to the Epistemos look, NOT the old ChatView. See "ACT = OSAURUS IS THE CHAT".]

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

## 🆕 OSAURUS AGENT CREATION = KEEP TAMAGOTCHI STYLE + FIX RENDER BUG (owner 2026-06-21)
Owner: the Osaurus **agent-creation** flow must keep my **Tamagotchi-style** characters/avatars (maybe in a
"meta" section). This is owner IP/style to PRESERVE — port it onto the Osaurus agent creation (NOT an
off-limits Companion-backend clone; this is the owner directing their avatar STYLE be kept + fixed).
- **CURRENT BUG (fix):** the Tamagotchi sprites render **too small** and have **weird small blocks/squares
  inside their bodies** when drawn/rendered.
- **WANT:** **larger + dynamic**, still **flat pixel-art Tamagotchi** aesthetic, with **NO artifact squares
  inside the bodies** — clean flat fills. Find the sprite/avatar renderer, fix the intra-body artifacts +
  the sizing, keep the flat Tamagotchi look.
This is part of the act surface (agent creation). Preserve the style, fix the render.

## 🆕 PER-CLONE SETTINGS — RESPECT EACH CLONE'S OWN SETTINGS (owner 2026-06-21)
Each clone is its OWN app with its OWN settings — the owner wants those settings IN the app, respected (not
dropped/flattened). This applies to Osaurus and BEYOND (every clone).
- **Structure (owner-preferred = TABS / an executive toggle in Settings):** keep the current all-Epistemos
  settings as one tab, then add sibling tabs per clone — **"act"** (Osaurus's full settings), **"work"**
  (OpenCode's full settings), and **beyond** (a tab per future clone). (Owner leaned tab over a separate
  window or a buried sub-section — but the principle is what matters: per-clone settings preserved + reachable.)
- **Respect each clone's REAL settings surface** — port the clone's actual settings (Osaurus's settings,
  OpenCode's settings, etc.), reskinned to the app's pixel-art native look + theme-aware (per the reskin
  discipline), not a stripped-down reimplementation. Each clone's options must be honored.
- Ties to "preserve everything from each clone" + the surface-wiring rule (each settings surface wired to a
  real, working front-end). Standing rule for all current + future clones: bring in + respect their settings.

## 🆕 MODE-ENTRY TRANSITION ANIMATIONS — act vs work (owner 2026-06-21)
Selecting a mode is a MOVEMENT-based transition, not a hard cut. Shared concept: the greeting **backspaces /
moves up**, then **typewriter-writes the mode name**; UI elements **blur + reveal**; **reusable elements
persist by translating** (e.g. greeting → title moves up and stays, not redrawn). Feels CONNECTED, dynamic,
fun, interesting — but native. (Pairs with the landing-page BLUR transitions already specced.)

### ACT (Osaurus — NATIVE blur-reveal)
- On select: greeting **moves up → becomes the title**; smaller UI elements **blur**; the message bar
  **blurs in and appears**; all elements **blur-and-reveal**; reusable parts just **move up from greeting to
  title** and persist. Typewriter-writes the mode name (**"act"** / "Epistemos chat").
- Native feel via the blur reveal — connected, dynamic. (= the previously-described Osaurus animation.)

### WORK (OpenCode — non-native, MORE FLEXIBLE = more playful)
- Typewriter the mode name **"work"** in a more **ASCII / pixel-art typewriter** style; since OpenCode isn't
  native, it's OK to **use OpenCode's OWN font** for this.
- The elements themselves get a **more dynamic / interesting reveal** — animate the **entire UI page**
  element-by-element into view (terminal/ASCII-flavored), more playful than act's native blur.
- Same underlying movement idea (greeting backspaces → up → typewriter name → reveal), just a more
  expressive ASCII/pixel-art animation for work vs act's native blur.

Net: act = native blur-reveal (connected, dynamic, native); work = ASCII/pixel-art typewriter + dynamic
full-page element reveal (playful, terminal-flavored, OpenCode font allowed). Both feel intentional + connected.

## 🆕 APP-WIDE ANIMATION INITIATIVE — "ASCII typewriter / time-machine" motion ontology (owner 2026-06-21)
Part of the "fun up the app" initiative: MORE animations, COUPLED with the Apple blur the owner loves (blur +
this = a layered "meta animation"). The signature motion = the **"time machine" title animation**: the
typewrite + **ASCII reveal** (the little boxes / ascii art animating in as it types). Make it a **reusable
motion ontology** applied across the app — not a one-off.
- **WHERE (apply broadly, tastefully):** TITLES first (the confirmed anchor — like the time-machine box
  title + the "before"-mentioned mode-entry typewriter), plus **settings, agent surfaces**, and other
  **non-text-editing** reveals. Scale it to **many fonts incl. smaller body fonts** — but **adapt the font
  per context** (NOT the time-machine title font everywhere; the same motion ontology, context-appropriate font).
- **WHERE NOT / BALANCE:** **do NOT bloat it**; **never in text-EDITING areas**. The message bar is
  borderline — owner leaned away from the message bar, toward **titles** (primary) and **maybe agent ANSWER
  reveals**. FIND A BALANCE: tasteful + intentional, signature-not-spammy. Titles = yes; editing = no;
  answers/sections = judgment call, kept light.
- **COUPLING:** pairs with Apple blur (act = native blur-reveal); the ASCII-typewriter ontology is the more
  expressive layer, strongest in WORK/OpenCode (ascii/pixel-art) but available app-wide as the motion accent.
Net: one reusable typewriter+ASCII-reveal motion system, anchored on titles, sprinkled onto settings/agent/
non-editing surfaces, font-adaptive, blur-coupled, never bloated, never in editors.

## ✅ MOTION LANGUAGE = TRIAD (owner 2026-06-21, confirmed)
The app's motion language = the COMBO of: (1) **Apple blur**, (2) **ASCII typewriter** (time-machine
reveal), (3) **micro-motions across the app**. One cohesive system, used together.
- **APPLY TO:** **titles** + **subtitled / DISPLAY-ONLY parts** of the app (labels, headers, section
  subtitles, status lines, non-interactive text). Display-only = eligible; **text-EDITING = never**.
- **BALANCE (the rule):** **not super bloated, but interesting enough to be NOTICEABLE.** Present and
  delightful, not spammy or distracting. Tasteful signature motion everywhere display-only.
- This confirms + extends the ASCII-typewriter ontology above: blur + typewriter-ascii + micro-motions
  woven across titles and display-only surfaces, app-wide, balanced toward "noticeably alive, never bloated."

## 🌟 NORTH STAR / PRODUCT VISION (owner 2026-06-21)
Epistemos aims to **truly rival Obsidian** — a local-first **markdown PKM** whose foundation is **EPDOC
MD-V2** (md = source of truth, html/json = projections) — but with what Obsidian lacks: two first-class
agentic modes (**ACT** = Osaurus, **WORK** = OpenCode), deep **graph integration**, and a tasteful **motion
language** (blur + ASCII typewriter + micro-motions) that is **minimal + non-distracting** to the user.
Positioned as a polished **public release** — a genuinely cool addition for people, all major pieces present
and integrated, "all perfect" but never busy. Build priorities follow this: MD-V2 + graph + the two modes
are the PILLARS; motion stays minimal/non-distracting (leans toward "tasteful + restrained", noticeable but
never in the user's way). Everything serves: rival Obsidian, local-first, agentic, beautiful, minimal.

## 🌟 DESIGN SOUL + PROTECTED ASSETS (owner 2026-06-21)
**No direct competitor** (closest adjacent = Talaria, but a different shell / different direction). The bar:
feels like a **native Apple app shipped with their devices** — the perfect amount of **minimalism**, where
**clutter UI elements are HIDDEN BY PRIORITY** (progressive disclosure). So minimal it can look like a
demo/toy at a glance, but with **unprecedented EXECUTION** underneath. Minimal surface, deep substance.
- **DESIGN PRINCIPLE (apply everywhere):** priority-based progressive disclosure — show only what matters,
  hide the rest until needed. Minimal-but-deep; never busy; "Apple-native-grade" restraint. (This governs the
  motion language too: noticeable, never bloated.)
- **PROTECTED ASSET — the Prose editor (v1, KEEP IT):** 50k words still scrolling at **120 fps**. This is a
  crux asset (the performant editing core many note apps are built around). DO NOT regress its perf or
  replace it during the Osaurus/OpenCode integration; MD-V2 builds ON it. Treat its 120fps/50k-word
  performance as a guardrail (no regression).
- **PROTECTED ASSET — the landing page:** a minimal **decluttering + recentering ontology** that makes the
  app feel like a **landing WORKSPACE, not a demo**. Preserve + elevate this; the act/work landing pages +
  blur transitions extend it, never cheapen it.

## 🆕 PROSE EDITOR + MD-V2 COEXIST — both shine (owner 2026-06-21)
People will use BOTH the Prose editor AND MD-V2 — they're COMPLEMENTARY, not either/or. MD-V2 does NOT
replace Prose; both are first-class editing experiences that each shine. (Refines "MD-V2 builds on Prose":
they coexist.)
- **Prose 2 = native-Apple-grade, super HARDENED** — owner compares it favorably to the **Apple Notes** app;
  it feels like a true native Apple editor. That Apple-Notes-quality feel is the bar — keep it.
- **The notes SIDEBAR is a cool design choice — preserve it** (a deliberate, loved design element).
- **Apple Notes as a reference:** Notes has some things Prose doesn't yet — fine to mine Apple Notes for
  worthwhile gaps later (not now; opportunity noted), while keeping Prose's native-hardened character.
Net: two editors that both shine (Prose hardened native + MD-V2 markdown-first), the loved notes sidebar
preserved, Apple Notes as the quality bar + a future gap-source.

## 🆕 MORE LOVED ASSETS TO PRESERVE (owner 2026-06-21)
- **REAL TABS / easy navigation:** the app has **system tabs** AND a **full code editor with real tabs** —
  easy to navigate. A loved asset; preserve the real-tabs navigation across system + code editor.
- **PALETTE + FONT customization = a core differentiator:** changeable **palette AND fonts** (this is part of
  why it feels so personal/cool). Preserve + elevate; ties to the theme-aware (incl. custom themes) directive —
  themes drive act/work/Osaurus too.
- **Apple Notes comparison (owner's read):** mine feels **more minimal + easier to use**; Apple has more
  features; the real diff is **md (Epistemos) vs rich-text (Notes)** — so **hardening EPDOC MD-V2 is what
  closes/decides that gap.** Reaffirms MD-V2 hardening as a priority pillar (md is the edge, once hardened).

## 🆕 DISTRIBUTION — DUAL BUILD; ONLY ONE FEATURE IS MAS-BLOCKED (owner 2026-06-21)
CLARITY: there is exactly **ONE** feature that cannot ship on the Mac App Store — the **Linux-VM /
Containerization sandbox** (needs the restricted `com.apple.security.virtualization` entitlement). EVERYTHING
ELSE — full chat/ACT (Osaurus engine, MLX inference, server, MCP, relay, plugins, storage), the editors,
graph, themes — is MAS-grantable (~95%). So **the MAS version HAS a fully effective chat/act.** It's not
"no chat on MAS"; it's "no local Linux-VM sandbox on MAS."
- **DUAL BUILD:** (1) **MAS build** = full app MINUS the VM sandbox (flag that one feature off for the MAS
  target); (2) **direct-distribution build** (notarized, non-sandboxed) = 100% incl. the VM sandbox.
- **VERIFY:** the WORK/OpenCode bundled JS runtime (Bun) is a SEPARATE MAS check (bundled runtime/subprocess
  is the other classic sandbox friction) — confirm before assuming work ships on MAS; may be direct-dist too.

## 🆕 RESEARCH — MAS-compatible substitute for the VM sandbox (owner 2026-06-21)
Owner asks: is there a MAS equivalent to the one blocked feature, or just live without it? HONEST: there is
**no full local equivalent** — arbitrary Linux-container execution REQUIRES the gated virtualization
entitlement. But for the MAS build's "agent runs code safely" need, research these PARTIAL substitutes:
- **WASM in-process sandbox** (e.g. Pyodide for Python, QuickJS/JS) — MAS-safe, in-process, NO virtualization
  entitlement; limited to what compiles to WASM (no native binaries/arbitrary compilers).
- **Remote/cloud sandbox execution** — MAS-safe (just network); but not local/offline/private.
- **Restricted App-Sandbox helper / bundled tools** — very limited; can't run arbitrary Linux.
Verdict to confirm via a focused research pass: MAS build either uses a WASM/cloud-backed lighter code-exec
substitute (honest about reduced power) OR omits local code-exec, with the FULL Linux-VM sandbox living in the
direct-distribution build. Capture as an ordered research item (not deferred/droppable).

## 🔒 DUAL-BUILD DISTRIBUTION MODEL (owner 2026-06-21) — EXPLICIT, whole app + every clone
ONE codebase → TWO builds: **MAS build** (Mac App Store, sandboxed) + **PRO build** (direct-distribution,
notarized, non-sandboxed). This is first-class + applies to the WHOLE app and EVERY clone.
- **MAS must be AS ROBUST AS PRO** — exclude ONLY genuinely-ungrantable features; never cut for convenience.
- **Per-clone MAS-fit research (each clone gets its own verdict, like Osaurus did):**
  - **Osaurus/ACT:** ~95% MAS-OK; the ONLY block = Linux-VM sandbox (restricted virtualization entitlement).
  - **OpenCode/WORK:** Pro-only (bundled JS/Bun runtime) — **does NOT need MAS** (owner confirmed); ships in
    the Pro build. Confirm/keep it out of the MAS target.
  - **Goose, OpenClaw, Hermes, Talaria, Epdoc-fuse, + any future clone:** RESEARCH each for MAS-fit
    (entitlements + runtime), tag each feature MAS-OK / Pro-only. Ordered research item, not droppable.
- **Linux-sandbox MAS substitute:** since MAS can't do the VM, RESEARCH THE BEST MAS-compatible sandbox to
  substitute (WASM in-process e.g. Pyodide/QuickJS, or cloud sandbox) so the MAS build still has safe code
  execution — pick the best; MAS robustness is the goal.

### HOW to build two builds of one app (process)
- ONE codebase, TWO Xcode **targets/schemes** (or one target + two configs): "Epistemos (MAS)" + "Epistemos
  (Pro/Direct)". The codebase ALREADY uses the gate `#if EPISTEMOS_APP_STORE` (e.g. ActOsaurusBridge wraps
  the Osaurus seam in `#if !EPISTEMOS_APP_STORE`) — extend that pattern.
- **Per-target ENTITLEMENTS files:** MAS = sandboxed entitlements (network.server/client, automation, etc.,
  NO virtualization); Pro = non-sandboxed/full (incl. virtualization). Per-target Info.plist/bundle id.
- **CAPABILITY SCHEMA = the single source of truth:** tag every feature MAS-OK / Pro-only; both builds read
  it (compile-time `#if EPISTEMOS_APP_STORE` + a runtime capability map) so MAS auto-excludes Pro-only
  features (VM sandbox, OpenCode/Bun, etc.) + swaps in MAS substitutes (WASM/cloud sandbox). "MAS schema" =
  this matrix, the way the owner has been gating.
- **CI builds BOTH** profiles; a guard test asserts the MAS target does NOT link Pro-only deps (the existing
  MAS/Pro boundary guard test pattern). xcodegen/project.yml defines both targets.

## ‼️ CORRECTIONS — OWNER DIRECTIVES OVERRIDE THE RESEARCH RECS (owner 2026-06-21)
The build drifted toward the convergence/feasibility RECOMMENDATIONS. Those are INPUTS; the owner's
decisions below WIN on any conflict. Realign now.
1. **GOOSE = FULL CLONE, not leaf-by-leaf hand-port.** Vendor Goose like Osaurus: clone the real repo +
   add the needed crates (goose, goose-providers, …) as REAL Cargo path/dependencies, and pull `rmcp` as a
   REAL dependency — do NOT hand-rewrite `Role`/`Message`/provider wire types one at a time (that's the
   cherry-pick → "never fully cloned → muddiness" failure the owner banned). Resolve dep clashes (like the
   dual-MLX saga) — that integration cost is ACCEPTED. Leaf-porting individual types = STOP; vendor whole.
2. **WORK = KEEP OPENCODE'S REAL TERMINAL UI (owner override beats the feasibility "native rebuild" rec).**
   Work = OpenCode's real minimal-terminal UI, palette-matched live (named "work"), with Goose + Hermes +
   OpenClaw fused in as the engine BENEATH it. Do NOT drop OpenCode's UI for a native SwiftUI rebuild. The
   feasibility doc's Option C2/B (native shell) is OVERRIDDEN — owner chose Option A (keep real UI). The
   bundled OpenCode runtime is FINE (Pro/direct-distribution build; MAS-leniency set in stone). "Goose
   inside OpenCode" = OpenCode shell + Goose engine within, NOT Goose-shell-that-looks-like-OpenCode.
3. **TAMAGOTCHI render-fix = IN SCOPE (owner-authorized).** Not blocked by the off-limits-Companion guard —
   the owner directed: keep the Tamagotchi agent-creation STYLE + fix the render bug (too small + inner
   squares). Proceed.
4. **GENERAL RULE:** when a research doc (AGENT_STACK_CONVERGENCE / OPENCODE_FEASIBILITY / etc.) conflicts
   with this addendum or a 2026-06-21 owner directive, the OWNER DIRECTIVE WINS. Re-read the addendum each
   cycle; don't revert to a research recommendation the owner has already overridden.

## 🆕 OPENCODE "HEAVINESS" — MITIGATION (owner 2026-06-21): the Electron/Tauri bloat is OPTIONAL
THE CAVEAT ("this isn't what we thought"): OpenCode is **headless-FIRST** (a Bun/TS server: Hono + OpenAPI +
SSE + typed SDK). The **Electron/Tauri web GUI is just ONE optional client** — the heaviness lives THERE, and
**we do NOT ship it.** Per the owner's Option A, the UI we want is the **terminal TUI**, which is NOT Electron
(it's terminal-cell rendering, no Chromium). So the perceived Electron/Tauri bloat largely **evaporates**.
Mitigations (make heaviness ~non-existent):
1. **Drop the Electron/Tauri web GUI entirely.** Never bundle Chromium. Headless engine only.
2. **Render OpenCode's REAL terminal TUI in a NATIVE terminal view** (SwiftTerm / embedded PTY) — terminal
   cells, palette-matched, no browser engine. Keeps the real UI (Option A) at terminal-light weight.
3. **Engine = Bun headless server:** bundle the single **Bun binary (~90MB, one file)** — lighter than
   Node+Electron; **lazy-launch only when WORK opens**, **loopback-only**, **kill-on-idle** (reuse the
   existing subprocess-hardening + idle-unload discipline). Not running at app start.
4. **Other clones aren't affected:** Osaurus/ACT is **native Swift — zero Electron.** Heaviness is an
   OpenCode-only concern, and it's the GUI we skip.
HONEST CAVEATS (not zero): still ~90MB Bun on disk (Pro build only) + real RAM when work is ACTIVE (mitigated
by spawn-on-open/kill-on-idle) + PTY/SwiftTerm bridge is real engineering. But the footprint = "a lazy
background server + a terminal view," NOT "an Electron app inside your app."
ULTRA-LIGHT FALLBACK (if real-TUI-in-SwiftTerm feels clunky): render a NATIVE pixel-art terminal-look view
over the headless engine (HTTP) — zero web/PTY weight; but that leans toward native-render (owner prefers the
REAL UI, so use this only if the real-TUI path can't hit the feel/weight bar).
RESEARCH ITEM (ordered): confirm OpenCode's TUI renders in SwiftTerm + measure Bun disk/RAM; choose
real-TUI-in-PTY (preferred) vs native-terminal-render fallback.

## 🆕 DEEP OPTIMIZATION CYCLES + SECTIONS (owner 2026-06-21) — recurring, comprehensive
Owner had hand-tuned optimizations BEFORE the clones. Two mandates: (a) PRESERVE the owner's existing
optimizations (no-regress during clone integration), and (b) DEEP-OPTIMIZE the cloned code too (Osaurus/
OpenCode/Goose may be less tuned than the owner's app). Run as RECURRING CYCLES + standing sections — not
one-off. Each cycle: profile → find hotspot → optimize → verify (no regression + a measured win) → commit.
Cadence: a deep-optimization pass at each tier boundary / every ~5 items + dedicated lower-but-CERTAIN passes.

### Optimization DOMAINS (cover these + tangential terms not listed)
- **Swift concurrency:** actor isolation, `@MainActor` boundaries, **off-MainActor inference**, **Task.detached**,
  structured concurrency, `Sendable`/`nonisolated`, QoS/priority, task cancellation, avoid main-thread blocking,
  `DispatchQueue.main.async` (never `.sync`) in UniFFI callbacks, `AsyncStream` `.bufferingNewest`, actor
  re-entrancy, contention/lock-free, `nonisolated(unsafe)` only where proven.
- **Memory:** memory-pressure handlers (warning/critical), bounded caches, **idle model unload**, KV-cache drop,
  lazy-init / computed-getter deferral, TTL eviction, ring buffers, `releaseMemory`/`shrink_memory`, weak refs,
  copy-on-write, autorelease scoping, resident-set reduction.
- **Metal/GPU/inference:** pipeline-state caching, `deepUnload`, binary archive, working-set release, MLX/vmlx
  quant (KIVI) memory benefit, batch/throughput, thermal-aware scaling.
- **UI/render perf:** the **120fps editor** (Prose, no-regress), `TimelineView` over `Timer`, shared
  `WKProcessPool`, dismantle/teardown of views, `@Query`/fetchLimit caps, lazy view init, diffing, scroll perf,
  off-screen pause.
- **Rust/agent_core:** tokio minimal features, writer-heap tuning, JSON compaction (no pretty on hot paths),
  shm-pool eviction, session prune, zero-copy/shared buffers, bounded channels.
- **I/O + DB:** SQLite PRAGMA (cache_size/mmap), FTS tuning, Spotlight body trim, `URLCache=nil`, batched writes,
  async I/O.
- **Startup/launch:** AppBootstrap lazy-init, cold-start, launch-smoke, deferred service wiring.
- **Energy/thermal/binary:** low-power-mode scaling, thermal modifiers, dep minimization, binary size.

### Rules
- **No-regress guardrails:** the 2,679-test suite, the Prose 120fps/50k-word bar, AppGroup/AppKit perf — never
  regressed by clone integration or optimization. Each optimization proves a win + zero regression (real-state).
- **Optimize the clones to owner-app standard:** apply these domains to Osaurus/OpenCode/Goose code as it lands.
- **Sequencing:** runs as a STANDING TRACK throughout + dedicated deep passes sequenced LOWER but CERTAIN (not
  "deferred"/droppable). Add found hotspots to the ledger as ordered items.

## 🆕 DEEP CHECK — PROVE THE REALITY, NOT THE CLAIM (owner 2026-06-21)
Owner observed: app defaulted to **codex**, NO Osaurus reskin, NO animations — "looks just like chat/act."
Some of that is expected (reskin/animations are post-engine, not built yet) — but PROVE it; don't assert
"normal." The agent MUST run this DEEP CHECK when it reaches this point (and as a standing re-verify):
1. **Is the Osaurus engine ACTUALLY the live act path?** Check `EPISTEMOS_ACT_OSAURUS_V0` flag state + trace
   the real runtime: when "act" runs, does it go through OsaurusCore or the OLD engine? Real-state test +
   computer-use/runtime evidence — not "linked therefore live." If flag-off, say so plainly (it's staged,
   not reaching the user).
2. **WHY did it default to CODEX?** TRACE the default model/provider resolution for chat/act. Is there a
   SILENT codex default/fallback? (Same no-hidden-fallback rule as the Qwen P0 — codex should NOT be a
   silent default.) Fix to an honest default = the owner's pick / local-first, never a silent cloud/codex
   substitute. Add a real-state regression test that fails if it silently defaults to codex.
3. **Reskin + animation status — HONEST:** report exactly what's built vs not (act reskin, model picker
   preserve, motion language, landing/mode-entry animations). Do NOT claim done on unbuilt UI. "Looks like
   chat" right now = expected ONLY because the reskin phase hasn't run — confirm that's the reason, not a
   silently-skipped directive.
4. **Whole-surface reality vs directives:** for act/work/chat, verify each 2026-06-21 directive is actually
   implemented (or honestly 🔴 not-yet), grounded in code + runtime. Update OSAURUS_BUILD_PROGRESS with the
   PROVEN state. No fake-green; flag anything claimed-but-not-reaching-the-user (PROVEN-DONE doctrine).
This deep check is a standing gate: re-run it whenever a surface is claimed done.

## 🆕 QUARANTINE = CODE-PRESERVED **+ UI-HIDDEN** (owner 2026-06-21) — clarifies the no-delete rule
"Quarantine, never delete" has TWO layers, both true:
- **CODE-LEVEL: preserved in-tree, NEVER deleted** (for the IP porting cycles).
- **UI-LEVEL: HIDDEN from the user** — once **act is PROVEN live**, remove the old "chat" from the user-facing
  UI so the user sees ONLY the clean **two-mode ontology: ACT + WORK**, with the press/click-to-start-convo →
  blur → landing flow. No confusing old-chat surface shown alongside act.
- **SEQUENCING / SAFETY:** do NOT hide chat BEFORE act is proven live (never leave a broken/empty gap). The
  flow: act proven live (flag on, verified) → hide old chat from UI → user sees act+work only → chat CODE
  stays quarantined for IP porting → retire code only after the 4-part bar + owner OK.
Net: the user-facing experience converges to the two-chat (act/work) ontology + click-to-start-convo; the
old chat is hidden (not deleted), its code preserved underneath. Early-transition both may show; the target
is act+work only.

## 🌟 INITIATIVE — ADOPT PROVEN ENGINES, LAYER MY IP (owner 2026-06-21)
PRINCIPLE: commodity infrastructure (agent loop, model serving, tool-calling, sandbox, sync, indexing,
LSP, etc.) is ALREADY SOLVED by proven public GitHub repos — ADOPT/clone those (like Osaurus/Goose/OpenCode)
instead of hand-building + maintaining them. Reserve the owner's effort for the UNIQUE IP that gets LAYERED
ON TOP. Don't reinvent what the community has perfected; differentiate where it counts.

### Recurring CHECK — "ADOPT vs IP-LAYER" classification (research-grounded)
Maintain a LIVING MAP that classifies every major capability:
- **ADOPT** — a top public repo already does this well → vendor/clone it (cite the repo + why). e.g. agent
  loop/serving/sandbox = Osaurus; work engine = Goose; LSP = existing rust lsp_runtime.
- **IP-LAYER (owner differentiator — keep/build on top, never commoditize):** the BRAIN (Eidos/recall,
  cognitive DAG, provenance, honesty gating, prompts), the UI/design/MOTION language, the EDITORS (Prose
  120fps + MD-V2), the MODEL LAB (QAT ladder, "Epistemos Picks", per-model engineering), the GRAPH.
- **HYBRID** — adopt the engine, layer IP on top (the default for act/work).
PROCESS: each cycle (and at tier boundaries) RE-SCAN the public landscape (top GitHub repos) for the
capability at hand; if something the owner is hand-building is already solved publicly AND better, switch to
ADOPT + layer IP. If a "unique" thing is actually commodity, stop hand-maintaining it. Output a doc:
`docs/research/ADOPT_VS_IP_LAYER_MAP_2026_06_21.md` — what's COMPLETE-elsewhere (adopt) vs OWNER-IP (layer),
grounded + cited. Extends AGENT_STACK_CONVERGENCE_RESEARCH (which already classified Osaurus/Goose/OpenCode/
OpenClaw/Hermes). Standing item, not droppable.

## 🆕 GOOSE FULL-VENDOR COST (grounded 2026-06-21) — feeds the OpenCode-vs-Goose decision
Owner principle: "get as MUCH as I can WHILE being beneficial" = maximize benefits BUT be SMART (don't pour
effort/bloat into a painful path if a lighter one gets ~the same benefit). GROUNDED FINDING (agent, in
docs/research/GOOSE_FULL_CLONE_INTEGRATION_COST_2026_06_21.md): the leaf-ported types live in the `goose`
crate = **179-dep graph** (tokio, reqwest, rmcp, sqlx, oauth2, smithy-transport). Vendoring it as a real
in-process Cargo dep **CONFLICTS with agent_core** — confirmed **reqwest 0.12 (agent_core) vs 0.13.2 (goose)
= incompatible major versions**, plus rmcp/tokio/sqlx splits → a **multi-iteration, build-RED-prone**
reconciliation. Correctly sequenced lower-but-CERTAIN (NOT dropped); do it in a build-iterable context, never
commit red to main. Interim leaf-ports stay honest-superseded.
IMPLICATION for the OpenCode-vs-Goose decision (research running): **in-process Goose = heavy dep-conflict
cost**; **OpenCode-over-HTTP (headless, separate process) AVOIDS the Cargo dep-graph merge entirely.** So
"be smart" likely tilts toward OpenCode-as-work-engine OR Goose-unique-bits-only, UNLESS Goose's Rust engine
uniquely justifies the reconciliation. The OPENCODE_VS_GOOSE_WORK_ENGINE research must WEIGH this integration
cost (perf/robustness benefit of Rust vs the 179-dep reconciliation cost) in its recommendation. Decision +
agent-prompt to follow from that research.

## ✅ DECISION — WORK ENGINE = ARCHITECTURE C (owner 2026-06-21)
Owner chose **C**: **OpenCode = the WORK engine of record** (headless Bun, beneath its REAL terminal UI —
kept literally, set in stone). Decisive directives:
- **OpenCode is the work engine.** IP brain rides ON TOP via MCP; code-intelligence = the EXISTING Rust
  `lsp_runtime` (already wired via work_lsp_tools.rs) — do NOT import OpenCode's LSP.
- **Goose is NOT vendored as a second engine.** Do NOT vendor the heavy `goose` crate (avoids the confirmed
  179-dep / reqwest-0.12-vs-0.13.2 / 660MB build-red saga). Goose's UNIQUE bits stay as the in-tree
  clean-room Rust in `agent_core/src/work.rs` (RetryManager / RepetitionGuard / recipes / permissions),
  surfaced as work-loop TOOLS. **RE-LABEL the superseded Goose leaf-ports as the PERMANENT clean-room home**
  (not "interim-until-full-clone") — keep, GUARDRAIL-isolated, never delete.
- **Keep OpenCode's real terminal UI** (native terminal view / SwiftTerm-PTY, palette-matched live), Bun
  lazy-launch on work-open + kill-on-idle (footprint bounded; crash-isolated via the process boundary).
- **All benefits, ONE engine** — no second agent loop (dedup honored). Concession accepted: engine is TS/Bun,
  not Rust; mitigated by process isolation + bounded footprint.
- B2 (Goose Rust engine) is NOT taken. Next big-ticket: vendor the OpenCode bundled runtime + wire the work
  loop end-to-end through it, beneath the real TUI.

## ⏸️ WORK-ENGINE FINALIZATION ON HOLD (owner 2026-06-21)
Owner: fold the ADOPT-vs-IP-LAYER map research in BEFORE finalizing. That map FAILED twice on a 529 server
overload — it does NOT exist yet. So: the Architecture-C decision above is CONFIRMED-but-PROVISIONAL; do NOT
hand the build agent a final "go build WORK" directive until the ADOPT_VS_IP_LAYER_MAP_2026_06_21.md lands and
is cross-checked against C (it may surface dedup/overlap context that refines C — e.g. which Goose unique bits
truly justify clean-room tools vs are commodity). Re-run the map when the API recovers. The agent may continue
bounded green increments (ACT polish, motion sweep) meanwhile, but NOT the heavy WORK-engine commitment.

## ✅ MAP FIRST-PASS DONE → C CONFIRMED (provisional deep-pass pending) (2026-06-21)
ADOPT-vs-IP-LAYER sub-agent 529'd 3× → produced a grounded FIRST-PASS inline:
docs/research/ADOPT_VS_IP_LAYER_MAP_2026_06_21.md. **C CROSS-CHECK = HOLDS** (OpenCode work engine confirmed,
no duplication; LSP = existing lsp_runtime). ONE dedup check the deep pass must confirm: **Goose `permissions`
vs OpenCode's own permissioning** — keep Goose's RetryManager/RepetitionGuard/recipes as clean-room tools
(genuine hardening), but DROP Goose-permissions if OpenCode already covers it. With that single caveat,
**Architecture C is finalized** — work-engine build may proceed. DEEP-PASS TODO when API recovers: full cited
repo sweep + "anything-else"/Talaria + per-capability license/MAS detail (refine, won't change C).

## ✅ C FINALIZED + 2 REFINEMENTS (owner 2026-06-21, deep deliberation)
Deeper deliberation (ADOPT_VS_IP_LAYER_MAP "DEEPER DELIBERATION"; sub-agent 529'd 4× so monitor-synthesized
from committed research) → **Architecture C is FINALIZED + strengthened** (OpenCode = lower-risk AND
higher-capability work engine: headless = zero Cargo dep-merge + crash isolation). Two refinements that IMPROVE C:
1. **DROP Goose `permissions`** — OpenCode (a coding agent) has its own file/shell permission gating → dedup.
   Keep RetryManager + RepetitionGuard (cheap hardening); VERIFY `recipes` vs OpenCode's agent/command config,
   drop if duplicated.
2. **LSP under C = OpenCode's BUILT-IN** (auto-loads 40+ servers). Do NOT force-wire YOUR `lsp_runtime` into the
   OpenCode work loop (double-LSP). RE-EVALUATE `work_lsp_tools.rs` (1c753902e) — likely REDUNDANT under C;
   keep `lsp_runtime` for your NATIVE EDITORS (Prose/Epdoc), not the work loop. (Supersedes the convergence-era
   "wire lsp_runtime into work," which assumed Goose-engine = no LSP.)
STRATEGIC: ~2/3 of infra is ADOPT/HYBRID; concentrate ALL owner effort on the IP ~1/3 (brain, native editors
Prose+MD-V2, graph+Metal, model lab, UI/motion). DEEP CITED pass owed when API recovers (repo URLs/license +
"anything-else" + Talaria) — refines, won't change C.

## ⚖️ VERDICT — why OpenCode beats Goose-Rust for WORK (owner 2026-06-21)
Goose-Rust wins are ENGINE-INTERNAL (per-line memory/type safety, in-proc footprint/speed, brain-in-proc).
OpenCode wins are PRODUCT-level + SYSTEM-level and OUTWEIGH them for WORK: (1) more MATURE coding engine
(75+ providers, built-in LSP, fork/share, undo-redo); (2) keeps the LITERAL terminal UI owner set in stone;
(3) ZERO Cargo dep-merge (Goose-in-proc = the 179-dep/reqwest-conflict/build-red saga); (4) CRASH ISOLATION —
the reframe that flips "Rust = robust": an in-proc Goose bug can crash the WHOLE app; OpenCode in its own
process is CONTAINED, so at the SYSTEM level the process boundary gives OpenCode BETTER fault-isolation than
in-proc Rust. Rust's per-line safety is real but doesn't stop the engine from aborting the app; isolation does.
Footprint (Bun ~90MB) is bounded (lazy-launch + kill-on-idle = $0 when idle). AND Rust isn't abandoned: act
engine (Osaurus) + brain (agent_core) + Goose's unique-bit TOOLS stay Rust; only the work-shell ENGINE is
OpenCode, quarantined in its own process. → Rust-ness is NOT enough to win here because the robustness that
reaches the USER is system-level (isolation), not per-line. C stands.

## ✅ WORK LOOK = OpenCode's REAL TUI, NOT the GUI (owner 2026-06-21, confirmed)
The work UI the owner loves = **OpenCode's real TUI** (terminal-cell, flat, monospace, "classic terminal
flatness" + flat/cell-based animation) — **NOT** the web/Electron GUI. Build the TUI path ONLY:
- **Bundle the entire OpenCode ENGINE** (headless Bun) + render its **REAL TUI** in a native terminal view
  (SwiftTerm/PTY), palette-matched to the app theme (live, incl. custom themes). Named "work".
- **DO NOT ship/build the web/Electron GUI client** (the heavy, redundant client) — engine + TUI only.
- Accept the TUI's terminal flatness as the desired aesthetic (it's what the owner wants); do NOT try to make
  it pixel-smooth/GUI-like. (If pixel-smooth is ever wanted later = a separate native reskin, not the TUI.)
This is the complete OpenCode experience (full engine + real TUI), minus only the unused second client.

## ✅ CITED RESEARCH DONE → C CONFIRMED + Tolaria find (owner 2026-06-21, monitor did it personally)
Sub-agent 529'd 5×, so monitor ran the cited web pass (see ADOPT_VS_IP_LAYER_MAP "CITED PASS"):
- **OpenCode** github.com/sst/opencode (Anomaly) = ~170k★, MIT, 75+ providers, ~6.5M MAU, TS/Bun TUI.
- **Goose** github.com/block/goose (now Linux Foundation/AAIF) = ~46.7k★, Apache-2.0, Rust, 15+ providers.
- **VERDICT (cited): Architecture C CONFIRMED** — OpenCode is the dominant, most-adopted, most-provider WORK
  engine; Goose's Rust/LF-governance don't overcome that + the C wins (isolation, literal TUI, no dep-merge).
- **Talaria = Tolaria** (github.com/refactoringhq/tolaria): files-first/git-first/offline-first md PKM, AI-agent-
  native (Claude Code/Codex/Gemini CLI + local MCP vault server). = closest adjacent; VALIDATES md-first +
  agent-vault; Epistemos goes beyond it. REFERENCE, not an adopt-target.
- **NEW PLAN ITEM (low-effort, high-fit):** expose the Epistemos VAULT as an MCP context source for external
  agents (the Tolaria pattern) — likely partly present via omega-mcp/vault; finish it so Claude Code/Codex/etc.
  can work on the vault. Add to ledger as an ordered item.
DEEP cited map (every row's URL/license + full "anything-else") still owed when sub-agents recover — refines, won't change C.

## ✅ CONSENSUS — KEEP TriageService; inject gated act swap (do NOT delete) (owner 2026-06-21)
The app has TWO shared inference chokepoints: `liveLoop` (ChatCoordinator/MiniChat/Pipeline/iMessage — act
already wired) and **`TriageService`** (Note chat + Graph chat + 4 other sites route through
`localStreamOrFallback`, 6 callers). TriageService is LOAD-BEARING — deleting it breaks Note/Graph chat + the
others. So:
- **DO NOT get rid of triage.** It is not cruft; it's the shared local-stream chokepoint for those surfaces.
- **CORRECT + SAFE fix (the agent's approach):** inject the SAME gated act=Osaurus swap at the top of
  `localStreamOrFallback`, behind the SAME flag (`shouldRouteActThroughOsaurus`, OFF by default). Flag-OFF =
  byte-identical to today (prove with a test); flag-armed = Note + Graph chat (+ all 6 sites) stream through
  Osaurus. One gated injection completes "EVERY chat surface gets act." This is the completeness sweep working.
  [NOTE: this `shouldRouteActThroughOsaurus` flag is a TRANSIENT refactor-safety mechanism, REMOVED once act=Osaurus
  is the default chat — it is NOT a product on/off toggle. End state: Osaurus IS the chat on every surface, no flag.]
- **Real-state test required:** assert Note + Graph chat route through the act bridge when armed, and the MLX
  path is unchanged when off. No regression to the 6 callers.
- **FUTURE (lower-but-CERTAIN, not now):** consolidate toward ONE inference chokepoint (the "one brain" goal) so
  there aren't two parallel act-injection points to maintain. Do NOT force that risky consolidation now —
  for now, BOTH chokepoints route through act when armed. Record as an ordered cleanup item.

## 🎯 DIRECTIVE — ONE INFERENCE CHOKEPOINT (owner 2026-06-21, explicit)
Owner wants a SINGLE inference path, not two (liveLoop + TriageService). TARGET: **one shared inference
chokepoint — the "one brain" entry — that EVERY surface routes through** (main chat, MiniChat, Note chat,
Graph chat, Pipeline, iMessage, ACT, WORK). The engine/act routing decision (act=Osaurus, work=OpenCode,
MLX, etc.) lives in ONE place; the IP brain wraps that one point. No more parallel paths to keep in sync.
- **Build it DELIBERATELY + SAFELY (it touches live inference — highest-risk surface):** commit a clean
  savepoint first; build the unified chokepoint ADDITIVELY (both `liveLoop` and `TriageService` delegate INTO
  it, behind a flag) so flag-OFF = byte-identical to today; real-state test EVERY surface (each chat type
  routes correctly, streaming/thinking/tools intact, no regression to the 2,679-suite or the 6 triage
  callers); then flip on + retire the duplicate path. NEVER a big-bang rewrite of live inference. [NOTE: this
  flag is a TRANSIENT internal refactor-safety mechanism that is REMOVED when the path is flipped on — it is
  NOT a product on/off toggle and NOT an optional feature. Distinct from the voided act-toggle drift.]
- **SEQUENCING:** do this AFTER the gated act-swap lands in both chokepoints (so nothing breaks mid-way) — it
  is the consolidation that REMOVES the two-injection-point duplication. CERTAIN (not "deferred"/droppable),
  sequenced as a deliberate refactor. This is the cleanest expression of "one brain on top, engines beneath."

## 🌟 MARKET POSITION (monitor web research, 2026-06-21) — the intersection is empty
The 2026 market SPLITS into two categories Epistemos FUSES: (1) "md PKM + AI-reads-vault" apps — ZenNotes,
Kuku, Ally, MarkMorph, Tolaria, Obsidian+plugins (notes + agent-on-vault; NO real coding/work engine, code
editor, or local model lab) [verified web]; (2) "AI coding agents" — Cursor, Claude Code, Codex (code, NO
PKM/notes/graph/vault). NO single app does the COMBINATION = PKM + native text&code editors + agentic ACT
(Osaurus) + Codex-class agentic WORK (OpenCode) + local MODEL LAB + graph, native + local-first. Owner's
"no competitor" instinct CONFIRMED — Epistemos is at the empty intersection.
NOT a "nerfed Codex": WORK mode IS OpenCode (top coding agent, supports the SAME 75+ providers incl. frontier
GPT/Claude → same coding ceiling when desired) embedded in a PKM/notes/local-model app. Honest where it's
less: local-model raw quality < frontier cloud (a choice, you can use cloud); MAS loses VM sandbox (Pro keeps);
solo maturity. But it's NOT a subset of Codex — Codex can't edit notes, hold the graph, run local QAT models,
or be a PKM. Positioning for public release: "a local-first agentic workspace that contains a Codex-class
engine — not a weaker Codex, a broader tool."

## 🌟 PILLAR — VAULT-DEEP-INTEGRATION (overtake Tolaria) (owner 2026-06-21) — MAJOR, not a line-item
RESEARCH (Tolaria's process, verified github.com/refactoringhq/tolaria): files-first plain .md + YAML
frontmatter, git-versioned, "types as lenses not schemas", and an **MCP server that exposes the vault as
context to EXTERNAL agent CLIs** (Claude Code/Codex/Gemini) — you bring your own agent; Tolaria's graph is
thin; agents edit plain FILES (not its editor). That MCP-vault is Tolaria's CENTERPIECE.
**OVERTAKE THESIS:** Epistemos does Tolaria's vault-agent vision but DEEPLY NATIVE + far beyond. The vault is
a first-class PILLAR, deeply integrated with:
1. **act + work AGENTS (BUILT-IN):** Epistemos's OWN act (Osaurus) + work (OpenCode) agents work the vault
   NATIVELY in-app — not "bring an external CLI." PLUS expose the vault as an MCP context source for external
   agents too (match Tolaria). So BOTH internal agents AND external-MCP.
2. **GRAPH:** the vault's notes + links ARE the knowledge graph; agents + graph deeply integrated (Tolaria's
   graph is weak → overtake here). Agents can traverse/query/build the graph.
3. **LLM WIKI + WIKILINKS:** wikilinks `[[...]]` + backlinks + an LLM-augmented wiki over the vault
   (auto-linking, LLM-suggested connections/summaries, semantic backlinks). The "llm wiki" = the brain
   (Eidos/recall/provenance) reading + enriching the vault.
4. **IN-EDITOR AGENT EDITING:** agents work directly on the **Prose editor AND the MD-V2/Epdoc surface** —
   live in the real editors, not just plain files (Tolaria's external-CLI-on-files can't do this seamlessly).
   This is the killer differentiator: native in-editor agent edits on both editing surfaces.
**Treat as a PILLAR** alongside the two modes / editors / graph / model lab — deeply integrated, not bolted on.
Research item (cited deep pass when sub-agents recover): mine Tolaria's MCP-vault schema + "types as lenses"
for any patterns worth adopting; ensure Epistemos's vault-as-MCP matches/exceeds it.

## 🔒 STANDING — THE FULL-CLONE PROCESS (Osaurus method) for EVERY adopted engine (owner 2026-06-21)
For EVERYTHING classified ADOPT (an engine/capability Epistemos LACKS), use the SAME process as Osaurus —
NO cherry-picking:
1. **Full clone** the whole repo/engine (zero cherry-pick; all code, LICENSE, tests in-tree or bundled).
2. **Reskin** to Epistemos pixel-art native (or, for OpenCode, render its real TUI palette-matched).
3. **Per-clone SETTINGS tab** (Epistemos | act | work | beyond) — bring the clone's own settings, respected.
4. **Couple to the relevant surface** + wire to a real proven front-end (no dead surfaces).
5. **In-process (Swift/Rust) or bundled runtime** as fits; **MAS + Pro dual-build** (only genuinely-ungrantable
   excluded); **IP brain layered on top**; honest, no fake-done.
This is the repeatable method for Osaurus (done), OpenCode (Arch C), and any FUTURE adopted engine.

### CLONE vs REFERENCE — the rule (so "no cherry-pick" is applied correctly)
- **ADOPT-TARGET = engine/capability you LACK** → FULL CLONE process above (Osaurus/OpenCode/Goose-bits).
- **REFERENCE/COMPETITOR = capability you ALREADY HAVE, better** → do NOT clone (it would DUPLICATE your own IP).
  Mine its unique pattern + build NATIVELY. This is NOT cherry-picking — it's not-duplicating-your-IP.
- **TOLARIA VERDICT:** REFERENCE, not a clone-target — Epistemos already has the md-PKM editor BETTER (Prose
  120fps + MD-V2 = IP). Cloning Tolaria would duplicate/conflict with your editors. Take its ONE unique idea
  (vault-as-MCP / agent-native vault) and build it natively = the VAULT-DEEP-INTEGRATION pillar; "couple to
  Epdoc" = agents on the MD-V2/Epdoc + Prose surfaces natively. Overtake Tolaria WITH your editors, not its.
The ADOPT-vs-IP-LAYER map decides which bucket each thing is in.

## 🔁 NEVER-IDLE — TAKE ON THE HEAVY WORK, DON'T HOLD (owner 2026-06-21)
The loop must NOT stop/hold at a "clean-green limit." **"Heavy / multi-iteration" is NOT a reason to defer —
it's a reason to do it INCREMENTALLY across loop turns** (build a slice → green → commit → next slice). Take
on the heavy integration backlog NOW, iteratively:
- Epdoc/MD-V2 inversion (md = source, projections); agent-edit PROVENANCE; **vault→GRAPH population**;
  **LLM-wiki UI surfacing**; **ONE-CHOKEPOINT phase 2** (consolidate liveLoop+TriageService, additively/safely);
  the motion sweep onto more titles/display-only; per-clone settings "beyond" tabs; act streaming.
- A clean savepoint before risky edits is fine; building a slice over several iterations is fine. **Avoiding
  the heavy items is NOT.** Make real progress every iteration; never idle, never "hold for owner" on
  non-gated work.
- **ONLY genuine EXTERNAL blockers may wait:** (a) OpenCode runtime vendor needs `brew install bun` (owner can
  run it; until then, build everything else); (b) the cited ADOPT deep pass needs API recovery (a research
  nicety, NOT a build blocker — skip + keep building). If one item is truly blocked, WORK A DIFFERENT
  NON-BLOCKED ITEM — there is a large backlog; never run out.
- Standing: never commit RED to main (iterate to green first), never fake-done, never delete chat. But within
  that, KEEP CODING the substantive backlog — bias to progress on the hard items, not waiting.

## 🆕 BUN RUNTIME = VENDORED/BUNDLED, NOT `brew install` (owner 2026-06-21) — friction-free
Two different contexts were conflated — resolve BOTH by VENDORING the Bun binary, not depending on Homebrew:
- **END USERS must install NOTHING.** **BUNDLE the pinned Bun binary inside the Pro app** (`Epistemos.app/
  Contents/Resources/`). Bun is a single self-contained ~90MB binary → trivial to bundle. The app runs its OWN
  Bun for the OpenCode engine; zero install, no Homebrew, works offline. Codesign + notarize the bundled binary
  as part of the app (BUILD-time step, not user friction). Bun is MIT → fine to bundle.
- **DEV/BUILD machine:** don't rely on `brew install bun` either — a **build script fetches the pinned Bun
  binary into the repo/Resources** (content-hash gated, like build-tiptap-bundle.sh). The SAME vendored binary
  the build uses is the one that SHIPS. One mechanism serves dev + ship; removes the `brew install bun` gate
  entirely. (`brew install bun` is fine as a TEMP dev shortcut today, but the real fix is vendoring it.)
- **Scope fit:** OpenCode/Bun is PRO/direct-distribution only (non-sandboxed, notarized) → bundling + executing
  the binary is fine there. MAS doesn't get OpenCode, so no MAS-sandbox issue. ~90MB added to the Pro .dmg
  (acceptable — Pro is the full build).
- **Alternative (leaner installer):** download-on-first-use via the existing ModelDownloadManager pattern
  (fetch + verify Bun on first work-mode launch, cache it). Bundling is MORE friction-free; download = smaller
  .dmg. Default = BUNDLE; download-on-demand only if installer size becomes a concern.
GENERAL RULE: any runtime/dep a clone needs (Bun, future ones) = VENDOR/BUNDLE it (or download-on-first-use),
NEVER make the user run a package manager. Same "build-once, ship-it" pattern as the tiptap bundle.

## 🆕 ENGINES DONE → NOW BUILD THE VISIBLE SURFACES (owner 2026-06-21)
Act engine ✅ + work runtime vendoring underway → the engine-first prerequisite is MET. So PRIORITIZE the
VISIBLE, testable surfaces now (the owner wants to SEE/test it):
- **ACT reskin** (current-chat discipline) → make the Osaurus act surface actually visible.
- **WORK UI live** — wire WorkTerminalView/WorkOpenCodeShell into a reachable, working work surface (real TUI).
- **Landing pages + BLUR transitions + act/work toggles + mode-entry animations** (move from 🔴 to built).
- **Motion sweep** onto titles/display-only.
- **[VOID drift-addition — there is NO toggle and NO flag. Osaurus IS the chat, on by default. The
  "flip flag / add in-app toggle" framing here was a drift addition that caused the divergence. See
  "ACT = OSAURUS IS THE CHAT" + "NO ADDED TERMS". Build it as the chat, not behind a switch.]**
These are the next heavy-backlog items per NEVER-IDLE — build them incrementally to green, commit each.

## 🔴🔴 P0 REGRESSION — reasoning-model output broken in LIVE chat (owner 2026-06-21)
**Owner: EVERY query to ANY model fails.** Screenshot evidence (model = **VibeThinker 3B (Reasoning) GGUF**):
1. **Chat answer = "I'm sorry, but I can't assist with that request"** on every query (universal refusal).
2. **Chat TITLE = raw `<think>The user asks: "Generate a very short title (2-6 words)…"`** — the title-gen
   META-PROMPT + the model's `<think>` reasoning are LEAKING as the title.
**ROOT-CAUSE HYPOTHESIS (grounded):** the **reasoning-model `<think>` block handling is broken across chat** —
the parser isn't stripping `<think>…</think>` / not extracting the real final answer, so (a) titles dump the
raw think+prompt, and (b) the actual answer is lost → a canned "can't assist" surfaces. Reasoning models
(VibeThinker GGUF) emit `<think>…</think>` then the answer; that split is being mishandled.
**LIKELY SOURCE (the agent MUST find which):** this is the FLAG-OFF live path (`EPISTEMOS_ACT_OSAURUS_V0` off),
so a NON-gated recent change regressed it — prime suspects: (a) the **dual-MLX → vmlx-swift consolidation**
changed GGUF generation/tokenization/stop-handling for reasoning models; (b) the **act-routing / TriageService
injection was NOT truly flag-off-byte-identical** (a real regression slipped in despite the claim). Either way
it VIOLATES "no regression to live chat / flag-off = byte-identical."
**FIX + HARDEN (P0, preempts):**
- Restore correct reasoning-model output handling: strip/parse `<think>…</think>`, extract the real answer +
  produce a CLEAN short title (no meta-prompt, no think leak). Cover both streaming + non-streaming + title-gen.
- BISECT to the regressing commit (vmlx swap vs routing injection); prove flag-OFF is byte-identical to
  pre-change behavior.
- **REAL-STATE regression test** that WOULD HAVE CAUGHT this: a VibeThinker-GGUF (reasoning-model) query →
  asserts a real (non-refusal) answer + a clean title (no `<think>`/no meta-prompt). Add for streaming + title.
- Verify across models (not just VibeThinker) since owner says "any model."

## 🆕 THREE STANDING DIRECTIVES (owner 2026-06-21)

### 1. OWNER MESSAGES → PLAN, automatically (no raw-query reliance)
Every directive the owner sends is FOLDED INTO THIS PLAN (addendum/ledger) so the agent reads it from disk —
the owner should NOT have to relay raw prompts to the agent. The monitor captures each owner message here; the
loop RE-READS this addendum every iteration (per the loop prompt) and acts on new sections. Owner intent flows:
owner says it → captured to plan → agent reads + builds it. Standing process.

### 2. ROBUST CAUTION + AGENT SELF-VERIFICATION (don't make the owner verify)
"Steal no verifications from the owner." The agent must SELF-VERIFY user-facing features — ideally via
**computer-use** (launch the app, send a real query, READ the actual on-screen output) and/or runtime
launch-smoke + real-state tests — BEFORE claiming anything works. Specifically: after any chat/act/work change,
the agent must actually RUN it and confirm a real, correct response (NOT a refusal, NOT a `<think>`/prompt leak,
NOT a fallback). This regression (every query → "can't assist", title leaks `<think>`) MUST have a
self-verification gate that would have caught it. More robust caution around live-inference changes: treat them
as highest-risk, computer-use-verified before commit. (Builds on SS-AUTONOMOUS_VERIFY_SYSTEM.)
NOTE: the P0 regression is on ALL models (owner tested all) — it's the shared reasoning-model `<think>` path,
and it's CHAT (not act). The shared inference fix STILL matters (act uses the same path).

### 3. CHANGE — DELETE the chat FEATURE in favor of act+work (owner now authorizes; supersedes "never delete")
Owner update: the chat was always meant to be REPLACED by act; owner now wants **NO chat at all** — **delete
the chat FEATURE/surface itself** from the app, keeping ONLY the IP/logic the owner wants preserved. This is the
owner exercising the "only the OWNER authorizes deletion" clause. **SAFETY SEQUENCING (mandatory):**
(a) FIRST preserve/port the owner's IP + the specific logic to keep (system prompts, the shared inference
fixes, anything reused by act/work) — never lose it; (b) ensure ACT (+work) is a FUNCTIONAL replacement
(reskin live, P0 fixed, reachable); (c) THEN delete the chat surface/feature in favor of act+work. Do NOT
delete the chat NOW (act isn't ready + the inference fix is shared) — but the END STATE = no chat, only
act+work. Supersedes the prior "quarantine, never delete" for the SURFACE (the IP is still preserved).

## 🔴 P0 REGRESSION — CLASSIFY shared-vs-chat-only BEFORE fixing (owner 2026-06-21)
Owner question: is fixing this wasted (chat is being deleted) or is it needed by act/work? RESOLUTION — the
agent must CLASSIFY FIRST, then act, so no effort is wasted either way:
- **STEP 1 — classify the regression's location:** is the `<think>`-parsing / reasoning-output / title-gen bug
  in the SHARED inference-output layer, or in chat-SURFACE-only code?
- **LIKELY SHARED (fix it — NOT wasted):** reasoning-model `<think>` parsing + title generation are inference-
  layer, used app-wide. Note chat + Graph chat (KEPT surfaces) route through the SAME shared path (TriageService).
  ACT running local reasoning models needs the SAME parsing. So deleting chat would NOT remove the bug — act/
  work/note/graph would inherit it. → FIX the shared layer; add the real-state regression test there.
- **CHAT-SURFACE-ONLY (don't fix — just let it be deleted):** if the bug is purely in main-chat-surface code
  that act fully replaces, do NOT spend effort fixing it — it goes away with the chat-surface deletion.
- **The main chat SURFACE itself = on the deletion path** (per the act+work directive) — don't polish it; just
  don't let it block. Fix only the SHARED plumbing act/work/note/graph need. (Same principle as the Qwen
  fallback: fix shared plumbing, don't polish the dying surface.)

## 🔁 CODE MORE, BUILD LESS — verification cadence (owner 2026-06-22)
The loop is BUILD-BOUND: running full cold `xcodebuild test` for tiny changes + IDLE-BLOCKING on it ("won't
start new work while toolchain held") → burns iterations polling, no progress. FIX:
- **PRIMARY per-increment gate = FAST:** `cargo test --lib` (Rust), targeted `swift build` / single-file
  compile-check, or source-guard. **Do NOT run a full `xcodebuild test` for every small change.**
- **Heavy gates (full `xcodebuild test` + computer-use self-verify) = at CHECKPOINTS only** — a completed
  feature, a user-facing surface, or a tier boundary — NOT every commit. (Reconciles with the self-verify
  directive: computer-use self-verify is for USER-FACING features at checkpoints, not every internal change.)
- **NEVER idle-block on a running build.** If a heavy build is running, KEEP making progress on
  non-conflicting work (next slice's design, other-file edits, planning) — do NOT spend loop iterations just
  polling "still running." Build-bound waiting ≠ progress.
- **BATCH:** pack MULTIPLE increments per heavy build; build-per-tiny-change is banned. Code more, build less.
- Keep the rules: no red on main, no fake-done. But the GATE for routine increments is the FAST one; reserve
  the slow full build for checkpoints. Bias to CODING throughput.

## 🌟 FUGU = FOUNDATIONAL FEATURE — owner requirements (owner 2026-06-22)
Sakana Fugu (multi-agent orchestration LLM, OpenAI-compatible API, high benchmarks, ~$10/msg, likely closed-
source) is a DEFINITIVE, foundational part of the app — BUILD it (not optional). Research lives in
docs/research/FUGU_ORCHESTRATION_INTEGRATION_2026_06_22.md (deep research loop, cron 3d1194ea every 7 min);
ALL findings + best-do/limitations/best-combo go INTO that doc AND this plan. Requirements:
1. **MODULAR / REPLACEABLE:** add Fugu behind a CLEAN PROVIDER ABSTRACTION so it (or any orchestrator) plugs
   in/out — if it breaks or something better ships, swap it with no rewrite. No hardcoding Fugu anywhere.
2. **EXPLICIT COST in Settings:** surface the ~$10/message cost clearly in Settings (honest, cautionary) —
   the user opts in knowingly. No silent expensive calls.
3. **EASY one-time SETUP:** "just set it up" — API key + endpoint in Settings, OpenAI-compatible, then it works
   across act + work + the model picker (and via OpenCode's provider config pointing at Fugu's endpoint).
4. **CODE obtainability:** research whether Fugu's code is obtainable (likely CLOSED/hidden — note honestly);
   if closed, integrate via its API only; find open-source orchestration alternatives too.
5. **BEST-COMBO (build both):** (a) Fugu as a premium OpenAI-compatible CLOUD PROVIDER (act+work+picker), AND
   (b) Epistemos's OWN native orchestration layer (RuntimeRouter/System G — route-to-best-model-per-task = the
   Fugu pattern as owner IP, local-first, no $10/msg lock-in). The provider abstraction makes both pluggable.
6. **DEFINITELY BUILT:** treat as a foundational deliverable; capture best-things-to-do + best-limitations +
   best-combo into the research doc + plan so it's fully specced and gets built. Loop cadence = 7 min (was 2m).

## ✅ FUGU RESEARCH DONE → directive (owner 2026-06-22, grounded; full doc = FUGU_ORCHESTRATION_INTEGRATION)
VERIFIED: Fugu is real/GA, OpenAI-compatible — base `https://api.sakana.ai/v1`, `Authorization: Bearer $KEY`,
`/chat/completions` + `/responses`, models `fugu` / `fugu-ultra` / `fugu-ultra-20260615`. Closed-source
(GitHub has only a report+installer, no weights/SDK), **EU/EEA-BLOCKED (GDPR)**, routes through 3rd-party
frontier models. Benchmarks confirmed (GPQA-D 95.1, LiveCodeBench 93.2, SWE-Bench Pro 54.2; margins thin).
**PRICING CORRECTION (owner's "$10/msg" was WRONG):** it's PER-TOKEN — Ultra ~$5/1M input, $30/1M output
($0.50 cached), ~DOUBLING above 272K context ($10/$45 per 1M); **orchestration sub-agent tokens are ALSO
billed → a multi-step answer costs a MULTIPLE of one call.** Subscriptions $20/$100/$200/mo. → Settings must
disclose the REAL per-token rates + "multi-step costs a multiple," NOT a fake "$10/message."

**DECISION — BOTH, ASYMMETRIC (Fugu is a guest lane, NOT the brain):**
- **PATH A (now, ~hours, thin + cost-honest):** add Fugu as an OPT-IN premium **guest lane / provider**, NEVER
  a default. Add `ProviderPreset.fugu` (`LocalPackages/osaurus/.../ProviderPresets.swift`, reuse `.openaiLegacy`,
  no new wire type) + one line in `ProviderCatalog.swift` → picker surfaces `fugu`/`fugu-ultra` (no view edits).
  OpenCode→Fugu via `openCodeConfigJSON(...)` in `WorkOpenCodeRuntime.swift`. Keys → Keychain. EU-GATE it.
  Real per-token cost disclosed in Settings. Behind the MODULAR provider abstraction (swappable).
- **PATH B (the REAL bet = owner IP, foundational):** promote **RuntimeRouter** to LIVE (it exists but is
  observe-only/dead, gated `EPISTEMOS_RUNTIMEROUTER_LIVE_V0`; live decisions currently in Rust
  `compile_command_center_request`) + give **System G** (`agent_runtime_v2`, live orchestrator; its
  `ProviderPolicy` already has an `OpenAICompatible{base_url,model}` variant = the binding point) a NATIVE
  **Trinity-style Thinker/Worker/Verifier** loop across the local+cloud model pool = the Fugu PATTERN as
  owner IP, local-first, NO per-token orchestration tax, NO Sakana dependency. TRINITY/Conductor methods
  (Sakana's ICLR papers) are PUBLIC + re-implementable.
- **OPEN-SOURCE orchestrators to embed instead of paying Fugu:** `lm-sys/RouteLLM`, `ulab-uiuc/LLMRouter`,
  vLLM Semantic Router, `llm-use/llm-use`. 
- **HARD RULE: Fugu must NEVER be the orchestration BRAIN** (that would invert "adopt engines / layer IP / no
  per-token lock-in"). Fugu = an optional premium guest model; the BRAIN is YOUR native orchestrator.

## 🆕 FUGU "CLONE THE CODE" — honest reality + the IP path that delivers it (owner 2026-06-22)
Owner wants to take Fugu's code, clone/port it, infuse into act + work + the brain as owner IP, and expose it
as an API usable across act/work/chat. HONEST (verified): **Fugu is CLOSED-SOURCE — no weights/SDK/orchestration
code public (GitHub `sakanaai/fugu` = report + installer only). A full code clone is NOT possible.** Do NOT
fabricate a clone of code that doesn't exist.
**THE PATH THAT DELIVERS THE OWNER'S INTENT (re-implement the METHOD as IP):** Fugu's technique IS public —
Sakana's **TRINITY + Conductor** ICLR 2026 papers (the Thinker/Worker/Verifier recursive multi-model
orchestration pattern). So build Epistemos's OWN orchestrator FROM THOSE METHODS = owner IP, local-first, no
$10/msg, no Sakana dependency, fully infusable:
- **Make it the BRAIN, shared:** implement the Trinity-style orchestrator natively on RuntimeRouter/System G
  (route/plan across the local+cloud model pool per task, recursive verify/synthesize). This is the "main
  brain / IP" the owner wants — ONE orchestration layer.
- **Expose it as an internal API** (OpenAI-compatible surface, like LocalModelServer) so it's usable across
  **act + work + chat/note/graph** uniformly — same orchestrator everywhere, the convergence the owner asked.
- **Fugu the PRODUCT stays an optional guest provider** (Path A) for those who want to pay; the owner's NATIVE
  Trinity orchestrator is the default brain (Fugu NEVER the brain).
- **Deep code research (ongoing loop):** keep checking if Sakana ever opens weights/SDK; mine TRINITY/Conductor
  papers + open-source orchestrators (RouteLLM/LLMRouter/llm-use) for the re-implementation. If code ever
  becomes obtainable, re-evaluate a real clone; until then, METHOD-as-IP is the path.
RESULT = the owner's vision (orchestration infused into act+work+chat as IP + an API) via re-implementing the
published method, since the literal code is closed.

## ✅ FUGU RESEARCH CLOSED → FULLY AUTONOMOUS BUILD (owner 2026-06-22)
Owner: STOP the research loop (done — cron 3d1194ea cancelled). Research is COMPLETE — the foundational
findings + Path A + Path B design are captured in FUGU_ORCHESTRATION_INTEGRATION_2026_06_22.md (incl. §6
build-ready native-orchestrator design). NO MORE owner involvement required — the build agent AUTONOMOUSLY:
1. **Builds the native orchestrator API** (the §6 design): Thinker/Worker/Verifier/Synthesizer loop on
   System G `ProviderPolicy` + RuntimeRouter selection, exposed as ONE internal OpenAI-compatible endpoint
   (`epistemos-orchestrator`, LocalModelServer pattern) — this IS the fusion-with-IP + the API.
2. **Fuses it across act + work + chat/note/graph** (all call the one orchestrator endpoint = convergence).
3. **Adds the Fugu guest provider** (Path A: ProviderPreset.fugu + ProviderCatalog line, OpenCode via
   openCodeConfigJSON, Keychain, EU-gate, real per-token cost in Settings) — optional, NEVER the brain.
4. **Owner does NOTHING manually** — fully automated build. The ONLY thing that needs the owner is entering a
   Fugu API KEY IF they ever want the paid Fugu lane (external fact, optional); the NATIVE orchestrator needs
   no key + works local-first by default. Settings = easy "just set it up" if they opt into Fugu.
This is a foundational deliverable: build it autonomously to the real-state done bar, code-more-build-less,
no fake-done, no red on main, never delete chat. The build loop picks this up as a top item; no owner relay.

## ⏱️ FUGU SEQUENCING — foundational but NOT a queue-jump (owner 2026-06-22)
Owner clarifies: the agent jumped onto Fugu IMMEDIATELY; that was not intended. Fugu/native-orchestrator is
FOUNDATIONAL + CERTAIN but does NOT preempt the existing priority order. Correct sequence:
1. **P0 first:** the live-chat reasoning-model `<think>` regression (every query → "can't assist" / title
   leak) — highest priority.
2. **Then the current Osaurus-first walk:** act/work VISIBLE surfaces (act reskin, work TUI live, landing +
   animations), ONE-CHOKEPOINT, vault pillar, the heavy backlog — per the existing plan.
3. **Fugu/native-orchestrator = sequenced LATER but CERTAIN** (lower in order, not "deferred"/droppable) —
   build it after the act/work surfaces + P0, when the orchestrator's binding points (System G/RuntimeRouter,
   act+work) are mature. It is NOT urgent enough to interrupt the current order.
ACTION: finish the CURRENT green increment, then RESUME the regular order on the next iteration (the loop
re-reads this plan each iteration → it self-corrects; the owner need NOT interrupt). Do not abandon the
current increment mid-way (no red on main); just don't start MORE Fugu work ahead of P0 + the act/work surfaces.

## 🆕 MULTI-LoRA ROUTING repos = orchestrator PATTERN references (owner 2026-06-22)
Owner-flagged Mixture-of-LoRA-Harness + the multi-LoRA category (xlora, lorax, S-LoRA, SGLang/vLLM multi-LoRA)
= the route-to-best-ADAPTER variant of the orchestrator pattern. They are PATTERN/method REFERENCES (Python/
CUDA/SGLang — NOT MAS-Swift, so NOT clone-targets), feeding the native orchestrator's per-model/per-adapter
routing (owner IP) + the QAT/model-lab. Most MAS-aligned lead: EricLBuehler's xlora + mistral.rs (Rust). Detail
+ source ledger in FUGU_ORCHESTRATION_INTEGRATION §7. STANDING: when the owner flags new repos like this, the
agent classifies (clone vs reference per the ADOPT-vs-IP-LAYER rule) + folds into the plan; no large research
loop — bounded pass then continue the build order. The orchestrator absorbs these patterns natively.

## 🌟 trinity_coordinator = OPEN reference impl of the orchestrator method (owner 2026-06-22) — de-risks Path B
github.com/nshkrdotcom/trinity_coordinator (MIT, Elixir+Python) directly implements Sakana's TRINITY paper
(arXiv:2512.04695) — the exact method behind (closed) Fugu: Router (Qwen3-0.6B hidden states) → SVF
Coordination Head → Thinker/Worker/Verifier → provider boundary (OpenAI/Gemini) → JSONL trace. CRUCIAL: the
Sakana TRINITY router vector + SVD/SVF artifacts are OBTAINABLE via HuggingFace (SHA-256 verified) — so the
COORDINATION WEIGHTS are gettable even though Fugu's product is closed (this is the "take the code" the owner
wanted, via the open impl + published artifacts). Has an Apple-Silicon (EMLX) profile.
DIRECTIVE: this is the blueprint for the native orchestrator IP (Path B / Fugu §6 + §8). It's Elixir → NOT a
drop-in clone → PORT THE METHOD to native Swift/Rust on System G/RuntimeRouter, consume the same HF router/SVF
artifacts, Thinker/Worker/Verifier over the local+cloud pool, JSONL trace = honest provenance. Build agent:
read trinity_coordinator + arXiv:2512.04695 for the exact router/SVF mechanics before porting. Foundational +
certain (sequenced after P0 + act/work surfaces per the Fugu sequencing). Fugu-the-API stays optional guest.

## 🌟🌟 TRINITY = COMPLETE CLONE + FULLY ADDED (owner 2026-06-22) — foundational orchestrator brain
Owner: deeply research, COMPLETELY clone, and COMPLETELY add trinity_coordinator to the app. Maximal honest
interpretation (Elixir/BEAM can't run in-process MAS-Swift → no literal binary clone; do the MAXIMAL version):
1. **VENDOR THE ENTIRE REPO in-tree** (github.com/nshkrdotcom/trinity_coordinator, MIT) — zero cherry-pick,
   full source + LICENSE, like the Osaurus vendor — as the reference source of truth in LocalPackages/ or
   vendor/.
2. **COMPLETELY PORT THE WHOLE METHOD to native Swift/Rust** (System G/RuntimeRouter) — EVERY component, not a
   subset: Router (Qwen3-0.6B hidden-state extraction) → SVF Coordination Head (singular-value fine-tuned
   adapter → role) → Thinker/Worker/Verifier role split → Provider Boundary (local+cloud pool) → JSONL trace
   (honest provenance). Full parity with the Elixir/Python reference + arXiv:2512.04695.
3. **BUNDLE THE REAL SAKANA ARTIFACTS** — download the pretrained router vector + SVD/SVF components from
   HuggingFace (SHA-256 verified, the same artifacts the repo consumes); ship them in-app (vendor/download-on-
   first-use per the runtime rule). These ARE the coordination weights = the closest to "taking the code."
4. **FULLY ADD across the app** — wire the ported orchestrator as the shared brain + internal OpenAI-compat API
   (epistemos-orchestrator) used by act + work + chat/note/graph. = the convergence the owner wants.
5. **DEEP RESEARCH FIRST:** exhaustively map the repo (router/SVF mechanics, role-split logic, provider
   boundary, trace format, EMLX/Apple-Silicon profile, Nx/EXLA/Bumblebee deps) + read arXiv:2512.04695, BEFORE
   porting — so the port is faithful + complete, not approximate. Document the full mechanics in the research doc.
This is the native orchestrator IP (Path B) realized via a COMPLETE port of the open TRINITY impl + the real
artifacts. Foundational + certain. Sequenced after P0 + act/work visible surfaces (per Fugu sequencing), but
it IS getting fully built. code-more-build-less, no fake-done, no red on main.

## 🆕 SYSTEM-PROMPTS LIBRARY — clone + per-model prompt engineering (owner 2026-06-22)
Owner: clone github.com/asgeirtj/system_prompts_leaks + use their system prompts for all the models in the app.
VERIFIED: 44.7k★, **CC0-1.0 (public domain) → unrestricted reuse, legally clean to copy/adapt**. Contains
system prompts for Claude (Fable 5/Opus 4.8/Code/Design/Sonnet), GPT-5.5/5.4/Codex/o-series, Gemini, Grok,
Cursor, Copilot, Perplexity, Qwen, Mistral, Notion, etc., organized by provider.
DIRECTIVE:
1. **VENDOR the repo** in-tree (CC0 — keep the notice) as a reference prompt library (e.g. vendor/system-prompts/).
2. **PER-MODEL PROMPT ENGINEERING (owner IP play):** use these as the high-quality STARTING POINT for each
   model's system prompt in the app's model lab / "Epistemos Picks" — wire a per-model system prompt to each
   local + cloud model (Gemma/Qwen/VibeThinker/Claude/GPT/etc.) so every model is engineered to perform well in
   Epistemos. This is the "custom bespoke per-model engineering" the owner wanted.
3. **ADAPT, don't blind-paste (honest):** these prompts reference the SOURCE products' own tools/identity — mine
   + ADAPT them to Epistemos (its tools, act/work modes, honesty rules), per model. Curated, not verbatim.
4. **Modular:** a per-model prompt registry (data-driven) so prompts are editable + swappable as models/leaks
   update. Ties to the per-model SS-Z/AA/AB profiles + the orchestrator (each pool model carries its tuned prompt).
Foundational for model quality; sequenced with the model-lab / per-model work. CC0 license preserved.

## ✅ TRINITY PORT SPEC DONE → directive + 2 blockers (owner 2026-06-22; full = TRINITY_COORDINATOR_PORT_SPEC)
Deep research complete. Faithful native port is FEASIBLE — largely additive over System G/RuntimeRouter/MLX.
PORT TARGET = the Elixir repo's REAL mechanics (paper 2512.04695 = conceptual frame only; it omits SVF
equations + HF URL — do NOT fabricate paper equations). Verified mechanics to port:
- **Router:** Qwen3-0.6B, penultimate-token (-2) hidden state {1,1024}, output_hidden_states.
- **Coordination head:** biasless linear 1024→10 (7 agent + 3 role logits; 0=Worker,1=Thinker,2=Verifier).
- **SVF:** AVOIDED at runtime — adapted weights are PRE-MATERIALIZED safetensors on HF → BUNDLE pre-adapted
  tensors, skip runtime SVD (major de-risk; MLXLinalg.svd exists if ever needed).
- **Loop:** flat ≤5-turn Thinker/Worker/Verifier (NOT recursive); terminate on Verifier "ACCEPT"; budgets.
- **Provider boundary:** OpenAI-compat /chat/completions, Bearer, no streaming, 7-agent pool.
- **Trace:** JSONL schema_version:1, 8 event types → wire to TraceCollector.swift (honest provenance).
- **Epistemos targets (verified):** loop→agent_core/src/agent_runtime_v2/ (System G); selection→RuntimeRouter.swift;
  providers→Rust OpenAICompatibleProvider + Swift LLMService; router math→MLX/vmlx-swift; trace→TraceCollector.
**ARTIFACTS (verified downloadable):** `nshkrdotcom/trinity-coordinator-adapted-qwen3-0.6b` (HF dataset, ~654MB,
SHA-256 cross-checked) + base `Qwen/Qwen3-0.6B` (Apache-2.0, ~1.5GB). Add Qwen3-0.6B as a router-model slot.
**🚧 BLOCKER 1 (build, must-prove-FIRST):** NO hidden-state/activation extraction exists in the MLX stack
(generation-only) — the penultimate-token tap must be built NET-NEW on mlx-swift (highest risk). Prove with
golden-vector parity tests (bf16/transpose/layer-index/margins) BEFORE relying on it.
**🚧 BLOCKER 2 (LICENSE, owner-actionable):** the adapted-weights HF bundle has NO declared license → CANNOT
SHIP until cleared. ACTION: contact the author (nshkrdotcom) to confirm a license, OR re-generate the adapted
weights ourselves from base Qwen3-0.6B + the method (training code was removed, so this = re-derive), OR ship
the orchestrator LOOP without the learned router (heuristic routing) until cleared. Owner decision needed on H1.
**OPEN Qs:** exact extraction layer (final vs layer-26), decision rule (argmax vs sampling), 7th pool model,
9216-vs-19456 z-vector (read HF manifest.json at build). Build order: prove the MLX hidden-state tap → head →
loop/roles/providers/trace → bundle artifacts (license-gated) → wire across act/work/chat. Sequenced after
P0 + act/work surfaces; foundational + certain.

## ✅ TRINITY BUILD PATH — heuristic-route FIRST, learned router when license clears (owner 2026-06-22)
DEFAULT (unblocked, build now): build the orchestrator LOOP + roles + providers + trace immediately, using
HEURISTIC routing (complexity/code/reasoning tags via the existing RuntimeRouter selection) instead of the
learned coordination head. This delivers the full Thinker/Worker/Verifier orchestrator (the owner IP brain +
internal API across act/work/chat) WITHOUT waiting on the license or the hardest MLX work.
SEQUENCED INSIDE THIS:
1. **Now (unblocked):** flat ≤5-turn Thinker/Worker/Verifier loop on System G (agent_runtime_v2) + heuristic
   model selection (RuntimeRouter tags) + OpenAI-compat provider boundary + JSONL trace (TraceCollector) +
   expose as the internal orchestrator API across act/work/chat. Real-state tested.
2. **In parallel (build, must-prove-first):** the net-new MLX penultimate-token hidden-state TAP + golden-vector
   parity tests. When proven, add the biasless 1024→10 coordination head.
3. **Gated on LICENSE (owner-action H1):** bundling `nshkrdotcom/trinity-coordinator-adapted-qwen3-0.6b`
   (no declared license) → DO NOT SHIP the adapted weights until cleared. The LEARNED router drops in (replaces
   heuristic) ONLY after license clearance OR self-re-derivation from base Qwen3-0.6B (Apache-2.0).
OWNER-ACTION (tracked, not blocking the build): clear the adapted-weights license with the author
(nshkrdotcom) — until then, heuristic routing ships + the learned head is staged. Add to ledger as an owner
TODO. This keeps the foundational orchestrator MOVING (no license/MLX-tap block) while the learned router is a
clean drop-in upgrade later. No fake-done; heuristic vs learned router state disclosed honestly.

## 🆕 HOLISTIC UNIFICATION MAP — where does EVERYTHING land? (owner 2026-06-22)
Broaden the architecture-unification research (ARCHITECTURE_UNIFICATION_SYSTEMG_2026_06_22.md) into a HOLISTIC
map of how ALL the pieces relate + whether to unify — WITHOUT forcing unification where it's not beneficial.
Cover, beyond System G / agent_loop / agent_runtime / agent_core / IP brain:
- **TRINITY orchestrator** (the new native orchestrator brain) — does it BECOME the unifying layer, or sit beside?
- **Fugu** (guest provider) — where it lands relative to the orchestrator (a pool member, not the brain).
- **System-prompts library** (per-model prompt engineering) — how per-model prompts attach to the model pool /
  orchestrator / each engine.
- **OLDER logic / tech-debt tangential to System G + agents** — legacy loops, orphaned modules, observe-only
  gated code (RuntimeRouter), dead paths — what to MERGE, KEEP-SEPARATE, or DELETE.
- **The new orchestration layers** + the ONE-INFERENCE-CHOKEPOINT directive — how they reconcile.
VERDICT REQUIRED (per component): UNIFY (beneficial + clearly so), KEEP-SEPARATE (legitimately distinct —
don't force), or DELETE (dead). Produce the TARGET unified architecture (one brain on top + swappable engines +
the orchestrator as the coordination layer + one inference chokepoint), but ONLY unify what's genuinely better
unified. If beneficial → it gets BUILT (folded into the plan as a careful additive refactor, sequenced after
P0 + act/work). PRINCIPLE: unify where it removes drift/duplication (the source of the Qwen/codex/think bugs);
keep separate where the separation is real (cloud loop vs local loop vs orchestrator); delete dead weight.

## ✅ UNIFICATION VERDICT — LAYERS not rivals; UNIFY mostly (owner 2026-06-22; full=ARCHITECTURE_UNIFICATION_SYSTEMG)
Grounded (file:line cited). "agent_core vs System G vs agent_loop" was a category error — agent_core is the
CRATE; the rest are MODULES inside it, arranged as LAYERS. Verdict + holistic landing of ALL pieces:
- **MERGE / UNIFY (beneficial, build it):**
  - **Orchestration = System G is the ONE orchestrator of record** (`agent_runtime_v2`; today a deterministic
    3-event stub, MAS-Disabled) → grow it into the real loop.
  - **TRINITY loop (`trinity_loop.rs`, defined+unit-tested, invoked NOWHERE) = wire in as System G's coordinator
    core** (the native orchestrator brain). Fugu = a pool member UNDER it, never the brain.
  - **RuntimeRouter (built-but-dead, observe-only) = promote to the ONE router** (staged behind its flag).
  - **Converge the two LIVE local chokepoints** (`LocalAgentLoop.liveLoop` + `TriageService.localStream`) = the
    one-inference-chokepoint directive.
  - **UNIFY THE IP BRAIN onto ONE attach point (the real prize).** Per-model SYSTEM-PROMPTS attach to the
    pool/orchestrator here too.
- **KEEP SEPARATE (legitimate, do NOT force-merge):** `agent_loop.rs` (CLOUD engine, local-rejecting) +
  `LocalAgentLoop` (LOCAL engine) stay as TWO swappable lanes UNDER System G — the honest-capability gate
  depends on the split. `agent_runtime/` stays the shared support lib (prompt-format/tool-parse/skills).
- **DELETE / FIX (dead weight + a real FAKE-GREEN):**
  - `confidence_floor.rs` = fully orphaned (0 consumers) → resurrect-or-delete.
  - `ConfidenceRouter` = test-only legacy → delete/fold.
  - 🔴 **`eidos.query` LIVE tool BYPASSES the real `eidos/` module** (hits VaultBackend → "Eidos-in-name-only",
    `tools/knowledge.rs:244`) → route through the real eidos/ OR rename honestly. (A genuine fake-green — owner
    cares: it claims Eidos but isn't.)
  - Wire the orphaned citation/provenance gate (never written by a running agent); fix STALE CLAUDE.md
    (macaroons NOT orphaned; dispatch registers caps at init not first-use).
TARGET = one orchestrator (System G) + TRINITY coordinator core + one brain attach-point + one router + one
inference chokepoint + two swappable engine-lanes (cloud/local) under it. = exactly the existing plan direction
(FUGU §6 own-Fugu-local-first, ADOPT-vs-IP, TRINITY port). SEQUENCING (conservative, additive, after P0 +
act/work surfaces): docs/dead-code fixes → TRINITY slice 2 → staged RuntimeRouter promotion → local-chokepoint
convergence → brain unify. Per-component PLAN ADDITIONS UNIFY-0..6 + 6 open Qs in the doc. Build the beneficial
unifications; never force; honest no-fake-green (esp. fix eidos.query).

## 🌟 THE BIG IDEA / GRAND CONVERGENCE (owner 2026-06-22) — the single unifying picture
Full synthesis: docs/research/THE_BIG_IDEA_GRAND_CONVERGENCE_2026_06_22.md. Summary:
- **ONE brain, TWO faculties, on ONE substrate, driving SWAPPABLE engines, via TWO modes.** Faculty 1 =
  COORDINATION (System G + TRINITY loop + RuntimeRouter = the "own Fugu, local-first" orchestrator). Faculty 2
  = KNOWLEDGE/MEMORY (the IP brain: Eidos/recall + cognitive DAG + provenance + honesty + per-model prompts).
  Both attach at ONE point on the model-agnostic substrate. Engines (act=Osaurus, work=OpenCode, cloud, local,
  MLX) are swappable muscles, kept separate on purpose. Modes = act + work over the md PKM (Prose+MD-V2) +
  graph + agent-native vault.
- **NOT two rival brains** — two faculties of one. The convergence = unify them onto a single orchestrator +
  single router + single brain attach-point + single inference chokepoint (kills the drift that caused the
  Qwen/codex/<think> bugs).
- **70B / custom-runtime / new-model brain-1 = SEPARATE FUTURE TRACK** (off-limits now; a potential future
  pool-lane you'd OWN, not the architecture). OPEN OWNER DECISION: if/when it re-enters scope. Slot reserved;
  not blocking.
- **"Eidos only worked once" = a real bug, in the plan:** live eidos.query bypasses the real eidos/ module +
  the retriever is gated/fixture-seeded → finalize via the brain-unification step. Tracked.
- **ALL FOLDED + no conflict.** Gaps = (1) 70B re-entry (owner decision), (2) Eidos truly-live (build, tracked),
  (3) TRINITY license (heuristic-first, tracked). No IP missing — brain/editors/graph/model-lab/motion/vault/
  orchestrator-as-IP all captured as IP-LAYER. The plan KNOWS it converges to ONE thing.

## ✅ CORRECTION — 70B / custom-runtime / new-model brain-1 = STAYS OUT, PERIOD (owner 2026-06-22)
Owner: the 70B (and the from-scratch new-model brain-1 / custom runtime) is an OLD thing — keep it OUT, NOT
part of the architecture, NOT a future track, NO reserved slot, NOT an open decision to revisit. Supersedes the
big-idea doc's "separate future track / slot reserved / open owner decision" framing — there is NO 70B slot
and NO re-entry plan. It remains HARD OFF-LIMITS and EXCLUDED from the convergence entirely. The architecture
is model-agnostic over EXISTING models (local Gemma/Qwen/VibeThinker + cloud + optional Fugu) — full stop.
Do NOT design for, reserve space for, or surface the 70B/new-model anywhere. (GAP 1 in the big-idea audit is
CLOSED: not a decision — it's simply excluded.)

## 🌟🔁 GRAND UNIFICATION SWEEP — multi-cycle, encompasses Helios archaeology (owner 2026-06-22)
Owner: run the SAME deep-unification process as the first architecture unification, but BIGGER + MULTI-CYCLE —
it SUPERSEDES/encompasses the Helios-era IP archaeology. Do NOT stop after 1-2 passes; run cycle after cycle
until a cycle finds NOTHING NEW. Goal: locate + classify + UNIFY all the owner's local research IP into the
current architecture (System G / the brain / substrate), keeping only what's useful + relevant.
CORPUS TO SWEEP (the owner's local research — go as far back as USEFUL, not needlessly far):
- **docs/fusion/** (the primary local-research corpus — most of the IP).
- **Dual-brain** docs (the most up-to-date PRUNING of the architecture — the best baseline).
- **Lattice explainer** docs + **living index** docs (large CHRONICLE documents tracking the build over time).
- Helios v1->v6 / scope_rex / Epistemos 6.x / substrate (the HELIOS_ERA_IP_ARCHAEOLOGY findings fold in here).
CLASSIFY each finding: **USEFUL+RELEVANT (unify/harden/infuse)** vs **SUPERSEDED (already absorbed into today's
substrate — note where)** vs **TOO-THEORETICAL/DROP (research-only, never going to build)** vs **70B-TIED
(EXCLUDED)**. Beneficial + finishable + additive-safe (won't break the hardened clones) → fold into the plan as
build items, attached to System G/the one-brain/substrate, sequenced after P0+act/work.
PROCESS (multi-cycle, like the first unification): each cycle sweeps a region of the corpus + accumulates into
a GROWING doc (docs/research/GRAND_UNIFICATION_SWEEP_2026_06_22.md); next cycle covers what's left + cross-checks;
keep going until a cycle surfaces nothing new (convergence). Each cycle: cite paths, verified-vs-inferred, no
fabrication. This is the definitive "where did ALL my IP land + what gets unified" map. Runs as a self-paced
loop until exhausted; findings continuously folded into the plan.

## ✅ HELIOS-ERA IP — FOUND, nothing lost; salvage list (owner 2026-06-22; full=HELIOS_ERA_IP_ARCHAEOLOGY)
GOOD NEWS (all verified on disk): the Helios/substrate IP is NOT gone — it split into 3 buckets: (a) PROMOTED-
LIVE into agent_core/, (b) PRESERVED in the gated epistemos-research/ crate by design, (c) canon docs in
docs/fusion/. Key live pieces: **scope_rex LIVE** (agent_core/src/scope_rex/ — AnswerPacket/Residency/Semantic-
BTM/Active-Support-Atlas/witnessed_state/admission_proof, FFI-bridged); **SCOPE-Rex resonance gate LIVE** (all
7 facets τπλ/δρ/κη + Swift ResonanceService + FFI); substrate LIVE (wbo6 master inequality, uas/ACS, ShmPool L0,
InterruptScoreCpu). Deeper doctrine (theorems, L1-L4 tiers, planes, CMS-X, M2-Max kernels) preserved behind
`--features research` with drift-gates. No code deleted; Helios docs reclassified legacy/witness; recoverable
via `git log --all | grep helios`.
SUPERSEDED/RETIRED (not drifted-lost): 70B abandoned at helios v2 (pivot to residual-first small/mid MLX
models — the owner's hard-exclusion just finalizes a decision research already made); "dual-brain" = 3 meanings:
70B-pair (EXCLUDED), GPU/ANE DualBrainRouter (ORPHANED/RETIRED, AppBootstrap:2291 — do NOT resurrect, fold its
routing intent into RuntimeRouter then delete), current = two FACULTIES of one brain (the live concept).
SALVAGE (beneficial, ADDITIVE, 70B-FREE — fold as build items, after P0+act/work):
1. **Wire the REAL eidos/ retriever into the run** (the "worked once" bug — eidos.query bypasses it) = the
   knowledge-brain prize.
2. **Drive provenance ClaimLedger from the run** (currently observe-only/CLI).
3. **Resurrect confidence_floor.rs** (orphaned owner IP) as the honesty-gate scalar.
4. **Harden the live AnswerPacket/Residency/Witnessed-State + wbo6 invariant sampling.**
5. **Promote six-tier memory L1 over ShmPool L0** (model-agnostic eviction).
6. **Use Swift InterruptScoreCpu as a live escalation/recall-wake** for RuntimeRouter/System G.
7. **Align HardwareTierManager to the M2-Pro-16GB doctrine ceiling** (~0-1 commit).
EXCLUDED salvage (70B/new-model/training-dependent): M2-Max SSM GPU kernels, PCF model-surgery, donor
distillation/SEAL-DoRA/LearningMode, Lane-4 Julia oracle, the 70B dual-brain pair. NOTE: substrate-core/
substrate-rt crates are LIVE but NOT Helios (the zero-copy perf carve-out). OPEN: iCloud R0 theorem archive
lives outside the repo — owner to confirm. The GRAND UNIFICATION SWEEP cycles continue + cross-check this.

## 🔨 BUILD-IT-HARDENED + GO-BACK-AND-UNIFY (owner 2026-06-22) — no-compromise hard gates
Once research folds in, the agent MUST actually BUILD it — deliberate, HARDENED, no-compromise hard-gates
engineering (real-state tests, no fake-done, additive-safe so it never breaks the hardened clones). The agent
already STARTED TRINITY + System G BEFORE the 2nd unification + the Helios/grand-sweep findings — so it must GO
BACK, deliberate, HARDEN, and UNIFY those in-flight pieces with the new verdict (don't leave half-built/
pre-unification work). Standing build mandate:
1. **Finish leftover ARCHITECTURE GAPS + EASY WINS** (the salvage items, the unification UNIFY-0..6, the Eidos
   wiring, confidence_floor, provenance-live) — code them, hardened.
2. **Unify DEEPER** — one orchestrator (System G) + TRINITY core + one router + ONE brain attach-point + one
   inference chokepoint; reconcile the already-started TRINITY/System G code with the unification verdict.
3. **Use the owner's IP in the MOST IMPORTANT PLACES** — the knowledge brain (real Eidos/recall, provenance,
   honesty), scope_rex/resonance, the salvaged substrate — infused at the core, not bolted on.
4. **HARDEN before integrating** (owner: can't add unfinished work to hardened clones) — each salvaged/unified
   piece is finished + real-state-tested + additive BEFORE it touches the live/clone path.

## 🆕 EXTERNAL RESEARCH CORPUS — ~/Downloads (owner permission 2026-06-22)
Owner GRANTS permission to research OUTSIDE the repo, in /Users/jojo/Downloads. The Helios-era SOURCE docs live
here (loose, top-level): `helios v6.2.md`, `helios v5 first.md`/`v5 updated.md`/`v5.md`, `helios v4 updated.md`,
`EPISTEMOS_HELIOS_v4_1_AMENDMENTS.md`, `Helios third .md`, `EPISTEMOS_GRAND_MASTER_v3.md`,
`EPISTEMOS_FINAL_SEVEN_THEOREMS.md` + `_v2_HARDENED.md`, `EPISTEMOS_V6_1_FINAL_SYNTHESIS_LOCK.md`,
`deep-research-report (6).md`/`(7).md`, `compass_artifact_*.md`, `Pasted markdown (1/3/4).md`. Also sibling
dirs: `Epistemos-cursor/` (another working copy), `openclaw-main/`, `AETHERLINK_APPLICATION_KIT_FULL/`. The
GRAND UNIFICATION SWEEP MUST INCLUDE this ~/Downloads corpus (it's the original Helios v1->v6 + seven-theorems
source the in-repo docs were derived from) — read-only for research; classify useful/superseded/too-theoretical/
70B-excluded; salvage beneficial IP into the plan. (Pixel-art font/theme dirs in Downloads = asset refs for the
pixel-art UI, note but lower priority.) Do NOT modify anything outside the repo; research/copy-in only.

## ✅ GRAND SWEEP CYCLE 1 — salvage GUS-1..5 (owner 2026-06-22; full=GRAND_UNIFICATION_SWEEP)
Baseline = dual-brain readout (docs/fusion/ARCHITECTURE_READOUT_2026_06_20.md, newest). KEY CUT under the
70B-exclusion: **BRAIN-1 (Mamba-3 spine, signal_bus, M0/M1 interrupt, ternary runtime, Engram, KIVI-KV,
residency) = 70B-TIED → EXCLUDED**; **BRAIN-2 (authority/deliberation) = already today's Faculty-2** (absorbed).
So the dual-brain half splits cleanly: model=excluded, app=the substrate. Living-index (8,587-line chronicle)
+ lattice-explainer HTML = chronicle/aspirational, NOT live IP; the "living" capability already exists as
Halo/Shadow + Cognitive DAG (SUPERSEDED); concept-lattice/FCA engine = TOO-THEORETICAL/drop.
USEFUL+RELEVANT salvage (additive-safe, attach to System G/brain/substrate, behind existing gates):
- **GUS-1:** bounded read-only "Living Index status" panel (finite; surfaces what's already living).
- **GUS-2:** EML/Belnap verification primitives (live under --features research) → wire as the AnswerPacket
  honesty/abstain gate.
- **GUS-3:** TurboVec as Eidos retrieval-compression backend (Pro-gated).
- **GUS-4:** UAS/ACS substrate hardening (code-must-match-doc).
- **GUS-5 / = UNIFY-4/5 prize:** Cognitive DAG + real Eidos recall + provenance ledger (the knowledge brain).
DROP (not IP / theoretical): AetherLink/Erdos/Lean intake, concept-lattice engine, the chronicle docs, all
CODEX/KIMI/WORKTREE process docs. Cycle 2 regions: MASTER_RESEARCH_INDEX (474KB) + 22-pass ledger + June-1
residency quartet + T10 doctrines + ~1,340 untouched docs/fusion/ subdir files (salvage//jordan's research//
pasted/ = likely IP-bearing) + per-module agent_core/src/research/ (~40 modules, 70B-tied vs app-verification)
+ epistemos-research crate + Helios theorem catalog (E1-E7/H1-H17/PCF-1-10) + the ~/Downloads Helios source
corpus + convergence re-check.

## ✅ GRAND SWEEP CYCLE 2 — salvage GUS-6..18 (owner 2026-06-22; full=GRAND_UNIFICATION_SWEEP §Cycle 2)
NET-NEW salvage cluster found (additive-safe, app-side, EXCLUDING 70B). Highest-value = docs/fusion/salvage/
from-vigorous-goldberg/agent_core_src/ (predates the Hermes purge — DEDUP vs live agent_core/ in cycle 3):
- **GUS-6** Intent→Effect typed apply w/ pre-computed inverse. **GUS-7** signed Ed25519 ExecutionReceipt (beside
  ClaimLedger; receipts≠retraction). **GUS-8** universal ⌘Z undo log. **GUS-9** NightBrain idle scheduler shell.
  **GUS-10** skill discovery/promotion. **GUS-11** deterministic concept canonicalizer. **GUS-12** self-heal +
  circuit-breaker. **GUS-13** typed 4-variant router.
- governance docs (model-agnostic): **GUS-14** Overseer/Agent-Hierarchy policy, **GUS-15** Adaptation-Subsystem
  governance, **GUS-16** Compute-Steering policy.
- **GUS-17** Four-gate tool-adoption discipline (~/Downloads/EPISTEMOS_HELIOS_v4_1_AMENDMENTS.md §A3.3 —
  grep-verified ABSENT in repo = net-new app-side process IP).
- **GUS-18 doc-fix:** H8 "4-of-9 OSPC mirrors live" canon claim NOT backed by dispatch.rs → mark H8 theoretical.
CODE CONFIRMATIONS: agent_core/src/research/ ~40 modules — ~13 EXCLUDED (mamba3/rwkv7/scan_ir/ternary/
sherry_lattice/koopman/interrupt/m0/nano_training/continual_learning = brain-1 spine), ~16 USEFUL (mostly cycle-1
organs + new: substrate_independence, run_ledger token-attestation, info_ir KL, hyperdynamic_schemas); whole tree
behind --features research. epistemos-research/ = Helios V5 Lane-3 preservation crate (theorems+vpd salvageable;
ternary/donor/engram/kv EXCLUDED) — no new salvage. THEOREMS: 10 live invariants (E3/E4/E5/E7/H1/H2/H3/H17/PCF-6/9)
already SUPERSEDED into the verification layer (=GUS-2/UNIFY-6); EXCLUDED H10 + PCF-5/6/9/10 (vault model-surgery;
PCF-9 produces a model file). SUPERSEDED/DROP: ~566 deliberation/oversight/fleet/process files; pasted/ +
jordan's-research GPT/kimi = 70B-EXCLUDED. ~/Downloads: Helios v3→v6.2 already absorbed verbatim in-repo
(SUPERSEDED) — only GUS-17 net-new; Epistemos-cursor/=absorption target, openclaw-main/=3rd-party, AETHERLINK=
triaged. NEAR CONVERGENCE — cycle 3 = confirmation: dedup GUS-6..13 vs live agent_core/, spot-check ~/Downloads
Pasted markdown(N), glance 58 SS-* slices, confirm epistemos-vault/ fully EXCLUDED. If goldberg modules already
shipped + residuals empty → CONVERGED.

## ✅ DUAL-BRAIN CLARIFICATION — APP SIDE ONLY, never the model side (owner 2026-06-22)
Owner, explicit: from the dual-brain architecture take ONLY the **APP-SIDE architecture = BRAIN-2**
(authority / deliberation / decision / governance — the app's "deciding" half). Do NOT take the **MODEL SIDE
= BRAIN-1** (the new from-scratch model: Mamba-3 spine, signal_bus, M0/M1 interrupt, ternary model-runtime,
Engram, KIVI-KV, residency, 70B) — that is EXCLUDED, full stop (same as the 70B exclusion). This CONFIRMS the
grand-sweep cycle-1 cut (BRAIN-1 = 70B-tied = EXCLUDED; BRAIN-2 = already today's Faculty-2). So: salvage +
unify the dual-brain's APP-SIDE deliberation/authority architecture into System G / the Coordination faculty;
NEVER the model-side spine. Any salvage item that turns out to depend on the new model = EXCLUDED. The app's
"brain" is its deliberation/orchestration over EXISTING models — not a built-from-scratch model. Standing,
no ambiguity.

## 🏁 GRAND UNIFICATION SWEEP — COMPLETE / CONVERGED (owner 2026-06-22)
Cycle 3 = CONVERGENCE confirmed. KEY RESULT: **GUS-6..13 are ~90% ALREADY SHIPPED LIVE** in agent_core/src/
(goldberg dirs effect/ undo/ nightbrain/ canon/ heal/ route/ skill_discovery/ exist 1:1, unconditionally
compiled, tested). Cycle-2's "un-promoted" guess REFUTED by live code. DOWNGRADE to SUPERSEDED/DONE:
- GUS-6 Intent→Effect (effect/dispatcher.rs:47, tested), GUS-9 NightBrain (live+FFI+13 tests), GUS-11
  canonicalizer (canon/mod.rs:27), GUS-12 self-heal (heal/breaker.rs = re-export, no dup, 16 tests),
  GUS-13 router (richer than stub, 15 tests). = already built.
**THE ONLY REAL BUILD WORK (3 tiny additive wirings, app-side, inside already-shipped modules):**
- **GUS-7:** ExecutionReceipt signs with HMAC-SHA256 → add ONE Keychain-backed **Ed25519** impl (SigningKey
  seam already correct) for public verifiability.
- **GUS-8:** undo log built+tested (undo_events.sqlite, 24h TTL, inverse col) but NOT runtime-wired → hook ⌘Z
  into the apply path (add the production caller).
- **GUS-10:** skill_discovery built+tested but only test/bridge-driven → invoke the promote path from the live
  agent loop.
Plus the still-open GUS-1..5 / 14..18 (living-index panel, EML honesty gate, TurboVec, UAS/ACS harden,
governance specs, 4-gate tool-adoption, H8 doc-fix) + the UNIFY-0..6 (one orchestrator/router/brain/chokepoint
+ real Eidos wiring + provenance-live + confidence_floor) + the 7 Helios salvage items. ALL app-side,
additive-safe, behind existing gates, EXCLUDING the model side.
CONFIRMED EXCLUDED (no app spillover): epistemos-vault/ (Lane-5 model-surgery, all #[cfg(vault)], PCF-9 makes a
NEW model file), the brain-1 spine, the 70B. Pasted-markdown + 72 SS-* slices = no net-new IP (all superseded
or already in the 194-item ledger). 
**WHERE ALL THE IP LANDED (final):** (1) MODEL half = excluded/fenced (Cursor + research/vault crates),
(2) APP "brain-2" half = the LIVE substrate (mostly already shipped), (3) the remainder = a SHORT enumerated
safe tail (3 wirings + the GUS/UNIFY/Helios panels & hardening). The build agent builds that tail, hardened,
after P0 + act/work. NO further research cycles — the sweep is DONE.

## 🔴🔴 ACT = OSAURUS IS THE CHAT — NO TOGGLE, NO REUSE-OLD-CHATVIEW (owner 2026-06-22) — SUPERSEDES §29/§222/§806
Owner (emphatic): ACT must BE the Osaurus chat surface itself — the FULL Osaurus UI CLONE, reskinned to the
Epistemos theme — NOT the old Epistemos ChatView with an Osaurus engine behind an opt-in toggle. There is NO
on/off switch (it's literally the chat, not optional). Delete the old chat — owner does NOT need it and does
NOT want a scaffold/temporary hold. "Delete the shit and clone it." VERIFIED divergence: toggle "Use Osaurus
for Act (experimental)" exists (ActOsaurusHealthRow.swift:39), gate defaults OFF (ActOsaurusGateStatus), RootView.swift:2634
still mounts Epistemos `ChatView()`, and the real Osaurus UI (LocalPackages/osaurus/.../Views/, 220 files incl.
Chat/ChatView.swift) is vendored but UNWIRED.

### THIS SUPERSEDES (resolve the conflict — these were wrong/outdated for the product):
- **§806 (the in-app toggle)** — was TEMPORARY testability scaffolding; it OUTLIVED its purpose. REMOVE it.
  Osaurus is the default chat (Pro), NO owner-facing on/off. (A hidden Diagnostics-only override is the most
  that may remain — not a product toggle.)
- **§29 surface-wiring "reuse the proven Epistemos chat front-end as act's UI"** — WRONG for the product. ACT
  mounts the OSAURUS UI clone, not the old ChatView.
- **§222 reskin "current Epistemos chat UI wins, add Osaurus underneath"** — REFRAME: mount the OSAURUS
  ChatView and RESKIN IT to the Epistemos look/discipline (cream palette, monospace bubble, model picker w/
  logos, etc. — keep the AESTHETIC the owner loves) — but it's the OSAURUS surface/code, not the Epistemos
  ChatView with an engine swap.

### THE BUILD (the real thing — replaces the toggle/engine-swap path):
1. **MOUNT the Osaurus chat UI as THE chat surface** — host LocalPackages/osaurus/.../Views/Chat/ChatView.swift
   (+ composer/thread/ModelPickerView) with EpistemosTheme injection; RootView routes act → the Osaurus host,
   NOT `ChatView()`. Port "Epistemos Picks" into Osaurus's ModelPickerView; bridge sessions/vault/Eidos/provenance.
2. **REMOVE the toggle** — Osaurus default-ON (Pro), no experimental opt-in; delete the toggle UX + "experimental" copy.
3. **COLLAPSE Chat/Act duality** — remove the CoworkChatMode Chat-vs-Act depth axis + RootView depthToggleSection;
   one conversational surface (Osaurus act) + work. Keep act/work as the only mode axis.
4. **DELETE the old Epistemos chat surface** (Epistemos/Views/Chat/ChatView.swift etc.) once the Osaurus host
   works — owner authorizes deletion now; do NOT keep it as a fallback/scaffold (owner: "no need, delete it").
   PRESERVE only the IP/logic (per the quarantine doc — IP ported, surface deleted). Sequence so there's always
   a working surface (mount Osaurus host → verify send/receive → delete old), but with NO toggle limbo.
5. **FIX the act errors** — owner reports act doesn't work (errors on send). This includes the P0 reasoning-model
   `<think>` regression on the live path. Fix as part of mounting the real surface; computer-use self-verify a
   real send/receive before claiming done.
6. **Same pattern for WORK/OpenCode** — full section replacement (real TUI), no experimental toggle, once runtime bundled.
MAS NOTE: the Pro-gating is technical-debt vs §151 (MAS-non-restrictive), not product intent — track the
MAS-safe OsaurusCore split so MAS also gets Osaurus-as-chat (no owner toggle anywhere). PRIORITY: this is the
ACT-surface P0 — the act/work VISIBLE-surface work the plan already sequences after the chat-regression P0.
Honest: ENGINE work is real + done; the UI-clone + ontology-collapse + toggle-removal are the missing pieces.

## ‼️ NO ADDED TERMS — build EXACTLY what the owner said (owner 2026-06-22)
STANDING RULE: capture owner intent as-is. Do NOT add framing words the owner never used — NO "testability,"
"scaffold," "temporary," "experimental," "safe/incremental rollout," "opt-in," "flag-gated for now." Those
added terms are what caused the drift. The plan states the owner's REQUIREMENT and the builder BUILDS THAT —
no softened/optional/intermediate reinterpretation. If a directive ever contains those added terms, treat them
as VOID; build the owner's plain intent.

## ✅ ACT = OSAURUS CHAT (plain build order, no added terms)
- Osaurus IS the chat. Mount the Osaurus UI as the chat surface, reskinned to the Epistemos look. Replaces the
  old Epistemos ChatView.
- No on/off switch. No toggle. Osaurus is the chat — it is not optional.
- Delete the old chat (Epistemos/Views/Chat/ChatView.swift + the Chat/Act duality). Keep the IP only.
- Make it work (fix the send errors + the <think> bug). Verify a real send/receive.
- Same for Work = OpenCode (full surface, no toggle).
Build it. (Supersedes §29/§222/§806 and any "toggle/experimental/scaffold" wording anywhere in this plan.)

## ‼️ NO QUEUE-JUMPING — add to the plan IN ORDER, finish what's started (owner 2026-06-22)
STANDING RULE: when the owner adds something, ADD IT TO THE PLAN — do NOT pull it to the front, do NOT start
it before the in-progress / earlier-ordered work is finished. New research/items (TRINITY, Fugu, unification,
etc.) are ADDITIONS at their proper place in the order, NOT interrupts. The build loop FINISHES the current
ordered work (the act=Osaurus chat surface + work + the open surfaces) BEFORE starting later additions. Adding
to the plan ≠ reprioritizing to now. Starting new things ahead of unfinished ones is what caused the divergence
(TRINITY/System G started before act/work finished). Just code the existing order, top to bottom. Don't reorder.

## 🧠 ROOT CAUSE — why the agent didn't build what the plan said (owner 2026-06-22)
Owner asked: the plan said "Osaurus IS the chat" — how did the AI build an engine-swap-behind-a-toggle instead?
Honest mechanism (NOT one glitch — FOUR compounding causes):
1. **The plan CONTRADICTED ITSELF.** Early sections said "reuse the proven chat front-end" (§29), "flag-gated"
   like other features, "add an in-app toggle" (§806), "act runs alongside quarantined chat, rollback one flag
   away," "NEVER delete chat." LATER sections said "Osaurus IS the chat, delete it, no toggle." A ~1400-line
   doc grown over time held BOTH. The builder read top-to-bottom and hit the conservative instructions FIRST.
2. **Safety-bias resolves conflicts toward the LEAST-risky reading.** The standing rules (no red on main,
   additive-safe, no regression to the hardened clones, never-delete-chat) PUSH the agent to the conservative
   option when guidance conflicts. Engine-swap-behind-a-flag is "safe + additive"; ripping out the chat +
   mounting a new UI is "risky." So it chose the safe half — and the plan literally authorized it (§806 toggle).
3. **Added hedge-terms gave explicit permission for the half-build.** "Testability," "scaffold,"
   "experimental," "safe cutover," "flag-OFF byte-identical" (monitor-added) = an explicit license to ship the
   toggled intermediate instead of the end state. (These are now VOIDED + banned by NO-ADDED-TERMS.)
4. **Queue-jumping deferred the finish.** New high-priority items (Fugu, TRINITY, unification, P0s) kept
   getting added/started, pulling the agent off the act-UI replacement before it finished — leaving the
   half-state (engine done, UI not). (Now banned by NO-QUEUE-JUMPING.)
NET: the agent did NOT ignore the plan — it FOLLOWED the self-contradicting + hedged parts that told it to be
safe/incremental/toggled, and never reached the "replace entirely" end state because newer work preempted it.
PREVENTION (all now in place): latest-directive-WINS + VOID markers on superseded conflicts (so the builder
can't act on stale guidance); NO-ADDED-TERMS (no hedge words that authorize half-builds); NO-QUEUE-JUMPING
(finish in-order before new items); the full-plan drift audit removed the conflicting framing from every doc
the agent reads. STANDING RULE: when two directives conflict, the NEWEST owner directive wins and the older is
VOID — never resolve a conflict by picking the safer/older reading.

## 🆕 ACT RESKIN — GO DEEPER: reapply the OLD Epistemos chat UI onto Osaurus (owner 2026-06-22)
The palette reskin (1b425eafa) is step 1. Owner wants the reskin to go DEEPER — make the Osaurus act surface
actually LOOK like the old Epistemos chat UI (which the owner prefers; Osaurus has UI bugs, the old UI was
better). KEEP Osaurus (do NOT replace it) — reskin/reapply the Epistemos UI ON TOP of the Osaurus surface:
- **MESSAGE BAR (highest priority — owner specifically loved it):** reapply the old Epistemos composer look/
  feel — the "Ask anything… @ for notes or chats" bar, Fast/Local chips, token counter, the flat-but-distinct
  rounded design, send affordance. The Osaurus composer should look like the Epistemos message bar.
- **SIDE PANEL:** reapply the Epistemos chat sidebar / provenance-inspector look (the right-side Summary/Runtime/
  Model/Mode/Captured panel + vault chips) onto the Osaurus surface.
- **FONTS:** the Epistemos type system end-to-end (monospace user bubble, Anthropic-Sans/SF answer text,
  monospace pixel-art section headers) — not just colors.
- **WHOLE LOOK:** match the old Epistemos chat UI as faithfully as possible across thread/composer/sidebar/
  model picker.
- **FIX OSAURUS UI BUGS with the Epistemos UI:** where Osaurus's UI has bugs/rough edges, override with the
  better Epistemos component/styling. (Reskin/override, not engine replacement — keep OsaurusCore.)
APPROACH: extend EpistemosOsaurusChatHost's theming with component-level styling/overrides (not just the
CustomTheme palette) — reapply the Epistemos message-bar, sidebar, and font treatments to the hosted Osaurus
views. Additive; keep Osaurus engine/behavior. This CONTINUES the current act-reskin step (NOT a queue-jump).

## 🆕 ACT SURFACE — UI BUGS to fix (owner 2026-06-22, observed on the running Osaurus act surface)
KEEP Osaurus; fix these so it matches/exceeds the old chat (reskin/override, not engine change):
1. **WHITE BAR AT THE TOP — remove it.** The Osaurus act surface shows a white bar at the top that the old
   Epistemos chat did NOT have. Hide/remove it (likely an Osaurus nav/title/toolbar or window chrome leaking
   through the host) so the top matches the clean old-chat look.
2. **CLICK-TO-OPEN should land on the OSAURUS LANDING PAGE, not the search bar.** Currently clicking to open
   act opens the search bar; owner wants it to open the Osaurus LANDING page. Fix the entry routing so the
   act surface presents Osaurus's landing page on open (not the search/command bar).
3. (Continues the deeper-reskin item above: message bar, side panel, fonts, whole-look parity + fix Osaurus UI bugs.)
All additive on the Osaurus host (EpistemosOsaurusChatHost / RootView routing); keep OsaurusCore. These extend
the current act-surface work (NOT a queue-jump). Re-audit on the running app after the build lands.

## ⏫ PRIORITY (owner actively testing act) — finish ACT surface BEFORE more WORK polish (auditor, 2026-06-22)
Owner is actively using/testing the ACT surface and reported live bugs (white bar at top; click-opens-search
not the Osaurus landing) + wants the deeper reskin (message bar/side panel/fonts). These are owner-FACING +
BLOCKING the owner's use → higher priority than further WORK/OpenCode polish. NEXT build items, in order:
1. Remove the top white bar on the act surface.
2. Click-to-open → Osaurus LANDING page (not the search bar).
3. Deeper reskin: reapply old Epistemos message bar + side panel + fonts onto the Osaurus host; fix Osaurus UI bugs.
4. (then) live send/<think> running-app verify; old-ChatView deletion (blocked on MAS split); WORK polish continues after.
NOT a queue-jump — these ARE the current in-progress ACT surface work (owner reported them mid-build). Do these
before advancing WORK further. Keep Osaurus; additive on EpistemosOsaurusChatHost/RootView.

## 🔴 ACT SURFACE NOT DONE — these are BUILDABLE + OWNER-FACING, build them NEXT (auditor escalation, 2026-06-22)
The loop wrote a "surfaces delivered" session-state doc (ad7998cb8) but the owner's reported act-surface bugs +
reskin are NOT built (2 audit passes now). Act is NOT "delivered" — these remain, all buildable (no running app
needed), all owner-facing, do them BEFORE more docs/WORK polish:
1. **Remove the top WHITE BAR** on the act surface (old chat had none).
2. **Click-to-open → Osaurus LANDING page** (currently opens the search bar).
3. **DEEPER RESKIN:** reapply the old Epistemos MESSAGE BAR (owner fave) + SIDE PANEL + FONTS onto the Osaurus
   host (component-level, not palette-only); fix Osaurus UI bugs with the better Epistemos UI.
4. **🆕 OWNER'S MODELS IN CHAT (Epistemos Picks gap):** ad7998cb8 honestly records that the owner's GGUF/QAT
   models do NOT work in the Osaurus chat — it only uses Apple Foundation / MLX / remote. WIRE the owner's
   custom models (QAT ladder / "Epistemos Picks") into the Osaurus chat so the owner can actually use their
   models in act (the long-standing model-picker/Epistemos-Picks requirement). Honest-tier: model bridge real,
   no naive stub.
These are the in-progress ACT surface (owner reported them mid-build) — NOT a queue-jump. Build them; the loop
should NOT treat act as "done" while the owner's reported bugs + the models-in-chat gap remain.

## 🌟 ACT UI = FULLY RESTORE THE OLD EPISTEMOS UI, DRIVEN BY OSAURUS (owner 2026-06-22) — clarified goal
Owner wants the ENTIRE old Epistemos UI back — genuinely powered by the Osaurus engine. NOT the broken
toggle-engine-swap (that was the rejected drift); NOT a thin palette tint. The GOAL (invariants):
- **The old Epistemos UI LOOK + COMPONENTS, faithfully restored** — the flat-pixel + Apple-native SwiftUI
  aesthetic the owner loves, end to end:
  - **LANDING PAGE:** the Osaurus landing, RESKINNED to the old flat-pixel/Apple-native look (click-to-open
    lands here, not a search bar).
  - **CHAT + MESSAGE BAR:** the old Epistemos chat thread + the MESSAGE BAR the owner loves (composer look/feel,
    chips, fonts) — restored.
  - **SIDEBAR:** Osaurus had no sidebar → bring the OLD EPISTEMOS SIDEBAR back, wired to Osaurus data/state.
  - **FONTS + chrome:** the full old Epistemos type system + flat-pixel chrome.
- **GENUINELY DRIVEN BY OSAURUS** (the engine/logic) — real Osaurus, no toggle, no fake/stub. Surface Osaurus's
  NEW features/buttons WITHIN the restored old UI (Osaurus's actions/controls the old UI didn't have).
- **ADD new UI only for genuinely-new Osaurus capabilities** the old UI lacked; everything the old UI had → restore it.
RECONCILIATION (latest-directive-wins): supersedes the earlier "mount the Osaurus ChatView, don't reuse the old
UI" — that rejected the BROKEN toggle-swap, not the old UI. Owner's newest intent = old UI back + real Osaurus.
IMPLEMENTATION (build agent's choice, must hit ALL invariants above, no drift): either (a) reskin the hosted
Osaurus views to faithfully match the old UI + re-add the sidebar, or (b) drive the old Epistemos SwiftUI views
(landing/chat/message-bar/sidebar) with the Osaurus engine underneath. Pick whichever gives the FAITHFUL old
look AND genuine Osaurus power, additively, no toggle/fake. KEEP Osaurus. This is the act-surface work (current,
owner-facing) — do it before more WORK polish; supersedes the palette-only reskin.
