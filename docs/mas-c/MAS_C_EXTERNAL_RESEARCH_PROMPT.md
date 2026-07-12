# MAS C External Research Prompt

ID: `MAS-C-EXTERNAL-RESEARCH-PROMPT-2026-07-08`

Use this with a cloud research agent that cannot see the local repository. Attach
the MAS C packet files plus the relevant source excerpts listed below.

If you want the cloud agent to recommend exact next prompts or handoff order,
include `MAS_C_HANDOFF_PROMPT_CATALOG.md` even when trimming attachments.

## Files To Attach

Minimum MAS C packet:

- `docs/mas-c/README.md`
- `docs/mas-c/MAS_C_CONTROL.md`
- `docs/mas-c/MAS_C_RESEARCH_ABSORPTION.md`
- `docs/mas-c/MAS_C_TRACEABILITY_MATRIX.md`
- `docs/mas-c/MAS_C_RESEARCH_INTAKE_PROTOCOL.md`
- `docs/mas-c/MAS_C_FEATURE_INDEX.md`
- `docs/mas-c/MAS_C_TERMINOLOGY_CANON.md`
- `docs/mas-c/MAS_C_ANTI_DRIFT_GUARD.md`
- `docs/mas-c/MAS_C_EVIDENCE_PROTOCOL.md`
- `docs/mas-c/MAS_C_MASTER_PLAN.md`
- `docs/mas-c/MAS_C_LOCAL_SOURCE_ANCHORS.md`
- `docs/mas-c/MAS_C_FIRST_PASS_IMPLEMENTATION_QUEUE.md`
- `docs/mas-c/MAS_C_HANDOFF_PROMPT_CATALOG.md`
- `docs/mas-c/MAS_C_FILE_MANIFEST.md`
- `docs/mas-c/MAS_C_RELEASE_EVIDENCE_GATE.md`
- `docs/mas-c/MAS_C_OBJECTIVE_AUDIT.md`
- `docs/mas-c/MAS_C_PACKET_CHANGELOG.md`
- every `docs/mas-c/features/*/PLAN.md`
- every `docs/mas-c/features/*/BUILD_PROMPT.md`

Repo context to attach when available:

- `AGENTS.md`
- `CLAUDE.md`
- `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md`
- `docs/prompts/MASTER_PLAN_INDEX_2026_07_03.md`
- `docs/prompts/INTEGRATION_FABRIC.md`
- `docs/prompts/RESEARCH_PROMPT_STANDARD.md`
- `docs/prompts/MAS_PIVOT_CLOUD_RESEARCH_PROMPT_2026_07_07.md`
- `project.yml`
- `Epistemos/Epistemos-AppStore.entitlements`
- `Epistemos/Resources/PrivacyInfo.xcprivacy`
- relevant code excerpts for June, Epdoc, vault writing, provenance, storage,
  release scripts, and the feature being researched

Attach previous Cursor artifacts when asking for a second opinion:

- `MAS_PIVOT_MINIMAL_PROMPT_PACK_2026_07_07.md`
- `MAS_PIVOT_INTEGRATED_RESEARCH_DOSSIER_2026_07_07.md`

## Prompt To Paste

```text
You are doing deep MAS C research for Epistemos, a Mac App Store-first macOS
app. Treat the attached MAS C docs as the current control packet.

Research goal:
Produce a rigorous, implementation-ready MAS C research dossier that improves
the attached plans without drifting away from them. The product target is one
Mac App Store app with native macOS quality, MAS June as the single agent
surface, in-process agent_core, vault files as truth, append-only provenance,
derived/rebuildable indexes, and App Review-safe behavior.

Non-negotiables:
- MAS only: no Pro, Developer-ID, Experimental, 1Code, OpenChamber, or Kindred
  runtime as active product lanes.
- No terminal/code-exec tools, browser-use Chromium, hidden sidecars, Node
  backend authority, stdio MCP, or subprocess agent runtime in the MAS archive.
- No database or proprietary store may become silent truth unless it proves
  lossless export/reconstruction, rollback, and user-visible vault continuity.
- No source integration may use scraping, paywall bypass, forbidden licenses, or
  unapproved commercial API terms.
- UI guidance must distinguish real native AppKit/SwiftUI shell work from
  bundled WKWebView surface work. Do not call a wrapper or CSS token pass a new
  stack.

Research method:
1. Use primary/official sources first: Apple developer docs, framework docs,
   source repos, license texts, API terms, and current App Store policy.
2. Distinguish observed facts from inference.
3. For every recommendation, name the rejected alternatives and why.
4. Map each feature to F1-F6 from INTEGRATION_FABRIC.md.
5. Search for contradictions inside the attached docs.
6. Identify which claims require local verification because you cannot inspect
   the repo directly.

Required output:
1. Executive thesis: what MAS C should become and why.
2. Cross-plan contradiction table.
3. Revised build order with dependency reasons.
4. Per-feature verdict for Keelstone, MAS June, LumenLens, Reckoner, Epdoc
   Assist, Embercatch, Lodestar, Sync, Capabilities, Sigilry, Release Pruning,
   and Storage Fusion.
5. MAS legality and source-legality matrix.
6. Storage verdict: keep, hybridize, retire, and proprietary-fusion options.
7. Native UI architecture verdict: what should be AppKit/SwiftUI, what can be
   WKWebView, and what must not remain a web reskin.
8. Release evidence gate improvements.
9. Exact suggested edits to the MAS C docs, grouped by file.
10. Open questions and local verification commands.
11. Self-critique with scores 1-5 for groundedness, alternatives, build
    actionability, no fabrication, constraint fidelity, integration depth, and
    novelty. Iterate before finalizing until every score is at least 4.

Be severe. The owner prefers deep, slow, source-grounded research over quick
answers. If a current plan is weak, say so precisely and give a better one.
```
