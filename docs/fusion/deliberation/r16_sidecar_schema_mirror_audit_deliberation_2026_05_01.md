# R16 Sidecar Schema Mirror Audit Deliberation - 2026-05-01

Closure refreshed on 2026-05-02 by Codex after re-running the Rust/Swift
schema-surface audits and focused Swift sidecar tests. The May 2 evidence still
supports the original docs-only verdict: no active Rust note-sidecar mirror
exists, so no Rust mirror should be invented in this card.

## Verdict

Approved as a docs-only audit slice under Card 2.

The audit found no active Rust-side reader or writer that mirrors the Swift
note sidecar contract for `<note-stem>.epistemos.json`. Because the Card 2 stop
trigger applies, this gate does not approve creating a Rust mirror, bumping the
sidecar schema, changing generated bindings, or editing production code.

## Scope

- Audit the current Swift note sidecar source of truth in
  `Epistemos/Engine/EpistemosSidecar.swift`.
- Audit the AFM sidecar writer in `Epistemos/Engine/AFMSidecarGenerator.swift`.
- Search Rust and Swift surfaces for active `.epistemos.json` mirrors, strict
  decoders, stale `deny_unknown_fields` contracts, and unrelated sidecar
  schemas.
- Record the result and future-contract requirements for any later Rust mirror.

## Authority Evidence

- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
  Card 2 requires a docs-only audit if no actual Rust sidecar mirror exists.
- `docs/fusion/deliberation/w1012_sidecar_interpretation_directive_deliberation_2026_04_30.md`
  established the Swift note sidecar as schema v3 and preserved v2 decode
  compatibility.
- `docs/fusion/deliberation/r16_afm_sidecar_generation_pr3c_deliberation_2026_05_01.md`
  added optional AFM payload fields through the Swift sidecar store only.
- `Epistemos/Engine/EpistemosSidecar.swift` is the active Swift source of truth
  for the note sidecar JSON contract.
- `Epistemos/Engine/AFMSidecarGenerator.swift` writes generated payload fields
  through `EpistemosSidecarStore.write(..., modelDerived: true)`.

## Audit Result

No active Rust `.epistemos.json` mirror was found.

Confirmed active Swift note sidecar contract:

- `schema_version` is current version `3`.
- `child_concept` and `interpretation_directive` remain optional.
- `summary`, `tags`, `entities`, and `suggested_links` are additive optional
  AFM payload fields.
- `suggested_links` uses snake-case JSON and contains `target_id`, `title`, and
  `reason`.
- Model-derived provenance is stored as the
  `com.epistemos.modelDerived` extended attribute by `EpistemosSidecarStore`.

Confirmed non-mirrors:

- `epistemos-code-index/src/sidecar.rs` mirrors
  `Epistemos/Models/CodeArtifactSidecar.swift` path hashing for
  `.epcache/code/*.epcode.json`; it is not the note sidecar schema.
- `agent_core/src/storage/raw_thoughts.rs` contains raw-thought sidecar structs;
  they are not `<note-stem>.epistemos.json`.
- `epistemos-shadow` sidecar references are vector/index storage sidecars, not
  note sidecar schema readers.
- `graph-engine` has retrieval-index serde aliases, not note sidecar readers.

## Allowed Files

- `docs/fusion/deliberation/r16_sidecar_schema_mirror_audit_deliberation_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_035_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Forbidden Files

- `Epistemos/Engine/EpistemosSidecar.swift`
- `Epistemos/Engine/AFMSidecarGenerator.swift`
- `EpistemosTests/**`
- `agent_core/**`
- `epistemos-shadow/**`
- `graph-engine/**`
- generated bindings, generated libraries, project files, entitlements,
  DerivedData, `.xcresult`, stash, or branch operations. Exact-file
  staging/commit by the overseer is allowed only under the user's active
  commit-as-you-go instruction.

## Future Contract

If a Rust note sidecar mirror is introduced later, it must:

- accept `schema_version` v2 and v3 payloads;
- treat `child_concept`, `interpretation_directive`, `summary`, `tags`,
  `entities`, and `suggested_links` as optional additive fields;
- avoid `deny_unknown_fields` unless compatibility tests prove legacy and
  forward payloads continue to decode;
- preserve the code-file exclusion rule for `.epistemos.json`;
- avoid confusing note sidecars with `.epcode.json`, raw-thought, vector, or
  retrieval-index sidecars;
- include parity tests against Swift fixture JSON before production wiring.

## Tests And Logs

- Broad mirror audit:
  `/tmp/epistemos-r16-sidecar-mirror-rg-audit-20260501.log`
- Rust targeted audit:
  `/tmp/epistemos-r16-sidecar-mirror-rust-targeted-audit-20260501.log`
- Swift targeted audit:
  `/tmp/epistemos-r16-sidecar-mirror-swift-targeted-audit-20260501.log`
- 2026-05-02 Rust mirror refresh:
  `/tmp/epistemos-r16-sidecar-schema-rust-mirror-audit-20260502.log`
- 2026-05-02 Swift active-surface refresh:
  `/tmp/epistemos-r16-sidecar-schema-swift-surfaces-20260502.log`
- 2026-05-02 strict-decoder refresh:
  `/tmp/epistemos-r16-sidecar-schema-strict-decoder-audit-20260502.log`
- 2026-05-02 focused Swift sidecar tests:
  `/tmp/epistemos-r16-sidecar-schema-swift-green-20260502.log`

The focused Swift run passed the selected `EpistemosSidecarTests` suite: 18
Swift Testing tests in 1 suite passed. Xcode still printed the pre-existing
SwiftLint package plugin failures for `CodeEditTextView` and
`CodeEditSourceEditor` after `TEST SUCCEEDED`; the command exited 0.

## Acceptance

- The active sidecar surfaces are documented.
- No Rust mirror is invented inside this docs-only slice.
- Future agents have explicit field requirements if they later open a Rust
  sidecar mirror gate.
- Card 2 is closed as an audit-only no-op for code: Swift remains the active
  read/write source, and Rust has no note-sidecar reader/writer to patch.

## Stop Triggers

- A real active Rust note sidecar mirror is discovered.
- A migration is needed for existing user sidecars.
- Any compatibility test fails.
- Any production code change becomes necessary.

## WRV

This is a contract-audit slice, not a user-facing feature slice.

- Wired: no additional wiring is authorized because no Rust mirror exists.
- Reachable: active reads and writes remain through Swift
  `EpistemosSidecarStore`.
- Visible: this gate and the oversight record document the current contract and
  the no-mirror result.
