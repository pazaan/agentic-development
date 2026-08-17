#!/usr/bin/env bash
# Hook: PreToolUse
# Blocks tool calls that match a "skill-gated action" until the required
# skill has been invoked at least once in the current session's transcript.
#
# Gated actions (v2):
#   - PR body / title writes via gh or git-spice / gs
#   - PR patches via gh REST API (PATCH on .../pulls/<N>)
#   - PR creation via gh REST API (POST on .../pulls)
#     → require: agentic-development:pr-body-protocol
#   - PR review submissions (gh pr review, gh api .../reviews POST)
#     → require: agentic-development:reviewing-code
#
# Subagent sessions: the event's transcript_path is the parent session's
# transcript, so a Skill invocation made by a subagent is invisible there.
# Before blocking, the gate also scans the subagent transcripts referenced
# from the parent transcript (tasks/<id>.output).
#
# Exit 0 = allow; event proceeds.
# Exit 2 = block; stderr message surfaced to the agent.
#
# Fails open (exit 0) on infrastructure problems: missing jq, missing
# transcript, malformed event payload. The hook is a forcing function for
# the in-session common case, not a hard production guarantee.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

EVENT=$(cat)

TOOL_NAME=$(echo "$EVENT" | jq -r '.tool_name // ""' 2>/dev/null || true)
[ "$TOOL_NAME" = "Bash" ] || exit 0

COMMAND=$(echo "$EVENT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)
[ -z "$COMMAND" ] && exit 0

# Help and dry-run invocations inspect a command; they cannot write a PR
# body or submit a review, so gating them is a false positive. The second
# clause guards against a stray `-h` inside a heredoc body: a real help
# invocation never carries a title/body payload.
if echo "$COMMAND" | grep -qE '(^|[[:space:]])(--help|-h|--dry-run)([[:space:]]|$)' \
   && ! echo "$COMMAND" | grep -qE '(^|[[:space:]])(--body|--title|-b|-t)([[:space:]]|=)'; then
  exit 0
fi

REQUIRED_SKILL=""
GATE_REASON=""

# Pattern match the command. Order matters — first match wins.

# --- PR body / title writes ---------------------------------------------

# gh pr create / gh pr edit
if echo "$COMMAND" | grep -qE '\bgh[[:space:]]+pr[[:space:]]+(create|edit)\b'; then
  REQUIRED_SKILL="agentic-development:pr-body-protocol"
  GATE_REASON="writes a PR title/body via gh pr"

# gh api PATCH on a pull request (either arg order)
elif echo "$COMMAND" | grep -qE '\bgh[[:space:]]+api\b.*(-X[[:space:]]+PATCH.*\bpulls/[0-9]+|\bpulls/[0-9]+.*-X[[:space:]]+PATCH)'; then
  REQUIRED_SKILL="agentic-development:pr-body-protocol"
  GATE_REASON="patches a PR via the GitHub REST API"

# gh api POST on .../pulls — PR creation via REST, the create-side twin of
# `gh pr create`. Field flags (-f/-F/--field/--raw-field) imply POST even
# without an explicit -X. Sub-resources (pulls/N/reviews, pulls/N/comments)
# are excluded so the review rules below still win for them.
elif echo "$COMMAND" | grep -qE '\bgh[[:space:]]+api\b.*\bpulls\b' \
  && ! echo "$COMMAND" | grep -qE '\bpulls/[0-9]+/' \
  && echo "$COMMAND" | grep -qE '(-X[[:space:]]+POST|--method([[:space:]]+|=)POST|(^|[[:space:]])(-f|-F|--field|--raw-field)([[:space:]]|=))'; then
  REQUIRED_SKILL="agentic-development:pr-body-protocol"
  GATE_REASON="creates a PR via the GitHub REST API"

# git-spice / git spice push paths (branch submit / stack submit) — covers
# the most common project PR-creation path. Catches `git-spice`, `git spice`
# (subcommand form), and `gs` (user shortname).
elif echo "$COMMAND" | grep -qE '\b(git-spice|git[[:space:]]+spice|gs)[[:space:]]+(branch|stack|bs|ss|bc)[[:space:]]+(submit|create)\b'; then
  REQUIRED_SKILL="agentic-development:pr-body-protocol"
  GATE_REASON="creates/updates PRs via git-spice"

# Common `gs ss` / `gs bs` shorthand (no second word).
elif echo "$COMMAND" | grep -qE '\bgs[[:space:]]+(ss|bs)\b'; then
  REQUIRED_SKILL="agentic-development:pr-body-protocol"
  GATE_REASON="creates/updates PRs via git-spice"

# GitHub Stacks (`gh stack submit`, and the extension's default `gs` alias).
# `gh stack push` only moves commits — it doesn't open PRs — so it is not
# gated.
elif echo "$COMMAND" | grep -qE '\b(gh[[:space:]]+stack|gs)[[:space:]]+submit\b'; then
  REQUIRED_SKILL="agentic-development:pr-body-protocol"
  GATE_REASON="creates/updates PRs via GitHub Stacks"

# --- PR reviews ----------------------------------------------------------

# gh pr review
elif echo "$COMMAND" | grep -qE '\bgh[[:space:]]+pr[[:space:]]+review\b'; then
  REQUIRED_SKILL="agentic-development:reviewing-code"
  GATE_REASON="submits a PR review via gh"

# gh api POST on .../pulls/N/reviews
elif echo "$COMMAND" | grep -qE '\bgh[[:space:]]+api\b.*\bpulls/[0-9]+/reviews\b'; then
  REQUIRED_SKILL="agentic-development:reviewing-code"
  GATE_REASON="submits a PR review via the GitHub REST API"
fi

[ -z "$REQUIRED_SKILL" ] && exit 0

TRANSCRIPT=$(echo "$EVENT" | jq -r '.transcript_path // ""' 2>/dev/null || true)
[ -z "$TRANSCRIPT" ] && exit 0
[ ! -f "$TRANSCRIPT" ] && exit 0

# Count prior Skill tool_use entries whose `input.skill` exactly matches the
# required skill name. Each transcript line is one JSON record (JSONL).
# Session-wide for the gate (not recency-windowed) — by the time we're at a
# tool call, even an old invocation means the skill was at least loaded once
# in this session.
count_skill_hits() {
  jq -rs --arg skill "$REQUIRED_SKILL" '
    [ .[]
      | select(.type=="assistant")
      | .message.content // []
      | (if type=="array" then . else [] end)
      | .[]
      | select(.type=="tool_use" and .name=="Skill")
      | .input.skill
      | select(. == $skill)
    ] | length
  ' "$1" 2>/dev/null || echo 0
}

HITS=$(count_skill_hits "$TRANSCRIPT")

# Subagent fallback: a subagent's own Skill invocations live in its own
# transcript (tasks/<id>.output), not in the parent transcript this event
# carries. The parent transcript records each spawned agent's output_file
# path at launch, so those files are exactly this session's subagents —
# scan them before blocking.
if [ "${HITS:-0}" -eq 0 ]; then
  while IFS= read -r SUB; do
    [ -n "$SUB" ] && [ -f "$SUB" ] || continue
    SUB_HITS=$(count_skill_hits "$SUB")
    if [ "${SUB_HITS:-0}" -gt 0 ]; then
      HITS=1
      break
    fi
  done < <(grep -hoE '/[^"[:space:]\\]*/tasks/[^"[:space:]\\]*\.output' "$TRANSCRIPT" 2>/dev/null | sort -u)
fi

if [ "${HITS:-0}" -eq 0 ]; then
  {
    echo "pretooluse-skill-gate: blocking."
    echo
    echo "This Bash call ${GATE_REASON}, but the required skill"
    echo "  ${REQUIRED_SKILL}"
    echo "has not been invoked yet in this session. The skill exists because"
    echo "this is a recurring failure mode — drafting from memory drops"
    echo "project-specific rules."
    echo
    echo "Invoke the skill, follow it, then retry:"
    echo "  Skill { skill: \"${REQUIRED_SKILL}\" }"
  } >&2
  exit 2
fi
exit 0
