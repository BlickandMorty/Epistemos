# PLAN / LEDGER / DIRECTIVE CONSISTENCY SWEEP (S7, 2026-06-19)

Read-only research (subagent), code-grounded. Feeds DEEP_PLAN_AUDIT_HUB. Scope: the ledger
(2,753 lines), master-loop prompt, CLAUDE.md, all 11 docs/research/*_2026_06_19.md.
**Bottom line: the big reversals are cleanly resolved/marked-superseded, but the plan carries
several DONE-but-broken ticks, real duplicate-tracking drift, 4 research roots not yet broken
into actionable lines, and 5 plan-level risks.**

## Contradictions
- C1 Osaurus "hidden sandbox" vs "IS the Act engine" — RESOLVED (line ~1068 correction); but the older P3.0 "FULL IMPORT incl SwiftUI frontend, entitlements verbatim" (422-443) is NOT reconciled with the research → see R-1.
- C2 "advertise canon-only" vs "owner-controlled set" — RESOLVED in sequence (2389 supersedes 2362); but the superseded reading at 2367-2375 lacks a "superseded" stamp.
- **C3 (live conflict) picker placement** — MODEL PICKER SIMPLIFY (1170, "effort/routing must move OUT of the picker") supersedes P1.11/NEW-PICKER (402/458, still open and tracking "carry over EVERY control / non-reductive"). Both open → conflicting instructions. Stamp 402/458 superseded-for-placement.
- C4 RuntimeRouter role — plan treats it as both authoritative badge source (P1.11:354) AND dead-code-to-wire (S1). Needs one decision.

## DONE-but-broken / status drift (un-tick these — pure honesty)
- **S-1: `[x]` "No hidden Qwen on tool/attachment seam (P1.10)" (line 1024) is FALSE** — contradicted by the open ❌ "MODEL SELECTION NOT HONORED … STILL BROKEN" (2632/2724); code confirms `AgentCommandCenterState.swift:580-600` still hardcodes Qwen lists + RuntimeRouter dead. UN-TICK.
- **S-2: `[x]` "Download progress visible (P1.8)" (1026)** vs open "PROGRESS BAR GONE — REGRESSION" (REQ 9, 2417). Drift.
- **S-3: PER-MODEL VAULTS is BOTH `[x]` (347) and `[ ]` (510)** — duplicate w/ conflicting status.
- **S-4: R-LITEPARSE `[x]` "DONE" (643)** but owner can't click-through (PDFium dylib not bundled/signed, 774/814) → should be `[~]` per the "DONE = owner can SEE+USE" rule.
- **S-6: P1.9 `[x]` "Fast effort visible" (1027)** reopened by P1.11 ("effort labels NEVER showed", 340). Un-tick/→[~].

## Duplicates (drift risk → consolidate)
D-1 per-model-vaults ×2 (347/510); **D-2 PICKER ×5+ (317/402/434/458/987/1170) — highest drift surface, has C3 baked in**; D-3 mini-chat parity ×2 (317/458); D-4 model-download/default-Qwen ×4 (993/2019/2355/2632); D-5 R-GOOSE ×3 (1434/2028/2048); D-6 R-OPENCLAW/R-HERMES/R-APPS ×2-3 (pre-research restatements); D-7 P5.H substrate ×4 (1257/1595/2220/2248); D-8 deep-settings-repair verbatim ×2 (1578/2242).

## Gaps (research roots not yet standalone actionable lines)
- **G-1 (top): WIRE RuntimeRouter + collapse 4 routers → R1+R2** — the durable root of the Qwen-pin, currently only a 🔎 sub-note under MODEL SELECTION (2744). Make it its own top-priority `[ ]`.
- **G-2: cloud tools for plain chat on ALL providers** (not just OpenAI/Anthropic `supportsAgentTier`, InferenceState:1347) — S4's biggest win, narrative-only, no standalone status.
- **G-3: un-gate skills from pro-build-only + unify skills dir + fix `.agents/skills` loader path** — the load-bearing "skills feel broken" root.
- **G-4: staging-purge still UNCONDITIONAL** (`LocalModelInfrastructure.swift:2593/2629`) — STEP 3 added a parallel `resumableStagingDirectory` but did NOT condition the 30-min purge on active-download as S1 prescribed → **partial-fix masquerading as fix**; the corrupt/incomplete root may still fire.
- **G-5: WEB CLIPPER (S5's "biggest unmapped gap") appears NOWHERE; multi-device SYNC unmapped; "expose vault over MCP + AGENTS.md (anti-Tolaria)" only buried in R-KUKU.**
- **G-6: self-evolution/procedural-memory dead path** (no Swift caller writes `write_procedure`) — prose-only.

## Risks in the plan itself
- **R-1 (high): P3.0 "FULL OSAURUS IMPORT incl SwiftUI frontend + entitlements verbatim" (422-443) would BREAK the MAS sandbox** if built literally — the research lands Osaurus as a Pro-gated :1337 server + vendored types + in-process brain, NOT the frontend/entitlements. Edit P3.0 prose to point at OSAURUS_ACT_CONNECTION_MAP.
- **R-2: advertised-set filter × auto-routing × still-live Qwen substitution** — if the router auto-picks an un-advertised model that's a no-hidden-route cousin; ship G-1 + honest-nil BEFORE the advertised filter goes live; add a covering test.
- **R-3 (important): all the tool-loop/auto-route fixes are flag-OFF** (`EPISTEMOS_AUTO_TOOL_ROUTE_V0` / `SCHEMA_PREFLIGHT_V0` / `GGUF_TOOL_GRAMMAR_V0` / `AUTOSUBSTITUTE_LOCAL_MODEL`). Per "DONE = owner can SEE+USE", **flag-OFF ≠ done** — TOOLS/SKILLS reads ~80% done from ✅ slices but is **0% live for the owner**. Add a "FLIP-THE-FLAGS + in-app verify" gating slice; block ticking until it passes.
- **R-4: S1 PRUNE list vs DELETION GUARDRAIL** — `ConfidenceRouter.swift` is referenced by P1.11(354)/EML-2(1968) so it's in-flight → KEEP+flag, do NOT blind-delete despite S1 calling it dead.
- **R-5: engine-isolation doctrine (1108) vs "shared Goose core so Act/Chat tap its MCP/subagents" (2054)** — need an explicit boundary: shared core allowed ONLY behind the shared capability-registry, not direct cross-engine import.

## Prioritized "fix the plan" list
1. **Un-tick the false [x]'s** (1024, 1026, 1027; R-LITEPARSE 643→[~]) — cheapest, highest trust.
2. **Add G-1 as a top-priority standalone line** (WIRE RuntimeRouter; fold AgentCommandCenterState:580 Qwen lists into R1).
3. **Resolve C3** — stamp 402/458 superseded-for-placement; merge the 5 picker entries into one epic.
4. **Add G-2..G-5 as actionable lines** (cloud-all-provider tools; un-gate+unify skills+`.agents/skills` path; condition staging-purge on active-download; WEB CLIPPER + expose-vault-over-MCP).
5. **Add R-3 gating slice** — "FLIP + VERIFY flags; flag-OFF ≠ done"; block TOOLS/SKILLS tick until live.
6. **Reconcile P3.0 (R-1)** — point its prose at OSAURUS_ACT_CONNECTION_MAP (no frontend/entitlements import).
7. **Reconcile R-4/R-5 doctrine tensions** (prune-vs-guardrail; isolation-vs-shared-core).
8. **Dedupe D-1,D-3..D-8** to one tracked item each + cross-refs (per-model-vaults & mini-parity first — active drift).

Load-bearing files: `RuntimeRouter.swift` (dead) · `AgentCommandCenterState.swift:580-600` (live Qwen pin) · `LocalModelInfrastructure.swift:2593/2629` (purge unconditional) · `agent_core/src/tools/registry.rs` (skills pro-build gate) · `.agents/skills/` (orphaned) · `InferenceState.swift:1347` (supportsAgentTier) · `PipelineService.swift:396` (auto-route flag OFF).
