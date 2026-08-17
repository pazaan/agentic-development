#!/usr/bin/env bash
# Hook: UserPromptSubmit
# Pattern-matches the user's prompt against trigger phrases for known
# project skills. When a trigger fires AND the matching skill has not been
# invoked in the last N transcript entries (recency-windowed — skills
# loaded at session start decay out of attention over long sessions),
# append a system reminder to the prompt nudging the agent to invoke the
# skill before proceeding.
#
# Soft intervention: writes to stdout (appended as additional context),
# never blocks (exit 0). Loud failures live in pretooluse-skill-gate.sh.
#
# Tuning:
#   $SKILL_NUDGE_RECENCY  — entries to look back (default 50)
#
# Fails open on infrastructure problems (no jq, no transcript, etc).
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

EVENT=$(cat)

PROMPT=$(echo "$EVENT" | jq -r '.prompt // ""' 2>/dev/null || true)
[ -z "$PROMPT" ] && exit 0

TRANSCRIPT=$(echo "$EVENT" | jq -r '.transcript_path // ""' 2>/dev/null || true)
[ -z "$TRANSCRIPT" ] && exit 0
[ ! -f "$TRANSCRIPT" ] && exit 0

RECENCY="${SKILL_NUDGE_RECENCY:-50}"

# Matched skills + human labels. Parallel arrays (not an associative array)
# so this hook works on macOS's default /bin/bash 3.2, which has no
# `declare -A`. First label wins per skill.
MATCHED_SKILLS=()
MATCHED_LABELS=()

# already_matched <skill> — exit 0 if $skill is already in MATCHED_SKILLS.
already_matched() {
  local target="$1" s
  if [ "${#MATCHED_SKILLS[@]}" -eq 0 ]; then
    return 1
  fi
  for s in "${MATCHED_SKILLS[@]}"; do
    [ "$s" = "$target" ] && return 0
  done
  return 1
}

# check <regex> <skill> <label>
# If $PROMPT matches the (extended, case-insensitive) regex AND we haven't
# already matched this skill, record it.
check() {
  local pattern="$1" skill="$2" label="$3"
  if echo "$PROMPT" | grep -qiE "$pattern"; then
    if ! already_matched "$skill"; then
      MATCHED_SKILLS+=("$skill")
      MATCHED_LABELS+=("$label")
    fi
  fi
}

# --- Triggers ------------------------------------------------------------

# pr-body-protocol
check '\bpush\b.*\b(prs?|stacks?|branch(es)?|remote)\b' \
      'agentic-development:pr-body-protocol' \
      'pushing / submitting PRs'
check '\b(create|open|submit|update)\b.*\b(prs?|pull[-_ ]?requests?)\b' \
      'agentic-development:pr-body-protocol' \
      'creating / updating PRs'
check '\bprs?\b.*\b(body|description|title|message)\b' \
      'agentic-development:pr-body-protocol' \
      'PR body / title'

# reviewing-code
check '\b(review|audit)\b.*\b(this[[:space:]]+)?(prs?|diffs?|code|changes?)\b' \
      'agentic-development:reviewing-code' \
      'reviewing code / a PR'
check '\bcode[[:space:]]+review\b' \
      'agentic-development:reviewing-code' \
      'reviewing code / a PR'

# stacked-prs — one skill for git-spice, GitHub Stacks, and plain PRs. The
# skill's Step 0 resolves which of the three owns the repo; the nudge only
# needs to fire on the intent.
check '\b(re)?stack\b' \
      'agentic-development:stacked-prs' \
      'stacked-PR ops'
check '\bgit[-_[:space:]]?spice\b' \
      'agentic-development:stacked-prs' \
      'stacked-PR ops'
check '\bgh[[:space:]]+stack\b' \
      'agentic-development:stacked-prs' \
      'stacked-PR ops'
check '\bgithub[[:space:]]+stacks?\b' \
      'agentic-development:stacked-prs' \
      'stacked-PR ops'
check '\bgs[[:space:]]+(ss|bs|stack|branch)\b' \
      'agentic-development:stacked-prs' \
      'stacked-PR ops'

# ticket-as-contract
check '\bacceptance[[:space:]]+criteria\b' \
      'agentic-development:ticket-as-contract' \
      'treating a ticket as the contract'
check '\bAC-?[0-9]+\b' \
      'agentic-development:ticket-as-contract' \
      'treating a ticket as the contract'

# --- Recency check + emit ------------------------------------------------

[ "${#MATCHED_SKILLS[@]}" -eq 0 ] && exit 0

NUDGES=()
i=0
while [ "$i" -lt "${#MATCHED_SKILLS[@]}" ]; do
  SKILL="${MATCHED_SKILLS[$i]}"
  LABEL="${MATCHED_LABELS[$i]}"
  i=$((i + 1))

  HITS=$(jq -rs --arg skill "$SKILL" --argjson n "$RECENCY" '
    .[(-1 * $n):]
    | [ .[]
        | select(.type=="assistant")
        | .message.content // []
        | (if type=="array" then . else [] end)
        | .[]
        | select(.type=="tool_use" and .name=="Skill")
        | .input.skill
        | select(. == $skill)
      ] | length
  ' "$TRANSCRIPT" 2>/dev/null || echo 0)

  if [ "${HITS:-0}" -eq 0 ]; then
    NUDGES+=("- For ${LABEL}: invoke \`${SKILL}\` before proceeding.")
  fi
done

[ "${#NUDGES[@]}" -eq 0 ] && exit 0

# Inject as additional context. UserPromptSubmit hooks emit stdout as
# context appended to the user's prompt.
{
  echo "<system-reminder>"
  echo "Skill-recall nudge: the user's prompt looks like one or more skill-gated"
  echo "tasks, and those skills have not been invoked in the last ${RECENCY}"
  echo "transcript entries. The skills exist because these are recurring failure"
  echo "modes — re-derive from skill, not from memory:"
  echo
  printf '%s\n' "${NUDGES[@]}"
  echo
  echo "Invoke the skill(s) first, then continue with the user's request."
  echo "</system-reminder>"
}
exit 0
