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

## 8. Baseline Results

`cargo test --manifest-path agent_core/Cargo.toml --lib` baseline for iteration 1:

```
running 1671 tests
test result: ok. 1671 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 4.58s
```

The cold build emitted two pre-existing dead-code warnings in `src/resonance/mod.rs` and `src/scope_rex/retrieval/hopfield.rs`; no code was changed in this iteration.

`cargo test --manifest-path agent_core/Cargo.toml --lib` baseline for iteration 2:

```
running 1671 tests
test result: ok. 1671 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 1.94s
```

The warm run emitted the same two pre-existing dead-code warnings. No production code was changed in this iteration.

`cargo test --manifest-path agent_core/Cargo.toml --lib` baseline for iteration 3:

```
running 1671 tests
test result: ok. 1671 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 2.07s
```

The warm run emitted the same two pre-existing dead-code warnings. No production code was changed in this iteration.

`cargo test --manifest-path agent_core/Cargo.toml --lib` baseline for iteration 4:

```
running 1671 tests
test result: ok. 1671 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 1.48s
```

The warm run emitted the same two pre-existing dead-code warnings. No production code was changed in this iteration.

`cargo test --manifest-path agent_core/Cargo.toml --lib` baseline for iteration 5:

```
running 1671 tests
test result: ok. 1671 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 7.38s
```

The warm run emitted the same two pre-existing dead-code warnings. No production code was changed in this iteration.

`cargo test --manifest-path agent_core/Cargo.toml --lib` baseline for iteration 6:

```
running 1671 tests
test result: ok. 1671 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 3.17s
```

The warm run emitted the same two pre-existing dead-code warnings. No production code was changed in this iteration.

`cargo test --manifest-path agent_core/Cargo.toml --lib` baseline for iteration 7:

```
running 1671 tests
test result: ok. 1671 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 1.55s
```

The warm run emitted the same two pre-existing dead-code warnings. No production code was changed in this iteration.

## 9. Design Starting Point

The doctrine doc should not pretend the current modules already implement the fabric. The honest design starting point is:

1. JSON is currently the only canonical editor body (`editor.getJSON()` and `.epdoc` content JSON).
2. Markdown exists as parse/input convenience, not a byte-preserving canonical peer.
3. HTML exists as Tiptap render/parse behavior, not as a tested semantic-tree round-trip peer.
4. Hyperdynamic Schemas should become the dynamic block/schema registry below Tri-Fusion, but it must grow nested path-aware schemas.
5. EML should stay optional at first: use it only for ambiguous parse choice scoring after deterministic round-trip lemmas are pinned.
6. The first real API should be `TriFusionDocument` plus typed mutation envelopes, not opaque full-text patching.

## 10. Iteration 2 Addendum - Existing Invariants And Missing Lemmas

This addendum records the current test-backed invariants that Tri-Fusion can inherit and the lemmas it still lacks. The point is to keep the later doctrine doc honest: a tested flat-schema invariant is useful, but it is not a tested document-fabric invariant until the supported MD/JSON/HTML subset is explicit.

### 10.1 Existing Rust Invariants

| Surface | Existing invariant coverage | Why it matters | Tri-Fusion gap |
|---|---|---|---|
| `repair_schema` | Empty schema accepts empty value; strict schemas validate matching values; type mismatches, missing required fields, and unknown fields are all surfaced; conservative repair widens type unions and adds optional fields; original type remains valid after widening. | This is the monotone-schema seed for dynamic block schemas. | The invariant is flat-field only; it does not prove nested block or rich text preservation. |
| `RepairPolicy` | `NoRepair` leaves schema unchanged; `Conservative` does not downgrade required fields; `Permissive` can downgrade required fields; policy codes round-trip. | Defines a clear policy boundary for model-authored schema evolution. | The model-facing policy must reject silent permissive weakening unless the user or a capability gate authorizes it. |
| `RepairReport` | Empty report iff total changes is zero; total changes sum the three categories. | Gives a deterministic repair summary shape. | Needs document ID, schema version, before/after hash, actor, and witness IDs. |
| `ValidationError` | Kind strings are distinct; classifier predicates form a three-way partition; field names extract consistently. | Useful for stable wire diagnostics. | Needs path-aware diagnostics for nested ProseMirror JSON, such as `/content/2/attrs/kind`. |
| `diff_schemas` | Identical schemas produce empty diffs; added/removed required fields break as expected; type widened is safe; type narrowed is breaking; mixed add/remove decomposes into two changes; output order is deterministic. | This is the compatibility gate seed. | Needs document-schema registry diffs, content-expression diffs, and mark/node-kind diffs. |
| `SchemaDiff` | Serde JSON round-trip works; safe plus breaking counts equal total; breaking count zero iff not breaking; change classifiers form a five-way partition. | Good audit-log payload shape. | Needs canonical serialization test against `TriFusionWitness`. |
| `eml` operator | Basic identities, branch-cut rejection, non-finite rejection, finite grid, partial derivatives, and inverse round-trips are tested. | Gives a numeric primitive with sane guardrails. | No document ambiguity scoring function consumes it. |
| `EmlExpr` grammar | Depth, size, leaves/internal identity, balance, perfect-tree leaf count, and serde JSON round-trip are tested. | Candidate embedded expression IR for future numeric blocks. | No Tri-Fusion schema type can carry or validate this expression yet. |
| `evaluate` | Leaf and nested evaluation, depth-4 bounded case, max-depth cap, and operator-error propagation are tested. | Gives bounded local evaluation. | No FFI-safe error serialization and no document budget integration yet. |
| `ulp_oracle` | Smoke sample count, 2-ULP bar, smoke pass, loose/strict tolerance behavior, report serde round-trip, and fraction invariants are tested. | Numeric-block acceptance can inherit a gate pattern. | Full production fixture remains deferred; this cannot be used to claim final numeric-block precision. |
| `gate` | Default AnswerPacket freeze check, status predicates, report accessor, block reason, and custom tolerance behavior are tested. | Gives a reusable gate pattern. | Gate is AnswerPacket-specific; Tri-Fusion needs its own schema and round-trip gates. |

### 10.2 Existing Editor Invariants

| Boundary | Current invariant | Tri-Fusion interpretation | Gap |
|---|---|---|---|
| JS canonical snapshot | `contentDidChange` sends `JSON.stringify(editor.getJSON())`. | JSON is the current practical canonical body. | No `TriFusionDocument` wrapper or witness hash. |
| Swift snapshot intake | `EpdocBridgeMessage.contentDidChange(json:)` forwards bytes to chrome persistence/projection. | Swift can receive full-document JSON snapshots. | No structured block mutation envelope. |
| JS content load | `setContent(json:)` parses JSON and calls `editor.commands.setContent(parsed, { emitUpdate: false })`. | JSON can hydrate the editor without feedback autosave. | No identity test from Rust handle to JS editor and back. |
| Markdown paste | `parseMarkdownPaste` converts supported Markdown structures to ProseMirror JSON. | Markdown can be an input language for a defined subset. | No Markdown serializer; byte-equal MD round-trip is absent. |
| HTML-rich custom nodes | `callout`, `epdocImage`, `mermaid`, and `epdocChart` define `parseHTML`/`renderHTML`. | HTML exists as render/parse behavior for selected block types. | No semantic-tree canonicalizer or HTML property test corpus. |
| Slash menu and commands | `insertSlashChoice` and `runCommand` apply named editor operations. | There is an operation dispatch channel. | It is command-name driven, not a typed mutation grammar with provenance. |

### 10.3 Required Later Lemmas

The implementation phase should pin these lemmas with tests before any user-facing claim that Tri-Fusion has landed:

| Lemma | Minimum test shape | Acceptance note |
|---|---|---|
| JSON identity | `TriFusionDocument::from_json(canonical).to_json() == canonical` over stable sorted/canonical JSON. | This should be the first Rust property test. |
| Markdown byte equality | For a declared supported subset, `MD -> JSON -> MD` is byte-equal. | The subset must be explicit; unsupported Markdown must be rejected or normalized with a witness. |
| HTML semantic tree equality | `HTML -> JSON -> HTML` preserves a canonical semantic tree, not raw bytes. | Whitespace, attribute order, and generated wrapper differences need a canonicalizer. |
| Mutation determinism | Applying the same `TriFusionMutation` to the same document hash yields the same output hash and witness. | Must include insert-block, mutate-block, link-block, and transclude-block. |
| Schema repair witness | Any dynamic schema widening emits a witness containing old schema hash, new schema hash, repair policy, actor, and reason. | Required before using `repair_schema` in model-authored paths. |
| Provenance hook | Every mutation maps to a ClaimGraph node and Cognitive DAG edge reference. | Must be testable without cloud or UI. |
| LocalAgent grammar | `LocalToolGrammar` can produce a JSON schema/grammar for the mutation envelope. | Must degrade honestly when true masking is unavailable. |
| Epdoc receiver | Swift can accept a typed mutation and dispatch the matching JS operation without full-text patching. | Visual model-authored highlighting belongs here, not in Rust. |

### 10.4 Minimum Corpus Plan

The required 200-document property corpus should be deterministic and generated in fixed buckets:

| Bucket | Count | Examples |
|---|---:|---|
| Plain Markdown prose | 30 | Paragraphs, headings, emphasis, code spans, links, wiki links. |
| Structured Markdown | 40 | Tables, task lists, ordered/bullet lists, blockquotes, callouts. |
| Code and math | 25 | Fenced code, inline math, block math, JSON chart fences. |
| Rich HTML | 35 | Images, callouts, Mermaid/chart wrappers, nested attributes. |
| Mixed Epdoc JSON | 40 | ProseMirror documents with marks, custom nodes, attrs, and stable IDs. |
| Mutation sequences | 30 | Insert, mutate, link, transclude, and schema-widen sequences. |

The corpus must not use random runtime state. If random generation is useful, seed it and commit the seed. Every failing case should shrink to a stable fixture checked into `tests/tri_fusion_*.rs`.

## 11. Iteration 3 Addendum - Code Anchor Custody

These anchors are the implementation locations that later Tri-Fusion doctrine should cite. They are not acceptance proof by themselves; they are custody pointers for future design and test work.

### 11.1 Rust Research Anchors

| Anchor | Current custody |
|---|---|
| `agent_core/src/research/hyperdynamic_schemas/mod.rs:40` | Module boundary for `diff` and `repair`; re-exports the public schema API. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:11` | `FieldType`, the current scalar-only type vocabulary. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:20` | `Value`, the current scalar runtime value enum. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:69` | `FieldSchema`, the current allowed-types plus required flag constraint. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:102` | `Schema`, the current flat `BTreeMap` schema. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:129` | `ValidationError`, the current non-path-aware validation diagnostic. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:179` | `RepairPolicy`, the current NoRepair/Conservative/Permissive policy. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:238` | `validate_value`, flat schema validation entrypoint. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:276` | `RepairReport`, current repair summary payload. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:285` | `repair_schema`, current schema repair entrypoint. |
| `agent_core/src/research/hyperdynamic_schemas/diff.rs:39` | `SchemaChange`, current diff event taxonomy. |
| `agent_core/src/research/hyperdynamic_schemas/diff.rs:108` | `SchemaDiff`, current diff report payload. |
| `agent_core/src/research/hyperdynamic_schemas/diff.rs:145` | `diff_schemas`, deterministic flat-schema diff entrypoint. |
| `agent_core/src/research/eml/grammar.rs:13` | `EmlExpr`, current expression tree grammar. |
| `agent_core/src/research/eml/operator.rs:21` | `eml`, current arithmetic primitive. |
| `agent_core/src/research/eml/evaluator.rs:44` | `evaluate`, current depth-capped expression evaluator. |
| `agent_core/src/research/eml/ulp_oracle.rs:88` | `run_smoke_oracle`, current ULP smoke harness. |
| `agent_core/src/research/eml/gate.rs:17` | `GateStatus`, current allowed/blocked gate report. |
| `agent_core/src/research/eml/gate.rs:64` | `check_answer_packet_freeze_allowed`, current AnswerPacket-specific gate. |

### 11.2 Editor And Swift Bridge Anchors

| Anchor | Current custody |
|---|---|
| `js-editor/src/index.ts:92` | JS posts full ProseMirror JSON snapshots through `contentDidChange`. |
| `js-editor/src/markdown/markdown-paste.ts:20` | Markdown paste parser entrypoint. |
| `js-editor/src/bridge/outbound.ts:35` | Outbound `contentDidChange` message type. |
| `js-editor/src/bridge/outbound.ts:82` | Outbound `classifyPaste` message type. |
| `js-editor/src/bridge/inbound.ts:25` | Inbound `setContent(json:)` command. |
| `js-editor/src/bridge/inbound.ts:52` | Inbound `insertSlashChoice(blockType:)` command. |
| `js-editor/src/bridge/inbound.ts:67` | Inbound generic `runCommand(name,args...)` command. |
| `Epistemos/Engine/EpdocEditorBridge.swift:393` | Swift `EpdocBridgeMessage` enum. |
| `Epistemos/Engine/EpdocEditorBridge.swift:396` | Swift `contentDidChange(json:)` case. |
| `Epistemos/Engine/EpdocEditorBridge.swift:541` | Swift `EpdocEditorCommand` enum. |
| `Epistemos/Engine/EpdocEditorBridge.swift:544` | Swift `setContent(json:)` command. |
| `Epistemos/Engine/EpdocEditorBridge.swift:557` | Swift `insertSlashChoice(blockType:)` command. |
| `Epistemos/Engine/EpdocEditorBridge.swift:563` | Swift `runCommand(name,argsJSON:)` command. |
| `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift:267` | Swift chrome `handleBridgeMessage` intake. |
| `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift:789` | Swift `classifyPaste` interception before normal bridge decode. |

### 11.3 Negative Anchors

The following absences were verified during this audit window:

- No `agent_core/src/tri_fusion/` directory.
- No `TriFusionDocument`, `TriFusionMutation`, or `TriFusionWitness` symbols in `agent_core/src`, `Epistemos`, or `js-editor/src`.
- No `tests/tri_fusion_*.rs` corpus.
- No Markdown serializer under `js-editor/src/markdown/`.
- No typed Epdoc bridge case for `insert-block`, `mutate-block`, `link-block`, or `transclude-block`.

## 12. Iteration 4 Addendum - FFI And Provenance Boundary Audit

Tri-Fusion's requested API shape names `TriFusionDocument` as an opaque handle. The current FFI boundary is not organized that way. `agent_core/src/bridge.rs` is a 3,535-line UniFFI surface built mostly from exported functions, records, callbacks, and JSON string envelopes.

### 12.1 Current FFI Anchors

| Anchor | Current custody | Tri-Fusion implication |
|---|---|---|
| `agent_core/src/bridge.rs:31` | FFI guard rule for `#[uniffi::export]` functions returning `Result`. | Any Tri-Fusion FFI function returning `Result` must use the same panic guard discipline. |
| `agent_core/src/bridge.rs:83` | Exported callback interface for streaming agent events. | Useful pattern for event callbacks, but not an opaque document handle. |
| `agent_core/src/bridge.rs:182` | `ToolConfig` UniFFI record. | Existing FFI favors records. |
| `agent_core/src/bridge.rs:201` | `AgentConfigFFI` UniFFI record. | Existing config payloads cross as value records. |
| `agent_core/src/bridge.rs:854` | `route_variant_b_schema_json(...) -> Result<String, AgentErrorFFI>`. | Existing schema output crosses as JSON string, not typed handle. |
| `agent_core/src/bridge.rs:2311` | `runtime_build_system_prompt(input_json)`. | LocalAgent prompt bridge currently consumes JSON input and returns a prompt string. |
| `agent_core/src/bridge.rs:3021` | `provenance_ledger_summary_json()`. | Provenance bridge currently exposes JSON summaries. |
| `agent_core/src/bridge.rs:3053` | `provenance_ledger_recent_events_json(limit)`. | Recent provenance events already have a JSON FFI path. |
| `agent_core/src/bridge.rs:3082` | `provenance_ledger_snapshot_json()`. | Snapshot export can be a later Tri-Fusion witness integration point. |
| `agent_core/src/bridge.rs:3122` | `lsp_send_message_json(envelope_json)`. | Existing long-lived kernel uses JSON-RPC over string APIs, not an exposed object handle. |
| `agent_core/src/bridge.rs:3160` | `lsp_poll_response_json()`. | Polling pattern exists for message queues. |
| `agent_core/src/bridge.rs:3233` | `cognitive_dag_stats_json()`. | Cognitive DAG is visible through JSON stats, not mutation edge creation APIs. |
| `agent_core/src/bridge.rs:3289` | `produce_answer_packet_json(...)`. | SCOPE-Rex answer packet is produced over FFI and already carries `mutation_envelope_id`. |

### 12.2 Existing Provenance And Mutation Anchors

| Anchor | Current custody | Tri-Fusion implication |
|---|---|---|
| `agent_core/src/mutations/envelope.rs:40` | `MutationEnvelope`, the typed mutation delivery vehicle. | Tri-Fusion should wrap or reference this rather than inventing an unrelated mutation log. |
| `agent_core/src/mutations/types.rs:107` | `BlockRef`, existing artifact/block pointer type. | Strong candidate for Tri-Fusion block references. |
| `agent_core/src/mutations/types.rs:134` | `SourceOp`, current categorical mutation descriptor. | Needs Tri-Fusion operations or a compatible detail layer. |
| `agent_core/src/provenance/ledger.rs:409` | `ClaimLedger`, in-memory provenance ledger. | ClaimGraph node creation should attach here or to the SCOPE-Rex claim graph state. |
| `agent_core/src/provenance/replay.rs:228` | `ReplayBundle`, portable replay artifact. | `TriFusionWitness` should be serializable into replay bundles. |
| `agent_core/src/provenance/replay.rs:246` | Replay bundles carry ordered `MutationEnvelope`s. | Tri-Fusion mutations should preserve deterministic ordering through this path. |
| `agent_core/src/scope_rex/answer_packet.rs:84` | `WitnessedStateId`, opaque witnessed-state reference. | Good reference shape for `TriFusionWitness` IDs. |
| `agent_core/src/scope_rex/answer_packet.rs:108` | `MutationEnvelopeId`, stable mutation envelope reference. | Tri-Fusion should emit or link this ID per mutation. |
| `agent_core/src/scope_rex/answer_packet.rs:247` | `AnswerPacket`, SCOPE-Rex answer envelope. | Future model responses can cite Tri-Fusion mutation witnesses. |
| `agent_core/src/scope_rex/btm_semantic.rs:166` | `ClaimGraphState`, current claim graph state. | Required provenance hook target for content mutations. |
| `agent_core/src/scope_rex/witnessed_state.rs:67` | `WitnessedState`, materialized snapshot. | Conceptual precedent for `TriFusionDocument` state/witness pairing. |

### 12.3 FFI Gap

There is no current `#[uniffi::export]` function or UniFFI object that can:

- Create a `TriFusionDocument` from Markdown, JSON, or HTML.
- Return an opaque document handle to Swift.
- Apply a typed content mutation to a handle.
- Return a `TriFusionWitness`.
- Attach a mutation to `MutationEnvelope`, `ClaimGraphState`, `ClaimLedger`, `ReplayBundle`, and Cognitive DAG in one deterministic path.

The future FFI should avoid starting as a pile of unrelated JSON string helpers. The bridge can still provide JSON convenience wrappers, but the canonical surface should be an owned Rust document object with explicit lifecycle, mutation, serialization, and witness calls.

## 13. Iteration 5 Addendum - LocalAgent And Editor Mutation Boundary Audit

This slice applied the §5.0 reconciliation gate to the model-facing prompt/grammar boundary and the Epdoc editor bridge. The current path is snapshot-and-command oriented. It does not yet expose the requested Tri-Fusion structured mutation ABI (`insert-block`, `mutate-block`, `link-block`, `transclude-block`).

### 13.1 Reconciliation Evidence

| Area | Evidence | Current fact |
|---|---|---|
| File inventory | `wc -l` reports `LocalAgentPromptBuilder.swift` 207 LOC, `LocalToolGrammar.swift` 208 LOC, `EpdocEditorBridge.swift` 712 LOC, `EpdocEditorChromeView.swift` 928 LOC, `inbound.ts` 360 LOC, `outbound.ts` 200 LOC, `markdown-paste.ts` 459 LOC. | The boundary is split across Swift prompt/grammar, Swift WKWebView bridge, and JS Tiptap command surface. |
| History | `git log --follow` shows `LocalToolGrammar.swift` was last materially touched by `09de1aaa3 Seal V2 tool grammar migration`; `EpdocEditorBridge.swift` by `43894a0db fix(epdoc): avoid Swift 6 URL scheme race warning`; `js-editor/src/bridge/inbound.ts` by `31e78cafe Fix epdoc heading command scoping`. | These are existing V2 tool-call and Epdoc command layers, not Tri-Fusion-specific work. |
| Negative grep | `rg "TriFusion|Tri-Fusion|insert-block|mutate-block|link-block|transclude-block"` across the audited Swift/JS files returns no implementation hits. | The mutation ABI does not exist in the prompt, grammar, Swift bridge, or JS receiver. |

### 13.2 LocalAgent Prompt And Grammar Anchors

| Anchor | Current custody | Tri-Fusion implication |
|---|---|---|
| `Epistemos/LocalAgent/LocalAgentPromptBuilder.swift:58` | System prompt declares function-calling over `<tools>` XML. | Tri-Fusion mutations are not introduced as a first-class response contract. |
| `Epistemos/LocalAgent/LocalAgentPromptBuilder.swift:63` | Tool call shape is `{name, arguments}` inside `<tool_call>`. | Mutations can fit as a tool call only if a registered tool schema exists; no native mutation grammar exists today. |
| `Epistemos/LocalAgent/LocalAgentPromptBuilder.swift:82` | Vault note lookup is Markdown path based. | Model instructions still assume note files, not block-addressable Tri-Fusion documents. |
| `Epistemos/LocalAgent/LocalAgentPromptBuilder.swift:83` | Vault note writes use `vault.write` with a `.md` path and full markdown content. | Current model write path encourages full-document markdown replacement, not structured block mutations. |
| `Epistemos/LocalAgent/LocalToolGrammar.swift:58` | Tool definitions are canonicalized before grammar construction. | Tri-Fusion must enter through the canonical tool-definition registry or a parallel typed mutation grammar with explicit priority. |
| `Epistemos/LocalAgent/LocalToolGrammar.swift:81` | MLXStructured path is triggered by `<tool_call>`. | Structured masking can constrain mutation arguments after a schema exists. |
| `Epistemos/LocalAgent/LocalToolGrammar.swift:115` | Missing structured libraries fall back to soft guidance. | Tri-Fusion cannot rely solely on MLXStructured; the soft path must still state the mutation ABI precisely. |

### 13.3 Epdoc Swift And JS Receiver Anchors

| Anchor | Current custody | Tri-Fusion implication |
|---|---|---|
| `Epistemos/Engine/EpdocEditorBridge.swift:393` | `EpdocBridgeMessage` covers JS-to-Swift snapshots, stats, readiness, menus, and image asset storage. | No JS-to-Swift mutation result/witness message exists. |
| `Epistemos/Engine/EpdocEditorBridge.swift:438` | `contentDidChange` decodes stringified ProseMirror JSON into `Data`. | The save path sees full snapshots, not typed deltas. |
| `Epistemos/Engine/EpdocEditorBridge.swift:541` | `EpdocEditorCommand` is Swift-to-JS command vocabulary. | This is the right enum to extend with a structured mutation command. |
| `Epistemos/Engine/EpdocEditorBridge.swift:544` | `setContent(json:)` replaces the whole editor body. | Snapshot restore exists; targeted mutation does not. |
| `Epistemos/Engine/EpdocEditorBridge.swift:557` | `insertSlashChoice(blockType:)` dispatches local block menu commands. | The existing block insertion path is UI-choice oriented, not model-authored mutation oriented. |
| `Epistemos/Engine/EpdocEditorBridge.swift:563` | `runCommand(name:argsJSON:)` invokes arbitrary Tiptap command names. | Generic commands are too unconstrained to be the canonical model mutation ABI. |
| `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift:272` | Chrome forwards `contentDidChange` JSON to the host and refreshes derived status. | Host save/projection can observe post-facto snapshots but cannot validate mutation intent. |
| `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift:835` | Swift-to-JS commands are batched before `evaluateJavaScript`. | A future mutation command can reuse batching, but must preserve deterministic mutation ordering. |
| `js-editor/src/bridge/inbound.ts:23` | `installInboundCommands` installs `window.epistemos.*`. | JS receiver is centralized enough for a Tri-Fusion entrypoint. |
| `js-editor/src/bridge/inbound.ts:25` | `setContent(json)` parses JSON and calls `editor.commands.setContent`. | JSON snapshot ingestion exists. |
| `js-editor/src/bridge/inbound.ts:52` | `insertSlashChoice(blockType)` applies slash-menu block insertion and posts a snapshot. | A mutation receiver should emit witness metadata in addition to snapshots. |
| `js-editor/src/bridge/inbound.ts:67` | `runCommand(name, ...args)` handles whitelisted special cases before generic Tiptap dispatch. | Generic command dispatch should not become the model mutation path. |
| `js-editor/src/bridge/inbound.ts:297` | `postDocumentSnapshot` emits `contentDidChange` with `JSON.stringify(editor.getJSON())`. | Current outbound contract is full JSON snapshot only. |
| `js-editor/src/bridge/outbound.ts:34` | `ContentDidChangeMessage` marks stringified ProseMirror JSON as canonical `.epdoc` body. | Confirms JSON is the present editor canonical form. |
| `js-editor/src/markdown/markdown-paste.ts:20` | `parseMarkdownPaste(source)` returns `EpdocJSONContent[] | null`. | Markdown enters as one-way parse convenience. |

### 13.4 Mutation ABI Gap

The later implementation should not ask the model to invent `runCommand` names or emit whole Markdown files for Epdoc edits. The minimum safe ABI needs:

1. A LocalAgent prompt clause that names Tri-Fusion mutations as structured operations, with block IDs, document IDs, actor, rationale, and provenance expectation.
2. A `LocalToolGrammar` schema path that constrains `insert-block`, `mutate-block`, `link-block`, and `transclude-block` arguments even when MLXStructured is unavailable.
3. A Swift `EpdocEditorCommand` case for a typed mutation envelope, not only `runCommand`.
4. A JS `window.epistemos.applyTriFusionMutation(...)` receiver that maps allowed mutation variants to deterministic ProseMirror transactions.
5. A JS-to-Swift acknowledgement message carrying `TriFusionWitness` data so Swift can persist model-authored block highlighting and provenance links.

This is the editor-side counterpart to section 12's Rust FFI gap: the content fabric needs a typed mutation spine from model prompt through Swift bridge through JS transaction through Rust witness/provenance, rather than disconnected JSON snapshot helpers.

## 14. Iteration 6 Addendum - EML Boundary Audit

This slice audited `agent_core/src/research/eml/` as a possible Tri-Fusion dependency. The result is a boundary, not a direct content-fabric implementation: EML currently provides a numeric primitive, an expression tree grammar, an evaluator, a ULP oracle, and a schema-freeze gate. It does not parse Markdown, normalize HTML, canonicalize ProseMirror JSON, or address blocks.

### 14.1 Reconciliation Evidence

| Check | Result | Tri-Fusion implication |
|---|---|---|
| File inventory | `wc -l agent_core/src/research/eml/*.rs` reports 1,232 LOC across `mod.rs`, `operator.rs`, `grammar.rs`, `evaluator.rs`, `ulp_oracle.rs`, and `gate.rs`. | EML is self-contained and small enough to use as an optional scoring layer. |
| Test inventory | `rg "#[test]" agent_core/src/research/eml/*.rs | wc -l` reports 74 tests. | Existing coverage is arithmetic/invariant coverage, not document round-trip coverage. |
| History | `git log --follow` shows `operator.rs`, `gate.rs`, and `ulp_oracle.rs` began at `032cf1ca2 feat(research/eml): Phase B.0 F-ULP-Oracle substrate`; later touchpoints include `750fd71f3`, `961951c75`, and `bc1a9cd48`. | This is recent research substrate, not legacy editor plumbing. |
| Negative grep | `rg "TriFusion|markdown|html"` across the module returns no implementation path beyond source comments/tests unrelated to content formats. | EML should not be represented as an existing MD/JSON/HTML bridge. |

### 14.2 EML Source Anchors

| Anchor | Current custody | Tri-Fusion implication |
|---|---|---|
| `agent_core/src/research/eml/mod.rs:1` | Module source comments cite V6.1 and the AnswerPacket schema-freeze gate. | EML's current owner concern is arithmetic trust for claim envelopes. |
| `agent_core/src/research/eml/mod.rs:42` | Hard fence states EML universality only covers the Liouvillian-solvable subdomain. | Tri-Fusion doctrine must not claim EML resolves all content ambiguity. |
| `agent_core/src/research/eml/mod.rs:54` | Public exports are `evaluate`, gate types, `EmlExpr`, `eml`, and ULP oracle types. | No document/block APIs are exported. |
| `agent_core/src/research/eml/operator.rs:19` | `eml(x, y) = exp(x) - ln(y)` with branch-cut and finite-result checks. | Numeric primitive only. |
| `agent_core/src/research/eml/operator.rs:35` | Partial derivative helpers exist for `x` and `y`. | Useful for scoring or optimization, not for document serialization. |
| `agent_core/src/research/eml/operator.rs:59` | Inverse helper solves for `x` from `(z, y)`. | Could support model-side search, not canonical document state. |
| `agent_core/src/research/eml/grammar.rs:10` | `EmlExpr` is a binary term algebra with `One` and `Eml(left, right)`. | If Tri-Fusion carries EML expressions, they must be embedded as block payloads, not conflated with the document grammar. |
| `agent_core/src/research/eml/grammar.rs:23` | Depth/size/leaf/internal-node helpers define tree invariants. | These invariants can become schema constraints for EML-typed blocks. |
| `agent_core/src/research/eml/evaluator.rs:43` | `evaluate(expr)` recursively reduces an `EmlExpr`. | Evaluation is deterministic and bounded, but format-neutral. |
| `agent_core/src/research/eml/evaluator.rs:49` | Evaluator rejects depth beyond `MAX_EVAL_DEPTH`. | Tri-Fusion should preserve this guard when embedding EML blocks. |
| `agent_core/src/research/eml/gate.rs:59` | `check_answer_packet_freeze_allowed()` runs the smoke ULP oracle. | Provenance/claim integration can cite this gate; content mutation should not depend on it unless the mutation emits EML-derived claims. |
| `agent_core/src/research/eml/ulp_oracle.rs:36` | `SMOKE_SAMPLE_COUNT = 1024`. | Unit-loop oracle is intentionally smaller than the production fixture. |
| `agent_core/src/research/eml/ulp_oracle.rs:43` | `UlpToleranceFp16::SHIPPING_BAR = 2.0`. | Any EML block execution witness should record the tolerance bar used. |
| `agent_core/src/research/eml/ulp_oracle.rs:88` | `run_smoke_oracle(...)` returns `UlpOracleReport`. | Witness data can carry oracle reports, but this is separate from MD/JSON/HTML round-trip witnesses. |

### 14.3 Tri-Fusion Use Boundary

EML belongs below or beside Tri-Fusion as an optional verifier/scorer for specific block payloads or ambiguous parse choices. It should not be a canonical format peer. The safe role split is:

1. Tri-Fusion owns document identity, block addressing, MD/JSON/HTML canonicalization, mutations, and provenance witnesses.
2. Hyperdynamic Schemas own block shape validation and schema repair.
3. EML can score ambiguous choices only after Tri-Fusion has already enumerated deterministic candidates.
4. EML can validate or evaluate EML-typed blocks, with depth and ULP witness metadata preserved.
5. EML hard fences must remain visible in doctrine: no "EML for everything" claim belongs in the content fabric.

This resolves `TF-AUDIT-008`: EML is not wired to content ambiguity today, and future wiring should be narrow, explicit, and witness-bearing.

## 15. Iteration 7 Addendum - Hyperdynamic Schema Shape Audit

This slice audited the `hyperdynamic_schemas` data model itself. The current implementation is deterministic and well covered for a scalar, flat-map substrate, but it cannot validate or repair nested Tri-Fusion document structures yet.

### 15.1 Reconciliation Evidence

| Check | Result | Tri-Fusion implication |
|---|---|---|
| File inventory | `wc -l agent_core/src/research/hyperdynamic_schemas/*.rs` reports 1,141 LOC: `repair.rs` 635, `diff.rs` 459, `mod.rs` 47. | The module is compact and focused. |
| Test inventory | `rg "#[test]" agent_core/src/research/hyperdynamic_schemas/*.rs | wc -l` reports 44 tests. | Coverage exists for scalar repair/diff invariants, not block-tree schemas. |
| History | `git log --follow` shows `repair.rs` originated at `146525277 feat(research/hyperdynamic_schemas): J6 - self-repairing schemas`; `diff.rs` originated at `53bc56d35 research/hyperdynamic_schemas: J6 diff sibling`; later classifier/diagnostic commits are `3e92de2c1` and `3e4f2b8c7`. | Current code is an additive research substrate, not editor-era schema code. |
| Negative grep | No `TriFusion`, `Path`, `Object`, `Array`, `Markdown`, or `HTML` implementation exists in the module. | Nested document validation is future work. |

### 15.2 Flat-Shape Source Anchors

| Anchor | Current custody | Tri-Fusion implication |
|---|---|---|
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:7` | Rustdoc explicitly says arrays, nested objects, regex constraints, and enum literals are deferred. | The module self-identifies its own nesting gap. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:11` | `FieldType` is limited to `Integer`, `Float`, `String`, `Bool`, and `Null`. | No block, object, array, mark, relation, or transclusion type exists. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:19` | `Value` mirrors only those scalar arms. | ProseMirror JSON trees cannot be represented directly. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:65` | `FieldSchema` contains `allowed_types` plus a required flag. | Constraints are field-level type unions only. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:101` | `Schema` is `BTreeMap<String, FieldSchema>`. | Deterministic ordering exists, but only for top-level fields. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:236` | `validate_value` accepts a flat `BTreeMap<String, Value>`. | No path-aware validator can address `doc.content[3].attrs.id` or mark arrays. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:275` | `RepairReport` tracks widened types, added optional fields, and downgraded required fields. | Repair witness lacks path, old/new value, actor, and provenance metadata. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:285` | `repair_schema` mutates the flat schema based on validation errors. | This is the right conceptual primitive, but it needs nested path repair and policy-aware witnesses before use in Tri-Fusion. |
| `agent_core/src/research/hyperdynamic_schemas/repair.rs:327` | `Permissive` repair downgrades missing required fields to optional. | Tri-Fusion must never perform this silently for model-authored content. |
| `agent_core/src/research/hyperdynamic_schemas/diff.rs:38` | `SchemaChange` variants are field added/removed, type widened/narrowed, and required flipped. | Diff taxonomy lacks nested path, relation, block kind, or transclusion changes. |
| `agent_core/src/research/hyperdynamic_schemas/diff.rs:143` | `diff_schemas` walks two schemas by sorted field name. | Deterministic ordering is good; path-sorted traversal should preserve it. |
| `agent_core/src/research/hyperdynamic_schemas/diff.rs:177` | Type-set differences become widened/narrowed changes. | This can generalize to nested node schemas, but it is not there yet. |
| `agent_core/src/research/hyperdynamic_schemas/diff.rs:199` | Required flag changes are emitted as `RequiredFlipped`. | Required/optional semantics need path and block-kind scope. |

### 15.3 Required Growth For Tri-Fusion

The minimum extension path is:

1. Add nested value/schema types: objects, arrays, literals/enums, and ProseMirror-like node constraints.
2. Add stable path addressing with deterministic sort order for fields, array indices, block IDs, marks, and relation edges.
3. Add validation errors that carry paths and actual nested value summaries.
4. Add repair reports that are witness-ready: before/after schema, repair policy, actor, reason, and path-level changes.
5. Add diff changes that can represent block schema additions, relation/transclusion constraints, and safe/breaking path changes.
6. Keep scalar `repair.rs` behavior as the substrate floor; layer nested support without breaking existing tests.

Until these exist, Hyperdynamic Schemas can validate simple block payload metadata, but not the full Tri-Fusion document fabric.
