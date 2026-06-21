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
