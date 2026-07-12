#!/bin/zsh

set -euo pipefail

backup_root=${BACKUP_ROOT:-/Volumes/treasure}
backup_date=$(date +%Y-%m-%d)
backup_dir="$backup_root/Epistemos-Codex-Restore-$backup_date"
archive_name="Epistemos-Codex-Restore-$backup_date.tar"
archive_partial="$backup_dir/$archive_name.partial"
archive_final="$backup_dir/$archive_name"
stage_dir=$(mktemp -d "${TMPDIR:-/private/tmp}/Epistemos-Codex-Restore-Stage-XXXXXX")
test_dir=""
tar_pid=""

cleanup() {
  if [[ -n "$tar_pid" ]] && kill -0 "$tar_pid" 2>/dev/null; then
    kill "$tar_pid" 2>/dev/null || true
  fi
  [[ -e "$archive_partial" ]] && rm -f -- "$archive_partial"
  [[ -n "$test_dir" && -d "$test_dir" ]] && rm -rf -- "$test_dir"
  [[ -d "$stage_dir" ]] && rm -rf -- "$stage_dir"
}

trap cleanup EXIT

require_closed() {
  local pattern
  for pattern in \
    'ChatGPT.app' \
    'Xcode.app/Contents/MacOS/Xcode' \
    'Simulator.app/Contents/MacOS/Simulator'; do
    if pgrep -f "$pattern" >/dev/null; then
      print -u2 "Close ChatGPT/Codex, Xcode, and Simulator before running this backup."
      exit 1
    fi
  done
}

require_path() {
  local source_path=$1
  [[ -e "$source_path" ]] || {
    print -u2 "Required restore source is missing: $source_path"
    exit 1
  }
}

require_closed
[[ -d "$backup_root" && -w "$backup_root" ]] || {
  print -u2 "Backup drive is not writable at $backup_root"
  exit 1
}
[[ ! -e "$backup_dir" ]] || {
  print -u2 "Backup destination already exists: $backup_dir"
  exit 1
}

source_paths=(
  /Users/jojo/Downloads/Epistemos
  /Users/jojo/.codex
  /Applications/ChatGPT.app
  /Users/jojo/.cache/codex-runtimes
  '/Users/jojo/Library/Application Support/Codex'
  '/Users/jojo/Library/Application Support/com.openai.codex'
  '/Users/jojo/Library/Application Support/OpenAI'
  '/Users/jojo/Library/Application Support/com.openai.chat'
  '/Users/jojo/Library/Caches/com.openai.chat'
  '/Users/jojo/Library/Caches/com.openai.codex'
  '/Users/jojo/Library/Caches/com.openai.sky.CUAService'
  '/Users/jojo/Library/Caches/com.openai.sky.CUAService.cli'
  '/Users/jojo/Library/Preferences/com.openai.chat.RemoteFeatureFlags.686f10c3-19f2-4702-90b8-6f5952d0bd99.plist'
  '/Users/jojo/Library/Preferences/com.openai.chat.StatsigService.plist'
  '/Users/jojo/Library/Preferences/com.openai.chat.plist'
  '/Users/jojo/Library/Preferences/com.openai.codex.plist'
  '/Users/jojo/Library/Preferences/com.openai.sky.CUAService.cli.plist'
  '/Users/jojo/Library/Preferences/com.openai.sky.CUAService.plist'
  '/Users/jojo/Library/Containers/com.openai.chat.Widgets'
  '/Users/jojo/Library/Group Containers/2DC432GLL2.com.openai.codex.notifications'
  '/Users/jojo/Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService'
  '/Users/jojo/Library/Group Containers/group.com.openai.chat'
  '/Users/jojo/Library/Application Support/Epistemos'
  '/Users/jojo/Library/Application Support/Epistemos-Recovery'
  '/Users/jojo/Library/Application Support/com.epistemos.appstore'
  '/Users/jojo/Library/Containers/com.epistemos.appstore'
  '/Users/jojo/Library/Group Containers/group.com.epistemos.shared'
  '/Users/jojo/Library/Developer/Xcode/UserData'
  '/Users/jojo/Library/Preferences/com.apple.dt.Xcode.plist'
  '/Users/jojo/Library/Developer/CoreSimulator'
  /Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08
  /Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08.zip
  /Users/jojo/Downloads/epistemos_mas_low_ram_preparation_2026_07_11
)

for source_path in "${source_paths[@]}"; do
  require_path "$source_path"
done

mkdir -p "$stage_dir/sqlite-snapshots"
snapshot_report="$stage_dir/SQLITE_SNAPSHOTS.tsv"
sources_list="$stage_dir/SOURCES.list"
inventory="$stage_dir/SOURCE_INVENTORY.tsv"
readme="$stage_dir/RESTORE_README.md"

while IFS= read -r -d '' database_path; do
  relative_path=${database_path#/}
  snapshot_path="$stage_dir/sqlite-snapshots/$relative_path"
  mkdir -p "$(dirname "$snapshot_path")"
  if sqlite3 "$database_path" ".timeout 60000" ".backup '$snapshot_path'" && sqlite3 "$snapshot_path" 'PRAGMA integrity_check;' | grep -qx 'ok'; then
    print -r -- "OK\t$(du -sk "$snapshot_path" | awk '{print $1}')\t/$relative_path" >> "$snapshot_report"
  else
    print -r -- "FAILED\t-\t/$relative_path" >> "$snapshot_report"
  fi
done < <(find /Users/jojo/.codex -type f \( -name '*.sqlite' -o -name '*.sqlite3' -o -name '*.db' \) -print0)

print -r -- "${stage_dir#/}" > "$sources_list"
for source_path in "${source_paths[@]}"; do
  print -r -- "${source_path#/}" >> "$sources_list"
done

cat > "$readme" <<'EOF'
# Epistemos + Codex restore archive

This archive restores the active MAS-only Epistemos workspace and Codex setup:
the full repository and scripts, Git state, Codex sessions/settings/skills/plugins,
ChatGPT/Codex app data, active MAS data, recovery snapshots, Xcode user settings,
and the attached canon packets.

It excludes deleted build products and retired Experimental/OpenChamber/model caches.

The raw Codex databases and WAL/SHM companions are included after the app-close
guard passes. The included `SQLITE_SNAPSHOTS.tsv` reports which additional
SQLite-consistent `~/.codex` snapshots were successfully made.

Verify the archive before restore:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

On the new Mac, install ChatGPT/Codex and Xcode first, quit them, then extract into
an empty staging directory with `bsdtar -xpf <archive>.tar -C <staging-dir>`.
Inspect the staged `Users/jojo/...` tree before copying any data into live locations.
EOF

total_kib=0
{
  print -r -- $'size_kib\tsource'
  while IFS= read -r relative_path; do
    source_path="/$relative_path"
    size_kib=$(du -sk "$source_path" | awk '{print $1}')
    total_kib=$((total_kib + size_kib))
    print -r -- "$size_kib\t/$relative_path"
  done < "$sources_list"
} > "$inventory"

free_kib=$(df -k "$backup_root" | awk 'NR == 2 {print $4}')
payload_limit_kib=$((free_kib * 80 / 100))
print -r -- "TOTAL_KIB\t$total_kib" >> "$inventory"
print -r -- "EXTERNAL_FREE_KIB_BEFORE_ARCHIVE\t$free_kib" >> "$inventory"
print -r -- "PAYLOAD_LIMIT_KIB_WITH_20_PERCENT_HEADROOM\t$payload_limit_kib" >> "$inventory"

if (( total_kib > payload_limit_kib )); then
  print -u2 "Selected restore set exceeds the 20%-headroom limit. See $inventory"
  exit 1
fi

mkdir -p "$backup_dir"
cp "$readme" "$backup_dir/RESTORE_README.md"
cp "$inventory" "$backup_dir/SOURCE_INVENTORY.tsv"
cp "$snapshot_report" "$backup_dir/SQLITE_SNAPSHOTS.tsv"
cp "$0" "$backup_dir/Run-Epistemos-Codex-Restore-Backup.zsh"
chmod 700 "$backup_dir/Run-Epistemos-Codex-Restore-Backup.zsh"

print "Creating $archive_final"
bsdtar --create --file="$archive_partial" --format=pax --acls --xattrs --mac-metadata --directory=/ --files-from="$sources_list" &
tar_pid=$!
while kill -0 "$tar_pid" 2>/dev/null; do
  if [[ -e "$archive_partial" ]]; then
    print "Archive written so far: $(du -h "$archive_partial" | awk '{print $1}')"
  fi
  sleep 30
done
wait "$tar_pid"
tar_pid=""
mv "$archive_partial" "$archive_final"
shasum -a 256 "$archive_final" > "$backup_dir/SHA256SUMS.txt"
bsdtar -tf "$archive_final" >/dev/null

test_dir=$(mktemp -d "${TMPDIR:-/private/tmp}/Epistemos-Codex-Restore-Test-XXXXXX")
bsdtar -xpf "$archive_final" --directory="$test_dir" Users/jojo/Downloads/Epistemos
git -C "$test_dir/Users/jojo/Downloads/Epistemos" status -sb > "$backup_dir/STAGING_GIT_STATUS.txt"
[[ -f "$test_dir/Users/jojo/Downloads/Epistemos/.git/HEAD" ]]

print -r -- "archive_readable=yes" > "$backup_dir/VERIFICATION.txt"
print -r -- "staging_project_restore=yes" >> "$backup_dir/VERIFICATION.txt"
print -r -- "git_status_checked=yes" >> "$backup_dir/VERIFICATION.txt"
print "Backup verified: $backup_dir"
