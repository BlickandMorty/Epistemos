# F-VisibleOutputSanitization-ReleaseBlockerCard - 2026-06-07

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Result

PASS as metadata-only L1/T1 source-card witness.

Artifact:
`artifacts/falsifiers/visible_output_sanitization_release_blocker_card/result.json`

Command:
`Tools/falsifiers/f_visible_output_sanitization_release_blocker_card.sh`

## What It Proves

`F-VisibleOutputSanitization-ReleaseBlockerCard` consumes `F-AgentRoutePolicy-LargeModelNoHiddenAuthority` plus the retained release-audit family source card, then binds the `visible_output_sanitization` family to exact user-facing output/privacy surfaces before release readiness or large-model route claims can promote.

Measured facts:

- Retained release-audit family: `visible_output_sanitization`
- Issue count: `5`
- Source refs: `9`
- Required invariants: `12`
- Focused commands: `4`
- Red fixtures rejected: `17/17`
- Model/runtime bytes loaded: `0`
- Deterministic address: `sha256:3fe36c7c3d24e809faad6c3efc84b6a8cc58b394c7d3fd4301c5aea58a1b8e53`

## Source Refs

- `Epistemos/Engine/Extensions.swift`
- `Epistemos/Engine/TriageService.swift`
- `Epistemos/Engine/ThinkTagStreamRouter.swift`
- `Epistemos/State/ChatState.swift`
- `Epistemos/State/AgentChatState.swift`
- `Epistemos/State/NoteChatState.swift`
- `Epistemos/Views/Chat/ChatView.swift`
- `Epistemos/Views/MiniChat/MiniChatView.swift`
- `EpistemosTests/UserFacingModelOutputTests.swift`

## Hard Boundaries

This witness rejects raw function-call visibility, raw action visibility, raw tool JSON visibility, hidden reasoning visibility, prelude-only control narration, dropped explicit final answers, missing AnswerPacket caveats, hidden route/cloud authority, L2/L3/product green claims, live dense-70B claims, and model/runtime byte leaks.

This does not prove L2 product capability, L3 user-facing release readiness, full Swift-suite green, live local large-model execution, or MAS/Pro build green status.

Correct phrasing: Architecture source-card boundary advanced; product capability and user surface did not.

## Next Link

Next source-card unit: `graph_filter_visibility_release_blocker_card`.

Guard-owned cursor remains `small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
