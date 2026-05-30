#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="$(mktemp -d /tmp/epistemos-metal-compile.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

shader_roots=(
  "$repo_root/Epistemos/Shaders"
  "$repo_root/agent_core/metal"
)

# HELIOS-V6-TARGET-ONLY-KERNEL-GUARD
#
# V6.1/V6.2 names these as canonical kernel targets. Some now have
# source-level kernels plus focused witness/equivalence tests, but the
# broad compile smoke test must not bless them as full M2 Pro falsifier
# passes. Keep this list as the warning rail until each primary artifact
# is measured and promoted.
deferred_hardware_kernels=(
  "SemiseparableBlockScan.metal"
  "LocalRecallIsland.metal"
  "PageGather.metal"
  "PacketRouter1bit.metal"
  "InterruptScore.metal"
)

for shader_root in "${shader_roots[@]}"; do
  for kernel in "${deferred_hardware_kernels[@]}"; do
    candidate="$shader_root/$kernel"
    if [[ -e "$candidate" ]]; then
      rel="${candidate#"$repo_root/"}"
      echo "DEFERRED $rel has source present; compile smoke is not a primary M2 Pro falsifier pass"
    fi
  done
done

shaders=()
while IFS= read -r shader; do
  shaders+=("$shader")
done < <(find "${shader_roots[@]}" -type f -name '*.metal' | sort)

if [[ "${#shaders[@]}" -eq 0 ]]; then
  echo "FAIL no Metal shaders found"
  exit 1
fi

for shader in "${shaders[@]}"; do
  rel="${shader#"$repo_root/"}"
  out="$tmpdir/${rel//[\/ ]/__}.air"
  xcrun -sdk macosx metal -std=metal3.1 -c "$shader" -o "$out" >/dev/null
  echo "PASS $rel"
done

echo "OK ${#shaders[@]} Metal shaders compile"
