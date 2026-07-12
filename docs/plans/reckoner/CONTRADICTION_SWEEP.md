# Contradiction Sweep — RECKONER vs Locked Sibling Decisions
ID: EPI-RP-09-RECKONER · Codename: RECKONER
Cycle-3 coherence pass. Each item: the potential contradiction, verdict, resolution, and the spine file that encodes the fix.

**1. Bridge/epoch model.** A grid load emitting change/autosave would break the locked load-vs-edit invariant. Real risk — resolved: loads run inside GridLoadEpoch with a suppression window; paint-back is re-entry guarded (`paint-back.ts`, `GridBridge.swift`). Phase-2 done-bar witnesses zero events on load.

**2. Suggestion schema fork.** Inventing a tabular provenance schema would fracture the ledger. Resolved after audit amendment: `tabular_suggestion.rs` now follows the locked LUMENLENS shape with typed `Author`, `AcceptState {Pending, Accepted, Rejected}`, `updated_at_ms`, and append-only staged/resolved events; ranges stay A1 as RECKONER's payload form. No parallel schema exists anywhere in the spine.

**3. Presence channel fork.** A separate grid-presence channel would double the truth. Amended by the 2026-07-07 MAS-only pivot: companion presence is parked; MAS-safe status/provenance must derive from real June/agent_core state and invent no new channel.

**4. Gating leak.** Grid presence on MAS would violate the MAS-only rule. Resolution: do not activate Kindred presence; June invokes identical tools with no presence, and the phase bar is zero presence/Kindred symbols in the MAS build.

**5. Vault-truth inversion.** GRDB-as-authority would violate F1. Resolved in cycle 2: CSV (flat) / XLSX-.icalc (workbook) in the vault is truth; GRDB is derived cache (`VaultArtifact.swift`, `DatasetStore.swift` headers state it).

**6. Embed data inlining.** Serializing cell data into notes would break minimal-diff writeback and bloat markdown. Resolved in cycle 2: `dataset-embed.ts` is a Tier-B atom carrying only {datasetId, vaultPath, viewSpec}; round-trip test asserts zero cell data in the note.

**7. Graph internals.** Dataset↔note↔entity edges must not touch graph internals. Resolved: public graph API only; RECKONER's graph adapter is a client, never a peer.

**8. Renderer authority.** Any Univer-computed value reaching persistence would breach the engine canon. Resolved: notExecuteFormula silences the engine (`silent-univer.ts`); the intercept cancels value commits (`edit-intercept.ts`); the residual risk is command-coverage completeness — tracked as OQ-3, not hand-waved.

Verdict: no unresolved contradictions. Items 1, 4, 6, 8 carry witnessable done-bars in the plan; OQ-3 is the one seam where the sweep depends on future enumeration rather than present proof.

---

## SWEEP AUDIT ADDENDUM (2026-07-06 — the audit's findings on this sweep)
Items 1,3,4,6,7,8: CONFIRMED sound. Item 2: PARTIAL — the "no parallel schema" claim was false in
the spine as delivered (typed-Author/accept-state/updated_at_ms drift + no append-only events);
fixed via §R-AMEND 5. Item 5: PARTIAL — the flip itself is right, but the sweep scoped itself to
SIBLING decisions and missed that it contradicts the PARENT canon (§0.5 LOCKED + RESHAPE
"unchanged" lines + registry/index rows); the supersession set now legitimizes it (review §E).
MISSED items, now covered: charts-vs-canon inversion (§R-AMEND 3); dual-zone/defined-names + §2
shape + record-level objects silently dropped (§R-AMEND 10); KEELSTONE B4 pool placement +
indexed-set gap (§R-AMEND 8/11); the packaging seam (§R-AMEND 9).
