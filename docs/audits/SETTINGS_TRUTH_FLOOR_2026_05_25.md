# Settings Truth Floor Audit - 2026-05-25

Terminal: T0 - Verified Floor / Settings Truth

Goal: Settings must not show a green substrate chip unless the row has both production wiring and a matching primary PASS witness/falsifier. A feature flag, metric counter, fixture trace, status mirror, fallback artifact, or test-only proof is not enough.

The dispatch prompt says "24 Settings rows." This checkout currently has 26 `*HealthRow.swift` files plus two adjacent Settings truth surfaces (`ActiveConstellationRow` and `AgentBlueprintSettingsView`). This audit enumerates all 28 guarded rows so no surface is omitted silently.

## Rule

`VerifiedFloorChipStrip` owns the green eligibility rule:

```text
green = productionWired && falsifierPassed
```

Every guarded row must pass:

- `productionWired`: the real production caller path is installed and observed by the row.
- `falsifierPassed`: the matching primary PASS witness is present for that production path.
- `falsifier`: the doc or audit path where the witness belongs.
- `wiredToday`: the exact thing Settings can honestly claim today.
- `stillStub`: the reason the row must remain non-green when either predicate is false.

## Row Ledger

| Row | Classification | Green status on this branch | Witness / falsifier path | Truth state |
|---|---|---:|---|---|
| `ACSAdmissionHealthRow` | status-only | blocked | `docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md` | strict policy summary is readable; Settings has not observed a production ACS admission witness |
| `APIKeysHealthRow` | status-only | blocked | `docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md` | credential presence is visible; no provider retention or tool-loop witness |
| `ActiveConstellationRow` | status-only | blocked | `docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md` | model hot/warm/cold state is visible; route table is still not a production-green claim |
| `AgentBlueprintSettingsView` | status-only | blocked | `docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md` | queues through Command Center; this page does not invoke System G directly |
| `AnswerPacketHealthRow` | status-only | blocked | `docs/falsifiers/F_WBO_DRIFT_LEDGER_2026_05_18.md` | in-process emitter is visible; canonical persistent AnswerPacket witness is pending |
| `ArenaHealthRow` | status-only | blocked | `docs/falsifiers/F-UAS-ZeroCopy-Spine_2026_05_17.md` | app-group arena path resolves; no mmap activation or zero-copy production witness |
| `CLIDiscoveryHealthRow` | status-only | blocked | `docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md` | filesystem CLI presence is visible; no CLI execution witness |
| `CognitiveDagCountsHealthRow` | status-only | blocked | `docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md` | DAG counts mirror is readable; no ACS anchor PASS witness |
| `CognitiveDagHealthRow` | status-only | blocked | `docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md` | DAG schema/status is readable; no mutation authority witness |
| `CognitiveWeightClassHealthRow` | status-only | blocked | `docs/falsifiers/F_WBO_DRIFT_LEDGER_2026_05_18.md` | weight badges are visible; policy enforcement is not green |
| `DeploymentProfileHealthRow` | status-only | blocked | `docs/audits/SETTINGS_TRUTH_FLOOR_2026_05_25.md` | compile-time MAS/Pro profile is visible; this is not a substrate falsifier |
| `EditorBundleHealthRow` | production asset check | blocked | `docs/falsifiers/F-ShadowFirst-PageEscalation_2026_05_17.md` | editor bundle and Halo-open status are visible; no primary retrieval witness |
| `EidosHealthRow` | fixture / production bridge observed only after real packet | blocked | `docs/falsifiers/F_EIDOS_CLOSED_CITATION_2026_05_18.md` | fixture path remains explicit; production vault packets still need a primary PASS witness before green |
| `EmlObservatoryHealthRow` | status-only / research-only | blocked | `docs/falsifiers/F-ULP-Oracle_2026_05_17.md` | self-test values are visible; SAE live stream is not production-green |
| `FalsifierArtifactsHealthRow` | production witness reader | eligible only for primary artifacts | `docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md` | primary artifacts may show green; fallback and legacy status artifacts may not |
| `FUlpHealthRow` | research-only | blocked | `docs/falsifiers/F-ULP-Oracle_2026_05_17.md` | witness can run; research-only oracle is not a MAS production surface |
| `LatticeWBOHealthRow` | production wiring, witness pending | blocked | `docs/falsifiers/F_WBO_DRIFT_LEDGER_2026_05_18.md` | accountant is always-on; WBO drift primary PASS witness is pending |
| `LocalAgentDiagnosticsHealthRow` | status-only | blocked | `docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md` | grammar/drift/model counters are visible; no local tool-use PASS witness |
| `OpLogProjectionHealthRow` | status-only | blocked | `docs/falsifiers/F_WBO_DRIFT_LEDGER_2026_05_18.md` | projection outbox and replay visibility are readable; no green mutation witness |
| `PlanePlacementHealthRow` | production wiring, witness pending | blocked | `docs/falsifiers/F-ACS-AnchorLookup_2026_05_24.md` | T14 plane counts are visible; schema-conforming primary PASS evidence is still required |
| `ProcessMemoryHealthRow` | status-only | blocked | `docs/audits/SETTINGS_TRUTH_FLOOR_2026_05_25.md` | RSS and idle-unload diagnostics are visible; this is not a substrate falsifier |
| `RuntimeTruthHealthRow` | status-only | blocked | `docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md` | mode/provider/tool-loop route is visible; route execution needs a primary PASS witness |
| `SearchFusionHealthRow` | status-only | blocked | `docs/falsifiers/F-ShadowFirst-PageEscalation_2026_05_17.md` | query metrics are visible; metrics are not a green retrieval witness |
| `ShadowSearchHealthRow` | status-only | blocked | `docs/falsifiers/F-ShadowFirst-PageEscalation_2026_05_17.md` | health metrics are visible without poking the index; no green retrieval claim |
| `SubstrateDriftMonitorHealthRow` | status-only unless snapshot marks pass | blocked by current snapshot | `docs/falsifiers/F_WBO_DRIFT_LEDGER_2026_05_18.md` | drift counters are visible; green requires `falsifier_passed=true` from the FFI snapshot |
| `SystemGHealthRow` | production seam, witness pending | blocked | `docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md` | RealSystemGRunSeam is registered/readable; ActiveAssembly/System G primary witness is pending |
| `UasAcsHealthRow` | status-only | blocked | `docs/falsifiers/F-UAS-ZeroCopy-Spine_2026_05_17.md` | UAS taxonomy and counters are visible; production anchor lookup remains non-green |
| `VaultRecallHealthRow` | fixture / stub trace | blocked | `docs/falsifiers/F-VaultRecall-50_2026_05_17.md` | F-VaultRecall-50 has primary artifact evidence, but the Settings trace remains synthetic until real VaultBackend binding is observed |

## Source Guard

`EpistemosTests/SettingsTruthFloorTests.swift` pins this ledger:

- every audited row must call `VerifiedFloorChipStrip`
- every chip call must include `productionWired`, `falsifierPassed`, `falsifier`, `wiredToday`, and `stillStub`
- no caller may pass a direct `substrateTint`
- the shared component must keep `productionWired && falsifierPassed` as the green gate
- this audit document must enumerate every guarded row

## No-Orphan Check

Motion: Project / Compress / Recall.

UAS / plane / residency: Settings projects existing substrate and status state only; it does not promote state.

WBO / error: non-production or status-only rows remain non-green and carry explicit tooltip caveats.

Witness / falsifier: linked per row above. Green is reserved for production wiring plus primary PASS witness.

Rollback: revert this T0 chip-strip contract and audit guard tests; no durable substrate data is mutated by this PR.
