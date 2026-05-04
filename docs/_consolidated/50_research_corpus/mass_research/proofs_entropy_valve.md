# Formal Properties: Entropy Valve (Focus Controller)

## Statement 1 — Boundedness of Depth
Let `min_depth <= max_depth`. The controller computes:

```
D = min_depth + difficulty * (max_depth - min_depth)
```
where `difficulty ∈ [0,1]`.

**Claim:** `min_depth <= D <= max_depth`.

**Proof:**
Because `difficulty ∈ [0,1]`, the term `(max_depth - min_depth) * difficulty` lies in `[0, max_depth - min_depth]`.
So `D` lies in `[min_depth, max_depth]`.

---

## Statement 2 — Monotonicity in Entropy
Let `difficulty = w_e * entropy + w_d * dissonance` with `w_e, w_d >= 0` and `w_e + w_d = 1`.

**Claim:** Increasing `entropy` while holding all else constant does not decrease `depth`.

**Proof:**
`depth` is an affine function of `difficulty`.
Since `difficulty` is non‑decreasing in `entropy` when `w_e >= 0`, `depth` is also non‑decreasing in `entropy`.

---

## Statement 3 — Temperature Scaling Boundedness
The temperature scale is computed via linear interpolation between
`throttle_temperature_max` and `throttle_temperature_min`.

**Claim:** `temperature_scale` always lies in `[min, max]`.

**Proof:**
Linear interpolation over `t ∈ [0,1]` maps into the closed interval between the endpoints.

---

## Statement 4 — Disabled Valve Invariant
If `enabled = false`, the controller returns a constant plan:

```
FocusPlan(depth=base_depth, temperature_scale=1.0, max_tokens_scale=1.0)
```

**Claim:** The output is independent of entropy and dissonance.

**Proof:**
The function returns without reading metrics. Therefore output is constant.
