# SS-I — External skill ecosystems (Anthropic / Vercel / Google) (2026-06-19)

Read-only research (subagent), code-grounded + web. Feeds SETTINGS_SIMPLIFICATION_HUB + the
SKILLS-EVERYWHERE ledger item. **Headline: the hard parts already exist — SS-I is WIRE + EXTEND + a
thin import UI, not new infrastructure.**

## Already in place
Epistemos already (a) **speaks the SKILL.md open standard**, (b) has a **quarantine + 40-rule scanner +
ProvenanceGate install pipeline** (`skill_manage`: `install_from_github`/`install_from_url`/`install_from_
local_path` → `quarantine/` → `scan_quarantined_tree` → explicit `approve:true` promote), (c) has the
**MCP universal connector** (stdio servers + URL servers), (d) has the **FineTunePack marketplace template**
(`{id,kind,source,license REQUIRED,gate,provenance}`, license-gated, MAS-safe descriptors).

## SKILL.md format-compat — external packs DROP IN (one small shim)
Open standard (agentskills.io): folder + `SKILL.md` (YAML frontmatter `name`≤64 + `description`≤1024 required;
optional `license`/`compatibility`/`metadata`/`allowed-tools`) + optional `scripts/`/`references/`/`assets/`.
Epistemos `parse_skill`/`parse_frontmatter` read `name`+`description` (+ dir fallback), copy sub-dirs intact in
quarantine, but: only read `metadata.epistemos.{category,tags,requires_tools}` (its nested dialect, ignores
standard top-level `tags`/`author`/`version`), don't honor `allowed-tools` (security), have an Epistemos-only
`triggers` extension (router falls back to TF-IDF on description, so external packs still route). **VERDICT:
an anthropics/skills pack works TODAY for instruction/routing; needs a ~½-day additive frontmatter shim** (read
standard top-level tags/author/version + compatibility/license/allowed-tools). **BLOCKER:** the 4-way skill-dir
path mismatch (S4/S1) means an installed pack (`~/.epistemos/skills`) isn't read by the router (`<vault>/skills/`
+ `.agents/skills/`) → **SS-I depends on Phase-0 #5 (unify the dirs).**

## Per-ecosystem
- **Anthropic Agent Skills = the PRIMARY importable ecosystem.** `github.com/anthropics/skills` publishes doc
  skills (docx/pdf/pptx/xlsx), skill-creator, MCP-builder, creative/enterprise. **License SPLIT:** open skills
  Apache-2.0 → `direct_import`; **doc-skills proprietary/source-available → `quarantine_reference`/research_only,
  NOT direct_import** (ProvenanceGate). The spec itself Apache/CC-BY → format adoption clean. Import via the
  EXISTING `skill_manage` path (git2 clone, no subprocess; Pro-gated; MAS gets `install_from_local_path` + honest
  "remote install is Pro"). Bundled Python `scripts/` stored but NEVER auto-run (no-sidecar) — instructions usable
  even where the script isn't.
- **Vercel = NO skill packs.** AI-Elements = React/shadcn UI only (S14 confirmed — separate slice). AI SDK `tool()`
  = a JS runtime tool (run-the-program, excluded), MCP-aligned in v5/6. **Adoptable Vercel value = MCP-served tools**
  via the existing connector. Record honestly: "MCP-consumed, no native skill packs."
- **Google = NO SKILL.md catalog.** ADK/Gemini function-calling = JSON-schema function defs, MCP/OpenAPI-shaped.
  Adopt via **MCP** (point an entry at a Google/ADK MCP server) + a future OpenAPI→ToolSchema importer (aspirational/L).
- **MCP = the universal connector (already built):** stdio servers (`mcp/client.rs`, `harden_cli_subprocess`, Pro)
  + URL servers (`mcp/url_servers.rs`, HTTPS-only, auth allowlist, **MAS-eligible — network.client only**). Map:
  Anthropic→SKILL.md import; Vercel→MCP; Google→MCP(+OpenAPI later); generic tool servers→MCP; native re-impl only
  if uniquely-valuable AND license-blocked (rare).

## Install path (both lanes ~80-90% built)
- **Lane A (Anthropic SKILL.md):** owner uses `skill_manage install_from_github {git_url, allow_remote_skill_install:true}`
  → quarantine+scan → `{approve:true}` promote. MAS = `install_from_local_path` + honest "Pro" message.
- **Lane B (the missing thin UI):** clone the **FineTunePack marketplace** shape → a `SkillPack`/`SkillPackRegistry`
  + `SkillMarketplaceView` whose `apply` calls `skill_manage install_*` — browse→import→approve→promote, provenance-
  gated, license-required, MAS-safe descriptors. Consolidate with the single MCP-install panel (MASTER_SYNTHESIS #27).

## Gating + ordered plan
Gating (preserve): Pro = remote github/url install + script-execution + stdio MCP; MAS = local-path import + URL-MCP +
non-executing instruction packs (honest "Pro only" for the rest). **Honor `allowed-tools` at promote as a tool-scope
whitelist (security, §3.7 lifecycle).** Never auto-execute bundled scripts on the in-process/MAS path.
1. (prereq, Phase-0 #5) unify the 4 skill dirs + register skill tools in MAS + point loader at `.agents/skills/`. [S]
2. Frontmatter compat shim (standard top-level tags/author/version + compatibility/license/allowed-tools, additive). [S ½day]
3. Honor `allowed-tools` at import/promote as a tool-scope whitelist. [S]
4. Skill marketplace UI mirrored from FineTunePack (apply→existing skill_manage). [M ~2-3d]
5. Seed catalog: Anthropic Apache skills direct_import; doc-skills quarantine_reference; Vercel/Google as MCP entries. [S-M]
6. (aspirational) OpenAPI→ToolSchema importer for Google ADK/Gemini. [L, defer]

## Real-vs-aspirational
REAL: SKILL.md compat (~, one shim), the quarantine/ProvenanceGate install path, MCP stdio+URL connectors, the
FineTunePack template, Pro/MAS honest gating. NEEDS WIRING (small): dir unification (prereq), compat shim,
allowed-tools enforcement. NEW-BUT-TEMPLATED: the skill marketplace UI. ASPIRATIONAL: OpenAPI→tool importer,
executing bundled scripts (needs the Pro Sandbox seam). **BE HONEST TO OWNER: Vercel has NO skill packs (AI-Elements
= UI only); Google has NO SKILL.md catalog — both are MCP/tool-def ecosystems, not SKILL.md. Only ANTHROPIC is a
true importable SKILL.md source; everything else flows through MCP.**

Key files: `agent_core/src/tools/skills.rs` (install_from_* + quarantine + scanner + Pro gate) · `skill_router.rs:189`
(parse_skill) · `storage/skills_registry.rs:21` · `mcp/{client.rs,url_servers.rs}` (URL=MAS-safe) · `KnowledgeFusion/
Marketplace/FineTunePack*.swift` + `Views/Settings/FineTuneMarketplaceView.swift` (template to clone) · `.agents/skills/*/SKILL.md`
(7 authored packs in the unread 5th path). Sources: github.com/anthropics/skills, agentskills.io/specification, ai-sdk.dev/docs/tools, google.github.io/adk-docs.
