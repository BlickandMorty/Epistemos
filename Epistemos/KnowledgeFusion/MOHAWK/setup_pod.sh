#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Pod Setup Script — runs ON the RunPod instance
# Upload this, then run: bash setup_pod.sh
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

echo "═══════════════════════════════════════════════════════"
echo "  Epistemos MOHAWK — Pod Setup"
echo "═══════════════════════════════════════════════════════"

# 1. Install Python deps
echo ""
echo "📦 Installing dependencies..."
pip install -q --upgrade pip
pip install -q torch torchvision torchaudio  # Usually pre-installed on RunPod
pip install -q transformers datasets safetensors wandb accelerate
pip install -q mamba-ssm causal-conv1d
pip install -q flash-attn --no-build-isolation 2>/dev/null || echo "⚠️  flash-attn failed (optional, continuing)"

# 2. Verify GPU
echo ""
echo "🔍 GPU check:"
python3 -c "
import torch
print(f'  CUDA available: {torch.cuda.is_available()}')
print(f'  GPU: {torch.cuda.get_device_name(0)}')
print(f'  VRAM: {torch.cuda.get_device_properties(0).total_mem / 1e9:.1f} GB')
"

# 3. Verify mamba-ssm
echo ""
echo "🐍 Mamba check:"
python3 -c "
try:
    from mamba_ssm import Mamba2
    print('  ✅ mamba-ssm with Mamba2 available')
except ImportError as e:
    print(f'  ❌ mamba-ssm import failed: {e}')
    print('  Trying: pip install mamba-ssm --no-build-isolation')
    import subprocess
    subprocess.run(['pip', 'install', 'mamba-ssm', '--no-build-isolation'])
"

# 4. Create output dirs
mkdir -p /workspace/mohawk_output
mkdir -p /workspace/vault_data

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ✅ Setup complete!"
echo ""
echo "  Dry run:  python /workspace/mohawk_train.py --stage all --tier nano --dry-run"
echo "  Train:    tmux new -s train 'python /workspace/mohawk_train.py --stage all --tier nano --output-dir /workspace/mohawk_output'"
echo "═══════════════════════════════════════════════════════"
