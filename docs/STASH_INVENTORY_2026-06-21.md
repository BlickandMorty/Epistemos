# STASH INVENTORY (2026-06-21) — permanent record so NOTHING is lost

24 old safety-stashes from prior multi-terminal sessions (May/Apr/Mar 2026). Stashes persist in git
until explicitly dropped; each underlying commit SHA below is recoverable forever via `git stash apply <SHA>`
or `git show <SHA>` EVEN IF the stash ref is later cleaned. Fresh-session task: triage each —
recover anything unique as a CANON commit, then drop redundant safety copies deliberately. Nothing
deleted blindly; nothing lost. (Owner 2026-06-21: do not lose work; no ephemeral 'stash' as a hiding place.)

| ref | sha | age | files | message |
|-----|-----|-----|-------|---------|
| stash@{0} | `de77e4a56773e109df02f76fccf52de412b6949e` | 3 weeks ago | 0 | On docs/canon-chronicle-2026-05-23: preserve-wrv-docs-chronicle-before-worktree- |
| stash@{1} | `f2b29edeea2ac9aee345e0899f558b5eaaf9a13b` | 3 weeks ago | 4 | On phase2-terminal-e-acs-gate-rev2-2026-05-24: preserve-terminal-e-actionable-do |
| stash@{2} | `af4666fbd5df14f89d330da2a622c26aeef54a7b` | 3 weeks ago | 3 | On phase2-terminal-d-substrate-health-wrv-2026-05-24-r3: preserve-terminal-d-r3- |
| stash@{3} | `d0e907018b0e1561df2c28d5d1e6f68a95cd5900` | 3 weeks ago | 3 | On phase2-terminal-d-substrate-health-wrv-2026-05-24-r2: preserve-terminal-d-r2- |
| stash@{4} | `4d92ff31a58ecd877808277fbf8226e2cb5c1b10` | 4 weeks ago | 27268 | On master: b-prime-uncommitted-followup-2026-05-26 |
| stash@{5} | `7cf744220b8954e2d8127a997f1b43b9bff9ff4f` | 4 weeks ago | 96 | On phase2-terminal-d-prime-health-rows-2026-05-24: preserve syntax-core target b |
| stash@{6} | `c112df439e7d3cd634738ef364fb9270b71f59e9` | 4 weeks ago | 4 | On phase2-terminal-e-acs-gate-2026-05-24: terminal-e-rev2-docs-before-fresh-main |
| stash@{7} | `3375e38e9b07ec311efb48a895393d75c566c3ed` | 4 weeks ago | 4 | On master: auto-pre-pull-after-72-merge |
| stash@{8} | `12a2b83cf430b8b45d8940a09ec5a217d1e45869` | 4 weeks ago | 6 | On phase2-terminal-e-acs-gate-2026-05-24: wip-pre-rebase-2026-05-24 |
| stash@{9} | `c59c5a237b1370753930069ddde4bcee8d77d860` | 4 weeks ago | 14 | On phase2-terminal-e-acs-gate-2026-05-24: terminal-e-pre-main-2026-05-24-rev2 |
| stash@{10} | `a1ccc3111e1a96df950d4f97c5543cc18657dca2` | 4 weeks ago | 23 | On master: preserve-wip-before-merge-wave-2026-05-24 |
| stash@{11} | `7361808932711ff89cc84dab067cb2367f14bc86` | 4 weeks ago | 48 | On master: auto-stash for ff pull 160254 |
| stash@{12} | `3ecbdd0c526fd16499a81df6455707a924f9e963` | 5 weeks ago | 2 | WIP on codex/t12-f-ulp-oracle-2026-05-18: a279fe2a38 test(t12): reject missing r |
| stash@{13} | `005d9a2f4e479df649becfeb3b55f2f6587a1686` | 5 weeks ago | 2 | On codex/t11-agent-runtime-v2-2026-05-18: PRE-CURSOR-HANDOFF-1779175040 |
| stash@{14} | `e4a9f3201af36a09bda5dfdc44a3a8f6541b5287` | 5 weeks ago | 96 | On codex/t2-agent-2026-05-16: PRE-REMOVAL-STASH-t2-agent-20260518-224503 |
| stash@{15} | `252e32fa07ab842bda592f70cd49e3005a3aef93` | 5 weeks ago | 96 | On codex/t1-trifusion-2026-05-16: PRE-REMOVAL-STASH-t1-trifusion-20260518-224439 |
| stash@{16} | `9b4e703217e106ce61a530ef15dbb63c18fe211b` | 5 weeks ago | 3 | On run-b-post-v1-research: PRE-REMOVAL-STASH-runB-20260518-224424 |
| stash@{17} | `5eeac73e8b5ae461b8b55fc04003d1fef004df05` | 5 weeks ago | 2 | On master: wip-multi-terminal-recovery-2026-05-18: lib.rs + acs_admission/ + doc |
| stash@{18} | `293081a6feb27585f0df9865c8ed63c08f749fbd` | 5 weeks ago | 2 | On master: codex-preserve-t17b-lattice-format-before-t12 |
| stash@{19} | `314fe0250681a382a01f2697c14de7be65af8080` | 6 weeks ago | 8 | On master: wip-codex-graph-filters-selected-expansion |
| stash@{20} | `466cae307305fc16a5c9219f8b04c42de2c858ab` | 8 weeks ago | 11 | On master: session-stash-2026-04-27: W9.21 PR4 (X salvaged) + W9.8 wire-up parti |
| stash@{21} | `f9692c9c500aee4048fb99443414508cdb446af0` | 8 weeks ago | 17 | On master: codex-wip-parallel-during-landing-wave-session |
| stash@{22} | `d1c4cfcb32c919ac818223abae2764944245d93c` | 9 weeks ago | 973 | WIP on main: 31214a4d Update progress and mark three runtime issues as patched |
| stash@{23} | `30111102b5c90a01f00dd324b7687b23283ea147` | 3 months ago | 3 | WIP on main: 29c0ca83 Fix: Invisible text in code editor — isRichText must be tr |
