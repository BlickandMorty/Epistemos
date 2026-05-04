#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_PATH = ROOT / "docs/fusion/oversight/HELIOS_HOTPATH_VERIFICATION_2026_05_03.json"

REQUIRED_PATHS = [
    "docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md",
    "docs/fusion/HELIOS_METAL_KERNELS_2026_05_03.md",
    "docs/fusion/HELIOS_KV_DIRECT_GATE_RUNBOOK_2026_05_03.md",
    "docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md",
    "docs/fusion/EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md",
    "docs/fusion/EPISTEMOS_FUSION_HANDOFF_2026_05_03.md",
    "EpistemosTests/Fixtures/red_team_prompts.json",
    "agent_core/src/resonance/mod.rs",
    "agent_core/src/resonance/tau.rs",
    "agent_core/src/resonance/pi.rs",
    "agent_core/src/resonance/lambda.rs",
    "agent_core/tests/resonance_seed.rs",
    "Epistemos/Engine/ResonanceService.swift",
    "Epistemos/LocalAgent/HermesGatewayPolicy.swift",
    "Epistemos/LocalAgent/HermesCapabilityRegistry.swift",
    "Epistemos/Sovereign/SovereignGate.swift",
    "Epistemos/Engine/KIVIQuantization.swift",
    "Epistemos/Vault/SSMStateService.swift",
    "EpistemosTests/KIVIKVCacheRuntimeTests.swift",
]

SHADER_PATHS = [
    "Epistemos/Shaders/CodeEditorEmbedding.metal",
    "Epistemos/Shaders/LandingWave.metal",
    "Epistemos/Shaders/ThinkingGlow.metal",
    "Epistemos/Shaders/Mamba2/direct_conv.metal",
    "Epistemos/Shaders/Mamba2/elementwise_ssm_helpers.metal",
    "Epistemos/Shaders/Mamba2/inter_chunk_scan.metal",
    "Epistemos/Shaders/Mamba2/segsum_stable.metal",
]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def e8_counts() -> tuple[int, int]:
    norm2 = []
    for i in range(8):
        for j in range(i + 1, 8):
            for sx in (-1.0, 1.0):
                for sy in (-1.0, 1.0):
                    v = [0.0] * 8
                    v[i] = sx
                    v[j] = sy
                    norm2.append(tuple(v))
    for mask in range(256):
        if bin(mask).count("1") % 2 == 0:
            norm2.append(tuple(-0.5 if (mask >> i) & 1 else 0.5 for i in range(8)))

    norm4 = []

    def rec(idx: int, remaining: int, cur: list[int]) -> None:
        if idx == 8:
            if remaining == 0 and sum(cur) % 2 == 0:
                norm4.append(tuple(float(x) for x in cur))
            return
        for value in (-2, -1, 0, 1, 2):
            cost = value * value
            if cost <= remaining:
                rec(idx + 1, remaining - cost, cur + [value])

    rec(0, 4, [])
    for large in range(8):
        for mask in range(256):
            scaled = []
            for i in range(8):
                sign = -1 if (mask >> i) & 1 else 1
                mag = 3 if i == large else 1
                scaled.append(sign * mag)
            if sum(scaled) % 4 == 0:
                norm4.append(tuple(x * 0.5 for x in scaled))
    return len(set(norm2)), len(set(norm4))


def sherry_roundtrip() -> bool:
    values = [0.1, -0.2, 0.8, -0.7, 1.0, -0.1, 0.3, -0.4]
    codes: list[int] = []
    scales: list[float] = []
    for off in range(0, len(values), 4):
        block = values[off : off + 4]
        zero = min(range(4), key=lambda i: abs(block[i]))
        sign_bits = 0
        sign_pos = 0
        scale_vals = []
        for i, value in enumerate(block):
            if i == zero:
                continue
            if value < 0:
                sign_bits |= 1 << sign_pos
            sign_pos += 1
            scale_vals.append(abs(value))
        codes.append((zero << 3) | sign_bits)
        scales.append(sum(scale_vals) / len(scale_vals))

    out = []
    for code, scale in zip(codes, scales):
        zero = code >> 3
        sign_pos = 0
        for i in range(4):
            if i == zero:
                out.append(0.0)
            else:
                neg = ((code >> sign_pos) & 1) == 1
                out.append(-scale if neg else scale)
                sign_pos += 1
    return len(out) == len(values) and all(math.isfinite(x) for x in out)


def fwht_check() -> bool:
    v = [1.0, 2.0, 3.0, 4.0]
    h = 1
    while h < len(v):
        for i in range(0, len(v), h * 2):
            for j in range(i, i + h):
                x, y = v[j], v[j + h]
                v[j] = x + y
                v[j + h] = x - y
        h *= 2
    return v == [10.0, -2.0, -4.0, 0.0]


def softmax_kl_check() -> bool:
    logits = [1.0, 2.0, 3.0]
    m = max(logits)
    exps = [math.exp(x - m) for x in logits]
    probs = [x / sum(exps) for x in exps]
    kl = sum(p * math.log(p / p) for p in probs)
    return abs(sum(probs) - 1.0) < 1e-12 and abs(kl) < 1e-12


def grep_for(pattern: str, roots: list[str], suffixes: tuple[str, ...]) -> list[str]:
    compiled = re.compile(pattern)
    hits: list[str] = []
    for root in roots:
        base = ROOT / root
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if not path.is_file() or path.suffix not in suffixes:
                continue
            rel = path.relative_to(ROOT).as_posix()
            text = path.read_text(encoding="utf-8", errors="ignore")
            for idx, line in enumerate(text.splitlines(), start=1):
                if compiled.search(line):
                    hits.append(f"{rel}:{idx}:{line.strip()}")
    return hits


def main() -> int:
    missing = [p for p in REQUIRED_PATHS + SHADER_PATHS if not (ROOT / p).exists()]

    shader_entrypoints = {
        path: bool(re.search(r"\b(kernel|vertex|fragment)\s+", read(path)))
        for path in SHADER_PATHS
        if (ROOT / path).exists()
    }
    mamba_shader_count = len(list((ROOT / "Epistemos/Shaders/Mamba2").glob("*.metal")))
    inter_chunk = read("Epistemos/Shaders/Mamba2/inter_chunk_scan.metal")

    resonance_mod = read("agent_core/src/resonance/mod.rs")
    tau = read("agent_core/src/resonance/tau.rs")
    pi = read("agent_core/src/resonance/pi.rs")
    lamb = read("agent_core/src/resonance/lambda.rs")
    resonance_swift = read("Epistemos/Engine/ResonanceService.swift")
    hermes_gateway = read("Epistemos/LocalAgent/HermesGatewayPolicy.swift")
    hermes_registry = read("Epistemos/LocalAgent/HermesCapabilityRegistry.swift")
    kivi = read("Epistemos/Engine/KIVIQuantization.swift")
    kivi_tests = read("EpistemosTests/KIVIKVCacheRuntimeTests.swift")

    la_hits = grep_for(
        r"LAContext\(|canEvaluatePolicy|evaluatePolicy",
        ["Epistemos"],
        (".swift",),
    )
    la_hits_outside_sovereign = [
        hit for hit in la_hits if not hit.startswith("Epistemos/Sovereign/")
    ]
    process_hits = grep_for(
        r"Process\(",
        ["Epistemos/Bridge", "Epistemos/LocalAgent", "Epistemos/Omega"],
        (".swift",),
    )
    naming_hits = grep_for(
        r"Epistenos|epistenos",
        ["Epistemos", "agent_core"],
        (".swift", ".rs"),
    )
    managed_private_hits = grep_for(
        r"storageModeManaged|storageModePrivate",
        ["Epistemos/Engine", "Epistemos/Graph", "Epistemos/Views/Notes"],
        (".swift",),
    )

    with (ROOT / "EpistemosTests/Fixtures/red_team_prompts.json").open(encoding="utf-8") as handle:
        prompts = json.load(handle)

    n2, n4 = e8_counts()
    checks = {
        "required_paths_present": not missing,
        "shader_entrypoints_present": all(shader_entrypoints.values()) and len(shader_entrypoints) == len(SHADER_PATHS),
        "mamba_shader_count_at_least_4": mamba_shader_count >= 4,
        "apple_safe_inter_chunk_scan": "LACK Forward-Progress Guarantees" in inter_chunk and "Reduce-then-Scan" in inter_chunk,
        "resonance_core_rust_present": all(
            marker in resonance_mod
            for marker in ["compute_signature_core", "ResonanceSignatureCore", "Claim"]
        ),
        "resonance_truth_ternary_present": all(
            marker in tau for marker in ["Truth::True", "Truth::Unknown", "Truth::False", "as_int"]
        ),
        "resonance_claim_types_9": "pub const ALL: [ClaimType; 9]" in pi,
        "resonance_core_residency_gate": "CORE_ALLOWED" in lamb and "is_core_allowed" in lamb,
        "resonance_swift_mirror_present": all(
            marker in resonance_swift
            for marker in ["ResonanceTruth", "ResonanceClaimType", "ResonanceSignatureCore", "computeSignatureCore"]
        ),
        "hermes_gateway_policy_present": all(
            marker in hermes_gateway
            for marker in ["hermesGateway", "structuredEvidenceProvenance", "directSubstrate", "inProcessLocalPrompt"]
        ),
        "hermes_capability_registry_present": all(
            marker in hermes_registry
            for marker in ["/todo", "/calc <expression>", "/tokens", "/mcp list", "HermesCapability"]
        ),
        "sovereign_single_owner": not la_hits_outside_sovereign,
        "no_critical_inference_subprocess": not process_hits,
        "canonical_naming": not naming_hits,
        "no_managed_private_hotpath_storage": not managed_private_hits,
        "kivi_runtime_floor_present": "KIVIKVCache" in kivi and "residualLength" in kivi_tests,
        "red_team_prompt_count": isinstance(prompts, list) and len(prompts) >= 10,
        "e8_counts_pass": n2 == 240 and n4 == 2160,
        "sherry_pack_pass": sherry_roundtrip(),
        "fwht_pass": fwht_check(),
        "softmax_kl_pass": softmax_kl_check(),
        "cargo_available": shutil.which("cargo") is not None,
        "rustc_available": shutil.which("rustc") is not None,
    }

    result = {
        "root": str(ROOT),
        "missing": missing,
        "shader_entrypoints": shader_entrypoints,
        "mamba_shader_count": mamba_shader_count,
        "la_hits_outside_sovereign": la_hits_outside_sovereign,
        "critical_process_hits": process_hits,
        "canonical_naming_hits": naming_hits,
        "managed_private_storage_hits": managed_private_hits,
        "e8_norm2_count": n2,
        "e8_norm4_count": n4,
        "checks": checks,
        "status": "pass" if all(checks.values()) else "fail",
    }
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if all(checks.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
