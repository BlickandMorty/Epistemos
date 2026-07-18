# Base App June Restore Intent Ledger — 2026-07-17

## Owner checkpoint 1

- Verbatim owner wording: "can u make it main now idk the process if fast forward or push is better idk the verbiageand thier meaning but make it all on main and save checklpopint to solidify this as a current version of the app. i want to make sure both the free build and the base app are good. and the base app still has working june"
- Interpreted intent: promote the current app to `main` only after preserving a durable checkpoint and verifying two distinct products: a physically pruned Free V1 build and a base app that still contains the last known-good June experience.
- Hard constraints: preserve current Free V1 removal; do not add June to the Free target; preserve June only in a separate base target; avoid force-pushing or rewriting existing history; checkpoint the verified result.
- Non-goals: do not revive retired browser-use, subprocess, Pro, Experimental, 1Code, OpenChamber, Kindred, terminal, or unrelated provider surfaces.
- Acceptance checks: Free target source membership excludes June; base target source membership includes June; both targets build; base app exposes the June surface; local, upstream, and GitHub `main` match; a permanent checkpoint tag exists remotely.
- Contradiction: the current repository has only one application target, both schemes point to Free V1, and `Epistemos/JuneAgent` is absent. The base/June claim is not currently true.
- Next action: recover the June closure from commit `668b52cfb43721de95db102260d9f327ae24e13e`, restore it only to a separate base target, and verify both builds before promotion.

## Owner checkpoint 2

- Verbatim owner wording: "well just push it all then"
- Interpreted intent: prefer completing the promotion without unnecessary ceremony, but this did not revoke the earlier base/June preservation requirement once the owner immediately restated it.
- Constraints and non-goals: unchanged.
- Next action: keep the local history-preserving merge unpushed until the base/June acceptance checks pass.

## Owner checkpoint 3

- Verbatim owner wording: "and yes make sure that the june is on base app becasue it was working the very last timne i was testing it i want to make sure it does not regress becasue it ewas good"
- Interpreted intent: the last working June implementation is protected product behavior, not optional historical code. Restore the final pre-deletion June closure rather than inventing a replacement.
- Hard constraints: no GitHub `main` promotion until June is present in the base app and Free V1 remains clean.
- Acceptance checks: build proof for both targets plus direct source/bundle evidence that June is base-only.
- Next action: map and restore the exact pre-deletion closure, then compiler-drive only the compatibility fixes required by the current shared app.

## Owner checkpoint 4

- Verbatim owner wording: "also i had the goose in porcess that was powering june nothign else so i need to make sure that that is waht is powering june again"
- Interpreted intent: June must execute through the in-process Goose MAS bridge backed by the bundled `agent_core` FFI, and Goose must have no separate product surface or authority outside June.
- Hard constraints: no Goose UI, subprocess, local server, Node backend, browser-use/Chromium path, or app-wide Goose settings; do not restore unrelated Goose code.
- Acceptance checks: `JuneAgentGateway` owns `GooseMASAgentCoreRunner`; the base target links and bundles `libagent_core`; the runner uses the generated in-process `agent_core` bindings; the Free target includes none of this closure.
- Next action: restore only the runner/provider support required by June and prove the linkage from source and built bundle.

## Owner checkpoint 5

- Verbatim owner wording: "and agsain the june settings should only be in jubne it shoudl not be mixed in with my apps system settings at all. and i do not want local models just cloud models"
- Interpreted intent: June owns its provider/model configuration inside the June surface. The app's normal Settings surface must not expose or manage June configuration. June must present and route only cloud models; local-model selection and local-chat runtime are out of scope for June.
- Hard constraints: no June/provider/model rows in app Settings; no local model catalog, GGUF/MLX/Llama picker, download, or local-runtime route in June; keep the Free app physically free of all June/cloud/provider surfaces.
- Non-goals: do not remove unrelated non-June app preferences, Kokoro read-aloud, or Free V1's audited local embedding-backed note search.
- Acceptance checks: source guards show June settings are implemented only under `JuneAgent`; app Settings have no June bindings; June's visible catalog contains cloud choices only; no local-model package or runtime is required by the base target solely for June.
- Next action: audit the recovered June surface and its dependency closure against these boundaries before completing the base target.

## Owner checkpoint 6 — implementation and hardening result

- Owner intent carried forward: preserve the last working June only in the base app, powered only by Goose's in-process `agent_core`, with all provider/model configuration owned by June and with cloud language models only.
- Implemented boundary: the `Epistemos` base target includes `JuneAgent`, staged June web assets, and `libagent_core`; the `Epistemos-AppStore` Free target excludes the entire June source/resource/runtime closure.
- Aggressive pruning performed: removed June's unused HUD/meeting/browser-renderer web entrypoints, removed local-model/Ollama and disconnected settings surfaces from the staged June bundle, physically deleted the disabled `JuneCloudEngine` proxy and zero-caller per-message Prompt Forge engine, and removed an unused app-Settings diagnostics row.
- Settings ownership: `JuneCloudSettingsView` is presented only from `JuneAgentNavBar`; app Settings contains no June, OpenAI, Anthropic, provider, API-key, or model row.
- Cloud-only contract: June admits only typed OpenAI and Anthropic model IDs and scopes Keychain credentials around the in-process Goose FFI call; no local language-model picker, downloader, runtime, or fallback is reachable from June.
- Verification completed without tests per owner direction: fresh Debug builds succeeded for base and Free; the base app launched; bundle/source-membership guards proved June and `agent_core` are base-only, and runtime-path guards found no Goose executable/server, Node, browser-use/Chromium/Playwright/Puppeteer, Ollama, GGUF, or Llama artifact.
- Remaining verification debt: automated tests were intentionally not run at the owner's explicit request; the local Debug apps were built without code signing because this machine has no signing identities.
- Next action: inspect the final diff, commit the complete current tree, create the permanent checkpoint tag, and atomically push the identical commit to the feature branch and GitHub `main`.

## Owner checkpoint 7 — June blank-screen correction

- Verbatim owner wording: "june is not loading"
- Interpreted intent: restore the base app's June surface to a visibly usable loaded state without weakening the already-established June-only ownership, cloud-only model routing, in-process Goose boundary, or Free V1 exclusion.
- Hard constraints: keep June absent from the Free target; keep June settings inside June; keep local language models, browser automation, subprocesses, local servers, and retired HUD windows absent; do not run the test suite per the owner's standing direction.
- Non-goals: do not redesign June, change providers, revive deleted standalone HUD entrypoints, or alter unrelated app settings.
- Acceptance checks: the checked-in June index has no missing referenced asset; a fresh base build succeeds; opening June visibly renders its first screen instead of a blank WKWebView; unified logging shows no missing June bundle asset during the verified load.
- Contradiction resolved: the pruning rule treated every `agent-hud-*` JavaScript chunk as a standalone HUD entry, but Vite also gave the shared main-surface command/settings module that prefix. The main bundle statically imports that shared module, and the runtime log recorded its 404.
- Verification result: the narrowed rule regenerated deterministically during both the direct web build and the fresh base-app build; the base build succeeded; the app bundle contains the required shared chunk and none of the retired HUD/server-browser entrypoints; June visibly rendered its session composer and cloud model selector; the verified runtime log contained no June asset 404 or frontend error.
- Next action: complete the scoped hardening guards, then commit and push the verified correction.

## Owner checkpoint 8 — save and publish the correction

- Verbatim owner wording: "commit and push as wll when ur done"
- Interpreted intent: once the June runtime proof and hardening checks pass, create a durable Git commit and publish it so GitHub reflects the working June correction.
- Hard constraints: commit only the scoped script, generated shared asset, and intent evidence; do not include unrelated files; preserve the identical current app checkpoint relationship by updating the current feature branch and `main` without force-pushing or rewriting history.
- Acceptance checks: the committed tree is clean; the feature branch and GitHub `main` both resolve to the verified fix commit; the running evidence app remains the fresh post-fix base build.
- Next action: inspect the final staged diff, commit it, push both branch refs, and verify remote object identity.
