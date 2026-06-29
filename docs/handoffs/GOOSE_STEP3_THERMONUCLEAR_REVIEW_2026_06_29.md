# Step 3 — thermo-nuclear code-quality review of the native Models slice (2026-06-29)

Adversarial review (independent agent, second perspective) over the 5 Step-3 files:
`GooseSurfaceRouter.swift`, `GooseNativeModelsView.swift`, the new `GooseACPEventBridge`
passthrough, `GooseACPProviderInventoryEntry`/`Model` in `GooseACPProtocol.swift`, and
`GooseACPClient.listGooseProviderInventory()`. Scope: real bugs only — concurrency, logic,
edge cases, decode fragility, parity gaps, GOLDEN-RULE violations.

## Findings (5) — ALL fixed + committed separately, build green

| # | Sev | Finding | Fix | Commit |
|---|-----|---------|-----|--------|
| 1 | HIGH | `reload()` can hang forever on `.loading` — the ACP client has no per-request timeout, so a server that accepts a request but never replies parks the await with no user escape | 20s sibling-task timeout → honest "Timed out — Retry?" state | `f89eb8649` |
| 2 | MED | `applySelection` race — pickers stayed live during save; post-await summary could show a provider/model pairing never saved | atomic capture of provider+model before the await + `.disabled(isSaving)` on both pickers | `f89eb8649` (capture also in `6799e0cc4`) |
| 3 | MED | one malformed model ELEMENT dropped the whole provider — `models` array decode threw on shape/type drift | per-element lenient decode (`[JSONValue]` → compactMap), plus entry-level compactMap in `listGooseProviderInventory` | `6a56961f9` |
| 4 | LOW | a live default pointing at a provider absent from `providers/list` → invalid/blank Picker selection | seed selection only from a provider present in the inventory, else first | `f89eb8649` |
| 5 | LOW | Retry spawned overlapping reloads racing on shared `@State` | monotonic `loadGeneration` guards every state write | `f89eb8649` |

## Confirmed CLEAN (independent corroboration)
- `GooseSurfaceRouter` — the HARD GATE holds: `enabledRoutes = requested.intersection(nativeCapableRoutes)`;
  with nothing enabled every route resolves to `.web`. No path defaults a route to native; no
  non-capable route can be promoted (even `all` flows through the intersection).
- `GooseACPEventBridge` passthrough — each is `guard let client else { throw .notConnected }` + forward;
  the locally-captured `client` keeps the actor alive across a concurrent `disconnect()` (teardown
  resumes the in-flight continuation with `.closed`, surfacing an error rather than hanging).
- GOLDEN RULE — zero provider/model names across all five files (code, comments, strings). Decode
  round-trips keys literally (no snake_case conversion); struct fields match live camelCase.

## Verification
- `** BUILD SUCCEEDED **` (app target, iso-DD) after all fixes.
- Focused post-fix live pass (re-runnable: `scripts/goose-native-models-probe.sh`):
  `NATIVE_MODELS_PARITY_PASS` — providers/list 65, 53 carry inline models, default openai present.
- GOLDEN RULE roster guard: clean on all edited files (exact case-sensitive roster + case-insensitive
  model-stem scans, zero hits).

Recursive-proof status for this repaired area: focused pass GREEN (1/3). The two further no-code-change
clean passes accrue across subsequent loop iterations.
