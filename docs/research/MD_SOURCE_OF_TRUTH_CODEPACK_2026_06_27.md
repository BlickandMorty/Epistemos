# JSON↔Markdown Source-of-Truth Code Pack (Pass 8, 2026-06-27)

> Resolves **OPEN QUESTION #1** from the Tolaria-supersede loop (`TOLARIA_SUPERSEDE_RESEARCH_2026_06_27.md` Pass 5 / `EDITOR_CANONICAL_PLAN_2026_06_27.md` §0 Q1): Epdoc stores ProseMirror JSON in `.epdoc` packages today; the locked direction is markdown-as-truth; the `@tiptap/markdown` serializer is UNBUILT. This pack is the two-sided buildable plan to close that fork — **8a** = JS/ProseMirror serializer half, **8b** = Swift persistence/write-through half. Both grounded in real files (paths cited inline).

## ★ TOP-LEVEL FINDINGS (read these before the code)

1. **The JS bundle is webpack 5, NOT esbuild.** `js-editor/webpack.config.js` + `ts-loader`; `package.json "build": "webpack --mode production"`. (CLAUDE.md says "esbuild" — stale. `build-tiptap-bundle.sh` already drives webpack; no script change for a new dep, only the lock-hash `npm ci` re-run.)
2. **TipTap is pinned at `3.24.0`, not 3.27.x.** Pin `@tiptap/markdown` to `3.24.0` to avoid a duplicate-ProseMirror / schema-mismatch hazard against `@tiptap/pm@3.24.0`. (Confirm `@tiptap/markdown@3.24.0` resolves on npm before committing the lock — agent was offline.)
3. **The Swift projector and the JS paste parser DISAGREE on the on-disk grammar** for 3 constructs — they do NOT round-trip today:
   | Construct | Swift `ProseMirrorMarkdownProjector.swift` emits | JS `markdown-paste.ts` reads | Round-trips? |
   |---|---|---|---|
   | Callout | `:::info … :::` (`:284`) | `> [!INFO] …` Obsidian (`:277`) | ❌ |
   | Chart | ` ```epdoc-chart ` (`:336`) | ` ```chart `/` ```json `+`isChartSpec` (`:178`) | ❌ |
   | Wikilink | not handled (raw `link` mark) | `[[t]]` ⇄ `epistemos-doc:wiki/<t>` (`:390`) | ❌ |
   **Decision needed (this IS open-Q1's core):** pick ONE grammar. **Recommendation = the JS/Obsidian grammar** (`> [!KIND]`, ` ```chart `, `[[wikilink]]`): it's the vault-native form, already has a working *reader*, and `[[wikilink]]` is what the unified graph already indexes. The JS serializer becomes the **single canonical doc→md authority**; `ProseMirrorMarkdownProjector.swift` is demoted to the lossy `shadow.md`/FTS view it already declares itself to be (`:16-32`).
4. **There are TWO persistence worlds, and only one is the `.epdoc` world.** **World A** (Epdoc `.epdoc` packages) = ProseMirror JSON-in-package is canonical; `shadow.md` is a lossy in-package projection; vault `.md` write-through does NOT happen. **World B** (Prose/TK2 notes) = ALREADY `.md`-on-disk canonical, with a content-hash + `F_FULLFSYNC` atomic writer + reload-suppression notification spine you can REUSE. The flip is cheaper than the docs imply because World A's GRDB/SwiftData/shadow.md layers already treat themselves as caches, and World B already solved atomic-write + self-write-suppression.
5. **There is no `update_note` tool.** The real Goose vault-write seam is **`edit_note`** (`omega-mcp/src/vault.rs:509`, in-app twin `VaultNoteEditor`/`AgentNoteEdit` `VaultNoteEditor.swift:36-79`) — it already writes plain `.md` to the vault. That's the *post-serializer* target.
6. **Doc-vs-code DRIFT flagged:** `SDPage.swift:7-9,50` says "SwiftData is source of truth / `.md` is secondary export" — contradicts §16's "filesystem wins." The Prose `body` field is cleared after save (`:29`), so disk is effectively canonical; the comment is stale.

---

### Pass 8a — JSON↔markdown serializer code pack (JS/ProseMirror half)

**Provenance:** grounded in `js-editor/package.json`, `webpack.config.js`, `build-tiptap-bundle.sh`, `src/index.ts`, `src/bridge/{outbound,inbound}.ts`, `src/types/webkit.d.ts`, `src/markdown/markdown-paste.ts`, `src/graph/document-graph.ts`, and the five custom-node files (`callout-node.ts`, `chart-node.ts`, `image-node.ts`, `code-block-node.ts`, `legacy-diagram-node.ts`). Cross-checked vs `Epistemos/Models/ProseMirrorMarkdownProjector.swift`.

#### 1. Dependency + bundle wiring
`js-editor/package.json` — add `"@tiptap/markdown": "3.24.0"` (alphabetical, between `extension-unique-id` and `extensions`). No `marked`/`markdown-it` direct dep (`@tiptap/markdown` vendors its own parser). No `webpack.config.js` change — `src/index.ts` (the `editor` entry at `:56`) tree-shakes it like every other `@tiptap/*`. Only build action = the existing lock-hash gate re-runs `npm ci` once.

`src/index.ts` — `import { Markdown } from '@tiptap/markdown'` (~`:35`); register in the `extensions` array AFTER all custom nodes (so the serializer sees the full schema), with:
```ts
Markdown.configure({
  html: false, tightLists: true, bulletListMarker: '-',
  linkify: false, breaks: false,
  transformPastedText: false, transformCopiedText: false, // paste already owned by markdown-paste.ts — DO NOT double-handle
}),
EpdocMarkdownCustomNodes,   // §2 hook bundle
```
The explicit `transformPastedText:false` is critical — `pasteClassifierBridge()` + `epdocMarkdownInputRules()` (`index.ts:48,166`) already own paste; double-parsing corrupts callouts.

#### 2. Per-custom-node serializers/parsers
New file `js-editor/src/markdown/epdoc-markdown-nodes.ts` registering `@tiptap/markdown` storage hooks (keyed by PM node name) — NOT `marked` tokenizers (that framing doesn't apply to this bundle). Canonical grammar = symmetric with `markdown-paste.ts` (the existing reader) so paste→serialize→reparse is a fixed point:
- **callout** (`callout-node.ts`, attrs.kind, `block+`) ⇄ `> [!KIND]\n> body` (mirrors `markdown-paste.ts parseQuoteOrCallout :263`).
- **epdocChart** (`chart-node.ts`, text JSON) ⇄ ` ```chart ` fence (reader `:178`). **Export `isChartSpec` from `markdown-paste.ts:432`** (one-word `export`) so writer + parser share one predicate.
- **mermaid** (`legacy-diagram-node.ts`) ⇄ ` ```mermaid `.
- **epdocImage** (`image-node.ts`, atom) ⇄ `![alt](src "title")` with escaping.
- **codeBlock** (`code-block-node.ts`, CodeBlockLowlight) ⇄ fenced, **fence-bump fix for the ``` bug**: fence length = `max(3, longest-inner-backtick-run + 1)`.
- **wikilink** = a `link` mark with `href = epistemos-doc:wiki/<t>` ⇄ `[[t]]` / `[[t|label]]`. **Recommended impl = a post-serialize regex pass** (`/\[([^\]]+)\]\(epistemos-doc:wiki\/([^)]+)\)/g` → `[[…]]`) rather than fragile open/close mark hooks — it's the exact inverse of `markdown-paste.ts:390`.
- **frontmatter** = a leading `codeBlock{language:'yaml'}` whose text is `---…---` (built `inbound.ts:308`, detected `:318`). **Anti-corruption guard:** serialize it RAW (no ``` fence, no escaping) ONLY at doc position 0; a mid-doc `---` is a `horizontalRule`. This is precisely the community-`tiptap-markdown` failure mode to avoid.
- **unknown HTML / unmodeled nodes:** `html:false` → emitted as literal escaped text; register a `defaultSerializer` that writes `node.textContent` verbatim (matches the Swift projector `default:` `:351`) so content is never silently dropped.

#### 3. Round-trip contract + fidelity harness
Fixed-point law: `serialize(parse(M)) ≡ normalize(M)` and `parse(serialize(D)) ≡ D` (strip `UniqueId` `attrs.id` before PM comparison — `index.ts:122` injects them; they're not in markdown). Pre-empt the 3 known TipTap bugs: **#7269** newline-doubling (`breaks:false` + `closeBlock` not manual `\n\n`), **#7353** ordered-list `start` (override `orderedList` to honor `node.attrs.start`), **#7731** table-cell `<br>` (convert in-cell `hardBreak`↔`<br>`, lossless — diverges from the Swift lossy cell-flatten `:374`). New `src/markdown/__tests__/roundtrip.test.ts` with fixtures: frontmatter / callout / wikilink / table-with-`<br>` / nested-code-fence / ordered-start / newline-doubling / chart; plus explicit guards (`!/\n{3,}/`, `^3\. `, `!/```/` on frontmatter). Wire `check:markdown-roundtrip` into `package.json scripts` next to the existing `check:markdown-paste` (the project already gates markdown this way, `package.json:8-13`).

#### 4. Bridge surface
Two new **inbound** commands on `window.epistemos` (`inbound.ts:23`, typed in `webkit.d.ts:34`): `getMarkdown(): string` (doc→canonical md via §2 serializer, read by Swift's `evaluateJavaScript` completion handler) and `setMarkdown(md): void` (vault md→doc via §2 parser → `editor.commands.setContent(json, {emitUpdate:false})` + `markHostDocumentLoaded()`). One new **outbound** message `markdownDidChange {markdown}` on the AP1 coalescing batcher (`outbound.ts:102`), emitted alongside `contentDidChange` in `scheduleContentDidChange` (`index.ts:84`) so the migration is reversible (Swift reads whichever it trusts). Naming mirrors existing `setContent`/`contentDidChange` vocabulary. Swift host must add the matching `EpdocBridgeMessage` case + `EpdocEditorCommand.get/setMarkdown` in `Epistemos/Engine/EpdocEditorBridge.swift` [INFERRED — file not read].

#### Divergences flagged vs `ProseMirrorMarkdownProjector.swift`
callout (`> [!KIND]` vs `:::kind`), chart (` ```chart ` vs ` ```epdoc-chart `), wikilink (added vs absent), tables (lossless vs lossy), and the **role flip** (projector self-declares "DERIVED, never canonical" `:16-32` → open-Q1 inverts this: JS serializer becomes canonical, Swift projector keeps only the lossy shadow/FTS job). Call this inversion out in the PR.

---

### Pass 8b — JSON↔markdown source-of-truth: Swift write-through code pack

#### 1. Verified current persistence map
**World A (`.epdoc`, this pass's target):** `NSDocument` package (`EpdocDocument.swift:57`), `autosavesInPlace`/`preservesVersions` (`:108-120`). Canonical = `content.pm.json` ProseMirror JSON; `contentHash` is SHA-256 over those bytes (`:201-202,256-259`). `projections/shadow.md` = lossy one-way GFM, regenerated every save (`:236-238`; projector `:9-17`), lives INSIDE the package (never in the vault tree). Save path: TipTap `onUpdate` → `onContentChanged` → 300ms debounce (`EpdocEditorSavePipeline`) → `setContentJSON` + `updateChangeCount` (`:278-281,504-511`) → `fileWrapper(ofType:)` (`:178-250`), synchronous (`canAsynchronouslyWrite=false :139-143`). Epdoc writes NO `SDPage` row — it fires two derived projections off-actor: `projectAndIndexBlocks`→`ReadableBlocksIndex` FTS (`:374-404`) + `projectAndPersistGraph`→graph (`:408-428`). **So GRDB/SwiftData are already derived caches for Epdoc.**

**World B (Prose/TK2, already `.md`-on-disk):** bodies at `<App Support>/Epistemos/note-bodies/<pageId>.md` (`NoteFileStorage.swift:251-253,954-960`) with a BLAKE3 content-hash sidecar + xattr + `F_FULLFSYNC` atomic write + readback (`:807-885`). `SDPage` holds metadata; `body` field cleared after save (`SDPage.swift:29`). **Self-write-suppression already exists:** `pageBodyDidChange` notification (`:1332`) + listeners in `ProseEditorView.swift:278` / `ProseEditorRepresentable2.swift:739`. `HTMLWorkspaceDocument` has NO such pattern (verified zero hits) — World B's is the one to mirror.

**Goose seam:** `edit_note` (`omega-mcp/src/vault.rs:509`, twin `VaultNoteEditor.swift:36-79`) writes plain `.md` to the vault (append/replace_first/insert_after, atomic, honest-fail). The crawler (`ShadowVaultBootstrapper.swift:128-191`) only reads `<vault>/notes/**/*.md` + `<vault>/chats/**/*.json` — has NEVER seen `.epdoc` packages.

#### 2. The flip — staged + reversible (3-state flag)
New `EpdocSourceOfTruthMode` enum read from `EPISTEMOS_MD_SOURCE_OF_TRUTH` (convention matches `InferenceState.swift:639`), default `.jsonOnly`:
- **(a) `.dualWrite` (Phase A, additive/reversible):** keep `content.pm.json` canonical; on each save ALSO write canonical `<vault>/notes/<rel>.md` + YAML frontmatter via a new `writeThroughCanonicalMarkdownIfEnabled` hooked into the existing autosave Task (`:504-511`). Markdown comes from the JS `getMarkdown()` bridge (full-fidelity, NOT the lossy shadow projector); frontmatter built from `EpdocManifest` (`EpdocManifest.swift:97-126`) with Tolaria `_`-system-prop convention; written via World B's proven `NoteFileStorage.writeTextAtomically`. If the serializer isn't proven for this doc → return without writing a degraded `.md` (falsifier gate). Flip OFF = lose nothing.
- **(b) `.markdownCanonical` (Phase B):** `EpdocDocument.read(from:)` (`:147-176`) reads the vault `.md`, re-derives `content.pm.json` as a CACHE via `setMarkdown`/`contentJSON(forMarkdown:)`. Package becomes a projection container, `content.pm.json` byte-rebuildable from disk = "filesystem wins" (`:256`). GRDB/SwiftData already derived → nothing downstream changes.
- **(c) HTML-in-md fallback:** non-round-trippable blocks (mermaid/chart/KaTeX/callout-before-tokenizers) emit raw HTML inside the `.md` (GFM allows it); serializer tags them, `setMarkdown` re-parses. Falsifier must assert these survive before Phase B.

#### 3. Goose `edit_note` consumption (the one switching seam)
New `AgentEpdocNoteWriteSeam.applyAgentEdit` routes by the mode flag: in `.jsonOnly`/`.dualWrite`, apply edits to the DERIVED markdown then re-import to JSON via the bridge (package JSON stays truth); in `.markdownCanonical`, write the `.md` via `VaultNoteEditor` THEN record a self-write in `EpdocSelfWriteLedger` (content-hash) so the file-watcher reload is suppressed (mirrors World B's `pageBodyDidChange` + `ProseEditorView.swift:278`). Without suppression: agent-write→file-change→reload→re-render→autosave→loop.

#### 4. Crawler/index coherence (dual-write)
`ShadowVaultBootstrapper` is idempotent (`docId = vaultRelativePath` stable `:118-126`; delete-then-add `:41-47,110-112`). The in-package `shadow.md` is NOT under `<vault>/notes/` → never crawled → exactly one indexed `.md` per note. `vaultMarkdownURL()` must derive a stable path (mirror `SDPage.subfolder :51`) so dual-write and flip target the SAME file → one stable `docId` across the flip. **No CACHE_VERSION wipe** — additive per-note content-hash deltas only (§16 vs Tolaria's full rebuild).

#### 5. Migration + safety + falsifiers
Invariants: Phase A purely additive (`content.pm.json` never mutated/deleted); Phase B demotes-not-deletes JSON (recovery seed until release-audit sign-off); all vault writes reuse World B's atomic `F_FULLFSYNC`+hash+readback path. **Falsifiers — ANY red blocks the flip to `.markdownCanonical`:** round-trip drops a callout / wikilink+relationship semantics / chart-mermaid-KaTeX HTML-fallback; `getMarkdown∘setMarkdown∘getMarkdown` not idempotent; frontmatter loses a typed prop or `_`-system key; self-write fails to suppress reload (loop reproduced); crawler indexes in-package `shadow.md` or double-indexes. **Gating chain:** Phase A behind `=1` (default OFF); Phase B `=2` allowed only when the JS fidelity harness (8a) is green on the full falsifier corpus AND a Swift round-trip parity test passes. T4 promotion (`ARCHITECTURE_TIER_PROMOTION_CANON`) not just compile.

#### 6. Honesty ledger
[VERIFIED-CODE]: Epdoc JSON-canonical + lossy in-package shadow.md; World B `.md`-on-disk + atomic + reload-notify; `SDPage` drift; `edit_note` is the real tool (no `update_note`); crawler scope; `HTMLWorkspaceDocument` has no suppression; `EPISTEMOS_MD_SOURCE_OF_TRUTH`/`get/setMarkdown` don't exist yet; env-var flag convention. [INFERRED]: all NEW Swift types (`EpdocSourceOfTruthMode`, `EpdocMarkdownSerializerBridge`, `EpdocSelfWriteLedger`, `AgentEpdocNoteWriteSeam`, `EpdocFrontmatter`, `vaultMarkdownURL()`) are proposed; `EpdocEditorBridge.swift` host cases not read.

**Bottom line:** the flip is cheaper than the docs imply — Epdoc's derived layers already self-treat as caches and World B already solved atomic-write + self-write-suppression; the only genuinely missing piece is the proven `@tiptap/markdown` serializer bridge (8a), which is exactly what gates the canonical flip.
