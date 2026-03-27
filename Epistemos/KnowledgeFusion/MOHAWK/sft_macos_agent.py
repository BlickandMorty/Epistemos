#!/usr/bin/env python3
"""
Post-MOHAWK SFT — Specialize the base model into a macOS device agent
======================================================================

Runs AFTER mohawk_train.py completes all 3 stages.
Takes the distilled base model and fine-tunes it on:
  1. Epistemos app-specific data (Code Graph + Symbol QA + AX Atlas + Trajectories)
  2. Comprehensive macOS tool-calling examples
  3. Negative examples (when NOT to call a tool)
  4. Error recovery examples

Uses LoRA rank 16 (per training non-negotiables) with WSD scheduler.
Never fuses adapters into base — hot-swap via MoLoRA routing.

Usage (on RunPod after MOHAWK):
    # Data is uploaded by runpod_full_pipeline.sh (always validated, never raw)
    # Remote path: /workspace/epistemos_validated (contains validated data only)

    python sft_macos_agent.py --base-model /workspace/mohawk_output/stage3/checkpoint-final \\
                              --data-dir /workspace/epistemos_validated \\
                              --output /workspace/sft_output --lora --lora-rank 16
"""

import argparse
import json
import math
import os
import time
from pathlib import Path

os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader, Dataset


# ─── Configuration ──────────────────────────────────────────────

SFT_DEFAULTS = {
    "learning_rate": 2e-5,           # Lower than MOHAWK — fine-tuning, not training
    "lora_lr": 1e-4,                 # Higher for LoRA adapters
    "warmup_steps": 200,
    "epochs": 3,
    "batch_size": 4,
    "grad_accum_steps": 8,
    "seq_len": 2048,
    "lora_rank": 16,                 # Non-negotiable: not 8 (too constrained), not 32 (overfits)
    "lora_alpha": 32,
    "lora_dropout": 0.05,
    "weight_decay": 0.01,
    "max_grad_norm": 1.0,
    "save_every_steps": 500,
    "eval_every_steps": 200,
    "decay_fraction": 0.2,           # WSD: 80% stable, 20% decay
}

# Data mix for SFT (from NANO-MASTER-TRAINING-GUIDE.md)
SFT_DATA_MIX = {
    "tool_calls":     0.40,   # 40% — tool calling is the core capability
    "general":        0.15,   # 15% — keep general instruction following
    "reasoning":      0.10,   # 10% — chain-of-thought, planning
    "app_specific":   0.20,   # 20% — THE SACRED MOAT (Code Graph + Symbol QA + AX Atlas + Trajectories)
    "negative":       0.10,   # 10% — when NOT to call a tool
    "error_recovery": 0.05,   # 5%  — graceful failure handling
}


# ─── Dataset ────────────────────────────────────────────────────

class SFTDataset(Dataset):
    """Load JSONL files for SFT. Supports chat format (messages array)."""

    def __init__(self, data_dir, tokenizer, seq_len, split="train"):
        self.tokenizer = tokenizer
        self.seq_len = seq_len
        self.examples = []

        # Load all JSONL files
        data_path = Path(data_dir)
        jsonl_file = data_path / f"{split}.jsonl"

        if jsonl_file.exists():
            self._load_jsonl(jsonl_file)
        else:
            # Load individual layer files
            for f in sorted(data_path.glob("*.jsonl")):
                if f.name.startswith("eval") and split == "train":
                    continue
                if f.name.startswith("train") and split == "eval":
                    continue
                self._load_jsonl(f)

        print(f"  SFT {split}: {len(self.examples)} examples from {data_dir}")

    def _load_jsonl(self, path):
        with open(path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    item = json.loads(line)
                    if "messages" in item:
                        self.examples.append(item)
                except json.JSONDecodeError:
                    continue

    def __len__(self):
        return len(self.examples)

    def __getitem__(self, idx):
        item = self.examples[idx]
        messages = item["messages"]

        # Format as Qwen chat template (chatml)
        parts = []
        for msg in messages:
            role = msg.get("role", "")
            content = msg.get("content", "")
            parts.append(f"<|im_start|>{role}\n{content}<|im_end|>")
        text = "\n".join(parts) + "<|im_start|>assistant\n"

        tokens = self.tokenizer.encode(text, add_special_tokens=False)

        # Truncate or pad to seq_len
        if len(tokens) > self.seq_len + 1:
            tokens = tokens[:self.seq_len + 1]
        elif len(tokens) < self.seq_len + 1:
            tokens = tokens + [self.tokenizer.pad_token_id or 0] * (self.seq_len + 1 - len(tokens))

        input_ids = torch.tensor(tokens[:-1])
        labels = torch.tensor(tokens[1:])

        # Mask system and user tokens (only train on assistant responses)
        # Find assistant response boundaries
        full_text = self.tokenizer.decode(tokens)
        assistant_start = full_text.rfind("<|im_start|>assistant\n")
        if assistant_start >= 0:
            prefix_tokens = len(self.tokenizer.encode(full_text[:assistant_start], add_special_tokens=False))
            labels[:prefix_tokens] = -100  # Don't compute loss on non-assistant tokens

        return {"input_ids": input_ids, "labels": labels, "category": item.get("category", "unknown")}


# ─── LoRA ───────────────────────────────────────────────────────

class LoRALinear(nn.Module):
    """LoRA adapter for Linear layers. Rank 16 per training non-negotiables."""

    def __init__(self, base_linear, rank=16, alpha=32, dropout=0.05):
        super().__init__()
        self.base = base_linear
        self.rank = rank
        self.alpha = alpha
        self.scaling = alpha / rank

        in_features = base_linear.in_features
        out_features = base_linear.out_features

        self.lora_A = nn.Parameter(torch.zeros(rank, in_features))
        self.lora_B = nn.Parameter(torch.zeros(out_features, rank))
        self.dropout = nn.Dropout(dropout) if dropout > 0 else nn.Identity()

        # Initialize A with Kaiming, B with zeros (LoRA convention)
        nn.init.kaiming_uniform_(self.lora_A, a=math.sqrt(5))
        nn.init.zeros_(self.lora_B)

        # Freeze base weights
        self.base.weight.requires_grad = False
        if self.base.bias is not None:
            self.base.bias.requires_grad = False

    def forward(self, x):
        base_out = self.base(x)
        lora_out = self.dropout(x) @ self.lora_A.T @ self.lora_B.T * self.scaling
        return base_out + lora_out


def apply_lora(model, rank=16, alpha=32, dropout=0.05, target_modules=None):
    """Apply LoRA to target modules in the model.

    Per Training Guide: LoRA on in_proj, x_proj, dt_proj, out_proj of Mamba blocks
    AND q_proj, k_proj, v_proj, o_proj of Attention blocks.
    """
    if target_modules is None:
        target_modules = [
            # Mamba-2 projections
            "in_proj", "out_proj", "dt_proj",
            # Attention projections
            "q_proj", "k_proj", "v_proj", "o_proj",
            # MLP projections
            "gate_proj", "up_proj", "down_proj",
        ]

    lora_params = []
    replaced = 0

    for name, module in model.named_modules():
        for child_name, child in module.named_children():
            if isinstance(child, nn.Linear) and any(t in child_name for t in target_modules):
                lora_layer = LoRALinear(child, rank=rank, alpha=alpha, dropout=dropout)
                setattr(module, child_name, lora_layer)
                lora_params.extend([lora_layer.lora_A, lora_layer.lora_B])
                replaced += 1

    total_lora = sum(p.numel() for p in lora_params)
    total_base = sum(p.numel() for p in model.parameters())
    print(f"  LoRA: {replaced} layers, {total_lora/1e6:.1f}M params ({total_lora/total_base*100:.1f}% of base)")

    return lora_params


def save_lora_adapter(model, output_dir, step, metadata=None):
    """Save ONLY the LoRA adapter weights — never fuse into base."""
    adapter_dir = os.path.join(output_dir, f"adapter-{step}")
    os.makedirs(adapter_dir, exist_ok=True)

    adapter_state = {}
    for name, param in model.named_parameters():
        if "lora_A" in name or "lora_B" in name:
            adapter_state[name] = param.cpu().detach()

    torch.save(adapter_state, os.path.join(adapter_dir, "adapter.pt"))

    meta = {
        "step": step,
        "rank": SFT_DEFAULTS["lora_rank"],
        "alpha": SFT_DEFAULTS["lora_alpha"],
        "type": "lora_adapter",
        "note": "NEVER fuse into base. Hot-swap via MoLoRA routing only.",
    }
    if metadata:
        meta.update(metadata)
    with open(os.path.join(adapter_dir, "adapter_config.json"), "w") as f:
        json.dump(meta, f, indent=2)

    print(f"  Saved adapter: {adapter_dir}")
    return adapter_dir


# ─── Scheduler ──────────────────────────────────────────────────

def wsd_lr(step, warmup, max_lr, total, decay_fraction=0.2):
    """WSD scheduler — non-negotiable, never cosine."""
    if step < warmup:
        return max_lr * step / warmup
    decay_start = int(total * (1 - decay_fraction))
    if step < decay_start:
        return max_lr
    progress = (step - decay_start) / max(1, total - decay_start)
    return max_lr * (0.1 ** progress)


# ─── Training Loop ──────────────────────────────────────────────

def train_sft(args):
    """Main SFT training loop."""
    print(f"\n{'='*60}")
    print(f"  Post-MOHAWK SFT — macOS Device Agent Specialization")
    print(f"  Base: {args.base_model}")
    print(f"  Data: {args.data_dir}")
    print(f"  LoRA: {'rank ' + str(args.lora_rank) if args.lora else 'disabled (full fine-tune)'}")
    print(f"{'='*60}\n")

    dev = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    # Load tokenizer
    from transformers import AutoTokenizer
    tok = AutoTokenizer.from_pretrained(args.tokenizer or "Qwen/Qwen2.5-1.5B-Instruct")
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token

    # Load base model
    print("Loading base model...")
    ckpt_path = os.path.join(args.base_model, "checkpoint.pt")
    if os.path.exists(ckpt_path):
        # Load our custom HybridMambaModel
        sys_path = os.path.dirname(os.path.abspath(__file__))
        if sys_path not in __import__('sys').path:
            __import__('sys').path.insert(0, sys_path)
        from mohawk_train import HybridMambaModel, TierConfig, TIER_CONFIGS

        config = TIER_CONFIGS[args.tier]
        model = HybridMambaModel(config).to(dev, torch.bfloat16)
        ck = torch.load(ckpt_path, map_location="cpu", weights_only=False)
        model.load_state_dict(ck["model"])
        print(f"  Loaded custom model from {args.base_model}")
    else:
        from transformers import AutoModelForCausalLM
        model = AutoModelForCausalLM.from_pretrained(
            args.base_model, torch_dtype=torch.bfloat16, device_map="auto")
        print(f"  Loaded HF model from {args.base_model}")

    # Apply LoRA if requested
    if args.lora:
        lora_params = apply_lora(model, rank=args.lora_rank, alpha=args.lora_alpha, dropout=args.lora_dropout)
        trainable = lora_params
        lr = args.lora_lr or SFT_DEFAULTS["lora_lr"]
    else:
        for p in model.parameters():
            p.requires_grad = True
        trainable = list(model.parameters())
        lr = args.lr or SFT_DEFAULTS["learning_rate"]

    print(f"  Trainable: {sum(p.numel() for p in trainable) / 1e6:.1f}M params")

    # Datasets
    train_ds = SFTDataset(args.data_dir, tok, args.seq_len, split="train")
    eval_ds = SFTDataset(args.data_dir, tok, args.seq_len, split="eval")

    train_loader = DataLoader(train_ds, batch_size=args.batch_size, shuffle=True,
                              num_workers=2, pin_memory=True, drop_last=True)
    eval_loader = DataLoader(eval_ds, batch_size=args.batch_size, shuffle=False,
                             num_workers=0, pin_memory=True)

    # Optimizer
    opt = torch.optim.AdamW(trainable, lr=lr, weight_decay=args.weight_decay)

    # Training
    os.makedirs(args.output, exist_ok=True)
    eff_bs = args.batch_size * args.grad_accum_steps
    steps_per_epoch = len(train_loader) // args.grad_accum_steps
    total_steps = steps_per_epoch * args.epochs

    print(f"  Epochs: {args.epochs} | Steps/epoch: {steps_per_epoch} | Total: {total_steps}")
    print(f"  Effective batch: {eff_bs} | LR: {lr:.2e}")

    # W&B
    wb = False
    try:
        import wandb
        wandb.init(project="epistemos-sft", name=f"sft-{'lora' if args.lora else 'full'}")
        wb = True
    except Exception:
        pass

    step, global_loss, t0, micro = 0, 0.0, time.time(), 0
    best_eval_loss = float('inf')

    for epoch in range(args.epochs):
        model.train()
        for batch in train_loader:
            if step >= total_steps:
                break

            ids = batch["input_ids"].to(dev)
            labels = batch["labels"].to(dev)

            logits = model(ids)
            if isinstance(logits, tuple):
                logits = logits[0]

            loss = F.cross_entropy(
                logits.view(-1, logits.size(-1)),
                labels.view(-1),
                ignore_index=-100
            ) / args.grad_accum_steps
            loss.backward()

            global_loss += loss.item() * args.grad_accum_steps
            micro += 1

            if micro < args.grad_accum_steps:
                continue
            micro = 0

            torch.nn.utils.clip_grad_norm_(trainable, args.max_grad_norm)
            current_lr = wsd_lr(step, args.warmup_steps, lr, total_steps, args.decay_fraction)
            for pg in opt.param_groups:
                pg["lr"] = current_lr
            opt.step()
            opt.zero_grad()

            step += 1

            # Logging
            if step % 50 == 0:
                elapsed = time.time() - t0
                avg_loss = global_loss / 50
                tps = (step * eff_bs * args.seq_len) / elapsed
                eta = (total_steps - step) / (step / elapsed) / 3600
                print(f"  {step}/{total_steps} | loss={avg_loss:.4f} | lr={current_lr:.2e} | "
                      f"{tps:.0f} tok/s | ETA: {eta:.1f}h | epoch {epoch+1}/{args.epochs}")
                if wb:
                    wandb.log({"loss": avg_loss, "lr": current_lr, "step": step, "epoch": epoch})
                global_loss = 0.0

            # Eval
            if step % args.eval_every_steps == 0 and len(eval_ds) > 0:
                eval_loss = evaluate(model, eval_loader, dev)
                print(f"  EVAL step {step}: loss={eval_loss:.4f} {'(best!)' if eval_loss < best_eval_loss else ''}")
                if wb:
                    wandb.log({"eval_loss": eval_loss, "step": step})
                if eval_loss < best_eval_loss:
                    best_eval_loss = eval_loss
                    if args.lora:
                        save_lora_adapter(model, args.output, step, {"eval_loss": eval_loss, "best": True})
                    else:
                        save_full(model, opt, step, eval_loss, args.output, "best")
                model.train()

            # Checkpoint
            if step % args.save_every_steps == 0:
                if args.lora:
                    save_lora_adapter(model, args.output, step)
                else:
                    save_full(model, opt, step, loss.item(), args.output)

    # Final save
    if args.lora:
        save_lora_adapter(model, args.output, step, {"final": True, "epochs": args.epochs})
    else:
        save_full(model, opt, step, loss.item(), args.output, "final")

    hrs = (time.time() - t0) / 3600
    meta = {
        "type": "sft",
        "mode": "lora" if args.lora else "full",
        "epochs": args.epochs,
        "steps": step,
        "best_eval_loss": best_eval_loss,
        "hours": hrs,
        "data_dir": args.data_dir,
        "base_model": args.base_model,
    }
    with open(os.path.join(args.output, "sft_metadata.json"), "w") as f:
        json.dump(meta, f, indent=2)

    print(f"\n  SFT COMPLETE: {step} steps, {hrs:.1f}h, best eval loss: {best_eval_loss:.4f}")
    if wb:
        wandb.finish()


def evaluate(model, loader, dev):
    """Run evaluation and return average loss."""
    model.eval()
    total_loss, count = 0.0, 0
    with torch.no_grad():
        for batch in loader:
            ids = batch["input_ids"].to(dev)
            labels = batch["labels"].to(dev)
            logits = model(ids)
            if isinstance(logits, tuple):
                logits = logits[0]
            loss = F.cross_entropy(logits.view(-1, logits.size(-1)), labels.view(-1), ignore_index=-100)
            total_loss += loss.item()
            count += 1
            if count >= 50:  # Cap eval at 50 batches
                break
    return total_loss / max(count, 1)


def save_full(model, opt, step, loss, out_dir, tag="checkpoint"):
    """Save full model checkpoint."""
    path = os.path.join(out_dir, f"{tag}-{step}")
    os.makedirs(path, exist_ok=True)
    torch.save({"model": model.state_dict(), "opt": opt.state_dict(),
                "step": step, "loss": loss}, os.path.join(path, "checkpoint.pt"))
    print(f"  Saved: {path}")
    return path


# ─── Main ───────────────────────────────────────────────────────

def main():
    p = argparse.ArgumentParser(description="Post-MOHAWK SFT for macOS Device Agent")
    p.add_argument("--base-model", required=True, help="Path to MOHAWK Stage 3 checkpoint")
    p.add_argument("--data-dir", required=True, help="Path to VALIDATED training data (epistemos_training_data_validated/ locally, /workspace/epistemos_validated on RunPod). Raw data must never be passed here.")
    p.add_argument("--output", default="./sft_output", help="Output directory")
    p.add_argument("--tier", default="nano", choices=["nano", "base", "pro"])
    p.add_argument("--tokenizer", default=None, help="Tokenizer (defaults to teacher model)")

    # LoRA
    p.add_argument("--lora", action="store_true", help="Use LoRA instead of full fine-tune")
    p.add_argument("--lora-rank", type=int, default=SFT_DEFAULTS["lora_rank"])
    p.add_argument("--lora-alpha", type=int, default=SFT_DEFAULTS["lora_alpha"])
    p.add_argument("--lora-dropout", type=float, default=SFT_DEFAULTS["lora_dropout"])
    p.add_argument("--lora-lr", type=float, default=None)

    # Training
    p.add_argument("--lr", type=float, default=None)
    p.add_argument("--epochs", type=int, default=SFT_DEFAULTS["epochs"])
    p.add_argument("--batch-size", type=int, default=SFT_DEFAULTS["batch_size"])
    p.add_argument("--grad-accum-steps", type=int, default=SFT_DEFAULTS["grad_accum_steps"])
    p.add_argument("--seq-len", type=int, default=SFT_DEFAULTS["seq_len"])
    p.add_argument("--warmup-steps", type=int, default=SFT_DEFAULTS["warmup_steps"])
    p.add_argument("--weight-decay", type=float, default=SFT_DEFAULTS["weight_decay"])
    p.add_argument("--max-grad-norm", type=float, default=SFT_DEFAULTS["max_grad_norm"])
    p.add_argument("--save-every-steps", type=int, default=SFT_DEFAULTS["save_every_steps"])
    p.add_argument("--eval-every-steps", type=int, default=SFT_DEFAULTS["eval_every_steps"])
    p.add_argument("--decay-fraction", type=float, default=SFT_DEFAULTS["decay_fraction"])

    args = p.parse_args()
    train_sft(args)


if __name__ == "__main__":
    main()
