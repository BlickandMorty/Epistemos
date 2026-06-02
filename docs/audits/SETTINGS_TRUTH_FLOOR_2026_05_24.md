# Settings Truth Floor Audit - 2026-05-24

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

Phase 2 Terminal T0 audited the Settings health projection surface against the verified-floor rule: a chip strip may be green only when it names a matching `artifacts/falsifiers/<name>/result.json` artifact whose result is PASS. ACS (Anchored Cognitive Substrate / Autopoietic Cognitive Stack) naming follows T25: first mention is expanded.

## Count Reconciliation

The dispatch prompt still says "24 rows", but `ls Epistemos/Views/Settings/*HealthRow.swift` on main now returns 26 files. This audit enumerates all 26 source files so no shipped row is orphaned by the stale count.

## Chip-Strip Rule

- Green chip strip: production posture only, and only with a matching PASS falsifier artifact.
- Orange chip strip: fixture, status-only, scaffold, production-pending, or falsifier-pending posture.
- Blue chip strip: research-only posture.
- No chip strip: ordinary status row; it must not imply production readiness elsewhere.

## 26-Row Enumeration

| # | HealthRow source | Classification | Production state shown today | Matching falsifier artifact |
|---|---|---|---|---|
| 1 | `ACSAdmissionHealthRow.swift` | production | Chip says `production gate active` and is green only with named falsifier. | `artifacts/falsifiers/acs_anchor_lookup/result.json` PASS |
| 2 | `APIKeysHealthRow.swift` | status-only | Credential presence only; no substrate production claim. | none |
| 3 | `AnswerPacketHealthRow.swift` | status-only | Emit ring / session status; chip is orange even when emitting. | none |
| 4 | `ArenaHealthRow.swift` | status-only | App-group arena file/materialization status only. | none |
| 5 | `CLIDiscoveryHealthRow.swift` | status-only | Pro-only executable presence probe; no runtime spawn claim. | none |
| 6 | `CognitiveDagCountsHealthRow.swift` | status-only | Read-only DAG count mirror; chip stays orange/secondary. | none |
| 7 | `CognitiveDagHealthRow.swift` | status-only | Read-only DAG mirror; chip stays orange/secondary. | none |
| 8 | `CognitiveWeightClassHealthRow.swift` | status-only | Badge taxonomy / enforcement status; chip stays orange until a production falsifier lands. | none |
| 9 | `DeploymentProfileHealthRow.swift` | status-only | Build-profile disclosure only. | none |
| 10 | `EditorBundleHealthRow.swift` | status-only | Bundle/Halo availability; chip stays orange because no production falsifier is attached. | none |
| 11 | `EidosHealthRow.swift` | fixture / production-pending | Fixture remains orange; real vault backend now says `production-vault - falsifier pending`, also orange. | none |
| 12 | `EmlObservatoryHealthRow.swift` | research-only | FFI/self-test visibility; chip stays orange and does not claim a live product stream. | none |
| 13 | `FUlpHealthRow.swift` | research-only | Research witness runner; chip is blue. | `artifacts/falsifiers/ulp_oracle/result.json` PASS, but not used for a green production chip |
| 14 | `FalsifierArtifactsHealthRow.swift` | status-only | Reads artifact directory and renders primary/fallback/failed status honestly. | row enumerates artifacts, not a production chip |
| 15 | `LatticeWBOHealthRow.swift` | status-only | Always-on accountant readout; chip stays orange until WBO drift artifact exists. | none |
| 16 | `LocalAgentDiagnosticsHealthRow.swift` | status-only | Grammar/drift/constellation counters; chip says placeholder routes and stays orange. | none |
| 17 | `OpLogProjectionHealthRow.swift` | status-only | EventStore -> Rust OpLog projection diagnostics only. | none |
| 18 | `PlanePlacementHealthRow.swift` | production | Five-plane field projection may be green only when FFI is reachable and fields are wired. | `artifacts/falsifiers/acs_anchor_lookup/result.json` PASS |
| 19 | `ProcessMemoryHealthRow.swift` | status-only | RSS and idle-unload diagnostic; no production substrate claim. | none |
| 20 | `RuntimeTruthHealthRow.swift` | status-only | Current mode/provider/tool-loop truth surface only. | none |
| 21 | `SearchFusionHealthRow.swift` | status-only | RRF flag and metrics status; chip stays orange even when metrics are live. | none |
| 22 | `ShadowSearchHealthRow.swift` | status-only | Halo/Shadow degraded-state diagnostics only. | none |
| 23 | `SubstrateDriftMonitorHealthRow.swift` | status-only | Drift monitor stays orange; F-WBO-DriftLedger is not passed on main. | none |
| 24 | `SystemGHealthRow.swift` | status-only | Dispatch seam is visible, but chip says falsifier pending and stays orange. | none |
| 25 | `UasAcsHealthRow.swift` | status-only / production-gated | Taxonomy/artifact status stays orange; production anchor lookup may be green only when the runtime adapter is wired. | `artifacts/falsifiers/acs_anchor_lookup/result.json` PASS for the production-anchor branch |
| 26 | `VaultRecallHealthRow.swift` | fixture | Trace scaffold remains orange; W-21 benchmark chip may go green only with the seeded-vault falsifier. | `artifacts/falsifiers/vault_recall_50/result.json` PASS for benchmark posture, not live user-vault production |

## Enforcement

- `EpistemosTests/VerifiedFloorChipStripAuditTests.swift` scans every Settings `*HealthRow.swift` source.
- Any `VerifiedFloorChipStrip` call that contains `.green` must include `falsifier: "<name>"`.
- The named artifact must exist at `artifacts/falsifiers/<name>/result.json` and report `status == "PASS"` or `overall_pass == true`.
- A probe row with `substrate: "production fake"` and `.green` but no falsifier is included and must be rejected by the audit helper.

## No-Orphan Check

Motion: Project / Compress / Recall. UAS: settings/verified-floor chip projection. Plane: Verification. Residency: CurrentApp. WBO/error: binary UI truth error only; no numeric approximation. Witness: this audit, source test, and PASS falsifier artifacts. Falsifier: `acs_anchor_lookup`, `vault_recall_50`, `ulp_oracle` as listed. Tier: T1 verified floor. Rollback: revert chip-strip tint/falsifier parameters and remove `VerifiedFloorChipStripAuditTests.swift` if the gate blocks a release incorrectly.
