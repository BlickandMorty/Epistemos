#!/bin/zsh
# Flags OPEN ledger items whose SS-tag has NOT appeared in any commit in the window — candidates for
# "not being touched -> maybe wrong slice -> re-research" (owner 2026-06-21).
cd /Users/jojo/Downloads/Epistemos || exit 1
L=docs/OWNER_REQUESTS_LEDGER_2026_06_18.md
WINDOW=${1:-400}
tags=$(grep -oE 'SS-[A-Z]{1,5}' "$L" | sort -u)
commits=$(git log -n "$WINDOW" --format='%s%n%b')
echo "=== UNTOUCHED open-ledger SS-tags (no commit in last $WINDOW) — re-research candidates ==="
n=0
for t in ${(f)tags}; do
  # is this tag still OPEN anywhere?
  if grep -qE "^- \[ \].*$t" "$L"; then
    if ! echo "$commits" | grep -q "$t"; then
      echo "  $t — open, 0 commits — RE-RESEARCH/verify slice exists + reaches a real path"; n=$((n+1))
    fi
  fi
done
[ "$n" -eq 0 ] && echo "  (none — every open SS-tag has at least one commit)"
echo "untouched-open-tag count: $n"
