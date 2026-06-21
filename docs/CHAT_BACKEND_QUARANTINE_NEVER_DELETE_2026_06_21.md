# 🛑 CHAT BACKEND — QUARANTINE, NEVER DELETE (owner 2026-06-21) — HARD GUARD

**Owner (verbatim, 2026-06-21):** *"all the parts of my chat can be preserved … the models the IP etc.
and add that to all the parts it is beneficial. but rn it is completely broken and needs to be
quarantined but should never be deleted as of now because one might try to delete it. whatever my
backend for the parts that are just broken … we can quarantine or whatever to preserve it so that i can
still work on IP and everything and add it to all the parts it needs like osaurus and the goose and such."*

## THE RULE (applies to ALL agents — the build loop, monitors, any session)
1. **NEVER DELETE the chat / chat-backend code.** Not the resolution layer, not the picker, not the
   views, not InferenceState chat paths, not the model wiring. No `rm`, no file removal, no "cleanup"
   that deletes these. The owner explicitly fears an agent will delete it — DO NOT.
2. **QUARANTINE instead:** the broken chat backend is isolated (flag-OFF / not-on-the-live-path /
   marked quarantined) but stays IN-TREE, fully preserved, so the owner can keep mining IP from it.
3. **PRESERVE + PORT the valuable parts** — the owner's models (QAT ladder etc., already standalone in
   `LocalModelInfrastructure.swift`/LocalModelCatalog), the IP (system prompts + hidden pieces), and any
   chat UI the owner loves — and ADD/port them into the parts that benefit: **Osaurus** (the act clone),
   **Goose** (work), and other surfaces per the plan.
4. **Only the OWNER may authorize deletion**, and only after the IP is fully ported + the replacement
   (Osaurus act) proves out. Until then: quarantine = the maximum action.

## WHY (do not "optimize" this away)
The chat backend has the recurring hidden-Qwen-fallback + many other breakages — it is being REPLACED
by the full Osaurus clone (see `OSAURUS_P3_IMPORT_PLAN_2026_06_19.md` + its 2026-06-21 owner-directive
append). "Replaced" does NOT mean "deleted now." Deleting it would destroy IP the owner is still
extracting. Quarantine preserves it safely while the clone is built and the IP is ported.

## STANDING SEQUENCING (owner 2026-06-21)
Osaurus full clone FIRST → port IP into Osaurus/Goose → THEN finish substrate + retire (NOT delete)
the quarantined chat once its IP is fully carried over. Stop spending effort patching the dying chat
backend now (e.g. the chat-picker / Qwen-fallback patch) — that requirement moves into the act build.

Cross-ref: OSAURUS_P3_IMPORT_PLAN_2026_06_19.md, OWNER_REQUESTS_LEDGER_2026_06_18.md,
SS-CHATPICKER_P0_INSTALLED_MODELS_NOT_CLICKABLE_2026_06_21.md, LOOP_HARDENED_ENGINEERING_CONTRACT.
