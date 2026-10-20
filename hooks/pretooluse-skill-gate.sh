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
# Matches commands, not text: heredoc bodies are dropped, each quoted string
# collapses to one opaque word, and every pattern is anchored at a command
# position (start, or after ; & | && || $( ( or a newline). So a commit
# message, grep pattern or heredoc that mentions `gh pr edit` passes.
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

. "$(dirname "${BASH_SOURCE[0]}")/lib/skill-hits.sh"

EVENT=$(cat)

TOOL_NAME=$(echo "$EVENT" | jq -r '.tool_name // ""' 2>/dev/null || true)
[ "$TOOL_NAME" = "Bash" ] || exit 0

COMMAND=$(echo "$EVENT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)
[ -z "$COMMAND" ] && exit 0

# One command per line: heredoc bodies dropped, a quoted string kept as a
# single word whose blanks and shell operators become `_` (so a quoted URL
# still reads as `pulls/12`, but quoted text can never open a command), then
# split at every command separator.
SEGMENTS=$(printf '%s\n' "$COMMAND" | awk '
  function word(c) { return (c ~ /[[:space:];&|()<>$`]/) ? "_" : c }
  BEGIN { quote = ""; buf = ""; pending = 0; body = 0 }
  {
    line = $0
    if (body) {
      probe = line
      if (strip[next_delim]) sub(/^\t+/, "", probe)
      if (probe == delim[next_delim] && ++next_delim > pending) { body = 0; pending = 0 }
      next
    }
    n = length(line)
    i = 1
    while (i <= n) {
      c = substr(line, i, 1)
      if (quote == "\047") {
        if (c == "\047") quote = ""; else buf = buf word(c)
        i++; continue
      }
      if (quote == "\"") {
        if (c == "\\" && i < n) { buf = buf word(substr(line, i + 1, 1)); i += 2; continue }
        if (c == "\"") quote = ""; else buf = buf word(c)
        i++; continue
      }
      if (c == "\\") { buf = buf "_"; i += 2; continue }
      if (c == "\047" || c == "\"") { quote = c; i++; continue }
      if (substr(line, i, 3) == "<<<") { buf = buf "<<<"; i += 3; continue }
      if (substr(line, i, 2) == "<<") {
        j = i + 2
        dash = 0
        if (substr(line, j, 1) == "-") { dash = 1; j++ }
        while (substr(line, j, 1) ~ /[ \t]/) j++
        d = ""
        while (j <= n && substr(line, j, 1) !~ /[ \t;&|<>()]/) {
          ch = substr(line, j, 1)
          if (ch != "\047" && ch != "\"" && ch != "\\") d = d ch
          j++
        }
        if (d != "") { pending++; delim[pending] = d; strip[pending] = dash }
        buf = buf "<<_"
        i = j; continue
      }
      buf = buf c
      i++
    }
    if (quote != "") { buf = buf "_"; next }
    print buf
    buf = ""
    if (pending) { body = 1; next_delim = 1 }
  }
  END { if (buf != "") print buf }
' | tr ';&|()' '\n\n\n\n\n' | sed -e 's/^[[:space:]]*//' -e 's/^\$$//' 2>/dev/null || true)

REQUIRED_SKILL=""
GATE_REASON=""

# First gated segment wins. Patterns are anchored at `^`: every segment
# starts at a command position.
while IFS= read -r SEG; do
  [ -z "$SEG" ] && continue

  # Help and dry-run invocations inspect a command; they cannot write a PR
  # body or submit a review. Without this, `git-spice branch submit --help`
  # blocks — observed live.
  if echo "$SEG" | grep -qE '(^|[[:space:]])(--help|-h|--dry-run)([[:space:]]|$)'; then
    continue
  fi

  # --- PR body / title writes -------------------------------------------

  if echo "$SEG" | grep -qE '^gh[[:space:]]+pr[[:space:]]+(create|edit)\b'; then
    REQUIRED_SKILL="agentic-development:pr-body-protocol"
    GATE_REASON="writes a PR title/body via gh pr"

  elif echo "$SEG" | grep -qE '^gh[[:space:]]+api\b.*(-X[[:space:]]+PATCH.*\bpulls/[0-9]+|\bpulls/[0-9]+.*-X[[:space:]]+PATCH)'; then
    REQUIRED_SKILL="agentic-development:pr-body-protocol"
    GATE_REASON="patches a PR via the GitHub REST API"

  # gh api POST on .../pulls — PR creation via REST, the create-side twin of
  # `gh pr create`. Field flags (-f/-F/--field/--raw-field) imply POST even
  # without an explicit -X. Sub-resources (pulls/N/reviews, pulls/N/comments)
  # are excluded so the review rules below still win for them.
  elif echo "$SEG" | grep -qE '^gh[[:space:]]+api\b.*\bpulls\b' \
    && ! echo "$SEG" | grep -qE '\bpulls/[0-9]+/' \
    && echo "$SEG" | grep -qE '(-X[[:space:]]+POST|--method([[:space:]]+|=)POST|(^|[[:space:]])(-f|-F|--field|--raw-field)([[:space:]]|=))'; then
    REQUIRED_SKILL="agentic-development:pr-body-protocol"
    GATE_REASON="creates a PR via the GitHub REST API"

  # git-spice / git spice push paths (branch submit / stack submit) — covers
  # the most common project PR-creation path. Catches `git-spice`, `git spice`
  # (subcommand form), and `gs` (user shortname).
  elif echo "$SEG" | grep -qE '^(git-spice|git[[:space:]]+spice|gs)[[:space:]]+(branch|stack|bs|ss|bc)[[:space:]]+(submit|create)\b'; then
    REQUIRED_SKILL="agentic-development:pr-body-protocol"
    GATE_REASON="creates/updates PRs via git-spice"

  elif echo "$SEG" | grep -qE '^gs[[:space:]]+(ss|bs)\b'; then
    REQUIRED_SKILL="agentic-development:pr-body-protocol"
    GATE_REASON="creates/updates PRs via git-spice"

  # GitHub Stacks (`gh stack submit`, and the extension's default `gs` alias).
  # `gh stack push` only moves commits — it doesn't open PRs — so it is not
  # gated.
  elif echo "$SEG" | grep -qE '^(gh[[:space:]]+stack|gs)[[:space:]]+submit\b'; then
    REQUIRED_SKILL="agentic-development:pr-body-protocol"
    GATE_REASON="creates/updates PRs via GitHub Stacks"

  # --- PR reviews -------------------------------------------------------

  elif echo "$SEG" | grep -qE '^gh[[:space:]]+pr[[:space:]]+review\b'; then
    REQUIRED_SKILL="agentic-development:reviewing-code"
    GATE_REASON="submits a PR review via gh"

  elif echo "$SEG" | grep -qE '^gh[[:space:]]+api\b.*\bpulls/[0-9]+/reviews\b'; then
    REQUIRED_SKILL="agentic-development:reviewing-code"
    GATE_REASON="submits a PR review via the GitHub REST API"
  fi

  [ -n "$REQUIRED_SKILL" ] && break
done <<< "$SEGMENTS"

[ -z "$REQUIRED_SKILL" ] && exit 0

TRANSCRIPT=$(echo "$EVENT" | jq -r '.transcript_path // ""' 2>/dev/null || true)
[ -z "$TRANSCRIPT" ] && exit 0
[ ! -f "$TRANSCRIPT" ] && exit 0

# invoked_in <transcript> — exit 0 when <transcript> invoked the required
# skill. Session-wide (no window): by the time we're at a tool call, even an
# old invocation means the skill was loaded once in this session.
invoked_in() {
  case $'\n'"$(skill_hits "$1")"$'\n' in
    *$'\n'"$REQUIRED_SKILL"$'\n'*) return 0 ;;
  esac
  return 1
}

# Subagent fallback: a subagent's own Skill invocations live in its own
# transcript (tasks/<id>.output), not in the parent transcript this event
# carries. The parent transcript records each spawned agent's output_file
# path at launch, so those files are exactly this session's subagents —
# scan them before blocking.
invoked_in "$TRANSCRIPT" && exit 0
while IFS= read -r SUB; do
  [ -n "$SUB" ] && [ -f "$SUB" ] || continue
  invoked_in "$SUB" && exit 0
done < <(grep -hoE '/[^"[:space:]\\]*/tasks/[^"[:space:]\\]*\.output' "$TRANSCRIPT" 2>/dev/null | sort -u)

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
