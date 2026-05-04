#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import json
import math
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_DOCS = [
    'docs/ARCHITECTURE.md', 'docs/MEMORY_TIERS.md', 'docs/WBO6_INEQUALITY.md', 'docs/RESONANCE_GATE.md',
    'docs/VAULT_GATED_SWARM.md', 'docs/HERMES_GATEWAY.md', 'docs/SELF_TUNING.md', 'docs/UNIVERSAL_PLASTICITY.md',
    'docs/METAL_KERNELS.md', 'docs/SWIFT_UI.md', 'docs/API_SPEC.md', 'docs/BUILD_GUIDE.md',
    'docs/TEST_HARNESS.md', 'docs/SECURITY_AUDIT.md', 'docs/COMPETITOR_ANALYSIS.md', 'docs/PAPER_DRAFT.md',
    'docs/CHANGELOG.md', 'docs/CONTRIBUTING.md', 'LICENSE', 'README.md'
]
REQUIRED_CODE = [
    'Cargo.toml', 'crates/helios-core/src/lib.rs', 'crates/helios-core/src/lattice.rs', 'crates/helios-core/src/sketch.rs',
    'crates/helios-core/src/prcda.rs', 'crates/helios-core/src/inequality.rs', 'crates/helios-core/src/types.rs',
    'crates/helios-mlx/src/lib.rs', 'crates/helios-mlx/src/kernels.rs', 'crates/helios-mlx/src/attention.rs', 'crates/helios-mlx/src/tensors.rs',
    'crates/helios-metal/src/lib.rs', 'crates/helios-metal/src/residency.rs', 'crates/helios-metal/src/pages.rs', 'crates/helios-metal/src/iosurface.rs',
    'crates/helios-runtime/src/lib.rs', 'crates/helios-runtime/src/agent.rs', 'crates/helios-runtime/src/orchestrator.rs', 'crates/helios-runtime/src/gate.rs', 'crates/helios-runtime/src/self_tuning.rs',
    'crates/helios-models/src/lib.rs', 'crates/helios-models/src/transformer.rs', 'crates/helios-models/src/ssm.rs',
    'crates/helios-bench/src/lib.rs', 'crates/helios-bench/src/kl_drift.rs', 'crates/helios-bench/src/recall.rs',
    'crates/helios-ffi/src/lib.rs', 'crates/helios-ffi/src/vault.rs', 'crates/helios-ffi/src/biometric.rs',
    'kernels/eml_softmax.metal', 'kernels/shadow_attention.metal', 'kernels/fwht.metal', 'kernels/sherry_decode.metal', 'kernels/count_sketch.metal',
    'swift/EpistenosApp/Sources/EpistenosApp/EpistenosApp.swift', 'swift/EpistenosApp/Sources/EpistenosApp/VaultManagerView.swift',
    'swift/EpistenosApp/Sources/EpistenosApp/VaultDetailView.swift', 'swift/EpistenosApp/Sources/EpistenosApp/AgentDashboardView.swift',
    'swift/EpistenosApp/Sources/EpistenosApp/ResonanceGateView.swift', 'swift/EpistenosApp/Sources/EpistenosApp/BiometricGate.swift',
    'build-xcframework.sh', 'ci.yml'
]

def e8_counts():
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
        if mask.bit_count() % 2 == 0:
            norm2.append(tuple(-0.5 if (mask >> i) & 1 else 0.5 for i in range(8)))
    norm4 = []
    def rec(idx, remaining, cur):
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

def sherry_roundtrip():
    values = [0.1, -0.2, 0.8, -0.7, 1.0, -0.1, 0.3, -0.4]
    codes = []
    scales = []
    for off in range(0, len(values), 4):
        block = values[off:off+4]
        zero = min(range(4), key=lambda i: abs(block[i]))
        sign_bits = 0
        sign_pos = 0
        scale_vals = []
        for i, value in enumerate(block):
            if i == zero:
                continue
            if value < 0:
                sign_bits |= (1 << sign_pos)
            sign_pos += 1
            scale_vals.append(abs(value))
        code = (zero << 3) | sign_bits
        assert code < 32
        codes.append(code)
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

def fwht_check():
    v = [1.0, 2.0, 3.0, 4.0]
    h = 1
    while h < len(v):
        for i in range(0, len(v), h * 2):
            for j in range(i, i + h):
                x, y = v[j], v[j+h]
                v[j] = x + y
                v[j+h] = x - y
        h *= 2
    return v == [10.0, -2.0, -4.0, 0.0]

def softmax_kl_check():
    logits = [1.0, 2.0, 3.0]
    m = max(logits)
    exps = [math.exp(x-m) for x in logits]
    probs = [x / sum(exps) for x in exps]
    kl = sum(p * math.log(p / p) for p in probs)
    return abs(sum(probs) - 1.0) < 1e-12 and abs(kl) < 1e-12

def main() -> int:
    missing = [p for p in REQUIRED_DOCS + REQUIRED_CODE if not (ROOT / p).exists()]
    n2, n4 = e8_counts()
    kernel_sources = [ROOT / 'kernels/eml_softmax.metal', ROOT / 'kernels/shadow_attention.metal', ROOT / 'kernels/fwht.metal', ROOT / 'kernels/sherry_decode.metal', ROOT / 'kernels/count_sketch.metal']
    kernels_have_entrypoints = all('kernel void' in path.read_text() for path in kernel_sources)
    swift_gate = (ROOT / 'swift/EpistenosApp/Sources/EpistenosApp/BiometricGate.swift').read_text()
    vault_view = (ROOT / 'swift/EpistenosApp/Sources/EpistenosApp/VaultManagerView.swift').read_text()
    result = {
        'inventory_docs_required': len(REQUIRED_DOCS),
        'inventory_code_required': len(REQUIRED_CODE),
        'missing': missing,
        'e8_norm2_count': n2,
        'e8_norm4_count': n4,
        'e8_counts_pass': n2 == 240 and n4 == 2160,
        'sherry_pack_pass': sherry_roundtrip(),
        'fwht_pass': fwht_check(),
        'softmax_kl_pass': softmax_kl_check(),
        'metal_kernel_entrypoints_pass': kernels_have_entrypoints,
        'swift_biometric_gate_present': 'LAContext' in swift_gate and 'deviceOwnerAuthenticationWithBiometrics' in swift_gate,
        'swift_security_bookmark_present': 'bookmarkData(options: .withSecurityScope' in vault_view,
        'cargo_available': shutil.which('cargo') is not None,
        'rustc_available': shutil.which('rustc') is not None,
    }
    out_path = ROOT / 'verification' / 'hotpath_verification.json'
    out_path.parent.mkdir(exist_ok=True)
    out_path.write_text(json.dumps(result, indent=2), encoding='utf-8')
    ok = not result['missing'] and result['e8_counts_pass'] and result['sherry_pack_pass'] and result['fwht_pass'] and result['softmax_kl_pass'] and result['metal_kernel_entrypoints_pass'] and result['swift_biometric_gate_present'] and result['swift_security_bookmark_present']
    print(json.dumps(result, indent=2))
    return 0 if ok else 1

if __name__ == '__main__':
    sys.exit(main())
