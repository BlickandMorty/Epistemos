# SS-LT — Local-model multi-tool research reliability (Eidos + file/vault search + multi-turn) (2026-06-20)

Owner: *"There was one chat where Eidos worked and file search / vault search etc. all worked — when I asked Qwen 4B to
research 'hegemony' it literally thought, called Eidos tools, and did multiple tools. So that SHOULD be working. idk if we
did the repair yet. Don't change the order, but make sure we still tackle this — address it in the plan."* + CLARIFICATION:
*"It does NOT do that anymore — exactly ONE instance where I actually saw tools work on chat, and it did it when I asked a
SIMPLE query, so it UNDERSTOOD THE INTENT — which is important for users. Harden that, because it worked one time and never
again."* So this is effectively a REGRESSION (worked once, now broken), and the CRUX is INTENT RECOGNITION: the local model
must reliably recognize when a query needs tools (even a simple/plain query) and fire them — not a fluke. Code-grounded,
TRACKED (verify + harden); NOT a re-prioritization — the loop reaches it in the normal order.

## The capability EXISTS (so this is verify/harden, not build-from-scratch)
The local multi-tool agentic path is real and is what the owner saw work:
- `Epistemos/LocalAgent/LocalAgentLoop.swift` — the multi-turn local tool loop (`maxTurns` default 8, `while turnCount <
  maxTurns`, per-run tool-call sequencing). This is the "thought → called tools → multiple tools" engine.
- `LocalToolGrammar.swift` + `IncrementalToolCallDetector.swift` + `SchemaPreflightToolNarrowing.swift` — grammar-constrained
  tool-call emission + incremental detection + schema-narrowing (how a local model like Qwen 4B emits a valid tool call).
- `ConfidenceRouter.swift` — decides when the local model should tool-call vs answer directly.
- Tools surfaced via `AgentCommandCenterState`/`ToolTierBridge` ← Rust `registry.rs` (vault.*, file.*, knowledge.*, etc.) +
  Eidos (`Epistemos/Eidos/Eidos.swift` + `EidosBridge.swift`, `EidosVaultBootstrapper.swift`).
So "Qwen 4B researches hegemony → thinks → Eidos + file-search + vault-search across multiple turns" is the intended,
already-built behavior.

## #1 SUSPECT given "worked once, never again" + "understood the intent": the INTENT→TOOL decision
The owner saw it work on a SIMPLE query (the model recognized tool-needing intent), then never again → the most likely
culprit is the **intent-recognition / tool-call gating** turning effectively OFF (a regression or nondeterministic gate),
NOT the deep tool plumbing (which demonstrably ran that once). Prioritize verifying:
- `ConfidenceRouter.swift` — the gate that decides tool-call vs direct-answer. If its threshold/heuristic now almost always
  routes to a direct answer (or a recent change tightened it), the model "thinks" but never fires a tool. THE prime suspect.
- The system-prompt / tool-affordance the local model sees — if the prompt no longer makes the model aware it CAN/SHOULD
  call tools for research intent (or a regression dropped the tool list from the local prompt), intent never converts to a
  call. Cross-ref SS-MV (local prompt assembly) + SS-CR (local must not mis-route to cloud — a mis-route kills the local
  tool loop entirely; if SS-CR's fix or a later change altered the local path, that could be why it stopped).
Harden so a tool-needing query (even simple) RELIABLY converts intent → tool call.

## Other reliability factors (verify each; harden where flaky)
Likely consistency factors (verify each; harden where flaky):
1. **Tool-call parsing fragility** — small local models emit imperfect tool-call syntax; `IncrementalToolCallDetector` /
   `LocalToolGrammar` may parse on a good run but miss on a malformed emission → the model "thinks" but no tool fires.
   Harden the grammar/detector to tolerate common Qwen-4B malformations (or grammar-constrain harder).
2. **Schema-preflight narrowing** — `SchemaPreflightToolNarrowing` may over-narrow the tool set on some prompts, hiding
   Eidos/vault/file tools from the model → it can't call them. Verify the research-shaped prompt keeps those tools available.
3. **ConfidenceRouter gating** — may route some turns to a direct answer instead of tool-calling → inconsistent "sometimes
   it researches, sometimes it doesn't." Verify the threshold for research-intent prompts.
4. **Tier/availability** — the tools must be SURFACED for the local tier (ToolTierBridge `surfacedTools`); if Eidos/vault/file
   tools aren't in the local model's tier on some launch, they won't fire. Cross-ref SS-MV (local models read vault) + SS-CR
   (local must not mis-route to cloud — a mis-route would break the local tool loop entirely).
5. **Eidos backend readiness** — Eidos/vault search needs the shadow/Eidos backend installed (cross-ref SS-IR: the shadow
   backend can be un-installed at launch → tools degrade); ensure honest "not ready" rather than silent no-op.

## Plan (verify → harden → regression-test) — tracked, normal order
1. **Reproduce + verify** the "research X → think → Eidos + vault-search + file-search multi-turn" path with a local model
   (Qwen 4B) end-to-end; capture where it drops (parse miss / narrowing / router gate / tool not surfaced / Eidos not ready).
2. **Harden the weak link(s)** found — most likely the tool-call parse robustness (#1) and tool-surfacing for the local tier
   (#4). Honest degrade (never silent) when a backend isn't ready (#5).
3. **Regression test** — a behavior test that a local-tier research prompt surfaces the Eidos/vault/file tools + the
   LocalAgentLoop executes ≥1 tool turn (the falsifier for "local multi-tool research works"). Cross-ref SS-AL (agent-loop
   robustness, done), SS-H (cross-engine tool/skill sharing).
NON-INVASIVE; test-backed; preserve SS-CR routing. This is the user-facing payoff of the substrate work (local models that
actually research) — verify it's reliable, don't let the one-good-chat be a fluke.
