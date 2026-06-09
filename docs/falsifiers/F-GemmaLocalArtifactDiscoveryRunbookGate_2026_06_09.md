# F-GemmaLocalArtifactDiscoveryRunbookGate - 2026-06-09

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS as a metadata-only T1/L1 primary witness.

- Artifact: `artifacts/falsifiers/gemma_local_artifact_discovery_runbook_gate/result.json`
- Command: `Tools/falsifiers/f_gemma_local_artifact_discovery_runbook_gate.sh`
- Upstream: `F-GemmaOfficialConvenienceCommandDenylistGate`
- Next cursor: `gemma_owner_approved_local_artifact_receipt_probe`

## What This Proves

This gate defines the safe runbook for discovering an already-local Gemma artifact without leaking private filesystem paths or laundering discovery into runtime capability.

It binds:

- 4 symbolic search roots: owner Downloads, repo quarantine models, Hugging Face cache, and LiteRT import root.
- 4 expected artifact patterns: Gemma 4 E2B QAT GGUF, Gemma 4 E4B QAT GGUF, Gemma 4 12B LiteRT-LM, and Gemma 4 12B QAT GGUF.
- 18 discovery rules, including owner approval before scan, symbolic roots only, bounded depth, extension and filename allowlists, path digest only, raw path redaction, no file open, no file hash until receipt, no runtime command, no server/endpoint, receipt required after candidate, abstention on ambiguity, rollback, RunEventLog, AnswerPacket, and non-promotion.
- 30 rejection policies.
- 36 red-fixture rejections.

## What This Does Not Prove

This gate does not scan local folders, canonicalize a path, open a model file, hash bytes, verify byte count, run llama.cpp, run LiteRT-LM, start a server, call a provider, load model/runtime bytes, produce a token, admit RuntimeRouter/System G, update settings, or make Gemma user-facing.

Correct phrasing: "The local Gemma discovery runbook is safe and witnessed; no local Gemma artifact has been found, approved, opened, hashed, loaded, or promoted by this witness."

## L1 / L2 / L3 Truth

- L1 architecture/canon: advanced as metadata-only T1/L1.
- L2 capability route: unchanged and still red.
- L3 user-facing / release readiness: unchanged and still red.

## Failure Classes Covered

Invalid fixtures cover missing/duplicate symbolic roots, missing/duplicate artifact patterns, missing discovery rules, missing rejection policies, owner-approval laundering, raw path storage, path canonicalization, file open/hash/byte-count actions, command arming/execution, server start, network probe, model/runtime/provider bytes, RuntimeRouter/System G/settings/default mutation, hidden route/Eidos/lattice/PatternBoost/cloud authority, candidate-discovery promotion, missing rollback/log/AnswerPacket/abstention, L2/L3/T4, live Gemma, live dense 70B, and SSD-as-RAM claims.

## Next Unit

`gemma_owner_approved_local_artifact_receipt_probe` should consume this runbook only after explicit owner approval and should emit a redacted local artifact receipt with path digest, sha256, byte count, tool identity, rollback, RunEventLog, AnswerPacket, and abstention evidence before any runtime proof.
