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
