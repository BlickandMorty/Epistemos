# SS-CC — Chat composer (main + mini): minimal Apple-native, fuse tools/skills/commands, fix context controls (2026-06-20)

Owner: *"For the chats main and mini I want to make sure it is minimal. Keep the context tuning but the book — idk if I need
that, it has cowork but it won't let me press anything so not sure if it's just for show. The Local/Cloud labels look ugly —
more minimal + Apple-native; the cloud button etc don't need that. The context logo looks ugly — Apple-like. The context bar
on the message bar is too thin to hover over — make it thicker. Still need the tool thing but it should actually WORK and have
ALL tools + skills, also the commands and skills should be FUSED with the agent tools button, and they should work. A big
process of minimizing + combining parts so it's less cluttered. Check the OTHER chats too — all minimal but still useful.
Also the agent routing keeps getting MORE regressed — how do you add incorrect routing when you're supposed to be removing
muddiness? This is huge. AND add all these to the PLAN, not just prompt the agent — things are missing because the plan isn't
being updated."* Code-grounded (ChatInputBar.swift / MiniChatView.swift). NON-INVASIVE; cross-ref SS-VIS (capability surfacing),
SS-CR (routing), SS-CLEAN (muddiness + no-regression).

## Composer controls today (ChatInputBar.swift — main; MiniChatInputBar — mini, reuses same stack)
- **Local/Cloud runtime pill:** `showInlineRuntimePicker` (:81) → `InlineRuntimePickerPanel`; `isCloudSelection`(:181); the
  "⚡ Local" pill + a separate **cloud-route button** `showsCloudRouteButton`(:325) + `needsCloudBanner`(:500). Owner: pill
  labels ugly; the extra cloud button isn't needed.
- **Context control:** the context badge → `CoworkContextPanel`(:137, "tapping the context badge opens the real CoworkContextPanel");
  "Read + Search vault" chip. Owner: logo ugly (want Apple-like) + the **bar is too THIN to hover** (hit-target too small).
- **The "book" / panel icon (cowork):** opens cowork but "won't let me press anything → just for show." Verify it's wired or
  remove it (dead/for-show control = SS-CLEAN dead-flag).
- **Tool button:** `toolPanelButton` → `AgentToolTogglePanel` (tools+MCP+cowork+skills). Slash **commands + skills** are a
  "fused main chat composer" (:123) but appear SEPARATE from the tool button. Owner: FUSE commands + skills INTO the agent-
  tools button, have ALL tools+skills, and make it actually work.

## Plan (a deliberate de-clutter + Apple-native pass; NON-INVASIVE; main + mini + all chat surfaces)
1. **Minimal Apple-native runtime control [S→M]:** replace the ugly Local/Cloud labels with a minimal, SF-native control
   (segmented/menu, system materials, SF Symbols) — one clean control, not a pill + separate cloud button + banner. Drop the
   redundant `showsCloudRouteButton`/`needsCloudBanner` clutter (fold "needs cloud" into the one control's state honestly).
2. **Context control — prettier + thicker hit target [S]:** Apple-like glyph for the context/"Read + Search vault" badge;
   widen the context bar's tappable area (min 28-32pt hit target) so it's hoverable/pressable. Keep the context tuning (owner
   wants to keep it) — just make it minimal + reachable.
3. **Cowork/book button — works or goes [S]:** verify the book/cowork icon actually opens an interactive `CoworkPanel`; if it's
   non-functional/for-show, either wire it or remove it (no dead controls).
4. **FUSE tools + skills + commands into ONE working button [M]:** the agent-tools button (`AgentToolTogglePanel`) becomes the
   single capability surface — tools + skills + slash-commands together, all functional (a tool/skill/command launched from it
   actually runs). One source of truth (reuse the registry; cross-ref SS-VIS). Remove the separate/parallel command+skill
   affordances that clutter the bar.
5. **Sweep ALL chat surfaces [S]:** main ChatInputBar, MiniChatInputBar, the graph-embedded chat, note mini-chat — apply the
   same minimal-but-useful composer (one shared composer component, not divergent clones — SS-CLEAN).
Each test-backed (render/behavior); honest (no dead controls); minimal + Apple-native + still useful. Pixel polish non-blocking
(owner verifies visually, but the loop ships per the no-owner-gate policy).

## Owner meta-concerns (record as standing discipline)
- **ROUTING NO-REGRESSION:** the routing fixes have been whack-a-mole (SS-CR introduced new dead-ends twice). Standing rule:
  any change to chat routing/model-resolution MUST add a FULL routing-matrix regression guard (each {Local,Cloud}×{model
  installed?,creds?} cell resolves correctly — no new dead-end, no local→cloud mis-route) BEFORE shipping. Removing muddiness
  must never add a routing bug. Fold into SS-CLEAN.
- **PLAN-CAPTURE (owner emphatic):** EVERY owner concern/query is written to the ledger + an SS-* slice — NEVER only steered to
  the agent. (This slice + the ledger entry are that capture.) Cross-ref SS-CLEAN Owner-Request Coverage Sweep.
