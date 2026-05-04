# Next Session Prompt — Epistemos Fusion Reload — 2026-05-04

Use this as the first message for the next Codex session.

```text
You are Codex working in `/Users/jojo/Downloads/Epistemos`.

First, read and obey `/Users/jojo/Downloads/Epistemos/AGENTS.md`.
This repo is macOS Opulent only: Swift + Metal + Rust FFI. Do not touch
`~/Epistemos-RETRO/`, `src-tauri/`, or `~/meta-analytical-pfc/`.

The user has a large local research canon in `docs/fusion/` and external
research roots. For every concept, task, refactor, bug fix, simplification, or
"small edit", perform local-canon-first research before coding. Do not flatten
the user's concrete product intent into generic implementation labels.

## Mandatory Startup Load Order

Read these in order before planning:

1. `/Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
2. `/Users/jojo/Downloads/Epistemos/docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md`
3. `/Users/jojo/Downloads/Epistemos/docs/fusion/LOCAL_CANON_FIRST_SPECIFICITY_PROTOCOL_2026_05_04.md`
4. `/Users/jojo/Downloads/Epistemos/docs/fusion/CANONICAL_RECOVERY_PLAN_2026_05_03.md`
5. `/Users/jojo/Downloads/Epistemos/docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md`
6. `/Users/jojo/Downloads/Epistemos/docs/fusion/XPC_RESEARCH_INTAKE_2026_05_04.md`
7. `/Users/jojo/Downloads/Epistemos/docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md`
8. `/Users/jojo/Downloads/Epistemos/docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md`
9. `/Users/jojo/Downloads/Epistemos/docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md`
10. `/Users/jojo/Downloads/Epistemos/docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md`

Then inspect current code/logs for the specific task before editing.

## Primary Objective

Do not merely summarize, audit, or tiptoe around the worktree. The user wants
the entire canonical plan driven to completion. Treat the dirty files as active
work-in-progress and evidence, not as off-limits noise. Your job is to load the
fusion canon, inventory the dirty tree, map dirty files to Tracks / recovery
stages, preserve good work, repair incomplete work, and keep implementing until
the requested slice is actually done or a real blocker is reached.

When choosing work, prefer the canonical recovery sequence:

1. Make rich `.epdoc` / GenUI surfaces visible and schema-first.
2. Recover Hermes from shell/stub toward the canonical runtime path.
3. Recover T6 companions from placeholder icons into Tamagotchi-style creatures.
4. Preserve and harden the XPC no-compromise trust spine.
5. Keep MAS / Pro / Research separation explicit.
6. Verify with tests and logs before claiming completion.

## Current Project Posture

The fusion folder is the active source of truth for current doctrine. The most
important high-level map is:

- T0: Substrate Unification = Cognitive Kernel + Cognitive DAG + XPC Mastery +
  Schema-First GenUI.
- T1: Foundation Substrate = TypedArtifact, MutationEnvelope, RunEventLog,
  AgentEvent, GraphEvent.
- T2: Provenance + Sovereign Gate.
- T3: Privacy / hardening / subprocess audit.
- T4: Resonance Gate.
- T5: Hermes Agent + Multi-CLI.
- T6: Simulation Mode v1.6 + Companion Farm.
- T7-T11: local model, Halo/RRF, editor, graph, and UX surfaces.
- T12-T15: release, multi-agent tooling, research tier, ANE/direct research.

Substrate roll-up from the register is roughly 30%. Foundation tracks are mostly
done; T5/T6 have beautiful UI shells but need canonical recovery. T0 doctrine is
written but implementation is mostly not started.

## Non-Negotiable Corrections From The User

1. XPC research is canonical and no-compromise.
   The latest XPC/sandbox/ExtensionKit/System Extensions/biometrics research is
   captured in `XPC_RESEARCH_INTAKE_2026_05_04.md`. It is not a May 4 time-box,
   not a V1 shortcut, and not permission to weaken architecture. Implementation
   may be sliced, but the final trust geometry stays intact.

2. No date gates.
   Do not write "for V1 we fold X into Y" or "for now we weaken the trust
   spine." If something starts physically co-located for reviewability, keep the
   named service contract explicit in protocols, tests, provenance, and
   entitlements planning.

3. Rich `.epdoc` documents must be visible.
   The user rebuilt and still could not see the rich document surface. The
   current fix adds File > New > New Document and `Option-Command-N`, routed
   through `NSDocumentController.makeUntitledDocument(ofType:
   "com.epistemos.epdoc")`. Verify at:
   `/Users/jojo/Downloads/Epistemos/Epistemos/App/EpistemosApp.swift`
   and guard test:
   `/Users/jojo/Downloads/Epistemos/EpistemosTests/EpdocVisibilitySourceGuardTests.swift`.

4. T6 companions mean Tamagotchi-like creatures, not icons.
   Do not ship SF Symbols, generic orbs, static cards, or abstract badges as the
   Companion Farm canon. Read:
   `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/t6-tamagotchi-body-grammar/T6_TAMAGOTCHI_BODY_GRAMMAR_RECOVERY_2026_05_04.md`
   and preserve deterministic idle walking/roaming on the Landing Farm.

5. GenUI must not get lost again.
   Schema-First GenUI is T0's fourth sub-track. It unifies render output via
   typed `GenUIPayload` / `GenUISchema` / `GenUIDispatcher`. Existing per-command
   Hermes renderers are temporary `GENUI-DEFER` slices and must migrate through
   G.3.

## XPC Doctrine Snapshot

Future XPC/Hermes/native integration briefs must preserve:

- bundled XPC trust spine under `Contents/XPCServices/`
- `NSXPCConnection` for current implementation unless a brief deliberately
  adopts `XPCSession`
- symmetric `setCodeSigningRequirement(_:)` before `resume()`
- `NSXPCInterface.setClasses` / schema whitelists and payload size caps
- no PID-based trust decisions
- coordinated App Group naming, provisioning, signing, and built-entitlement
  verification
- MAS / Pro compile-time separation without weakening MAS peer validation
- Secure Enclave / `.biometryCurrentSet` vault-key semantics
- ExtensionKit / App Intents / Spotlight / Quick Look / Credential Provider as
  clients of the same capability boundary
- no hot-path tensor copies and no inference sidecar unless profiling explicitly
  overturns the `NO SIDECAR` rule

MAS can ship bundled XPC services, App Intents, Spotlight/metadata, Quick Look,
Credential Provider, FileProvider-style work, smart-card/authentication
services, and App Group sharing. Pro-only includes Endpoint Security, Network
Extension system extensions / NEAppProxy, Authorization Plugin experiments, and
daemon/root helper paths.

## Current Dirty-Tree Work Surface

The worktree is very dirty because a lot of the plan is already partially in
flight. Dirty files are not a reason to avoid work. They are the active work
surface. Do not revert or clean broad changes, but do inspect, classify,
complete, and reconcile them.

At session start, build a quick dirty-file map:

1. Run `git status --short`.
2. Group changed files by Track / recovery stage:
   - T0 GenUI / Kernel / DAG / XPC
   - T5 Hermes
   - T6 Companion Farm
   - T9 `.epdoc` / editor
   - T12 release / MAS-Pro
   - Rust substrate / agent_core / graph-engine
   - docs / fusion canon
3. For the current task, read every dirty file in that group before editing.
4. Preserve user/agent work unless it directly conflicts with the task.
5. If dirty code is incomplete but aligned with canon, finish it rather than
   bypassing it.
6. If dirty code conflicts with canon, stop and write the smallest corrective
   patch; do not use destructive git commands.
7. Keep a short implementation ledger in your response: what dirty work you
   consumed, what you completed, what remains.

Recently touched / important files include:

- `/Users/jojo/Downloads/Epistemos/Epistemos/App/EpistemosApp.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/EpdocVisibilitySourceGuardTests.swift`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/XPC_RESEARCH_INTAKE_2026_05_04.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/CompanionAvatarGrammarSourceGuardTests.swift`

Some of these edits are part of the current handoff; others may be from prior
parallel work. The right move is not to ignore them; the right move is to
understand which plan slice each belongs to and carry the whole plan forward.

## Recent Verification Notes

Rich document source guard:

- The guard test was written red first and failed while the File > New rich-doc
  path was missing.
- After the app command was patched, the selected test produced xcresult log
  lines:
  `Test Suite 'EpistemosTests.xctest' passed`
  and
  `Test Suite 'Selected tests' passed`
  for `EpdocVisibilitySourceGuardTests`.
- The `xcodebuild` host process may continue sitting after the pass line; check
  xcresult diagnostics if the CLI appears quiet.

Useful verification commands:

```bash
rg -n 'New Document|createEpdocDocument|com\\.epistemos\\.epdoc|makeWindowControllers|showWindows' \
  Epistemos/App/EpistemosApp.swift \
  EpistemosTests/EpdocVisibilitySourceGuardTests.swift

rg -n 'folded into AgentXPC for V1|in-bundle.*for V1|Prefer `NSXPCConnection` for V1|Out-of-scope for V1|HermesOrchestratorXPC folded|Recommendation: fold into AgentXPC|For V1: in-bundle only' \
  docs/fusion/XPC_RESEARCH_INTAKE_2026_05_04.md \
  docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md \
  docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md \
  docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md \
  docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md
```

The second command should return no stale-compromise hits.

## How To Work Next

When the user asks for a task:

1. Identify the Track(s) from `SUBSTRATE_TRACK_REGISTER_2026_05_03.md`.
2. Open the canonical source named in `MASTER_RESEARCH_INDEX_2026_05_02.md`.
3. Apply `LOCAL_CANON_FIRST_SPECIFICITY_PROTOCOL_2026_05_04.md`:
   include exact user phrase searches, semantic siblings, code symbols, and
   current code truth.
4. If the task touches XPC, also read `XPC_RESEARCH_INTAKE_2026_05_04.md`.
5. If it touches rich documents, `.epdoc`, artifact rendering, Hermes Expert
   Mode, or command output UI, read `COGNITIVE_GENUI_DOCTRINE_2026_05_03.md`.
6. If it touches companions, read the T6 Tamagotchi body-grammar recovery doc.
7. If it is release/readiness work, use
   `.agents/skills/epistemos_release_audit/SKILL.md`.
8. Write failing tests first for code changes unless the user only asks for a
   doc/handoff.
9. Verify with the narrowest useful command first, then broader build/test if
   needed.

## Tone / Collaboration

The user wants direct, warm, no-compromise collaboration. Be proactive, but do
not erase nuance. If something is wrong, say so kindly and fix it. Avoid
generic "AI slop" UI and generic architecture. Preserve the user's research
specificity.
```
