#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <app-or-executable-path> [seconds] [output-dir]"
  exit 1
fi

target_path="$1"
seconds="${2:-20}"
output_dir="${3:-artifacts/xctrace/$(date +%Y%m%d-%H%M%S)}"

mkdir -p "${output_dir}"

if [[ -d "${target_path}" && "${target_path}" == *.app ]]; then
  binary_name="$(basename "${target_path}" .app)"
  launch_target="${target_path}/Contents/MacOS/${binary_name}"
else
  launch_target="${target_path}"
fi

if [[ ! -x "${launch_target}" ]]; then
  echo "launch target is not executable: ${launch_target}"
  exit 1
fi

time_trace="${output_dir}/time_profiler.trace"
leaks_trace="${output_dir}/leaks.trace"

echo "Recording Time Profiler for ${seconds}s..."
xcrun xctrace record \
  --template "Time Profiler" \
  --time-limit "${seconds}s" \
  --output "${time_trace}" \
  --launch -- "${launch_target}" \
  --no-prompt

echo "Recording Leaks for ${seconds}s..."
xcrun xctrace record \
  --template "Leaks" \
  --time-limit "${seconds}s" \
  --output "${leaks_trace}" \
  --launch -- "${launch_target}" \
  --no-prompt

echo "Exporting trace TOCs..."
xcrun xctrace export --input "${time_trace}" --toc --output "${output_dir}/time_profiler.toc.xml"
xcrun xctrace export --input "${leaks_trace}" --toc --output "${output_dir}/leaks.toc.xml"

echo
echo "xctrace profiling complete."
echo "Artifacts: ${output_dir}"

