# SS-F — Settings robustness (persistence / honest-gating / silent-fail) (2026-06-19)

Read-only research (subagent), code-grounded. Feeds the settings-robustness + "LEFT-UNCHANGED-BY-SIMPLIFICATION"
ledger items. Owner: *"things totally left unchanged by simplification — make it more robust."* Balance:
simplify presentation, NEVER delete/hide; honest gating (no green without a witness); no-fake. Cross-refs SS-B
(sprawl), SS-Y (orphan loop), SS-X (chat-bar), SS-U/SS-W (crashes).

## Headline
Persistence is **mostly honest** (the `@AppStorage` + `*Flags.userDefaultsKey` single-source pattern is real;
Eidos/VaultRecall/SystemG/ACS/FUlp/PromptTree all have verified runtime readers). But simplification left
**three concrete holes:** (1) a **FAKE config toggle** — `EPISTEMOS_GRAPH_INDEX_CHATS` is wired to a switch with
**zero runtime readers** (Swift OR Rust; self-admitted "status-only"); (2) **two orphan HealthRows**
(`CognitiveDagHealthRow`, `HyperdynamicLoopHealthRow`) defined but **never instantiated**, the loop row
hardcoded "no read yet"; (3) **General/Session settings bypass `@AppStorage`** with hand-rolled `@State` + raw
`UserDefaults` snapshots that drift on defaults + don't re-read on service mutation. Worst: the **flag↔witness
split** — the only fake/witness-less flags (`graphIndexChats`, `rrfFusion`, `powerUserMode`) are exactly the
ones with no co-located proof. Every gap is a HARDEN, none requires deleting functionality.

## Persistence gaps
- **Raw-UserDefaults `@State` snapshots bypass `@AppStorage` (drift + stale-read).** `GeneralDetailView`
  hand-rolls three settings as `@State` reading raw UserDefaults:
  - `restoreLastSession` (`SettingsView.swift:772-774`, writes via `WorkspaceService.swift:319-322`, same key — OK).
  - `showSaveOnQuit` (`:775-779`, the SS-B raw-key; key `epistemos.showSaveOnQuitDialog`, consumed `EpistemosApp
    .swift:1165,1180,1307` — persists, lone fully-manual round-trip).
  - **`summaryInterval` — REAL DEFAULT-DRIFT BUG (`:780-783`):** settings `@State` defaults to `"15m"`/
    `.fifteenMinutes` but the service truth (`WorkspaceSummaryService.swift:24-25`) defaults to `"5m"`/
    `.fiveMinutes`. On fresh install the **picker shows 15m while the engine runs 5m** until the user touches it.
    Silent UI/runtime disagreement.
  - **Stale-read (all three):** snapshot into `@State` at view-init + only write outward → if a service mutates
    the key later, the toggle shows a stale value (no `@AppStorage` observation). `@AppStorage` fixes all three.
- Healthy contrast: retention numerics use `@AppStorage(AppDataRetentionPolicy.*Key)` (`:789-800`); substrate
  flags use `@AppStorage(*Flags.userDefaultsKey)` single-source (`:1385-1394`). No typo/key-mismatch found there.

## Silent-fail / fake-state / no-witness
- **FAKE CONFIG TOGGLE (CLAUDE.md "no fake features" violation):** `EPISTEMOS_GRAPH_INDEX_CHATS` toggle
  (`SettingsView.swift:1386,1406-1410`). **Zero runtime readers** (only hits are the toggle's own decl/key/
  binding; `grep GRAPH_INDEX_CHATS` over `agent_core` empty). Detail string self-admits "Reserved UserDefaults
  flag; status-only until a runtime reader lands." Flipping it does NOTHING — textbook config-UI-for-an-unwired-
  field.
- **ORPHAN WITNESS ROWS (SS-B/SS-Y confirmed):** `HyperdynamicLoopHealthRow.swift:22` **never instantiated**
  (0 external refs, not in `SubstrateHealthPanel`); body hardcodes "no read yet (loop bridge not yet wired)"
  (`:19-20`); `ingest(...)` `:247` zero callers (SS-Y). `CognitiveDagHealthRow.swift:23` **never instantiated**
  (the panel shows the DIFFERENT `CognitiveDagCountsHealthRow` `SubstrateHealthPanel.swift:134` → the variant is
  a stranded duplicate).
- No "green without a witness" among DISPLAYED rows — Eidos/SystemG/ACS keep the chip orange until a falsifier
  passes (`:1426,1444,1450`). The honesty discipline is real where rows are shown; the failure is rows/flags
  NOT shown.

## Validation / honest-gating (mostly healthy)
- Numeric inputs well-guarded: `timeMachineMaxSnapshots 5...500` (`:866`), `savedWorkspaceLimit 0...200` (`:872`),
  `tokenCapDraft 500...32000` (`:1937`); clamps `min(max(...))` (`AppDataRetentionPolicy.swift:97,101`). No
  free-text port/range field accepting invalid input found.
- MAS firewall consistent: `safeDetailSelection` (`:181-235,404-481`) + `#if EPISTEMOS_APP_STORE||MAS_SANDBOX`
  on Channels/iMessage/CLIDiscovery/FineTune/ActOsaurus. No MAS build found exposing an unhonorable control
  (*unverified* — didn't compile both flavors; guards present at every direct-distribution surface checked).
- Cloud keys/OAuth → Keychain not UserDefaults (`:2902,2906`), per CLAUDE.md.

## Flag→witness gaps (flag-ON ≠ done)
- **Two-section split (SS-B):** toggles in `ExperimentalFeaturesSettingsPanel` (`.experimentalFeatures`
  `:499,1384`); witnesses in `SubstrateHealthPanel` (`.substrateHealth` `:498`, rows `SubstrateHealthPanel.swift
  :31-143`). Toggle in one pane, proof in another.
- **Witness-less flags:** `graphIndexChats` (no reader — fake); `rrfFusion` (real readers `VaultSyncService
  .swift:2914+` but NO named HealthRow — `SearchFusionHealthRow` covers fused-search latency, not this flag);
  `localAgentPowerUserMode` (real readers in `AppBootstrap`/`LocalModelInfrastructure` but only an in-panel
  `LabeledContent` + "relaunch" label `:1468-1477`, no health witness). Verified WITH witnesses: Eidos/
  VaultRecall/SystemG/ACS/FUlp/PromptTree (each has a `*Wiring.swift` + `*HealthRow`).

## Surfaces skipped by simplification
- Raw-`@State` cluster `GeneralDetailView` (`:772-783`) — never converted to `@AppStorage`.
- Orphan rows `CognitiveDagHealthRow` + `HyperdynamicLoopHealthRow` — left, never wired/never deleted.
- `EPISTEMOS_GRAPH_INDEX_CHATS` — live switch over a no-op key.
- Demo-ish panels reachable but unhardened: `FineTuneMarketplaceView` (from `ModelVaultsSettingsView.swift:175`),
  `StructuredSurfacesView` (from `AgentSectionDetailView.swift:138`) — MAS-guarded but SS-B "demo" smell, control→
  runtime wiring *unverified*.
- (`EditorBundleHealthRow` raw-UserDefaults is a deliberate test-seam `defaults:UserDefaults = .standard`, NOT
  drift — healthy; noted to pre-empt a false positive.)

## Ordered plan (harden, never delete)
1. **[S]** Fix `summaryInterval` default drift — make the settings `@State` default match the service truth (5m)
   or convert to `@AppStorage("epistemos.summaryInterval")` (one source). `:780-783` vs `WorkspaceSummaryService
   .swift:24`.
2. **[S]** Convert the three `GeneralDetailView` raw-`@State` settings to `@AppStorage` — kills stale-read +
   drift. `:772-783`.
3. **[M]** Resolve `EPISTEMOS_GRAPH_INDEX_CHATS` — wire the runtime reader OR demote the `Toggle` to a disabled
   "reserved (not yet wired)" status row so it can't masquerade as functional. `:1386,1406-1410`. (Harden, don't
   delete.)
4. **[M]** Re-home/honestly-gate the orphan rows — instantiate them behind their real witness (+ wire
   `HyperdynamicLoopMetrics.ingest`, SS-Y) OR mark `#if DEBUG`/"not wired" so they're not silently dead.
   `HyperdynamicLoopHealthRow.swift:22,247`, `CognitiveDagHealthRow.swift:23`.
5. **[M]** Co-locate flag→witness — add a witness chip for `rrfFusion` + `powerUserMode` next to their toggles
   (or a compact witness strip inside `ExperimentalFeaturesSettingsPanel`) so flag-ON shows live proof in-pane.
   `:1384-1478` ↔ `SubstrateHealthPanel.swift`.
6. **[L]** Audit `FineTuneMarketplaceView` + `StructuredSurfacesView` for end-to-end runtime wiring; harden any
   fake/demo controls (MAS-guard already present).

## Unverified
Did not compile MAS vs direct builds (firewall asserted from source guards); did not trace FineTune/
StructuredSurfaces control→runtime end-to-end.

Key files: `Views/Settings/SettingsView.swift` (`GeneralDetailView` raw-state `:772-783`, `ExperimentalFeatures
SettingsPanel` `:1384-1501`, MAS firewall `:181-481`) · `Views/Settings/SubstrateHealthPanel.swift:26-143` ·
`Views/Settings/HyperdynamicLoopHealthRow.swift:22,247` + `CognitiveDagHealthRow.swift:23` (orphans) ·
`State/WorkspaceService.swift:315-322` + `WorkspaceSummaryService.swift:13-31` (the 5m/15m mismatch) ·
`State/EpistemosConfig.swift:14-47` (canonical `@AppStorage` pattern) · `State/AppDataRetentionPolicy.swift
:87-101` (validation done right). Cross-refs: SS-B, SS-Y, SS-X, SS-U/SS-W.
