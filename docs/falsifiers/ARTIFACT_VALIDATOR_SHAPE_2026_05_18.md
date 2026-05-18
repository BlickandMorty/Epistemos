---
state: t23b-falsifier-artifact-validator-shape
created_on: 2026-05-18
schema_version: 2026-05-18.2
owner: TBD merge-phase or validator-implementation terminal
---

# Artifact Validator Shape - 2026-05-18

This is the doc-only shape for a future validator. It is not an executable harness and does not validate any current artifact.

## Inputs

1. `schema_doc`: `docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md`
2. `handbook`: `docs/falsifiers/M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md`
3. `fragment`: the matching `docs/falsifiers/F_*_2026_05_18.md`
4. `artifact`: the expected artifact path from the handbook row
5. `repo_root`: the producing checkout
6. `negative_catalog`: `docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md`

## Required Checks

```text
load_json_schema_fragment(schema_doc)
assert exactly_one_fenced_json_block(schema_doc)
load_axis_floor_table(schema_doc)
load_command_path_map(schema_doc)
load_expected_artifact_root_map(schema_doc)
load_hardware_pin_migration_mapping(schema_doc)
load_negative_catalog(negative_catalog)
load_handbook_row(handbook, artifact.falsifier_id)
load_fragment(fragment)

assert artifact.schema_version == schema.const.schema_version
assert artifact.falsifier_id == handbook.row.id == fragment.frontmatter.falsifier
assert artifact.hardware_pin == schema.const.hardware_pin
assert artifact.command == strip_prefix(handbook.row.command, "NOT IMPLEMENTED: ")
assert command_path(artifact.command) == command_path_map[artifact.falsifier_id]
assert command_args_are_plain_tokens(artifact.command)
assert artifact.path starts_with expected_artifact_root_map[artifact.falsifier_id]
assert is_full_40_char_lower_hex(artifact.commit_sha)
assert commit_exists_in_repo(repo_root, artifact.commit_sha)
assert is_rfc3339_utc_z(artifact.timestamp_utc)
assert fixture_id_is_recoverable(artifact.fixture_id)

axis_floor = axis_floor_table[artifact.falsifier_id]
assert axis_floor subset_of keys(artifact.measurements)
assert keys(artifact.measurements) == keys(artifact.acceptance_thresholds)
assert keys(artifact.measurements) == keys(artifact.pass_per_axis)

for axis in keys(artifact.measurements):
    validate_measurement_shape(axis)
    validate_threshold_shape(axis)
    assert measurement_value_matches_threshold_operator(axis)
    recompute_pass_boolean(axis)

assert artifact.overall_pass == all(required pass_per_axis values)
assert fallback_tier_matches_route(handbook.row, artifact.fallback_tier)
assert anomalies_are_structured(artifact.anomalies)
assert notes_do_not_override_schema(artifact.notes)
assert negative_catalog.frontmatter.invalid_example_count == count_sections_matching("^## N")
assert all_negative_examples_fail_validation(negative_catalog)
```

## Ownership

Implementation owner is TBD: merge-phase if artifact validation becomes part of the T23B handbook terminal, or a separate validator-implementation terminal if it touches Rust/Python tooling.
