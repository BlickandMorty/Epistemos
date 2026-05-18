-- HELIOS V5 W24 — top-level Epistemos library entry.
-- Imports each E1-E7 foundational theorem stub plus Primitive IR
-- schema modules selected for Lean schema authority.

import Epistemos.EML

import Epistemos.E1
import Epistemos.E2
import Epistemos.E3
import Epistemos.E4
import Epistemos.E5
import Epistemos.E6
import Epistemos.E7

-- H1-H17 + PCF-1..PCF-10 stubs live as side-files at:
--   Epistemos/H1.lean .. Epistemos/H17.lean
--   Epistemos/PCF_1.lean .. Epistemos/PCF_10.lean
--
-- They are NOT imported here because:
--   * H1-H17 + PCF-1..10 side-files are audited by the W24
--     sorry-budget tracker on the filesystem, independent of
--     `lake build`.
--
-- A follow-up slice (W24.b) imports them once the per-id Lean
-- elaboration is being written for real.
--
-- Per docs/HELIOS_V5_DOC_6_THEOREM_CANON.md §1+§2+§3 the substrate
-- presence of these stubs is sufficient for lock; the proof
-- elaboration is W24.b/c follow-up.
