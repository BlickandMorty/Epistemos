---
falsifier: F-LiteRTLM-NativeSwiftAdmission
created_on: 2026-06-06
artifact: artifacts/falsifiers/litertlm_native_swift_admission/result.json
scope: T1/L1 metadata-only LiteRT-LM Swift/macOS admission
---

# F-LiteRTLM-NativeSwiftAdmission

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS
ships the safe floor, Pro contains the gated/research/vault/omega ladder, and
no claim promotes without visible proof.

## Result

PASS as a metadata-only T1/L1 witness on 2026-06-06.

The artifact is:

- `artifacts/falsifiers/litertlm_native_swift_admission/result.json`

The script is:

- `Tools/falsifiers/f_litertlm_native_swift_admission.sh`

## What It Proves

`F-LiteRTLM-NativeSwiftAdmission` source-cards the official LiteRT-LM Swift
package and release evidence before LiteRT-LM can influence RuntimeRouter /
System G.

It accepts one LiteRT-LM admission card:

- repo: `https://github.com/google-ai-edge/LiteRT-LM`
- package: `https://github.com/google-ai-edge/LiteRT-LM/blob/main/Package.swift`
- release: `v0.13.1`
- license: `Apache-2.0`
- Swift docs: `https://ai.google.dev/edge/litert-lm/swift`
- binary targets: `CLiteRTLM` and `CLiteRTLM_mac`
- declared binary asset bytes: `123675099`
- unsafe linker flags source-carded, including `-all_load`
- MAS verdict: denied until binary/sandbox review
- Pro status: `ResearchCandidate`

The witness rejects 33 red fixtures, including missing binary targets, bad
checksums, missing asset sizes, missing unsafe-linker review, missing prebuilt
binary review, MAS/Live promotion, server-sidecar defaulting, missing
cancellation/tool-schema/AnswerPacket/rollback requirements, bad proof refs,
non-HTTPS URLs, unsupported license, product dependency import, package
resolution, binary download, runtime/model bytes, provider calls, product file
copy, hidden route authority, live dense 70B, and L2/L3 promotion.

## What It Does Not Prove

This witness does not import LiteRT-LM, resolve a Swift package, download an
XCFramework, link a binary target, load a model, run a runtime, start an
OpenAI-compatible server, benchmark MTP, prove tool calling, prove
cancellation, prove MAS safety, or make any product capability claim.

Correct phrasing:

- Architecture source-card/admission proof advanced for the LiteRT-LM Swift
  lane.
- Product capability, runtime route, MAS readiness, and user-facing model
  surfaces did not advance.

## Next Unit

The next research-to-build unit is
`F-Gemma4-MTP-DrafterCompatibilityCard`, followed by the runtime-plural QAT
lane tournament once the LiteRT and MTP source-card axes exist.
