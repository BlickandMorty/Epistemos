Continue the Epistemos architecture salvage and runtime-hardening loop from
`/Users/jojo/Downloads/Epistemos`.

You are running unattended from `Tools/audits/epistemos_architecture_heartbeat_loop.sh`.
Do not wait for user input unless the work is blocked by a genuinely unsafe
choice. Do one small, high-confidence unit of work, verify it, commit it, and
leave a concise report in your final answer.

Start by reading and obeying:

1. `AGENTS.md`
2. `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
3. `docs/audits/UNFINISHED_ARCHITECTURE_AND_BEST_COMBO_MANIFEST_2026_05_30.md`
4. `docs/audits/ARCHITECTURE_NO_GAP_BUILD_ORDER_2026_05_28.md`
5. `docs/audits/AGENT_MANAGEABLE_ARCHITECTURE_CANON_2026_05_30.md`
6. `docs/audits/ACS_NAMESPACE_RECONCILIATION_2026_05_30.md`
7. `docs/audits/NEXT_SESSION_WORKTREE_SALVAGE_PROMPT_2026_05_30.md`
8. `docs/audits/NAMESPACE_AND_ARCHITECTURE_CLARITY_AUDIT_2026_05_31.md`

Current naming/build lock:

- Epistemos has two distributable builds: MAS and Pro. Research, Vault, Omega,
  heavy runtime, and future substrate work are Pro status bands, not app
  builds.
- Use ProductBuild plus ProStatus/ResidencyStatus in new architecture claims.
- Use ColdStore for Active Cold Storage. Keep AcsAnchor for anchored
  coordinate/provenance. Use SCOPE-Rex/SovereignGate for admission/verdicts.

Hard safety rules:

- Do not touch the paused font/typography bundle unless the user explicitly
  resumes font work. In particular, do not edit, stage, commit, or "fix" the
  dirty font files or missing `ka1.ttf`.
- Do not edit, stage, commit, or "fix"
  `artifacts/lattice-coordinate-explainer/index.html` unless the user
  explicitly resumes lattice explainer artifact work.
- Do not run 70B, 128K, full Metal witness, mmap/SSD stress, live MLX/GGUF
  heavy probes, Xcode/full-app tests, or commands likely to pressure memory.
- Do not delete worktrees, sibling Epistemos folders, `~/Epistemos-RETRO/`,
  `src-tauri/`, or `~/meta-analytical-pfc/`.
- Do not wholesale merge donor branches. Use non-mutating checks first and
  port only one additive, focused hunk/file if it is clearly safe.
- Do not treat files, fixtures, docs rows, health rows, or branch-local code as
  product claims. Preserve WRV: Wired, Reachable, Visible, Verified.
- If a donor would remove stricter current truth-floor fields, skip it and
  record why.
- When mining pasted research, donor docs, papers, or generated syntheses,
  extract only the buildable mechanism. Map it to an existing organ
  (Eidos/VaultRecall, System G, RuntimeRouter, ColdStore, Primitive IR,
  SCOPE-Rex/SovereignGate, AnswerPacket, etc.) and do not mint a new top-level
  architecture name from prose.
- EML is an elementary-function/proof chart inside the Primitive IR stack, not
  UAS, ColdStore, Eidos, RuntimeRouter, or a general product/intelligence proof.

Preferred unattended work order:

1. If the current repo has new uncommitted changes outside the paused font
   bundle, inspect them before editing and avoid clobbering them.
2. Pick one safe current-head surface from the best-combo manifest:
   - T4 unique-value check;
   - T21/Eidos/VaultRecall/PageGather retrieval unification;
   - RuntimeRouter policy behavior;
   - System G guarded route surfaces that do not launch inference;
   - AcsAnchor/UAS pure Rust read surfaces;
   - ResidencyPlan / WeightBlockManifest dry-run guardrails.
3. Prefer verified code over docs. If no code is safe, update the salvage docs
   with exact reasons.
4. Run only lightweight verification:
   - `git diff --check`;
   - focused cargo tests for touched Rust modules only;
   - focused Swift source guards only when Xcode is blocked by the paused font
     bundle.
5. Commit the checkpoint before ending. Do not stage paused font files.

End with: what was inspected, what was changed or skipped, what verification
ran, commit hash, and what the next loop should attempt.
