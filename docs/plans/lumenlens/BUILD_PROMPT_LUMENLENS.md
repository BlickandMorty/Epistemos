# BUILD PROMPT — LUMENLENS
ID: EPI-RP-02-LUMENLENS · doubles as a proposal for reviewing agents AND an instruction set for a coding agent (Claude Code)
**READ FIRST: the REPO REALITY ADDENDUM at the bottom binds like the phase list. Research base:**
`../kindred/RESEARCH_DUAL_KINDRED_LUMENLENS_2026_07_06.md`. Spine: `spine/` (audited copies — use these).

## Context you inherit
Stack: Swift 6 + Rust agent_core (UniFFI) + GRDB + WKWebView + Tiptap/ProseMirror + CodeMirror6
+ PDFKit, Apple Silicon. Two builds: MAS (sandboxed, no subprocess, June agent, NO companion)
and 1Code/Experimental (Developer ID, everything). The LUMENLENS_SPINE scaffold carries the
binding contracts; extend those exact files, don't invent parallel ones.

## Coding-agent — build phase by phase (each ends at a witnessable done-bar)
1. **L0 Bridge spine.** Implement `js-editor/src/bridge/document-load-state.ts` fully; wire
   `loadStatePlugin` into the editor; implement `EpdocEditorBridge.loadDocument` epoch bump +
   the brotli scheme handler (decode server-side; a custom scheme does NOT auto-decompress
   Content-Encoding: br; do NOT use the private _registerURLSchemeAsSecure on MAS). Write a test
   that dispatches a transaction stamped with a stale epoch and asserts filterTransaction returns
   false. DO NOT use emitUpdate:false anywhere (cite Tiptap #1715/#4828 in a comment).
   *(→ Addendum 2-3: the scheme+brotli ALREADY EXIST; extend the live load-state module; the
   emitUpdate ban is "never RELY on it" — the pinned loader keeps the flag.)*
2. **L1 Suggestion seam.** Implement `HwcSuggestionAdapter.decorateDispatch` using
   withSuggestChanges; implement `buildSchema` with the block-mark trick; implement accept/reject
   via applySuggestion/revertSuggestion. Keep the SuggestionAdapter interface swappable — the
   NoopSuggestionAdapter must still compile.
3. **L2 Serializer tiers.** Implement Tier A/B/C serializers behind `pickTier`; implement
   `roundTrip` and run it over a 100+ real-vault-file corpus in CI. Frontmatter passes through
   verbatim via `splitFrontmatter`.
4. **L3 Minimal-diff writeback.** Implement `minimalWriteback` using ChangeSet.changedRange;
   expand to block boundaries; assert only changed-block bytes are rewritten.
5. **L4 Session state machine.** Implement `NoteSessionStateMachine` transitions + single-lease
   enforcement (GRDB note_session row) + the diff3 conflict path (v1, not CRDT).
6. **L5 Provenance ledger.** Implement `suggestion_schema.rs` append-only insert + replay() +
   revert_turn().

## Reviewing agents — pressure-test these named assumptions
1. **Fork A:** Fetch src/schema.ts of @handlewithcare/prosemirror-suggest-changes AND
   davefowler/prosemirror-suggestion-mode; confirm the exact mark attrs/toDOM. Is a first-party
   engine justified vs adopting hwc wholesale? Does hwc's numeric-id + our ledger beat davefowler's
   username+data model for our provenance needs?
2. **Fork B:** Independently reproduce or refute the byte-for-byte round-trip claim on a corpus
   including GFM tables, wikilinks, and frontmatter. Measure minimal-diff writeback on a 5 MB doc —
   does it hold the <16 ms budget?
3. **Fork C:** Stress the write-lease handoff with two windows editing one note; does the shared
   source-tagged undo stack reconcile correctly on lens switch?
4. **Fork D:** Confirm current Tiptap v3 setContent/emitUpdate/setEditable semantics against the
   latest release; does the epoch guard fully survive #1715/#4828?
5. **Gating:** Verify the 3-row CI matrix actually FAILS when a Companion symbol leaks into the
   defaults build (add a deliberate leak, confirm red).

## Embedded open-ended research questions for the agents
- Real memory/CPU cost of prosemirror-changeset diffing on multi-MB docs during live streaming?
- Does CodeMirror6 viewport rendering interact badly with Source-lens provenance decorations at
  multi-MB scale?
- Can PDFKit's PDFPageOverlayViewProvider be reconciled with "annotations immutable after save"
  for persistent provenance overlays, or must overlays be re-derived each open?

## Anti-patterns (do not do)
No generic rich-text-editor boilerplate. No invented ProseMirror APIs. No design that loses md
fidelity, clobbers the user on load/edit, builds a shadow editor, or leaks the companion layer
onto MAS. Don't silently override Epdoc-as-default (validate, note trade-offs).

---

## REPO REALITY ADDENDUM (verified against the live repo 2026-07-06 — binds like the phase list)

1. **Gating is ALREADY LANDED** (KEELSTONE `8a1ca87d1`): flags on the Epistemos target's configs,
   absent from AppStore, `AppSurface.swift` `#error` guards live. There is NO root Package.swift —
   SwiftPM traits are inapplicable (`spine/Package.swift.NOT-APPLICABLE`). The CI leak detector is
   a JOB in the EXISTING `.github/workflows/ci.yml` (5 real workflows exist): build
   `Epistemos-AppStore`, then nm/strings-scan the binary for companion symbols
   (`spine/ci-matrix.REFERENCE.yml` has the re-mapped rows).
2. **L0 corrections.** The custom scheme + brotli ALREADY EXIST — `epistemos-doc://`
   (`epdocEditorURLScheme`, EpdocEditorBridge.swift:36) + `decompressBrotli` (:347), guard-tested.
   Never create `epdoc://`. `document-load-state.ts` is a LIVE 14-line boolean gate whose exports
   are guard-pinned (EpdocVisibilitySourceGuardTests:270-277) — LAYER the epoch plugin onto it.
   The pinned loader block legitimately contains `emitUpdate: false`; the ban means never RELY on
   it. Any loader reflow updates the pinned guard test in the same commit.
3. **L2 corrections.** The serializer EXISTS: `@tiptap/markdown` + `epdoc-markdown-nodes.ts`
   renderMarkdown hooks (wikilinks already round-trip `[[target]]`), `editor.getMarkdown()`,
   plus a `check:markdown-roundtrip` script. Tier A/B/C hardens THIS pipeline. Toolchain is
   webpack 5 (not esbuild).
4. **L1 deps.** `prosemirror-changeset` 2.4.1 IS installed; `@handlewithcare/…suggest-changes` is
   NOT — start with `npm add` (reference adapter) or first-party marks per the locked verdict.
5. **L3/L4 KEELSTONE seams (hard order).** The disk write goes through KEELSTONE's
   `AtomicVaultWriter` (whole-buffer atomic; the splice is in-memory). `NoteSessionStateMachine`
   IS KEELSTONE's `ActiveEditorBridge` implementation (seam header on the spine file).
   `note_session` joins the EXISTING per-vault GRDB — never a second DB. **KEELSTONE Phases 0-4
   must be landed first; if they aren't, stop and surface it.** L4 OPENS with the undo decision
   (live code tears down the WKWebView on lens switch): retain-per-session vs documented v1
   undo-loss; amend the bar to the chosen branch.
6. **L5 correction.** `ClaimLedger` is in-memory Phase 1 — copy its existing idiom (`events` Vec +
   `events_since()` + `snapshot()`→ReplayBundle/BLAKE3/FFI). Durable persistence = the GRDB
   editor-domain table per `spine/EditorProvenanceStore.swift` (kept from V1), `claim_id`-linked.
7. **Three spine files are DELTA contracts** (`*.DELTA.swift`) over big live guard-pinned files —
   surgical edits to the live files, never replacements.
8. **Build discipline.** Isolated DerivedData; BUILD SUCCEEDED on BOTH targets per phase; never two
   xcodebuilds at once; pathspec-scoped commits (`git commit --only -- <files>`); never commit
   `.research-clones/`; no worktrees; js-editor changes need `build-tiptap-bundle.sh` restaging.
9. **RECKONER seam:** note tables stay editor-side (Tier B); Data-room datasets are Plan 9's —
   notes reference them via wikilink/embed. Keep L1/L5 span metadata payload-agnostic so Data-cell
   edits can attribute through the same ledger later (plan §P-AMEND 9).
10. **Lens-Fidelity Disclosure (owner-mandated, plan §P-AMEND 10 — folds into L2's done-bar):**
   the Tier classifier doubles as a per-lens fidelity registry (rendered / degraded / invisible +
   preview provider per Tier B/C node type); Prose/Source get a disclosure toggle (extend the
   existing `showInfoPopover` in NoteDetailWorkspaceView) listing every degraded/invisible item
   with a rendered preview + jump-to-Epdoc. Quiet when empty. External types register via the
   same seam (RECKONER embeds first). L2 is not done until the disclosure bar passes on the
   full-corpus doc. **Popovers are ROBUST:** high-quality rendered previews + per-item
   download/export actions (dataset → xlsx/CSV via IronCalc; chart → image; chat tab →
   markdown transcript; quarantine → raw bytes) — working exports are part of the L2 bar.
11. **The Epdoc Notebook (owner-mandated, plan §P-AMEND 11 — new phase L6):** a note hosts tabs
   (body + RECKONER sheet tabs + KINDRED chat tabs + a "+ new tab" launcher pane). You own the
   CONTAINER: the Tier-B tab manifest (references only — dataset/session ids; the `.md` stays
   sole note truth per KEELSTONE 4.5; legible in vim; Fork-B byte-stable), the tab chrome, the
   launcher, tombstone-tab UX for dangling references, and disclosure integration (tabs surface
   through the robust popovers on Prose/Source; chat tabs are 1Code-only — degraded+exportable
   on MAS). Content mounts come from RECKONER (grid, second mount) and KINDRED (K6 minichat) —
   consume their seams by ID; do not build sheet/chat internals. L6 done-bar per the plan.
