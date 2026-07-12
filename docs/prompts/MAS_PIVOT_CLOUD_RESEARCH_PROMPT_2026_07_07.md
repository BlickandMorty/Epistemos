# MAS Pivot Cloud Research Packet - 2026-07-07

ID: MAS-PIVOT-CLOUD-RESEARCH-2026-07-07
Lock: `MAS-ONLY-SHIP-LOCK-2026-07-07`

Use this packet for a cloud or online research agent that does not have access to the local
Epistemos repo. Attach the files listed below, paste the prompt section, and require the agent to
work from attachments plus current primary/official web sources.

## Owner Intent Checkpoint

Verbatim owner steer, excerpted:

> all the plans i want them all to be competely redirected towards mas ... completel stopping pro
> and experient and just going full mas no other builds atp ... keelstone lumenlens and reckoner
> all need to be deeply auditted to reflect just mas ... quick capture, sync, etc. embercatch, maybe
> even lodestar ... auditin the storage to make sure it is mas freindly ... deep pruning of base app
> to make it just mas but ofc safely ... the minicht should be native but idk if thatll work sinee im
> usng goose and etc.should it be june a diff version of june

Interpreted intent:
- Epistemos should now be researched, planned, built, pruned, and release-hardened as one Mac App
  Store product.
- Pro, Developer-ID, Experimental, 1Code, OpenChamber, Goose, Kindred runtime, browser-use,
  subprocess, local-server, terminal, stdio-MCP, and hidden sidecar lanes are parked unless a later
  owner directive explicitly reopens them.
- Useful ideas from parked lanes are allowed only when rebuilt through MAS-safe June, in-process
  `agent_core`, native Swift/AppKit/SwiftUI, WKWebView bundled assets, sandbox-safe storage,
  Keychain secrets, and approval-gated tools.
- Research must connect the plans, not treat them as islands: KEELSTONE storage/release,
  LUMENLENS editor/provenance, RECKONER datasets, EMBERCATCH quick capture, LODESTAR ResearchHub,
  Sync, MAS June, and the base-app pruning plan must become one coherent MAS release strategy.

Non-goals:
- Do not recommend a second active product lane.
- Do not resurrect 1Code/Kindred/OpenChamber/Goose/browser-use as active MAS surfaces.
- Do not delete or discard old research just because it mentions parked lanes; classify it as
  provenance, donor material, or forbidden-for-MAS.
- Do not provide generic App Store advice. Every conclusion must map back to the attached plan docs.

## Attachment Checklist

Attach paths exactly as files, not screenshots, when possible. If upload space is limited, attach
Tier 0-2 first, then add Tier 3, then Tier 4.

### Tier 0 - mandatory lock and cross-plan map

- `AGENTS.md`
- `CLAUDE.md`
- `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md`
- `docs/prompts/MASTER_PLAN_INDEX_2026_07_03.md`
- `docs/prompts/INTEGRATION_FABRIC.md`
- `docs/prompts/RESEARCH_PROMPT_STANDARD.md`
- `docs/prompts/MAS_PIVOT_CLOUD_RESEARCH_PROMPT_2026_07_07.md`

### Tier 1 - active triad plans to audit deeply

- `docs/plans/keelstone/PLAN_KEELSTONE_EPI-RP-07-KEELSTONE.md`
- `docs/plans/keelstone/BUILD_PROMPT_KEELSTONE.md`
- `docs/plans/lumenlens/PLAN_LUMENLENS_EPI-RP-02-LUMENLENS.md`
- `docs/plans/lumenlens/BUILD_PROMPT_LUMENLENS.md`
- `docs/plans/lumenlens/INTEGRATION_SPINE_LUMENLENS_EPI-RP-02-LUMENLENS.md`
- `docs/plans/reckoner/PLAN_RECKONER_EPI-RP-09-RECKONER.md`
- `docs/plans/reckoner/BUILD_PROMPT_RECKONER_EPI-RP-09-RECKONER.md`
- `docs/plans/reckoner/CONTRADICTION_SWEEP.md`
- `docs/plans/reckoner/HANDOFF_CARDS.md`

### Tier 2 - adjacent MAS plans that must be integrated

- `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
- `docs/prompts/BUILD_PROMPT_MAS_JUNE_ENTERPRISE.md`
- `docs/prompts/PROMPT_PLAN_3_CAPABILITIES.md`
- `docs/prompts/PROMPT_PLAN_6_QUICKCAPTURE.md`
- `docs/prompts/RESEARCH_PROMPT_PLAN_6_QUICKCAPTURE.md`
- `docs/prompts/PROMPT_PLAN_7_SYNC.md`
- `docs/prompts/RESEARCH_PROMPT_PLAN_7_SYNC.md`
- `docs/prompts/PROMPT_PLAN_8_RESEARCHHUB.md`
- `docs/prompts/RESEARCH_PROMPT_PLAN_8_RESEARCHHUB.md`
- `docs/prompts/PROMPT_PLAN_9_DATA_TABLES.md`
- `docs/prompts/RESEARCH_PROMPT_PLAN_9_RECKONER.md`

### Tier 3 - useful optional docs

- `docs/prompts/PROMPT_PLAN_2_EDITOR.md`
- `docs/prompts/PROMPT_PLAN_4_ICONS.md`
- `docs/prompts/PROMPT_PLAN_5_COMPANION.md` only as parked provenance
- `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`
- `docs/research/AGENT_SURFACE_PERFORMANCE_DOCTRINE_2026_07_03.md`
- `docs/research/AGENT_SURFACE_HARDENING_DOCTRINE_2026_07_03.md`
- `docs/research/RESEARCHHUB_SOURCE_DOSSIER_2026_07_03.md`
- `docs/research/PLAN9_ADJUDICATION_WORKING_2026_07_03.md`

### Tier 4 - local code/config snippets for release/pruning checks

If the cloud agent can inspect code snippets, attach these too:

- `project.yml`
- every `*.entitlements`
- every `PrivacyInfo.xcprivacy`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/App/AppSurface.swift`
- `Epistemos/Views/Landing/LandingView.swift` if present
- `Epistemos/JuneAgent/*` summaries or key files
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Sync/VaultIndexActor.swift`
- `Epistemos/Views/Notes/*Epdoc*` or `Epistemos/Engine/EpdocEditorBridge.swift`
- `agent_core/src/bridge.rs`
- `agent_core/src/tools/*` summaries if tool allowlist is in scope
- `EpistemosTests/AppStoreHardeningTests.swift`
- `EpistemosTests/AppStoreJuneHardeningTests.swift`

If a file cannot be attached, the cloud agent must label all claims about it as `REQUIRES LOCAL
VERIFICATION` and provide the exact local command or search query needed.

### Tier 5 - optional storage lineage packet

Attach these if the research question includes "should we keep the current storage architecture,
revert to the old one, or build a proprietary fused storage substrate?"

- `docs/ARCHITECTURE_AUDIT.md`
- `docs/MASTER_BUILD_PLAN.md`
- `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md`
- `docs/RECURSIVE_GOVERNANCE_VIABLE_SYSTEMS_MODEL_2026_05_15.md`
- `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md` or the relevant storage/UAS/AppColdStore excerpts
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` or the relevant storage/UAS/AppColdStore excerpts
- any current code snippets for `SDPage`, `NoteFileStorage`, `VaultSyncService`,
  `VaultIndexActor`, `SearchIndexService`, `ReadableBlocksIndex`, `AtomicVaultWriter`,
  `EpdocEditorBridge`, and dataset artifact storage.

If the large canon files are too big to attach, provide excerpts around: `NoteFileStorage`,
`SDPage`, vault truth, derived index, GRDB, rope, AppColdStore, UAS, cold storage, stable external
IDs, rebuildable caches, and file-system sync.

## Primary Sources The Cloud Agent Must Use

The cloud agent must verify current platform and source legality against primary/official sources,
not memory. Minimum source families:

- Apple App Review Guidelines:
  `https://developer.apple.com/app-store/review/guidelines/`
- Apple App Sandbox and sandboxed file access:
  `https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox`
- Apple privacy manifests and required reason APIs:
  `https://developer.apple.com/documentation/bundleresources/privacy-manifest-files`
  and `https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api`
- Apple current upload requirements:
  `https://developer.apple.com/news/upcoming-requirements/`
- arXiv API and terms:
  `https://info.arxiv.org/help/api/index.html`
  and `https://info.arxiv.org/help/api/tou.html`
- Crossref REST API guidelines:
  `https://www.crossref.org/documentation/retrieve-metadata/rest-api/tips-for-using-the-crossref-rest-api/`
- NCBI E-utilities:
  `https://www.ncbi.nlm.nih.gov/books/NBK25497/`
- Semantic Scholar API and license:
  `https://www.semanticscholar.org/product/api`
  and `https://www.semanticscholar.org/product/api/license`
- Unpaywall/OpenAlex/provider documentation for open-access retrieval and licensing.

The cloud agent should add current official sources for StoreKit 2, App Store Server API, Keychain,
NSFileCoordinator, NSFilePresenter, File Provider/iCloud, FSEvents, WKWebView bundled assets,
Foundation Models, Speech/SpeechAnalyzer, Vision, PDFKit, and any third-party source/provider it
classifies.

## Paste This Prompt To The Cloud Research Agent

```text
You are the principal MAS pivot researcher and adversarial integration auditor for Epistemos, a
macOS-native PKM app. You do not have access to the local repo except through the attached files.
Your job is to deeply re-research, audit, and redirect the attached plan stack so it becomes one
coherent Mac App Store product strategy.

Current date: July 7, 2026. Treat platform rules, provider APIs, source terms, and App Store
requirements as current-fact questions. Verify them with primary/official web sources and cite
links. Do not rely on memory.

Non-negotiable lock:
Read and obey `MAS-ONLY-SHIP-LOCK-2026-07-07`. MAS/June is the only active product lane. Pro,
Developer-ID, Experimental, 1Code, OpenChamber, Goose, Kindred runtime, browser-use Chromium,
terminal/code-exec tools, stdio MCP, Node backends, local servers, hidden sidecars, runtime
subprocesses, and non-sandboxed lanes are parked unless a later owner directive explicitly reopens
them. Useful ideas from parked lanes may be salvaged only by rebuilding them through App Store-safe
June, in-process `agent_core`, native Swift/AppKit/SwiftUI, WKWebView bundled assets, Keychain,
security-scoped bookmarks, sandbox-safe storage, and approval-gated tools.

Owner intent:
The owner is not asking for a shallow rename from Pro/Experimental to MAS. The owner wants a deep
strategic pivot: every plan must be made MAS-native, MAS-safe, release-hardened, and integrated.
Words like "pivot", "audit", "redirect", "prune", "MAS-only", "deeply integrated", and "release"
carry product weight. Treat them as structural requirements, not wording polish.

Attachments are source truth:
Use the attached files as the plan corpus. If a required local file is not attached, mark related
claims as `REQUIRES LOCAL VERIFICATION` and provide the exact file/search/command needed. Do not
invent local code facts.

Required research method:
1. Read the lock, master index, integration fabric, research standard, and all attached plans before
   writing recommendations.
2. Build an owner-intent map: the literal owner goal, hard constraints, non-goals, acceptance checks,
   and unresolved contradictions.
3. Perform a contradiction sweep across KEELSTONE, LUMENLENS, RECKONER, EMBERCATCH, LODESTAR,
   Sync, Capabilities, and MAS June. Flag every line that still implies Pro, Developer-ID,
   Experimental, 1Code, OpenChamber, Goose, Kindred runtime, browser-use, subprocess, local server,
   terminal, stdio MCP, or a second chat/agent lane as active.
4. Verify current MAS rules and source/provider terms using primary/official sources. Prefer Apple
   docs and provider docs/terms over blogs. For every external source or API, classify what is safe
   on MAS, safe with conditions, parked, research-needed, or forbidden.
5. Do three internal audit cycles before finalizing:
   - Cycle A: MAS legality and release-readiness audit.
   - Cycle B: cross-plan integration audit using F1-F6 from `INTEGRATION_FABRIC.md`.
   - Cycle C: contradiction/buildability audit that rewrites weak recommendations until they are
     build-directive-grade.
6. Self-score the final dossier 1-5 on groundedness, alternatives named, build-actionability,
   no-fabrication, constraint fidelity, integration depth, depth/novelty, release safety, and
   contradiction cleanup. Any score below 4 means revise before final.

Core deliverables:

1. Executive Thesis
Give the one-page MAS-only product thesis. It must name the active product surface, active agent,
active storage truth, active data truth, active editor truth, and release gate.

2. MAS Legality Matrix
Create a matrix with rows for:
- MAS June agent surface
- Epdoc MiniChat / Epdoc assist
- KEELSTONE storage and release gate
- LUMENLENS editor/provenance/notebook
- RECKONER data/datasets/charts/grid
- EMBERCATCH Quick Capture and voice
- Plan 7 Sync / iCloud / external sync coexistence
- LODESTAR ResearchHub
- Plan 3 capabilities: PDF, provenance, vault tools, arXiv, Browser, STT/voice, skills
- base-app pruning / OpenChamber-ProAgent-Experimental removal
- StoreKit/proxy/cloud lane
- local model / Foundation Models / embedded llama.cpp lane

Columns:
- MAS verdict: SAFE, SAFE WITH CONDITIONS, PARK, RESEARCH NEEDED, or FORBIDDEN
- Why
- Primary sources cited
- Required entitlements/capabilities
- Privacy manifest / required reason API implications
- App Review notes needed
- Release-test evidence needed
- Plan docs that need edits

3. ResearchHub / LODESTAR Source Legality Matrix
For every proposed source, classify official API/feed, auth model, rate limits, license/ToS,
storage/caching rules, attribution, privacy risks, and MAS verdict. Cover at least:
arXiv, Crossref, OpenAlex, Unpaywall, PubMed/PMC/NCBI, Semantic Scholar, CORE, DOAJ, Europe PMC,
bioRxiv/medRxiv, OSF/PsyArXiv/SocArXiv/EdArXiv, GitHub, Hugging Face, Papers with Code, HN,
Reddit, X/Twitter, Mastodon, Bluesky, RSS/Atom, OpenLibrary, Internet Archive, Gutendex, Zotero,
Readwise, publisher RSS, and any source the attached docs name.

Hard rules:
- Never recommend Sci-Hub, LibGen, Google Scholar scraping, forbidden publisher scraping,
  unauthorized full-text download, credential harvesting, hidden paid-content access, or ToS-violating
  scraping.
- If a source is allowed only for non-commercial/internal/research use, say so and mark commercial
  MAS release as requiring license/legal review.
- If only metadata is safe, separate metadata from full-text/media storage.
- Use official APIs, RSS/Atom, OA infrastructure, or user BYO credentials only.

4. Storage And Sync MAS Audit
Audit whether the storage model is MAS-friendly:
- vault files as truth
- security-scoped bookmarks
- NSFileCoordinator / NSFilePresenter / FSEvents roles
- iCloud Drive / Dropbox / Syncthing coexistence
- derived indexes/GRDB not authoritative
- atomic writes and crash recovery
- external-editor conflict handling
- dataset artifacts and `.dataset.md`
- Quick Capture zero-loss writes
- ResearchHub saved items/media/cache
- privacy and backup/export implications

Return a safe storage architecture and a release soak plan: external edit storm, sync race,
kill -9 during write, stale bookmark, volume unmount, iCloud placeholder, cache rebuild, dataset
artifact move/delete, ResearchHub purge/retention, and Quick Capture crash recovery.

4B. Storage Architecture Reconsideration: Old vs Current vs Proprietary Fusion
The owner is explicitly open to three outcomes:
- keep the current KEELSTONE direction if it is actually best;
- revert toward an older storage architecture if it was stronger;
- design a proprietary fused architecture that takes the app to the next level while staying MAS-safe.

Do not answer this from taste. Build a comparative architecture dossier.

Compare at least these candidates:
- **Current KEELSTONE model:** vault markdown/files/artifacts are durable truth; `SDPage`/GRDB/indexes
  become metadata, derived cache, search/projection, and working store; all writes are coordinated,
  atomic, and externally visible.
- **Older app-owned model:** `SDPage`/GRDB/`NoteFileStorage`-style persistence where app DB/body
  state is more central, with file export/sync as a projection or bridge.
- **Hybrid file-truth plus app-owned operation log:** markdown/artifacts remain user-readable truth,
  but Epistemos owns an append-only journal/provenance/op-log that can replay, heal, explain,
  migrate, and reconstruct state after crashes or sync races.
- **Proprietary fused substrate:** a MAS-safe "Epistemos storage layer" that combines file-truth
  portability, stable content IDs, UAS/AppColdStore-style addressing where appropriate, rebuildable
  cold caches, derived indexes, append-only provenance, conflict witnesses, and export/import
  guarantees without locking the user into opaque bytes.

For each candidate, score:
- MAS/App Store safety
- user trust and portability
- external editor compatibility
- iCloud/Dropbox/Syncthing behavior
- crash/data-loss resistance
- conflict clarity
- 10k-100k note scale
- agent/provenance friendliness
- ResearchHub/Quick Capture/Reckoner artifact fit
- migration complexity
- long-term product moat
- App Review/privacy risk

Return a verdict: KEEP CURRENT, REVERT, HYBRIDIZE, PROPRIETARY FUSION, or RESEARCH NEEDED. The
verdict must include:
- chosen architecture diagram in words;
- what stays truth;
- what is derived;
- what is append-only;
- what is rebuildable;
- what stable IDs survive moves, renames, import/export, and cache rebuild;
- exact migration plan from current state;
- rollback path;
- falsifier tests that would prove the recommendation wrong;
- local files and commands needed to verify live repo reality.

Hard constraints:
- Do not recommend opaque proprietary storage as the only truth unless there is a fully lossless,
  user-readable, round-trippable export and a compelling MAS-safe reason.
- Do not let GRDB, AppColdStore, embeddings, search indexes, or dataset caches silently outrank the
  user's vault files/artifacts unless the owner explicitly accepts that product trade-off.
- If a proprietary layer is recommended, it must be additive, witnessed, recoverable, privacy-safe,
  and explainable to App Review and to users.

5. Base App Pruning Plan
Design the safe MAS-only pruning path:
- active target: `Epistemos-AppStore`, `EPISTEMOS_APP_STORE`, `MAS_SANDBOX`
- no flagless hidden base app
- no active `EPISTEMOS_EXPERIMENTAL` or `KINDRED_ENABLED`
- OpenChamber/ProAgent deleted or quarantined as provenance only
- no browser-use/Chromium/Python/subprocess/terminal/stdio MCP/local server in MAS archive
- leak/symbol scans and archive entitlement checks
- XcodeGen/project.yml source-of-truth discipline
- rollback path and staged deletions

Return exact local verification commands/searches for the local agent.

6. MiniChat / Epdoc Assist Decision
Answer this directly:
Should Epdoc MiniChat be native, June, Goose, 1Code, or a separate runtime?

The required bias is: no new chat runtime. Prefer MAS-June ownership. Propose the best architecture:
- a native Swift/AppKit/SwiftUI shell for focused context, selection, status, approval, and
  provenance;
- the same MAS-June / `agent_core` session and tool registry as the main Agent room;
- optional compact June component in a WKWebView only if reusing June transcript/composer is
  necessary and can be bundled without a server;
- no Goose/1Code/Kindred runtime, no Node/Tauri backend, no local server, no second chat database,
  no separate tool authority.

Explain trade-offs honestly: native transcript vs compact June web component vs hybrid shell.
Specify what must be proven before implementation.

7. Deep Integration Plan
Using `INTEGRATION_FABRIC.md`, produce an F1-F6 matrix for every active plan:
- F1 Vault bus
- F2 Agent capability registry
- F3 MAS status/provenance
- F4 Knowledge graph
- F5 Provenance/citation
- F6 State/event bus

For each feature, state the owner side, consumer side, data shape, event shape, approval gate,
release evidence, and what must not be duplicated.

8. Build Order And Dependency Graph
Return a strategic MAS-only build order. It should prefer:
1. KEELSTONE storage/release gate and base-pruning truth
2. MAS June agent seam
3. LUMENLENS editor/provenance/notebook infrastructure
4. RECKONER datasets only where LUMENLENS/KEELSTONE seams are ready
5. EMBERCATCH Quick Capture, Sync, LODESTAR ResearchHub, and Plan 3 capabilities as MAS-safe
   capabilities using the same fabric

If you disagree with that order, explain why with evidence.

9. Plan-Edit Checklist
Produce a file-by-file list of recommended edits to the attached docs. For each item include:
- file
- exact stale wording or section
- severity
- proposed replacement
- why this preserves owner intent
- whether it is a wording fix, structural plan change, or local-code verification need

10. Local-Agent Redirect Prompt
Write a final paste-ready prompt for a local coding agent that has repo access. It must:
- tell the local agent which docs to read first;
- enforce MAS-only;
- enforce read-before-edit and intent checkpointing;
- enforce batched verification debt rather than build spam;
- tell it exactly how to audit KEELSTONE/LUMENLENS/RECKONER/EMBERCATCH/LODESTAR for MAS;
- tell it how to keep working after apparent completion via deep hardening;
- forbid active non-MAS lanes.

11. Release Evidence Checklist
Return the concrete evidence a MAS release candidate needs:
- build/test commands
- archive/entitlements/privacy manifest checks
- required reason API checks
- symbol/leak checks
- StoreKit/proxy checks
- vault permission and storage tests
- ResearchHub API compliance checks
- mini-chat/June tool approval checks
- manual/runtime checks and App Review notes

12. Self-Critique
List the three weakest parts of your own dossier and the follow-up research needed.

Tone and output rules:
- Be direct and exact. No vague "ensure compliance" language without proof steps.
- Cite sources with links.
- Label every claim as OBSERVED FROM ATTACHMENT, PRIMARY-SOURCE VERIFIED, INFERRED, or REQUIRES
  LOCAL VERIFICATION when ambiguity matters.
- Do not summarize the attachments lazily; audit and synthesize them.
- Preserve nuance. Parked provenance is not active scope, but it is not trash.
- This is a serious release pivot, not a wording exercise.
```

## Short Local Steer For In-Flight Agents

Use this if a local agent is already running and needs a compact redirect:

```text
Read `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md`,
`docs/prompts/MASTER_PLAN_INDEX_2026_07_03.md`, `docs/prompts/INTEGRATION_FABRIC.md`, and
`docs/prompts/MAS_PIVOT_CLOUD_RESEARCH_PROMPT_2026_07_07.md` before your next edit.

Treat MAS/June as the only active product lane. Re-audit your current plan against the cloud-prompt
deliverables: MAS legality, storage/release safety, F1-F6 integration, parked-lane leak checks,
and contradiction cleanup. Do not revive Pro, Developer-ID, Experimental, 1Code, OpenChamber,
Goose, Kindred runtime, browser-use, terminal/code-exec, stdio MCP, local server, or subprocess
lanes. Salvage useful ideas only through MAS-safe June + in-process `agent_core` + native/WKWebView
bundled assets.

Before editing, write/update an intent checkpoint preserving the owner's latest steer. Keep a
verification-debt ledger during long coding batches, then run narrow and broad checks at meaningful
checkpoints. After a phase appears complete, enter the deep-hardening loop: contradiction sweep,
release-risk audit, MAS leak checks, storage/data-loss tests, UI/runtime evidence where relevant,
and targeted fixes until the owner stops you or a real blocker remains.
```

## Initial MAS Research Conclusions To Validate

These are starting hypotheses for the cloud agent, not final answers:

- ResearchHub can be MAS-friendly only if it uses official APIs/RSS/open-access infrastructure/BYO
  credentials, respects provider terms/rate limits, stores only allowed metadata/media/full text,
  attributes sources, and uses privacy-consented networking.
- ResearchHub is not MAS-safe if it relies on forbidden scraping, Sci-Hub/LibGen, Google Scholar
  scraping, unauthorized full-text downloads, hidden paid-content access, or provider terms that
  forbid the release use case.
- Epdoc MiniChat should be MAS-June owned, not Goose/1Code/Kindred owned. Native shell for context,
  approvals, and provenance is attractive; transcript/composer reuse can come from a compact June
  bundled component only if it does not create a second runtime or server.
- KEELSTONE must be the first serious gate because MAS pruning, sandbox storage, release evidence,
  and leak checks decide what the other plans can safely depend on.
- LUMENLENS and RECKONER should remain deeply integrated through references, ledger, and previews,
  not by copying rows into notes or making a new Data room/chat room.
- Current Keelstone-style file truth is likely the safest MAS default, but the best proprietary
  version may be an additive fused layer: app-owned append-only provenance/op-log, stable content
  IDs, UAS/AppColdStore-inspired rebuildable cold caches, and deterministic recovery over
  user-readable vault truth. The cloud agent must prove or disprove this with migration and
  falsifier evidence.
