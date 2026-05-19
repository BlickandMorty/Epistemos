---
state: t23b-falsifier-artifact-schema
created_on: 2026-05-18
schema_version: 2026-05-18.2
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
---

# Falsifier Artifact Schema - 2026-05-18

This schema defines the canonical witness artifact contract for every T23B F-* falsifier. It generalizes the T12 [F-ULP-Oracle](F_ULP_ORACLE_2026_05_18.md) witness pattern into a shared document shape. A row in the M2 Pro Verified Floor Handbook may not claim runtime evidence unless its artifact uses this contract or a documented successor.

## Canon Anchors

This artifact schema is subordinate to the active canon: [MASTER_FUSION](../_consolidated/00_canonical_authority/MASTER_FUSION.md) for the local-computer, zero-copy, and KV precision claims, and [Unified Active Substrate Canon](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md) for UAS/ACS naming, V6.2 falsifier order, MAS-first sorting, and dependency discipline.

## Initial Fields

| Field | Type | Required | Rule |
|---|---|---|---|
| `falsifier_id` | string | yes | Exact F-* identifier from the handbook row, for example `F-ULP-Oracle`. |
| `schema_version` | string | yes | Schema version for this artifact contract. Initial value: `2026-05-18.2`. |
| `artifact_kind` | string | yes | Artifact classification: `primary_witness`, `fallback_witness`, or `failure_report`. |
| `hardware_pin` | object | yes | Jojo's M2 Pro hardware floor for the run; substitutes such as M2 Max, M3 Max, or theoretical bandwidth fail the artifact. |
| `command` | string | yes | Exact command line used to produce the artifact. It must match the row command after `NOT IMPLEMENTED:` is removed. |
| `command_digest` | string | yes | Lowercase `sha256:` digest of the normalized command string used for replay. |
| `runner_environment` | object | yes | Closed execution-context pin for cwd, shell, environment policy, locale, timezone, macOS build, toolchain identity, thermal state, and power source. |
| `commit_sha` | string | yes | Full 40-character lowercase hex Git commit SHA for the repo state that produced the artifact. Short SHAs fail replay eligibility. |
| `fixture_id` | string | yes | Stable fixture identifier for the input set, including dataset/config version when applicable. |
| `fixture_lineage` | object | no | Structured recovery metadata for generated, seeded, or versioned fixtures. |
| `timestamp_utc` | string | yes | UTC timestamp for artifact creation in RFC 3339 date-time form. Local time zones fail the artifact. |
| `result_digest` | string | yes | Lowercase `sha256:` digest for the canonical result payload used by replay. |
| `measurements` | object | yes | Per-axis measured values from the run. Each axis must be named and must include a value plus unit. |
| `acceptance_thresholds` | object | yes | Per-axis pass criteria. Each threshold must name an operator, value, and unit so the artifact can be replayed against the handbook row. |
| `pass_per_axis` | object | yes | Per-axis boolean validator result. Axis names should match the measurement and threshold axes. |
| `overall_pass` | boolean | yes | Falsifier-level result after all required axes are evaluated. Runtime witness status requires `true`; preserved speculation remains non-witness. |
| `fallback_tier` | string | yes | T12 ladder value: `Primary`, `Fallback`, or `Fail`. `Fail` means no acceptable fallback runtime witness was produced. |
| `anomalies` | array | yes | Structured anomaly ledger. Use an empty array only when no rig, input, output, timing, memory, fallback, or unsupported-case anomaly occurred. |
| `notes` | string | yes | Human-readable caveats or replay notes. Use `none` when there is nothing to add. |
| `provider_receipts` | array | no | Required only when a falsifier uses cloud, hosted, or external-provider evidence; absent means local-only evidence. |

## Hardware Pin Rule

`hardware_pin` must identify Jojo's M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s memory-bandwidth floor. M2 Max, M3 Max, cloud GPU, simulator, and theoretical-bandwidth substitutions fail schema validation.

## Hardware Pin Schema Definition Rule

The JSON Schema fragment centralizes the current hardware floor under `$defs.hardware_pin`; the top-level `hardware_pin` field must reference that definition. This keeps every artifact on Jojo's M2 Pro 16 GB UMA floor while preserving the `2026-05-18.2` field names.

## Hardware Pin Typed Sub-Schema Target

The next hardware-pin schema revision should replace prose-shaped fields with typed fields: `model_identifier`, `chip`, `cpu_cores`, `gpu_cores`, `memory_gb`, `uma`, and `memory_bandwidth_gb_s`. Until that bump lands, the current JSON fragment remains authoritative; artifacts must not pre-adopt the target shape under schema version `2026-05-18.2`.

## Hardware Pin Migration Mapping

For the next schema bump, `machine` maps to `model_identifier`, `cpu` maps to `cpu_cores`, `gpu` maps to `gpu_cores`, `unified_memory_gb` maps to `memory_gb`, and `memory_bandwidth_gb_s` keeps its name. The new `chip` field must equal `M2 Pro`, and `uma` must be `true`.

## Falsifier ID Rule

`falsifier_id` must be the exact canonical row identifier from the handbook and the matching fragment frontmatter. The JSON Schema fragment enumerates the 15 accepted IDs; aliases such as `F-ULP`, `F-KV-Direct`, or `F-VaultRecall` are allowed in prose only and fail artifact identity.

## Falsifier Map Alignment Rule

The `falsifier_id` enum, cross-gate axis floor table, command path map, and expected artifact root map must cover the same 15 canonical IDs. Adding, removing, or renaming a gate is invalid unless all four surfaces change together.

## Schema Version Rule

`schema_version` must equal the version constant in the JSON Schema fragment. Artifacts from older schema versions are preserved historical evidence only until they are replayed or migrated with an explicit migration note; they may not satisfy a current handbook pass claim by silent compatibility.

## Schema Migration Table

| From | To | Trigger | Migration note requirement |
|---|---|---|---|
| `2026-05-18.1` | `2026-05-18.2` | Structured `anomalies` became required and cross-gate axis floors became explicit. | Name the source artifact, state whether anomalies were inspected, and map every legacy axis to the current minimum axis set. |
| `2026-05-18.2` | `2026-05-18.3` | Any real `.2` witness exists and the fragment then changes artifact-kind pass coupling, required axis floors, anomaly base fields, anomaly evidence reference fields, per-kind anomaly required fields, measurement evidence-kind fields, threshold-source fields, aggregate sample-count fields, notes reviewer, reviewer-sentinel, review-time, token-delimiter, length-cap, token-key allowlist, local-reference artifact, local-reference row-root, local-reference dot-segment, provider data-sent class, provider replay permission, provider pass-retention, provider-artifact root, or provider-artifact dot-segment fields, JSONL row fields, command path map, command digest fields, fixture-lineage digest fields, expected-artifact-root map, sidecar digest reference fields, provider receipt required fields, runner-environment shape, runner OS-build field, runner toolchain identity field, runner thermal/power fields, timing thermal/power gates, result-digest canonicalization, or the hardware-pin shape. | Include `schema_fragment_digest_before`, `schema_fragment_digest_after`, `artifact_kind_gap_report`, `axis_gap_report`, `anomaly_gap_report`, `anomaly_evidence_gap_report`, `measurement_kind_gap_report`, `threshold_source_gap_report`, `notes_reviewer_gap_report`, `notes_reviewer_sentinel_gap_report`, `notes_review_timestamp_gap_report`, `notes_token_delimiter_gap_report`, `notes_length_gap_report`, `notes_length_old_cap`, `notes_length_new_cap`, `notes_length_reason`, `notes_token_key_gap_report`, `local_reference_gap_report`, `local_reference_root_gap_report`, `local_reference_dot_segment_gap_report`, `provider_data_sent_class_gap_report`, `provider_replay_permission_gap_report`, `provider_pass_retention_gap_report`, `provider_artifact_root_gap_report`, `provider_artifact_dot_segment_gap_report`, `command_digest_gap_report`, `fixture_lineage_gap_report`, `aggregate_sample_gap_report`, `sidecar_digest_gap_report`, `runner_environment_gap_report`, `timing_environment_gap_report`, validator command, and reviewer. |
| `2026-05-18.2` | next | New F-* gate, changed artifact-kind pass coupling, typed hardware-pin sub-schema, changed command-path map, changed command-digest requirement, changed fixture-lineage digest requirement, changed expected-artifact-root map, expanded anomaly requirements, changed anomaly evidence reference requirement, changed measurement evidence-kind requirement, changed threshold-source requirement, changed aggregate sample-count requirement, changed notes reviewer, reviewer-sentinel, review-time, token-delimiter, length-cap, token-key allowlist, local-reference artifact, local-reference row-root, local-reference dot-segment, provider data-sent class, provider replay permission, provider pass-retention, provider-artifact root, or provider-artifact dot-segment requirement, changed sidecar digest reference requirement, changed runner-environment requirement, changed runner OS-build field, changed runner toolchain identity field, changed runner thermal/power field, changed timing thermal/power gate, changed provider receipt required field, or changed top-level witness field. | Include `from_schema`, `to_schema`, `artifact_path`, `migration_command`, `field_mapping`, and `reviewer` in `notes` or a linked migration artifact. |

## Migration Note Minimum Shape

Migration notes must name `from_schema`, `to_schema`, `artifact_path`, `migration_command`, `field_mapping`, `reviewer`, and `reviewed_at_utc`. If a schema fragment changes after a witness exists, the note must also include `schema_fragment_digest_before` and `schema_fragment_digest_after` in lowercase `sha256:` form. If threshold-source fields change, `threshold_source_gap_report` must name every added or rewritten `threshold_source` and any `provider_receipt_ref` introduced by the migration. If notes reviewer requirements change, `notes_reviewer_gap_report` must name every migrated artifact whose previous `notes` value lacked a reviewer token and the reviewer identity now attached. If reserved reviewer sentinels change, `notes_reviewer_sentinel_gap_report` must name every migrated artifact whose previous `notes` value used or newly conflicts with a reserved reviewer identity. If notes review-time requirements change, `notes_review_timestamp_gap_report` must name every migrated artifact whose previous `notes` value lacked `reviewed_at_utc` and the UTC timestamp now attached. If token delimiter requirements change, `notes_token_delimiter_gap_report` must name every migrated artifact whose previous `notes` value used whitespace-separated machine tokens. If notes length requirements change, `notes_length_gap_report` must name every migrated artifact whose previous `notes` value exceeds the new cap, `notes_length_old_cap` and `notes_length_new_cap` must carry integer cap values, and `notes_length_reason` must carry the machine-readable reason; the pre-witness `.2` cap moved from 1024 to 1536 so a full post-witness migration token set can fit. If notes token-key allowlists change, `notes_token_key_gap_report` must name every migrated artifact whose previous `notes` value used a now-disallowed machine token key. If local-reference artifact fields change, `local_reference_gap_report` must name every migrated artifact whose `local_reference_only=true` note lacks a retained artifact path or digest. If local-reference row-root fields change, `local_reference_root_gap_report` must name every migrated artifact whose local reference path moved into the row root. If local-reference dot-segment fields change, `local_reference_dot_segment_gap_report` must name every migrated artifact whose local reference path needed dot-segment removal. If provider data-sent class fields change, `provider_data_sent_class_gap_report` must name every migrated provider receipt that previously claimed `data_sent_class=none` or `data_sent_class=prompt_text`. If provider replay permission fields change, `provider_replay_permission_gap_report` must name every migrated provider receipt that previously claimed `replay_allowed=false`. If provider pass-retention fields change, `provider_pass_retention_gap_report` must name every migrated pass witness whose provider receipt previously used a retention claim other than `zero_retention`. If provider-artifact root fields change, `provider_artifact_root_gap_report` must name every migrated provider receipt whose artifact path moved into the owning row root. If provider-artifact dot-segment fields change, `provider_artifact_dot_segment_gap_report` must name every migrated provider receipt whose artifact path needed dot-segment removal. A migrated artifact without these required values remains historical evidence, not a current pass witness.

## Migration Note Token Rule

Migration notes must encode their migration fields as semicolon-delimited `key=value` tokens inside `notes`, using ASCII keys and values. When `from_schema=` appears, the JSON Schema fragment requires the base migration keys so validator tooling can parse the note without natural-language inference.

## Pre-Witness Tightening Rule

While no real T23B artifact exists under schema `2026-05-18.2`, this document may tighten the `.2` fragment to close obvious validation gaps. After the first real `.2` witness lands, any further change to field presence, axis floors, anomaly requirements, JSONL row shape, command paths, artifact roots, or hardware-pin structure must bump the schema version.

## Schema Fragment Digest Rule

When a migration note names `schema_fragment_digest_before` or `schema_fragment_digest_after`, each digest must be lowercase `sha256:` followed by 64 hex characters. The digest is computed over the exact first fenced JSON block after normalizing line endings to LF and preserving all other bytes.

## Replay Identity Rule

`command` must match the handbook row command after `NOT IMPLEMENTED:` is removed, and `commit_sha` must identify the repo state that produced the artifact with a full 40-character lowercase hex SHA. A witness with a stale command, missing commit, short SHA, or commit from another branch is replay-ineligible.

## Result Digest Rule

`result_digest` must be a lowercase `sha256:` digest of the canonical result payload used by replay. For object artifacts, the validator computes it over the witness JSON after removing `result_digest` and canonicalizing object keys with LF line endings. For JSONL artifacts, the validator computes it over the full LF-normalized `result.jsonl` byte stream. A digest copied from a sidecar, raw stdout, or prose note cannot substitute for the canonical result digest.

Object-artifact canonicalization is deterministic: parse the witness as JSON, remove only the root `result_digest` key, sort every object by bytewise UTF-8 key order, preserve array order, emit strings with standard JSON escaping, emit finite numbers without locale formatting, use no insignificant whitespace, append one final LF, then compute SHA-256 over those UTF-8 bytes. The validator must reject non-finite numbers before digesting, so `NaN`, `Infinity`, and locale-formatted numeric strings never become digest-stable evidence.

## Provider Receipt Rule

Artifacts are local-only by default. If a falsifier uses cloud, hosted, or external-provider evidence for reference logits, model output, oracle comparison, or replay support, it must include `provider_receipts`. Each receipt must name the provider, model or service, purpose, hashed request ID, UTC timestamp, sent-data class, retention claim, redaction digest, replay permission flag, and local artifact reference inside the expected artifact root for the owning `falsifier_id`. A present receipt may not use `data_sent_class=none`, and `prompt_text` is not an allowed sent-data class; local-only evidence is represented by absent `provider_receipts` or by the explicit `local_reference_only=true` notes path for the 70B row. Provider `replay_allowed` must be `true`; non-replayable provider output is not promotable witness evidence. Pass witnesses with provider receipts must use `retention_claim=zero_retention`; weaker retention claims may only appear in retained failure reports. Provider `artifact_ref` paths may not contain `.` or `..` path segments. Provider URLs, raw API keys, raw prompts, and unredacted provider payloads do not belong in the witness JSON.

For `F-70B-Local-Cocktail-Lite`, a witness must either include `provider_receipts` for the cloud/fp16 reference path or set `local_reference_only=true` in `notes` and provide local reference replay material through ordinary artifact references. The local-only token must pair with `local_reference_artifact=artifacts/falsifiers/70b_local_cocktail_lite/...` and `local_reference_artifact_sha256=sha256:<64hex>` so the replacement reference is retained inside the row root and digest-addressed. `local_reference_artifact` may not contain `.` or `..` path segments. A silent missing receipt is invalid because the 70B row is the only current falsifier whose threshold may depend on hosted reference evidence.

## Command Path Rule

`command` must begin with the canonical `tools/falsifiers/<script>.sh` path for the matching row. Wrapper commands, shell aliases, copied scripts, or commands run from another directory fail replay eligibility unless the handbook row itself is updated first.

## Command Argument Rule

Command arguments, when present, must be plain space-separated flag/path/value tokens. Shell metacharacters, pipelines, command substitution, environment-prefix execution, or newline-separated command strings fail replay eligibility.

## Command Normalization Rule

The command string is normalized only by removing the handbook's leading `NOT IMPLEMENTED: ` marker before comparison. It must use one ASCII space between tokens, no leading or trailing whitespace, no `./` or absolute-path prefix, no quoted compound argument, no glob, no implicit current-directory dependency, and no reordered flag bundle that changes fixture identity. `command_digest` is `sha256:` over the UTF-8 normalized command string with no trailing newline. If a future falsifier needs environment variables, cwd changes, or multi-step setup, those belong in the script and artifact metadata, not in the witness `command` string.

## Command Path Map

| Falsifier | Canonical command path |
|---|---|
| `F-Eidos-ClosedCitation` | `tools/falsifiers/f_eidos_closed_citation.sh` |
| `F-VaultRecall-50` | `tools/falsifiers/f_vault_recall_50.sh` |
| `F-PageGather-Baseline` | `tools/falsifiers/f_page_gather_baseline.sh` |
| `F-PageGather-Scatter` | `tools/falsifiers/f_page_gather_scatter.sh` |
| `F-UAS-CopyCount` | `tools/falsifiers/f_uas_copy_count.sh` |
| `F-ACS-AnchorLookup` | `tools/falsifiers/f_acs_anchor_lookup.sh` |
| `F-InterruptScore-CPU` | `tools/falsifiers/f_interrupt_score_cpu.sh` |
| `F-PacketRouter1bit` | `tools/falsifiers/f_packet_router_1bit.sh` |
| `F-ControllerKernelPack` | `tools/falsifiers/f_controller_kernel_pack.sh` |
| `F-SemiseparableBlockScan` | `tools/falsifiers/f_semiseparable_block_scan.sh` |
| `F-LocalRecallIsland` | `tools/falsifiers/f_local_recall_island.sh` |
| `F-KV-Direct-Gate` | `tools/falsifiers/f_kv_direct_gate.sh` |
| `F-WBO-DriftLedger` | `tools/falsifiers/f_wbo_drift_ledger.sh` |
| `F-ULP-Oracle` | `tools/falsifiers/f_ulp_oracle.sh` |
| `F-70B-Local-Cocktail-Lite` | `tools/falsifiers/f_70b_local_cocktail_lite.sh` |

## Timestamp Rule

`timestamp_utc` must record the artifact creation time in RFC 3339 UTC form ending in `Z`, with bounded month, day, hour, minute, and second fields. Local timezone strings, date-only values, offset timestamps, leap-second spellings, or timestamps captured before the falsifier command completed fail replay eligibility because they cannot anchor the witness to the produced payload.

## Fixture Identity Rule

`fixture_id` must be a replay-safe lowercase slug matching `^[a-z0-9][a-z0-9._-]*$` and stable enough to recover the input corpus, generated-case grid, seed, configuration, and dataset version used by the run. A fixture label that cannot distinguish regenerated inputs from the original witness input set fails replay eligibility.

## Fixture Lineage Rule

Generated, seeded, or dataset-versioned fixtures should include `fixture_lineage`. The lineage object records the fixture manifest path, `fixture_manifest_sha256`, seed, generator command, dataset version, configuration digest, case count, and whether unicode cases are present. A generated fixture without enough lineage to regenerate the exact input set remains replay-ineligible even when its `fixture_id` slug is well-formed.

## Runner Toolchain Identity Rule

`runner_environment.toolchain_identity` records the command-version surface available to the falsifier run: `xcodebuild`, `swift`, `rustc`, and `python`. Each field must be a single-line version token containing at least one digit or the exact sentinel `not_used`; missing, vague, empty, or multi-line toolchain identity fails replay eligibility because command replay cannot distinguish compiler or interpreter drift from model behavior.

## Measurements Rule

`measurements` records observed run output only. Each axis must store the raw measured value, unit, and `evidence_kind` used by the falsifier, not a prose summary, target, or inferred pass label. Aggregate axes may add `samples`, `statistic`, or raw-artifact references, but the reported `value` must remain replay-computable from the committed artifact payload.

## Measurement Evidence Kind Rule

`evidence_kind` must be one of `direct_measurement`, `aggregate_statistic`, `digest`, `classification`, or `reference_link`. Aggregate statistics must use `aggregate_statistic`, digest measurements must use `digest`, boolean taxonomy results may use `classification`, and sidecar- or upstream-derived values may use `reference_link`. The evidence kind describes the measurement source shape; it does not override threshold comparison or pass/fail replay.

## Classified Unsupported Value Rule

`value: null` is allowed only when `statistic` is `classified` and an `unsupported_case` anomaly names the affected axis. Null cannot stand in for missing numeric, boolean, or digest output.

## Aggregate Statistic Rule

When `statistic` is `min`, `max`, `mean`, `median`, `p50`, `p95`, `p99`, or `count`, the measurement must provide nonempty `samples` or `raw_artifact`, set `evidence_kind` to `aggregate_statistic`, and declare `sample_count`. A `samples` array must use one scalar type across all entries, and `sample_count` must equal the array length when samples are embedded. Aggregate values without replay material are summaries, not witness measurements.

## Digest Measurement Rule

When `statistic` is `digest`, `value` must be a lowercase `sha256:` digest and `unit` must be `sha256`. Bare hashes, uppercase hex, alternate algorithms, and prose digests fail validation.

## Acceptance Thresholds Rule

`acceptance_thresholds` records the falsifiable bar copied from the handbook row or fragment. Each axis must name the operator, value, unit, and `threshold_source` used to judge the matching measurement. `threshold_source` is `handbook_row`, `fragment_contract`, `upstream_artifact`, or `provider_receipt`. Thresholds that depend on another artifact, such as PageGather scatter depending on the baseline calibration, must identify the upstream artifact path or axis; provider-derived thresholds must name `provider_receipt_ref` matching a retained receipt `request_id_hash`; recomputing a private threshold from prose fails validation.

## Falsifier Dependency Graph

Downstream falsifiers must name their upstream artifacts when a pass claim depends on a prior gate:

| Downstream falsifier | Required upstream evidence | Linkage rule |
|---|---|---|
| `F-PageGather-Scatter` | `F-PageGather-Baseline` | Scatter throughput thresholds must include `upstream_artifact` and `upstream_axis` pointing at the baseline calibration artifact. |
| `F-LocalRecallIsland` | `F-SemiseparableBlockScan` when citing state-kernel acceleration | Any recall-island artifact that cites semiseparable acceleration must reference the block-scan correctness artifact. |
| `F-KV-Direct-Gate` | `F-WBO-DriftLedger` when claiming bounded approximation debt | Any residual-patched or compressed KV pass claim must reference a WBO drift artifact for the same prompt class. |
| `F-70B-Local-Cocktail-Lite` | Any component falsifier it uses as a cocktail dependency | PageGather, KV-Direct, LocalRecallIsland, WBO, or provider-reference components must be linked by artifact path or provider receipt. |

## Artifact Reference Rule

`raw_artifact` and `upstream_artifact` references must point under `artifacts/falsifiers/` without `.` or `..` path segments. A schema witness cannot use ad hoc temp files, user-local absolute paths, cloud URLs, path traversal, or prose-only upstream references as replay material.

## Sidecar Digest Reference Rule

Every replay sidecar path must carry a sibling digest: `raw_artifact` pairs with `raw_artifact_sha256`, threshold `upstream_artifact` pairs with `upstream_artifact_sha256`, and provider `artifact_ref` pairs with `artifact_ref_sha256`. Each sidecar digest uses lowercase `sha256:` form over the referenced file bytes; LF normalization is allowed only when the referenced file is declared as text evidence. A path without a digest is not retained evidence, and a digest without a path is not replay material.

## Upstream Threshold Pair Rule

If a threshold includes `upstream_artifact`, it must also include `upstream_axis`; if it includes `upstream_axis`, it must also include `upstream_artifact`. A half-linked upstream threshold is not replayable.

## Expected Artifact Root Map

| Falsifier | Expected artifact root |
|---|---|
| `F-Eidos-ClosedCitation` | `artifacts/falsifiers/f_eidos_closed_citation/` |
| `F-VaultRecall-50` | `artifacts/falsifiers/f_vault_recall_50/` |
| `F-PageGather-Baseline` | `artifacts/falsifiers/page_gather/baseline/` |
| `F-PageGather-Scatter` | `artifacts/falsifiers/page_gather/scatter/` |
| `F-UAS-CopyCount` | `artifacts/falsifiers/uas_copy_count/` |
| `F-ACS-AnchorLookup` | `artifacts/falsifiers/acs_anchor_lookup/` |
| `F-InterruptScore-CPU` | `artifacts/falsifiers/interrupt_score_cpu/` |
| `F-PacketRouter1bit` | `artifacts/falsifiers/packet_router_1bit/` |
| `F-ControllerKernelPack` | `artifacts/falsifiers/controller_kernel_pack/` |
| `F-SemiseparableBlockScan` | `artifacts/falsifiers/semiseparable_block_scan/` |
| `F-LocalRecallIsland` | `artifacts/falsifiers/local_recall_island/` |
| `F-KV-Direct-Gate` | `artifacts/falsifiers/kv_direct_gate/` |
| `F-WBO-DriftLedger` | `artifacts/falsifiers/wbo_drift_ledger/` |
| `F-ULP-Oracle` | `artifacts/falsifiers/ulp_oracle/` |
| `F-70B-Local-Cocktail-Lite` | `artifacts/falsifiers/70b_local_cocktail_lite/` |

The artifact file path is validator input, not a JSON payload field. Adding `artifact_path` inside the witness JSON fails `additionalProperties: false`; placing the file outside its mapped root fails replay eligibility. Canonical witness filenames are `result.json` for object artifacts and `result.jsonl` only for row-stream artifacts such as `F-WBO-DriftLedger`; every other falsifier must use `result.json`. Sidecars may be referenced as raw evidence but cannot replace the canonical witness file.

## Witness Retention Policy

Canonical witness files live only under the expected artifact root for their falsifier. Primary-pass and fallback-pass witnesses must be retained indefinitely while a handbook row cites them; failed artifacts may be retained as failure reports when they are linked from a row, anomaly ledger, or negative example, and otherwise may be garbage-collected after a newer witness or explicit fail report supersedes them. Raw sidecars needed to replay a measurement, threshold, digest, dependency, provider receipt, or anomaly must remain under the same artifact root and cannot be replaced by a prose note. Garbage collection is allowed only when the artifact is not the latest cited primary/fallback witness, no retained artifact references it through `raw_artifact`, `upstream_artifact`, `artifact_ref`, or `provider_receipts`, and the replacement witness records the old artifact digest or fail-report path.

## JSONL Witness Rule

When the canonical witness file is `result.jsonl`, every line must be a JSON object with `schema_version`, `falsifier_id`, `row_index`, `prompt_id`, `token_index`, `axis`, `measurement`, `acceptance_threshold`, `pass`, and `anomalies`. The file must be UTF-8 without a BOM, use LF line endings rather than CRLF, end with a final LF so append-only replay never drops the last row, and contain no blank lines. JSONL rows inherit the canonical artifact path and file-level `result_digest` from validator input; they may not repeat `artifact_path`, `path`, `result_digest`, or sidecar location fields. The file-level `result_digest` for a JSONL witness covers the full LF-normalized byte stream, not a concatenation of per-row digests. JSONL rows may not add undeclared top-level keys; row `measurement`, `acceptance_threshold`, and `anomalies` entries inherit the same closed-object rule as object artifacts. Row `measurement` must be the canonical measurement object with `value` and `unit`, never a bare scalar or array. Row `acceptance_threshold` must be the canonical threshold object with `operator`, `value`, and `unit`, never a prose clause or scalar target. Each row `schema_version` must equal the current schema version, and each row `falsifier_id` must equal the artifact manifest falsifier ID. `row_index` values must be zero-based and contiguous so replay can identify missing or reordered ledger rows. `prompt_id` must match `^[a-z0-9][a-z0-9._-]*$`, and `token_index` must be a non-negative integer, binding each drift row back to the producing prompt fixture and token position without aliases. Within a `prompt_id`, `token_index` values must be non-decreasing as `row_index` increases. The tuple `(prompt_id, token_index, axis)` must be unique across the file. `axis` must match one of the falsifier's declared floor axes or an explicitly declared added axis from the same artifact manifest. Row `measurement.unit` must equal row `acceptance_threshold.unit`. Any row-level anomaly with an `axis` must use that same row `axis`; row-level anomalies apply only to the row they appear on and cannot excuse file-level framing, ordering, or uniqueness violations. Row `pass` must equal replaying `measurement` against `acceptance_threshold`.

## JSONL Replay Manifest Rule

Every `result.jsonl` witness must be accompanied by `manifest.json` in the same artifact root. The manifest is the file-level envelope for fields that do not belong on every row: `artifact_kind`, `hardware_pin`, `command`, `commit_sha`, `fixture_id`, `timestamp_utc`, `result_digest`, `pass_per_axis`, `overall_pass`, `fallback_tier`, `anomalies`, `notes`, and any dependency, provider, or fixture-lineage material. The manifest must name `jsonl_file=result.jsonl` and `jsonl_file_sha256` equal to `result_digest`; the row stream remains the canonical measured payload, and the manifest cannot replace or summarize individual rows.

## Threshold Operator Rule

Numeric comparison operators require numeric threshold values: `<=` and `>=` use one number, while `between` uses exactly two numbers. The `present` operator must use boolean `true` as its value. The `contains` operator must use a string or array value. Other non-numeric operators may carry string, boolean, or array values only when the axis semantics need them.

## Measurement Threshold Compatibility Rule

For numeric threshold operators, the matching measurement `value` must also be numeric. Categorical strings may be used for taxonomy or digest axes, but they cannot satisfy numeric comparisons by string coercion.

## Unit Consistency Rule

For every axis, `measurements[axis].unit` must equal `acceptance_thresholds[axis].unit`. Digest axes therefore require `sha256` on both sides. Unit aliases, implicit conversions, or mixed forms such as `GB/s` versus `MB/s` fail validation unless the schema version explicitly adds a conversion table.

## Unit Token Rule

Units must be compact ASCII tokens matching `^[A-Za-z0-9%./_-]+$`. Freeform units such as `gigabytes per second`, unit strings with spaces, or unicode symbols fail validation because replay code must compare units byte-for-byte.

## Pass Per Axis Rule

`pass_per_axis` records the boolean result of applying each acceptance threshold to its matching measurement. A failed axis must remain present with `false`; omitting a failed axis or renaming it so `overall_pass` can become true invalidates the artifact. Non-numeric axes, such as fake-citation rejection or stress-case classification, still require explicit boolean results tied to named thresholds.

## Overall Pass Rule

`overall_pass` is the conjunction of all required `pass_per_axis` values for the artifact's selected tier. It may be `true` with `fallback_tier: Fallback` only as fallback-route evidence; primary row promotion still requires `overall_pass: true` and `fallback_tier: Primary`. If any required axis is `false`, missing, or replay-ineligible, `overall_pass` must be `false`.

## Pass-Affecting Anomaly Rule

If any anomaly has `affects_pass: true`, the artifact cannot be a primary pass. It may still record fallback evidence only when `fallback_tier` is `Fallback` and the anomaly ledger names the fallback route.

## Anomalies Rule

`anomalies` records structured facts about unexpected rig, input, output, timing, memory, thermal, power, disk, permission, fallback, or unsupported-case behavior. Each anomaly must say whether it affects pass eligibility. An empty array means no anomaly occurred; it does not mean anomalies were uninspected.

Every anomaly must include `severity`, and it must be one of `info`, `warning`, or `blocking`. `blocking` anomalies must set `affects_pass: true` and include `evidence_ref` plus `evidence_ref_sha256`; otherwise the artifact hides a disqualifying condition behind a harmless flag or unretained prose. Freeform severity labels fail validation because merge tooling must sort anomaly urgency without synonym tables.

## Timing Thermal Rule

If `runner_environment.thermal_state_start` or `runner_environment.thermal_state_end` is `serious` or `critical`, every timing-shaped axis must either fail or carry a blocking `thermal` anomaly with `affects_pass: true`. Timing-shaped axes include units `s`, `ms`, `us`, `tok/s`, and axis names containing `latency`, `wall_clock`, `ttft`, `throughput`, or `decode`. A timing pass recorded under serious or critical thermal pressure is replay-ineligible because the M2 Pro floor was not stable.

## Timing Power Rule

If `runner_environment.power_source` is `battery` or `unknown`, every timing-shaped axis must either fail or carry a blocking `power` anomaly with `affects_pass: true`. Timing pass thresholds are calibrated for Jojo's M2 Pro floor under AC power; battery or unknown power state is valid failure evidence but not primary timing-pass evidence.

## Anomaly Axis Reference Rule

When an anomaly has an `axis`, that axis must appear in the artifact's `measurements`, `acceptance_thresholds`, and `pass_per_axis` maps. An anomaly cannot introduce a side-channel axis that bypasses the per-axis pass ledger.

## Anomaly Kind Requirements

| Kind | Schema-required fields beyond base anomaly | Required detail in `description` |
|---|---|---|
| `rig` | none | Actual machine identifier and the expected M2 Pro pin it diverged from. |
| `input` | none | Fixture case, seed, or source input that diverged from the declared `fixture_id`. |
| `output` | `axis` | Output artifact path, digest, or missing-output condition affected by the anomaly. |
| `timing` | `axis` | Affected axis plus observed wall-clock or latency value. |
| `memory` | `axis` | Affected axis plus observed RAM, RSS, UMA, or allocation value. |
| `thermal` | `axis` | Thermal state or throttling signal and whether timing axes are invalidated. |
| `power` | `axis` | Power source or low-power state and whether timing axes are invalidated. |
| `disk` | none | Disk-full, write-failure, or filesystem path detail. |
| `permission` | none | Denied entitlement, sandbox, file, or device permission. |
| `fallback` | `fallback_tier` | Referenced fallback route in `description` plus the anomaly object's `fallback_tier`. |
| `unsupported_case` | `axis` | Fixture case that was classified instead of silently counted. |
| `other` | none | Specific reason the anomaly does not fit the enumerated kinds; generic `other` is invalid. |

The base anomaly fields are `kind`, `description`, `affects_pass`, and `severity`.

## Notes Rule

`notes` is for replay caveats, rig observations, and summaries that do not fit a numeric or boolean axis. Use `none` only when the run has no caveat. Any non-`none` note must include semicolon-delimited `anomaly_inspection=complete`, `reviewer=<id>`, and `reviewed_at_utc=<RFC3339Z>` tokens so reviewers can distinguish observed caveats from an uninspected, anonymous, or untimestamped anomaly surface. Reserved reviewer identities `anonymous`, `unknown`, `tbd`, and `none` are invalid. Machine-readable `key=value` tokens in notes must use schema-owned keys; prose caveats must not invent new keys. Notes are capped at 1536 characters so a full post-witness migration token set can fit without prose. Notes cannot add hidden thresholds, override failed axes, replace raw measurements, replace the structured anomaly ledger, embed fenced JSON, begin with an object payload, or turn fallback evidence into a primary pass claim.

## Axis Consistency Rule

The keys under `measurements`, `acceptance_thresholds`, and `pass_per_axis` must describe the same axis set. Missing or extra axes fail artifact validation because they make the per-axis result non-replayable.

## Axis Name Grammar Rule

Every axis key must match `^[a-z][a-z0-9_]*$`. CamelCase, hyphenated, dotted, spaced, or prose-shaped axis labels fail validation even when they are obvious to a human reviewer, because replay tooling must join the axis across measurements, thresholds, pass booleans, anomaly references, and the cross-gate floor table without aliases.

## Falsifier Axis Enum Rule

For each `falsifier_id`, the JSON Schema fragment must require that row's minimum axis keys under `measurements`, `acceptance_thresholds`, and `pass_per_axis`. Added axes remain allowed only when the producing artifact declares them and they still match the axis grammar; missing floor axes fail before replay thresholds are evaluated.

## Validation Boundary

The JSON Schema fragment is authoritative for top-level field presence, field types, enum values, M2 Pro hardware constants, and required per-falsifier axis floors. Replay validation still compares full key sets across fields and checks any declared added axis beyond the schema floor.

## JSON Fragment Authority Rule

The first fenced `json` block in this document is the only machine-readable schema fragment. Additional prose tables and migration notes may tighten validator behavior, but they must not introduce a second competing JSON Schema block.

## Replay-Ineligibility Checklist

An artifact is replay-ineligible if any predicate below is true:

1. `falsifier_id` does not exactly match a handbook row and fragment frontmatter.
2. `schema_version` differs from the current schema and lacks an explicit migration note.
3. `hardware_pin` differs from Jojo's M2 Pro 16 GB UMA floor.
4. `command` differs from the row command after removing `NOT IMPLEMENTED:`.
5. `command_digest` is missing, is not lowercase `sha256:`, or does not hash the normalized command string.
6. `commit_sha` is missing, short, non-hex, or not the producing repo state.
7. `fixture_id` cannot recover the exact input set, seed, or dataset/config version, or `fixture_lineage.fixture_manifest` lacks a matching `fixture_manifest_sha256`.
8. `timestamp_utc` is not UTC `Z` time or predates command completion.
9. Measurement, threshold, and pass-axis key sets differ.
10. Any required cross-gate axis floor is absent.
11. `overall_pass` is true while any required axis is false, missing, or replay-ineligible.
12. `fallback_tier` claims `Primary` for a fallback route artifact.
13. A pass-affecting anomaly is omitted, only described in freeform notes, or has `severity: blocking` without retained `evidence_ref` plus `evidence_ref_sha256`.
14. A replay sidecar path is present without its sibling `sha256:` field, or the digest does not match the referenced bytes.
15. A `result.jsonl` witness lacks `manifest.json`, or the manifest fails `$defs.jsonl_manifest`.
16. `manifest.json` names a `jsonl_file_sha256` that differs from `result_digest`.
17. `runner_environment` is missing, has extra keys, differs from the closed `repo_root`/`zsh`/`script_owned`/`C`/`UTC` execution pin, or omits macOS build, toolchain identity, thermal state, or power-source capture.
18. A measurement omits `evidence_kind`, uses an unknown kind, or names a kind inconsistent with `statistic`, digest fields, classification values, or replay sidecar references.
19. An acceptance threshold omits `threshold_source`, names a source outside the enum, marks an upstream-derived threshold without `upstream_artifact`, `upstream_axis`, and `upstream_artifact_sha256`, or marks a provider-derived threshold without `provider_receipt_ref`.
20. An aggregate measurement omits `sample_count`, or `sample_count` disagrees with embedded samples or the raw-artifact sample manifest.

## Negative Examples Catalog

Invalid witness shapes, including schema-required axis-floor, anomaly severity, migration-note, hardware-pin-shape, provider-receipt, dependency-link, and retention failures, are cataloged in [Artifact Negative Examples](ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md). Validator work must keep these examples failing unless a future schema migration explicitly rewrites the violated rule.

## Validator Harness Shape

The future validator contract is sketched in [Artifact Validator Shape](ARTIFACT_VALIDATOR_SHAPE_2026_05_18.md). That document is non-executable until a merge-phase or validator-implementation terminal owns the harness.

## Fallback Tier Semantics

`Primary` means the exact row command and threshold passed on Jojo's M2 Pro hardware floor. `Fallback` means the documented fallback route produced an acceptable artifact, but the primary row remains not fully passed unless its row threshold explicitly accepts that route. `Fail` means neither primary nor fallback evidence satisfies the contract.

## Artifact Kind Rule

`artifact_kind` classifies why the artifact exists. `primary_witness` must pair with `overall_pass: true` and `fallback_tier: Primary`; `fallback_witness` must pair with `overall_pass: true` and `fallback_tier: Fallback`; `failure_report` must pair with `overall_pass: false` and `fallback_tier: Fail`. A failure report may be retained as evidence, but it cannot promote a row.

## Cross-Gate Axis Floors

These are the minimum axis keys each F-* artifact must cover in `measurements`, `acceptance_thresholds`, and `pass_per_axis`. Artifacts may add more axes when the row needs them, but added axes must obey the same consistency rule.

| Falsifier | Minimum axis keys |
|---|---|
| `F-Eidos-ClosedCitation` | `citation_membership`, `fake_citation_rejection`, `empty_vault_deferral`, `source_trace_visible` |
| `F-VaultRecall-50` | `target_recall`, `distractor_suppression`, `candidate_count`, `trace_components`, `weak_evidence_behavior` |
| `F-PageGather-Baseline` | `median_bw_256mb`, `median_bw_512mb`, `median_bw_1gb`, `window_seconds` |
| `F-PageGather-Scatter` | `scatter_bw_256mb`, `scatter_bw_512mb`, `baseline_ratio`, `correctness_digest`, `window_seconds` |
| `F-UAS-CopyCount` | `tensor_copy_count`, `data_copy_bytes`, `metadata_copy_ledger`, `stack_label_coverage` |
| `F-ACS-AnchorLookup` | `round_trip_field_digest`, `invalid_theorem_rejection`, `projection_integrity` |
| `F-InterruptScore-CPU` | `equation_match`, `clamp_bounds`, `bucket_boundaries`, `p99_latency_us` |
| `F-PacketRouter1bit` | `p99_latency_us`, `reconstruction_digest`, `mask_class_breakdown`, `lane_balance_report` |
| `F-ControllerKernelPack` | `per_kernel_equivalence`, `fp32_max_diff`, `threadgroup_budget`, `unsupported_case_ledger` |
| `F-SemiseparableBlockScan` | `core_max_abs_diff`, `final_state_diff`, `chunk_size`, `ngroups`, `stretch_labeling` |
| `F-LocalRecallIsland` | `peak_memory_gb`, `passkey_recall`, `niah_single_1`, `depth_failure_labels` |
| `F-KV-Direct-Gate` | `average_d_kl_nats`, `peak_ram_gb`, `decode_tok_s`, `suite_wall_clock_min`, `spill_labeling` |
| `F-WBO-DriftLedger` | `finite_nonnegative_terms`, `envelope_bound`, `post_softmax_drift`, `missing_term_fail_closed` |
| `F-ULP-Oracle` | `max_ulp`, `comparable_points_over_2ulp`, `stress_case_classification`, `wall_clock_seconds` |
| `F-70B-Local-Cocktail-Lite` | `d_kl_nats`, `decode_tok_s`, `ttft_seconds`, `resident_memory_gb`, `bottleneck_identified` |

## T12 F-ULP Witness Correspondence

T12's F-ULP witness shape is the first specific instance of this general artifact schema. On this branch, the Rust substrate report is `UlpOracleReport` in `agent_core/src/research/eml/ulp_oracle.rs`; a future T12 `FulpWitness` artifact must map `max_ulp_error` to `measurements.max_ulp`, `samples_within_bar` plus total comparable samples to `measurements.comparable_points_over_2ulp`, stress taxonomy output to `measurements.stress_case_classification`, and run timing to `measurements.wall_clock_seconds`.

## JSON Schema Fragment

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.json",
  "title": "T23B Falsifier Artifact",
  "type": "object",
  "required": ["falsifier_id", "schema_version", "artifact_kind", "hardware_pin", "command", "command_digest", "runner_environment", "commit_sha", "fixture_id", "timestamp_utc", "result_digest", "measurements", "acceptance_thresholds", "pass_per_axis", "overall_pass", "fallback_tier", "anomalies", "notes"],
  "$defs": {
    "hardware_pin": {
      "type": "object",
      "required": ["machine", "cpu", "gpu", "unified_memory_gb", "memory_bandwidth_gb_s"],
      "properties": {
        "machine": {
          "type": "string",
          "const": "M2 Pro 14-inch 2023"
        },
        "cpu": {
          "type": "string",
          "const": "12-core CPU"
        },
        "gpu": {
          "type": "string",
          "const": "19-core GPU"
        },
        "unified_memory_gb": {
          "type": "integer",
          "const": 16
        },
        "memory_bandwidth_gb_s": {
          "type": "integer",
          "const": 200
        }
      },
      "additionalProperties": false
    },
    "toolchain_identity": {
      "type": "object",
      "required": ["xcodebuild", "swift", "rustc", "python"],
      "properties": {
        "xcodebuild": {
          "type": "string",
          "minLength": 1,
          "pattern": "^(not_used|(?=.*[0-9])[^\\r\\n]+)$"
        },
        "swift": {
          "type": "string",
          "minLength": 1,
          "pattern": "^(not_used|(?=.*[0-9])[^\\r\\n]+)$"
        },
        "rustc": {
          "type": "string",
          "minLength": 1,
          "pattern": "^(not_used|(?=.*[0-9])[^\\r\\n]+)$"
        },
        "python": {
          "type": "string",
          "minLength": 1,
          "pattern": "^(not_used|(?=.*[0-9])[^\\r\\n]+)$"
        }
      },
      "additionalProperties": false
    },
    "runner_environment": {
      "type": "object",
      "required": ["cwd", "shell", "env_policy", "locale", "timezone", "os_build", "toolchain_identity", "thermal_state_start", "thermal_state_end", "power_source"],
      "properties": {
        "cwd": {
          "const": "repo_root"
        },
        "shell": {
          "const": "zsh"
        },
        "env_policy": {
          "const": "script_owned"
        },
        "locale": {
          "const": "C"
        },
        "timezone": {
          "const": "UTC"
        },
        "os_build": {
          "type": "string",
          "minLength": 1,
          "pattern": "^[A-Za-z0-9._() -]+$"
        },
        "toolchain_identity": {
          "$ref": "#/$defs/toolchain_identity"
        },
        "thermal_state_start": {
          "type": "string",
          "enum": ["nominal", "fair", "serious", "critical", "unknown"]
        },
        "thermal_state_end": {
          "type": "string",
          "enum": ["nominal", "fair", "serious", "critical", "unknown"]
        },
        "power_source": {
          "type": "string",
          "enum": ["ac_power", "battery", "unknown"]
        }
      },
      "additionalProperties": false
    },
    "provider_receipt": {
      "type": "object",
      "required": ["provider", "model_or_service", "purpose", "request_id_hash", "timestamp_utc", "data_sent_class", "retention_claim", "redaction_digest", "replay_allowed", "artifact_ref", "artifact_ref_sha256"],
      "allOf": [
        {
          "not": {
            "properties": {
              "data_sent_class": { "const": "none" }
            },
            "required": ["data_sent_class"]
          }
        }
      ],
      "properties": {
        "provider": {
          "type": "string",
          "minLength": 1,
          "pattern": "^[A-Za-z0-9._-]+$"
        },
        "model_or_service": {
          "type": "string",
          "minLength": 1,
          "pattern": "^[A-Za-z0-9._:/+-]+$"
        },
        "purpose": {
          "type": "string",
          "enum": ["reference_logits", "reference_output", "oracle_compare", "replay_support"]
        },
        "request_id_hash": {
          "type": "string",
          "pattern": "^sha256:[a-f0-9]{64}$"
        },
        "timestamp_utc": {
          "type": "string",
          "format": "date-time",
          "pattern": "^\\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\\d|3[01])T(?:[01]\\d|2[0-3]):[0-5]\\d:[0-5]\\d(?:\\.\\d+)?Z$"
        },
        "data_sent_class": {
          "type": "string",
          "enum": ["none", "prompt_hash_only", "fixture_subset", "metrics_only"]
        },
        "retention_claim": {
          "type": "string",
          "enum": ["none", "zero_retention", "provider_default", "unknown"]
        },
        "redaction_digest": {
          "type": "string",
          "pattern": "^sha256:[a-f0-9]{64}$"
        },
        "replay_allowed": {
          "const": true
        },
        "artifact_ref": {
          "type": "string",
          "minLength": 1,
          "pattern": "^artifacts/falsifiers/(?!\\.\\.?/)(?!.*?/\\.\\.?(?:/|$))[A-Za-z0-9._/-]+$"
        },
        "artifact_ref_sha256": {
          "type": "string",
          "pattern": "^sha256:[a-f0-9]{64}$"
        }
      },
      "additionalProperties": false
    },
    "jsonl_manifest": {
      "type": "object",
      "required": ["schema_version", "falsifier_id", "artifact_kind", "hardware_pin", "command", "command_digest", "runner_environment", "commit_sha", "fixture_id", "timestamp_utc", "result_digest", "jsonl_file", "jsonl_file_sha256", "pass_per_axis", "overall_pass", "fallback_tier", "anomalies", "notes"],
      "properties": {
        "schema_version": {
          "const": "2026-05-18.2"
        },
        "falsifier_id": {
          "$ref": "#/properties/falsifier_id"
        },
        "artifact_kind": {
          "$ref": "#/properties/artifact_kind"
        },
        "hardware_pin": {
          "$ref": "#/$defs/hardware_pin"
        },
        "command": {
          "$ref": "#/properties/command"
        },
        "command_digest": {
          "$ref": "#/properties/command_digest"
        },
        "runner_environment": {
          "$ref": "#/$defs/runner_environment"
        },
        "commit_sha": {
          "$ref": "#/properties/commit_sha"
        },
        "fixture_id": {
          "$ref": "#/properties/fixture_id"
        },
        "fixture_lineage": {
          "$ref": "#/$defs/fixture_lineage"
        },
        "timestamp_utc": {
          "$ref": "#/properties/timestamp_utc"
        },
        "result_digest": {
          "$ref": "#/properties/result_digest"
        },
        "jsonl_file": {
          "const": "result.jsonl"
        },
        "jsonl_file_sha256": {
          "$ref": "#/properties/result_digest"
        },
        "pass_per_axis": {
          "$ref": "#/properties/pass_per_axis"
        },
        "overall_pass": {
          "$ref": "#/properties/overall_pass"
        },
        "fallback_tier": {
          "$ref": "#/properties/fallback_tier"
        },
        "anomalies": {
          "$ref": "#/properties/anomalies"
        },
        "notes": {
          "$ref": "#/properties/notes"
        },
        "provider_receipts": {
          "$ref": "#/properties/provider_receipts"
        }
      },
      "additionalProperties": false
    },
    "fixture_lineage": {
      "type": "object",
      "required": ["fixture_manifest", "fixture_manifest_sha256", "case_count"],
      "properties": {
        "fixture_manifest": {
          "type": "string",
          "minLength": 1,
          "pattern": "^(artifacts/falsifiers|docs/falsifiers)/(?!\\.\\.?/)(?!.*?/\\.\\.?(?:/|$))[A-Za-z0-9._/-]+$"
        },
        "fixture_manifest_sha256": {
          "type": "string",
          "pattern": "^sha256:[a-f0-9]{64}$"
        },
        "seed": {
          "type": "string",
          "minLength": 1,
          "pattern": "^[A-Za-z0-9._-]+$"
        },
        "generator_command": {
          "type": "string",
          "minLength": 1,
          "pattern": "^[A-Za-z0-9._=:/,-]+(?: [A-Za-z0-9._=:/,-]+)*$"
        },
        "dataset_version": {
          "type": "string",
          "minLength": 1,
          "pattern": "^[A-Za-z0-9._:/+-]+$"
        },
        "config_digest": {
          "type": "string",
          "pattern": "^sha256:[a-f0-9]{64}$"
        },
        "case_count": {
          "type": "integer",
          "minimum": 0
        },
        "unicode_cases_present": {
          "type": "boolean"
        }
      },
      "additionalProperties": false
    }
  },
  "properties": {
    "falsifier_id": {
      "type": "string",
      "pattern": "^F-[A-Za-z0-9][A-Za-z0-9-]*$",
      "enum": [
        "F-Eidos-ClosedCitation",
        "F-VaultRecall-50",
        "F-PageGather-Baseline",
        "F-PageGather-Scatter",
        "F-UAS-CopyCount",
        "F-ACS-AnchorLookup",
        "F-InterruptScore-CPU",
        "F-PacketRouter1bit",
        "F-ControllerKernelPack",
        "F-SemiseparableBlockScan",
        "F-LocalRecallIsland",
        "F-KV-Direct-Gate",
        "F-WBO-DriftLedger",
        "F-ULP-Oracle",
        "F-70B-Local-Cocktail-Lite"
      ]
    },
    "schema_version": {
      "type": "string",
      "const": "2026-05-18.2"
    },
    "artifact_kind": {
      "type": "string",
      "enum": ["primary_witness", "fallback_witness", "failure_report"]
    },
    "hardware_pin": {
      "$ref": "#/$defs/hardware_pin"
    },
    "command": {
      "type": "string",
      "minLength": 1,
      "pattern": "^tools/falsifiers/[a-z0-9_]+\\.sh(?: [A-Za-z0-9._=:/,-]+)*$"
    },
    "command_digest": {
      "type": "string",
      "pattern": "^sha256:[a-f0-9]{64}$"
    },
    "runner_environment": {
      "$ref": "#/$defs/runner_environment"
    },
    "commit_sha": {
      "type": "string",
      "pattern": "^[0-9a-f]{40}$"
    },
    "fixture_id": {
      "type": "string",
      "minLength": 1,
      "pattern": "^[a-z0-9][a-z0-9._-]*$"
    },
    "fixture_lineage": {
      "$ref": "#/$defs/fixture_lineage"
    },
    "timestamp_utc": {
      "type": "string",
      "format": "date-time",
      "pattern": "^\\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\\d|3[01])T(?:[01]\\d|2[0-3]):[0-5]\\d:[0-5]\\d(?:\\.\\d+)?Z$"
    },
    "result_digest": {
      "type": "string",
      "pattern": "^sha256:[a-f0-9]{64}$"
    },
    "measurements": {
      "type": "object",
      "minProperties": 1,
      "propertyNames": {
        "pattern": "^[a-z][a-z0-9_]*$"
      },
      "patternProperties": {
        "^[a-z][a-z0-9_]*$": {
          "type": "object",
          "required": ["value", "unit", "evidence_kind"],
          "properties": {
            "value": {
              "type": ["number", "string", "boolean", "null"]
            },
            "unit": {
              "type": "string",
              "minLength": 1,
              "pattern": "^[A-Za-z0-9%./_-]+$"
            },
            "evidence_kind": {
              "type": "string",
              "enum": ["direct_measurement", "aggregate_statistic", "digest", "classification", "reference_link"]
            },
            "samples": {
              "type": "array",
              "minItems": 1,
              "oneOf": [
                { "items": { "type": "number" } },
                { "items": { "type": "string" } },
                { "items": { "type": "boolean" } }
              ]
            },
            "sample_count": {
              "type": "integer",
              "minimum": 1
            },
            "statistic": {
              "type": "string",
              "enum": ["raw", "min", "max", "mean", "median", "p50", "p95", "p99", "count", "digest", "classified"]
            },
            "raw_artifact": {
              "type": "string",
              "minLength": 1,
              "pattern": "^artifacts/falsifiers/(?!\\.\\.?/)(?!.*?/\\.\\.?(?:/|$))[A-Za-z0-9._/-]+$"
            },
            "raw_artifact_sha256": {
              "type": "string",
              "pattern": "^sha256:[a-f0-9]{64}$"
            }
          },
          "allOf": [
            {
              "if": {
                "properties": {
                  "statistic": { "const": "digest" }
                },
                "required": ["statistic"]
              },
              "then": {
                "properties": {
                  "value": {
                    "type": "string",
                    "pattern": "^sha256:[a-f0-9]{64}$"
                  },
                  "unit": { "const": "sha256" },
                  "evidence_kind": { "const": "digest" }
                }
              }
            },
            {
              "if": {
                "properties": {
                  "statistic": { "enum": ["min", "max", "mean", "median", "p50", "p95", "p99", "count"] }
                },
                "required": ["statistic"]
              },
              "then": {
                "required": ["sample_count"],
                "properties": {
                  "evidence_kind": { "const": "aggregate_statistic" }
                }
              }
            },
            {
              "if": {
                "required": ["raw_artifact"]
              },
              "then": {
                "required": ["raw_artifact_sha256"]
              }
            },
            {
              "if": {
                "required": ["raw_artifact_sha256"]
              },
              "then": {
                "required": ["raw_artifact"]
              }
            }
          ],
          "additionalProperties": false
        }
      },
      "additionalProperties": false
    },
    "acceptance_thresholds": {
      "type": "object",
      "minProperties": 1,
      "propertyNames": {
        "pattern": "^[a-z][a-z0-9_]*$"
      },
      "patternProperties": {
        "^[a-z][a-z0-9_]*$": {
          "type": "object",
          "required": ["operator", "value", "unit", "threshold_source"],
          "properties": {
            "operator": {
              "type": "string",
              "enum": ["<=", ">=", "==", "!=", "between", "contains", "present"]
            },
            "value": {
              "oneOf": [
                { "type": "number" },
                { "type": "string" },
                { "type": "boolean" },
                {
                  "type": "array",
                  "items": {
                    "type": ["number", "string", "boolean"]
                  }
                }
              ]
            },
            "unit": {
              "type": "string",
              "minLength": 1,
              "pattern": "^[A-Za-z0-9%./_-]+$"
            },
            "threshold_source": {
              "type": "string",
              "enum": ["handbook_row", "fragment_contract", "upstream_artifact", "provider_receipt"]
            },
            "upstream_artifact": {
              "type": "string",
              "minLength": 1,
              "pattern": "^artifacts/falsifiers/(?!\\.\\.?/)(?!.*?/\\.\\.?(?:/|$))[A-Za-z0-9._/-]+$"
            },
            "upstream_artifact_sha256": {
              "type": "string",
              "pattern": "^sha256:[a-f0-9]{64}$"
            },
            "upstream_axis": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_]*$"
            },
            "provider_receipt_ref": {
              "type": "string",
              "pattern": "^sha256:[a-f0-9]{64}$"
            }
          },
          "allOf": [
            {
              "if": {
                "properties": {
                  "operator": { "enum": ["<=", ">="] }
                },
                "required": ["operator"]
              },
              "then": {
                "properties": {
                  "value": { "type": "number" }
                }
              }
            },
            {
              "if": {
                "properties": {
                  "operator": { "const": "between" }
                },
                "required": ["operator"]
              },
              "then": {
                "properties": {
                  "value": {
                    "type": "array",
                    "minItems": 2,
                    "maxItems": 2,
                    "items": { "type": "number" }
                  }
                }
              }
            },
            {
              "if": {
                "properties": {
                  "operator": { "const": "present" }
                },
                "required": ["operator"]
              },
              "then": {
                "properties": {
                  "value": { "const": true }
                }
              }
            },
            {
              "if": {
                "properties": {
                  "operator": { "const": "contains" }
                },
                "required": ["operator"]
              },
              "then": {
                "properties": {
                  "value": {
                    "type": ["string", "array"]
                  }
                }
              }
            },
            {
              "if": {
                "required": ["upstream_artifact"]
              },
              "then": {
                "required": ["upstream_axis"],
                "properties": {
                  "threshold_source": { "const": "upstream_artifact" }
                }
              }
            },
            {
              "if": {
                "required": ["upstream_axis"]
              },
              "then": {
                "required": ["upstream_artifact"]
              }
            },
            {
              "if": {
                "required": ["upstream_artifact"]
              },
              "then": {
                "required": ["upstream_artifact_sha256"]
              }
            },
            {
              "if": {
                "required": ["upstream_artifact_sha256"]
              },
              "then": {
                "required": ["upstream_artifact"]
              }
            },
            {
              "if": {
                "properties": {
                  "threshold_source": { "const": "upstream_artifact" }
                },
                "required": ["threshold_source"]
              },
              "then": {
                "required": ["upstream_artifact", "upstream_axis", "upstream_artifact_sha256"]
              }
            },
            {
              "if": {
                "properties": {
                  "threshold_source": { "const": "provider_receipt" }
                },
                "required": ["threshold_source"]
              },
              "then": {
                "required": ["provider_receipt_ref"]
              }
            },
            {
              "if": {
                "required": ["provider_receipt_ref"]
              },
              "then": {
                "properties": {
                  "threshold_source": { "const": "provider_receipt" }
                }
              }
            }
          ],
          "additionalProperties": false
        }
      },
      "additionalProperties": false
    },
    "pass_per_axis": {
      "type": "object",
      "minProperties": 1,
      "propertyNames": {
        "pattern": "^[a-z][a-z0-9_]*$"
      },
      "patternProperties": {
        "^[a-z][a-z0-9_]*$": {
          "type": "boolean"
        }
      },
      "additionalProperties": false
    },
    "overall_pass": {
      "type": "boolean"
    },
    "fallback_tier": {
      "type": "string",
      "enum": ["Primary", "Fallback", "Fail"]
    },
    "anomalies": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["kind", "description", "affects_pass", "severity"],
        "properties": {
          "kind": {
            "type": "string",
            "enum": ["rig", "input", "output", "timing", "memory", "thermal", "power", "disk", "permission", "fallback", "unsupported_case", "other"]
          },
          "axis": {
            "type": "string",
            "pattern": "^[a-z][a-z0-9_]*$"
          },
          "description": {
            "type": "string",
            "minLength": 1
          },
          "affects_pass": {
            "type": "boolean"
          },
          "severity": {
            "type": "string",
            "enum": ["info", "warning", "blocking"]
          },
          "fallback_tier": {
            "type": "string",
            "enum": ["Fallback", "Fail"]
          },
          "evidence_ref": {
            "type": "string",
            "minLength": 1,
            "pattern": "^(artifacts/falsifiers|docs/falsifiers)/(?!\\.\\.?/)(?!.*?/\\.\\.?(?:/|$))[A-Za-z0-9._/-]+$"
          },
          "evidence_ref_sha256": {
            "type": "string",
            "pattern": "^sha256:[a-f0-9]{64}$"
          }
        },
        "allOf": [
          {
            "if": {
              "properties": {
                "kind": { "const": "fallback" }
              },
              "required": ["kind"]
            },
            "then": {
              "required": ["fallback_tier"]
            }
          },
          {
            "if": {
              "properties": {
                "kind": { "enum": ["output", "timing", "memory", "thermal", "power", "unsupported_case"] }
              },
              "required": ["kind"]
            },
            "then": {
              "required": ["axis"]
            }
          },
          {
            "if": {
              "properties": {
                "severity": { "const": "blocking" }
              },
              "required": ["severity"]
            },
            "then": {
              "required": ["evidence_ref", "evidence_ref_sha256"],
              "properties": {
                "affects_pass": { "const": true }
              }
            }
          }
        ],
        "additionalProperties": false
      }
    },
    "notes": {
      "type": "string",
      "minLength": 1,
      "maxLength": 1536,
      "not": {
        "pattern": "```|^\\s*\\{|local_reference_artifact=[^;]*(?:\\.\\.|/\\./)|reviewer=(?:anonymous|unknown|tbd|none)(?:\\s|;|$)|(?:^|;\\s*)(?!(?:anomaly_inspection|reviewer|reviewed_at_utc|from_schema|to_schema|artifact_path|migration_command|field_mapping|schema_fragment_digest_before|schema_fragment_digest_after|artifact_kind_gap_report|axis_gap_report|anomaly_gap_report|anomaly_evidence_gap_report|measurement_kind_gap_report|threshold_source_gap_report|notes_reviewer_gap_report|notes_reviewer_sentinel_gap_report|notes_review_timestamp_gap_report|notes_token_delimiter_gap_report|notes_length_gap_report|notes_length_old_cap|notes_length_new_cap|notes_length_reason|notes_token_key_gap_report|local_reference_gap_report|local_reference_root_gap_report|local_reference_dot_segment_gap_report|provider_data_sent_class_gap_report|provider_replay_permission_gap_report|provider_pass_retention_gap_report|provider_artifact_root_gap_report|provider_artifact_dot_segment_gap_report|command_digest_gap_report|fixture_lineage_gap_report|aggregate_sample_gap_report|sidecar_digest_gap_report|runner_environment_gap_report|timing_environment_gap_report|local_reference_only|local_reference_artifact|local_reference_artifact_sha256)=)[A-Za-z_][A-Za-z0-9_]*="
      },
      "allOf": [
        {
          "if": {
            "not": { "const": "none" }
          },
          "then": {
            "pattern": "(?=.*(?:^|;\\s*)anomaly_inspection=complete(?:;|$))(?=.*(?:^|;\\s*)reviewer=[A-Za-z0-9._-]+(?:;|$))(?=.*(?:^|;\\s*)reviewed_at_utc=\\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\\d|3[01])T(?:[01]\\d|2[0-3]):[0-5]\\d:[0-5]\\d(?:\\.\\d+)?Z(?:;|$))"
          }
        },
        {
          "if": {
            "pattern": "from_schema="
          },
          "then": {
            "pattern": "(?=.*from_schema=\\d{4}-\\d{2}-\\d{2}\\.\\d+)(?=.*to_schema=\\d{4}-\\d{2}-\\d{2}\\.\\d+)(?=.*artifact_path=artifacts/falsifiers/[A-Za-z0-9._/-]+)(?=.*migration_command=[A-Za-z0-9._/-]+)(?=.*field_mapping=[A-Za-z0-9._,/:+-]+)(?=.*schema_fragment_digest_before=sha256:[a-f0-9]{64})(?=.*schema_fragment_digest_after=sha256:[a-f0-9]{64})(?=.*artifact_kind_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*axis_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*anomaly_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*anomaly_evidence_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*measurement_kind_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*threshold_source_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*notes_reviewer_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*notes_reviewer_sentinel_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*notes_review_timestamp_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*notes_token_delimiter_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*notes_length_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*notes_length_old_cap=\\d+)(?=.*notes_length_new_cap=\\d+)(?=.*notes_length_reason=[A-Za-z0-9._,/:+-]+)(?=.*notes_token_key_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*local_reference_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*local_reference_root_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*local_reference_dot_segment_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*provider_data_sent_class_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*provider_replay_permission_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*provider_pass_retention_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*provider_artifact_root_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*provider_artifact_dot_segment_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*command_digest_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*fixture_lineage_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*aggregate_sample_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*sidecar_digest_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*runner_environment_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*timing_environment_gap_report=[A-Za-z0-9._,/:+-]+)(?=.*reviewer=[A-Za-z0-9._-]+)(?=.*reviewed_at_utc=\\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\\d|3[01])T(?:[01]\\d|2[0-3]):[0-5]\\d:[0-5]\\d(?:\\.\\d+)?Z)"
          }
        },
        {
          "if": {
            "pattern": "(?:^|;\\s*)local_reference_only=true(?:;|$)"
          },
          "then": {
            "pattern": "(?=.*(?:^|;\\s*)local_reference_artifact=artifacts/falsifiers/70b_local_cocktail_lite/[A-Za-z0-9._/-]+(?:;|$))(?=.*(?:^|;\\s*)local_reference_artifact_sha256=sha256:[a-f0-9]{64}(?:;|$))"
          }
        }
      ]
    },
    "provider_receipts": {
      "type": "array",
      "minItems": 1,
      "items": {
        "$ref": "#/$defs/provider_receipt"
      }
    }
  },
  "allOf": [
    {
      "if": {
        "properties": { "artifact_kind": { "const": "primary_witness" } },
        "required": ["artifact_kind"]
      },
      "then": {
        "properties": {
          "overall_pass": { "const": true },
          "fallback_tier": { "const": "Primary" }
        }
      }
    },
    {
      "if": {
        "properties": { "artifact_kind": { "const": "fallback_witness" } },
        "required": ["artifact_kind"]
      },
      "then": {
        "properties": {
          "overall_pass": { "const": true },
          "fallback_tier": { "const": "Fallback" }
        }
      }
    },
    {
      "if": {
        "properties": { "artifact_kind": { "const": "failure_report" } },
        "required": ["artifact_kind"]
      },
      "then": {
        "properties": {
          "overall_pass": { "const": false },
          "fallback_tier": { "const": "Fail" }
        }
      }
    },
    {
      "if": {
        "properties": { "overall_pass": { "const": true } },
        "required": ["overall_pass", "provider_receipts"]
      },
      "then": {
        "properties": {
          "provider_receipts": {
            "items": {
              "properties": {
                "retention_claim": { "const": "zero_retention" }
              },
              "required": ["retention_claim"]
            }
          }
        }
      }
    },
    {
      "if": {
        "properties": { "falsifier_id": { "const": "F-Eidos-ClosedCitation" } },
        "required": ["falsifier_id"]
      },
      "then": {
        "properties": {
          "measurements": { "required": ["citation_membership", "fake_citation_rejection", "empty_vault_deferral", "source_trace_visible"] },
          "acceptance_thresholds": { "required": ["citation_membership", "fake_citation_rejection", "empty_vault_deferral", "source_trace_visible"] },
          "pass_per_axis": { "required": ["citation_membership", "fake_citation_rejection", "empty_vault_deferral", "source_trace_visible"] }
        }
      }
    },
    {
      "if": {
        "properties": { "falsifier_id": { "const": "F-VaultRecall-50" } },
        "required": ["falsifier_id"]
      },
      "then": {
        "properties": {
          "measurements": { "required": ["target_recall", "distractor_suppression", "candidate_count", "trace_components", "weak_evidence_behavior"] },
          "acceptance_thresholds": { "required": ["target_recall", "distractor_suppression", "candidate_count", "trace_components", "weak_evidence_behavior"] },
          "pass_per_axis": { "required": ["target_recall", "distractor_suppression", "candidate_count", "trace_components", "weak_evidence_behavior"] }
        }
      }
    },
    {
      "if": {
        "properties": { "falsifier_id": { "const": "F-PageGather-Baseline" } },
        "required": ["falsifier_id"]
      },
      "then": {
        "properties": {
          "measurements": { "required": ["median_bw_256mb", "median_bw_512mb", "median_bw_1gb", "window_seconds"] },
          "acceptance_thresholds": { "required": ["median_bw_256mb", "median_bw_512mb", "median_bw_1gb", "window_seconds"] },
          "pass_per_axis": { "required": ["median_bw_256mb", "median_bw_512mb", "median_bw_1gb", "window_seconds"] }
        }
      }
    },
    {
      "if": {
        "properties": { "falsifier_id": { "const": "F-PageGather-Scatter" } },
        "required": ["falsifier_id"]
      },
      "then": {
        "properties": {
          "measurements": { "required": ["scatter_bw_256mb", "scatter_bw_512mb", "baseline_ratio", "correctness_digest", "window_seconds"] },
          "acceptance_thresholds": { "required": ["scatter_bw_256mb", "scatter_bw_512mb", "baseline_ratio", "correctness_digest", "window_seconds"] },
          "pass_per_axis": { "required": ["scatter_bw_256mb", "scatter_bw_512mb", "baseline_ratio", "correctness_digest", "window_seconds"] }
        }
      }
    },
    {
      "if": {
        "properties": { "falsifier_id": { "const": "F-UAS-CopyCount" } },
        "required": ["falsifier_id"]
      },
      "then": {
        "properties": {
          "measurements": { "required": ["tensor_copy_count", "data_copy_bytes", "metadata_copy_ledger", "stack_label_coverage"] },
          "acceptance_thresholds": { "required": ["tensor_copy_count", "data_copy_bytes", "metadata_copy_ledger", "stack_label_coverage"] },
          "pass_per_axis": { "required": ["tensor_copy_count", "data_copy_bytes", "metadata_copy_ledger", "stack_label_coverage"] }
        }
      }
    },
    {
      "if": {
        "properties": { "falsifier_id": { "const": "F-ACS-AnchorLookup" } },
        "required": ["falsifier_id"]
      },
      "then": {
        "properties": {
          "measurements": { "required": ["round_trip_field_digest", "invalid_theorem_rejection", "projection_integrity"] },
          "acceptance_thresholds": { "required": ["round_trip_field_digest", "invalid_theorem_rejection", "projection_integrity"] },
          "pass_per_axis": { "required": ["round_trip_field_digest", "invalid_theorem_rejection", "projection_integrity"] }
        }
      }
    },
    {
      "if": {
        "properties": { "falsifier_id": { "const": "F-InterruptScore-CPU" } },
        "required": ["falsifier_id"]
      },
      "then": {
        "properties": {
          "measurements": { "required": ["equation_match", "clamp_bounds", "bucket_boundaries", "p99_latency_us"] },
          "acceptance_thresholds": { "required": ["equation_match", "clamp_bounds", "bucket_boundaries", "p99_latency_us"] },
          "pass_per_axis": { "required": ["equation_match", "clamp_bounds", "bucket_boundaries", "p99_latency_us"] }
        }
      }
    },
    {
      "if": {
        "properties": { "falsifier_id": { "const": "F-PacketRouter1bit" } },
        "required": ["falsifier_id"]
      },
      "then": {
        "properties": {
          "measurements": { "required": ["p99_latency_us", "reconstruction_digest", "mask_class_breakdown", "lane_balance_report"] },
          "acceptance_thresholds": { "required": ["p99_latency_us", "reconstruction_digest", "mask_class_breakdown", "lane_balance_report"] },
          "pass_per_axis": { "required": ["p99_latency_us", "reconstruction_digest", "mask_class_breakdown", "lane_balance_report"] }
        }
      }
    },
    {
      "if": {
        "properties": { "falsifier_id": { "const": "F-ControllerKernelPack" } },
        "required": ["falsifier_id"]
      },
      "then": {
        "properties": {
          "measurements": { "required": ["per_kernel_equivalence", "fp32_max_diff", "threadgroup_budget", "unsupported_case_ledger"] },
          "acceptance_thresholds": { "required": ["per_kernel_equivalence", "fp32_max_diff", "threadgroup_budget", "unsupported_case_ledger"] },
          "pass_per_axis": { "required": ["per_kernel_equivalence", "fp32_max_diff", "threadgroup_budget", "unsupported_case_ledger"] }
        }
      }
    },
    {
      "if": {
        "properties": { "falsifier_id": { "const": "F-SemiseparableBlockScan" } },
        "required": ["falsifier_id"]
      },
      "then": {
        "properties": {
          "measurements": { "required": ["core_max_abs_diff", "final_state_diff", "chunk_size", "ngroups", "stretch_labeling"] },
          "acceptance_thresholds": { "required": ["core_max_abs_diff", "final_state_diff", "chunk_size", "ngroups", "stretch_labeling"] },
          "pass_per_axis": { "required": ["core_max_abs_diff", "final_state_diff", "chunk_size", "ngroups", "stretch_labeling"] }
        }
      }
    },
    {
      "if": {
        "properties": { "falsifier_id": { "const": "F-LocalRecallIsland" } },
        "required": ["falsifier_id"]
      },
      "then": {
        "properties": {
          "measurements": { "required": ["peak_memory_gb", "passkey_recall", "niah_single_1", "depth_failure_labels"] },
          "acceptance_thresholds": { "required": ["peak_memory_gb", "passkey_recall", "niah_single_1", "depth_failure_labels"] },
          "pass_per_axis": { "required": ["peak_memory_gb", "passkey_recall", "niah_single_1", "depth_failure_labels"] }
        }
      }
    },
    {
      "if": {
        "properties": { "falsifier_id": { "const": "F-KV-Direct-Gate" } },
        "required": ["falsifier_id"]
      },
      "then": {
        "properties": {
          "measurements": { "required": ["average_d_kl_nats", "peak_ram_gb", "decode_tok_s", "suite_wall_clock_min", "spill_labeling"] },
          "acceptance_thresholds": { "required": ["average_d_kl_nats", "peak_ram_gb", "decode_tok_s", "suite_wall_clock_min", "spill_labeling"] },
          "pass_per_axis": { "required": ["average_d_kl_nats", "peak_ram_gb", "decode_tok_s", "suite_wall_clock_min", "spill_labeling"] }
        }
      }
    },
    {
      "if": {
        "properties": { "falsifier_id": { "const": "F-WBO-DriftLedger" } },
        "required": ["falsifier_id"]
      },
      "then": {
        "properties": {
          "measurements": { "required": ["finite_nonnegative_terms", "envelope_bound", "post_softmax_drift", "missing_term_fail_closed"] },
          "acceptance_thresholds": { "required": ["finite_nonnegative_terms", "envelope_bound", "post_softmax_drift", "missing_term_fail_closed"] },
          "pass_per_axis": { "required": ["finite_nonnegative_terms", "envelope_bound", "post_softmax_drift", "missing_term_fail_closed"] }
        }
      }
    },
    {
      "if": {
        "properties": { "falsifier_id": { "const": "F-ULP-Oracle" } },
        "required": ["falsifier_id"]
      },
      "then": {
        "properties": {
          "measurements": { "required": ["max_ulp", "comparable_points_over_2ulp", "stress_case_classification", "wall_clock_seconds"] },
          "acceptance_thresholds": { "required": ["max_ulp", "comparable_points_over_2ulp", "stress_case_classification", "wall_clock_seconds"] },
          "pass_per_axis": { "required": ["max_ulp", "comparable_points_over_2ulp", "stress_case_classification", "wall_clock_seconds"] }
        }
      }
    },
    {
      "if": {
        "properties": { "falsifier_id": { "const": "F-70B-Local-Cocktail-Lite" } },
        "required": ["falsifier_id"]
      },
      "then": {
        "properties": {
          "measurements": { "required": ["d_kl_nats", "decode_tok_s", "ttft_seconds", "resident_memory_gb", "bottleneck_identified"] },
          "acceptance_thresholds": { "required": ["d_kl_nats", "decode_tok_s", "ttft_seconds", "resident_memory_gb", "bottleneck_identified"] },
          "pass_per_axis": { "required": ["d_kl_nats", "decode_tok_s", "ttft_seconds", "resident_memory_gb", "bottleneck_identified"] }
        },
        "anyOf": [
          { "required": ["provider_receipts"] },
          {
            "properties": {
              "notes": {
                "pattern": "local_reference_only=true"
              }
            },
            "required": ["notes"]
          }
        ]
      }
    }
  ],
  "additionalProperties": false
}
```
