# Research-First Protocol Update - 2026-05-02

## Tier

Docs-only / All tiers. No runtime, build, UI, provider-routing, Rust, generated
binding, graph, or editor behavior changed.

## Trigger

The user clarified that the comprehensive research corpus is intentionally the
first source of truth for every concept and task. Codex, Claude, Kimi, and
future builders should search the user's disk canon before coding, then use web
validation only when local guidance is absent or external facts may have moved.

## Decision

Add a research-first protocol to the active canon:

- Search `MASTER_RESEARCH_INDEX_2026_05_02.md` and the named canonical local
  source before any deliberation, build card, refactor, reroute/reduction, bug
  fix, or simple code change.
- Use semantic expansion rather than literal-only matching. Example:
  "zero-copy" expands to UMA, shared Metal buffers, IOSurface, in-process,
  single-binary, no hot-path subprocess, no tensor copies, deterministic
  provenance, direct/bare-metal path, and the user's philosophy: "as complex as
  a brain, as simple as an app, as fast as a jet."
- If local docs do not answer, or if the slice depends on current API, package,
  OS, model, App Store, security, or framework behavior, run a targeted web
  validation pass using primary/official sources where possible.
- Web search validates or updates the local plan; it does not replace the local
  canon.
- Keep searches useful and bounded: read the canonical local source, verify
  against current code/logs, and stop once the slice has enough evidence.

## Files Updated

- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md`
- `docs/fusion/README_START_HERE_2026_04_30.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
