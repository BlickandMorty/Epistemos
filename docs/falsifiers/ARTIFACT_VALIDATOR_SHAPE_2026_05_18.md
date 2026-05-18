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
load_jsonl_manifest_schema(schema_doc)
load_negative_catalog(negative_catalog)
load_handbook_row(handbook, artifact.falsifier_id)
load_fragment(fragment)

assert artifact.schema_version == schema.const.schema_version
assert migrated_artifacts_have_complete_migration_note(artifact)
assert migration_note_tokens_are_semicolon_key_value(artifact.notes)
assert schema_fragment_digests_are_sha256_prefixed_when_present(artifact)
assert schema_fragment_digest_matches_first_fenced_json_block(schema_doc)
assert object_result_digest_uses_canonical_sorted_key_bytes(artifact)
assert result_digest_matches_canonical_payload(artifact)
assert keys(axis_floor_table) == schema.properties.falsifier_id.enum
assert keys(command_path_map) == schema.properties.falsifier_id.enum
assert keys(expected_artifact_root_map) == schema.properties.falsifier_id.enum
assert artifact.falsifier_id == handbook.row.id == fragment.frontmatter.falsifier
assert artifact.hardware_pin == schema.$defs.hardware_pin.constants
assert runner_environment_matches_schema_definition(artifact)
assert runner_environment_base_fields_match_closed_pin(artifact)
assert runner_environment_captures_os_build(artifact)
assert runner_environment_captures_toolchain_identity(artifact)
assert runner_environment_captures_thermal_and_power_state(artifact)
assert artifact.command == strip_prefix(handbook.row.command, "NOT IMPLEMENTED: ")
assert command_path(artifact.command) == command_path_map[artifact.falsifier_id]
assert command_args_are_plain_tokens(artifact.command)
assert command_uses_single_ascii_space_tokenization(artifact.command)
assert command_has_no_cwd_prefix_glob_quote_or_env_assignment(artifact.command)
assert artifact.path starts_with expected_artifact_root_map[artifact.falsifier_id]
assert canonical_witness_filename_matches_gate(artifact.basename, artifact.falsifier_id)
assert jsonl_witness_file_has_no_utf8_bom(artifact)
assert jsonl_witness_file_uses_lf_not_crlf(artifact)
assert jsonl_witness_file_ends_with_final_lf(artifact)
assert jsonl_witness_file_has_no_blank_lines(artifact)
assert jsonl_manifest_exists_next_to_result_jsonl(artifact)
assert jsonl_manifest_matches_schema_definition(artifact)
assert jsonl_manifest_carries_file_level_envelope_fields(artifact)
assert jsonl_manifest_jsonl_file_sha256_equals_result_digest(artifact)
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
assert provider_receipt_artifact_ref_digests_match(artifact)
assert provider_receipts_do_not_embed_raw_prompts_api_keys_or_payloads(artifact)
assert dependency_graph_edges_are_satisfied(artifact, schema_doc)
assert upstream_artifacts_exist_for_dependency_edges(artifact)
assert replay_sidecar_paths_have_matching_sha256_fields(artifact)
assert replay_sidecar_sha256_fields_match_file_bytes(artifact)
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
    assert measurement_evidence_kind_is_consistent(axis)
    assert null_measurements_have_classified_unsupported_anomaly(axis)
    assert aggregate_statistics_have_nonempty_samples_or_raw_artifact(axis)
    assert aggregate_sample_count_matches_samples_or_raw_manifest(axis)
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
assert timing_axes_fail_or_have_blocking_thermal_anomaly_under_pressure(artifact)
assert timing_axes_fail_or_have_blocking_power_anomaly_off_ac(artifact)
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

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); abort("provider artifact_ref_sha256 not required") unless schema.dig("$defs","provider_receipt","required").include?("artifact_ref_sha256"); abort("raw_artifact_sha256 missing") unless schema.dig("properties","measurements","patternProperties","^[a-z][a-z0-9_]*$","properties","raw_artifact_sha256","pattern") == "^sha256:[a-f0-9]{64}$"; abort("upstream_artifact_sha256 missing") unless schema.dig("properties","acceptance_thresholds","patternProperties","^[a-z][a-z0-9_]*$","properties","upstream_artifact_sha256","pattern") == "^sha256:[a-f0-9]{64}$"; puts "sidecar digest fields ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); manifest=schema.dig("$defs","jsonl_manifest") || abort("jsonl_manifest missing"); %w[result_digest jsonl_file jsonl_file_sha256 pass_per_axis overall_pass].each { |k| abort("jsonl_manifest missing #{k}") unless manifest["required"].include?(k) }; abort("jsonl_file not pinned") unless manifest.dig("properties","jsonl_file","const") == "result.jsonl"; puts "jsonl manifest ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); env=schema.dig("$defs","runner_environment") || abort("runner_environment missing"); abort("runner_environment not required") unless schema["required"].include?("runner_environment"); { "cwd"=>"repo_root", "shell"=>"zsh", "env_policy"=>"script_owned", "locale"=>"C", "timezone"=>"UTC" }.each { |k,v| abort("runner #{k} drift") unless env.dig("properties",k,"const") == v }; %w[os_build toolchain_identity thermal_state_start thermal_state_end power_source].each { |k| abort("runner #{k} not required") unless env["required"].include?(k) }; puts "runner environment ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); os=schema.dig("$defs","runner_environment","properties","os_build") || abort("os_build missing"); abort("os_build minLength drift") unless os["minLength"] == 1; abort("os_build pattern drift") unless os["pattern"] == "^[A-Za-z0-9._() -]+$"; puts "runner os build ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); abort("runner toolchain ref drift") unless schema.dig("$defs","runner_environment","properties","toolchain_identity","$ref") == "#/$defs/toolchain_identity"; tc=schema.dig("$defs","toolchain_identity") || abort("toolchain_identity missing"); abort("toolchain additionalProperties drift") unless tc["additionalProperties"] == false; expected=%w[xcodebuild swift rustc python]; abort("toolchain required drift") unless tc["required"] == expected; expected.each { |k| prop=tc.dig("properties",k) || abort("toolchain #{k} missing"); abort("toolchain #{k} pattern drift") unless prop["pattern"] == "^(not_used|(?=.*[0-9])[^\\r\\n]+)$" }; puts "runner toolchain identity ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); m=schema.dig("properties","measurements","patternProperties","^[a-z][a-z0-9_]*$"); abort("evidence_kind not required") unless m["required"].include?("evidence_kind"); expected=%w[direct_measurement aggregate_statistic digest classification reference_link]; abort("evidence_kind enum drift") unless m.dig("properties","evidence_kind","enum") == expected; puts "measurement evidence kind ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); m=schema.dig("properties","measurements","patternProperties","^[a-z][a-z0-9_]*$"); abort("sample_count missing") unless m.dig("properties","sample_count","minimum") == 1; aggregate=m["allOf"].any? { |rule| rule.dig("then","required")&.include?("sample_count") && rule.dig("then","properties","evidence_kind","const") == "aggregate_statistic" }; abort("aggregate sample_count rule missing") unless aggregate; puts "aggregate sample count ok"'
```

```bash
rg -q '^## Timing Thermal Rule$' docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md && rg -q 'timing_axes_fail_or_have_blocking_thermal_anomaly_under_pressure' docs/falsifiers/ARTIFACT_VALIDATOR_SHAPE_2026_05_18.md
```

```bash
rg -q '^## Timing Power Rule$' docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md && rg -q 'timing_axes_fail_or_have_blocking_power_anomaly_off_ac' docs/falsifiers/ARTIFACT_VALIDATOR_SHAPE_2026_05_18.md
```

## Ownership

Implementation owner is TBD: merge-phase if artifact validation becomes part of the T23B handbook terminal, or a separate validator-implementation terminal if it touches Rust/Python tooling.
