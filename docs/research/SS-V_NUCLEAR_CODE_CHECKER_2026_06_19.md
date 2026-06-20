# SS-V — The Cursor "nuclear" code-checker + a multi-checkpoint adversarial review gate (2026-06-19)

Read-only research (subagent, web + repo grounding). Feeds the AGGRESSIVE-CODE-CHECKER ledger item. Owner:
*"that one skill/tool Cursor had — aggressively checks the code — 'nuclear something' — used multiple times in
the plan as a checkpoint for multiple parts, not overdoing it."*

## Headline / identification
The owner means **Cursor's `thermo-nuclear-code-review` skill** (the "thermos" plugin) — "nuclear something" →
**thermo-nuclear**. **Confidence: HIGH (~90%).** NOT Nuclei (red herring — web/infra DAST, not source review);
Bugbot is the productized hosted sibling (~10% the owner means that). It's actually TWO Cursor skills:
- **`thermo-nuclear-review`** — security & correctness branch audit (bugs, breaking changes, security, devex
  regressions, feature-gate leaks). The "aggressively check the code" one.
- **`thermo-nuclear-code-quality-review`** — strict maintainability audit (1k-line rule, spaghetti conditionals,
  abstraction quality, "code-judo" simplifications).
"Double thermo" launches both in parallel + synthesizes.

## What it does (the "nuclear" essence vs a linter)
An adversarial LLM auditor with a **refute-by-default** posture (not pattern-matching): audits only added/
modified code in a branch diff across bugs/breaking-changes/security/devex/feature-gate-leaks; **full
end-to-end tracing required before reporting** (explicitly forbidden from hand-waving "if the backend handles
X then ok"); reads the PR's own narrative only AFTER its independent audit; **calibrated** (over-reporting
penalized — false positives erode trust); **gatekeeps** (the quality variant blocks even on correct behavior if
a simplification exists or a file crosses 1k lines unjustified). Bugbot/Greptile scale the same idea (whole-repo
index, multi-pass, autofix; Greptile ~82% bug-catch / Bugbot ~58% / CodeRabbit ~44% in one benchmark).

## Epistemos equivalent (Swift 6 + Rust dev-time gate + adversarial LLM pass)
**Build-time/dev-time ONLY — never ships in the notarized app, so the no-runtime-sidecar constraint does NOT
apply; external dev tooling is fine.** Two layers per checkpoint:

**Layer 1 — deterministic static gate (fast, first):**
- `cargo clippy --all-targets -- -D warnings` — *already in `.github/workflows/lint.yml` + `ci.yml`*; **but
  `ci-parallel-branches.yml:76` sets clippy `continue-on-error: true` → that escape hatch MUST be off at a
  nuclear checkpoint.*
- `swiftlint --strict` (*already CLAUDE.md L69*) + `swift-format lint --strict`.
- `cargo audit` (RustSec CVEs) + `cargo deny check` (licenses/bans/advisories) — **NOT yet in repo, add.**
- `semgrep --config auto` + a project Swift+Rust ruleset — **not yet in repo, add.**
- Clang static analyzer on the C/ObjC bridge surface.

**Layer 2 — adversarial LLM bug-hunt (the actual "nuclear" essence):**
Mirror double-thermo with THIS harness's subagents — **2-3 independent skeptics in parallel, refute-by-default,
no shared context**, over the diff/subsystem:
- *Correctness skeptic* — logic errors, races, error-path/`Result`-swallowing, **UniFFI Swift↔Rust FFI
  lifetime/ownership mismatches** (highest-leverage Epistemos-specific surface).
- *Security skeptic* — composes the VULNERABILITY-RESEARCH directive: injection, SSRF, unsafe `.unwrap()`/panic,
  subprocess/exec, **MAS-escape / notarization-sandbox** violations.
- *Quality skeptic* (optional) — 1k-line rule, spaghetti, abstraction leaks.
Then a **synthesizer** dedupes + requires each finding to cite file:line + an end-to-end trace; drops
uncited/un-traced findings (no false-positive tax). Implementable today as a Claude Code skill (`/thermo-nuclear`
or extend the existing `/security-review` + `/code-review`) via the Agent tool with general-purpose/Explore
subagents.

## Multi-checkpoint integration (deliberate milestones, NOT every commit)
Place gates where blast radius is highest:
- **CP-0 — after Phase-0 fixes land:** full Layer 1 + security skeptic.
- **CP-N — before each clone/lift lands:** full Layer 1 + correctness + security skeptics over THAT lift's diff.
- **CP-Δ — after each major subsystem change** (agent runtime, ACS/admission, persistence, UniFFI surface):
  full double-thermo (all skeptics).
- **CP-R — pre-release / pre-notarization:** full Layer 1 (all `continue-on-error` OFF) + double-thermo over the
  whole release delta + a MAS-escape pass.
Wire as a manual/`workflow_dispatch` GitHub Action (`.github/workflows/thermo-nuclear.yml`) so it's invoked at
checkpoints, keeping per-push `lint.yml`/`ci.yml` fast. **(Note: this loop is MAIN-ONLY no-worktree — the gate
runs on main at checkpoints, blocks-on-findings, fixes go through normal plan-conformant edits; no branch/merge.)**

**Gate criteria (block-on-real-findings, adversarially-verified):**
1. Any Layer-1 failure → hard block (clippy `-D warnings`, swiftlint `--strict`, cargo-audit/deny advisory,
   semgrep ERROR).
2. Any Layer-2 finding sev ≥ High surviving the synthesizer's trace+file:line requirement → block until fixed or
   explicitly justified-as-intentional + scope-constrained.
3. Findings without a trace are discarded (no false-positive tax).
4. PLAN authority preserved: the gate only finds + blocks; fixes go through normal edits.

## Ordered plan
1. **[S]** New `thermo-nuclear.yml` `workflow_dispatch` job: add `cargo audit` + `cargo deny check`; reuse
   clippy/swiftlint; flip `ci-parallel-branches.yml:76` clippy `continue-on-error` OFF at checkpoints.
2. **[S]** Add `semgrep --config auto` + a small `/.semgrep/` Swift+Rust ruleset (unsafe-unwrap, subprocess,
   FFI null-deref, injection).
3. **[M]** Author a `/thermo-nuclear` Claude Code skill: parallel correctness + security + (optional) quality
   skeptics → synthesizer with trace/file:line gate; compose the VULNERABILITY-RESEARCH directive; extend
   `/security-review` + `/code-review` rather than rebuild.
4. **[M]** Insert CP-0 / CP-N / CP-Δ / CP-R markers into the mass-plan docs at phase/lift/subsystem/pre-release
   boundaries.
5. **[L]** Tune skeptic prompts on the UniFFI boundary + MAS-escape patterns; calibrate the false-positive
   discard threshold over a few real lifts; optionally evaluate hosted Greptile/Bugbot as a parallel oracle if
   cloud review is ever acceptable.

## Honest uncertainty
~10% the owner means **Bugbot** (Cursor's hosted reviewer, same team/lineage, "aggressive") rather than the
literally-named thermo-nuclear skill — but "nuclear" points strongly to the skill. Compose with SS-S
(vulnerability-audit techniques) — SS-V is the *gate/checkpoint harness*, SS-S is the *technique catalog*.

Sources: Cursor thermo-nuclear skills — github.com/cursor/plugins/blob/main/thermos/skills/thermo-nuclear-review/
SKILL.md + .../cursor-team-kit/skills/thermo-nuclear-code-quality-review/SKILL.md + github.com/cursor/plugins/
tree/main/thermos · cursor.com/bugbot + cursor.com/blog/building-bugbot · greptile.com/benchmarks · semgrep.dev ·
github.com/rustsec/rustsec · github.com/EmbarkStudios/cargo-deny. Repo grounding: clippy `-D warnings` in
`.github/workflows/lint.yml` + `ci.yml`; SwiftLint CLAUDE.md L69; gaps = cargo-audit/cargo-deny/semgrep + the
adversarial skill; `.github/workflows/ci-parallel-branches.yml:76` clippy `continue-on-error: true`.
