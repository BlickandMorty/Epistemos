# F-GemmaOwnerApprovedLocalArtifactReceiptProbe - 2026-06-09

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS as a metadata-only T1/L1 primary witness.

- Artifact: `artifacts/falsifiers/gemma_owner_approved_local_artifact_receipt_probe/result.json`
- Command: `Tools/falsifiers/f_gemma_owner_approved_local_artifact_receipt_probe.sh`
- Upstream: `F-GemmaLocalArtifactDiscoveryRunbookGate`
- Next cursor: `gemma_direct_harness_owner_approved_first_runtime_execution_probe`

## What This Proves

This probe freezes the receipt contract required before a local Gemma artifact can feed a runtime proof.

It binds:

- 28 required receipt fields, including owner approval phrase digest, model id, model family, source repo, source revision, expected filename, expected and observed byte counts, local file sha256, redacted path digest, raw-path absence, runtime lane, command-card id, llama-cli version/help digests, offline flag, source license, provenance mode, hardware profile, rollback, RunEventLog, AnswerPacket, abstention, reviewer summary, and non-promotion.
- 4 allowed model ids: Gemma 4 E2B QAT GGUF, Gemma 4 E4B QAT GGUF, MLX Community Gemma 4 E4B 4-bit, and LiteRT Community Gemma 4 12B LiteRT-LM.
- 3 allowed runtime lanes: direct offline GGUF/llama.cpp, pending MLX manifest loader, and pending LiteRT-LM Pro admission.
- 14 denied shortcuts and 36 rejection policies.
- 46 red-fixture rejections.

## What This Does Not Prove

This probe does not grant owner approval, create a receipt fixture, scan local folders, store raw owner paths, canonicalize paths, open files, hash files, verify bytes, execute `llama-cli --help` or `llama-cli --version`, arm commands, run commands, start servers, allow network probes, load model/runtime/provider bytes, mutate RuntimeRouter/System G/settings/default state, or make Gemma user-facing.

Correct phrasing: "The owner-approved Gemma local artifact receipt contract is witnessed; no Gemma artifact has been approved, opened, hashed, loaded, route-admitted, or promoted by this witness."

## L1 / L2 / L3 Truth

- L1 architecture/canon: advanced as metadata-only T1/L1.
- L2 capability route: unchanged and still red.
- L3 user-facing / release readiness: unchanged and still red.

## Failure Classes Covered

Invalid fixtures cover missing/duplicate receipt fields, missing/unknown model ids, missing/unknown runtime lanes, missing/duplicate denied shortcuts, missing rejection policies, owner-approval laundering, premature receipt presence/read/write, raw path storage, path canonicalization, file open/hash/sha256/byte-count actions, `llama-cli --help` or `--version` execution, command/server/network actions, model/runtime/provider bytes, RuntimeRouter/System G/settings/default mutation, hidden route/Eidos/lattice/PatternBoost/cloud authority, missing rollback/log/AnswerPacket/abstention, quality claims, L2/L3/T4 claims, live Gemma, live dense 70B, and SSD-as-RAM claims.

## Next Unit

`gemma_direct_harness_owner_approved_first_runtime_execution_probe` should consume a real owner-approved local artifact receipt before any one-token Gemma runtime proof. It must remain Pro Gated, direct local-file first, rollbackable, digest-only where possible, non-default, and unable to bypass RunEventLog, AnswerPacket, SCOPE-Rex/SovereignGate, or release-audit evidence.
