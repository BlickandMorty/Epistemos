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
- **JSON Schema Draft 2020-12** (latest stable). Validates via `jsonschema` crate Rust-side + `JSONSchema` Swift mirror.

## Usage

These schemas are the contract for hybrid MD+JSON memory writes (`deterministicapp.md` §1). Production callers:

1. **MutationEnvelope writes** (`agent_core/src/mutations/envelope.rs`) validate payload against the matching schema before commit. Malformed → reject with `MutationError::SchemaViolation`.
2. **NightBrain task bodies** (`agent_core/src/nightbrain/live.rs`) — `vault_consolidate`, `procedural_curate`, `claim_evidence_decay` read+write these schemas under task budgets.
3. **Skills marketplace** (Pro-only `skills.list` / `skills.view` / `skills.manage` tools) — reads `epistemos.skill.v1` to enumerate + dispatch.
4. **GenUI rendering** — `epistemos.episode.v1` + `epistemos.semantic.v1` surface in the Provenance Console and Brain Time Machine.

## Validation

Round-trip parity test lives at `agent_core/tests/schemas_roundtrip.rs` (post-V1 Wave A5 follow-up). Each schema:
- Loads + parses without error
- Validates a known-good fixture
- Rejects a known-bad fixture
- Round-trips through Rust types via `schemars` (when those types land)

## Cross-references

- `docs/fusion/jordan's research/deterministicapp.md` §5 Hybrid MD+JSON memory
- `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` (Claim / Evidence node kinds)
- `docs/fusion/HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md` (FFI contracts when these schemas cross the boundary)
- `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §B.5
- `agent_core/src/mutations/envelope.rs` (validation entry point — wiring in B.5 follow-up)
- `agent_core/src/provenance/ledger.rs` (ClaimLedger consumes `epistemos.semantic.v1` for retraction propagation)
