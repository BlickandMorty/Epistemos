# MAS C - Standalone MAS Control Pack

ID: `MAS-C-ROOT-2026-07-08`
Status: active MAS-only planning packet

MAS C is a standalone control folder for the Mac App Store pivot. It does not
replace the historical research corpus. It converts the useful parts of the
current MAS research, Cursor packet, and local repo facts into one non-drifting
execution packet.

Read order:

1. `MAS_C_CONTROL.md`
2. `MAS_C_RESEARCH_ABSORPTION.md`
3. `MAS_C_TRACEABILITY_MATRIX.md`
4. `MAS_C_RESEARCH_INTAKE_PROTOCOL.md` when adding new research
5. `MAS_C_FEATURE_INDEX.md`
6. `MAS_C_TERMINOLOGY_CANON.md`
7. `MAS_C_ANTI_DRIFT_GUARD.md`
8. `MAS_C_EVIDENCE_PROTOCOL.md`
9. `MAS_C_MASTER_PLAN.md`
10. `MAS_C_LOCAL_SOURCE_ANCHORS.md`
11. `MAS_C_FIRST_PASS_IMPLEMENTATION_QUEUE.md`
12. `MAS_C_HANDOFF_PROMPT_CATALOG.md`
13. `MAS_C_FILE_MANIFEST.md`
14. `MAS_C_OBJECTIVE_AUDIT.md`
15. `MAS_C_PACKET_CHANGELOG.md`
16. `MAS_C_MASTER_BUILD_PROMPT.md`
17. `MAS_C_RELEASE_EVIDENCE_GATE.md`
18. `MAS_C_EXTERNAL_RESEARCH_PROMPT.md` when using a cloud agent without repo access
19. The specific feature folder under `features/`
20. The matching operational prompt under `prompts/` only when that mode is needed

Source-of-truth posture:

- Active product: `Epistemos-AppStore` only.
- Active agent surface: MAS June through in-process `agent_core`.
- Active storage doctrine: vault files are truth, append-only provenance/op-log is
  durable witness, derived indexes are rebuildable.
- Active UI doctrine: native macOS shell quality first, bundled WKWebView where it
  is the honest best component host, no hidden external runtime.
- Parked lanes: Pro, Developer-ID, Experimental, 1Code, OpenChamber, Kindred
  runtime, terminal/code-exec tools, browser-use Chromium, Node backend, stdio
  MCP, and subprocess agents.

The older plan folders remain provenance. MAS C is the current packet to hand to
agents when the owner wants one coherent App Store build.
