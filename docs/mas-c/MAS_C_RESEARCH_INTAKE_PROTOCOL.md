# MAS C Research Intake Protocol

ID: `MAS-C-RESEARCH-INTAKE-PROTOCOL-2026-07-08`

Use this protocol when the owner brings new Cursor, Claude, cloud-agent,
manual, repo, or web research back into MAS C. Its job is to absorb stronger
research without letting MAS C drift, duplicate itself, or silently reverse the
MAS-only strategy.

## Intake Rule

New research is evidence, not automatic instruction. Before changing any MAS C
plan or build prompt:

1. Identify every new artifact and its path or source.
2. Read the artifact enough to extract claims, decisions, contradictions, and
   evidence quality.
3. Classify each claim against MAS C.
4. Update traceability before updating feature plans.
5. Update only the smallest owning MAS C docs.
6. Run the packet checks and refresh the zip.

## Research Intake Record

For each new research batch, add a short record to the working evidence note or
handoff:

```text
Research batch name:
Artifact paths or links:
Date received:
Features touched:
Claims accepted:
Claims corrected:
Claims rejected:
Claims needing official/current source:
MAS C docs updated:
Contradictions found:
Verification run:
Zip refreshed:
Next research gap:
```

## Claim Classification

Use these labels:

- `accept`: improves MAS C without conflict.
- `accept-with-correction`: useful but needs MAS C framing or local proof.
- `reject`: contradicts MAS C or relies on forbidden behavior.
- `park-as-provenance`: historically useful but not active product direction.
- `needs-local-proof`: cannot be accepted until current source or runtime is
  inspected.
- `needs-official-source`: depends on current policy, API, SDK, source terms,
  or license.
- `needs-owner-decision`: strategic or product tradeoff the owner must choose.

## Update Order

Apply updates in this order:

1. `MAS_C_TRACEABILITY_MATRIX.md`
2. `MAS_C_FEATURE_INDEX.md` if dependency order, first proof, or feature
   coverage changes
3. the affected feature `PLAN.md`
4. the affected feature `BUILD_PROMPT.md`
5. `MAS_C_EXTERNAL_RESEARCH_PROMPT.md` if future cloud-agent instructions
   change
6. `MAS_C_ANTI_DRIFT_GUARD.md` if new red flags or classification labels appear
7. `MAS_C_EVIDENCE_PROTOCOL.md` if proof requirements change
8. `MAS_C_FILE_MANIFEST.md`
9. `MAS_C_OBJECTIVE_AUDIT.md`
10. `MAS_C_PACKET_CHANGELOG.md`

Do not update broad docs first unless the new research changes the MAS C control
lock itself.

## Conflict Handling

When new research conflicts with MAS C:

- If it recommends a parked product lane, classify it as provenance unless the
  owner explicitly reopens that lane.
- If it recommends a hidden runtime, classify it as rejected for MAS unless it
  can be reframed as in-process, reviewable, and App Store-safe.
- If it recommends database or proprietary storage as truth, require lossless
  vault reconstruction, rollback, and user data ownership proof.
- If it recommends a source/API integration, require official terms and a
  source-legality verdict before implementation.
- If it recommends a UI direction, require native-shell ownership boundaries and
  proof that the change is more than wrapper/reskin/token polish.

## Feature Plan Merge Rule

A feature plan may change only when the research answers at least one of these:

- dependency order
- scope
- forbidden behavior
- acceptance evidence
- F1-F6 integration
- MAS legality/source legality
- storage truth/rebuild behavior
- native shell versus WKWebView ownership
- release scan or App Review proof

If research only restates an existing decision, update the traceability matrix
or changelog, not the feature plan.

## Required Checks After Intake

After any MAS C research intake edit, run:

```bash
find docs/mas-c -type f | sort
git diff --check -- docs/mas-c
find docs/mas-c -name '*.md' -type f -exec sh -c 'for f do grep -q "^ID:" "$f" || echo "missing ID: $f"; done' sh {} +
find docs/mas-c/features -mindepth 1 -maxdepth 1 -type d -exec sh -c 'for d do test -f "$d/PLAN.md" || echo "missing PLAN: $d"; test -f "$d/BUILD_PROMPT.md" || echo "missing BUILD_PROMPT: $d"; done' sh {} +
LC_ALL=C rg -n "[^\x00-\x7F]" docs/mas-c
```

Then run the current placeholder and contradiction scans used by
`MAS_C_OBJECTIVE_AUDIT.md`, refresh the zip, and record the file count.

