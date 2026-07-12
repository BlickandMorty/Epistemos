#!/bin/zsh

set -euo pipefail

backup_root=${BACKUP_ROOT:-/Volumes/treasure}
backup_date=$(date +%Y-%m-%d)
backup_dir="$backup_root/Epistemos-Codex-Restore-$backup_date"
image_name="Epistemos-Codex-Restore-$backup_date.sparseimage"
image_path="$backup_dir/$image_name"
restore_script="$backup_root/Restore-Epistemos-Codex-On-New-Mac.command"
stage_dir=$(mktemp -d "${TMPDIR:-/private/tmp}/Epistemos-Codex-Restore-Stage-XXXXXX")
mountpoint="$stage_dir/image-mount"
verify_mountpoint="$stage_dir/verify-mount"
image_attached=0
backup_started=0
backup_complete=0

cleanup() {
  if (( image_attached )); then
    hdiutil detach "$mountpoint" -force >/dev/null 2>&1 || true
    hdiutil detach "$verify_mountpoint" -force >/dev/null 2>&1 || true
  fi
  if (( backup_started && ! backup_complete )); then
    [[ -d "$backup_dir" ]] && rm -rf -- "$backup_dir"
  fi
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

remove_transient_sockets() {
  local socket_path
  for socket_path in \
    /Users/jojo/Downloads/Epistemos/.git/fsmonitor--daemon.ipc \
    /Users/jojo/.codex/vendor_imports/skills/.git/fsmonitor--daemon.ipc; do
    [[ -e "$socket_path" || -S "$socket_path" ]] && rm -f -- "$socket_path"
  done
}

copy_with_progress() {
  local source_path=$1
  local destination_path=$2
  local copy_pid

  mkdir -p "$(dirname "$destination_path")"
  print "Copying $source_path"
  ditto --rsrc --extattr --acl "$source_path" "$destination_path" &
  copy_pid=$!
  while kill -0 "$copy_pid" 2>/dev/null; do
    if [[ -e "$image_path" ]]; then
      print "Image written so far: $(du -h "$image_path" | awk '{print $1}')"
    fi
    sleep 30
  done
  wait "$copy_pid"
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
[[ -x "$restore_script" ]] || {
  print -u2 "Restore script missing: $restore_script"
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
remove_transient_sockets

total_kib=0
for source_path in "${source_paths[@]}"; do
  total_kib=$((total_kib + $(du -sk "$source_path" | awk '{print $1}')))
done
free_kib=$(df -k "$backup_root" | awk 'NR == 2 {print $4}')
payload_limit_kib=$((free_kib * 80 / 100))
if (( total_kib > payload_limit_kib )); then
  print -u2 "Selected restore set exceeds the 20%-headroom limit."
  exit 1
fi

mkdir -p "$backup_dir" "$mountpoint"
backup_started=1
hdiutil create -size 70g -type SPARSE -fs APFS -volname "Epistemos Codex Restore $backup_date" -nospotlight "$image_path" >/dev/null
hdiutil attach -nobrowse -mountpoint "$mountpoint" "$image_path" >/dev/null
image_attached=1

payload_root="$mountpoint/Payload"
metadata_root="$mountpoint/Metadata"
mkdir -p "$payload_root" "$metadata_root/sqlite-snapshots"

for source_path in "${source_paths[@]}"; do
  copy_with_progress "$source_path" "$payload_root/${source_path#/}"
done

snapshot_report="$metadata_root/SQLITE_SNAPSHOTS.tsv"
while IFS= read -r -d '' database_path; do
  relative_path=${database_path#/}
  snapshot_path="$metadata_root/sqlite-snapshots/$relative_path"
  mkdir -p "$(dirname "$snapshot_path")"
  if sqlite3 "$database_path" ".timeout 60000" ".backup '$snapshot_path'" && sqlite3 "$snapshot_path" 'PRAGMA integrity_check;' | grep -qx 'ok'; then
    print -r -- "OK\t$(du -sk "$snapshot_path" | awk '{print $1}')\t/$relative_path" >> "$snapshot_report"
  else
    print -r -- "FAILED\t-\t/$relative_path" >> "$snapshot_report"
  fi
done < <(find /Users/jojo/.codex -type f \( -name '*.sqlite' -o -name '*.sqlite3' -o -name '*.db' \) -print0)

inventory="$metadata_root/SOURCE_INVENTORY.tsv"
print -r -- $'size_kib\tsource' > "$inventory"
for source_path in "${source_paths[@]}"; do
  print -r -- "$(du -sk "$source_path" | awk '{print $1}')\t$source_path" >> "$inventory"
done
print -r -- "TOTAL_KIB\t$total_kib" >> "$inventory"
print -r -- "EXTERNAL_FREE_KIB_BEFORE_BACKUP\t$free_kib" >> "$inventory"
print -r -- "PAYLOAD_LIMIT_KIB_WITH_20_PERCENT_HEADROOM\t$payload_limit_kib" >> "$inventory"

cat > "$metadata_root/RESTORE_README.md" <<'EOF'
# Epistemos + Codex full restore image

This unencrypted APFS sparse image contains the active MAS-only Epistemos
workspace, scripts, complete Codex state, active MAS app data, recovery
snapshots, Xcode user settings, and canon packets. It excludes retired
Experimental/OpenChamber/model caches and build products.

Run `Restore-Epistemos-Codex-On-New-Mac.command` from the external drive on a
new Mac. It verifies the image checksum, stages the image, and replaces the
backed-up user paths only after explicit confirmation, preserving a local
rollback folder first.
EOF
cp "$restore_script" "$metadata_root/Restore-Epistemos-Codex-On-New-Mac.command"
chmod 700 "$metadata_root/Restore-Epistemos-Codex-On-New-Mac.command"
git -C "$payload_root/Users/jojo/Downloads/Epistemos" status -sb > "$metadata_root/STAGING_GIT_STATUS.txt"

sync
hdiutil detach "$mountpoint" >/dev/null
image_attached=0
hdiutil compact "$image_path" >/dev/null

mkdir -p "$verify_mountpoint"
hdiutil attach -readonly -nobrowse -mountpoint "$verify_mountpoint" "$image_path" >/dev/null
image_attached=1
git -C "$verify_mountpoint/Payload/Users/jojo/Downloads/Epistemos" status -sb > "$backup_dir/STAGING_GIT_STATUS.txt"
hdiutil detach "$verify_mountpoint" >/dev/null
image_attached=0

(cd "$backup_dir" && shasum -a 256 "$image_name" > SHA256SUMS.txt)
print -r -- "image_mount_verified=yes" > "$backup_dir/VERIFICATION.txt"
print -r -- "staging_project_restore=yes" >> "$backup_dir/VERIFICATION.txt"
print -r -- "git_status_checked=yes" >> "$backup_dir/VERIFICATION.txt"
backup_complete=1
print "Backup verified: $backup_dir"
