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
load_schema_migration_table(schema_doc)
load_falsifier_dependency_graph(schema_doc)
load_witness_retention_policy(schema_doc)
load_provider_receipt_schema(schema_doc)
load_negative_catalog(negative_catalog)
load_handbook_row(handbook, artifact.falsifier_id)
load_fragment(fragment)

assert artifact.schema_version == schema.const.schema_version
assert migrated_artifacts_have_complete_migration_note(artifact)
assert migration_note_tokens_are_semicolon_key_value(artifact.notes)
assert schema_fragment_digests_are_sha256_prefixed_when_present(artifact)
assert schema_fragment_digest_matches_first_fenced_json_block(schema_doc)
assert result_digest_matches_canonical_payload(artifact)
assert keys(axis_floor_table) == schema.properties.falsifier_id.enum
assert keys(command_path_map) == schema.properties.falsifier_id.enum
assert keys(expected_artifact_root_map) == schema.properties.falsifier_id.enum
assert artifact.falsifier_id == handbook.row.id == fragment.frontmatter.falsifier
assert artifact.hardware_pin == schema.$defs.hardware_pin.constants
assert artifact.command == strip_prefix(handbook.row.command, "NOT IMPLEMENTED: ")
assert command_path(artifact.command) == command_path_map[artifact.falsifier_id]
assert command_args_are_plain_tokens(artifact.command)
assert artifact.path starts_with expected_artifact_root_map[artifact.falsifier_id]
assert canonical_witness_filename_matches_gate(artifact.basename, artifact.falsifier_id)
assert jsonl_witness_file_has_no_utf8_bom(artifact)
assert jsonl_witness_file_uses_lf_not_crlf(artifact)
assert jsonl_witness_file_ends_with_final_lf(artifact)
assert jsonl_witness_file_has_no_blank_lines(artifact)
assert jsonl_result_digest_covers_full_lf_normalized_stream(artifact)
assert jsonl_rows_do_not_repeat_artifact_or_sidecar_paths(artifact)
assert jsonl_rows_do_not_repeat_result_digest(artifact)
assert jsonl_witness_rows_have_required_prompt_token_ids_and_contiguous_indices(artifact)
assert jsonl_prompt_ids_and_token_indices_match_schema(artifact)
assert jsonl_token_indices_are_nondecreasing_within_prompt(artifact)
assert jsonl_prompt_token_axis_triples_are_unique(artifact)
assert jsonl_row_falsifier_ids_match_artifact_falsifier_id(artifact)
assert jsonl_row_axes_match_declared_artifact_axes(artifact, axis_floor_table)
assert jsonl_row_anomaly_axes_match_row_axis(artifact)
assert jsonl_row_anomalies_do_not_excuse_file_level_defects(artifact)
assert jsonl_row_measurements_are_value_unit_objects(artifact)
assert jsonl_row_thresholds_are_operator_value_unit_objects(artifact)
assert jsonl_row_pass_matches_measurement_threshold_replay(artifact)
assert jsonl_row_schema_versions_match_current_schema(artifact)
assert jsonl_row_measurement_units_match_threshold_units(artifact)
assert jsonl_rows_and_nested_objects_have_no_extra_properties(artifact)
assert artifact_reference_paths_have_no_dot_segments(artifact)
assert provider_receipts_absent_means_no_cloud_hosted_or_external_provider_evidence(artifact, handbook.row)
assert provider_receipts_match_schema_definition_when_present(artifact)
assert provider_receipt_artifact_refs_exist_under_falsifier_root(artifact)
assert provider_receipts_do_not_embed_raw_prompts_api_keys_or_payloads(artifact)
assert dependency_graph_edges_are_satisfied(artifact, schema_doc)
assert upstream_artifacts_exist_for_dependency_edges(artifact)
assert retained_referenced_artifacts_are_not_garbage_collected(artifact)
assert garbage_collected_artifacts_have_replacement_digest_or_fail_report(artifact)
assert is_full_40_char_lower_hex(artifact.commit_sha)
assert commit_exists_in_repo(repo_root, artifact.commit_sha)
assert is_rfc3339_utc_z(artifact.timestamp_utc)
assert fixture_id_is_recoverable(artifact.fixture_id)
assert fixture_lineage_matches_fixture_id_when_present(artifact)
assert generated_or_seeded_fixtures_have_lineage(artifact, fragment)

axis_floor = axis_floor_table[artifact.falsifier_id]
assert all_axis_keys_match_schema_pattern(artifact.measurements, artifact.acceptance_thresholds, artifact.pass_per_axis)
assert axis_floor subset_of keys(artifact.measurements)
assert keys(artifact.measurements) == keys(artifact.acceptance_thresholds)
assert keys(artifact.measurements) == keys(artifact.pass_per_axis)

for axis in keys(artifact.measurements):
    validate_measurement_shape(axis)
    assert null_measurements_have_classified_unsupported_anomaly(axis)
    assert aggregate_statistics_have_nonempty_samples_or_raw_artifact(axis)
    assert sample_arrays_are_scalar_homogeneous(axis)
    assert digest_measurements_are_sha256_prefixed(axis)
    validate_threshold_shape(axis)
    assert threshold_operator_value_type_is_valid(axis)
    assert upstream_threshold_links_are_paired(axis)
    assert measurement_value_matches_threshold_operator(axis)
    assert measurement_unit_equals_threshold_unit(axis)
    assert unit_tokens_match_schema_pattern(axis)
    recompute_pass_boolean(axis)

assert artifact.overall_pass == all(required pass_per_axis values)
assert artifact_kind_matches_overall_pass_and_fallback_tier(artifact)
assert fallback_tier_matches_route(handbook.row, artifact.fallback_tier)
assert anomalies_are_structured(artifact.anomalies)
assert anomaly_base_fields_are_present(artifact.anomalies)
assert anomaly_kind_required_fields_are_present(artifact.anomalies)
assert anomaly_severity_values_are_enum(artifact.anomalies)
assert blocking_anomalies_set_affects_pass_true(artifact.anomalies)
assert no_primary_pass_when_any_anomaly_affects_pass(artifact)
assert anomaly_axis_refs subset_of keys(artifact.measurements)
assert notes_do_not_override_schema(artifact.notes)
assert notes_do_not_embed_json_payloads(artifact.notes)
assert non_none_notes_include_anomaly_inspection_token(artifact.notes)
assert negative_catalog.frontmatter.invalid_example_count == count_sections_matching("^## N")
assert all_negative_examples_fail_validation(negative_catalog)
```

## Doc-Only Consistency Commands

These commands are documentation checks only; they do not execute falsifier scripts or validate real artifacts.

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); JSON.parse(s[/```json\n(.*?)\n```/m,1]); puts "schema json ok"'
```

```bash
fragments=$(rg -l '^falsifier: F-' docs/falsifiers/F_*_2026_05_18.md | wc -l | tr -d ' ')
anchors=$(rg -l '^## Canon Anchors' docs/falsifiers/F_*_2026_05_18.md | wc -l | tr -d ' ')
test "$fragments" = "15" && test "$anchors" = "15"
```

```bash
declared=$(rg '^invalid_example_count:' docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md | awk '{print $2}')
actual=$(rg '^## N[0-9]+' docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md | wc -l | tr -d ' ')
test "$declared" = "$actual"
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); abort("artifact_kind not required") unless schema["required"].include?("artifact_kind"); abort("artifact_kind enum drift") unless schema.dig("properties","artifact_kind","enum") == ["primary_witness","fallback_witness","failure_report"]; puts "artifact kind ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); abort("result_digest not required") unless schema["required"].include?("result_digest"); abort("result_digest pattern drift") unless schema.dig("properties","result_digest","pattern") == "^sha256:[a-f0-9]{64}$"; puts "result digest ok"'
```

## Ownership

Implementation owner is TBD: merge-phase if artifact validation becomes part of the T23B handbook terminal, or a separate validator-implementation terminal if it touches Rust/Python tooling.
