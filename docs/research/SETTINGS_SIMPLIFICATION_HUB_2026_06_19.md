# SETTINGS-SIMPLIFICATION + ROBUSTNESS + INTEGRATION — Research Hub (2026-06-19)

**Why (owner 2026-06-19):** *"robust ways to simplify setup + further settings for ALL the
things I'm adding to my app — and even my app's own settings parts that can be further simplified,
and parts of the other (cloned) settings that can be simplified + made more robust + connect better
with my app in full. Endless research on all these parts — make sure it touches all the things that
will be added / repaired."* GOVERNING BALANCE (from the ledger): **simplify the PRESENTATION +
automate the defaults; preserve ALL the FUNCTIONALITY. Progressive-disclosure (collapsed-but-
reachable) ≠ hiding/deleting. Never amputate.** Feeds the build loop (read after MASTER_SYNTHESIS).

## Methodology — iterative deepen + broaden (rotate each pass)
Each pass: persist completed agents' findings into a slice doc + this hub's findings log + commit;
then advance the next slice (broaden) or deepen a done one. Cross-link new docs into the main hub.

## Slice backlog
| # | Slice | Status |
|---|---|---|
| SS-A | Cloned-app setup/settings simplification + robustness + integration | ✅ done → SS-A_CLONED_APP_SETTINGS_SIMPLIFY |
| SS-B | Epistemos's OWN settings — simplify the sprawl (~80 health rows + S7 duplicate sections), clean IA + progressive-disclosure for diagnostics, robust defaults | ☐ in progress |
| SS-C | SETUP / ONBOARDING flow — first-run + per-feature auto-config for everything added (models/engines/MCP/voice/logos): the "it just works" path | ☐ |
| SS-D | Settings INTEGRATION — one coherent settings model: how clone settings + app settings + new-feature settings (model stack, MCP-install, per-engine sections) cohere + share state | ☐ |
| SS-E | DEFAULTS & AUTOMATION audit — everywhere the app asks the owner to configure something it could derive/default; make it auto | ☐ |
| SS-F | ROBUSTNESS of settings — persistence, honest gating, validation, no-fake, witness; settings that silently fail or don't apply | ☐ |
| SS-G | The MODEL-INSTALL setup specifically (owner's #1 blocker) — the simplest robust click-to-installed path | ☐ |
| SS-H | CROSS-ENGINE native tool/skill SHARING (owner 2026-06-19) — Osaurus/Goose/OpenClaw access the app's native tools+skills via the shared registry; skills/tools/"superpowers" work for BOTH local AND cloud models in chat | ☐ |
| SS-I | EXTERNAL SKILL ECOSYSTEMS (owner 2026-06-19) — Anthropic/Claude Agent-Skills (SKILL.md + anthropics/skills), Vercel (AI-Elements/skills), Google, etc. — what to adopt/clone natively as skill/tool sources for the app + all engines | ☐ |

## FINDINGS LOG (appended each pass)
**SS-A CLONED-APP SETTINGS** → the machinery already ships (`SettingsDisclosureSection` = the literal 'Advanced' container; GateStatus+HealthRow triad; native absorbers ModelStack/Authority/Skills). Pattern = a reusable `EngineSettingsSection` (curated native simple front: model→stack, perms→Authority, skills→Skills, MCP→ONE consolidated panel) + a `… · Advanced` disclosure with the full surface. Per clone: auto-default the plumbing (ports/dirs/keys/sandbox), surface ~3-5 knobs simply, full settings under Advanced. **OpenClaw (33-section config) = reskin its config-form via CSS injection + keep it under `OpenClaw · Advanced` — never hide it (reverses S3).** Top move = consolidate MCP-install into one panel. Full: SS-A doc.
- (SS-B app's-own settings + SS-I external ecosystems still running.)
