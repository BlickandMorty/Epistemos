# Codex / Claude Release Preservation Prompt

Use this prompt verbatim when you want Codex or Claude Code to keep Epistemos release-ready.

---

We are doing a release-preservation pass for Epistemos.

Repo: `/Users/jojo/Downloads/Epistemos`
Current source-of-truth commit should be checked first.

Goals:

1. Keep the app buildable and launchable from a fresh local app bundle.
2. Make sure all required runtime assets and embedded dependencies are really inside the `.app`.
3. Keep the repo, local artifacts, and Git state aligned.
4. Do not drift into unrelated refactors.
5. If you make changes, update the release handoff docs.

Required workflow:

1. Read:
   - `docs/handoffs/2026-03-28-final-claude-release-master-handoff.md`
   - `docs/handoffs/2026-03-28-codex-release-audit-handoff.md`
   - `docs/plans/2026-03-28-zero-corruption-handoff-for-claude.md`
   - `docs/handoffs/2026-03-28-codex-dead-code-cleanup.md`
   - `docs/plans/2026-03-28-distribution-decision-and-compliance-report.md`
2. Run:
   - `./scripts/audit/release_preflight.sh`
3. Verify the produced app bundle contains:
   - `Contents/Frameworks/libepistemos_core.dylib`
   - `Contents/Frameworks/libomega_mcp.dylib`
   - `Contents/Frameworks/libomega_ax.dylib`
   - `Contents/Resources/model_manifest.json`
   - `Contents/Resources/PrivacyInfo.xcprivacy`
   - `Contents/Resources/RetroGaming.ttf`
   - all required `Contents/Resources/KnowledgeFusion/...` runtime files
4. Verify the app bundle does **not** contain stray test-host noise such as unexpected `Contents/PlugIns`.
5. Verify the app bundle passes:
   - `codesign --verify --deep --strict --verbose=4 <app>`
6. If anything is missing, fix the build graph so the real `.app` contains it.
7. If you fix anything, rerun the preflight from scratch.
8. If the tree is clean and verified, update the release handoff docs.
9. If asked to publish, commit intentionally, push, and prepare the release artifacts.

Important nuance:

- For normal local development, keep building in Xcode.
- For repeatable release preservation, do **not** rely only on clicking Run in Xcode; always use `./scripts/audit/release_preflight.sh`.
- For public distribution, the app needs real signing:
  - `Apple Development` for normal signed development flows
  - `Developer ID Application` for direct distribution outside the Mac App Store
  - App Store signing only if shipping through the Mac App Store
- The earlier “The executable is not codesigned” error does **not** mean the project fundamentally needs a provisioning profile just to run locally. It means the specific bundle being launched was not in a valid signed state.

Expected output:

- honest readiness status
- exact commands run
- whether the `.app` is self-contained
- what still blocks public release, if anything
- updated handoff docs if changes were made

