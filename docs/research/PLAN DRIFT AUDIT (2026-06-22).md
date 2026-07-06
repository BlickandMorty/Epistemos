# PLAN DRIFT AUDIT (2026-06-22)

Full top-to-bottom drift audit of the Epistemos plan, per the owner's directive that the monitor
(directive-capturing assistant) ADDED framing/terms the owner never used — "testability," "scaffold,"
"experimental," "opt-in," "incremental rollout," "safe cutover," "flag-gated for now," "temporary toggle" —
and that added verbiage caused the BUILDER to DRIFT (built an optional toggle + engine-swap instead of
"Osaurus IS the chat"). Three spots were already fixed (addendum line 29, line 806/808-810, quarantine §63
line 63). This audit covers ALL OTHER items.

**Method:** read every named doc in full; flag only MONITOR-ADDED framing (not owner-verbatim quotes, not
the 3 already-fixed spots, not the legitimate transient refactor flag clarified at addendum lines 701-703,
not the Fugu opt-in/cost which the owner wanted, not honest engineering language). Each finding cites the
file + exact line + quoted text + drift class + owner-verbatim-or-monitor-added + suggested neutralization.

**Drift classes:** (1) OPTIONALITY, (2) SOFTENING/REINTERPRETATION, (3) ADDED-CONCEPT, (4) CONFLICT,
(5) SCOPE.

---

## SUMMARY COUNT

- **HIGH: 4** (could mislead a top-to-bottom builder NOW)
- **MEDIUM: 5**
- **LOW: 3**

The plan has been heavily self-corrected by the owner near the end (the "ACT = OSAURUS IS THE CHAT" §1336,
"NO ADDED TERMS" §1376, "ACT = OSAURUS CHAT plain build order" §1383 all explicitly VOID the toggle/
experimental/scaffold framing). The HIGH findings below are the spots that STILL carry stale optional/
reuse-old framing WITHOUT a VOID/supersede marker, so a builder walking top-to-bottom could still act on
them before reaching the late-doc corrections.

---

## HIGH SEVERITY (could mislead the builder NOW — un-marked stale framing)

| file | line | quoted text | drift class | owner-verbatim or monitor-added | suggested neutralization |
|---|---|---|---|---|---|
| docs/SESSION_CONTINUATION_PROMPT_2026_06_21.md | 43 | "**Act replaces chat.** The owner LOVES the chat front-end and wants act to look exactly like it — REUSE the proven chat front-end as act's UI." | CONFLICT + SOFTENING (2/4) | monitor-added ("REUSE the proven chat front-end as act's UI" is the monitor's phrasing) | This is the SAME drift as addendum §29 (already VOIDed) but lives in a DIFFERENT doc with NO void marker. A builder reading this continuation prompt would "reuse the old ChatView" — exactly the divergence. Add VOID marker: "[VOID — superseded by addendum 'ACT = OSAURUS IS THE CHAT' §1336/§1383: mount the OSAURUS UI clone reskinned to the Epistemos look, NOT the old ChatView.]" |
| docs/SESSION_CONTINUATION_PROMPT_2026_06_21.md | 152 | "act reskin = current-chat-UI discipline (cream palette, MONOSPACE user bubble, … PRESERVE model picker …" with no statement that the SURFACE is the Osaurus clone | SOFTENING (2) | monitor-added | Same reframe gap as addendum §222 (which WAS reframed at §1351). This doc's UI spec never says "mount the Osaurus surface and reskin IT" — a builder could read it as "restyle the existing ChatView." Add the §1351 reframe pointer: "[the SURFACE is the OSAURUS ChatView clone, reskinned to this discipline — not the old Epistemos ChatView. See addendum §1336/§1383.]" |
| docs/AGENT_LOOP_PROMPT_2026_06_21.md | 5 | "5. **PROTECT:** chat backend QUARANTINED, NEVER deleted (porting cycles before retire)" (line 47 in file) | CONFLICT (4) | monitor-added (summary phrasing) | Directly contradicts the owner's later authorization to DELETE the chat surface (addendum §855 "DELETE the chat FEATURE", §1336/§1363 "DELETE the old Epistemos chat surface … owner authorizes deletion now"). A loop reading THIS prompt every iteration (it says "re-read each iteration") would treat delete as forbidden. Add: "[UPDATED — owner now authorizes deleting the chat SURFACE after IP ported + act proven (addendum §855/§1363). 'Never delete' now applies to the IP/logic only, not the surface.]" |
| docs/AGENT_DIRECTIVE_CHECK_PROMPT_2026_06_21.md | 42 | "7. **Chat backend:** QUARANTINED, NEVER deleted; porting cycles move its logic/IP into beneficial surfaces before retire; retire only after 4-part bar + owner OK." | CONFLICT (4) | monitor-added | Same as above — a checker auditing "compliance" against THIS directive list would flag a (correct) chat-surface deletion as a DIVERGENCE, and "go back and fix" it by restoring the chat (STEP 4 instructs fixing divergences). Add: "[UPDATED per addendum §855/§1363 — the SURFACE may be deleted after IP port + act-proven + owner OK (given); preserve the IP/logic only.]" |

---

## MEDIUM SEVERITY

| file | line | quoted text | drift class | owner-verbatim or monitor-added | suggested neutralization |
|---|---|---|---|---|---|
| docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md | 162-168 | "## 🆕 OPENCODE MUST BE FULLY THEME-RESPONSIVE … NOTE: this strengthens the case for a NATIVE shell … a bundled web/Electron UI would require explicit theme-bridging" | SOFTENING (2) | monitor-added ("strengthens the case for a NATIVE shell") | The monitor here nudges toward a native-shell rebuild; owner LATER chose "keep OpenCode's REAL UI" (§170, §449). The native-shell nudge is contradicted but this NOTE has no supersede marker; a builder could read it as license to rebuild natively. Add: "[Owner chose KEEP-THE-REAL-UI (§170/§449/§652) — the native-shell nudge here is superseded; theme via palette-bridge, do NOT rebuild native.]" |
| docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md | 676-690 | "## ✅ CONSENSUS — KEEP TriageService; inject gated act swap … behind the SAME flag (`shouldRouteActThroughOsaurus`, OFF by default). Flag-OFF = byte-identical to today" | OPTIONALITY (1) | monitor-added (the gated-flag mechanism is the agent's "approach", not an owner ask) | The owner's ask here was "every chat surface gets act." The monitor framed the delivery as a default-OFF flag/gated swap. This reads as the SAME optional-toggle pattern the owner banned at §1376. It is arguably a transient refactor flag (like §692-703), BUT it is NOT explicitly clarified as transient/removed, and §1336 says "NO on/off switch." Add the §703-style clarifier: "[this gated swap is a TRANSIENT internal refactor-safety flag, REMOVED when act becomes the default chat — NOT a product toggle. Per §1336 the end state is Osaurus-IS-the-chat, no switch.]" |
| docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md | 522-526 | "1. **Is the Osaurus engine ACTUALLY the live act path?** Check `EPISTEMOS_ACT_OSAURUS_V0` flag state … If flag-off, say so plainly (it's staged, not reaching the user)." | OPTIONALITY-adjacent (1) | monitor-added (the deep-check framing) | This DEEP CHECK normalizes "act lives behind a flag that may be off / staged" as the expected state. Post-§1336 (Osaurus IS the chat, no flag), the flag is supposed to be REMOVED, not a permanent staged gate. The check is honest diagnostics (owner-wanted intent), but the "flag-off = staged is fine" framing should point at the no-toggle end state. Add: "[end state per §1336 = the flag is REMOVED and Osaurus IS the default chat; 'staged behind flag' is only the transient build state, not the target.]" |
| docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md | 855-863 | "### 3. CHANGE — DELETE the chat FEATURE … Supersedes the prior 'quarantine, never delete' for the SURFACE" | CONFLICT-resolution (4) — already mostly handled, but cross-doc gap | monitor-added (captures an owner authorization) | This section DOES correctly supersede the never-delete-surface rule INSIDE the addendum, but the supersede is NOT propagated to CHAT_BACKEND_QUARANTINE_NEVER_DELETE (whose §1-§4 still read as absolute "NEVER DELETE the chat") nor to the two check/loop prompts (HIGH rows above). Add a forward-pointer at the TOP of the quarantine doc: "[UPDATED 2026-06-22: owner authorizes deleting the chat SURFACE after IP ported + act proven (addendum §855/§1363). This doc's 'never delete' now governs the IP/logic ONLY.]" |
| docs/CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md | 10-13 | "1. **NEVER DELETE the chat / chat-backend code.** Not the resolution layer, not the picker, not the views, not InferenceState chat paths … No `rm`, no file removal" | CONFLICT (4) | owner-verbatim-derived rule, but now PARTIALLY superseded | The owner's later directive (addendum §855/§1363) authorizes deleting the chat SURFACE (views) while preserving IP. This rule as written still forbids deleting "the views," which now conflicts. Do NOT delete the rule (IP-preservation is still binding) — add the same forward-pointer marker so a builder doesn't treat surface-deletion as a violation. |

---

## LOW SEVERITY

| file | line | quoted text | drift class | owner-verbatim or monitor-added | suggested neutralization |
|---|---|---|---|---|---|
| docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md | 402-412 | "## 🆕 RESEARCH — MAS-compatible substitute for the VM sandbox … research these PARTIAL substitutes: WASM in-process sandbox … Remote/cloud sandbox" | ADDED-CONCEPT (3) | monitor-added research framing | Low risk: it's a research item, honestly scoped, and the owner did ask "is there a MAS equivalent or just live without it." The substitutes (WASM/cloud) are monitor-introduced concepts but framed as research-to-confirm, not as built scope. No neutralization needed beyond keeping it labeled "research item," but note it so it isn't silently promoted to a build requirement. |
| docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md | 479-481 | "ULTRA-LIGHT FALLBACK (if real-TUI-in-SwiftTerm feels clunky): render a NATIVE pixel-art terminal-look view over the headless engine … use this only if the real-TUI path can't hit the feel/weight bar." | SOFTENING (2) | monitor-added | A monitor-introduced fallback to native-render, which leans away from the owner's "keep the REAL UI" (§170/§652). It is correctly hedged ("only if … can't hit the bar"), so low risk, but it re-opens a path the owner closed. Suggest a pointer: "[owner confirmed keep-the-real-TUI (§652); this native-render fallback is a last resort only, not a planned path.]" |
| docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md | 795-797 | "**Alternative (leaner installer):** download-on-first-use … Bundling is MORE friction-free; download = smaller .dmg. Default = BUNDLE; download-on-demand only if installer size becomes a concern." | ADDED-CONCEPT (3) | monitor-added alternative | Minor: introduces a download-on-demand alternative the owner didn't ask for, but explicitly defaults to BUNDLE (owner's intent) and gates the alternative on a real concern. No correction needed; flagged for completeness only. |

---

## SECTIONS AUDITED AND FOUND CLEAN (no monitor-added drift)

- **Addendum §3-§17** (Epistemos Picks design, owner-verbatim quoted): CLEAN. The "honest selection / no silent Qwen" is owner-wanted honesty language.
- **Addendum §24-§29** (surface-wiring rule): the drift was the §29 trailing clause — ALREADY FIXED (VOID marker present). Body is owner-verbatim + clean.
- **Addendum §50-§64** (CONFLICT-RESOLUTION favor Osaurus): CLEAN — owner-verbatim quoted; the "cherry-pick owner's compatible IP" is correctly distinguished from "zero cherry-pick of Osaurus."
- **Addendum §117-§149** (two-mode architecture): CLEAN — owner-verbatim quote anchors it; ACT=Osaurus / WORK=OpenCode is the canonical decision.
- **Addendum §151-§160** (MAS non-restrictive set-in-stone): CLEAN — owner-verbatim; correctly supersedes CLAUDE.md MAS gating with honesty caveat preserved.
- **Addendum §170-§204** (OpenCode UI decision = keep real UI + landing/blur): CLEAN — authoritative owner decision, consistent with later sections.
- **Addendum §206-§390** (EPDOC MD-V2, substrate-certain-not-deferred, reskin north star, model picker preserve, Tamagotchi, per-clone settings, motion language, north star, design soul, Prose protect): CLEAN — the "lower in order / CERTAIN / not deferred" language is owner-mandated anti-drift, not drift itself; the "no fake-done / real-state / hardened" language is owner-wanted engineering.
- **Addendum §391-§439** (dual-build MAS/Pro): CLEAN — the one MAS-blocked feature (VM sandbox) is an honest technical fact; flagging it off for the MAS target is the legitimate build mechanism, not optionality drift on an owner requirement.
- **Addendum §441-§483** (CORRECTIONS overriding research, OpenCode heaviness mitigation): CLEAN — these are owner directives correcting prior drift; the "Electron/Tauri bloat is OPTIONAL" refers to a third-party CLIENT we don't ship, not an owner feature made optional.
- **Addendum §485-§517** (deep optimization cycles): CLEAN — owner-wanted, honest no-regress engineering.
- **Addendum §519-§551** (deep-check, quarantine code-preserved+UI-hidden): mostly CLEAN; the flag-state framing flagged MEDIUM above. The "UI-hidden once act proven" is consistent with the later delete-surface directive.
- **Addendum §553-§763** (adopt-engines/IP-layer, Goose cost, work-engine = Architecture C, market position, vault pillar, full-clone process): CLEAN — heavily owner-deliberated decisions; the gated/flag language at §684 is the only spot flagged (MEDIUM). The work-engine flags here are real architecture decisions, not optionality drift.
- **Addendum §692-§706** (one inference chokepoint): CLEAN — the flag here is EXPLICITLY clarified as a transient refactor-safety mechanism (§701-703), which the directive says NOT to flag.
- **Addendum §765-§799** (NEVER-IDLE, Bun vendoring): CLEAN — owner-wanted; "incrementally across loop turns" is build cadence, not softening of a requirement.
- **Addendum §813-§893** (P0 regression, three standing directives, code-more-build-less): CLEAN — honest bug-fix + verification + cadence language, owner-wanted.
- **Addendum §895-§1099** (Fugu, Trinity, system-prompts library): CLEAN — Fugu opt-in/cost is explicitly owner-wanted (excluded from drift per the directive); "Fugu NEVER the brain" + "native orchestrator is the brain" is owner IP intent, not scope drift. Trinity full-clone + system-prompts vendor are owner-verbatim "completely clone" directives. Heuristic-first-then-learned-router is honest sequencing tied to a real license blocker, not softening.
- **Addendum §1101-§1334** (holistic unification, grand sweep cycles, dual-brain app-side-only, Helios salvage): CLEAN on the SCOPE axis — the 70B / new-model / model-side dual-brain (BRAIN-1) is consistently EXCLUDED and the §1170 correction explicitly removes the earlier "future track / reserved slot" framing. No re-inclusion of excluded scope. The salvage items are app-side + additive + behind existing gates, honestly classified.
- **Addendum §1336-§1399** (ACT=OSAURUS-IS-THE-CHAT, NO ADDED TERMS, plain build order, no queue-jumping): CLEAN — these ARE the corrective directives; they are the authority the HIGH findings should point back to.
- **THE_BIG_IDEA_GRAND_CONVERGENCE_2026_06_22.md** (all 84 lines): CLEAN — 70B explicitly excluded (§13, §33-41, §72), no optionality drift, consistent with the addendum. "Two faculties of one brain" is the owner's framing.

---

## NOTE ON THE SCOPE AXIS (70B / new-model / model-side dual-brain)

Checked specifically per drift class 5. The plan is CONSISTENT and SAFE here: §1170 ("STAYS OUT, PERIOD"),
§1299 (dual-brain APP-SIDE only, never model-side), §1170/§1176 explicitly retract the earlier big-idea
"future track / reserved slot / open decision" framing, and the Big Idea doc §33-41/§72 mark GAP-1 as
CLOSED. No section re-includes the excluded model-side scope or treats a "keep separate" as "merge." The
only "keep separate" that is deliberate (cloud vs local engine lanes under System G, §1132) is correctly
preserved, not drifted into a forced merge.

---

## RECOMMENDED ACTIONS (report-only; owner/loop to apply — do NOT edit plan per audit scope)

1. **HIGH — propagate the chat-surface-deletion + ACT=Osaurus-IS-the-chat supersedes into the 3 secondary
   prompt docs** (SESSION_CONTINUATION lines 43 & 152, AGENT_LOOP_PROMPT line 47, AGENT_DIRECTIVE_CHECK
   line 42) and the quarantine doc top — these are the live cross-doc conflicts a top-to-bottom builder/
   checker hits BEFORE the late-addendum corrections.
2. **MEDIUM — add transient-flag clarifiers** to addendum §684 (TriageService gated swap) and §522 (deep-
   check flag framing) mirroring the §703 wording, and supersede markers to §162-168 (native-shell nudge)
   and §855→quarantine-doc.
3. **LOW — add hedge-pointers** to §479-481 (native-render fallback) and note §402-412 / §795-797 as
   research/alternative-only (no build promotion).
