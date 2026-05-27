# Tri-Fusion Typed Mutations - 2026-05-27

Status: Wave 4 follow-up slice, one safe model-authored note edit.

## Scope

This slice adds `ModelAuthoredNoteMutation`, a narrow app-side path for a model-authored append-section note edit. It builds a typed committed `MutationEnvelope`, a rollback body, and a witness before any caller persists text.

It does not replace the editor, mutate per-keystroke state, or bypass the existing Rust Tri-Fusion corpus. The Rust `agent_core/src/tri_fusion/` fabric remains the substrate owner for structured JSON mutations; this Swift slice makes the app-side commit discipline explicit for one safe note operation.

## No-Orphan Check

Motion: Mutate / Project. Model-authored text becomes an artifact update carried by `MutationEnvelope`.

UAS: The touched artifact and touched block are explicit through `EpdocArtifactRef` and `MutationBlockRef`.

Plane: Assembly/Verification plane. The body change is staged as a deterministic plan, then committed with provenance.

Residency: CurrentApp. No subprocess, remote caller, or graph/editor hot-path dependency.

WBO: The witness carries before/after/rollback SHA256 hashes. No fuzzy or approximate text edit is claimed.

Witness: `ModelAuthoredNoteMutationWitness` plus `MutationEnvelope.integrityHash`.

Falsifier: `ModelAuthoredNoteMutationTests` prove the envelope fields, body/envelope two-phase commit, rollback-on-envelope-failure, invalid-input rejection, and source guard against raw page body mutation.

Tier: T1 MAS-safe. The operation is local, deterministic, reversible, and internal sensitivity.

Rollback: `ModelAuthoredNoteMutationRollback.body` is the exact pre-mutation body. If envelope persistence fails after body persistence, `commit` restores that body before throwing.

## Performance Guardrails

- No `page.saveBody` call is embedded in the model-authored mutation builder.
- No SwiftUI view body, graph renderer, or TextKit hot path is touched.
- Hashing runs once per planned commit, not per keystroke.
- The commit API accepts caller-owned persistence closures so editor-specific debounce/sync rules stay in their existing owners.

## Validation

Required before merge:

- `git diff --check`
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosTriFusionTypedMutationGate test -only-testing:EpistemosTests/ModelAuthoredNoteMutationTests CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`
- `cargo test --manifest-path agent_core/Cargo.toml --lib --quiet`
- `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosTriFusionTypedMutationGate build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`
