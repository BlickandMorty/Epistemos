# Epistemos MAS Execution Status — 2026-07-10

Instruction lock: `MAS-ONLY-SHIP-LOCK-2026-07-07`

Daily execution authority:

- `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/00_READ_FIRST.md`
- `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/02_MASTER_BUILD_ORDER_AND_DEPENDENCY_GRAPH.md`
- `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/03_MINIMAL_PROMPT_PACK.md`

The July 8 canon has exactly five execution keys. Numeric prompt/plan shorthand
is not an execution-state key. Older numbered files under `docs/prompts/` are
provenance/spec appendices only.

## Canonical execution status

| Canonical execution key | Scope | Current status |
|---|---|---|
| `EPISTEMOS-MAS-PROGRAM-DIRECTOR-2026-07-08` | MAS alignment, one-product truth, verification ledger | **Complete for current alignment/static truth.** MAS-only lock, active target, parked lanes, and durable ledgers are established. Final archive truth remains in the current KEELSTONE key. |
| `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` | Storage, pruning, base-app truth, MAS release gate | **CURRENT.** Extensive source hardening exists, but exact current MAS runtime/archive evidence is open. Reproduced graph-embedded/hologram editor hangs and June local-model failure are current blockers. |
| `EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08` | MAS June Agent + Epdoc MiniChat/Assist | **Not active yet.** June/GGUF/cloud and Epdoc substrate exists because KEELSTONE must prove the base app, but this key opens only after KEELSTONE's exact done bar. |
| `EPISTEMOS-MAS-LUMENLENS-RECKONER-WORKSPACE-2026-07-08` | LUMENLENS + RECKONER unified workspace | **Pending.** Existing editor/provenance/minimal-writeback substrate does not make this key active or complete. |
| `EPISTEMOS-MAS-CAPABILITY-RING-2026-07-08` | ResearchHub + Quick Capture + Sync + MAS-safe PDF/Vision/Speech/WebKit browser-lite and related capabilities | **Pending.** Existing components may be reused only after required KEELSTONE and June seams are ready. |

Execution order is strictly the table order above.

## Current KEELSTONE blocker order

1. Graph-embedded and hologram editor load/typing hangs across Epdoc,
   Source/Code, Prose, and other editor surfaces.
2. June selected local GGUF models do not yet produce owner-proven output. The
   newest retained MAS archive exposes their rows but does not embed or link
   `llama.framework`; the gate now rejects that contradiction. OpenAI/Anthropic
   cloud output is untested.
3. Epdoc cross-surface switching has not yet proved that content, tables, and
   formatting survive without blanking or data loss.
4. Kokoro has not yet produced owner-proven audible English or an exact visible
   blocker.
5. Exact saved-vault quit/relaunch/save behavior and the current MAS archive
   release/leak/privacy gate still need current evidence.

## KEELSTONE exit matrix

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` exits only after one
current `Epistemos-AppStore` evidence chain proves:

1. The saved security-scoped vault restores after quit/relaunch and saves
   without `no vault URL`, truncation, or silent loss.
2. Epdoc opens, switches, and reopens without blanking or losing rich tables,
   formatting, or intentionally empty documents.
3. Prose, Source/Code, Epdoc, Quick Capture, embedded graph, and hologram graph
   accept input without the reported hangs; node-to-editor routing works.
4. Source/Code is editable through the real one-writer lease path.
5. June returns real selected-model output or a precise visible error; normal
   send does not run Prompt Forge/Hermes.
6. The selected local GGUF rows are June-owned; Qwen3 4B is admitted on the
   16 GB target, while Qwen3 8B and Qwen2.5 7B remain honestly RAM-gated.
7. Kokoro produces audible English or shows the exact bounded package/runtime/
   synthesis blocker.
8. The current MAS archive passes release, entitlement, privacy/package, and
   parked-lane leak checks.

## Retained MAS artifact gate

The newest retained archive is **RED with 12 findings**, grouped as:

- 2 June GGUF runtime findings: missing embedded `llama.framework` and missing
  app-executable linkage;
- 1 parked account/backend marker finding;
- 7 stale JuneWeb identity/configuration findings;
- 2 privacy-manifest collected-data findings.

The current source-only gate is green, so the next evidence action is one new
serial MAS archive—not another source-hardening sweep. The retained failure log
is `/tmp/keelstone-retained-app-gate-20260710.log`.

## Anti-stall rule

- The current editor/graph convergence batch is the source-freeze boundary.
- A new source edit must correspond to a failed KEELSTONE exit check, compile
  error, release-gate failure, or HIGH data-loss/security contradiction.
- Static search finding another optional micro-optimization is not enough.
- Reconcile source with low-RAM parse/gates, then run one serial,
  resource-capped evidence chain when memory conditions permit.
- Do not run parallel builds, broad suites, multiple archives, or concurrent
  model loads. Stop the evidence chain immediately if memory crosses its cap.
- A failed evidence leg gets one surgical fix and reruns only that leg. Passing
  evidence closes the current key and advances to
  `EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08`; it does not trigger
  another unlimited KEELSTONE sweep.

## Provenance-only crosswalk

Older `PROMPT_PLAN_*.md` and `MASTER_PLAN_INDEX_2026_07_03.md` labels may still
describe feature requirements, but they do not control execution keys or daily
order. Their content maps into the final canon only as directed:

- older June/agent material →
  `EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08`;
- older Editor/LumenLens and data/Reckoner material →
  `EPISTEMOS-MAS-LUMENLENS-RECKONER-WORKSPACE-2026-07-08`;
- older ResearchHub, Quick Capture, Sync, and capability material →
  `EPISTEMOS-MAS-CAPABILITY-RING-2026-07-08`;
- Companion/Kindred runtime and Experimental/1Code remain parked provenance.

## Next execution key

Remain in `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. After its exact
MAS evidence bar passes, proceed to
`EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08`, then
`EPISTEMOS-MAS-LUMENLENS-RECKONER-WORKSPACE-2026-07-08`, then
`EPISTEMOS-MAS-CAPABILITY-RING-2026-07-08`.
