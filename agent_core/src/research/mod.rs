//! Source:
//! - `docs/fusion/jordan's research/helios v3.md` — Helios v3 capstone synthesis
//!   (5 Pillars · WBO-6 inequality · 6-tier memory · Wave J research-tier roadmap).
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md` §5 Phase B.1 —
//!   Wave J research-tier priority queue (J1 Ternary core through J9 MLSys papers).
//!
//! Wave J research-tier substrate for Terminal B (post-V1 lane). This is the
//! umbrella module under which each Wave J slice lands as its own submodule
//! (`ternary` for J1, future siblings for J2..J9). All modules under this
//! tree are gated behind `feature = "research"` so MAS/Pro builds do not
//! pay the compile cost unless explicitly opted in.
//!
//! Per `§8 PR-discipline` of the driver doc, every new module under this
//! tree MUST cite its primary source paper (arXiv ID or equivalent) in a
//! `//! Source:` doc comment.

pub mod ternary;
