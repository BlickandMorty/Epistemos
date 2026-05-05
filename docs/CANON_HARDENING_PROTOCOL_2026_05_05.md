# Canon Hardening Protocol — 2026-05-05

**Status:** CANON. Promoted from Codex's drift-pass recommendations
2026-05-05.

This doc codifies three canonical-upgrade protocols Codex flagged as
the highest-value next moves after the V2 stretch:

1. **WRV status protocol** (Codex #2): replace ambiguous "shipped"
   language with a six-state ladder so authority claims become
   verifiable.
2. **Canon promotion protocol** (Codex #10): six-state lifecycle for
   research → live doctrine, so research never disappears + doctrine
   never silently fragments.
3. **No date gates** (Codex #3): the only valid gates are capability,
   verification, distribution, entitlement, licensing, and doctrine.

These three protocols are linked: WRV is how features earn promotion;
the promotion protocol is the lifecycle WRV operates inside; no-date-
gates is the rule that prevents calendar handwaving from substituting
for either.

This doc is **canon as of merge** — every future feature, doctrine
PR, and audit applies these protocols. Existing canon docs are
honored unchanged; this layers on top.

---

## 1. WRV status protocol

Per Codex's 2026-05-05 advice: a feature should be one of these six
states, not "shipped":

| State | Meaning | What it requires |
|---|---|---|
| **research** | Idea / spec / design doc only | A written canonical doc the user can read |
| **implemented** | Code exists in the repo | Compiles + has unit tests |
| **wired** | Reachable from the runtime | At least one production call site invokes it |
| **reachable** | Available from the user's UI / CLI / API | The user can actually exercise the path through normal use |
| **visible** | The user can see / observe its effect | Some surface (Settings row, Halo ribbon, log line) reflects it |
| **verified** | Codex has independently verified WRV | Explicit Codex sign-off doc cites the verification logs |
| **released** | Shipped to a distribution channel | App Store build OR Developer ID notarized binary OR public CLI release |

**The "shipped" claim requires VERIFIED at minimum.** Anything below
verified must use the lower-state language explicitly.

### How to apply

When writing a commit message, doc, or status report:

- Use the lowest-state word that's literally true.
- "Implemented" without "wired" means the code compiles + tests pass
  but nothing in production calls it. This is the state of most
  scaffold work (e.g. ANEBackend protocol + mock today).
- "Wired" without "visible" means production calls it but the user
  can't see the effect. This is what dispatch-emitted DAG writes
  look like before observability surfaces are built.
- "Verified" requires a Codex sign-off doc; "released" requires a
  shipped binary signed under a real distribution gate.

### Examples (current codebase, 2026-05-05)

| Surface | True state | Why |
|---|---|---|
| Cognitive DAG Phase 8.A-8.G | implemented + wired (auto-invoke dispatch) + visible (Settings row) | NOT verified by Codex against the Phase 1-7 preconditions; NOT released until 8.H |
| V2.3 in-process LSP semantic | wired + visible | Codex verified focused tests but NOT full app; "verified" partial |
| ProviderServiceStreamingProtocol (V2.4) | implemented | No production call site; mock-only |
| ANEBackend (V3.2) | implemented | No production call site; PrivateFrameworkANEBackend not built |
| ResonanceService FFI swap | implemented + wired + verified by tests | Not "visible" until a UI surfaces the signature; not released |
| Halo ledger ribbon | implemented + wired + reachable + visible | Settings opens, Halo opens, ribbon renders ledger counts |

### Substitution rule

Never write "X is shipped" — write "X is `<state>`" picking the
lowest-state word from the table that is literally true. If you
cannot pick one, the work is not yet `implemented`.

---

## 2. Canon promotion protocol

Per Codex's 2026-05-05 advice: every doc + design + research artifact
sits in one of these six lifecycle states.

| State | Meaning | Where it lives |
|---|---|---|
| **research** | Idea / hypothesis / external reference | `docs/fusion/research/` or `docs/_archive/.../research/` |
| **candidate** | Explicit doctrine candidate; staged but not merged | `docs/fusion/CANON_GAPS_*.md` style staging docs |
| **canon** | Live doctrine; binding on every PR | The four canonical doctrine files + this doc + sister canonical docs |
| **superseded** | Was canon, now replaced; kept for history + commit-archaeology | Marked `SUPERSEDED` in title + frontmatter; canonical replacement linked |
| **historical** | Was research/candidate; not promoted; kept as audit trail | Untouched but marked in an index |
| **rejected** | Explicitly considered + declined; reason recorded | Marked `REJECTED` with link to the deliberation that declined it |

### State transitions (allowed)

```
research      → candidate          (someone proposes promotion)
research      → historical         (no one championed it)
candidate     → canon              (Codex verifies + user signs off)
candidate     → rejected           (deliberation declined it)
canon         → superseded         (replaced by a stronger canon doc)
superseded    → historical         (no longer informative)
```

**Never:**
- `canon → rejected` directly (must go through `superseded` so the
  replacement is named)
- `historical → research` (resurrection requires a fresh research doc)
- `rejected → canon` (declined work needs a fresh candidate)

### How to apply

Every doctrine PR includes a one-line status declaration in its
frontmatter:

```yaml
---
state: canon | candidate | research | superseded | historical | rejected
supersedes: <doc-name-or-section>      # required for superseded
superseded_by: <doc-name>              # required when transitioning canon → superseded
rejection_reason: <one line>           # required for rejected
canon_promoted_on: 2026-MM-DD          # required for canon
---
```

This makes drift impossible to hide: anyone can grep for `state: canon`
to enumerate the live doctrine surface.

### Existing canon (live as of 2026-05-05)

These docs are `state: canon` regardless of whether they have the
frontmatter today (this protocol applies prospectively):

- `CLAUDE.md`
- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`
- `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md`
- `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md`
- `docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md`
- `docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md`
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md`
- `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` (this doc)

Existing candidates awaiting promotion:
- `docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md` — 11 MERGE
  TARGET blocks across 5 destination files. Per Codex's #1
  recommendation, these should be merged. The merge is itself a
  multi-commit operation that needs its own canon brief — held until
  scheduled.

---

## 3. No date gates

Per Codex's 2026-05-05 advice: dates are not gates. The valid gate
types are:

| Gate type | Example |
|---|---|
| **capability** | "the runtime must do X before we promise Y" |
| **verification** | "Codex must independently verify WRV before this is canon" |
| **distribution** | "needs Apple Developer Program enrollment" |
| **entitlement** | "needs `com.apple.security.network.client`" |
| **licensing** | "needs NousResearch license for brand assets" |
| **doctrine** | "blocked on Phase 1-7 preconditions per cognitive_kernel_doctrine §11" |

**Invalid:**
- "blocked until May 4" (calendar date)
- "wait until next sprint" (calendar window)
- "scheduled for Q2" (calendar quarter)

If a real gate happens to imply a calendar window (e.g. the
two-week §10 CI green window), state the doctrine gate; the
calendar is a derived consequence, not the gate itself.

### How to apply

When writing "X is blocked on Y" in any doc / commit / handoff:
- Y must be a phrase that names one of the six gate types.
- "Codex hasn't verified" is a valid verification gate.
- "Friday's review" is NOT a valid gate.
- "the user needs to sign up for Apple Developer Program" IS a valid
  distribution / entitlement gate.

This rule already shows up in the V2 close-out + Codex handoff: the
"Gate" column in the V2 status matrix uses these six types
exclusively. Promote that practice to canon.

---

## 4. Three protocols together — the canon-hardening invariant

A feature reaches `canon + verified + released` iff:
1. Its WRV state is `verified` per §1.
2. Its doc is `state: canon` per §2.
3. Every blocker named for it is one of the six gate types per §3.

A feature claims `released` iff additionally:
4. A signed binary (App Store / Developer ID notarized / public CLI
   release) exists for it.

Anything failing any of (1)-(4) MUST use the lower-state language.
This is the contract Codex enforces on every audit.

---

## 5. What Codex's other recommendations imply

Codex's full 10-point list is in their 2026-05-05 advice message. The
other seven items remain as canon-candidate work:

- **#1**: Merge `CANON_GAPS_AND_ADDENDA_2026_05_02.md` 11 MERGE
  TARGET blocks. Held — needs its own canon brief + verified merge
  pass.
- **#4**: ✅ Closed by commit `9835b439` (CD-005 capability-bound
  put_edge).
- **#5/#9**: XPC trust spine — `NSXPCConnection.setCodeSigningRequirement(_:)`
  per Apple docs. Implementation-grade trust checklist needed.
  Held as research → candidate.
- **#6**: MAS/Pro brutal separation — needs source guard sweep
  over every `Command::new`, `Process`, `Pipe` site. Mostly aligned
  per existing `MAS_RUNTIME_FORBIDDEN_TOOLS` discipline; needs
  doctrine-linter gate addition.
- **#7**: V2.3 cross-file LSP — implementation work in V2.3 Stage F.
- **#8**: Sim worktree as donor mine — protocol: every cherry-pick
  needs its own canon brief.

These are tracked separately in the next session's plan.

---

## 6. Acceptance + activation

This doc is `state: canon` as of its merge commit. Every future
canon-touching PR (any commit that adds a `state: canon` doc, claims
`released`, or modifies one of the canon docs in §2.2 above) is
expected to honor §1, §2, §3.

Codex's audit framework now has six states to evaluate against
(rather than the binary "shipped / not shipped"). This is the
canon-hardening payoff.

---

## Cross-references

- Codex 2026-05-05 advice message (in chat history) — origin of
  the three protocols
- `docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md` — the drift
  register that motivated this hardening
- `docs/SUBSTRATE_V2_FINAL_CLOSEOUT_2026_05_05.md` — the V2 status
  the protocols re-frame
- `docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md` — the
  candidate-state doc Codex's #1 recommendation targets
