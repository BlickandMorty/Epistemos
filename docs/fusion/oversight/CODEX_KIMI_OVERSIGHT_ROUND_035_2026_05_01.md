# Codex Kimi Oversight Round 035 - 2026-05-01

## Slice

R16 Sidecar Schema Mirror Audit.

## Kimi Advisory

Kimi was invoked in terminal read-only advisory mode. Kimi did not edit files.
The first invocation reached its step cap before a conclusion, then Codex
resumed the same advisory flow with a higher cap.

- Resume id: `1cf934a1-4ac0-4b4b-97b4-9015c4550f41`
- Kimi found no active Rust reader or writer for the Swift note sidecar
  contract at `<note-stem>.epistemos.json`.
- Kimi identified the Rust sidecar hits as unrelated sidecar families:
  `epistemos-code-index/src/sidecar.rs` for `.epcode.json`,
  `agent_core/src/storage/raw_thoughts.rs` for raw-thought sidecars,
  `epistemos-shadow` vector/index storage sidecars, and `graph-engine`
  retrieval-index serde aliases.
- Kimi found no stale Rust `deny_unknown_fields` decoder for the note sidecar
  contract.
- Kimi recommended closing Card 2 as docs-only and not inventing a Rust mirror
  inside this slice.

## Codex Audit

Codex independently audited the same surfaces:

- `Epistemos/Engine/EpistemosSidecar.swift` remains the Swift source of truth
  for note sidecars.
- `EpistemosSidecar.currentSchemaVersion == 3`.
- `child_concept`, `interpretation_directive`, `summary`, `tags`,
  `entities`, and `suggested_links` are optional additive fields.
- `AFMSidecarGenerator.persist(payload:for:)` writes generated payload fields
  through `EpistemosSidecarStore.write(..., modelDerived: true)`.
- The model-derived audit mark remains the
  `com.epistemos.modelDerived` extended attribute.
- `epistemos-code-index/src/sidecar.rs` is only the code artifact path mirror
  for `.epcache/code/*.epcode.json`.
- No active Rust `.epistemos.json` mirror or strict stale decoder was found.

## Files Changed By This Slice

- `docs/fusion/deliberation/r16_sidecar_schema_mirror_audit_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_035_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Verification

Search/audit logs:

- Broad mirror audit:
  `/tmp/epistemos-r16-sidecar-mirror-rg-audit-20260501.log`
- Rust targeted audit:
  `/tmp/epistemos-r16-sidecar-mirror-rust-targeted-audit-20260501.log`
- Swift targeted audit:
  `/tmp/epistemos-r16-sidecar-mirror-swift-targeted-audit-20260501.log`
- Kimi advisory:
  `/tmp/epistemos-r16-sidecar-mirror-kimi-advisory-20260501.log`

Focused Swift sidecar suite:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EpistemosSidecarTests test
```

- Log:
  `/tmp/epistemos-r16-sidecar-mirror-swift-sidecar-tests-20260501.log`
- Result: `16` Swift Testing tests in `1` suite passed.
- Xcode result: `** TEST SUCCEEDED **`

Focused AFM sidecar suite:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/AFMSidecarGeneratorTests test
```

- Log:
  `/tmp/epistemos-r16-sidecar-mirror-afm-sidecar-tests-20260501.log`
- Result: `3` Swift Testing tests in `1` suite passed.
- Xcode result: `** TEST SUCCEEDED **`

As with prior focused runs, Xcode still reports SwiftLint command failures for
`CodeEditSourceEditor` and `CodeEditTextView` after the successful test result.
This is inherited plugin/lint noise, not a sidecar-contract test failure.

## Guardrails

Guardrails are docs-only for this slice:

- No production Swift, Rust, generated binding, project, entitlement,
  `graph-engine`, `epistemos-shadow`, protected editor, or protected graph file
  was changed.
- The Card 2 stop trigger was honored: no Rust note sidecar mirror was created.

## Remaining Risks

- If a Rust note sidecar mirror is introduced later, it must explicitly accept
  v2/v3 payloads and optional `child_concept`, `interpretation_directive`,
  `summary`, `tags`, `entities`, and `suggested_links`.
- A future Rust mirror should include Swift fixture parity tests before
  production wiring.
- Full R16 WRV remains incomplete until worker execution, generated sidecar
  badge visibility, memory-pressure pause, and MAS bookmark enforcement land.
