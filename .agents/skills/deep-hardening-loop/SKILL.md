---
name: deep-hardening-loop
description: Use after any Epistemos implementation plan, feature phase, refactor, UI/UX build, release-risk change, or "done" claim to keep auditing, hardening, researching, testing, intent-checking, and improving until the owner explicitly stops or a real blocker is reached. Also use when the user asks for a forever loop, recursive hardening, exhaustive audit, verification-debt batching, thermonuclear review, deep verification, or no-premature-completion behavior.
---

# Deep Hardening Loop

This repo skill turns apparent completion into the next audit pass. Root instructions decide that the loop must happen; this skill defines how to run it without bloating every Epistemos feature prompt.

## Core Rule

Completion is a transition, not a stopping point. After the stated plan is implemented and its normal done bars pass, enter continuing hardening until the owner explicitly says to stop, the session is redirected, or a real blocker prevents useful progress.

The loop hardens the implemented scope, its seams, tests, evidence, docs, and release risk. It must not casually expand feature scope or absorb unrelated plan work.

## Loop Contract

Each cycle:

1. Re-read `AGENTS.md`, `CLAUDE.md`, the active plan/build prompt, recent owner steers, recent diffs, tests, and evidence ledger.
2. Update the intent checkpoint: owner's verbatim wording or exact excerpt, interpreted intent, hard constraints, non-goals, acceptance checks, contradictions/questions, and next action.
3. State hard constraints, proven done bars, and highest-risk unproven claims.
4. Run semantic local searches for contradictions, stale directives, hidden TODOs, forbidden patterns, brittle seams, and missing tests.
5. Validate current or external facts with targeted web research when packages, APIs, OS behavior, UI libraries, security, release policy, or model/tool behavior could have changed.
6. Select applicable skills/tools and load their instructions before acting.
7. Audit implementation quality with `thermo-nuclear-code-quality-review`.
8. Audit behavior and regressions with narrow checks, then broader checks when shared surfaces are touched. If verification is being batched, update the verification-debt ledger with deferred commands, touched files, risks, expected proof, and checkpoint trigger.
9. For UI/UX work, perform runtime/manual/browser/screenshot checks against the actual target experience.
10. For security, permissions, persistence, networking, model routing, release, or data-loss risk, run the appropriate security/release/threat-model checks before claiming safety.
11. Fix the most important issue found, or record why no safe fix exists yet.
12. Re-read changed regions, inspect the diff, and re-run checks affected by the fix.
13. Write a checkpoint: owner intent, what was read, what changed, what passed, what remains risky, deferred verification debt, and the next hardening target.

Then start the next cycle.

## Epistemos Skill Stack

Use applicable skills, especially `agentic-engineering-protocol`, `thermo-nuclear-code-quality-review`, `Recursive App Audit`, `Epistemos Release Audit`, browser/Playwright/screenshot tooling, note/graph audit skills, and security/threat-model skills. If an obvious skill is skipped, record why.

## Stop Conditions

Stop only when the owner explicitly stops or redirects, a real blocker prevents meaningful progress, or the turn must end for tool/runtime reasons. Leave a checkpoint and the next loop target.

Do not stop merely because tests passed once, a build succeeded, the checklist reached the last phase, or the visual result looks better.
