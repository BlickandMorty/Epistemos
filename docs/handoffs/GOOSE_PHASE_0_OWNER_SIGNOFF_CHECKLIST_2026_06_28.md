# Goose Phase 0 — Owner §7 Sign-Off Checklist (2026-06-28)

Branch: `feat/goose-surface`. Prepared by the Claude deep-hardening loop.
**Phase 0 is NOT signed off.** This checklist is the §7 gate: the items only
*you* (owner) can verify, plus the one OAuth login the automated proofs cannot
perform. Nothing here starts Phase 1 / `Epistemos/Agent/*` / Paseo §15.

---

## What the automated proofs already established (re-runnable)

Built on an isolated DerivedData (CoW-cloned SourcePackages) to avoid the
concurrent-agent build race. Combined live sweep, real `goose serve` 1.39.0:

```
✔ Test run with 5 tests in 5 suites passed
  provider catalog:  65 providers / 413 models  (catalog_source=goose_serve_acp_only)
  session lifecycle: prompt end_turn; persisted session listed; fork differs
  custom capability: recipe-id reconciled (by_path), session launched
  web prompt:        renderer submits, streams to end_turn
  web route smoke:   all owner routes render with their ACP methods seen
```

- GOLDEN RULE: 0 hardcoded provider/model rosters in `Epistemos/Goose/*.swift`.
- No silent ACP drops: unknown methods → structured diagnostic + JSON-RPC `-32601`.
- Secrets: Keychain via `GooseProviderKeyBridge` (never UserDefaults).
- Thermonuclear hardening: per-frame ACP decode containment; reconnect recovery
  (budget reset + `connectionKey` clear); stale-prompt cancellation; nav `file:`
  scheme removed. 5/5 sweep stays green after these edits.
- Repaired Web UI re-staged to `~/Library/Application Support/Epistemos/GooseWebUI`.

Evidence: `docs/handoffs/GOOSE_PHASE_0_VERIFICATION_2026_06_27.md` (2026-06-28
addendum), `docs/handoffs/GOOSE_PHASE_0_THERMONUCLEAR_FINDINGS_2026_06_28.md`,
proof logs under `/tmp/epistemos-goose-phase0-*.log`.

---

## Feature-parity closures since this checklist was first written (2026-06-28 PM)

Directly addressing your "feature completeness 100% is the main gate" — the
silently-missing controls (dead `@/api` REST not grafted to ACP) found and fixed,
each gated by a strict test and re-proven by the 5/5 live sweep:

- **Thinking Effort** now end-to-end: appears (live inventory `reasoning`),
  applies to the agent (`setSessionConfigOption thinking_effort`), and PERSISTS
  across restart (`preferencesSave/Read_unstable`). (`c4995667b`)
- **First-run welcome provider grid** populates from the live ACP catalog
  (OnboardingGuard → ProviderSelector); was an empty dead-REST dropdown — your
  "my app is not doing that at all." (`af1521aa3`)
- **Custom-provider CRUD** (add/edit/delete) bridged onto
  `providersCustom*_unstable`; adding/editing a custom provider previously threw
  silently. (`05a9f4e65`)
- Model switcher / config-status / auth credentials (earlier this loop).
- Gate test `stagingGraftsWireLiveParityFeatures` now carries **39 assertions**
  locking every graft (passes 0.049s); the parity-gate IS the regression guard
  you asked for ("deep hardened strict tests moving forward").

Still tracked (verify-then-fix, not yet grafted): tools/permissions list
(`toolsList_unstable` — needs live extension-prefix filtering check), dictation,
agent-mode cross-restart persistence (no `GOOSE_MODE` preference home in 1.39.0).

### Feature-completeness DEFINITIVELY assessed (your primary gate)

A 10-agent audit swept ALL 42 ungrafted Goose UI components that touch the dead
`@/api` REST surface (`docs/handoffs/GOOSE_MISSING_FEATURE_AUDIT_2026_06_28.md`).
Result: **35 are NOT missing features** (types-only / already-ACP-wired /
dead-branch / non-ACP native carve-outs), and **7 are genuine gaps** — of which
**1 was a clean fix (AlertBox threshold save, grafted `80de32ab7`)** and the other
**6 are NOT silent bugs but product decisions or features with no ACP method**:
PermissionModal-save + Prompts have **no ACP persistence method** (implement native
or hide); Dictation needs a **graft-vs-native** decision (Epistemos has native
voice); MCP-App rendering needs a goosed-only host; toolsCache/PermissionModal-load
need a live extension-filter check. So the residual is **bounded and named, not an
unknown "things are silently missing"** — the surface is feature-complete for
everything ACP can express.

### 2026-06-28 evening — Path-A grafting exhausted + Path-B gating risk cleared

Closing out the "Both: graft ACP gaps now, plan Path B" decision:

- **toolsCache (#1) shipped + gate-locked** (`listAcpSessionTools` via
  `toolsList_unstable` with a full-list fallback so a tool-name casing mismatch can
  never be worse than the silent-null REST it replaces; +7 parity-gate assertions).
- **PermissionModal (#3) — deliberately NOT half-grafted (verify-then-fix).** Its
  tool-LOAD is ACP-graftable, but per-tool SAVE (`upsertPermissions`) has no ACP
  method. A LOAD-only graft would make the modal LOOK functional while silently
  discarding saves — a NEW silent failure, strictly worse than today's honest
  load-error. It is both-halves-or-nothing → Path B.
- **Path-A graft work is now EXHAUSTED of safe, non-throwaway items.** Every residual
  gap is Path-B (#3 Permission-save, #5 MCP-app, #6 Prompts), a no-op (#2 Extension
  env_keys are references not secrets), or a "don't rush" native-vs-graft call
  (#4 Dictation — Epistemos has native voice).
- **Path-B gating risk RESOLVED, verdict FAVORABLE.** Source-level check: `goosed
  agent`'s tunnel/gateway tasks are network-only (zero subprocess spawning → same
  launched-server shape as the already-accepted `goose serve`, no new sidecar vs
  CLAUDE.md's no-subprocess rule); the two entitlements it needs (`network.client`
  + `network.server`) already ship. Caveats named (wider network surface for MAS
  review; the shared "is a launched goose binary MAS-distributable at all" question
  is unchanged, not regressed). See `GOOSE_PATH_B_FULL_GOOSED_MIGRATION_PLAN...md`.

**→ OWNER DECISION NEEDED to make further automated progress:** start Path-B
*implementation* (bundle `goosed`, swap the supervisor to `goosed agent` behind a
build flag, Path A stays default until proven) — which makes Prompts / Permission-
save / MCP-app work natively — **or** stay Path-A and have me honest-gate (hide) the
no-ACP-method controls so nothing looks functional-but-silently-broken. Until you
pick, and until the shared Swift test bundle unblocks (another agent's
`CodeEditorPolishTests`), no further safe Goose code work remains this loop.

---

## OWNER — manual app pass (please click through and confirm)

> Note: every route below is ALSO covered by the automated live WebRoute suite
> (`GooseWebRouteLiveIntegrationTests`, green this pass), which asserts each route
> renders its real heading AND fires its real ACP method (not dead REST) —
> `/apps`, `/schedules`→`schedules/list`, `/recipes`→`recipes/list`,
> `/sessions`→`session/list`, `/skills`→`sources/list`, `/extensions`→
> `config/extensions/list`, `/settings?section=models|auth`, `/configure-providers`
> — with empty-state text (e.g. "No apps available") accepted and error-boundary
> text forbidden. Your manual pass is final confirmation, not first discovery.

Launch the current Debug build:

> ⚠️ **IMPORTANT — relaunch to pick up the fixes.** The Goose surface loads its Web
> UI from `~/Library/Application Support/Epistemos/GooseWebUI` at launch. All the
> parity fixes from this loop (welcome provider grid, model switcher / config-status,
> Thinking-Effort persistence, custom-provider add/edit/delete) live in that
> re-staged bundle. If an Epistemos instance is still running from BEFORE the
> re-stage, it shows the OLD surface — which would look like "still broken." **Quit
> any running Epistemos (Cmd-Q) first, then open the build below.** (The bundle is
> already current; you do NOT need to rebuild for these Web-UI fixes. A rebuild is
> only needed if you also want the Swift-side hardening from this loop.)

```
# quit any running instance first, then:
/usr/bin/open "/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app"
```

- [ ] **Cmd-3 opens Goose.** Open the details/slider panel. It reads exactly
      `native ACP Goose ready (1.39.0)` and `custom ACP Goose ready`
      (NOT a vague "Goose ACP ready").
- [ ] **Settings → Auth**: no `Failed to load provider credentials`. Configured
      providers list their credential fields; empty providers show an empty
      state, not a toast error.
- [ ] **Settings → Models → Switch models**: the provider picker auto-populates
      from the Goose ACP catalog. (A provider-specific model error for a local
      provider whose server is off — e.g. LM Studio/Ollama — is acceptable and is
      NOT the same as a generic "ACP WebSocket connection failed".)
- [ ] **Settings → Models → Thinking Effort**: for a reasoning-capable model the
      effort selector is visible, changing it applies, and it survives an app
      restart (newly persisted this pass).
- [ ] **First run / welcome**: with no provider configured, the welcome screen's
      provider list is populated (not empty) and configured providers read as
      ready.
- [ ] **Settings → Models → Add custom provider** (and edit/delete an existing
      one): the form saves without a silent failure; the new provider appears and
      is selectable.
- [ ] **New Chat**: the prompt input appears after loading; the default
      provider/model shows; a tiny prompt streams and returns.
- [ ] **Apps**: route loads. `No apps available` is fine; a generic
      `Error loading apps` is not.
- [ ] **Recipes**: route loads; save-and-run does not throw `recipe not found`.
- [ ] **Session History**: route loads; a recently-prompted session appears; no
      generic `Error Loading Sessions`.
- [ ] **Skills / Scheduler / Extensions**: routes load without generic error
      boundaries.
- [ ] **(Edge) Reconnect**: with Goose open, kill `goose serve` and let it
      restart (or toggle the runtime); the surface recovers or shows an honest
      blocked state — no stale provider errors. *(Newly hardened this pass.)*

## OWNER — the OAuth login the proofs cannot perform

- [ ] **Browser-mediated provider OAuth success.** Pick an OAuth provider
      (e.g. the one you normally use), run its sign-in from Settings → Auth, and
      confirm a configured/authenticated status comes back and a prompt then
      streams. This is the Gate-5 item that requires your interactive browser
      session; the automated suite can only prove the non-OAuth rejection path.

---

## Gate status (honest)

| Gate | Status | Note |
| --- | --- | --- |
| 1 Real Goose Electron fallback launches | PASS (prior pass) | not re-run this pass; comparison fallback only |
| 2 `goose serve` ACP WS reachable | PASS | every proof log shows live `/acp` init |
| 3 new→prompt→stream→permission→result | PASS, except live `agent_thought_chunk` | thinking chunk is provider-dependent / codec-test-only — needs a live thinking emit OR your §7 amendment |
| 4 Staged Web UI boots via shim | PASS | route smoke green |
| 5 Nothing lost vs real Goose | PARTIAL | owner OAuth success, true confirm-dialog/MCP-app window affordances, MAS/manual/distribution WRV still open |

## Remaining non-owner work before/after sign-off (tracked)

- Gate 3 live thinking chunk, or your explicit §7 amendment that Goose no longer
  emits it on the supported path.
- Gate 5: true confirm-dialog / MCP-app window affordances proven or honestly
  demoted; MAS honest-gate + manual WRV + distribution preflight.
- 24 deferred thermonuclear findings (documented backlog) — future hardening loops.

**Sign-off:** reply with your decision once the manual pass + OAuth login above
are confirmed (or amend Gate 3). Until then Phase 0 stays open and no Phase 1 /
hybrid AppKit / Paseo work begins.
