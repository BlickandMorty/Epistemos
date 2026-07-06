# Experimental Surface — Skills Index (the compounding grimoire)

The forever-loop's crystallized capabilities. Each cycle FORGES a build by composing these,
and CRYSTALLIZES one more. Skills are leverage to build with — never trophies. Any skill no
later cycle invokes is reviewed, merged, or pruned.

| Cycle | Skill | Class it captures | Forged by |
|-------|-------|-------------------|-----------|
| 1 | [`experimental-provenance-writeback`](experimental-provenance-writeback/SKILL.md) | web-UI → native reply-capable `epistemos` handler → Epistemos substrate (vault/graph/provenance), no SwiftUI, no shim edit | the "Save to vault" provenance-write-back build + the read-aloud/selection fusions |
| 2 | [`experimental-vault-context-assembly`](experimental-vault-context-assembly/SKILL.md) | web prompt → native `vault:search-ranked` → app RRF index (tantivy BM25 + usearch HNSW) → ranked, `[[wiki]]`-cited grounded context. **Composes Cycle 1.** | the "Vault" grounding button (RRF-ranked context assembly in the composer) |
| 3 | [`experimental-submission-enhance`](experimental-submission-enhance/SKILL.md) | renderer trigger → tRPC mutation → SDK one-shot small-model transform (**must pass `pathToClaudeCodeExecutable`** or it silently no-ops) → parsed structured result → diff/accept UX. **Composes Cycle 2** (vault grounding). | Prompt Forge (submission-time prompt upgrader) + System Prompt Forge |
| 5 | [`experimental-substrate-verification`](experimental-substrate-verification/SKILL.md) | agent OUTPUT → extract assertions → verify vs the substrate (vault/ClaimLedger/grammar) → honest verdict (never a fake pass). The trust axis (claims). **Composes Cycles 1 + 2.** | vault cite-check (verify [[citations]] against the real vault) |
| 6 | [`experimental-run-provenance`](experimental-run-provenance/SKILL.md) | agent ACTIONS → ordered events → SHA-256 hash chain (tamper-evident) → persist to substrate. The trust axis (actions); makes an opaque run auditable + KB-persisted. **Composes Cycle 1.** | run provenance capture (Provenance button → vault note w/ root hash) |
| 7 | [`experimental-cross-run-discovery`](experimental-cross-run-discovery/SKILL.md) | scan the accumulated substrate (provenance notes) → mine recurring patterns → frequency-gate → surface ONLY proven ones (withhold one-offs). The learning axis (across sessions). **Composes Cycle 6** (run-provenance). | user Skills library — "Learned workflows" (recurring tool sequences) |
| 8 | [`experimental-substrate-repair`](experimental-substrate-repair/SKILL.md) | a verification MISS → nearest VALID substrate entity by cheap explainable similarity → high-confidence suggestion (withhold noise). Detect → repair. **Composes Cycle 5** (verification) **+ Cycle 2** (retrieval). | cite-check "did you mean [[X]]?" repair |

## Next cycles will compose these to build (the raised bar)
- **Cycle 3 crux:** cross-session memory. Swap the Cycle-2 `.notes` retrieval for the
  **graph** (`graph.traverse` / `graph.search_semantic` / the cognitive DAG) so the agent
  recalls "what we decided last time" keyed by concept, not directory — composing
  `experimental-vault-context-assembly` (retrieval round-trip) + `experimental-provenance-writeback`
  (write the decision back). The recall the field's `LIKE`/id-lookup memory cannot do.
- **Also open (Phase E hardening):** the Keychain-prompt storm (set an always-allow ACL on
  the `app.epistemos` provider-slot reads); Codex tool-policy `deny` audit-only → real gate.
