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
assert migration_notes_include_validator_identity_distinct_from_reviewer(artifact.notes)
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
assert command_digest_matches_normalized_command(artifact)
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
assert provider_receipts_never_claim_data_sent_none(artifact)
assert provider_receipts_never_claim_prompt_text_sent(artifact)
assert provider_receipts_require_replay_allowed_true(artifact)
assert provider_pass_witness_receipts_use_zero_retention(artifact)
assert provider_receipt_artifact_refs_exist_under_falsifier_root(artifact)
assert provider_receipt_artifact_ref_digests_match(artifact)
assert provider_receipt_artifact_refs_have_no_dot_segments(artifact)
assert provider_receipts_do_not_embed_raw_prompts_api_keys_or_payloads(artifact)
assert provider_threshold_refs_match_provider_receipts(artifact)
assert local_reference_notes_have_artifact_ref_and_digest(artifact.notes)
assert local_reference_artifact_stays_under_row_root(artifact.notes, handbook.row)
assert local_reference_artifact_has_no_dot_segments(artifact.notes)
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
assert fixture_lineage_manifest_digest_matches_when_present(artifact)
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
    assert threshold_source_is_declared_and_consistent(axis)
    assert provider_threshold_source_refs_are_paired(axis)
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
assert blocking_anomalies_have_retained_evidence_refs(artifact.anomalies)
assert timing_axes_fail_or_have_blocking_thermal_anomaly_under_pressure(artifact)
assert timing_axes_fail_or_have_blocking_power_anomaly_off_ac(artifact)
assert blocking_anomalies_set_affects_pass_true(artifact.anomalies)
assert no_primary_pass_when_any_anomaly_affects_pass(artifact)
assert anomaly_axis_refs subset_of keys(artifact.measurements)
assert notes_do_not_override_schema(artifact.notes)
assert notes_do_not_embed_json_payloads(artifact.notes)
assert non_none_notes_include_anomaly_inspection_token(artifact.notes)
assert anomaly_inspection_token_is_semicolon_delimited(artifact.notes)
assert non_none_notes_include_lowercase_slug_reviewer_token(artifact.notes)
assert notes_reviewer_token_is_semicolon_delimited(artifact.notes)
assert non_none_notes_include_review_timestamp_token(artifact.notes)
assert notes_review_timestamp_token_is_semicolon_delimited(artifact.notes)
assert notes_reviewer_token_not_reserved_anonymous_identity(artifact.notes)
assert notes_reviewer_sentinels_are_semicolon_delimited(artifact.notes)
assert migration_validator_sentinels_are_semicolon_delimited(artifact.notes)
assert migration_validator_reviewer_sentinel_sets_match_schema(artifact.notes)
assert migration_identity_sentinel_gap_report_names_both_roles(artifact.notes)
assert migration_identity_sentinel_gap_report_uses_role_labels(artifact.notes)
assert migration_identity_sentinel_gap_report_values_are_not_reserved(artifact.notes)
assert migration_identity_sentinel_gap_report_values_have_no_commas(artifact.notes)
assert migration_identity_sentinel_gap_report_values_are_lowercase_slugs(artifact.notes)
assert migration_identity_sentinel_gap_report_values_have_old_new_states(artifact.notes)
assert migration_identity_sentinel_gap_report_values_are_distinct_by_role(artifact.notes)
assert migration_identity_sentinel_gap_report_is_semicolon_delimited(artifact.notes)
assert migration_identity_sentinel_gap_report_is_bound_to_artifact_path(artifact.notes)
assert negative_catalog_has_identity_gap_role_value_cases(negative_catalog)
assert negative_catalog_has_shared_identity_sentinel_pair_case(negative_catalog)
assert notes_required_tokens_are_semicolon_delimited(artifact.notes)
assert notes_length_within_schema_cap(artifact.notes)
assert migration_notes_parse_positive_increasing_notes_cap_tokens(artifact.notes)
assert migration_notes_length_cap_tokens_are_semicolon_delimited(artifact.notes)
assert notes_machine_token_keys_are_schema_owned(artifact.notes)
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
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); abort("artifact_kind not required") unless schema["required"].include?("artifact_kind"); abort("artifact_kind enum drift") unless schema.dig("properties","artifact_kind","enum") == ["primary_witness","fallback_witness","failure_report"]; failure=schema["allOf"].find { |r| r.dig("if","properties","artifact_kind","const") == "failure_report" } || abort("failure_report rule missing"); abort("failure report pass drift") unless failure.dig("then","properties","overall_pass","const") == false && failure.dig("then","properties","fallback_tier","const") == "Fail"; puts "artifact kind ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); abort("command_digest not required") unless schema["required"].include?("command_digest"); abort("command_digest pattern drift") unless schema.dig("properties","command_digest","pattern") == "^sha256:[a-f0-9]{64}$"; abort("jsonl command_digest not required") unless schema.dig("$defs","jsonl_manifest","required").include?("command_digest"); puts "command digest ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); abort("result_digest not required") unless schema["required"].include?("result_digest"); abort("result_digest pattern drift") unless schema.dig("properties","result_digest","pattern") == "^sha256:[a-f0-9]{64}$"; puts "result digest ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); fl=schema.dig("$defs","fixture_lineage") || abort("fixture_lineage missing"); abort("fixture_manifest_sha256 not required") unless fl["required"].include?("fixture_manifest_sha256"); abort("fixture_manifest_sha256 pattern drift") unless fl.dig("properties","fixture_manifest_sha256","pattern") == "^sha256:[a-f0-9]{64}$"; puts "fixture lineage digest ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("then","pattern")&.include?("reviewer=[a-z0-9][a-z0-9._-]*") && r.dig("then","pattern")&.include?("anomaly_inspection=complete") }; abort("notes lowercase reviewer rule missing") unless rule; puts "notes reviewer token ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("then","pattern")&.include?("reviewer=[a-z0-9][a-z0-9._-]*") } || abort("notes reviewer rule missing"); pat=rule.dig("then","pattern") || abort("notes reviewer pattern missing"); abort("notes reviewer delimiter missing") unless pat.include?("(?:^|;\\\\s*)reviewer=[a-z0-9][a-z0-9._-]*(?:;|$)") && s.include?("embedded `reviewer=<id>` substring inside another value is not reviewer attestation"); puts "notes reviewer delimiter ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("then","pattern")&.include?("anomaly_inspection=complete") } || abort("notes anomaly inspection rule missing"); pat=rule.dig("then","pattern") || abort("notes anomaly inspection pattern missing"); abort("anomaly inspection delimiter missing") unless pat.include?("(?:^|;\\\\s*)anomaly_inspection=complete(?:;|$)") && s.include?("embedded `anomaly_inspection=complete` substring inside another value is not inspection evidence"); puts "notes anomaly inspection delimiter ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("then","pattern")&.include?("reviewed_at_utc=") && r.dig("then","pattern")&.include?("reviewer=") }; abort("notes review timestamp rule missing") unless rule; puts "notes review timestamp ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("then","pattern")&.include?("reviewed_at_utc=") } || abort("notes review timestamp rule missing"); pat=rule.dig("then","pattern") || abort("notes review timestamp pattern missing"); abort("notes review timestamp delimiter missing") unless pat.include?("(?:^|;\\\\s*)reviewed_at_utc=\\\\d{4}-") && s.include?("embedded `reviewed_at_utc=<RFC3339Z>` substring inside another value is not timestamp evidence"); puts "notes review timestamp delimiter ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","not","pattern") || abort("notes not pattern missing"); abort("anonymous reviewer sentinel rule missing") unless pat.include?("(?:^|;\\\\s*)reviewer=(?:anonymous|unknown|tbd|none)(?:;|$)") && s.include?("reserved reviewer identities `anonymous`, `unknown`, `tbd`, and `none` are invalid only when they appear as bounded reviewer tokens"); puts "notes reviewer sentinel ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","not","pattern") || abort("notes not pattern missing"); abort("validator sentinel rule missing") unless pat.include?("(?:^|;\\\\s*)validator=(?:anonymous|unknown|tbd|none)(?:;|$)") && s.include?("Reserved validator sentinels are evaluated only on bounded validator tokens"); puts "migration validator sentinel ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","not","pattern") || abort("notes not pattern missing"); abort("migration reviewer sentinel rule missing") unless pat.include?("(?:^|;\\\\s*)reviewer=(?:anonymous|unknown|tbd|none)(?:;|$)") && s.include?("Reserved reviewer sentinels are evaluated only on bounded reviewer tokens"); puts "migration reviewer sentinel ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","not","pattern") || abort("notes not pattern missing"); validator=pat[/validator=\(\?:([^)]+)\)/,1] || abort("validator sentinel set missing"); reviewer=pat[/reviewer=\(\?:([^)]+)\)/,1] || abort("reviewer sentinel set missing"); abort("sentinel set drift #{validator} != #{reviewer}") unless validator == reviewer && validator == "anonymous|unknown|tbd|none"; abort("shared sentinel prose missing") unless s.include?("shared migration identity sentinel set is exactly"); puts "migration identity sentinel set parity ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); pat=notes.dig("allOf",1,"then","pattern") || abort("migration note pattern missing"); abort("identity sentinel gap report missing") unless pat.include?("identity_sentinel_gap_report=validator:") && pat.include?(",reviewer:") && notes.dig("not","pattern").include?("identity_sentinel_gap_report") && s.include?("identity_sentinel_gap_report` must use `validator:<impact>,reviewer:<impact>` role labels"); puts "migration identity sentinel gap report ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","not","pattern") || abort("notes not pattern missing"); abort("identity sentinel reserved values missing") unless pat.include?("identity_sentinel_gap_report=validator:(?:anonymous|unknown|tbd|none),reviewer:old-") && pat.include?("identity_sentinel_gap_report=validator:old-[a-z0-9][a-z0-9._-]*-new-[a-z0-9][a-z0-9._-]*,reviewer:(?:anonymous|unknown|tbd|none)") && s.include?("role-impact values must be distinct lowercase old/new atoms"); puts "migration identity sentinel gap values ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","allOf",1,"then","pattern") || abort("migration note pattern missing"); abort("identity sentinel comma boundary missing") unless pat.include?("validator:old-[a-z0-9][a-z0-9._-]*-new-[a-z0-9][a-z0-9._-]*,reviewer:old-[a-z0-9][a-z0-9._-]*-new-[a-z0-9][a-z0-9._-]*") && !pat.include?("validator:[A-Za-z0-9._,/:+-]+,reviewer") && s.include?("comma is reserved as the role separator"); puts "migration identity sentinel gap comma boundary ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","not","pattern") || abort("notes not pattern missing"); abort("identity sentinel distinct-role rule missing") unless pat.include?("identity_sentinel_gap_report=validator:(old-[a-z0-9][a-z0-9._-]*-new-[a-z0-9][a-z0-9._-]*),reviewer:\\\\1") && s.include?("role-impact values must be distinct lowercase old/new atoms"); puts "migration identity sentinel gap distinct roles ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","allOf",1,"then","pattern") || abort("migration note pattern missing"); abort("identity sentinel old/new state shape missing") unless pat.include?("identity_sentinel_gap_report=validator:old-[a-z0-9][a-z0-9._-]*-new-[a-z0-9][a-z0-9._-]*,reviewer:old-[a-z0-9][a-z0-9._-]*-new-[a-z0-9][a-z0-9._-]*") && s.include?("old-<state>-new-<state>"); puts "migration identity sentinel old new states ok"'
```

```bash
ruby -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); abort("nested identity transition delimiter rule missing") unless s.include?("may not contain nested `old-` or `-new-` transition delimiters inside either state atom"); puts "migration identity nested transition delimiters ok"'
```

```bash
ruby -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); abort("identity state endpoint rule missing") unless s.include?("state atoms must begin and end with lowercase alphanumeric text"); puts "migration identity state endpoints ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","allOf",1,"then","pattern") || abort("migration note pattern missing"); abort("numeric-leading identity state grammar missing") unless pat.include?("old-[a-z0-9][a-z0-9._-]*-new-[a-z0-9][a-z0-9._-]*"); puts "migration identity numeric-leading states ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","allOf",1,"then","pattern") || abort("migration note pattern missing"); abort("numeric-only identity states no longer fit grammar") unless "identity_sentinel_gap_report=validator:old-1-new-2,reviewer:old-3-new-4".match?(Regexp.new(pat[/identity_sentinel_gap_report=validator:old-.*?\\(\\?:;\\|\\$\\)/] || "a^")); puts "migration identity numeric-only states ok"'
```

```bash
ruby -rjson -e 'schema=JSON.parse(File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md")[/```json\n(.*?)\n```/m,1]); pat=Regexp.new(schema.dig("properties","notes","not","pattern")); notes=JSON.parse(File.read("docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md")[/## N194 - .*?```json\n(.*?)\n```/m,1]).fetch("notes"); abort("reserved identity state branch missing") unless notes.match?(pat); ok="identity_sentinel_gap_report=validator:old-1-new-2,reviewer:old-3-new-4"; abort("numeric-only valid states rejected") if ok.match?(pat); puts "migration identity reserved states rejected ok"'
```

```bash
ruby -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); %w[reserved-state duplicate-numeric-transition punctuation-endpoint-state nested-transition-marker transition-order empty-state role-labels comma-bearing-impact lowercase-impact identical-impact artifact-path-bound].each { |slug| abort("#{slug} missing") unless s.include?("| `#{slug}` |") }; puts "identity gap slug catalog coverage ok"'
```

```bash
ruby -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); section=s[/## Identity Gap Slug Catalog\n(.*?)\n## /m,1] || abort("identity slug catalog missing"); abort("identity slug grammar missing") unless section.include?("^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"); slugs=section.scan(/^\\| `([^`]+)` \\|/).flatten; bad=slugs.grep_v(/\\A[a-z][a-z0-9]*(?:-[a-z0-9]+)*\\z/); abort("bad identity slugs: #{bad.join(",")}") unless bad.empty?; puts "identity gap slug grammar ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md"); block=s[/## N196 - .*?```json\n(.*?)\n```/m,1] || abort("N196 missing"); x=JSON.parse(block); abort("N196 catalog flag mismatch") unless x["catalog_slug"] == "missing-validator-role-impact" && x["schema_catalog_present"] == false; puts "identity gap slug catalog negative case ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md"); block=s[/## N197 - .*?```json\n(.*?)\n```/m,1] || abort("N197 missing"); x=JSON.parse(block); abort("N197 underscore slug missing") unless x["catalog_slug"] == "reserved_state"; abort("N197 unexpectedly matches slug grammar") if x["catalog_slug"].match?(/\A[a-z][a-z0-9]*(?:-[a-z0-9]+)*\z/); puts "identity gap underscore slug negative case ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md"); block=s[/## N198 - .*?```json\n(.*?)\n```/m,1] || abort("N198 missing"); x=JSON.parse(block); abort("N198 title-case slug missing") unless x["catalog_slug"] == "Reserved-State"; abort("N198 unexpectedly matches slug grammar") if x["catalog_slug"].match?(/\A[a-z][a-z0-9]*(?:-[a-z0-9]+)*\z/); puts "identity gap title-case slug negative case ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md"); block=s[/## N199 - .*?```json\n(.*?)\n```/m,1] || abort("N199 missing"); x=JSON.parse(block); abort("N199 leading-hyphen slug missing") unless x["catalog_slug"] == "-reserved-state"; abort("N199 unexpectedly matches slug grammar") if x["catalog_slug"].match?(/\A[a-z][a-z0-9]*(?:-[a-z0-9]+)*\z/); puts "identity gap leading-hyphen slug negative case ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md"); block=s[/## N200 - .*?```json\n(.*?)\n```/m,1] || abort("N200 missing"); x=JSON.parse(block); abort("N200 trailing-hyphen slug missing") unless x["catalog_slug"] == "reserved-state-"; abort("N200 unexpectedly matches slug grammar") if x["catalog_slug"].match?(/\A[a-z][a-z0-9]*(?:-[a-z0-9]+)*\z/); puts "identity gap trailing-hyphen slug negative case ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md"); block=s[/## N201 - .*?```json\n(.*?)\n```/m,1] || abort("N201 missing"); x=JSON.parse(block); abort("N201 double-hyphen slug missing") unless x["catalog_slug"] == "reserved--state"; abort("N201 unexpectedly matches slug grammar") if x["catalog_slug"].match?(/\A[a-z][a-z0-9]*(?:-[a-z0-9]+)*\z/); puts "identity gap double-hyphen slug negative case ok"'
```

```bash
ruby -e 'h=File.read("docs/falsifiers/M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md"); abort("identity slug registration audit missing") unless h.include?("## Identity Gap Slug Registration Audit") && h.include?("N196 is the negative catalog guard"); puts "identity slug registration audit ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","allOf",1,"then","pattern") || abort("migration note pattern missing"); abort("internal-dot identity states no longer fit grammar") unless "identity_sentinel_gap_report=validator:old-anonymous.v1-new-blocked,reviewer:old-unknown.v1-new-blocked".match?(Regexp.new(pat[/identity_sentinel_gap_report=validator:old-.*?\\(\\?:;\\|\\$\\)/] || "a^")); puts "migration identity internal-dot states ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","allOf",1,"then","pattern") || abort("migration note pattern missing"); abort("internal-underscore identity states no longer fit grammar") unless "identity_sentinel_gap_report=validator:old-anonymous_v1-new-blocked,reviewer:old-unknown_v1-new-blocked".match?(Regexp.new(pat[/identity_sentinel_gap_report=validator:old-.*?\\(\\?:;\\|\\$\\)/] || "a^")); puts "migration identity internal-underscore states ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","allOf",1,"then","pattern") || abort("migration note pattern missing"); abort("internal-hyphen identity states no longer fit grammar") unless "identity_sentinel_gap_report=validator:old-anonymous-v1-new-blocked,reviewer:old-unknown-v1-new-blocked".match?(Regexp.new(pat[/identity_sentinel_gap_report=validator:old-.*?\\(\\?:;\\|\\$\\)/] || "a^")); puts "migration identity internal-hyphen states ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","allOf",1,"then","pattern") || abort("migration note pattern missing"); abort("identity sentinel gap delimiter missing") unless pat.include?("(?:^|;\\s*)identity_sentinel_gap_report=validator:old-[a-z0-9][a-z0-9._-]*-new-[a-z0-9][a-z0-9._-]*,reviewer:old-[a-z0-9][a-z0-9._-]*-new-[a-z0-9][a-z0-9._-]*(?:;|$)") && s.include?("embedded substrings do not satisfy version, path, command, mapping, digest, notes-cap, identity, sentinel-gap, or review-time attestation"); puts "migration identity sentinel gap delimiter ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","allOf",1,"then","pattern") || abort("migration note pattern missing"); abort("identity sentinel artifact path binding missing") unless pat.include?("(?:^|;\\\\s*)artifact_path=artifacts/falsifiers/") && pat.include?("identity_sentinel_gap_report=validator:") && s.include?("artifact_path` token is the affected artifact path for any `identity_sentinel_gap_report`"); puts "migration identity sentinel artifact path binding ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md"); required={"N173"=>"identity_sentinel_gap_report=changed","N174"=>"identity_sentinel_gap_report=validator:none,reviewer:changed","N175"=>"identity_sentinel_gap_report=validator:changed,extra,reviewer:changed","N176"=>"identity_sentinel_gap_report=validator:Changed,reviewer:changed","N177"=>"identity_sentinel_gap_report=validator:changed,reviewer:changed","N178"=>"identity_sentinel_gap_report=validator:validator-impact,reviewer:reviewer-impact","N179"=>"identity_sentinel_gap_report=validator:changed,reviewer:updated","N180"=>"identity_sentinel_gap_report=validator:old-anonymous-new-blocked,reviewer:updated","N181"=>"identity_sentinel_gap_report=validator:changed,reviewer:old-unknown-new-blocked","N182"=>"identity_sentinel_gap_report=validator:old--new-blocked,reviewer:old-unknown-new-blocked","N183"=>"identity_sentinel_gap_report=validator:old-anonymous-new-,reviewer:old-unknown-new-blocked","N184"=>"identity_sentinel_gap_report=validator:new-blocked-old-anonymous,reviewer:old-unknown-new-blocked","N185"=>"identity_sentinel_gap_report=validator:old-old-anonymous-new-blocked,reviewer:old-unknown-new-blocked","N186"=>"identity_sentinel_gap_report=validator:old-anonymous-new-new-blocked,reviewer:old-unknown-new-blocked","N187"=>"identity_sentinel_gap_report=validator:old-.anonymous-new-blocked,reviewer:old-unknown-new-blocked","N188"=>"identity_sentinel_gap_report=validator:old--anonymous-new-blocked,reviewer:old-unknown-new-blocked","N189"=>"identity_sentinel_gap_report=validator:old-anonymous.-new-blocked,reviewer:old-unknown-new-blocked","N190"=>"identity_sentinel_gap_report=validator:old-anonymous--new-blocked,reviewer:old-unknown-new-blocked","N191"=>"identity_sentinel_gap_report=validator:old-_anonymous-new-blocked,reviewer:old-unknown-new-blocked","N192"=>"identity_sentinel_gap_report=validator:old-anonymous_-new-blocked,reviewer:old-unknown-new-blocked"}; required.each { |id, token| block=s[/## #{id} - .*?```json\n(.*?)\n```/m,1] || abort("#{id} missing"); notes=JSON.parse(block).fetch("notes"); abort("#{id} token missing") unless notes.include?(token) }; abort("N178 detached path missing") if s[/## N178 - .*?```json\n(.*?)\n```/m,1].include?("artifact_path="); puts "migration identity sentinel gap negative cases ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md"); block=s[/## N193 - .*?```json\n(.*?)\n```/m,1] || abort("N193 missing"); notes=JSON.parse(block).fetch("notes"); abort("N193 duplicate numeric transition missing") unless notes.include?("identity_sentinel_gap_report=validator:old-1-new-2,reviewer:old-1-new-2"); puts "migration identity duplicate numeric negative case ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md"); block=s[/## N194 - .*?```json\n(.*?)\n```/m,1] || abort("N194 missing"); notes=JSON.parse(block).fetch("notes"); abort("N194 reserved state token missing") unless notes.include?("identity_sentinel_gap_report=validator:old-none-new-blocked,reviewer:old-unknown-new-updated"); puts "migration identity reserved state negative case ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md"); block=s[/## N195 - .*?```json\n(.*?)\n```/m,1] || abort("N195 missing"); notes=JSON.parse(block).fetch("notes"); abort("N195 reserved new-state token missing") unless notes.include?("identity_sentinel_gap_report=validator:old-blocked-new-none,reviewer:old-updated-new-unknown"); puts "migration identity reserved new-state negative case ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md"); block=s[/## N170 - Paired Reserved Migration Identities.*?```json\n(.*?)\n```/m,1] || abort("N170 missing"); artifact=JSON.parse(block); notes=artifact.fetch("notes"); abort("shared sentinel negative pair missing") unless notes.include?("validator=none") && notes.include?("reviewer=unknown"); puts "migration identity sentinel negative pair ok"'
```

```bash
ruby -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); abort("reserved identity parity rule missing") unless s.include?("The reserved identity set for `validator` and `reviewer` is shared: `anonymous`, `unknown`, `tbd`, and `none`"); puts "migration reserved identity parity ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| p=r.dig("then","pattern"); p&.include?(";\\s*") && p.include?("reviewed_at_utc=") }; abort("notes semicolon token rule missing") unless rule; puts "notes semicolon tokens ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); abort("notes maxLength drift") unless schema.dig("properties","notes","maxLength") == 1536; puts "notes length cap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); cap=schema.dig("properties","notes","maxLength") || abort("notes maxLength missing"); keys=%w[anomaly_inspection from_schema to_schema artifact_path migration_command field_mapping schema_fragment_digest_before schema_fragment_digest_after artifact_kind_gap_report axis_gap_report anomaly_gap_report anomaly_evidence_gap_report measurement_kind_gap_report threshold_source_gap_report notes_reviewer_gap_report notes_reviewer_sentinel_gap_report notes_review_timestamp_gap_report notes_token_delimiter_gap_report notes_length_gap_report notes_length_old_cap notes_length_new_cap notes_length_reason notes_token_key_gap_report local_reference_gap_report local_reference_root_gap_report local_reference_dot_segment_gap_report provider_data_sent_class_gap_report provider_replay_permission_gap_report provider_pass_retention_gap_report provider_artifact_root_gap_report provider_artifact_dot_segment_gap_report command_digest_gap_report fixture_lineage_gap_report aggregate_sample_gap_report sidecar_digest_gap_report runner_environment_gap_report timing_environment_gap_report validator reviewer reviewed_at_utc]; vals=keys.map { |k| case k; when "anomaly_inspection" then "complete"; when "from_schema" then "2026-05-18.2"; when "to_schema" then "2026-05-18.3"; when "artifact_path" then "artifacts/falsifiers/f_ulp_oracle/result.json"; when "migration_command" then "tools/falsifiers/migrate_schema.sh"; when "schema_fragment_digest_before","schema_fragment_digest_after" then "sha256:" + "a" * 64; when "notes_length_old_cap" then "1024"; when "notes_length_new_cap" then "1536"; when "notes_length_reason" then "full_token_set"; when "validator" then "schema-validator"; when "reviewed_at_utc" then "2026-05-18T00:00:00Z"; else "x"; end }; min=keys.zip(vals).map { |k,v| "#{k}=#{v}" }.join("; ").length; abort("migration note minimum #{min} exceeds notes cap #{cap}") unless min <= cap; puts "migration note length feasibility ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","not","pattern") || abort("notes not pattern missing"); %w[schema_fragment_digest_before validator notes_length_old_cap notes_length_new_cap notes_length_reason local_reference_only local_reference_gap_report local_reference_root_gap_report local_reference_dot_segment_gap_report provider_data_sent_class_gap_report provider_replay_permission_gap_report provider_pass_retention_gap_report provider_artifact_root_gap_report provider_artifact_dot_segment_gap_report].each { |k| abort("notes key allowlist missing #{k}") unless pat.include?(k) }; abort("notes key parser missing") unless pat.include?("[A-Za-z_][A-Za-z0-9_]*="); puts "notes key allowlist ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); %w[provider_data_sent_class_gap_report provider_replay_permission_gap_report provider_pass_retention_gap_report provider_artifact_root_gap_report provider_artifact_dot_segment_gap_report].each { |k| abort("migration provider gap missing #{k}") unless pat.include?(k) }; puts "migration provider gaps ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); allow=notes.dig("not","pattern") || abort("notes allowlist missing"); abort("migration validator token missing") unless pat.include?("(?:^|;\\\\s*)validator=[a-z0-9][a-z0-9._-]*(?:;|$)") && allow.include?("validator"); abort("migration reviewer token missing") unless pat.include?("(?:^|;\\\\s*)reviewer=[a-z0-9][a-z0-9._-]*(?:;|$)"); puts "migration validator identity ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration version delimiter rule missing") unless pat.include?("(?:^|;\\\\s*)from_schema=") && pat.include?("(?:^|;\\\\s*)to_schema=") && s.include?("embedded substrings do not satisfy version, identity, or review-time attestation"); puts "migration version delimiters ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration path command delimiter rule missing") unless pat.include?("(?:^|;\\\\s*)artifact_path=") && pat.include?("(?:^|;\\\\s*)migration_command=") && s.include?("embedded substrings do not satisfy version, path, command, mapping, digest, identity, or review-time attestation"); puts "migration path command delimiters ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration field mapping delimiter rule missing") unless pat.include?("(?:^|;\\\\s*)field_mapping=") && s.include?("embedded substrings do not satisfy version, path, command, mapping, digest, identity, or review-time attestation"); puts "migration field mapping delimiter ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration digest delimiter rule missing") unless pat.include?("(?:^|;\\\\s*)schema_fragment_digest_before=") && pat.include?("(?:^|;\\\\s*)schema_fragment_digest_after=") && s.include?("embedded substrings do not satisfy version, path, command, mapping, digest, identity, or review-time attestation"); puts "migration digest delimiters ok"'
```

```bash
ruby -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); abort("migration validator slug rule missing") unless s.include?("validator` names the tool or terminal") && s.include?("^[a-z0-9][a-z0-9._-]*$"); abort("migration reviewer slug rule missing") unless s.include?("reviewer` names the human or accountable review identity and must use the same lowercase-slug grammar"); abort("migration validator distinctness rule missing") unless s.include?("If `validator` equals `reviewer`, the migration note is invalid"); puts "migration validator distinctness ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration identity delimiter rule missing") unless pat.include?("(?:^|;\\\\s*)validator=") && pat.include?("(?:^|;\\\\s*)reviewer=") && pat.include?("(?:^|;\\\\s*)reviewed_at_utc=") && s.include?("embedded substrings do not satisfy identity or review-time attestation"); puts "migration identity delimiters ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); %w[local_reference_gap_report local_reference_root_gap_report local_reference_dot_segment_gap_report].each { |k| abort("migration local-reference gap missing #{k}") unless pat.include?(k) }; puts "migration local-reference gaps ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration command digest gap missing") unless pat.include?("command_digest_gap_report"); puts "migration command digest gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration fixture lineage gap missing") unless pat.include?("fixture_lineage_gap_report"); puts "migration fixture lineage gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration aggregate sample gap missing") unless pat.include?("aggregate_sample_gap_report"); puts "migration aggregate sample gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration sidecar digest gap missing") unless pat.include?("sidecar_digest_gap_report"); puts "migration sidecar digest gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration runner environment gap missing") unless pat.include?("runner_environment_gap_report"); puts "migration runner environment gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration timing environment gap missing") unless pat.include?("timing_environment_gap_report"); puts "migration timing environment gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); %w[schema_fragment_digest_before schema_fragment_digest_after].each { |k| abort("migration schema fragment digest missing #{k}") unless pat.include?("#{k}=sha256:[a-f0-9]{64}") }; puts "migration schema fragment digests ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration artifact-kind gap missing") unless pat.include?("artifact_kind_gap_report"); puts "migration artifact-kind gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration axis gap missing") unless pat.include?("axis_gap_report"); puts "migration axis gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration anomaly gap missing") unless pat.include?("anomaly_gap_report"); puts "migration anomaly gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration anomaly evidence gap missing") unless pat.include?("anomaly_evidence_gap_report"); puts "migration anomaly evidence gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration measurement-kind gap missing") unless pat.include?("measurement_kind_gap_report"); puts "migration measurement-kind gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration threshold-source gap missing") unless pat.include?("threshold_source_gap_report"); puts "migration threshold-source gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration notes reviewer gap missing") unless pat.include?("notes_reviewer_gap_report"); puts "migration notes reviewer gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration notes reviewer sentinel gap missing") unless pat.include?("notes_reviewer_sentinel_gap_report"); puts "migration notes reviewer sentinel gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration notes review timestamp gap missing") unless pat.include?("notes_review_timestamp_gap_report"); puts "migration notes review timestamp gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration notes token delimiter gap missing") unless pat.include?("notes_token_delimiter_gap_report"); puts "migration notes token delimiter gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration notes length gap missing") unless pat.include?("notes_length_gap_report"); puts "migration notes length gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); allow=notes.dig("not","pattern") || abort("notes allowlist missing"); expected=%w[notes_length_old_cap notes_length_new_cap notes_length_reason]; expected.each { |k| abort("notes length cap token missing #{k}") unless pat.include?(k) && allow.include?(k) }; abort("notes length old cap grammar missing") unless pat.include?("(?:^|;\\\\s*)notes_length_old_cap=[1-9]\\\\d*(?:;|$)"); abort("notes length new cap grammar missing") unless pat.include?("(?:^|;\\\\s*)notes_length_new_cap=[1-9]\\\\d*(?:;|$)"); abort("notes length reason enum missing") unless pat.include?("(?:^|;\\\\s*)notes_length_reason=(?:full_token_set|reviewer_token_set|validator_gap_tokens)(?:;|$)"); abort("notes cap delimiter prose missing") unless s.include?("embedded substrings inside another token value do not satisfy length migration evidence"); puts "migration notes length cap tokens ok"'
```

```bash
ruby -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); abort("notes length migration rationale missing") unless s.include?("notes_length_old_cap") && s.include?("notes_length_new_cap") && s.include?("notes_length_reason") && s.include?("1024 to 1536") && s.include?("full post-witness migration token set"); puts "notes length migration rationale ok"'
```

```bash
ruby -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); abort("notes length cap order rule missing") unless s.include?("notes_length_new_cap` must be greater than `notes_length_old_cap"); puts "notes length cap order ok"'
```

```bash
ruby -e 's=File.read("docs/falsifiers/ARTIFACT_VALIDATOR_SHAPE_2026_05_18.md"); abort("notes cap parse pseudo-code missing") unless s.include?("migration_notes_parse_positive_increasing_notes_cap_tokens"); puts "notes cap parse pseudo-code ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); abort("migration notes token-key gap missing") unless pat.include?("notes_token_key_gap_report"); puts "migration notes token-key gap ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); allow=notes.dig("not","pattern") || abort("notes allowlist missing"); expected=%w[artifact_kind_gap_report axis_gap_report anomaly_gap_report anomaly_evidence_gap_report measurement_kind_gap_report threshold_source_gap_report notes_reviewer_gap_report notes_reviewer_sentinel_gap_report notes_review_timestamp_gap_report notes_token_delimiter_gap_report notes_length_gap_report notes_token_key_gap_report local_reference_gap_report local_reference_root_gap_report local_reference_dot_segment_gap_report provider_data_sent_class_gap_report provider_replay_permission_gap_report provider_pass_retention_gap_report provider_artifact_root_gap_report provider_artifact_dot_segment_gap_report command_digest_gap_report fixture_lineage_gap_report aggregate_sample_gap_report sidecar_digest_gap_report runner_environment_gap_report timing_environment_gap_report]; expected.each { |k| abort("migration gap token missing #{k}") unless pat.include?(k) && allow.include?(k) }; puts "migration gap token set ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); expected=%w[artifact_kind_gap_report axis_gap_report anomaly_gap_report anomaly_evidence_gap_report measurement_kind_gap_report threshold_source_gap_report notes_reviewer_gap_report notes_reviewer_sentinel_gap_report notes_review_timestamp_gap_report notes_token_delimiter_gap_report notes_length_gap_report notes_token_key_gap_report local_reference_gap_report local_reference_root_gap_report local_reference_dot_segment_gap_report provider_data_sent_class_gap_report provider_replay_permission_gap_report provider_pass_retention_gap_report provider_artifact_root_gap_report provider_artifact_dot_segment_gap_report command_digest_gap_report fixture_lineage_gap_report aggregate_sample_gap_report sidecar_digest_gap_report runner_environment_gap_report timing_environment_gap_report]; expected.each { |k| abort("migration gap value grammar missing #{k}") unless pat.include?("#{k}=[A-Za-z0-9._,/:+-]+") }; puts "migration gap value grammar ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern") == "from_schema=" } || abort("migration note rule missing"); pat=rule.dig("then","pattern") || abort("migration note pattern missing"); expected=%w[artifact_kind_gap_report axis_gap_report anomaly_gap_report anomaly_evidence_gap_report measurement_kind_gap_report threshold_source_gap_report notes_reviewer_gap_report notes_reviewer_sentinel_gap_report notes_review_timestamp_gap_report notes_token_delimiter_gap_report notes_length_gap_report notes_token_key_gap_report local_reference_gap_report local_reference_root_gap_report local_reference_dot_segment_gap_report provider_data_sent_class_gap_report provider_replay_permission_gap_report provider_pass_retention_gap_report provider_artifact_root_gap_report provider_artifact_dot_segment_gap_report command_digest_gap_report fixture_lineage_gap_report aggregate_sample_gap_report sidecar_digest_gap_report runner_environment_gap_report timing_environment_gap_report]; expected.each { |k| abort("migration gap delimiter missing #{k}") unless pat.include?("(?:^|;\\\\s*)#{k}=[A-Za-z0-9._,/:+-]+(?:;|$)") }; abort("migration gap delimiter prose missing") unless s.include?("Every `*_gap_report` migration token follows the same delimiter rule"); puts "migration gap delimiters ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern")&.include?("local_reference_only=true") && r.dig("then","pattern")&.include?("local_reference_artifact_sha256=sha256:") }; abort("local reference notes rule missing") unless rule; puts "local reference notes ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); notes=schema.dig("properties","notes") || abort("notes missing"); rule=notes["allOf"].find { |r| r.dig("if","pattern")&.include?("local_reference_only=true") && r.dig("then","pattern")&.include?("artifacts/falsifiers/70b_local_cocktail_lite/") }; abort("local reference row root rule missing") unless rule; puts "local reference row root ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("properties","notes","not","pattern") || abort("notes not pattern missing"); abort("local reference dot-segment rule missing") unless pat.include?("local_reference_artifact=[^;]*(?:\\.\\.|/\\./)"); puts "local reference dot segment ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); abort("provider artifact_ref_sha256 not required") unless schema.dig("$defs","provider_receipt","required").include?("artifact_ref_sha256"); abort("raw_artifact_sha256 missing") unless schema.dig("properties","measurements","patternProperties","^[a-z][a-z0-9_]*$","properties","raw_artifact_sha256","pattern") == "^sha256:[a-f0-9]{64}$"; abort("upstream_artifact_sha256 missing") unless schema.dig("properties","acceptance_thresholds","patternProperties","^[a-z][a-z0-9_]*$","properties","upstream_artifact_sha256","pattern") == "^sha256:[a-f0-9]{64}$"; puts "sidecar digest fields ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pat=schema.dig("$defs","provider_receipt","properties","artifact_ref","pattern") || abort("provider artifact_ref pattern missing"); abort("provider dot-segment rule missing") unless pat.include?("?!.*?/\\.\\.?(?:/|$)"); puts "provider artifact dot segment ok"'
```

```bash
rg -q 'expected artifact root for the owning `falsifier_id`' docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md && rg -q 'provider_receipt_artifact_refs_exist_under_falsifier_root' docs/falsifiers/ARTIFACT_VALIDATOR_SHAPE_2026_05_18.md
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); pr=schema.dig("$defs","provider_receipt") || abort("provider_receipt missing"); rule=pr["allOf"].any? { |r| r.dig("not","properties","data_sent_class","const") == "none" }; abort("provider data_sent_class none rule missing") unless rule; puts "provider data sent class ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); enum=schema.dig("$defs","provider_receipt","properties","data_sent_class","enum") || abort("provider data_sent_class enum missing"); abort("provider prompt_text class still allowed") if enum.include?("prompt_text"); puts "provider prompt text class blocked"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); abort("provider replay_allowed not true") unless schema.dig("$defs","provider_receipt","properties","replay_allowed","const") == true; puts "provider replay permission ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); rule=schema["allOf"].find { |r| r.dig("if","properties","overall_pass","const") == true && (r.dig("if","required") || []).include?("provider_receipts") } || abort("provider pass retention rule missing"); abort("provider pass retention not zero") unless rule.dig("then","properties","provider_receipts","items","properties","retention_claim","const") == "zero_retention"; puts "provider pass retention ok"'
```

```bash
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); a=schema.dig("properties","anomalies","items") || abort("anomaly schema missing"); abort("evidence_ref pattern missing") unless a.dig("properties","evidence_ref","pattern")&.include?("artifacts/falsifiers"); blocking=a["allOf"].any? { |rule| rule.dig("if","properties","severity","const") == "blocking" && (rule.dig("then","required") || []).include?("evidence_ref_sha256") }; abort("blocking evidence rule missing") unless blocking; puts "blocking anomaly evidence ok"'
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
ruby -rjson -e 's=File.read("docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md"); schema=JSON.parse(s[/```json\n(.*?)\n```/m,1]); t=schema.dig("properties","acceptance_thresholds","patternProperties","^[a-z][a-z0-9_]*$") || abort("threshold shape missing"); abort("threshold_source not required") unless t["required"].include?("threshold_source"); expected=%w[handbook_row fragment_contract upstream_artifact provider_receipt]; abort("threshold_source enum drift") unless t.dig("properties","threshold_source","enum") == expected; upstream=t["allOf"].any? { |rule| rule.dig("if","properties","threshold_source","const") == "upstream_artifact" && (rule.dig("then","required") || []).include?("upstream_artifact_sha256") }; provider=t["allOf"].any? { |rule| rule.dig("if","properties","threshold_source","const") == "provider_receipt" && (rule.dig("then","required") || []).include?("provider_receipt_ref") }; abort("upstream threshold_source rule missing") unless upstream; abort("provider threshold_source rule missing") unless provider; puts "threshold source ok"'
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

| Work row | Owner | Trigger | Required output |
|---|---|---|---|
| `W-Validator-ToolchainIdentity` | TBD validator-implementation terminal | Any executable validator accepts falsifier artifacts with `runner_environment.toolchain_identity`. | Reject missing, extra-key, multi-line, vague-sentinel, or non-ref `$defs.toolchain_identity` drift before artifact replay. |
| `W-Validator-ThresholdSource` | TBD validator-implementation terminal | Any executable validator accepts falsifier artifacts with `acceptance_thresholds[*].threshold_source`. | Reject missing threshold sources, upstream/provider source mismatch, missing provider receipt refs, or provider refs not matching retained `provider_receipts[*].request_id_hash`. |
| `W-Validator-CommandDigest` | TBD validator-implementation terminal | Any executable validator accepts falsifier artifacts with `command_digest`. | Recompute `sha256:` over the normalized command string and reject missing, mismatched, or manifest-drifted command digests before script replay. |
| `W-Validator-FixtureLineageDigest` | TBD validator-implementation terminal | Any executable validator accepts falsifier artifacts with `fixture_lineage.fixture_manifest`. | Recompute `fixture_manifest_sha256`, reject missing or mismatched manifest bytes, and require retained fixture manifests before generated-fixture replay. |
| `W-Validator-NotesReviewerToken` | TBD validator-implementation terminal | Any executable validator accepts non-`none` falsifier `notes`. | Reject non-`none` notes missing `anomaly_inspection=complete` or lowercase-slug `reviewer=<id>` before anomaly or migration review. |
| `W-Validator-NotesReviewerDelimiter` | TBD validator-implementation terminal | Any executable validator accepts non-`none` falsifier `notes`. | Reject embedded `reviewer=<id>` substrings that are not bounded by note start/end or semicolon delimiters before anomaly or migration review. |
| `W-Validator-NotesAnomalyInspectionDelimiter` | TBD validator-implementation terminal | Any executable validator accepts non-`none` falsifier `notes`. | Reject embedded `anomaly_inspection=complete` substrings that are not bounded by note start/end or semicolon delimiters before anomaly review. |
| `W-Validator-NotesReviewTimestamp` | TBD validator-implementation terminal | Any executable validator accepts non-`none` falsifier `notes`. | Reject non-`none` notes missing `reviewed_at_utc=<RFC3339Z>` or using an offset/local timestamp before replay promotion. |
| `W-Validator-NotesReviewTimestampDelimiter` | TBD validator-implementation terminal | Any executable validator accepts non-`none` falsifier `notes`. | Reject embedded `reviewed_at_utc=<RFC3339Z>` substrings that are not bounded by note start/end or semicolon delimiters before replay promotion. |
| `W-Validator-NotesReviewerSentinel` | TBD validator-implementation terminal | Any executable validator accepts reviewer tokens in falsifier `notes`. | Reject reserved reviewer identities `anonymous`, `unknown`, `tbd`, and `none` only when they appear as bounded reviewer tokens before anomaly or migration review. |
| `W-Validator-NotesTokenDelimiter` | TBD validator-implementation terminal | Any executable validator accepts machine-readable tokens in falsifier `notes`. | Reject whitespace-separated required notes tokens and require semicolon-delimited `key=value` parsing before replay promotion. |
| `W-Validator-NotesLengthCap` | TBD validator-implementation terminal | Any executable validator accepts falsifier `notes`. | Reject notes longer than 1536 characters before replay promotion or migration acceptance, while preserving room for the full migration gap-token set. |
| `W-Validator-NotesLengthMigrationReason` | TBD validator-implementation terminal | Any executable validator accepts schema migrations that alter `notes.maxLength`. | Reject length-cap migrations unless the migration note names positive `notes_length_old_cap`, greater positive `notes_length_new_cap`, and closed-enum `notes_length_reason` for the capacity change. |
| `W-Validator-MigrationNotesLengthDelimiter` | TBD validator-implementation terminal | Any executable validator accepts notes length-cap migration tokens. | Reject embedded `notes_length_old_cap`, `notes_length_new_cap`, or `notes_length_reason` token substrings that are not bounded by note start/end or semicolon delimiters before migration acceptance. |
| `W-Validator-NotesTokenKeyAllowlist` | TBD validator-implementation terminal | Any executable validator accepts machine-readable `key=value` tokens in falsifier `notes`. | Reject note tokens whose keys are not schema-owned before replay promotion or migration acceptance. |
| `W-Validator-MigrationGapTokens` | TBD validator-implementation terminal | Any executable validator accepts `from_schema=` migration notes. | Reject migration notes missing any schema-table gap token, reject gap tokens absent from both the notes key allowlist and the `from_schema=` regex, and reject whitespace-bearing gap-token values before migration acceptance. |
| `W-Validator-MigrationGapDelimiter` | TBD validator-implementation terminal | Any executable validator accepts `*_gap_report` tokens in migration notes. | Reject embedded gap-report token substrings that are not bounded by note start/end or semicolon delimiters before migration acceptance. |
| `W-Validator-MigrationVersionDelimiter` | TBD validator-implementation terminal | Any executable validator accepts `from_schema` or `to_schema` tokens in migration notes. | Reject embedded version-token substrings that are not bounded by note start/end or semicolon delimiters before migration acceptance. |
| `W-Validator-MigrationPathCommandDelimiter` | TBD validator-implementation terminal | Any executable validator accepts `artifact_path` or `migration_command` tokens in migration notes. | Reject embedded path or command token substrings that are not bounded by note start/end or semicolon delimiters before migration acceptance. |
| `W-Validator-MigrationFieldMappingDelimiter` | TBD validator-implementation terminal | Any executable validator accepts `field_mapping` tokens in migration notes. | Reject embedded field-mapping token substrings that are not bounded by note start/end or semicolon delimiters before migration acceptance. |
| `W-Validator-MigrationDigestDelimiter` | TBD validator-implementation terminal | Any executable validator accepts schema fragment digest tokens in migration notes. | Reject embedded schema-fragment digest token substrings that are not bounded by note start/end or semicolon delimiters before migration acceptance. |
| `W-Validator-MigrationValidatorIdentity` | TBD validator-implementation terminal | Any executable validator accepts `from_schema=` migration notes. | Reject migration notes missing a lowercase-slug `validator` token, missing a lowercase-slug human `reviewer` token, or using the same value for both before migration acceptance. |
| `W-Validator-MigrationIdentityDelimiter` | TBD validator-implementation terminal | Any executable validator accepts `validator`, `reviewer`, or `reviewed_at_utc` tokens in migration notes. | Reject embedded identity or review-time token substrings that are not bounded by note start/end or semicolon delimiters before migration acceptance. |
| `W-Validator-MigrationValidatorSentinel` | TBD validator-implementation terminal | Any executable validator accepts `validator` tokens in migration notes. | Reject reserved validator identities `anonymous`, `unknown`, `tbd`, and `none` only when they appear as bounded validator tokens before migration acceptance. |
| `W-Validator-MigrationReviewerSentinel` | TBD validator-implementation terminal | Any executable validator accepts `reviewer` tokens in migration notes. | Reject reserved reviewer identities `anonymous`, `unknown`, `tbd`, and `none` only when they appear as bounded reviewer tokens before migration acceptance. |
| `W-Validator-MigrationIdentitySentinelParity` | TBD validator-implementation terminal | Any executable validator accepts reserved identity changes for migration note tokens. | Reject schema edits that make validator and reviewer sentinel regexes differ from each other or from the exact shared set `anonymous|unknown|tbd|none` before migration acceptance. |
| `W-Validator-MigrationIdentitySentinelGap` | TBD validator-implementation terminal | Any executable validator accepts shared identity sentinel changes with a reviewer-only migration gap. | Require `identity_sentinel_gap_report` to name both `validator:<impact>` and `reviewer:<impact>` role labels before migration acceptance. |
| `W-Validator-MigrationIdentitySentinelGapValues` | TBD validator-implementation terminal | Any executable validator accepts reserved words as identity sentinel gap role impacts. | Reject `identity_sentinel_gap_report` when either role-impact value equals `anonymous`, `unknown`, `tbd`, or `none` before migration acceptance. |
| `W-Validator-MigrationIdentitySentinelGapComma` | TBD validator-implementation terminal | Any executable validator accepts comma-bearing identity sentinel role-impact values. | Reject `identity_sentinel_gap_report` role-impact values containing commas because comma is the validator/reviewer role separator. |
| `W-Validator-MigrationIdentitySentinelGapSlug` | TBD validator-implementation terminal | Any executable validator accepts uppercase or symbolic identity sentinel role-impact values. | Reject `identity_sentinel_gap_report` role-impact values unless both are lowercase old/new atoms before migration acceptance. |
| `W-Validator-MigrationIdentitySentinelGapOldNew` | TBD validator-implementation terminal | Any executable validator accepts role-impact values without old/new state transitions. | Reject `identity_sentinel_gap_report` role-impact values unless both use `old-<state>-new-<state>` before migration acceptance. |
| `W-Validator-MigrationIdentitySentinelGapNestedDelimiters` | TBD validator-implementation terminal | Any executable validator accepts nested transition markers inside old/new state atoms. | Reject role-impact state atoms containing nested `old-` or `-new-` transition delimiters before migration acceptance. |
| `W-Validator-MigrationIdentitySentinelGapStateEndpoints` | TBD validator-implementation terminal | Any executable validator accepts punctuation-bounded identity gap state atoms. | Reject old/new state atoms that do not begin and end with lowercase alphanumeric text before migration acceptance. |
| `W-Validator-MigrationIdentitySentinelGapNumericLeading` | TBD validator-implementation terminal | Any executable validator rewrites identity gap state grammar to letter-only starts. | Preserve lowercase numeric-leading state atoms as valid while still rejecting punctuation-leading state atoms. |
| `W-Validator-MigrationIdentitySentinelGapNumericOnly` | TBD validator-implementation terminal | Any executable validator rejects numeric-only old/new state atoms. | Preserve numeric-only state atoms as valid identity transition labels while still enforcing old/new structure. |
| `W-Validator-MigrationIdentitySentinelGapInternalDot` | TBD validator-implementation terminal | Any executable validator rejects dot-separated identity state atoms. | Preserve internal dots inside state atoms while still rejecting leading or trailing dots. |
| `W-Validator-MigrationIdentitySentinelGapInternalUnderscore` | TBD validator-implementation terminal | Any executable validator rejects underscore-separated identity state atoms. | Preserve internal underscores inside state atoms while still rejecting leading or trailing underscores. |
| `W-Validator-MigrationIdentitySentinelGapInternalHyphen` | TBD validator-implementation terminal | Any executable validator rejects hyphen-separated identity state atoms. | Preserve internal hyphens inside state atoms while still rejecting leading or trailing hyphens. |
| `W-Validator-MigrationIdentitySentinelGapDuplicateNumeric` | TBD validator-implementation terminal | Any executable validator treats numeric-only identity gap transitions as automatically distinct by role. | Keep N193 failing: numeric-only state atoms are valid labels, but identical validator/reviewer role-impact transitions are still invalid. |
| `W-Validator-MigrationIdentitySentinelGapReservedState` | TBD validator-implementation terminal | Any executable validator allows reserved identity words as old/new state atoms. | Keep N194 failing: state atoms may not equal `anonymous`, `unknown`, `tbd`, or `none` even inside otherwise well-shaped role-impact transitions. |
| `W-Validator-MigrationIdentitySentinelGapReservedNewState` | TBD validator-implementation terminal | Any executable validator only checks old-state atoms for reserved identity words. | Keep N195 failing: new-state atoms may not equal `anonymous`, `unknown`, `tbd`, or `none` either. |
| `W-Validator-MigrationIdentitySlugCatalog` | TBD validator-implementation terminal | Any executable validator hard-codes identity gap families without schema catalog lookup. | Keep the schema identity-gap slug catalog as the vocabulary source for validator ownership, handbook audits, and negative examples. |
| `W-Validator-MigrationIdentitySlugCatalogNegative` | TBD validator-implementation terminal | Any executable validator accepts validator-owned identity slugs missing from the schema catalog. | Keep N196 failing so validator-shape and handbook references cannot mint uncataloged identity-gap families. |
| `W-Validator-MigrationIdentitySlugGrammarNegative` | TBD validator-implementation terminal | Any executable validator accepts underscore, uppercase, title-case, boundary-punctuation, or empty-token identity-gap slug aliases. | Keep N197/N198/N199/N200/N201 failing so identity-gap slug references use only lowercase hyphenated catalog tokens. |
| `W-Validator-MigrationIdentitySentinelGapDistinct` | TBD validator-implementation terminal | Any executable validator accepts identical validator/reviewer identity sentinel impacts. | Reject `identity_sentinel_gap_report` when validator and reviewer role-impact values are identical before migration acceptance. |
| `W-Validator-MigrationIdentitySentinelGapDelimiter` | TBD validator-implementation terminal | Any executable validator accepts embedded `identity_sentinel_gap_report` substrings. | Reject identity sentinel gap-report token substrings that are not bounded by note start/end or semicolon delimiters before migration acceptance. |
| `W-Validator-MigrationIdentitySentinelGapArtifactPath` | TBD validator-implementation terminal | Any executable validator accepts identity sentinel gap reports without an affected artifact path. | Bind every `identity_sentinel_gap_report` to the migration note `artifact_path` before migration acceptance. |
| `W-Validator-MigrationIdentitySentinelGapNegativeCases` | TBD validator-implementation terminal | Any executable validator omits one of the identity sentinel gap negative fixtures. | Keep missing, embedded, unlabeled, reserved, comma-bearing, uppercase, identical-impact, detached-artifact, missing-old-new, half-old-new, swapped-half-old-new, empty-old-state, empty-new-state, reversed-old-new, nested-old-marker, nested-new-marker, leading-dot-state, leading-hyphen-state, trailing-dot-state, trailing-hyphen-state, leading-underscore-state, trailing-underscore-state, duplicate-numeric-transition, reserved-state, and reserved-new-state identity gap examples failing before migration acceptance. |
| `W-Validator-MigrationIdentitySentinelNegativePair` | TBD validator-implementation terminal | Any executable validator accepts only single-sided reserved identity fixtures. | Keep a paired validator/reviewer reserved-identity negative catalog case failing before migration acceptance. |
| `W-Validator-LocalReferenceNotes` | TBD validator-implementation terminal | Any executable validator accepts `local_reference_only=true` in falsifier `notes`. | Reject missing `local_reference_artifact` or `local_reference_artifact_sha256`, and verify the retained artifact digest before replay promotion. |
| `W-Validator-LocalReferenceRoot` | TBD validator-implementation terminal | Any executable validator accepts local-reference artifacts in falsifier `notes`. | Reject `local_reference_artifact` paths outside the owning falsifier row root before digest verification. |
| `W-Validator-LocalReferenceDotSegments` | TBD validator-implementation terminal | Any executable validator accepts local-reference artifact paths in falsifier `notes`. | Reject `.` or `..` path segments in `local_reference_artifact` before row-root or digest checks. |
| `W-Validator-ProviderDataSentClass` | TBD validator-implementation terminal | Any executable validator accepts provider receipt `data_sent_class`. | Reject present provider receipts that claim `data_sent_class=none` or `prompt_text`; local-only evidence must omit `provider_receipts` or use the 70B local-reference notes path. |
| `W-Validator-ProviderReplayPermission` | TBD validator-implementation terminal | Any executable validator accepts provider receipt `replay_allowed`. | Reject provider receipts with `replay_allowed=false`; non-replayable provider output cannot promote a pass witness. |
| `W-Validator-ProviderPassRetention` | TBD validator-implementation terminal | Any executable validator accepts pass witnesses with provider receipts. | Reject `overall_pass=true` provider receipts unless every `retention_claim` is `zero_retention`; weaker claims may remain failure-report evidence only. |
| `W-Validator-ProviderArtifactRoot` | TBD validator-implementation terminal | Any executable validator accepts provider receipt artifact refs. | Reject provider receipt `artifact_ref` paths outside `expected_artifact_root_map[falsifier_id]` before digest checks. |
| `W-Validator-ProviderArtifactDotSegments` | TBD validator-implementation terminal | Any executable validator accepts provider receipt artifact refs. | Reject `.` or `..` path segments in provider receipt `artifact_ref` before root or digest checks. |
| `W-Validator-BlockingAnomalyEvidence` | TBD validator-implementation terminal | Any executable validator accepts blocking anomaly ledgers. | Recompute every blocking anomaly `evidence_ref_sha256`, reject missing evidence refs, and keep the referenced anomaly evidence retained with the witness. |
| `W-Validator-ArtifactKindCoupling` | TBD validator-implementation terminal | Any executable validator accepts `artifact_kind` on falsifier artifacts. | Reject artifact-kind/pass/fallback mismatches, especially `failure_report` with `overall_pass=true`, before row promotion logic runs. |
