# ProShell Skills Index

## proshell-subprocess-env-hardening

- Path: `.claude/skills/proshell-subprocess-env-hardening/SKILL.md`
- Class: Pro/OpenChamber child-process launch hardening.
- Use for: ProAgent, Goose, Work, or ActGoose seams that spawn children, construct subprocess environments, bridge provider credentials, bind loopback ports, supervise web/agent runtimes, or clean up crash/zombie/orphan process state.
- Cycle breakthrough: ProAgent child environment now matches and tightens the Goose hardening posture by bounding inherited values, rejecting NUL bytes, requiring absolute path-like values, capping/deduping PATH entries, and preserving user-tool path support without leaking broad inherited env.
- Next leverage: apply this method to the next Pro runtime seam before adding any new child process, auth proxy, or runtime health route.

## proshell-work-runtime-env-boundary

- Path: `.claude/skills/proshell-work-runtime-env-boundary/SKILL.md`
- Class: Work/OpenCode child-process environment and loopback-auth boundary hardening.
- Use for: Work runtime, OpenCode, OpenGUI, OpenWork, or adjacent ProShell seams that launch bundled child runtimes, pass loopback credentials, rebuild PATH, or sanitize inherited process environments.
- Cycle breakthrough: WorkRuntimeSupervisor now drops hostile inherited env values and stale auth before injecting fresh per-launch OpenCode basic-auth credentials into the managed runtime.
- Next leverage: apply the same Work-specific env helper to the remaining Work OpenGUI/OpenWork subprocess launchers before expanding their bridge surface.

## proshell-prompt-forge-review

- Path: `.claude/skills/proshell-prompt-forge-review/SKILL.md`
- Class: Visible prompt-upgrade and system-prompt pattern-library flows.
- Use for: shared Prompt Forge APIs, System Prompt Forge, authored Pattern Library seeds, composer review UX, app/vault context grounding, and pre-send prompt transformation guardrails.
- Cycle breakthrough: Prompt Forge now has a shared deterministic core, System Prompt Forge has authored pattern layering, and the Work composer shows a native review before upgraded prompts reach the engine or queue.
- Next leverage: expose the same core to OpenChamber's hosted SPA through an allowed host bridge or native overlay without editing donor web code.

## proshell-runtime-skill-visibility

- Path: `.claude/skills/proshell-runtime-skill-visibility/SKILL.md`
- Class: ProShell runtime-visible skill inventory and user-facing skill-library surfacing.
- Use for: Work/OpenCode, Goose/OpenChamber, or shared-shell surfaces that need to show which user skills the running agent can actually see without editing the protected Vault/Rust skill kernel.
- Cycle breakthrough: Work now exposes a safe read-only inventory of provisioned `.opencode/skills` manifests and renders the runtime-visible skills in the native engines panel.
- Next leverage: connect the same inventory shape to Goose ACP skill injection/outcome recording once the protected kernel exposes the missing evolution wires.

## proshell-work-context-grounding

- Path: `.claude/skills/proshell-work-context-grounding/SKILL.md`
- Class: Work-owned app-context grounding for Prompt Forge and native MCP tools.
- Use for: Work context snapshots, Prompt Forge context rows, native MCP context tooling, and safe propagation of runtime-visible capabilities into agent prompts.
- Cycle breakthrough: Work context snapshots now include bounded runtime skill identifiers, so Prompt Forge and the native context tool can ground prompts in the skills the running Work agent can actually see.
- Next leverage: add confidence/availability rows for other already-proven runtime capabilities without importing protected graph/note/app state.
