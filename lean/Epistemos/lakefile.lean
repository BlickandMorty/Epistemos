-- HELIOS V5 W24 — Lean 4 sorry-budget anchor.
--
-- Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W24 +
-- `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §1.
--
-- This lake project pins mathlib4 by tagged release per
-- `docs/fusion/helios v5 first.md` PART 2 Q4:
--
--   "Pin mathlib4 by tagged release (e.g. `v4.16.0` style) with
--    explicit `lake-manifest.json` SHA pinning per the Lean
--    community guidance."
--
-- Each E1-E7 theorem lives in its own file under `Epistemos/`.
-- Per-id sorry budgets are enforced by
-- `Tools/sorry-budget/sorry-budget.sh` (W24).
--
-- Build:
--   cd lean/Epistemos
--   lake update
--   lake build
--
-- The toolchain pin is `lean-toolchain` (leanprover/lean4:v4.16.0).
-- mathlib4 pin lives below.

import Lake
open Lake DSL

package «epistemos» where
  -- Settings shared across all targets.
  leanOptions := #[
    ⟨`pp.unicode.fun, true⟩,
    ⟨`autoImplicit, false⟩
  ]

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.16.0"

@[default_target]
lean_lib «Epistemos» where
  -- Substrate library for E1-E7 Epistemos Core Theorems.
  -- See per-theorem stubs in `Epistemos/E*.lean`.
