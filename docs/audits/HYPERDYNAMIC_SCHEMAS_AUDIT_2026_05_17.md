# Hyperdynamic Schemas Audit - 2026-05-17

Owner: T1 Tri-Fusion content fabric
Slice: Iteration 1, read-only/doc-only audit
Scope: `agent_core/src/research/hyperdynamic_schemas/`, `agent_core/src/research/eml/`, Epdoc editor boundary, LocalAgent prompt/grammar boundary

## 0. Reconciliation Evidence

Commands run for the section 5.0 gate:

- `git status --short --branch` -> clean branch `codex/t1-trifusion-2026-05-16` before edits.
- `wc -l agent_core/src/research/hyperdynamic_schemas/*.rs agent_core/src/research/eml/*.rs Epistemos/Engine/EpdocPasteClassifier.swift Epistemos/Engine/EpdocBlockTemplateStore.swift Epistemos/LocalAgent/LocalAgentPromptBuilder.swift Epistemos/LocalAgent/LocalToolGrammar.swift js-editor/src/* js-editor/src/*/*`
- `rg -c "#\\[test\\]" agent_core/src/research/hyperdynamic_schemas/*.rs agent_core/src/research/eml/*.rs`
- `rg -n "pub (struct|enum|trait|fn|const|type)|^pub mod|^pub use" agent_core/src/research/hyperdynamic_schemas agent_core/src/research/eml`
- `rg -n "TriFusion|Tri-Fusion|tri_fusion" agent_core/src Epistemos js-editor/src docs/fusion docs/audits --glob '!docs/audits/codebase-verbatim-packets-2026-05-09/**'` -> no current implementation/doc hits in those paths.
- `find agent_core/src -maxdepth 2 -type d -name tri_fusion -print` -> no existing module.
- `git log --oneline -- agent_core/src/research/hyperdynamic_schemas agent_core/src/research/eml Epistemos/Engine/EpdocPasteClassifier.swift Epistemos/Engine/EpdocBlockTemplateStore.swift Epistemos/LocalAgent/LocalAgentPromptBuilder.swift Epistemos/LocalAgent/LocalToolGrammar.swift js-editor/src | head -80`
- `cargo test --manifest-path agent_core/Cargo.toml --lib` was started before this doc edit and completed after authoring with the baseline recorded in section 8.

## 1. Verdict

The existing substrate is a good seed for Tri-Fusion, but it is not yet Tri-Fusion.

`hyperdynamic_schemas` currently provides a deterministic, flat, scalar schema repair and schema diff runtime. It can validate JSON-like field maps, widen field type unions, add optional fields, downgrade required fields under permissive policy, and emit deterministic backward-compatibility diffs. It does not yet model nested ProseMirror trees, Markdown byte preservation, HTML semantic tree equivalence, block identity, mutation witnesses, or provenance hooks.

`eml` currently provides an EML arithmetic and grammar floor: the binary `eml(x,y) = exp(x) - ln(y)` primitive, expression-tree grammar, depth-capped evaluator, smoke ULP oracle, and AnswerPacket freeze gate. It is useful for future Tri-Fusion ambiguity resolution, but no current code uses it to classify or choose among MD/JSON/HTML parses.

The Epdoc editor already has a rich local content surface: Tiptap stores canonical ProseMirror JSON, parses selected Markdown paste structures into JSON nodes, renders HTML-rich custom nodes, and bridges content snapshots into Swift. The missing piece is model-facing structured mutation. Today the Swift/JS bridge can set whole content JSON, run named commands, insert slash choices, and save snapshots; it cannot yet receive `insert-block`, `mutate-block`, `link-block`, or `transclude-block` envelopes from a model.

LocalAgent currently tells models to write Markdown vault notes and use XML-wrapped JSON tool calls. `LocalToolGrammar` can build structured tool-call and JSON-output plans when MLXStructured/JSONSchema are present. Neither path mentions Tri-Fusion, `TriFusionDocument`, nor block mutation operations.

## 2. Size And Test Inventory

| Surface | Files | LOC | Unit tests found by `#[test]` | Current role |
|---|---:|---:|---:|---|
| `agent_core/src/research/hyperdynamic_schemas/` | 3 | 1,141 | 44 | Schema repair and diff floor |
| `agent_core/src/research/eml/` | 6 | 1,232 | 74 | EML primitive, evaluator, ULP gate |
| `Epistemos/Engine/EpdocPasteClassifier.swift` | 1 | 210 | Swift test status not counted here | Scaffold-only paste intent classifier |
| `Epistemos/Engine/EpdocBlockTemplateStore.swift` | 1 | 139 | Swift test status not counted here | Per-vault ProseMirror JSON block templates |
| `Epistemos/LocalAgent/LocalAgentPromptBuilder.swift` | 1 | 207 | Swift test status not counted here | Model prompt with MD-oriented note guidance |
| `Epistemos/LocalAgent/LocalToolGrammar.swift` | 1 | 208 | Swift test status not counted here | Tool-call and JSON-output grammar plans |
| `js-editor/src/` | 20 | 3,750 | JS test status not counted here | Tiptap editor, bridge, Markdown paste, rich blocks |

Hyperdynamic Schemas test split:

- `repair.rs`: 25 tests.
- `diff.rs`: 19 tests.

EML test split:

- `operator.rs`: 21 tests.
- `grammar.rs`: 18 tests.
- `evaluator.rs`: 10 tests.
- `gate.rs`: 10 tests.
- `ulp_oracle.rs`: 15 tests.

## 3. Source Custody And Citations On Disk

Hyperdynamic Schemas cites:

- `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md` section 5, Phase B.1 J6.
- Liskov substitution and type-union widening.
- Bonifati et al., "Schema Evolution in Document Databases", VLDB 2024.
- Bourbaki-style structural mathematics.

EML cites:

- `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` section 1.1 and Terminal B Phase B.0.
- Odrzywolek, "Liouvillian-elementary universality of `eml(x,y) = exp(x) - ln(y)`", arXiv:2603.21852.
- Stachowiak, "Abelian-group + functional-inverse decomposition for EML", arXiv:2604.23893.
- The hard fence that EML universality is only over the Liouvillian-solvable subdomain.

No audit claim below treats those citations as proving Tri-Fusion. They prove the current research-floor modules only.

## 4. Hyperdynamic Schemas Public API To Tri-Fusion Roles

| Public API | Current behavior | Tri-Fusion role | Gap before implementation |
|---|---|---|---|
| `FieldType` | Scalar tags: integer, float, string, bool, null. Includes stable code/from-code helpers. | Initial scalar atom vocabulary for JSON block attributes. | Needs arrays, objects, enums, marks, rich text spans, block refs, links, embeds, and provenance fields. |
| `Value` | Scalar runtime value enum with `field_type()`. | Candidate leaf value for schema validation and repair. | Not sufficient for ProseMirror node trees or HTML attributes with nested children. |
| `FieldSchema` | Allowed type union plus required flag. Constructors for strict/optional and predicates. | Attribute-level schema for dynamic block fields. | Needs constraints beyond type: cardinality, allowed marks, child node content expressions, semantic IDs. |
| `Schema` | Deterministic `BTreeMap<String, FieldSchema>`. Builder, count, empty predicate. | Candidate dynamic block schema registry entry. | Flat only; cannot describe document-level or nested block schemas yet. |
| `ValidationError` | Missing required, type mismatch, unknown field. Stable kind and field classifiers. | Pre-mutation rejection reason and future witness input. | Needs path-aware errors such as `/content/3/attrs/src`, not just field names. |
| `RepairPolicy` | NoRepair, Conservative, Permissive. Conservative widens/adds optional; permissive also downgrades required. | Runtime policy knob for schema drift. | Tri-Fusion needs a stricter "model mutation" policy that cannot silently weaken user-authored schemas without witness/provenance. |
| `RepairReport` | Lists widened types, added optional fields, downgraded required fields. | Basis for schema evolution witness. | Needs before/after hash, affected document IDs, and SCOPE-Rex/Cognitive DAG references. |
| `SchemaError` | `NoErrorsToRepair`. | Caller bug signal. | Needs richer invalid-policy and unsupported-feature errors once nested schemas land. |
| `validate_value` | Validates a flat field map against a flat schema and returns all errors. | Preflight validation for mutation payloads. | Must accept document/block paths and typed ProseMirror JSON values. |
| `repair_schema` | Applies repair to validation errors and returns new schema plus report. | Dynamic schema evolution primitive. | Must be gated by provenance and explicit policy before model-authored repairs are accepted. |
| `SchemaChange` | Field added/removed, type widened/narrowed, required flipped; breaking classifier. | Schema-delta event for audit logs and migrations. | Needs node-type added/removed, mark-set changes, content-expression widening/narrowing, and transform classes. |
| `SchemaDiff` | Deterministic list of changes plus safe/breaking counts. | CI/audit compatibility report. | Needs stable canonical serialization and links to mutation witnesses. |
| `diff_schemas` | Diffs two flat schemas sorted by field name. | Migration diff between schema versions. | Needs tree/schema registry diff, not just one flat map. |

## 5. EML Public API To Tri-Fusion Roles

| Public API | Current behavior | Tri-Fusion role | Gap before implementation |
|---|---|---|---|
| `EmlError` | Non-positive log argument and non-finite result. | Ambiguity scoring failure reason. | Needs content-domain errors, not only arithmetic errors. |
| `eml` | Computes `exp(x) - ln(y)` over real branch with guards. | Primitive for energy terms if content ambiguity is encoded numerically. | No content features currently map into EML energy terms. |
| `eml_partial_x`, `eml_partial_y`, `eml_inverse_x` | Derivative and inverse helpers. | Potential optimization/search utilities for ambiguity minimization. | No parser-choice search API yet. |
| `EmlExpr` | Grammar tree: `One` or `Eml(left,right)`. | Serializable expression for future EML-IR annotations inside Tri-Fusion JSON. | No schema field currently carries `EmlExpr`. |
| `eml_grammar_root` | Returns `One`. | Seed expression for search. | Too primitive for real content ambiguity. |
| `MAX_EVAL_DEPTH` | 32. | Safety cap for expression evaluation. | Tri-Fusion will need per-document and per-paste time budgets too. |
| `EmlEvalError` | Depth exceeded or operator error. | Witnessable evaluation failure. | Needs provenance-friendly serialization if exposed through FFI. |
| `evaluate` | Depth-capped recursive evaluator. | Runtime evaluator for any EML-typed expression in a document. | Not wired to document schema or model grammar. |
| `UlpToleranceFp16` | Tolerance bar; shipping bar is 2 ULP. | Arithmetic acceptance floor. | Not directly a content-fabric concern except for trustworthy numeric blocks. |
| `UlpOracleReport` | Smoke oracle stats plus within/outside fractions. | Evidence payload for numeric block safety. | Production fixture remains outside this module. |
| `run_smoke_oracle` | Runs 1,024 sample smoke ULP oracle. | Gate input for numeric-expression mutation acceptance. | Full 412k plus stress fixture not wired here. |
| `GateStatus`, `GateError` | AnswerPacket freeze allowed/blocked around ULP smoke report. | Existing gate model Tri-Fusion can imitate for schema freeze. | Current gate is AnswerPacket-specific, not Tri-Fusion-specific. |
| `check_answer_packet_freeze_allowed`, `check_with_custom_tolerance` | Smoke-gate entrypoints. | Pattern for a future `check_tri_fusion_schema_freeze_allowed`. | No Tri-Fusion gate exists yet. |

## 6. Editor And LocalAgent Boundary Reality

Verified editor facts:

- `js-editor/src/index.ts` mounts Tiptap with StarterKit, Link, Highlight, tables, task lists, math, footnotes, custom code, Mermaid, chart, image, callout, slash menu, image asset bridge, Markdown input rules, and paste classifier bridge.
- `js-editor/src/markdown/markdown-paste.ts` converts selected Markdown structures into ProseMirror JSON nodes: headings, fences, Mermaid, chart JSON fences, task/bullet/ordered lists, blockquotes/callouts, tables, inline marks, wiki links, links, math, and image lines.
- `js-editor/src/bridge/outbound.ts` sends `contentDidChange` snapshots as stringified ProseMirror JSON.
- `js-editor/src/bridge/inbound.ts` accepts `setContent`, focus commands, `insertSlashChoice`, `runCommand`, image completion, heading/paragraph commands, graph insertion, frontmatter insertion, and code-block toggling.
- `Epistemos/Engine/EpdocEditorBridge.swift` decodes standard bridge messages but has no structured Tri-Fusion mutation case.
- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift` forwards `contentDidChange` JSON into persistence/projection and handles image asset requests. It intercepts `classifyPaste` out of band.
- `Epistemos/Engine/EpdocPasteClassifier.swift` is explicitly scaffold-only and says no production Swift caller reaches it today.
- `Epistemos/Engine/EpdocBlockTemplateStore.swift` persists ProseMirror JSON node templates in `<vault>/.epcache/templates/<template_id>.json`.

Verified LocalAgent facts:

- `LocalAgentPromptBuilder.systemPrompt` tells models to use tool calls and, for vault writes, to write full Markdown content to `.md` paths.
- `LocalToolGrammar.buildToolCallingPlan` can build structured XML-wrapped tool-call output with JSON Schema masking when MLXStructured/CMLXStructured/JSONSchema are linked; otherwise it degrades to soft guidance.
- `LocalToolGrammar.buildJsonOutputPlan` can build a generic JSON-output plan from a schema string.
- Neither file contains Tri-Fusion vocabulary or mutation operations.

## 7. Drift And Risk Register

| ID | Finding | Severity | Evidence | Required follow-up |
|---|---|---:|---|---|
| TF-AUDIT-001 | No `agent_core/src/tri_fusion/` module exists. | Blocking for Phase C | `find agent_core/src -maxdepth 2 -type d -name tri_fusion -print` returned no paths. | Create module after doctrine doc. |
| TF-AUDIT-002 | No `TriFusionDocument`, `TriFusionMutation`, or `TriFusionWitness` exists in code. | Blocking for FFI/API | Tri-Fusion grep against `agent_core/src`, `Epistemos`, and `js-editor/src` returned no hits. | Define Rust API and opaque handle in implementation phase. |
| TF-AUDIT-003 | Hyperdynamic schema runtime is flat and scalar-only. | High | Public API has only `FieldType`, scalar `Value`, flat `Schema`. | Add nested document/block schema support before claiming MD/JSON/HTML fabric. |
| TF-AUDIT-004 | Existing repair can weaken schemas under `Permissive` without provenance. | High | `RepairPolicy::Permissive` downgrades missing required fields. | Gate model-authored repairs behind witness/provenance and explicit policy. |
| TF-AUDIT-005 | Markdown paste parser is one-way into ProseMirror JSON; byte-equal Markdown round-trip is absent. | High | `parseMarkdownPaste` returns JSON nodes or null; no serializer in `js-editor/src/markdown/`. | Define supported Markdown subset and byte-preserving serializer. |
| TF-AUDIT-006 | HTML semantic tree round-trip is absent as a named testable lemma. | High | Tiptap renders/parses HTML nodes but no `HTML <-> JSON` Tri-Fusion harness exists. | Add semantic-tree canonicalizer and property tests. |
| TF-AUDIT-007 | Epdoc receiver handles snapshots and commands, not structured model mutations. | High | Bridge has `contentDidChange`, `setContent`, `insertSlashChoice`, `runCommand`; no insert/mutate/link/transclude envelope. | Add mutation receiver and visible model-authored block marking. |
| TF-AUDIT-008 | EML is not wired to content ambiguity. | Medium | EML modules are arithmetic/grammar/gate only. | Use EML as optional ambiguity scorer after round-trip doctrine defines choices. |
| TF-AUDIT-009 | LocalAgent remains Markdown-oriented for notes. | High | Prompt says use `.md` path and full markdown content. | Extend prompt and grammar with Tri-Fusion mutation ABI. |

## 8. Baseline Result

`cargo test --manifest-path agent_core/Cargo.toml --lib` baseline for this iteration:

```
running 1671 tests
test result: ok. 1671 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 4.58s
```

The cold build emitted two pre-existing dead-code warnings in `src/resonance/mod.rs` and `src/scope_rex/retrieval/hopfield.rs`; no code was changed in this iteration.

## 9. Iteration 2 Handoff

The doctrine doc should not pretend the current modules already implement the fabric. The honest design starting point is:

1. JSON is currently the only canonical editor body (`editor.getJSON()` and `.epdoc` content JSON).
2. Markdown exists as parse/input convenience, not a byte-preserving canonical peer.
3. HTML exists as Tiptap render/parse behavior, not as a tested semantic-tree round-trip peer.
4. Hyperdynamic Schemas should become the dynamic block/schema registry below Tri-Fusion, but it must grow nested path-aware schemas.
5. EML should stay optional at first: use it only for ambiguous parse choice scoring after deterministic round-trip lemmas are pinned.
6. The first real API should be `TriFusionDocument` plus typed mutation envelopes, not opaque full-text patching.
