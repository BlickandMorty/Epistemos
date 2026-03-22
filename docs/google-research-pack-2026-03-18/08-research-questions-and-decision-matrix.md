# Research Questions and Decision Matrix

Use this as the required checklist. The final recommendation should answer each item directly.

## 1. MLX architecture

Choose and justify one:

- `Option A`: MLX becomes a first-class `LLMProviderType`
- `Option B`: MLX is a separate local inference tier under `TriageService`
- `Option C`: hybrid approach where provider selection remains cloud-focused but local routing is handled separately

Required discussion:

- code impact on `InferenceState`
- code impact on `LLMService`
- code impact on `TriageService`
- best state object ownership
- how Qwen + Gemma are represented

## 2. Local model lifecycle

Define:

- when each model downloads
- when each model loads into memory
- how model swapping works
- whether one small model should stay resident
- what memory ceiling policy should be used
- when to unload on idle / pressure / backgrounding

## 3. Best starter local models

For each memory tier, specify:

- starter Qwen
- starter Gemma
- always-installed models
- optional models
- recommended quantization
- expected disk and memory cost
- role in routing

## 4. Chatterbox runtime architecture

Choose and justify one:

- bundled Python runtime + internal subprocess
- app-managed environment in Application Support
- separate helper app/binary strategy
- other strong alternative

Required discussion:

- signing/notarization
- first-run setup
- updates
- failure recovery
- App Store implications

## 5. Settings architecture

Recommend:

- section structure
- minimal controls for normal users
- advanced controls for power users
- status UI
- download UI
- fallback UX

## 6. Surface rollout

Recommend exactly what ships in V1:

- main chat
- notes AI
- note read aloud
- graph summaries
- notifications
- toolbar controls
- settings controls

And what should wait.

## 7. Performance safeguards

Required safeguards to define:

- no launch-time heavy model load
- no main-thread blocking during download or load
- streaming token path compatible with current note/chat flows
- no duplicate runtime instances if graph + notes + home are open
- cancellation and teardown behavior

## 8. What not to do

Explicitly call out bad ideas if applicable, for example:

- bundling huge model weights directly inside the main app bundle
- forcing user terminal setup
- reviving old agent UI structure
- introducing a fragile second inference stack that bypasses current routing
- making Fish the default without strong evidence

## 9. Expected final recommendation format

The ideal final answer from research should include:

1. final recommended architecture
2. alternative considered and rejected
3. exact model matrix
4. exact packaging/install strategy
5. exact settings plan
6. exact phased implementation plan for this codebase
7. risk table
8. source citations
