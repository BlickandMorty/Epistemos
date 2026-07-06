# Handoff Cards — RECKONER Cross-Plan Seams
ID: EPI-RP-09-RECKONER · Codename: RECKONER
One card per seam. Owner side / other side / message contract / gating.

**Card 1 — RECKONER ↔ EPI-RP-02-LUMENLENS (lens host, epoch, suggestions, serializer).**
RECKONER owns: the .dataset mode host, the grid epoch extension, TabularSuggestion production, the datasetEmbed node. LUMENLENS owns: NoteWorkspaceMode/NoteDetailWorkspaceView, loadEpoch/suppression/filterTransaction, the suggestion schema + ledger + retention, serializer Tiers A/B/C + minimal-diff writeback. Contract: RECKONER adds one enum case and registers a host; embeds register into Tier B through the existing registry; suggestions append in the locked shape. Gating: none platform-specific; suppression during load is mandatory.

**Card 2 — RECKONER ↔ EPI-RP-05-KINDRED (presence, run-state, approval).**
RECKONER owns: emitting activity ("cleaning column C") and routing destructive ops. KINDRED owns: the presence CRDT (clock-guarded, coalesced), the run-state enum, the mascot binding, the ApprovalGate boundary. Contract: RECKONER publishes onto the existing bus with existing states; every destructive DatasetTool crosses the ApprovalGate before staging. Gating: presence is 1Code-only via KINDRED_ENABLED; MAS compiles it out; June runs the identical tools bare.

**Card 3 — RECKONER ↔ EPI-RP-07-KEELSTONE (vault truth, sync, watcher).**
RECKONER owns: the artifact formats (CSV truth / XLSX-.icalc workbook truth / .dataset.md companion), row-level writeback, the promotion rule (OQ-8). KEELSTONE owns: file storage, sync/move semantics, the watcher, merge on external change. Contract: durable writes go to vault artifacts through sanctioned vault I/O; external move/delete surfaces as embedInvalidated + relink, never a crash; GRDB never becomes authoritative. Gating: no subprocess on MAS.

**Card 4 — RECKONER ↔ knowledge graph.**
RECKONER owns: creating dataset nodes and dataset↔note-that-embeds-it↔entity edges. Graph owns: everything internal. Contract: public graph API only. Gating: none.

**Card 5 — RECKONER ↔ provenance ledger (F5).**
RECKONER owns: appending every agent tabular op and every chart's dataset+range provenance pointer; reading for accept-state and press-mascot views. Ledger owns: storage, replay, checkpoint+tail retention (tabular-tuned caps pending Phase-7 bench). Contract: records in the locked shape; chart provenance written before the chart exists — no orphan charts. Gating: none.

---

## CARD AMENDMENTS (2026-07-06 audit)
**Card 2 (KINDRED):** RECKONER's promises need contract ADDITIONS on the KINDRED side, now issued
as K-AMEND 11 — a Data-tab Surface variant, a datasetId slot in Location, and a live `detail`
field (else "cleaning column C" has no wire slot). Emit target = the SWIFT presence hub
(CompanionState), not agent_core, per KINDRED's binding amendment.
**Card 3 (KEELSTONE):** the duties this card assigns were NOT performable by KEELSTONE as specced —
its reconciler indexed only .md/.json. The KEELSTONE addendum (its plan §15.10 + prompt item) now
adds: extensible artifact routes (csv/xlsx/icalc → dataset re-derive; *.dataset.md → companion
parser, not the note indexer), conflict DELEGATION (KEELSTONE detects+routes, RECKONER resolves),
and gate-soak extensions. Durable writes: splice-in-memory → AtomicVaultWriter (Data overload for
binary); Rust returns bytes, Swift writes.
