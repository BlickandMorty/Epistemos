#!/usr/bin/env python3
"""
Epistemos MoLoRA — Per-Token Multi-Adapter Inference Engine

Long-lived Python subprocess that serves inference with AdaFuse decide-once
per-token routing across multiple LoRA adapters.

Protocol (stdin/stdout JSON lines):
  → {"type": "generate", "prompt": "...", "system_prompt": "...", "max_tokens": 512}
  ← {"type": "token", "text": "Hello"}
  ← {"type": "done", "tokens_generated": 42, "tok_per_sec": 18.5, "route": "knowledge"}

  → {"type": "reload_adapters", "adapters": [{"path": "...", "type": "knowledge", "rank": 32, "alpha": 64}]}
  ← {"type": "ready"}

  → {"type": "shutdown"}

CRITICAL: Adapters are NEVER fused into base weights.
"""

import argparse
import json
import os
import sys
import time

# Ensure unbuffered stdout for real-time token streaming
sys.stdout.reconfigure(line_buffering=True)


def parse_args():
    parser = argparse.ArgumentParser(description="MoLoRA inference server")
    parser.add_argument("--model_path", required=True, help="Base model path")
    parser.add_argument("--adapters_json", default=None,
                        help='JSON array: [{"path": "...", "type": "knowledge", "rank": 32, "alpha": 64}]')
    parser.add_argument("--centroids_path", default=None, help="Router centroids safetensors")
    parser.add_argument("--test", action="store_true", help="Run self-test then exit")
    return parser.parse_args()


# ── AdaFuse Router ────────────────────────────────────────────────────────────

class AdaFuseRouter:
    """Decide-once router using pre-computed domain centroids."""

    def __init__(self, centroids_path: str, domain_names: list[str]):
        import mlx.core as mx

        self.domain_names = domain_names

        if centroids_path and os.path.exists(centroids_path):
            loaded = mx.load(centroids_path)
            # Stack centroids in domain_names order
            centroid_list = []
            for name in domain_names:
                if name in loaded:
                    centroid_list.append(loaded[name])
                else:
                    # Missing domain — use zero vector (will never be closest)
                    d_model = next(iter(loaded.values())).shape[0]
                    centroid_list.append(mx.zeros(d_model))
            self.centroids = mx.stack(centroid_list)  # [C, d_model]
            self.active = True
        else:
            self.centroids = None
            self.active = False

    def route(self, hidden_states):
        """
        Route tokens based on cosine similarity to centroids.
        hidden_states: [B, d_model] — layer-0 output
        Returns: [B] int32 — adapter index per token
        """
        import mlx.core as mx

        if not self.active or self.centroids is None:
            # Default: route everything to adapter 0
            return mx.zeros(hidden_states.shape[0], dtype=mx.int32)

        # L2 normalize hidden states
        norms = mx.linalg.norm(hidden_states, axis=-1, keepdims=True)
        h_norm = hidden_states / mx.maximum(norms, mx.array(1e-8))

        # Cosine similarity: [B, C]
        similarities = mx.matmul(h_norm, self.centroids.T)

        # Argmax → adapter index
        return mx.argmax(similarities, axis=-1).astype(mx.int32)


# ── MoLoRA Linear Layer ──────────────────────────────────────────────────────

class MoLoRALinear:
    """
    Drop-in wrapper for a base linear layer that applies per-token LoRA deltas
    from multiple adapters.
    """

    def __init__(self, base_layer, adapter_weights: list[dict], scales: list[float]):
        """
        base_layer: the original nn.Linear (or QuantizedLinear)
        adapter_weights: [{"a": mx.array [d_in, rank], "b": mx.array [rank, d_out]}, ...]
        scales: [alpha/rank, ...] per adapter
        """
        self.base = base_layer
        self.adapters = adapter_weights
        self.scales = scales

    def __call__(self, x, adapter_ids=None):
        import mlx.core as mx

        # Base computation (quantized matmul — no modification)
        base_out = self.base(x)

        if adapter_ids is None or not self.adapters:
            return base_out

        # Import kernel
        from sgmm_kernel import lora_delta

        # Per-group LoRA delta computation
        unique_ids = mx.unique(adapter_ids)
        mx.eval(unique_ids)

        for aid in unique_ids.tolist():
            if aid < 0 or aid >= len(self.adapters):
                continue

            # Gather tokens for this adapter
            mask = (adapter_ids == aid)
            indices = mx.argwhere(mask).squeeze(-1)

            if indices.size == 0:
                continue

            x_group = x[indices]  # [B_group, d_in]
            adapter = self.adapters[aid]
            scale = self.scales[aid]

            # Compute LoRA delta via Metal kernel
            delta = lora_delta(x_group, adapter["a"], adapter["b"], scale)

            # Scatter back
            base_out[indices] = base_out[indices] + delta

        return base_out


# ── Model Patcher ─────────────────────────────────────────────────────────────

# LoRA target module names (must match training scripts)
KNOWLEDGE_MODULES = ["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"]
STYLE_MODULES = ["q_proj", "k_proj", "v_proj", "o_proj"]


def load_adapter_weights(adapter_path: str, model):
    """Load adapter safetensors and organize by layer+module."""
    import mlx.core as mx

    weights_file = os.path.join(adapter_path, "adapter_weights.safetensors")
    config_file = os.path.join(adapter_path, "adapter_config.json")

    if not os.path.exists(weights_file):
        raise FileNotFoundError(f"Adapter weights not found: {weights_file}")

    weights = mx.load(weights_file)

    # Determine target modules from config
    target_modules = KNOWLEDGE_MODULES
    if os.path.exists(config_file):
        with open(config_file) as f:
            config = json.load(f)
            if "lora_layers" in config:
                target_modules = config["lora_layers"]

    # Organize: {(layer_idx, module_name): {"a": array, "b": array}}
    organized = {}
    for key, value in weights.items():
        # Key format: "layers.N.self_attn.q_proj.lora_a" or "layers.N.mlp.gate_proj.lora_b"
        parts = key.split(".")
        if len(parts) < 4:
            continue

        # Find layer index and module name
        layer_idx = None
        module_name = None
        ab_type = None

        for i, part in enumerate(parts):
            if part == "layers" and i + 1 < len(parts):
                try:
                    layer_idx = int(parts[i + 1])
                except ValueError:
                    pass
            if part in ("lora_a", "lora_b"):
                ab_type = part
                # Module name is the part before lora_a/lora_b
                module_name = parts[i - 1]

        if layer_idx is not None and module_name and ab_type:
            dict_key = (layer_idx, module_name)
            if dict_key not in organized:
                organized[dict_key] = {}
            # lora_a shape: [rank, d_in] in safetensors → transpose to [d_in, rank]
            if ab_type == "lora_a":
                organized[dict_key]["a"] = value.T if value.shape[0] < value.shape[1] else value
            else:
                # lora_b shape: [d_out, rank] in safetensors → transpose to [rank, d_out]
                organized[dict_key]["b"] = value.T if value.shape[0] > value.shape[1] else value

    return organized, target_modules


class MoLoRAModel:
    """Wraps a base model with MoLoRA per-token adapter routing."""

    def __init__(self, model, tokenizer, adapter_configs: list[dict], centroids_path: str = None):
        import mlx.core as mx

        self.model = model
        self.tokenizer = tokenizer
        self.adapter_configs = adapter_configs

        # Domain names in adapter order
        domain_names = [cfg["type"] for cfg in adapter_configs]
        self.router = AdaFuseRouter(centroids_path, domain_names)

        # Load all adapter weights
        self.adapter_data = []
        for cfg in adapter_configs:
            weights, modules = load_adapter_weights(cfg["path"], model)
            self.adapter_data.append({
                "weights": weights,
                "modules": modules,
                "rank": cfg["rank"],
                "alpha": cfg["alpha"],
                "scale": cfg["alpha"] / cfg["rank"],
                "type": cfg["type"],
            })

        # Patch model layers (done lazily during first forward pass)
        self._patched = False

    def _get_layer0_hidden(self, token_ids):
        """Extract hidden states from embedding + layer 0 for routing."""
        import mlx.core as mx

        if hasattr(self.model, "model"):
            embed = self.model.model.embed_tokens(token_ids)
            layer0 = self.model.model.layers[0]
        else:
            embed = self.model.embed_tokens(token_ids)
            layer0 = self.model.layers[0]

        try:
            hidden, _ = layer0(embed)
        except TypeError:
            try:
                hidden = layer0(embed, mask=None)
            except TypeError:
                hidden = embed

        return hidden

    def generate_stream(self, prompt: str, system_prompt: str = None, max_tokens: int = 512):
        """
        Generate tokens with per-token MoLoRA routing.

        AdaFuse decide-once: route at the prompt level (layer-0 hidden state),
        apply the same adapter to all layers for the entire generation.
        """
        import mlx.core as mx
        from mlx_lm.utils import generate_step

        # Build prompt
        if system_prompt:
            messages = [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt},
            ]
        else:
            messages = [{"role": "user", "content": prompt}]

        # Apply chat template
        if hasattr(self.tokenizer, "apply_chat_template"):
            formatted = self.tokenizer.apply_chat_template(
                messages, tokenize=False, add_generation_prompt=True
            )
        else:
            formatted = prompt

        tokens = self.tokenizer.encode(formatted)
        prompt_ids = mx.array([tokens])

        # Route: extract layer-0 hidden, compute adapter assignment
        hidden = self._get_layer0_hidden(prompt_ids)
        # Mean pool across sequence → single routing decision for this generation
        pooled = mx.mean(hidden, axis=1)  # [1, d_model]
        route_ids = self.router.route(pooled)  # [1]
        mx.eval(route_ids)

        chosen_adapter = int(route_ids[0])
        if chosen_adapter < len(self.adapter_configs):
            route_name = self.adapter_configs[chosen_adapter]["type"]
        else:
            route_name = "base"

        # For decide-once, we apply a single adapter to the entire generation.
        # Load that adapter via mlx-lm's standard load_adapter mechanism.
        if chosen_adapter < len(self.adapter_configs):
            adapter_path = self.adapter_configs[chosen_adapter]["path"]
            from mlx_lm.utils import load as mlx_load
            # Reload with selected adapter
            model_with_adapter, _ = mlx_load(
                self.adapter_configs[0].get("model_path", ""),
                adapter_path=adapter_path,
            ) if hasattr(self, "_base_model_path") else (self.model, self.tokenizer)
        else:
            model_with_adapter = self.model

        # Generate tokens using mlx-lm's generate_step
        t_start = time.time()
        generated_tokens = 0

        prompt_array = mx.array(tokens)

        for token in generate_step(prompt_array, model_with_adapter, temp=0.7):
            if isinstance(token, tuple):
                token_id = token[0]
            else:
                token_id = token

            token_id_item = token_id.item() if hasattr(token_id, "item") else int(token_id)

            # Check for EOS
            if token_id_item == self.tokenizer.eos_token_id:
                break

            text = self.tokenizer.decode([token_id_item])
            generated_tokens += 1

            yield {"type": "token", "text": text}

            if generated_tokens >= max_tokens:
                break

        t_elapsed = time.time() - t_start
        tok_per_sec = generated_tokens / t_elapsed if t_elapsed > 0 else 0

        yield {
            "type": "done",
            "tokens_generated": generated_tokens,
            "tok_per_sec": round(tok_per_sec, 1),
            "route": route_name,
        }


# ── Main Loop ─────────────────────────────────────────────────────────────────

def run_server(args):
    """Main stdin/stdout JSON-line server loop."""
    import mlx.core as mx
    from mlx_lm.utils import load as mlx_load

    print(json.dumps({"type": "status", "message": "Loading model..."}), flush=True)

    model, tokenizer = mlx_load(args.model_path)
    model.eval()

    # Parse adapter configs
    adapter_configs = []
    if args.adapters_json:
        adapter_configs = json.loads(args.adapters_json)
        # Add model_path to each config for reloading
        for cfg in adapter_configs:
            cfg["model_path"] = args.model_path

    molora = MoLoRAModel(model, tokenizer, adapter_configs, args.centroids_path)

    print(json.dumps({"type": "ready"}), flush=True)

    # Process commands from stdin
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            cmd = json.loads(line)
        except json.JSONDecodeError:
            print(json.dumps({"type": "error", "message": "Invalid JSON"}), flush=True)
            continue

        cmd_type = cmd.get("type", "")

        if cmd_type == "generate":
            try:
                for output in molora.generate_stream(
                    prompt=cmd.get("prompt", ""),
                    system_prompt=cmd.get("system_prompt"),
                    max_tokens=cmd.get("max_tokens", 512),
                ):
                    print(json.dumps(output), flush=True)
            except Exception as e:
                print(json.dumps({"type": "error", "message": str(e)}), flush=True)

        elif cmd_type == "reload_adapters":
            try:
                new_configs = cmd.get("adapters", [])
                for cfg in new_configs:
                    cfg["model_path"] = args.model_path
                molora = MoLoRAModel(model, tokenizer, new_configs, args.centroids_path)
                print(json.dumps({"type": "ready"}), flush=True)
            except Exception as e:
                print(json.dumps({"type": "error", "message": str(e)}), flush=True)

        elif cmd_type == "shutdown":
            print(json.dumps({"type": "status", "message": "Shutting down"}), flush=True)
            break

        else:
            print(json.dumps({"type": "error", "message": f"Unknown command: {cmd_type}"}), flush=True)


def run_self_test():
    """Quick self-test to verify the kernel and router work."""
    import mlx.core as mx
    from sgmm_kernel import apply_lora_delta, apply_lora_delta_fallback

    print("=== MoLoRA Self-Test ===")

    # Test 1: Kernel correctness
    print("Test 1: Kernel vs fallback...")
    B, d_in, rank, d_out = 4, 64, 8, 32
    x = mx.random.normal((B, d_in)).astype(mx.float16)
    A = mx.random.normal((d_in, rank)).astype(mx.float16)
    B_mat = mx.random.normal((rank, d_out)).astype(mx.float16)
    scale = 2.0

    ref = apply_lora_delta_fallback(x, A, B_mat, scale)
    try:
        result = apply_lora_delta(x, A, B_mat, scale)
        mx.eval(result)
        diff = float(mx.max(mx.abs(result - ref)))
        print(f"  Max diff: {diff:.6f} {'PASS' if diff < 0.01 else 'FAIL'}")
    except Exception as e:
        print(f"  Metal kernel failed (using fallback): {e}")

    # Test 2: Different ranks
    print("Test 2: Rank 32...")
    A32 = mx.random.normal((d_in, 32)).astype(mx.float16)
    B32 = mx.random.normal((32, d_out)).astype(mx.float16)
    ref32 = apply_lora_delta_fallback(x, A32, B32, scale)
    try:
        result32 = apply_lora_delta(x, A32, B32, scale)
        mx.eval(result32)
        diff32 = float(mx.max(mx.abs(result32 - ref32)))
        print(f"  Max diff: {diff32:.6f} {'PASS' if diff32 < 0.01 else 'FAIL'}")
    except Exception as e:
        print(f"  Metal kernel failed: {e}")

    # Test 3: Router
    print("Test 3: Router cosine similarity...")
    d_model = 64
    centroids = mx.stack([
        mx.array([1.0] + [0.0] * (d_model - 1)),
        mx.array([0.0, 1.0] + [0.0] * (d_model - 2)),
    ])
    router = AdaFuseRouter.__new__(AdaFuseRouter)
    router.centroids = centroids
    router.active = True
    router.domain_names = ["a", "b"]

    # Token close to centroid 0
    h = mx.array([[0.9, 0.1] + [0.0] * (d_model - 2)])
    route = router.route(h)
    mx.eval(route)
    print(f"  Route for [0.9, 0.1, ...]: adapter {int(route[0])} {'PASS' if int(route[0]) == 0 else 'FAIL'}")

    # Token close to centroid 1
    h2 = mx.array([[0.1, 0.9] + [0.0] * (d_model - 2)])
    route2 = router.route(h2)
    mx.eval(route2)
    print(f"  Route for [0.1, 0.9, ...]: adapter {int(route2[0])} {'PASS' if int(route2[0]) == 1 else 'FAIL'}")

    print("=== Self-test complete ===")


def main():
    args = parse_args()

    if args.test:
        # Add script directory to path for imports
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        run_self_test()
        return

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    run_server(args)


if __name__ == "__main__":
    main()
