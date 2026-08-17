#!/usr/bin/env bash
# Hook: Stop
# Checks last assistant message in the transcript against required items from
# $PROJECT_PRECOMMIT_CHECKLIST (YAML, `required:` list).
# Exit 0 = pass / hook no-op. Exit 2 = block (missing items on stderr).
set -euo pipefail

if [ -z "${PROJECT_PRECOMMIT_CHECKLIST:-}" ]; then
  exit 0
fi
if [ ! -f "$PROJECT_PRECOMMIT_CHECKLIST" ]; then
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

EVENT=$(cat)
TRANSCRIPT=$(echo "$EVENT" | jq -r '.transcript_path // ""' 2>/dev/null || true)
[ -z "$TRANSCRIPT" ] && exit 0
[ ! -f "$TRANSCRIPT" ] && exit 0

LAST=$(jq -rs '
  map(select(.type=="assistant"))
  | last // {}
  | .message.content // ""
  | (if type=="array"
     then map(select(.type=="text") | .text) | join("\n")
     else tostring end)
' "$TRANSCRIPT" 2>/dev/null || true)

[ -z "$LAST" ] && exit 0

MISSING=()
while IFS= read -r ITEM; do
  [ -z "$ITEM" ] && continue
  if ! echo "$LAST" | grep -qF "$ITEM"; then
    MISSING+=("$ITEM")
  fi
done < <(awk '/^required:/{p=1; next} p && /^  - /{sub(/^  - /, ""); print; next} p && !/^  /{p=0}' "$PROJECT_PRECOMMIT_CHECKLIST")

if [ ${#MISSING[@]} -gt 0 ]; then
  {
    echo "task-completed-checklist: required items missing in last assistant message:"
    printf '  - %s\n' "${MISSING[@]}"
  } >&2
  exit 2
fi
exit 0
