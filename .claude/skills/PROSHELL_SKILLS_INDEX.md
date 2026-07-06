# ProShell Skills Index

## proshell-subprocess-env-hardening

- Path: `.claude/skills/proshell-subprocess-env-hardening/SKILL.md`
- Class: Pro/OpenChamber child-process launch hardening.
- Use for: ProAgent, Goose, Work, or ActGoose seams that spawn children, construct subprocess environments, bridge provider credentials, bind loopback ports, supervise web/agent runtimes, or clean up crash/zombie/orphan process state.
- Cycle breakthrough: ProAgent child environment now matches and tightens the Goose hardening posture by bounding inherited values, rejecting NUL bytes, requiring absolute path-like values, capping/deduping PATH entries, and preserving user-tool path support without leaking broad inherited env.
- Next leverage: apply this method to the next Pro runtime seam before adding any new child process, auth proxy, or runtime health route.
