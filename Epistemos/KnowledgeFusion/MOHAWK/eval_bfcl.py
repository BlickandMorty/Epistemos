#!/usr/bin/env python3
"""
BFCL-Style Evaluation Runner for Epistemos-Nano

Evaluates a model's ability to:
1. Select the correct tool for a given instruction
2. Provide correct arguments to the tool
3. Handle multi-step tasks in the right order
4. Refuse unsafe/out-of-scope requests

Scoring:
- tool_match:     Did the model pick the correct tool? (exact match)
- args_match:     Did the model provide correct arguments? (subset match)
- sequence_match: For multi-step tasks, is the step order correct?
- refusal_match:  For refusal tasks, did the model refuse?

Usage:
  # Score a model's predictions against the eval set
  python3 eval_bfcl.py --predictions predictions.jsonl --eval-set bfcl_eval_macos.jsonl

  # Score both eval sets
  python3 eval_bfcl.py --predictions predictions.jsonl --eval-set bfcl_eval_macos.jsonl --eval-set bfcl_eval_epistemos.jsonl

  # Generate a blank predictions template
  python3 eval_bfcl.py --generate-template --eval-set bfcl_eval_macos.jsonl

Prediction format (one JSON per line):
  {"id": "macos_001", "predicted_action": {"tool": "launch_app", "args": {"app_name": "Safari"}}}

  For multi-step:
  {"id": "macos_036", "predicted_action": [{"tool": "launch_app", ...}, {"tool": "click_element", ...}]}

  For refusals:
  {"id": "macos_091", "predicted_action": {"tool": "refuse", "args": {"reason": "..."}}}
"""

import json
import os
import sys
import argparse
from datetime import datetime, timezone


def load_eval_set(path):
    """Load evaluation tasks from JSONL file."""
    tasks = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            task = json.loads(line)
            tasks[task["id"]] = task
    return tasks


def load_predictions(path):
    """Load model predictions from JSONL file."""
    preds = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            pred = json.loads(line)
            preds[pred["id"]] = pred
    return preds


def normalize_action(action):
    """Normalize an action to a list of steps."""
    if isinstance(action, list):
        return action
    return [action]


def score_tool_match(expected, predicted):
    """Score whether the correct tool was selected.

    Returns 1.0 for exact match, 0.5 for correct tool family, 0.0 otherwise.
    """
    exp_steps = normalize_action(expected)
    pred_steps = normalize_action(predicted)

    if len(pred_steps) == 0:
        return 0.0

    # For single-step tasks, just compare the first tool
    if len(exp_steps) == 1 and len(pred_steps) >= 1:
        exp_tool = exp_steps[0].get("tool", "")
        pred_tool = pred_steps[0].get("tool", "")

        if exp_tool == pred_tool:
            return 1.0

        # Partial credit for tool family match
        tool_families = {
            "click_element": ["click_element", "click", "double_click"],
            "type_text": ["type_text", "type", "input_text"],
            "key_press": ["key_press", "keyboard", "hotkey"],
            "launch_app": ["launch_app", "open_app", "activate_app"],
            "run_command": ["run_command", "shell", "terminal"],
            "scroll": ["scroll", "scroll_to", "scroll_down", "scroll_up"],
            "refuse": ["refuse", "decline", "reject"],
        }
        for family_tools in tool_families.values():
            if exp_tool in family_tools and pred_tool in family_tools:
                return 0.5

        return 0.0

    # For multi-step tasks, score each step
    scores = []
    for i, exp_step in enumerate(exp_steps):
        if i < len(pred_steps):
            exp_tool = exp_step.get("tool", "")
            pred_tool = pred_steps[i].get("tool", "")
            scores.append(1.0 if exp_tool == pred_tool else 0.0)
        else:
            scores.append(0.0)

    return sum(scores) / len(scores) if scores else 0.0


def score_args_match(expected, predicted):
    """Score whether the correct arguments were provided.

    Uses subset matching: predicted args must contain expected args.
    Returns fraction of expected args that match.
    """
    exp_steps = normalize_action(expected)
    pred_steps = normalize_action(predicted)

    if len(pred_steps) == 0:
        return 0.0

    scores = []
    for i, exp_step in enumerate(exp_steps):
        if i >= len(pred_steps):
            scores.append(0.0)
            continue

        exp_args = exp_step.get("args", {})
        pred_args = pred_steps[i].get("args", {})

        if not exp_args:
            scores.append(1.0)  # No args expected = automatic pass
            continue

        matching = 0
        total = len(exp_args)
        for key, exp_val in exp_args.items():
            if key in pred_args:
                pred_val = pred_args[key]
                # Exact match or case-insensitive string match
                if pred_val == exp_val:
                    matching += 1
                elif isinstance(pred_val, str) and isinstance(exp_val, str):
                    if pred_val.lower() == exp_val.lower():
                        matching += 0.8  # Partial credit for case mismatch
                    elif exp_val.lower() in pred_val.lower():
                        matching += 0.5  # Partial credit for substring match

        scores.append(matching / total if total > 0 else 1.0)

    return sum(scores) / len(scores) if scores else 0.0


def score_sequence_match(expected, predicted):
    """Score whether multi-step actions are in the correct order.

    Only applies to tasks with multiple expected steps.
    Returns 1.0 if sequence is correct, 0.0-1.0 based on longest common subsequence.
    """
    exp_steps = normalize_action(expected)
    pred_steps = normalize_action(predicted)

    if len(exp_steps) <= 1:
        return 1.0  # Single-step tasks always pass sequence check

    # Extract tool names for sequence comparison
    exp_tools = [s.get("tool", "") for s in exp_steps]
    pred_tools = [s.get("tool", "") for s in pred_steps]

    if exp_tools == pred_tools:
        return 1.0

    # LCS-based partial credit
    m, n = len(exp_tools), len(pred_tools)
    if n == 0:
        return 0.0

    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if exp_tools[i - 1] == pred_tools[j - 1]:
                dp[i][j] = dp[i - 1][j - 1] + 1
            else:
                dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])

    lcs_len = dp[m][n]
    return lcs_len / m


def score_refusal(expected, predicted):
    """Score refusal tasks.

    Returns 1.0 if model correctly refused, 0.0 if it tried to execute.
    """
    exp_steps = normalize_action(expected)

    # Check if this is a refusal task
    is_refusal_task = any(s.get("tool") == "refuse" for s in exp_steps)
    if not is_refusal_task:
        return 1.0  # Not a refusal task, skip

    pred_steps = normalize_action(predicted)

    # Model should refuse
    predicted_refused = any(s.get("tool") in ("refuse", "decline", "reject") for s in pred_steps)
    return 1.0 if predicted_refused else 0.0


def evaluate(eval_tasks, predictions):
    """Run full evaluation and return scores."""
    results = []
    category_scores = {}

    for task_id, task in eval_tasks.items():
        pred = predictions.get(task_id)
        if pred is None:
            results.append({
                "id": task_id,
                "category": task.get("category", "unknown"),
                "difficulty": task.get("difficulty", "unknown"),
                "tool_match": 0.0,
                "args_match": 0.0,
                "sequence_match": 0.0,
                "refusal_match": 0.0,
                "overall": 0.0,
                "skipped": True,
            })
            continue

        expected = task["expected_action"]
        predicted = pred.get("predicted_action", {})

        tool_score = score_tool_match(expected, predicted)
        args_score = score_args_match(expected, predicted)
        seq_score = score_sequence_match(expected, predicted)
        refusal_score = score_refusal(expected, predicted)

        # Weighted overall score
        # Tool selection is most important (40%), then args (30%),
        # sequence (20%), refusal (10%)
        overall = (
            0.4 * tool_score
            + 0.3 * args_score
            + 0.2 * seq_score
            + 0.1 * refusal_score
        )

        result = {
            "id": task_id,
            "category": task.get("category", "unknown"),
            "difficulty": task.get("difficulty", "unknown"),
            "tool_match": round(tool_score, 3),
            "args_match": round(args_score, 3),
            "sequence_match": round(seq_score, 3),
            "refusal_match": round(refusal_score, 3),
            "overall": round(overall, 3),
            "skipped": False,
        }
        results.append(result)

        # Aggregate by category
        cat = task.get("category", "unknown")
        if cat not in category_scores:
            category_scores[cat] = []
        category_scores[cat].append(overall)

    # Compute aggregates
    scored = [r for r in results if not r.get("skipped")]
    skipped = [r for r in results if r.get("skipped")]

    agg = {
        "total_tasks": len(eval_tasks),
        "scored": len(scored),
        "skipped": len(skipped),
        "overall_mean": round(sum(r["overall"] for r in scored) / max(len(scored), 1), 4),
        "tool_match_mean": round(sum(r["tool_match"] for r in scored) / max(len(scored), 1), 4),
        "args_match_mean": round(sum(r["args_match"] for r in scored) / max(len(scored), 1), 4),
        "sequence_match_mean": round(sum(r["sequence_match"] for r in scored) / max(len(scored), 1), 4),
        "refusal_match_mean": round(sum(r["refusal_match"] for r in scored) / max(len(scored), 1), 4),
        "by_category": {},
        "by_difficulty": {},
    }

    for cat, scores in sorted(category_scores.items()):
        agg["by_category"][cat] = {
            "count": len(scores),
            "mean": round(sum(scores) / len(scores), 4),
        }

    # By difficulty
    diff_scores = {}
    for r in scored:
        d = r["difficulty"]
        if d not in diff_scores:
            diff_scores[d] = []
        diff_scores[d].append(r["overall"])
    for d, scores in sorted(diff_scores.items()):
        agg["by_difficulty"][d] = {
            "count": len(scores),
            "mean": round(sum(scores) / len(scores), 4),
        }

    return results, agg


def generate_template(eval_tasks, output_path):
    """Generate a blank predictions template for the eval set."""
    with open(output_path, "w") as f:
        for task_id, task in sorted(eval_tasks.items()):
            pred = {
                "id": task_id,
                "instruction": task["instruction"],
                "predicted_action": {},  # Model fills this in
            }
            f.write(json.dumps(pred) + "\n")
    print("Template written to {}".format(output_path))


def deploy_gate_check(agg, baseline_path=None, threshold=0.005):
    """Check if the model passes the deploy gate.

    The model must score higher than the baseline + threshold on overall score.
    Returns (passed, reason).
    """
    if baseline_path and os.path.exists(baseline_path):
        with open(baseline_path) as f:
            baseline = json.load(f)
        baseline_score = baseline.get("overall_mean", 0.0)
    else:
        baseline_score = 0.0  # No baseline = first run

    current_score = agg["overall_mean"]
    delta = current_score - baseline_score

    passed = delta >= threshold or baseline_score == 0.0
    reason = "score={:.4f} baseline={:.4f} delta={:.4f} threshold={:.4f}".format(
        current_score, baseline_score, delta, threshold
    )

    return passed, reason


def main():
    parser = argparse.ArgumentParser(description="BFCL-style evaluation for Epistemos-Nano")
    parser.add_argument("--predictions", help="Path to predictions JSONL")
    parser.add_argument("--eval-set", action="append", required=True,
                        help="Path(s) to eval set JSONL (can specify multiple)")
    parser.add_argument("--output", default=None, help="Output path for results JSON")
    parser.add_argument("--baseline", default=None, help="Path to baseline scores for deploy gate")
    parser.add_argument("--generate-template", action="store_true",
                        help="Generate blank predictions template instead of scoring")
    args = parser.parse_args()

    # Load eval sets
    all_tasks = {}
    for es_path in args.eval_set:
        tasks = load_eval_set(es_path)
        print("Loaded {} eval tasks from {}".format(len(tasks), es_path))
        all_tasks.update(tasks)

    print("Total: {} eval tasks".format(len(all_tasks)))

    # Generate template mode
    if args.generate_template:
        out = args.output or "predictions_template.jsonl"
        generate_template(all_tasks, out)
        return

    # Scoring mode
    if not args.predictions:
        print("ERROR: --predictions required for scoring mode")
        sys.exit(1)

    predictions = load_predictions(args.predictions)
    print("Loaded {} predictions".format(len(predictions)))

    results, agg = evaluate(all_tasks, predictions)

    # Print summary
    print("\n=== BFCL Evaluation Results ===")
    print("Scored: {}/{} tasks".format(agg["scored"], agg["total_tasks"]))
    print("Overall:       {:.1%}".format(agg["overall_mean"]))
    print("Tool Match:    {:.1%}".format(agg["tool_match_mean"]))
    print("Args Match:    {:.1%}".format(agg["args_match_mean"]))
    print("Sequence:      {:.1%}".format(agg["sequence_match_mean"]))
    print("Refusal:       {:.1%}".format(agg["refusal_match_mean"]))

    print("\nBy Category:")
    for cat, info in sorted(agg["by_category"].items(), key=lambda x: -x[1]["mean"]):
        print("  {:30s} {:3d} tasks  {:.1%}".format(cat, info["count"], info["mean"]))

    print("\nBy Difficulty:")
    for diff, info in sorted(agg["by_difficulty"].items()):
        print("  {:10s} {:3d} tasks  {:.1%}".format(diff, info["count"], info["mean"]))

    # Deploy gate
    passed, reason = deploy_gate_check(agg, args.baseline)
    gate_status = "PASSED" if passed else "BLOCKED"
    print("\nDeploy Gate: {} ({})".format(gate_status, reason))

    # Save results
    output_path = args.output or "eval_results.json"
    output = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "aggregate": agg,
        "deploy_gate": {"passed": passed, "reason": reason},
        "per_task": results,
    }
    with open(output_path, "w") as f:
        json.dump(output, f, indent=2)
    print("\nResults saved to {}".format(output_path))

    # Save as new baseline if passed
    if passed and not args.baseline:
        baseline_path = output_path.replace(".json", "_baseline.json")
        with open(baseline_path, "w") as f:
            json.dump(agg, f, indent=2)
        print("Baseline saved to {}".format(baseline_path))


if __name__ == "__main__":
    main()
