# Epistemos schemas — canonical source of truth

Per `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §B.5.

## Files

| File | Purpose | Source doc |
|---|---|---|
| `epistemos.soul.v1.schema.json` | Per-model user identity + preferences + agent persona | `deterministicapp.md` §5 |
| `epistemos.skill.v1.schema.json` | Voyager-style executable skill (code OR plan body) | `deterministicapp.md` §5 |
| `epistemos.episode.v1.schema.json` | CoALA episodic memory entry (timestamped event) | `deterministicapp.md` §2.3 |
| `epistemos.semantic.v1.schema.json` | CoALA semantic memory fact (atemporal claim) with 9-arm Kleene K3 claim_kind | `deterministicapp.md` §2.3 + `helios v5 first.md` §1.5 |

## Conventions

- **`schema_rev`** field is a `const` string. NEVER mutate it without:
  1. Authoring an `epistemos.X.v2.schema.json` file alongside
  2. Adding migration logic to the schema_rev registry (post-V1 Wave A)
  3. Source-guard test pinning the v1→v2 transition
- **12-char lowercase-alphanumeric ids** everywhere (`^[a-z0-9]{12}$`). Collision-resistant across machines; matches the existing `note_id` convention in `vault.read`.
- **`additionalProperties: false`** on every top-level object. Schema-validated writes reject unknown fields — caller must fail fast rather than silently drop data.
- **JSON Schema Draft 2020-12** (latest stable). Validates via typed Rust mirrors (`agent_core::schemas`) on the Rust side, with serde `deny_unknown_fields` enforcing `additionalProperties: false` and a post-parse regex enforcing the 12-char id pattern. Swift-side validation uses the same JSON files via the existing `JSONSchema` infra.

## Usage

These schemas are the contract for hybrid MD+JSON memory writes (`deterministicapp.md` §1). The validator entry point is **`agent_core::schemas::validate_epistemos_payload`** — it takes a `serde_json::Value`, dispatches on the `schema_rev` discriminator, and returns either a typed `EpistemosPayload` enum or a structured `SchemaValidationError` callers surface to the user.

Production callers:

1. **`validate_epistemos_payload`** is the wiring entry point. Any path that accepts untrusted JSON for one of the four schemas (Soul/Skill editor input, MCP tool dispatch, NightBrain task bodies) calls this first and refuses to write on `Err`.
2. **MutationEnvelope writes** (`agent_core/src/mutations/envelope.rs`) carry invalidation metadata, not raw payloads. Callers that batch a typed payload alongside an envelope validate the payload via the entry point above before committing the envelope — no `MutationError::SchemaViolation` variant is needed today because the validator runs at the call site, not inside the envelope.
3. **NightBrain task bodies** (`agent_core/src/nightbrain/live.rs`) — `vault_consolidate`, `procedural_curate`, `claim_evidence_decay` read + write these schemas under task budgets. Wiring lands with the B.9 NightBrain bodies slice.
4. **Skills marketplace** (Pro-only `skills.list` / `skills.view` / `skills.manage` tools) — reads `epistemos.skill.v1` to enumerate + dispatch. Wiring lands behind the Pro Cargo feature.
5. **GenUI rendering** — `epistemos.episode.v1` + `epistemos.semantic.v1` surface in the Provenance Console and Brain Time Machine.

## Validation

Round-trip parity tests live at `agent_core/tests/schemas_roundtrip.rs` (10 integration tests) plus `agent_core/src/schemas/mod.rs` `#[cfg(test)]` (13 unit tests). For each of the four schemas the integration suite asserts:

- The on-disk schema JSON file loads + parses
- `properties.schema_rev.const` matches `EpistemosSchemaRev::as_str`
- The schema declares `additionalProperties: false` (matches the Rust `deny_unknown_fields`)
- The schema's `required` array includes `schema_rev`
- A known-good fixture validates and the typed payload round-trips back to JSON without loss
- A known-bad fixture is rejected with a structured `SchemaValidationError`

The schemars-derive-from-Rust-types parity check (the fourth bullet in the original spec) is tracked as a follow-up: today the JSON schemas are hand-written and the Rust types are hand-written mirrors. When the Rust types gain `#[derive(JsonSchema)]`, an additional assertion will compare the generated schema against the on-disk schema and fail on drift.

## Cross-references

- `docs/fusion/jordan's research/deterministicapp.md` §5 Hybrid MD+JSON memory
- `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` (Claim / Evidence node kinds)
- `docs/fusion/HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md` (FFI contracts when these schemas cross the boundary)
- `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §B.5
- `agent_core/src/schemas/mod.rs` (typed Rust mirrors + validator entry point)
- `agent_core/src/mutations/envelope.rs` (envelope metadata; payload validation runs at call-site)
- `agent_core/src/provenance/ledger.rs` (ClaimLedger consumes `epistemos.semantic.v1` for retraction propagation)
