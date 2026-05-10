# Verbatim Codebase Markdown Packets

Generated: 2026-05-09

This bundle converts the git-tracked, text-readable source corpus into markdown packets for external research. Each packet begins with an outline and then includes verbatim fenced file contents.

## Scope

- Source of truth: `git ls-files` from the current workspace.
- Requested packet count: 40
- Actual code packets: 40
- Included files: 6,246
- Included bytes: 134,194,715
- Included lines: 2,345,930
- Skipped tracked files: 27,669

## Exclusion Policy

Skipped files are build outputs, binary/model/media assets, generated artifacts, recursive audit packets, or text files larger than the configured per-file cap. This keeps the markdown corpus useful for code research without embedding object files, model weights, images, or generated build state.

### Skipped Reasons

- excluded generated/build/audit prefix: 24,389
- excluded path component target: 2,955
- binary/generated extension .comp: 124
- binary/generated extension .docx: 46
- binary/generated extension .png: 30
- binary/generated extension .woff2: 20
- binary or non-text: 17
- binary/generated extension .gguf: 17
- binary/generated extension .pdf: 13
- binary/generated extension .inp: 13
- binary/generated extension .out: 13
- binary/generated extension .webp: 12
- gitlink/submodule directory: 5
- too large for markdown packet: 4104379 bytes: 2
- too large for markdown packet: 2362880 bytes: 1
- too large for markdown packet: 27531472 bytes: 1
- too large for markdown packet: 2335138 bytes: 1
- too large for markdown packet: 2955890 bytes: 1
- too large for markdown packet: 2255577 bytes: 1
- too large for markdown packet: 2628186 bytes: 1
- binary/generated extension .jpeg: 1
- binary/generated extension .gz: 1
- binary/generated extension .jpg: 1
- too large for markdown packet: 2601458 bytes: 1
- too large for markdown packet: 6622399 bytes: 1
- too large for markdown packet: 3623113 bytes: 1
- too large for markdown packet: 64316888 bytes: 1

## Top-Level Coverage

- `docs`: 2,472 files, 60,914,717 bytes
- `LocalPackages`: 1,774 files, 34,618,710 bytes
- `Epistemos`: 758 files, 21,435,176 bytes
- `EpistemosTests`: 356 files, 5,688,779 bytes
- `agent_core`: 250 files, 3,739,421 bytes
- `graph-engine`: 67 files, 3,387,469 bytes
- `epistemos-core`: 56 files, 838,097 bytes
- `epistemos-research`: 56 files, 455,497 bytes
- `scripts`: 59 files, 371,290 bytes
- `js-editor`: 32 files, 328,002 bytes
- `omega-mcp`: 28 files, 303,587 bytes
- `epistemos-shadow`: 12 files, 200,175 bytes
- `Tools`: 51 files, 120,521 bytes
- `Epistemos.xcodeproj`: 5 files, 99,993 bytes
- `syntax-core`: 11 files, 91,109 bytes
- `bench`: 4 files, 82,762 bytes
- `SKILL_PORTING_GUIDE.md`: 1 files, 76,507 bytes
- `reference-code`: 5 files, 65,237 bytes
- `omega-ax`: 13 files, 63,017 bytes
- `lean`: 38 files, 55,055 bytes
- `substrate-core`: 10 files, 54,664 bytes
- `graph-engine-bridge`: 2 files, 43,129 bytes
- `CODEX_FULL_AUDIT_SYNTHESIS.md`: 1 files, 41,517 bytes
- `conversation_export_full.md`: 1 files, 39,750 bytes
- `IMPLEMENTATION_PLAN_FEATURES.md`: 1 files, 34,264 bytes
- `epistemos-code-index`: 6 files, 33,675 bytes
- `EPISTEMOS-NORTH-STAR.md`: 1 files, 29,823 bytes
- `substrate-rt`: 6 files, 29,552 bytes
- `omega_verify.sh`: 1 files, 27,799 bytes
- `CLAUDE.md`: 1 files, 25,298 bytes
- `MAMBA2_CODEX_IMPLEMENTATION_GUIDE.md`: 1 files, 23,294 bytes
- `IMPLEMENTATION_ADVICE_SYNTHESIS.md`: 1 files, 23,261 bytes
- `SESSION_SYNTHESIS_2026-04-09.md`: 1 files, 23,175 bytes
- `HERMES_PARITY_AUDIT_REPORT.md`: 1 files, 23,005 bytes
- `compaction.rs`: 1 files, 22,813 bytes
- `project.yml`: 1 files, 22,450 bytes
- `.github`: 3 files, 22,089 bytes
- `.claude`: 4 files, 21,162 bytes
- `LOCAL_MODEL_STACK_ADVICE.md`: 1 files, 20,472 bytes
- `epistemos-vault`: 13 files, 20,442 bytes
- `security.rs`: 1 files, 20,257 bytes
- `CONTEXTUAL_SCALPEL_IMPLEMENTATION_PLAN.md`: 1 files, 19,942 bytes
- `HANDOFF_SESSION_2026-04-07.md`: 1 files, 19,070 bytes
- `COMPREHENSIVE_AGENT_AUDIT_SYNTHESIS.md`: 1 files, 19,045 bytes
- `.agents`: 7 files, 16,552 bytes
- `NEXT_SESSION_PASTE_IN_BRIEF_2026-04-08.md`: 1 files, 16,271 bytes
- `RELEASE_READINESS_AUDIT.md`: 1 files, 16,221 bytes
- `PHASE9_AUDIT.md`: 1 files, 15,788 bytes
- `AGENTS.md`: 1 files, 15,244 bytes
- `NEXT_SESSION_RELEASE_SYNTHESIS_2026-04-08.md`: 1 files, 14,593 bytes
- `CODEBASE_AUDIT_SYNTHESIS.md`: 1 files, 14,389 bytes
- `LOCAL_MODEL_CAPABILITY_AUDIT_SYNTHESIS.md`: 1 files, 12,657 bytes
- `FFI_AUDIT.md`: 1 files, 12,432 bytes
- `RELEASE_PATCHSET_SUMMARY.md`: 1 files, 11,539 bytes
- `sprint-omega-1-foundation.md`: 1 files, 11,480 bytes
- `V1_RELEASE_GATE_AUDIT.md`: 1 files, 11,341 bytes
- `AGENT_SOURCE_SYNTHESIS.md`: 1 files, 11,044 bytes
- `TEST_SUITE_SUMMARY.md`: 1 files, 10,460 bytes
- `benchmarks`: 12 files, 10,438 bytes
- `CLAUDE_IMPLEMENTATION_AUDIT.md`: 1 files, 10,430 bytes
- `WHOLE_APP_PERF_MAP.md`: 1 files, 10,056 bytes
- `CLAUDE_IMPLEMENTATION_AUDIT_V2.md`: 1 files, 9,664 bytes
- `CODE_EDITOR_GPU_AUDIT.md`: 1 files, 9,535 bytes
- `RESEARCH_PROMPT.md`: 1 files, 9,426 bytes
- `TESTING_GUIDE.md`: 1 files, 9,321 bytes
- `STATE_OF_SYSTEM.md`: 1 files, 9,305 bytes
- `INTEGRATION_GUIDE.md`: 1 files, 8,934 bytes
- `TEST_AND_VALIDATION_MATRIX.md`: 1 files, 8,870 bytes
- `AUDIT_MATRIX.md`: 1 files, 8,581 bytes
- `TEST_COVERAGE_SUMMARY.md`: 1 files, 8,566 bytes
- `GROUND_TRUTH_SYNTHESIS.md`: 1 files, 8,439 bytes
- `A+_RELEASE_ROADMAP.md`: 1 files, 8,068 bytes
- `prompt_caching.rs`: 1 files, 7,980 bytes
- `SHIP_PROGRESS_2026-04-05.md`: 1 files, 7,976 bytes
- `AGENT_REPLACEMENT_PLAN.md`: 1 files, 7,731 bytes
- `CODEX_REVIEW_REPORT.md`: 1 files, 7,717 bytes
- `CODE_EDITOR_FEATURE_AUDIT.md`: 1 files, 7,414 bytes
- `ARCHITECTURE_MAP.md`: 1 files, 7,344 bytes
- `FIX_LOG.md`: 1 files, 7,205 bytes
- `CRASH_REPRO_AND_OWNERSHIP_AUDIT.md`: 1 files, 6,987 bytes
- `MAMBA2_RUNTIME_PLAN.md`: 1 files, 6,924 bytes
- `syntax-core-bridge`: 1 files, 6,460 bytes
- `generate_hardened_native_tests.py`: 1 files, 6,374 bytes
- `build-tiptap-bundle.sh`: 1 files, 6,087 bytes
- `FFI_OPPORTUNITY_MATRIX.md`: 1 files, 5,814 bytes
- `AGENT_MIGRATION_MATRIX.md`: 1 files, 5,810 bytes
- `patch-uniffi-bindings.py`: 1 files, 5,607 bytes
- `SHIP_SCOPE_V1.md`: 1 files, 5,454 bytes
- `BEFORE_AFTER_BENCHMARKS.md`: 1 files, 5,433 bytes
- `AGENT_COMMAND_CENTER_UX_HANDOFF.md`: 1 files, 5,402 bytes
- `generate_swift_tests.py`: 1 files, 5,340 bytes
- `think.rs`: 1 files, 5,253 bytes
- `AGENT_RUNTIME_ARCHITECTURE.md`: 1 files, 5,224 bytes
- `LATENCY_BUGS_AND_HIDDEN_TAX.md`: 1 files, 5,147 bytes
- `ffi_copy_trace.md`: 1 files, 5,024 bytes
- `SYSTEMS_UPGRADE_PLAN.md`: 1 files, 4,510 bytes
- `AI_VAULT_RUNTIME_AUDIT.md`: 1 files, 4,428 bytes
- `MAMBA2_PHASE1_COMPLETION.md`: 1 files, 4,281 bytes
- `STARTING_PROMPT.md`: 1 files, 4,228 bytes
- `build-omega-mcp.sh`: 1 files, 4,175 bytes
- `build-agent-core.sh`: 1 files, 4,146 bytes
- `TAHOE_TEXT_VISIBILITY_FIXES.md`: 1 files, 4,032 bytes
- `Epistemos-Info.plist`: 1 files, 3,915 bytes
- `BENCHMARK_AFTER.md`: 1 files, 3,911 bytes
- `bundle-app-runtime-assets.sh`: 1 files, 3,783 bytes
- `TOP_LATENCY_WINS.md`: 1 files, 3,664 bytes
- `AGENT_TEST_PLAN.md`: 1 files, 3,644 bytes
- `build-epistemos-core.sh`: 1 files, 3,640 bytes
- `generate_advanced_swift_tests.py`: 1 files, 3,472 bytes
- `COZO_AUDIT.md`: 1 files, 3,470 bytes
- `PERFORMANCE_DECISION_RULES.md`: 1 files, 3,376 bytes
- `RESEARCH_PROMPT_SHORT.md`: 1 files, 3,324 bytes
- `VAULT_STATE_SCHEMA.md`: 1 files, 3,281 bytes
- `MIGRATION_AND_ROLLBACK_PLAN.md`: 1 files, 3,171 bytes
- `build-omega-ax.sh`: 1 files, 3,161 bytes
- `settings.json`: 1 files, 3,090 bytes
- `EpistemosNightBrainHelper`: 1 files, 3,082 bytes
- `Epistemos-AppStore-Info.plist`: 1 files, 3,025 bytes
- `AGENT_PROGRESS.md`: 1 files, 3,002 bytes
- `build-epistemos-shadow.sh`: 1 files, 2,614 bytes
- `WATCHER_AUDIT.md`: 1 files, 2,585 bytes
- `EpistemosWidgets`: 2 files, 2,292 bytes
- `graph-engine-build-inputs.xcfilelist`: 1 files, 2,199 bytes
- `AGENT_BENCHMARKS.md`: 1 files, 2,077 bytes
- `config`: 2 files, 2,007 bytes
- `PERF_BASELINE.md`: 1 files, 1,921 bytes
- `query_hot_path_findings.md`: 1 files, 1,863 bytes
- `PARSER_AUDIT.md`: 1 files, 1,666 bytes
- `XPCServices`: 4 files, 1,619 bytes
- `build-rust.sh`: 1 files, 1,485 bytes
- `fractional_index_pathology_report.md`: 1 files, 1,396 bytes
- `Makefile`: 1 files, 1,321 bytes
- `CRDT_AUDIT.md`: 1 files, 1,312 bytes
- `build-substrate-rt.sh`: 1 files, 1,286 bytes
- `build-epistemos-code-index.sh`: 1 files, 1,283 bytes
- `.swiftlint.yml`: 1 files, 1,224 bytes
- `.gitignore`: 1 files, 1,185 bytes
- `embed-and-sign-rust-dylib.sh`: 1 files, 1,131 bytes
- `BENCHMARK_BASELINE.md`: 1 files, 1,093 bytes
- `build-syntax-core.sh`: 1 files, 1,028 bytes
- `SWIFT_UI_AUDIT.md`: 1 files, 995 bytes
- `PERF_AUDIT.md`: 1 files, 978 bytes
- `subscription_lifecycle_report.md`: 1 files, 886 bytes
- `SAFETY_AUDIT.md`: 1 files, 805 bytes
- `mainactor_pressure_report.md`: 1 files, 805 bytes
- `MIGRATION_PLAN.md`: 1 files, 799 bytes
- `Epistemos-Bridging-Header.h`: 1 files, 789 bytes
- `RISK_REGISTER.md`: 1 files, 783 bytes
- `parser_benchmark.md`: 1 files, 709 bytes
- `GO_NO_GO.md`: 1 files, 682 bytes
- `schema_gap_report.md`: 1 files, 655 bytes
- `FUZZ_PLAN.md`: 1 files, 635 bytes
- `ABI_AUDIT.md`: 1 files, 634 bytes
- `parser_allocations_report.md`: 1 files, 596 bytes
- `.vscode`: 1 files, 558 bytes
- `render_update_batching_report.md`: 1 files, 328 bytes
- `.cargo`: 1 files, 146 bytes
- `clippy.toml`: 1 files, 114 bytes
- `.gitmodules`: 1 files, 0 bytes

## Packet Map

| Packet | Files | Bytes | Lines | Main Areas |
|---|---:|---:|---:|---|
| [01_CODE_PACKET.md](01_CODE_PACKET.md) | 200 | 3,364,649 | 87,107 | `Epistemos` (197), `AGENTS.md` (1), `CLAUDE.md` (1), `project.yml` (1) |
| [02_CODE_PACKET.md](02_CODE_PACKET.md) | 54 | 3,990,674 | 13,253 | `Epistemos` (54) |
| [03_CODE_PACKET.md](03_CODE_PACKET.md) | 5 | 3,071,463 | 2,700 | `Epistemos` (5) |
| [04_CODE_PACKET.md](04_CODE_PACKET.md) | 21 | 3,429,276 | 4,894 | `Epistemos` (21) |
| [05_CODE_PACKET.md](05_CODE_PACKET.md) | 213 | 2,985,049 | 54,466 | `Epistemos` (213) |
| [06_CODE_PACKET.md](06_CODE_PACKET.md) | 181 | 3,304,964 | 86,872 | `Epistemos` (181) |
| [07_CODE_PACKET.md](07_CODE_PACKET.md) | 236 | 3,346,128 | 85,158 | `EpistemosTests` (149), `Epistemos` (87) |
| [08_CODE_PACKET.md](08_CODE_PACKET.md) | 194 | 3,486,099 | 81,858 | `EpistemosTests` (194) |
| [09_CODE_PACKET.md](09_CODE_PACKET.md) | 80 | 3,315,226 | 95,063 | `graph-engine` (60), `EpistemosTests` (13), `XPCServices` (4), `EpistemosWidgets` (2), `EpistemosNightBrainHelper` (1) |
| [10_CODE_PACKET.md](10_CODE_PACKET.md) | 214 | 3,262,936 | 94,278 | `agent_core` (205), `graph-engine` (7), `graph-engine-bridge` (2) |
| [11_CODE_PACKET.md](11_CODE_PACKET.md) | 319 | 3,353,443 | 97,841 | `LocalPackages` (131), `epistemos-core` (56), `agent_core` (45), `omega-mcp` (28), `omega-ax` (13) |
| [12_CODE_PACKET.md](12_CODE_PACKET.md) | 106 | 3,997,071 | 55,497 | `LocalPackages` (106) |
| [13_CODE_PACKET.md](13_CODE_PACKET.md) | 3 | 3,225,633 | 22,847 | `LocalPackages` (3) |
| [14_CODE_PACKET.md](14_CODE_PACKET.md) | 3 | 4,357,761 | 28,620 | `LocalPackages` (3) |
| [15_CODE_PACKET.md](15_CODE_PACKET.md) | 196 | 1,964,393 | 49,349 | `LocalPackages` (196) |
| [16_CODE_PACKET.md](16_CODE_PACKET.md) | 96 | 3,229,979 | 69,671 | `LocalPackages` (96) |
| [17_CODE_PACKET.md](17_CODE_PACKET.md) | 317 | 3,386,241 | 87,159 | `LocalPackages` (317) |
| [18_CODE_PACKET.md](18_CODE_PACKET.md) | 194 | 3,399,902 | 76,951 | `LocalPackages` (194) |
| [19_CODE_PACKET.md](19_CODE_PACKET.md) | 118 | 3,299,527 | 86,894 | `LocalPackages` (118) |
| [20_CODE_PACKET.md](20_CODE_PACKET.md) | 375 | 4,171,485 | 114,959 | `LocalPackages` (375) |
| [21_CODE_PACKET.md](21_CODE_PACKET.md) | 216 | 2,512,552 | 70,192 | `LocalPackages` (216) |
| [22_CODE_PACKET.md](22_CODE_PACKET.md) | 250 | 3,371,458 | 66,903 | `docs` (70), `scripts` (59), `Tools` (51), `js-editor` (32), `LocalPackages` (19) |
| [23_CODE_PACKET.md](23_CODE_PACKET.md) | 179 | 3,344,367 | 65,779 | `docs` (179) |
| [24_CODE_PACKET.md](24_CODE_PACKET.md) | 147 | 3,381,147 | 62,783 | `docs` (147) |
| [25_CODE_PACKET.md](25_CODE_PACKET.md) | 116 | 3,347,387 | 53,542 | `docs` (116) |
| [26_CODE_PACKET.md](26_CODE_PACKET.md) | 86 | 3,350,249 | 41,230 | `docs` (86) |
| [27_CODE_PACKET.md](27_CODE_PACKET.md) | 97 | 3,361,488 | 37,304 | `docs` (97) |
| [28_CODE_PACKET.md](28_CODE_PACKET.md) | 94 | 3,347,311 | 39,297 | `docs` (94) |
| [29_CODE_PACKET.md](29_CODE_PACKET.md) | 135 | 3,373,419 | 50,337 | `docs` (135) |
| [30_CODE_PACKET.md](30_CODE_PACKET.md) | 45 | 4,088,070 | 54,696 | `docs` (45) |
| [31_CODE_PACKET.md](31_CODE_PACKET.md) | 3 | 2,633,574 | 19,808 | `docs` (3) |
| [32_CODE_PACKET.md](32_CODE_PACKET.md) | 10 | 3,397,800 | 28,779 | `docs` (10) |
| [33_CODE_PACKET.md](33_CODE_PACKET.md) | 84 | 3,278,196 | 39,112 | `docs` (84) |
| [34_CODE_PACKET.md](34_CODE_PACKET.md) | 587 | 3,356,068 | 57,381 | `docs` (587) |
| [35_CODE_PACKET.md](35_CODE_PACKET.md) | 184 | 3,386,531 | 77,068 | `docs` (184) |
| [36_CODE_PACKET.md](36_CODE_PACKET.md) | 145 | 3,305,523 | 43,420 | `docs` (145) |
| [37_CODE_PACKET.md](37_CODE_PACKET.md) | 86 | 3,353,267 | 49,196 | `docs` (86) |
| [38_CODE_PACKET.md](38_CODE_PACKET.md) | 212 | 3,358,340 | 60,785 | `docs` (212) |
| [39_CODE_PACKET.md](39_CODE_PACKET.md) | 93 | 3,367,413 | 50,899 | `docs` (93) |
| [40_CODE_PACKET.md](40_CODE_PACKET.md) | 352 | 3,338,656 | 81,982 | `docs` (99), `epistemos-research` (56), `lean` (38), `epistemos-vault` (13), `.agents` (7) |

## Research Notes

- Use `00_INDEX.md` first to understand which packets contain which top-level systems.
- Packet order roughly follows product architecture first, tests/runtime next, package/runtime crates next, scripts/tools/docs later.
- Every file body is verbatim; only packet headings and metadata are generated.
- To regenerate, run `python3 scripts/generate_verbatim_code_packets.py --packets 40` from the repo root.

