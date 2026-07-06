---
name: june-source-decomposition
description: Use when decomposing oversized MAS June Swift files, source-guard tests, gateway helpers, bridge helpers, model catalogs, prompt/context builders, approval registries, or any June source-quality pass that must reduce file size and spaghetti without changing behavior, capability truth, or App Store boundaries.
---

# June Source Decomposition

## Purpose

Use this skill to make MAS June source smaller, clearer, and more directly owned by the right layer. The goal is not cosmetic splitting. The goal is to move cohesive authority into named files so the gateway, bridge, and source guards stay readable while every MAS non-negotiable remains true.

Do not use this skill to widen June's runtime capability, touch `Epistemos/ExperimentalAgent/**`, touch Pro/1Code lanes, or move code just to satisfy a number while making the ownership model harder to understand.

## Required Reads

1. `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
2. `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`
3. The oversized source or test file
4. Nearby call sites that prove behavior ownership
5. `EpistemosTests/AppStoreJuneHardeningTests.swift` and any split June source-guard files

## Method

1. Name the ownership boundary.
   - Extract only a cohesive concept: model row catalog, conversation context, approval registry, vault scope, tool bounds, session store, prompt forge, or source-guard substrate tests.
   - Keep execution/routing authority in the gateway unless the extracted concept owns it naturally.
   - Prefer a small enum or final class with direct static functions over wrapper layers.

2. Move behavior without changing it.
   - Keep names and payload shapes stable when possible.
   - Keep capability truth at the same boundary: local stays chat-tier; cloud/tool rows stay honest; no model loading or downloads move into passive catalog/context helpers.
   - Keep MAS law intact: no subprocess, no stdio MCP, no hidden server, no raw vault roots to JS.

3. Move source guards with the behavior.
   - When code moves out of `JuneAgentGateway.swift`, update tests to read the new file.
   - Use one shared source-section helper for split test files; do not copy helper functions.
   - Split source-guard suites by concern when a test file crosses 1k lines.

4. Validate cheaply first.
   - Run `wc -l` on touched source/test files and confirm the target file moved below the threshold.
   - Run `git diff --check` and direct trailing-whitespace scans.
   - Run parser-only Swift over the touched June seam.
   - Source-scan for old anchors and new ownership anchors.
   - Defer full App Store builds/runtime proof to deliberate checkpoints on a quiet 16 GB machine.

5. Record evidence.
   - Update `docs/research/JUNE_MAS_CONNECTION_AUDIT.md` with before/after line counts, moved ownership, and validation commands.
   - Say plainly when build/runtime proof was not run.

## Review Checklist

- No MAS June production source file remains over 1k lines because of this slice.
- Split files have clear ownership names, not vague "Utils" names.
- The gateway still owns turn orchestration, default model selection, and engine routing unless intentionally extracted.
- Passive helpers do not start downloads, load model bytes, call network APIs, mutate vault files, or emit JS.
- Source guards still cover the same invariants after moves.
- Test helper code is shared, not duplicated.
- Validation notes distinguish parser/source proof from App Store build or running MAS proof.
