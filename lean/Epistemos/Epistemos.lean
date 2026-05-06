-- HELIOS V5 W24 — top-level Epistemos library entry.
-- Imports each E1-E7 foundational theorem stub so `lake build`
-- checks them all.

import Epistemos.E1
import Epistemos.E2
import Epistemos.E3
import Epistemos.E4
import Epistemos.E5
import Epistemos.E6
import Epistemos.E7

-- H1-H17 + PCF-1..PCF-10 stubs live as side-files at:
--   Epistemos/H1.lean .. Epistemos/H17.lean
--   Epistemos/PCF-1.lean .. Epistemos/PCF-10.lean
--
-- They are NOT imported here because:
--   * PCF-* file names contain a hyphen which Lean's module
--     resolution does not accept (PCF-1 would parse as PCF − 1).
--   * H1-H17 + PCF-1..10 stubs all carry one `sorry` placeholder;
--     the W24 sorry-budget tracker counts them via awk on the
--     filesystem, no `lake build` required.
--
-- A follow-up slice (W24.b) renames them to underscore form
-- (PCF_1.lean etc.) once the per-id Lean elaboration is being
-- written for real, at which point they are imported here.
--
-- Per docs/HELIOS_V5_DOC_6_THEOREM_CANON.md §1+§2+§3 the substrate
-- presence of these stubs is sufficient for lock; the proof
-- elaboration is W24.b/c follow-up.
