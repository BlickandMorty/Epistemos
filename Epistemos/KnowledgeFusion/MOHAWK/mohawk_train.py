#!/usr/bin/env python3
"""
MOHAWK Distillation Pipeline — Epistemos Hybrid Mamba-2
=======================================================

3-stage progressive distillation from transformer teacher to hybrid student.
Runs on RunPod A100/H100. NOT for local execution.

Architecture: 75% Mamba-2 layers + 25% Attention layers (every 4th)
Teacher: Llama 3.2 1B (Nano) | Llama 3.1 8B (Base) | Llama 3.1 70B (Pro)

Usage:
    python mohawk_train.py --stage all --tier nano --output-dir /workspace/mohawk_nano
    python mohawk_train.py --stage 1 --tier nano --dry-run
"""

import argparse
import json
import math
import os
import sys
import time
from dataclasses import dataclass, asdict
from typing import Dict

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader, IterableDataset

# ─── Configuration ─────────────────────────────────────────────

@dataclass
class TierConfig:
    name: str
    student_params: str
    teacher_model: str
    teacher_params: str
    mamba_layers: int
    attention_layers: int
    hidden_dim: int
    num_heads: int
    state_dim: int
    vocab_size: int
    intermediate_dim: int = 0
    stage1_tokens: int = 0
    stage2_tokens: int = 0
    stage3_tokens: int = 0
    batch_size: int = 32
    learning_rate: float = 3e-4
    warmup_steps: int = 2000
    save_every_steps: int = 1000
    seq_len: int = 2048

    def __post_init__(self):
        if self.intermediate_dim == 0:
            self.intermediate_dim = int(self.hidden_dim * 2.67)

    @property
    def total_layers(self) -> int:
        return self.mamba_layers + self.attention_layers

TIER_CONFIGS = {
    "nano": TierConfig(
        name="Epistemos-Nano", student_params="1B",
        teacher_model="meta-llama/Llama-3.2-1B-Instruct", teacher_params="1B",
        mamba_layers=18, attention_layers=6, hidden_dim=2048, num_heads=16,
        state_dim=128, vocab_size=128256,
        stage1_tokens=300_000_000, stage2_tokens=3_000_000_000,
        stage3_tokens=5_000_000_000, batch_size=32, learning_rate=3e-4,
        warmup_steps=2000, save_every_steps=1000,
    ),
    "base": TierConfig(
        name="Epistemos-Base", student_params="3B",
        teacher_model="meta-llama/Llama-3.1-8B-Instruct", teacher_params="8B",
        mamba_layers=24, attention_layers=8, hidden_dim=3072, num_heads=24,
        state_dim=128, vocab_size=128256,
        stage1_tokens=500_000_000, stage2_tokens=5_000_000_000,
        stage3_tokens=6_500_000_000, batch_size=16, learning_rate=2e-4,
        warmup_steps=3000, save_every_steps=1000,
    ),
    "pro": TierConfig(
        name="Epistemos-Pro", student_params="8B",
        teacher_model="meta-llama/Llama-3.1-70B-Instruct", teacher_params="70B",
        mamba_layers=36, attention_layers=12, hidden_dim=4096, num_heads=32,
        state_dim=128, vocab_size=128256,
        stage1_tokens=500_000_000, stage2_tokens=5_000_000_000,
        stage3_tokens=6_500_000_000, batch_size=8, learning_rate=1e-4,
        warmup_steps=4000, save_every_steps=500,
    ),
}

DATA_MIX = {
    "stage1": {"slimpajama": 0.40, "starcoder": 0.20, "dolma_wiki": 0.20, "tool_calls": 0.20},
    "stage2": {"slimpajama": 0.35, "starcoder": 0.20, "dolma_wiki": 0.15, "openorca": 0.15, "tool_calls": 0.15},
    "stage3": {"slimpajama": 0.25, "starcoder": 0.15, "dolma_wiki": 0.10, "openorca": 0.20, "tool_calls": 0.15, "epistemos_vault": 0.15},
}

DATASET_MAP = {
    "slimpajama": "cerebras/SlimPajama-627B",
    "starcoder": "bigcode/starcoderdata",
    "dolma_wiki": "allenai/dolma",
    "openorca": "Open-Orca/OpenOrca",
    "tool_calls": "glaiveai/glaive-function-calling-v2",
}

# ─── Model Components ─────────────────────────────────────────

class RMSNorm(nn.Module):
    def __init__(self, dim, eps=1e-6):
        super().__init__()
        self.weight = nn.Parameter(torch.ones(dim))
        self.eps = eps

    def forward(self, x):
        norm = x.float().pow(2).mean(-1, keepdim=True).add(self.eps).rsqrt()
        return (x.float() * norm).type_as(x) * self.weight


class SwiGLUMLP(nn.Module):
    def __init__(self, dim, intermediate_dim):
        super().__init__()
        self.gate_proj = nn.Linear(dim, intermediate_dim, bias=False)
        self.up_proj = nn.Linear(dim, intermediate_dim, bias=False)
        self.down_proj = nn.Linear(intermediate_dim, dim, bias=False)

    def forward(self, x):
        return self.down_proj(F.silu(self.gate_proj(x)) * self.up_proj(x))


class CausalSelfAttention(nn.Module):
    def __init__(self, dim, num_heads):
        super().__init__()
        self.num_heads = num_heads
        self.head_dim = dim // num_heads
        self.q_proj = nn.Linear(dim, dim, bias=False)
        self.k_proj = nn.Linear(dim, dim, bias=False)
        self.v_proj = nn.Linear(dim, dim, bias=False)
        self.o_proj = nn.Linear(dim, dim, bias=False)

    def forward(self, x):
        B, T, C = x.shape
        q = self.q_proj(x).view(B, T, self.num_heads, self.head_dim).transpose(1, 2)
        k = self.k_proj(x).view(B, T, self.num_heads, self.head_dim).transpose(1, 2)
        v = self.v_proj(x).view(B, T, self.num_heads, self.head_dim).transpose(1, 2)
        out = F.scaled_dot_product_attention(q, k, v, is_causal=True)
        return self.o_proj(out.transpose(1, 2).contiguous().view(B, T, C))


class Mamba2Block(nn.Module):
    """Mamba-2 SSM block. Uses mamba_ssm.Mamba2 if available, else pure-PyTorch fallback."""
    def __init__(self, dim, state_dim):
        super().__init__()
        self._use_cuda = False
        try:
            from mamba_ssm import Mamba2
            self.mamba = Mamba2(d_model=dim, d_state=state_dim, d_conv=4, expand=2)
            self._use_cuda = True
        except ImportError:
            expand = 2
            inner = dim * expand
            self.in_proj = nn.Linear(dim, inner * 2, bias=False)
            self.conv1d = nn.Conv1d(inner, inner, kernel_size=4, padding=3, groups=inner)
            self.out_proj = nn.Linear(inner, dim, bias=False)
            self.dt_proj = nn.Linear(inner, inner, bias=True)
            self.D = nn.Parameter(torch.ones(inner))

    def forward(self, x):
        if self._use_cuda:
            return self.mamba(x)
        B, T, D = x.shape
        xz = self.in_proj(x)
        x_inner, z = xz.chunk(2, dim=-1)
        x_conv = self.conv1d(x_inner.transpose(1, 2))[:, :, :T].transpose(1, 2)
        x_conv = F.silu(x_conv)
        dt = F.softplus(self.dt_proj(x_conv))
        y = x_conv * self.D + x_conv * torch.sigmoid(dt)
        y = y * F.silu(z)
        return self.out_proj(y)


class HybridBlock(nn.Module):
    def __init__(self, dim, num_heads, state_dim, intermediate_dim, use_attention):
        super().__init__()
        self.use_attention = use_attention
        self.norm1 = RMSNorm(dim)
        self.mixer = CausalSelfAttention(dim, num_heads) if use_attention else Mamba2Block(dim, state_dim)
        self.norm2 = RMSNorm(dim)
        self.mlp = SwiGLUMLP(dim, intermediate_dim)

    def forward(self, x):
        h = x + self.mixer(self.norm1(x))
        return h + self.mlp(self.norm2(h))


class HybridMambaModel(nn.Module):
    """75% Mamba-2 + 25% Attention hybrid. Attention every 4th layer."""
    def __init__(self, config: TierConfig):
        super().__init__()
        self.config = config
        self.embed = nn.Embedding(config.vocab_size, config.hidden_dim)
        self.norm_f = RMSNorm(config.hidden_dim)
        self.lm_head = nn.Linear(config.hidden_dim, config.vocab_size, bias=False)
        self.lm_head.weight = self.embed.weight  # Tie

        self.layers = nn.ModuleList([
            HybridBlock(config.hidden_dim, config.num_heads, config.state_dim,
                        config.intermediate_dim, use_attention=(i % 4 == 3))
            for i in range(config.total_layers)
        ])

        total = sum(p.numel() for p in self.parameters())
        mamba_n = sum(1 for l in self.layers if not l.use_attention)
        attn_n = sum(1 for l in self.layers if l.use_attention)
        print(f"  Student: {total / 1e9:.2f}B params, {mamba_n} Mamba + {attn_n} Attn layers")

    def forward(self, input_ids, output_hidden_states=False):
        x = self.embed(input_ids)
        hiddens = [x] if output_hidden_states else None
        for layer in self.layers:
            x = layer(x)
            if output_hidden_states:
                hiddens.append(x)
        x = self.norm_f(x)
        logits = self.lm_head(x)
        return (logits, hiddens) if output_hidden_states else logits

    def mamba_mixing_params(self):
        params = []
        for l in self.layers:
            if not l.use_attention:
                params.extend(l.mixer.parameters())
        return params

    def attn_layer_indices(self):
        return [i for i, l in enumerate(self.layers) if l.use_attention]


# ─── Dataset ──────────────────────────────────────────────────

class MixedStreamDataset(IterableDataset):
    def __init__(self, mix, tokenizer, seq_len, seed=42):
        self.mix = mix
        self.tokenizer = tokenizer
        self.seq_len = seq_len
        self.seed = seed

    def __iter__(self):
        from datasets import load_dataset
        import random
        rng = random.Random(self.seed)

        streams = {}
        for name, ratio in self.mix.items():
            if ratio <= 0 or name == "epistemos_vault":
                continue
            hf = DATASET_MAP.get(name)
            if not hf:
                continue
            try:
                ds = load_dataset(hf, split="train", streaming=True, trust_remote_code=True)
                streams[name] = (iter(ds), ratio)
            except Exception as e:
                print(f"  Warn: {name}: {e}")

        if not streams:
            raise RuntimeError("No datasets loaded")

        names = list(streams.keys())
        weights = [streams[n][1] for n in names]
        tw = sum(weights)
        weights = [w / tw for w in weights]
        buf = []

        while True:
            name = rng.choices(names, weights=weights, k=1)[0]
            it, _ = streams[name]
            try:
                item = next(it)
            except StopIteration:
                ds = load_dataset(DATASET_MAP[name], split="train", streaming=True, trust_remote_code=True)
                streams[name] = (iter(ds), streams[name][1])
                continue

            text = item.get("text") or item.get("content") or item.get("instruction", "")
            if not text:
                continue
            buf.extend(self.tokenizer.encode(text, add_special_tokens=False))
            while len(buf) >= self.seq_len + 1:
                chunk = buf[: self.seq_len + 1]
                buf = buf[self.seq_len:]
                yield {"input_ids": torch.tensor(chunk[:-1]), "labels": torch.tensor(chunk[1:])}


# ─── Utilities ─────────────────────────────────────────────────

def cosine_lr(step, warmup, max_lr, total):
    if step < warmup:
        return max_lr * step / warmup
    return max_lr * 0.5 * (1 + math.cos(math.pi * (step - warmup) / max(1, total - warmup)))


def save_ckpt(model, opt, step, loss, out_dir, tag="checkpoint"):
    path = os.path.join(out_dir, f"{tag}-{step}")
    os.makedirs(path, exist_ok=True)
    torch.save({"model": model.state_dict(), "opt": opt.state_dict(),
                "step": step, "loss": loss}, os.path.join(path, "checkpoint.pt"))
    torch.save(model.state_dict(), os.path.join(path, "model.safetensors"))
    with open(os.path.join(path, "config.json"), "w") as f:
        json.dump({"model_type": "hybrid_mamba2", "step": step}, f)
    print(f"  Saved: {path}")
    return path


def load_ckpt(model, opt, path):
    ck = torch.load(os.path.join(path, "checkpoint.pt"), map_location="cpu", weights_only=False)
    model.load_state_dict(ck["model"])
    if opt:
        opt.load_state_dict(ck["opt"])
    return ck["step"], ck["loss"]


def init_wandb(config, stage):
    try:
        import wandb
        wandb.init(project="epistemos-mohawk", name=f"{config.name}-s{stage}",
                   config={**asdict(config), "stage": stage})
        return True
    except Exception:
        return False


def log_step(step, total, loss, lr, t0, bs, sl, wb, extra=None):
    elapsed = time.time() - t0
    tps = (step * bs * sl) / elapsed
    eta = (total - step) / (step / elapsed) / 3600
    msg = f"  {step}/{total} | loss={loss:.4f} | lr={lr:.2e} | {tps:.0f} tok/s | ETA: {eta:.1f}h"
    if extra:
        msg += f" | {extra}"
    print(msg)
    if wb:
        import wandb
        d = {"loss": loss, "lr": lr, "tokens_per_sec": tps, "step": step}
        if extra:
            d["extra"] = extra
        wandb.log(d)


# ─── Stage 1: Matrix Orientation ──────────────────────────────

def stage1(config, checkpoint=None, out="stage1"):
    """Train ONLY Mamba mixing params. Loss: MSE vs teacher hidden states."""
    print(f"\n{'='*60}\n  Stage 1: Matrix Orientation\n  {config.name} | Teacher: {config.teacher_model}\n{'='*60}")
    os.makedirs(out, exist_ok=True)
    json.dump({"stage": 1, "config": asdict(config), "mix": DATA_MIX["stage1"]},
              open(f"{out}/config.json", "w"), indent=2)

    dev = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    wb = init_wandb(config, 1)

    from transformers import AutoModelForCausalLM, AutoTokenizer
    tok = AutoTokenizer.from_pretrained(config.teacher_model)
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token

    teacher = AutoModelForCausalLM.from_pretrained(
        config.teacher_model, torch_dtype=torch.bfloat16, device_map="auto", output_hidden_states=True)
    teacher.eval()

    student = HybridMambaModel(config).to(dev, torch.bfloat16)
    if checkpoint:
        load_ckpt(student, None, checkpoint)

    for p in student.parameters():
        p.requires_grad = False
    mp = student.mamba_mixing_params()
    for p in mp:
        p.requires_grad = True
    print(f"  Trainable: {sum(p.numel() for p in mp) / 1e6:.1f}M (Mamba mixing only)")

    opt = torch.optim.AdamW(mp, lr=config.learning_rate, weight_decay=0.01)
    loader = DataLoader(MixedStreamDataset(DATA_MIX["stage1"], tok, config.seq_len),
                        batch_size=config.batch_size, num_workers=2, pin_memory=True)

    total = config.stage1_tokens // (config.batch_size * config.seq_len)
    step, rl, t0 = 0, 0.0, time.time()
    n_teacher = None

    for batch in loader:
        if step >= total:
            break
        ids = batch["input_ids"].to(dev)

        with torch.no_grad():
            th = teacher(ids, output_hidden_states=True).hidden_states
            if n_teacher is None:
                n_teacher = len(th) - 1

        _, sh = student(ids, output_hidden_states=True)

        loss = torch.tensor(0.0, device=dev, dtype=torch.float32)
        for si in range(config.total_layers):
            if student.layers[si].use_attention:
                continue
            ti = min(int((si / config.total_layers) * n_teacher) + 1, len(th) - 1)
            s, t = sh[si + 1].float(), th[ti].float()
            if s.shape[-1] != t.shape[-1]:
                t = F.adaptive_avg_pool1d(t.transpose(1, 2), s.shape[-1]).transpose(1, 2)
            loss = loss + F.mse_loss(s, t)
        loss = loss / max(1, config.mamba_layers)

        opt.zero_grad()
        loss.backward()
        torch.nn.utils.clip_grad_norm_(mp, 1.0)
        lr = cosine_lr(step, config.warmup_steps, config.learning_rate, total)
        for pg in opt.param_groups:
            pg["lr"] = lr
        opt.step()

        rl += loss.item()
        step += 1
        if step % 100 == 0:
            log_step(step, total, rl / 100, lr, t0, config.batch_size, config.seq_len, wb)
            rl = 0.0
        if step % config.save_every_steps == 0:
            save_ckpt(student, opt, step, loss.item(), out)

    fp = save_ckpt(student, opt, step, loss.item(), out, "checkpoint-final")
    hrs = (time.time() - t0) / 3600
    json.dump({"stage": 1, "status": "completed", "steps": step, "loss": loss.item(), "hours": hrs},
              open(f"{out}/training_metadata.json", "w"), indent=2)
    if wb:
        import wandb; wandb.finish()
    return fp


# ─── Stage 2: Hidden-State Alignment ─────────────────────────

def stage2(config, checkpoint, out="stage2"):
    """All params trainable. Loss: cosine + L2 at attention layer positions."""
    print(f"\n{'='*60}\n  Stage 2: Hidden-State Alignment\n  From: {checkpoint}\n{'='*60}")
    os.makedirs(out, exist_ok=True)
    json.dump({"stage": 2, "config": asdict(config), "mix": DATA_MIX["stage2"], "ckpt": checkpoint},
              open(f"{out}/config.json", "w"), indent=2)

    dev = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    wb = init_wandb(config, 2)

    from transformers import AutoModelForCausalLM, AutoTokenizer
    tok = AutoTokenizer.from_pretrained(config.teacher_model)
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token

    teacher = AutoModelForCausalLM.from_pretrained(
        config.teacher_model, torch_dtype=torch.bfloat16, device_map="auto", output_hidden_states=True)
    teacher.eval()
    t_dim = teacher.config.hidden_size

    student = HybridMambaModel(config).to(dev, torch.bfloat16)
    load_ckpt(student, None, checkpoint)
    for p in student.parameters():
        p.requires_grad = True

    # Projection layers for dim mismatch
    attn_idx = student.attn_layer_indices()
    projs = nn.ModuleList([
        nn.Linear(t_dim, config.hidden_dim, bias=False).to(dev, torch.bfloat16) if t_dim != config.hidden_dim
        else nn.Identity()
        for _ in attn_idx
    ])

    all_p = list(student.parameters()) + list(projs.parameters())
    lr_base = config.learning_rate * 0.3
    opt = torch.optim.AdamW(all_p, lr=lr_base, weight_decay=0.01)
    loader = DataLoader(MixedStreamDataset(DATA_MIX["stage2"], tok, config.seq_len),
                        batch_size=config.batch_size, num_workers=2, pin_memory=True)

    total = config.stage2_tokens // (config.batch_size * config.seq_len)
    step, rl, t0 = 0, 0.0, time.time()
    n_teacher = None

    for batch in loader:
        if step >= total:
            break
        ids = batch["input_ids"].to(dev)

        with torch.no_grad():
            th = teacher(ids, output_hidden_states=True).hidden_states
            if n_teacher is None:
                n_teacher = len(th) - 1

        _, sh = student(ids, output_hidden_states=True)

        loss = torch.tensor(0.0, device=dev, dtype=torch.float32)
        for idx, si in enumerate(attn_idx):
            ti = min(int((si / config.total_layers) * n_teacher) + 1, len(th) - 1)
            s, t = sh[si + 1].float(), projs[idx](th[ti].float())
            loss = loss + (1 - F.cosine_similarity(s, t, dim=-1).mean()) + 0.1 * F.mse_loss(s, t)
        loss = loss / max(1, len(attn_idx))

        opt.zero_grad()
        loss.backward()
        torch.nn.utils.clip_grad_norm_(all_p, 1.0)
        lr = cosine_lr(step, config.warmup_steps, lr_base, total)
        for pg in opt.param_groups:
            pg["lr"] = lr
        opt.step()

        rl += loss.item()
        step += 1
        if step % 100 == 0:
            log_step(step, total, rl / 100, lr, t0, config.batch_size, config.seq_len, wb)
            rl = 0.0
        if step % config.save_every_steps == 0:
            save_ckpt(student, opt, step, loss.item(), out)

    fp = save_ckpt(student, opt, step, loss.item(), out, "checkpoint-final")
    hrs = (time.time() - t0) / 3600
    json.dump({"stage": 2, "status": "completed", "steps": step, "loss": loss.item(), "hours": hrs},
              open(f"{out}/training_metadata.json", "w"), indent=2)
    if wb:
        import wandb; wandb.finish()
    return fp


# ─── Stage 3: Knowledge Distillation ─────────────────────────

def stage3(config, checkpoint, out="stage3"):
    """All params. Loss: KL(teacher||student) + CE(labels). T=2, alpha=0.7."""
    print(f"\n{'='*60}\n  Stage 3: Knowledge Distillation\n  From: {checkpoint}\n{'='*60}")
    os.makedirs(out, exist_ok=True)
    json.dump({"stage": 3, "config": asdict(config), "mix": DATA_MIX["stage3"], "ckpt": checkpoint},
              open(f"{out}/config.json", "w"), indent=2)

    dev = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    wb = init_wandb(config, 3)

    from transformers import AutoModelForCausalLM, AutoTokenizer
    tok = AutoTokenizer.from_pretrained(config.teacher_model)
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token

    teacher = AutoModelForCausalLM.from_pretrained(
        config.teacher_model, torch_dtype=torch.bfloat16, device_map="auto")
    teacher.eval()

    student = HybridMambaModel(config).to(dev, torch.bfloat16)
    load_ckpt(student, None, checkpoint)
    for p in student.parameters():
        p.requires_grad = True

    lr_base = config.learning_rate * 0.1
    opt = torch.optim.AdamW(student.parameters(), lr=lr_base, weight_decay=0.01)
    loader = DataLoader(MixedStreamDataset(DATA_MIX["stage3"], tok, config.seq_len),
                        batch_size=config.batch_size, num_workers=2, pin_memory=True)

    total = config.stage3_tokens // (config.batch_size * config.seq_len)
    T, alpha = 2.0, 0.7
    step, rl, rk, rc, t0 = 0, 0.0, 0.0, 0.0, time.time()

    for batch in loader:
        if step >= total:
            break
        ids = batch["input_ids"].to(dev)
        labels = batch["labels"].to(dev)

        with torch.no_grad():
            tl = teacher(ids).logits.float()

        sl = student(ids).float()

        # KL on soft targets
        tp = F.softmax(tl / T, dim=-1)
        slp = F.log_softmax(sl / T, dim=-1)
        mv = min(tp.shape[-1], slp.shape[-1])
        kd = F.kl_div(slp[..., :mv], tp[..., :mv], reduction="batchmean") * (T ** 2)

        # CE on hard targets
        ce = F.cross_entropy(sl.view(-1, sl.size(-1)), labels.view(-1), ignore_index=-100)
        loss = alpha * kd + (1 - alpha) * ce

        opt.zero_grad()
        loss.backward()
        torch.nn.utils.clip_grad_norm_(student.parameters(), 1.0)
        lr = cosine_lr(step, config.warmup_steps, lr_base, total)
        for pg in opt.param_groups:
            pg["lr"] = lr
        opt.step()

        rl += loss.item()
        rk += kd.item()
        rc += ce.item()
        step += 1
        if step % 100 == 0:
            log_step(step, total, rl / 100, lr, t0, config.batch_size, config.seq_len, wb,
                     f"kd={rk / 100:.4f} ce={rc / 100:.4f}")
            rl = rk = rc = 0.0
        if step % config.save_every_steps == 0:
            save_ckpt(student, opt, step, loss.item(), out)

    fp = save_ckpt(student, opt, step, loss.item(), out, "checkpoint-final")
    hrs = (time.time() - t0) / 3600
    json.dump({"stage": 3, "status": "completed", "steps": step, "loss": loss.item(),
               "kd": kd.item(), "ce": ce.item(), "hours": hrs},
              open(f"{out}/training_metadata.json", "w"), indent=2)
    if wb:
        import wandb; wandb.finish()
    return fp


# ─── Conversion ────────────────────────────────────────────────

def convert_to_mlx(ckpt, out="mlx_model"):
    import subprocess
    os.makedirs(out, exist_ok=True)
    r = subprocess.run(["python", "-m", "mlx_lm.convert", "--hf-path", ckpt, "--mlx-path", out, "-q"],
                       capture_output=True, text=True)
    print(f"  MLX: {'done' if r.returncode == 0 else r.stderr[:200]}")


# ─── Main ──────────────────────────────────────────────────────

def main():
    p = argparse.ArgumentParser(description="MOHAWK Distillation")
    p.add_argument("--stage", required=True, help="1, 2, 3, or 'all'")
    p.add_argument("--tier", required=True, choices=["nano", "base", "pro"])
    p.add_argument("--checkpoint", help="Checkpoint from previous stage")
    p.add_argument("--output-dir", default="./mohawk_output")
    p.add_argument("--convert-mlx", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    a = p.parse_args()

    c = TIER_CONFIGS[a.tier]
    d = a.output_dir

    if a.dry_run:
        print(json.dumps(asdict(c), indent=2))
        for s, m in DATA_MIX.items():
            print(f"  {s}: {m}")
        tok_s = 50_000  # A100 throughput estimate
        cost_hr = 1.19
        s1h = c.stage1_tokens / (tok_s * 3600)
        s2h = c.stage2_tokens / (tok_s * 3600)
        s3h = c.stage3_tokens / (tok_s * 3600)
        th = s1h + s2h + s3h
        print(f"\n  S1: {c.stage1_tokens // (c.batch_size * c.seq_len):,} steps, ~{s1h:.1f}h, ~${s1h * cost_hr:.0f}")
        print(f"  S2: {c.stage2_tokens // (c.batch_size * c.seq_len):,} steps, ~{s2h:.1f}h, ~${s2h * cost_hr:.0f}")
        print(f"  S3: {c.stage3_tokens // (c.batch_size * c.seq_len):,} steps, ~{s3h:.1f}h, ~${s3h * cost_hr:.0f}")
        print(f"  Total: {(c.stage1_tokens + c.stage2_tokens + c.stage3_tokens) / 1e9:.1f}B tok, ~{th:.0f}h, ~${th * cost_hr:.0f}")
        print(f"\n  Arch: {c.total_layers} layers ({c.mamba_layers} Mamba + {c.attention_layers} Attn)")
        print(f"  Dim: {c.hidden_dim}, Heads: {c.num_heads}, SSM state: {c.state_dim}")
        return

    if a.stage == "all":
        cp1 = stage1(c, output_dir=f"{d}/stage1")
        cp2 = stage2(c, cp1, out=f"{d}/stage2")
        cp3 = stage3(c, cp2, out=f"{d}/stage3")
        if a.convert_mlx:
            convert_to_mlx(cp3, f"{d}/mlx_model")
    elif a.stage == "1":
        stage1(c, a.checkpoint, f"{d}/stage1")
    elif a.stage == "2":
        assert a.checkpoint, "Stage 2 needs --checkpoint"
        stage2(c, a.checkpoint, f"{d}/stage2")
    elif a.stage == "3":
        assert a.checkpoint, "Stage 3 needs --checkpoint"
        stage3(c, a.checkpoint, f"{d}/stage3")


if __name__ == "__main__":
    main()
