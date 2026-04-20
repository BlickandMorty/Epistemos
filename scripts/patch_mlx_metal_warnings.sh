#!/bin/bash
set -euo pipefail

if [[ "${EPISTEMOS_PATCH_MLX_METAL_WARNINGS:-1}" == "0" ]]; then
  exit 0
fi

readonly relative_path="Source/Cmlx/mlx-generated/metal/steel/attn/kernels/steel_attention.metal"
readonly warning_flag="-Wc++17-extensions"

candidate_files=()

add_candidate_root() {
  local root="$1"
  if [[ -n "${root}" ]]; then
    candidate_files+=("${root}/SourcePackages/checkouts/mlx-swift/${relative_path}")
  fi
}

add_build_dir_candidate() {
  local suffix="$1"
  local root
  root="$(cd "${BUILD_DIR}/${suffix}" 2>/dev/null && pwd -P || true)"
  add_candidate_root "${root}"
}

if [[ -n "${BUILD_DIR:-}" ]]; then
  add_build_dir_candidate "../.."
  add_build_dir_candidate "../../.."
fi

while IFS= read -r file; do
  candidate_files+=("${file}")
done < <(/usr/bin/find "${HOME}/Library/Developer/Xcode/DerivedData" \
  -path "*/SourcePackages/checkouts/mlx-swift/${relative_path}" \
  -print 2>/dev/null || true)

patch_file() {
  local file="$1"
  local tmp

  [[ -f "${file}" ]] || return 1

  if /usr/bin/grep -Fq -- "${warning_flag}" "${file}"; then
    return 0
  fi

  /bin/chmod u+w "${file}" 2>/dev/null || true
  tmp="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/mlx-metal-warning.XXXXXX")"

  if /usr/bin/awk '
    BEGIN { inserted = 0 }
    {
      print
      if (inserted == 0 && $0 == "// clang-format off") {
        print "#pragma clang diagnostic push"
        print "#pragma clang diagnostic ignored \"-Wc++17-extensions\""
        inserted = 1
        next
      }
      if (inserted == 1 && $0 == "#include \"../../../steel/attn/kernels/steel_attention.h\"") {
        print "#pragma clang diagnostic pop"
        inserted = 2
      }
    }
    END { if (inserted != 2) exit 42 }
  ' "${file}" > "${tmp}"; then
    /bin/cp "${tmp}" "${file}"
    /bin/rm -f "${tmp}"
    echo "Patched MLX Metal warning: ${file}"
    return 0
  fi

  /bin/rm -f "${tmp}"
  echo "warning: could not patch MLX Metal warning in ${file}" >&2
  return 1
}

patched_any=0
while IFS= read -r file; do
  if patch_file "${file}"; then
    patched_any=1
  fi
done < <(/usr/bin/printf '%s\n' "${candidate_files[@]}" | /usr/bin/sort -u)

if [[ "${patched_any}" == "0" ]]; then
  echo "MLX Metal warning patch: no mlx-swift checkout found yet"
fi
