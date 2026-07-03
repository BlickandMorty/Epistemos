# AI-Edit-Instructions Graft + Grammar-Unification Code Pack (Pass 9, 2026-06-27)

> 🟢 **MOSTLY LIVE 2026-07-02.** The AI-edit-instructions + grammar-unification code is engine/backend-layer work, largely unaffected by the OpenChamber UI pivot. Re-anchor ONLY any "Goose-as-surface / reskin / Option 1" reference to: Agent surface = OpenChamber (Pro) / June+goose-in-process (MAS); goose = one engine. Canon: memory `project_ui_base_pivot_openchamber_2026_07_02`.

> Two deepen-pass code packs. **9a** delivers the owner's explicit "study Tolaria down to **system prompts / AI-edit instructions / file+page context tracking** and SUPERSEDE it" goal as CODE (was behavioral-only in Pass 1b/3a). **9b** resolves Pass-8 finding #3 (Swift projector ⟂ JS reader grammar) with concrete diffs + a parity test. Both grounded in real files (paths inline).

---

### Pass 9a — AGENTS.md + AI-edit-instructions graft code pack

**Clean-room** (Tolaria AGPL-3.0): all guidance strings are ORIGINAL Epistemos prose written from the Pass-1b/3a behavioral spec, never copied. ~80% of this is wiring/extension over verified seams; 2 genuine new builds.

#### Ground-truth seam map (`[VERIFIED-CODE]` this pass)
| Behavioral spec | Real Epistemos seam | Status |
|---|---|---|
| AGENTS.md seed/repair/status + shims | none — closest is `WorkSkillsProvisioner` (idempotent non-clobber provisioning) `WorkSkillsProvisioner.swift:13-83` | BUILD |
| Context Snapshot per turn | `WorkAppContextSnapshot` (typed, `clean()`-bounded) `:7-61` + `WorkToolMCPCore.contextSnapshotResult` `:148-151` | EXISTS, extend |
| Thin "current note" preamble | `GooseACPClient.prompt(sessionId:text:)` `GooseACPClient.swift:143-149` | EXISTS, extend |
| "call snapshot before edits" doctrine | MCP descriptor `WorkToolMCPCore.swift:131-141`; tool name `epistemos.context.snapshot` `:16` | EXISTS, reword |
| Per-edit approval gate | `session/request_permission`: `GooseACPRequestPermissionRequest` `GooseACPProtocol.swift:1040-1061` + `respondToPermission` `GooseACPClient.swift:402-407` | EXISTS |
| EditClaim provenance | Swift spine EXISTS: `AgentNoteEditProvenance.envelope`→EventStore `:34-64` wired in `VaultNoteEditor.applyEdits(_:to:provenance:)` `:53-79`. Rust `ClaimLedger.commit_claim` `ledger.rs:589` is **read-only over FFI** (`bridge.rs:3465`) | EXISTS (Swift) / **DRIFT** (Rust) |
| `newSession` carries `mcpServers` | GAP: `GooseACPClient.newSession:74-83` omits it though struct supports it (`GooseACPProtocol.swift:755-768`) | BUILD (1-line) |

#### 1. `VaultAgentsGuideManager` (NEW Swift)
Seeds/repairs/status-tracks one vault-root `AGENTS.md` + `CLAUDE.md`/`GEMINI.md` redirect shims. 5-state model (`managed`/`stale`/`missing`/`broken`/`custom`) — **never clobbers a no-marker (user-authored) file**. Modeled on `WorkSkillsProvisioner`'s idempotent non-clobbering pattern (`:29-45`), atomic-write like `VaultNoteEditor` (`:29`), vault root from `FirstRunBootstrap.defaultVaultURL()` (`:60`). A `<!-- epistemos:agents-guide v3 -->` first-line marker + a body-hash tag distinguish "ours, current" / "ours, stale → repair" / "user's → leave". The guidance BODY (original prose) teaches: filesystem-is-truth; title = first H1 → humanized filename (no `title:` field); category in `type:` frontmatter not folders; relationships = any frontmatter field with `[[wikilinks]]` (forward only, app persists inverse); `_`-prefixed keys are app-managed/hidden; **how to edit** (call `epistemos.context.snapshot` before content-sensitive edits; honest-truncation elision marker → fetch full note before editing the middle; every write is reviewed before it lands → make minimal diffs; never write outside the vault); navigate via `open_note`/`highlight_editor`. Recommended call site = the bootstrap path that already runs `WorkSkillsProvisioner.provisionAll` after `FirstRunBootstrap.bootstrap` [INFERRED exact site].

#### 2. Per-turn preamble builder (NEW) — Decision 12 (MCP-pull primary + thin preamble)
ACP has no system-prompt slot, so the doctrine lives in AGENTS.md + the live MCP snapshot; the per-turn injection is a 1-line `[context] The user is currently on the note "X". Call epistemos.context.snapshot for the live body before any content-sensitive edit.` prepended to the FIRST prompt block only (subsequent blocks rely on the live MCP pull, not re-injection — no token burn, never stale). New `GoosePerTurnPreamble.decorate(userText:snapshot:)` reads only the already-bounded `activeNoteTitle` (`WorkAppContextSnapshot.swift:57-58`). Wired via a new `GooseACPClient.promptNoteAware(...)` convenience that decorates then calls the existing `prompt(sessionId:text:)` unchanged (wire shape still `[.text]`, `:146`). Any note-aware Goose sender (now Plan-1-owned Goose WebView/reskin with Plan-2-provided context plumbing) calls `promptNoteAware(... snapshot: noteContext.snapshot())`; the older native-minichat sender reference is superseded.

#### 3. AI-edit-instruction doctrine as CODE (two code-resident homes)
(a) The AGENTS.md "How to edit" body (§1). (b) The MCP tool **descriptions** at `tools/list` (`WorkToolMCPCore.swift:131-146`) — reword the `epistemos.context.snapshot` descriptor to carry the doctrine ("call BEFORE any content-sensitive edit … if the excerpt shows an elision marker and your edit touches the middle, fetch the full note first"), and add doctrine-bearing descriptors for the 8 vault/UI-steering tools (`vault.search` RRF, `vault.get_note` honest-truncation, `vault.create_note` vault-root-validated, `vault.propose_edit` "REVIEWED before it lands — focused/minimal", `open_note`, `highlight_editor`, `refresh_vault`) appended where `appendContextSnapshotToolIfNeeded` runs (`:46-48,143-146`). Enforces doctrine at the tool boundary, not just in prose.

#### 4. SUPERSEDE deltas (what Tolaria CANNOT do — concrete seams)
- **4.1 Real per-edit approval gate.** Tolaria = git-only after-the-fact. Epistemos = wire `propose_edit` permission prompts to allow_once/allow_always/reject_once/reject_always via new `GooseACPClient.resolveEditApproval(...)` over the EXISTING `session/request_permission` round-trip (`GooseACPProtocol.swift:1040-1066`, `option(for:)` `:1045`). All types verified — wiring, not new protocol.
- **4.2 EditClaim provenance — ⚠️ DRIFT CORRECTION (load-bearing).** Decision 13 / plan §6 say "EditClaim → Rust `ClaimLedger`." **As of this pass that is NOT buildable as written:** the Rust ledger FFI is read-only (`bridge.rs:3465-3499`, no commit export) and Phase 8.E intentionally routes live provenance to the Cognitive DAG (`bridge.rs:3441`). The SHIPPABLE path is the already-built Swift spine: enrich `AgentNoteEditProvenance` → EventStore (via `VaultNoteEditor.applyEdits(_:to:provenance:)` `:53-79`) with a new `EditClaim` metadata struct (agentID/modelID/version/runtimeKind/capabilityTier/confidence/approver/`generatedAtMs` vs `acceptedAtMs` — fields git's 2-identity model can't hold). `claimID` becomes the run identity tying inline-hunk ↔ commit ↔ provenance record. If the owner still wants it in the Rust ledger/DAG, that needs a NEW FFI (`record_edit_claim_json` → `commit_claim` `ledger.rs:589` or DAG dispatch `:646`) **that does not exist today — do not claim it's wired.**
- **4.3 Honest capability gating.** Supervisor already gates `.unavailable` under `#if EPISTEMOS_APP_STORE` (`GooseRuntimeSupervisor.swift:119-123`); `GooseSurfaceAvailability` reports real `runtimeBinary`/`webUIIndex` truth (`:3-9`). `EditClaim.capabilityTier` records "agent" only when the cloud runtime is genuinely present — never fake agent on local (CLAUDE.md).
- **4.4 `newSession` carries `mcpServers` (1-line gap that unlocks §1–3).** Without it the agent can't reach `epistemos.context.snapshot`/`vault.*`, so the whole graft is inert. Add `mcpServers: [JSONValue] = []` param forwarding into `GooseACPNewSessionRequest` (`:760`). ⚠️ `GooseACPClientTests.swift:38` asserts `mcpServers == .array([])` — fix MUST update that test (cross-ref Pass-7b A1).

**Honesty:** [VERIFIED-CODE] all §2/§3/§4.1/§4.2-Swift/§4.4 symbols exist as cited. [INFERRED]/BUILD: `VaultAgentsGuideManager`, exact call site, `vault.*` arg schemas. The one real spec-vs-code divergence = §4.2 provenance-ledger drift.

---

### Pass 9b — Swift projector grammar-unification fix

#### Decision: ALIGN (cheap) — honest finding is "demote-not-required-today, align-for-safety"
**Evidence:** the projector output `shadowMarkdown` is purely FTS-shadow-internal **write-only** bytes that NOTHING reads back, re-parses, exports, or surfaces today. Consumer grep:
- Only producer: `ProseMirrorMarkdownProjector.project(jsonData:)` → `pkgCopy.shadowMarkdown` (`EpdocDocument.swift:236-238`).
- Package (de)serialization only: `EpdocPackage.swift:145-147` writes, `:227,260` reads into the struct field on load — then dropped.
- **Non-write reads of `.shadowMarkdown` across the Swift tree: ZERO.**
- **FTS does NOT consume the projector** — the FTS5 index is fed by a *different* projector, `ReadableBlocksProjector.project(contentJSON:)` reading `contentJSON` directly (`EpdocDocument.swift:384-393`); `ReadableBlocksProjector.swift:38-39` confirms they're disjoint pipelines. **So the grammar divergence has no current effect on search.**
- The in-package `shadow.md` lives under `projections/` and is never crawled (`ShadowVaultBootstrapper` only walks `<vault>/notes/**/*.md`).

→ So **demote-not-align literally suffices for today's `.jsonOnly` code (no live bug).** BUT Pass-8b designates this projector as the **degraded-`.md` fallback** when the JS `getMarkdown()` bridge is unproven for a doc — on that path its grammar WILL reach the JS reader. **Recommendation: ALIGN** (3 tiny diffs + a parity test makes drift permanently impossible), and update the file's comments to stop calling `:::`/`epdoc-chart` canonical (keep the "DERIVED/lossy/shadow" role framing — that's correct; the JS bridge stays the canonical authority per Pass-8b §2a).

#### Concrete diffs (`ProseMirrorMarkdownProjector.swift`)
- **(a) Callout** `:::info` → `> [!INFO]` (`:273-288`): emit `> [!\(kind.uppercased())]\n` + `> `-prefixed body lines; add `calloutKinds = {NOTE,TIP,WARNING,DANGER,INFO}` allowlist (matches reader `markdown-paste.ts:277`), unmodeled kinds degrade to `INFO` (reader-parseable) instead of an Obsidian token the reader flattens.
- **(b) Chart** ` ```epdoc-chart ` → ` ```chart ` (`:332-340`): reader routes `(lang=="chart"||"json") && isChartSpec` → `epdocChart` (`:178`); emitting `chart` makes it re-parse as a chart. Malformed spec falls back to `codeBlock` on both sides (consistent).
- **(c) Wikilink** — ADD the missing case in `applyMarks` link branch (`:501-503`): if `href` has prefix `epistemos-doc:wiki/`, emit `[[target]]` (or `[[target|label]]` when visible text differs) via a new `wikiTarget(fromHref:)` decode helper (exact inverse of the reader's `encodeURIComponent`, `markdown-paste.ts:389-394`). Currently the generic link branch emits `[label](href)` which the reader re-parses as a plain external link, losing the wikilink.
- **(d)** Fix the inline doc-comments (`:9-32,96-97,276,335`) that name the old grammar as canonical.

#### Parity test (un-driftable)
Swift+TS can't share a process, so use **one shared JSON fixture** both suites load: `EpistemosTests/Fixtures/md_grammar_parity.json` with `{pmDoc, expectedMarkdown, expectedReaderNodeType}` per construct (callout/chart/wikilink). New Swift Testing `MdGrammarParityTests` asserts `project(pmDoc) == expectedMarkdown` + targeted checks (`contains("> [!INFO]")` & `!contains(":::")`, etc.); the JS `check:markdown-paste`/Pass-8a roundtrip test adds one assertion that `parseMarkdownPaste(expectedMarkdown)` yields `expectedReaderNodeType`. Because both read the SAME `expectedMarkdown` string, neither grammar can change without turning one suite red. [INFERRED `Bundle.module` resource config — swap loader if the Xcode test bundle differs; the shared-fixture mechanism is the point.]

#### Sequencing — land 9b BEFORE the Pass-8b dual-write flip
For `.jsonOnly` (today) it's a no-op risk-wise (nothing reads the projector). For `.dualWrite`/`.markdownCanonical` the projector's fallback output reaches the JS reader → unaligned grammar silently degrades callouts/charts/wikilinks, which is **exactly a Pass-8b flip-blocking falsifier**. So 9b is a prerequisite of Pass-8b's `=2` gate (and can land in parallel with 8a, which builds the canonical authority; 9b aligns the fallback). Both green before the `.markdownCanonical` flip so "FTS/vault search matches the canonical `.md`" holds regardless of which side produced the bytes.

**Honesty:** [VERIFIED-CODE] zero non-write reads of `shadowMarkdown`; FTS fed by `ReadableBlocksProjector` off `contentJSON` (divergence has no current search effect); the 3 divergences are real at the cited lines; projector self-declares lossy/shadow role. The cheaper literal truth (demote suffices today) is stated plainly; align is recommended for the Pass-8b fallback path + permanent drift-lock. [INFERRED] new symbols proposed not present.
