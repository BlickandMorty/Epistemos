# Goose S2 — block/goose Rust-core extraction PLAN (2026-06-19)

**Owner DECISION (R-GOOSE): Work/Open-Code = Goose. Pull block/goose's RUST CORE
(Apache-2.0) into agent_core via UniFFI = the full engine (repo indexing, git
lifecycle, multi-file diffs, deterministic test-and-fix loop, parallel subagents,
YAML recipes). NOT the Node/TS Goose desktop. Surfaced through WORK; isolated behind
Work + a flag; GOOSE GUARDRAIL: Chat (Epistemos) / Act (Osaurus) NEVER break.**

This is the research-first PLAN + the first landable vendor (one small real type),
following the proven Osaurus S2 pattern (vendor one verbatim type → grow the seam).

## What block/goose is (primary source: github.com/block/goose tree)
- **License:** **Apache-2.0** (confirmed via `gh api repos/block/goose/license`) —
  permissive, App-Store/closed-source compatible → ProvenanceGate `direct_import` OK
  (unlike the AGPL repos in R-FIELDTHEORY/Khoj).
- **A Rust workspace**, multiple crates. The engine core is **`crates/goose/`**
  (`crates/goose/src/`). Other crates (goose-server, goose-cli, the Electron/TS
  desktop) are NOT imported (NO-SIDECAR: the Node/TS desktop would dual-process
  swap-kill the 18 GB M2 Pro).
- **`crates/goose/src/` key modules (the extraction surface):**
  - `agents/` — the agent loop + `subagent_execution_tool` (parallel subagents).
  - `providers/` — model providers + `formats/` (OpenAI/Anthropic wire formats).
  - `session/` — session lifecycle.
  - `permission/`, `skills/`, `slash_commands/`, `recipe`/YAML recipes.
  - `source_roots.rs` — the workspace roots the engine operates on (repo indexing /
    multi-file diffs).
  - `acp/` — Agent Client Protocol (server/transport/tools).
  - `builtin_extension.rs`, `instance_id.rs`, `config`, `tracing`.

## The extraction strategy (UniFFI, isolated, GUARDRAIL-safe)
The Swift `WorkBackend` (Seam A) + the Rust `work` module (Seam B) are the seams.
S2 grows the Rust side toward the real engine:

1. **ProvenanceGate `direct_import` (Apache-2.0).** Vendor block/goose source into
   agent_core, isolated under the `work` module. Keep the upstream license/NOTICE;
   record provenance per file.
2. **Selective, dependency-led vendor — NOT the whole crate at once.** `crates/goose`
   pulls heavy deps (tokio, reqwest, mcp, tree-sitter, …) and references its own
   `config`/`providers`. Vendoring it wholesale would balloon agent_core's
   dependency graph + risk Chat/Act build health. Instead, vendor **leaf, self-
   contained types first** (std/serde-only), then grow inward as each layer's deps
   are satisfied — each step `cargo test --lib` green under BOTH default + pro-build.
3. **UniFFI surface.** The Rust `work` module exposes the engine to Swift via
   `#[uniffi::export]` (Seam B already added `work_backend_status_json`). The real
   `run_work_session` becomes FFI-exported once the engine layer lands.
4. **GOOSE GUARDRAIL — Chat/Act unchanged.** The `work` module stays isolated:
   nothing in `agent_loop` / `agent_runtime` references it; a guard test asserts the
   isolation. Work is surfaced ONLY through Work mode + `EPISTEMOS_WORK_GOOSE_V0`.
5. **P8.2 deterministic schemas.** Goose code patches validate against the existing
   deterministic schemas before they touch the workspace (a later layer).

## S2 first vendor (this slice): `SourceRoot`
`crates/goose/src/source_roots.rs` — `SourceRoot { path: PathBuf, writable: bool }` +
`SourceRoot::read_only(path)`. **Self-contained (std::path only)**, and the most
Work-relevant leaf type (the workspace roots the Goose engine indexes / diffs).
Vendored VERBATIM into the agent_core `work` module under `vendored_goose`
(Apache-2.0 `direct_import`, provenance header), and the inert `run_work_session`
seam now takes the source roots it will operate on — proving the direct_import path
works for block/goose, the same way Osaurus S2 vendored `ServerHealth`.

## Sequenced slices (each `cargo test --lib` green BOTH features, GUARDRAIL-safe)
1. **S2 (this):** PLAN + vendor `SourceRoot` (leaf) + the seam takes source roots.
2. **S3 ✅ (2026-06-19):** vendored the block/goose PERMISSION leaf VERBATIM
   (`Permission`/`PrincipalType`/`PermissionConfirmation` from
   `crates/goose-providers/src/permission.rs`, `direct_import`, `ToSchema` derive
   trimmed — no `utoipa` in agent_core; serde wire form byte-identical) + first-party
   typed `WorkRequest` (safe-default `AllowOnce` posture) / `WorkResult`;
   `run_work_session(&WorkRequest) -> Result<WorkResult, WorkError>` still inert.
   cargo `--lib work` green BOTH profiles. GUARDRAIL holds.
3. **S4:** the provider/format layer (OpenAI/Anthropic wire formats) once its deps
   are satisfied; FFI-export the real `run_work_session`.
4. **S5+:** the agent loop + subagents + session (the engine), behind the flag, with
   the P8.2 schema validation gate; then the Swift `GooseWorkBackend` drives it.

## Net
Apache-2.0 makes block/goose a license-clean `direct_import`, but its core crate is
deeply interdependent + heavy-dep, so the safe extraction is leaf-first, isolated
under `work`, each step cargo-green under both build profiles and GUARDRAIL-locked
(Chat/Act untouched). S2 lands the first real vendored type (`SourceRoot`) + the seam
that uses it. Cross-ref: agent_core/src/work.rs (Seam B), Epistemos/Work/WorkBackend
(Seam A), the Osaurus S2 vendor precedent, the GOOSE GUARDRAIL.
