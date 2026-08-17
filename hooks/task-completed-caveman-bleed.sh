#!/usr/bin/env bash
# Hook: Stop
# Detects caveman-mode bleed in the last assistant message of the transcript.
# Threshold configurable via $CAVEMAN_BLEED_THRESHOLD (default 40, percent).
# Exit 0 = clean / no-op. Exit 2 = caveman patterns detected.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

EVENT=$(cat)
TRANSCRIPT=$(echo "$EVENT" | jq -r '.transcript_path // ""' 2>/dev/null || true)
[ -z "$TRANSCRIPT" ] && exit 0
[ ! -f "$TRANSCRIPT" ] && exit 0

TEXT=$(jq -rs '
  map(select(.type=="assistant"))
  | last // {}
  | .message.content // ""
  | (if type=="array"
     then map(select(.type=="text") | .text) | join("\n")
     else tostring end)
' "$TRANSCRIPT" 2>/dev/null || true)

[ -z "$TEXT" ] && exit 0

LINES=$(echo "$TEXT" | wc -l | tr -d ' ')
[ "$LINES" -lt 3 ] && exit 0

FRAG=$(echo "$TEXT" | grep -cE '^[A-Z][a-z]+ [a-z]+\.$' || true)
RATIO=$((FRAG * 100 / LINES))
THRESHOLD="${CAVEMAN_BLEED_THRESHOLD:-40}"

if [ "$RATIO" -gt "$THRESHOLD" ]; then
  {
    echo "task-completed-caveman-bleed: ${RATIO}% short-fragment lines (threshold ${THRESHOLD}%)."
    echo "Caveman mode is bleeding into the artifact. Rewrite in normal prose."
  } >&2
  exit 2
fi
exit 0
