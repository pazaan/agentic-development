#!/usr/bin/env bash
# Hook: UserPromptSubmit
# When the user's prompt is a request for a skill-gated task AND the
# matching skill has not been invoked in the last N transcript entries
# (recency-windowed — skills loaded at session start decay out of attention
# over long sessions), append a system reminder nudging the agent to invoke
# the skill before proceeding.
#
# A trigger fires only on a request: its verb opens a sentence, optionally
# after "please" / "can you" / "could you". A prompt that merely mentions a
# skill-shaped name ("What calls pr-review-complex?") stays silent, and so
# does a harness-injected message (task notification, subagent hand-back),
# which is skipped before any trigger runs.
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

. "$(dirname "${BASH_SOURCE[0]}")/lib/skill-hits.sh"

# Line one is the transcript path; everything after it is the prompt,
# newlines intact, so each prompt line can open a sentence.
TRANSCRIPT=""
PROMPT=""
{
  IFS= read -r TRANSCRIPT || true
  PROMPT=$(cat)
} < <(jq -r '(.transcript_path // ""), (.prompt // "")' 2>/dev/null || true)

[ -z "$PROMPT" ] && exit 0

# Harness-injected messages arrive as prompts but carry no user request.
# Only the opening is checked: real user text may quote a tag later on.
OPENING="${PROMPT#"${PROMPT%%[![:space:]]*}"}"
case "$OPENING" in
  '<task-notification>'* | '<agent-message'* | '<teammate-message'* | \
  '<system-reminder>'* | 'Another Claude session sent a message:'* | \
  '<local-command-'* | '<command-name>'* | '<bash-input>'* | '<bash-stdout>'*)
    exit 0 ;;
esac

[ -z "$TRANSCRIPT" ] && exit 0
[ ! -f "$TRANSCRIPT" ] && exit 0

RECENCY="${SKILL_NUDGE_RECENCY:-50}"

# The request shape every trigger shares: a sentence opening (prompt or line
# start, or after . ! ? ; :), then an optional lead-in, then the trigger.
REQUEST='(^|[.!?;:][[:space:]]+)[[:space:]]*((please|ok|okay|now|then|so|and|also),?[[:space:]]+)*((can|could|would|will)[[:space:]]+you[[:space:]]+)?(please[[:space:]]+)?((carefully|thoroughly|quickly|just|also)[[:space:]]+)?'

# Skill names invoked within the window, read on the first trigger hit.
unset RECENT_SKILLS
NUDGES=()

# check <skill> <label> <trigger regex>
# Nudge for <skill> when the prompt makes a request matching <trigger> and
# the skill is absent from the recency window.
check() {
  local skill="$1" label="$2" trigger="$3"
  printf '%s\n' "$PROMPT" | grep -qiE "${REQUEST}(${trigger})" || return 0
  [ -n "${RECENT_SKILLS+set}" ] || RECENT_SKILLS=$(skill_hits "$TRANSCRIPT" "$RECENCY")
  case $'\n'"$RECENT_SKILLS"$'\n' in
    *$'\n'"$skill"$'\n'*) return 0 ;;
  esac
  NUDGES+=("- For ${label}: invoke \`${skill}\` before proceeding.")
}

# --- Triggers ------------------------------------------------------------

check 'agentic-development:pr-body-protocol' 'creating / updating PRs' \
  '(push|submit)\b[^.!?]*\b(prs?|pull[-_ ]?requests?|stacks?|branch(es)?|remote)\b|(create|open|submit|update|write|draft|edit|rewrite)\b[^.!?]*\b(prs?|pull[-_ ]?requests?)\b'

check 'agentic-development:reviewing-code' 'reviewing code / a PR' \
  '(re-?)?(review|audit)[[:space:]]+(this|that|the|my|our|these|those|prs?|pull|#?[0-9]+|diffs?|branch(es)?|changes?|code|commits?|work)\b|(do|run|give|start|perform)[[:space:]]+(me[[:space:]]+)?an?[[:space:]]+((code|quick|full|thorough|careful)[[:space:]]+)?review\b'

# The skill's Step 0 resolves which stack tool owns the repo, so the nudge
# fires on stacking intent whatever the tool.
check 'agentic-development:stacked-prs' 'stacked-PR ops' \
  'restack\b|stack[[:space:]]+(the|these|those|this|my|our|them|it|on|onto|up|branch(es)?|prs?)\b|(use|run|try|install|configure|set[[:space:]]+up|switch[[:space:]]+to)\b[^.!?]*\b(git[-_[:space:]]?spice|github[[:space:]]+stacks?)\b|gs[[:space:]]+(ss|bs|branch)\b'


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
