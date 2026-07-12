# MAS C Prompt 03 - Legality Matrix

ID: `MAS-C-PROMPT-03-LEGALITY-MATRIX-2026-07-08`

Use this for sources, datasets, cloud APIs, local models, scraping, privacy, and
App Store compliance research.

```text
Build a MAS legality and source-legality matrix for the feature.

Use official or primary sources first. Separate observed facts from inference.
For each source, API, SDK, model, dataset, or runtime, provide:
- allowed / allowed with conditions / parked / forbidden
- licensing or terms basis
- App Store privacy and entitlement impact
- user-consent requirements
- attribution and deletion requirements
- offline fallback
- MAS implementation shape
- release evidence required

Hard defaults:
- no scraping where an official API or license is required
- no paywall bypass
- no Reddit API commercial feature without explicit terms/review clearance
- no browser-use Chromium or subprocess automation in MAS
- no hidden cloud fallback
- no local model/runtime promotion without package, memory, privacy, and
  rollback evidence
```

