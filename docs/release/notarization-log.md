# Epistemos Pro Notarization Log

**Purpose:** Append-only audit trail of every `xcrun notarytool submit` invocation against the Epistemos Pro Developer-ID DMG.

**Authority:** Format spec is canonical in [`docs/release/MAS_APP_REVIEW_NOTES.md §9.2`](MAS_APP_REVIEW_NOTES.md). This file is the persistent log; that section is the procedure.

**Created:** 2026-05-16 (T-A iter 21) — skeleton-only; first real submission pending Pro DMG build readiness.

---

## Schema (per `MAS_APP_REVIEW_NOTES §9.2`)

Each submission appends one entry block. Required fields:

- `## Submission <ISO8601 UTC datetime>` — section heading (use `date -u +%Y-%m-%dT%H:%M:%SZ`)
- `DMG SHA256` — `shasum -a 256 Epistemos-Pro.dmg | awk '{print $1}'`
- `Submission ID` — from `notarytool submit ... --output-format json` → `.id`
- `Status` — from same JSON → `.status` (expected: `Accepted` · failure: `Invalid` or `In Progress` requiring follow-up)
- `Created` — from same JSON → `.createdDate`
- (On failure only) link to detailed log: `build/notarization-log-<id>.json` written via `xcrun notarytool log <id> --output-format json > build/...`

**Optional fields** (recommended for traceability):
- `Bundle build commit SHA` — git rev-parse of the codex/run branch tip at time of build
- `Stapler validation` — `Pass` / `Fail` from `xcrun stapler validate Epistemos-Pro.dmg` post-staple
- `Gatekeeper assessment` — `accepted` / `rejected` from `spctl --assess --type install` post-staple
- `Operator` — initials or sub-team that ran the submission

---

## Discipline rules

1. **Append-only.** Never edit a past entry. If a previous entry has incorrect info, append a new "## Correction <datetime>" block referring back by Submission ID — the original entry stays for audit-trail integrity.
2. **Chronological order.** Newest entries at the BOTTOM of the file (append), not the top. This matches the audit-trail-grows-down convention; readers `tail -n 100` to see the latest activity.
3. **Failures live alongside successes.** A rejected submission gets its own block (Status: Invalid · with `build/notarization-log-<id>.json` link). Do NOT delete failed submissions — they document the version history and reviewer feedback.
4. **No secrets.** This file is checked into git. Never paste `NOTARY_APP_SPECIFIC_PASSWORD` / Team ID secrets / API keys here. The submission command itself uses env vars per `MAS_APP_REVIEW_NOTES §9.2` — they don't appear in the response JSON.
5. **One file per repo.** This is the single source of truth. Do not fork into per-release-channel logs; if/when V3 §5 Phase G G6 distribution channel decision lands, distribution-channel-specific entries can add an optional `Channel:` field, but the file stays single.

---

## Example entry (illustrative — not a real submission)

```markdown
## Submission 2026-06-01T14:32:17Z

- DMG SHA256: `a3f5c8e9b2d4f1e6c7a8b9d0e1f2c3b4a5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0`
- Bundle build commit SHA: `abc123def456`
- Submission ID: `f1e2d3c4-b5a6-7890-1234-567890abcdef`
- Status: `Accepted`
- Created: `2026-06-01T14:32:18.456Z`
- Stapler validation: `Pass`
- Gatekeeper assessment: `accepted`
- Operator: `jc`
- Notes: First Pro V1 submission. Pre-submission gate per `MAS_APP_REVIEW_NOTES §9.1` all green; XPC entitlement audit per §10 all green.
```

---

## Cross-references

- [`docs/release/MAS_APP_REVIEW_NOTES.md §9.1`](MAS_APP_REVIEW_NOTES.md) — Pre-submission gate (run BEFORE every submission listed here)
- [`docs/release/MAS_APP_REVIEW_NOTES.md §9.2`](MAS_APP_REVIEW_NOTES.md) — Submission command + audit-trail capture format (this file's spec)
- [`docs/release/MAS_APP_REVIEW_NOTES.md §9.3`](MAS_APP_REVIEW_NOTES.md) — Stapling + validation (run AFTER `Status: Accepted`)
- [`docs/release/MAS_APP_REVIEW_NOTES.md §9.4`](MAS_APP_REVIEW_NOTES.md) — Failure modes table (consult on any non-Accepted Status)
- [`docs/release/MAS_APP_REVIEW_NOTES.md §10`](MAS_APP_REVIEW_NOTES.md) — Per-XPC entitlement audit (V3 §0 criterion 15; pre-submission validation per §10.2)
- V3 §0 victory criteria 11 (codesign) · 12 (notarytool Accepted) · 13 (stapler validate)
- V3 §5 Phase G G2 (codesigning) · G4 (notarization submit) · G5 (staple + verify)
- `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_A_2026_05_16.md §0` — full 15-criteria victory ladder

---

## Submissions

> **Pending first submission.** No notarytool submissions have been logged yet. The first entry will be added when the Pro V1 DMG is built + submitted per `MAS_APP_REVIEW_NOTES §9` end-to-end.
>
> **Pre-conditions for first submission** (per `MAS_APP_REVIEW_NOTES §9.1` + §10):
> - Apple Developer Program membership active (✅ confirmed 2026-05-16 per HELIOS V6.1)
> - `Epistemos-Pro.app` built via `xcodebuild archive` with Developer-ID signing identity
> - 5 XPC services entitlements verified per §10.2 (5 greps must exit 0)
> - 3 cross-XPC invariants verified per §10.3 (no leak pass)
> - DMG packaged via `productbuild` / `hdiutil` (out-of-scope per §9.6)
> - WASMExecJIT doctrine reconciliation per §10.4 settled (Option A vs Option B — pending user decision)

<!-- BEGIN AUTO-APPENDED ENTRIES — do not delete this marker; new entries land below -->

<!-- END AUTO-APPENDED ENTRIES -->
