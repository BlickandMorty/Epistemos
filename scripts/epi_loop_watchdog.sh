#!/bin/zsh
# Epistemos loop watchdog — HARD GATE: resume the master loop within ~2 min of any park.
# Resumes ONLY when truly idle (no "esc to interrupt" AND no compilers running), so it
# never interrupts active work or a mid-build hold. Owner directive 2026-06-21: never stop.
SESSION=epistemos-master-loop
LOG=/tmp/epi_watchdog.log
echo "$(date '+%H:%M:%S') watchdog START" >> "$LOG"
while true; do
  if ! pgrep -f "claude.*$SESSION" >/dev/null 2>&1; then
    echo "$(date '+%H:%M:%S') loop process DEAD — not auto-relaunching (needs operator)" >> "$LOG"
    sleep 100; continue
  fi
  screen -S "$SESSION" -p 0 -X hardcopy -h /tmp/epi_wd.txt 2>/dev/null
  esc=$(LC_ALL=C tr -cd '[:print:]\n' < /tmp/epi_wd.txt 2>/dev/null | grep -c 'esc to interrupt')
  swift=$(pgrep -x swift-frontend 2>/dev/null | wc -l | tr -d ' ')
  xcode=$(pgrep -x xcodebuild 2>/dev/null | wc -l | tr -d ' ')
  if [ "${esc:-0}" -eq 0 ] && [ "${swift:-0}" -eq 0 ] && [ "${xcode:-0}" -eq 0 ]; then
    # PARKED / idle -> resume
    screen -S "$SESSION" -p 0 -X stuff $'\025' 2>/dev/null
    sleep 2
    screen -S "$SESSION" -p 0 -X stuff 'Keep going per the master queue — never stop. Substantive feature/substrate items, deliberate-first per CONNECTION_MAP_2026_06_20.md, tests, single build, commit each green.' 2>/dev/null
    sleep 2
    screen -S "$SESSION" -p 0 -X stuff $'\r' 2>/dev/null
    echo "$(date '+%H:%M:%S') RESUMED a park (esc=$esc swift=$swift xcode=$xcode)" >> "$LOG"
  fi
  sleep 100
done
