#!/usr/bin/env bash
# Hook: PostToolUse (matcher: Edit|Write)
# Judges the comment lines an edit ADDED, and nothing else. Two stages:
#
#   1. Extract added comment lines. Zero of them → exit 0, silently. A
#      code-only edit never reaches stage 2.
#   2. Judge that comment text against the rules in
#      agentic-development:no-bullshit-comments — unresolvable references,
#      self-defending phrasing, a spelled count where a symbol belongs, and
#      a heuristic for narration of the line below.
#
# The remedy surfaced to the agent is always "rewrite or delete the
# comment". Adjacent code is read as the reference the comment is measured
# against; it is never judged.
#
# Runs after the write, so nothing is blocked: exit 2 surfaces stderr to
# the agent, which can revise in place.
#
# Tuning:
#   $COMMENT_CHECK_DISABLE   — any non-empty value: no-op
#   $COMMENT_CHECK_RECENCY   — entries to look back for the skill (default 100)
#
# Fails open on infrastructure problems (no jq, no file_path, unknown
# language).
set -euo pipefail

[ -n "${COMMENT_CHECK_DISABLE:-}" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

EVENT=$(cat)

TOOL_NAME=$(echo "$EVENT" | jq -r '.tool_name // ""' 2>/dev/null || true)
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(echo "$EVENT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || true)
[ -z "$FILE_PATH" ] && exit 0

# Comment syntax by extension. Prose files are out of scope — a Markdown
# document is all "comment", so every rule here would misfire.
case "$FILE_PATH" in
  *.rs|*.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.go|*.java|*.c|*.h|*.cc|*.cpp|*.hpp|*.swift|*.kt|*.kts|*.scala|*.php|*.dart|*.proto|*.css|*.scss)
    SYNTAX=slash ;;
  *.svelte|*.vue|*.html|*.xml)
    SYNTAX=markup ;;
  *.py)
    SYNTAX=python ;;
  *.sh|*.bash|*.zsh|*.rb|*.yaml|*.yml|*.toml|*.tf|*.pl|*.r|*.ex|*.exs)
    SYNTAX=hash ;;
  *.sql|*.lua|*.hs|*.elm)
    SYNTAX=dash ;;
  *) exit 0 ;;
esac

# Added lines only. For Edit that is new_string minus old_string; for Write
# the whole payload, since the file did not exist in this form before.
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

if [ "$TOOL_NAME" = "Edit" ]; then
  echo "$EVENT" | jq -r '.tool_input.old_string // ""' > "$TMP_DIR/old" 2>/dev/null || true
  echo "$EVENT" | jq -r '.tool_input.new_string // ""' > "$TMP_DIR/new" 2>/dev/null || true
  grep -Fxv -f "$TMP_DIR/old" "$TMP_DIR/new" > "$TMP_DIR/added" 2>/dev/null || true
else
  echo "$EVENT" | jq -r '.tool_input.content // ""' > "$TMP_DIR/added" 2>/dev/null || true
fi

[ -s "$TMP_DIR/added" ] || exit 0

FINDINGS=$(awk -v syntax="$SYNTAX" '
function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }

# Comment text of $0, or "" when the line carries none. Block state is
# tracked across lines so a /* … */ or """ … """ body counts as comment.
function comment_text(line,   probe, at, text) {
  probe = line

  if (syntax == "slash" || syntax == "markup") {
    if (in_block) {
      if (probe ~ /\*\//) in_block = 0
      gsub(/\/\*|\*\/|^[[:space:]]*\*/, "", probe)
      return trim(probe)
    }
    if (probe ~ /\/\*/) {
      if (probe !~ /\*\//) in_block = 1
      gsub(/.*\/\*|\*\/.*/, "", probe)
      return trim(probe)
    }
  }

  if (syntax == "markup") {
    if (in_markup) {
      if (probe ~ /-->/) in_markup = 0
      gsub(/<!--|-->/, "", probe)
      return trim(probe)
    }
    if (probe ~ /<!--/) {
      if (probe !~ /-->/) in_markup = 1
      gsub(/.*<!--|-->.*/, "", probe)
      return trim(probe)
    }
  }

  if (syntax == "python") {
    if (in_doc) {
      if (probe ~ /"""/) in_doc = 0
      gsub(/"""/, "", probe)
      return trim(probe)
    }
    if (probe ~ /"""/) {
      if (gsub(/"""/, "", probe) == 1) in_doc = 1
      return trim(probe)
    }
  }

  if (syntax == "slash" || syntax == "markup") {
    # A protocol slash-slash is not a comment marker.
    gsub(/https?:\/\//, "", probe)
    at = index(probe, "//")
    if (at > 0) return trim(substr(probe, at + 2))
    return ""
  }

  if (syntax == "python" || syntax == "hash") {
    if (probe ~ /^[[:space:]]*#!/) return ""
    gsub(/\$\{[^}]*\}/, " ", probe)
    if (probe !~ /(^|[[:space:]])#/) return ""
    at = index(probe, "#")
    return trim(substr(probe, at + 1))
  }

  if (syntax == "dash") {
    at = index(probe, "--")
    if (at > 0) return trim(substr(probe, at + 2))
    return ""
  }

  return ""
}

# Identifier fragments of a code line, camel and snake boundaries split,
# as a space-padded haystack.
function fragments(line,   i, ch, prev, out) {
  out = ""
  prev = ""
  for (i = 1; i <= length(line); i++) {
    ch = substr(line, i, 1)
    if (ch ~ /[A-Z]/ && prev ~ /[a-z0-9]/) out = out " "
    out = out ch
    prev = ch
  }
  gsub(/[^A-Za-z]+/, " ", out)
  return " " tolower(trim(out)) " "
}

function judge(body, code, label,   probe, found, hay, n, words, kept, echoed, rationale, k, w) {
  probe = tolower(body)
  found = ""

  if (probe ~ /(^|[^a-z])ac-?[0-9]/ || probe ~ /acceptance criteri/)
    found = "cites an acceptance criterion — task reasoning belongs in the PR body"
  else if (probe ~ /(in|for) this (pr|pull request|branch|change)/ || probe ~ /on this branch/ || probe ~ /as (discussed|agreed|decided) (above|earlier|elsewhere)/)
    found = "refers to the PR or branch — meaningless once merged"
  else if (probe ~ /~\/\.claude\/(specs|plans)/ || probe ~ /docs\/superpowers/ || probe ~ /(specs?|plans?)\/[0-9]{4}-[0-9]{2}-[0-9]{2}/)
    found = "points at a path outside the repo — the reader cannot resolve it"
  else if (probe ~ /belt[ -]and[ -]braces/ || probe ~ /requirement,? not/ || probe ~ /not (mere|just )?(thoroughness|paranoia|defensive)/ || probe ~ /to be clear,? (this is )?not/)
    found = "argues with an imagined critic — state the fact once"
  else if (probe ~ /(the|all|none of the|any of the|each of the) (two|three|four|five|six|seven|eight|nine|ten)([^a-z]|$)/)
    found = "carries a spelled count — name the symbol instead, counts go stale silently"
  else if (probe ~ /§[0-9]/ && probe !~ /[a-z]{3,}.*[a-z]{3,}.*[a-z]{3,}/)
    found = "leans on a section number for its content — the comment must stand alone"

  if (found == "" && code != "") {
    # Narration test: does the block mostly restate the identifiers of the
    # code under it, carrying no reason of its own?
    hay = fragments(code)
    n = split(probe, words, /[^a-z0-9]+/)
    kept = 0; echoed = 0; rationale = 0
    for (k = 1; k <= n; k++) {
      w = words[k]
      if (length(w) < 4) continue
      if (index(STOP, " " w " ") > 0) continue
      if (index(REASON, " " w " ") > 0) rationale = 1
      kept++
      if (index(hay, " " w " ") > 0) echoed++
    }
    if (!rationale && kept >= 2 && echoed * 10 >= kept * 6)
      found = "restates the identifiers on the line below — code already documents what happens"
  }

  if (found != "") printf "  %s\n    → %s\n", label, found
}

{ raw[NR] = $0; text[NR] = comment_text($0); }

END {
  STOP = " the a an of to in on for and or is are it its this that with as be by not no all none any each from at into "
  REASON = " because since so that otherwise must cannot never always avoid prevent upstream downstream bug workaround safe unsafe order matters race deliberate requires required assumes assumption instead unless "

  i = 1
  while (i <= NR) {
    if (text[i] == "") { i++; continue }

    # Contiguous comment lines are one comment.
    body = text[i]
    j = i + 1
    while (j <= NR && text[j] != "") { body = body " " text[j]; j++ }

    code = ""
    for (k = j; k <= NR; k++) {
      if (text[k] != "") continue
      if (trim(raw[k]) == "") continue
      code = raw[k]
      break
    }

    judge(body, code, text[i])
    i = j
  }
}
' "$TMP_DIR/added")

if [ -n "$FINDINGS" ]; then
  {
    echo "no-bullshit-comments: comment lines added by this ${TOOL_NAME} of"
    echo "${FILE_PATH} look like ones the skill rules out:"
    echo
    echo "$FINDINGS"
    echo "Rewrite each one to a single fact the code cannot state — rationale,"
    echo "hazard, non-obvious constraint, decision plus reason, or a measurement"
    echo "the reader cannot re-derive — or delete it. Change the comment only;"
    echo "the code is not what this check is about, and comments already in the"
    echo "file are out of scope."
  } >&2
  exit 2
fi

# Comments added, none flagged: surface the rules once per window, at the
# moment the agent is actually writing comments.
TRANSCRIPT=$(echo "$EVENT" | jq -r '.transcript_path // ""' 2>/dev/null || true)
[ -z "$TRANSCRIPT" ] && exit 0
[ ! -f "$TRANSCRIPT" ] && exit 0

RECENCY="${COMMENT_CHECK_RECENCY:-100}"
HITS=$(jq -rs --argjson n "$RECENCY" '
  .[(-1 * $n):]
  | [ .[]
      | select(.type=="assistant")
      | .message.content // []
      | (if type=="array" then . else [] end)
      | .[]
      | select(.type=="tool_use" and .name=="Skill")
      | .input.skill
      | select(. == "agentic-development:no-bullshit-comments")
    ] | length
' "$TRANSCRIPT" 2>/dev/null || echo 0)

[ "${HITS:-0}" -gt 0 ] && exit 0

{
  echo "no-bullshit-comments: this edit added comments and the skill has not"
  echo "been invoked in the last ${RECENCY} transcript entries. A comment earns"
  echo "its place only by carrying rationale, a hazard, a non-obvious"
  echo "constraint, a decision plus its reason, or a measurement the reader"
  echo "cannot re-derive. Every reference in it must resolve from inside the"
  echo "repo. Check the comments you just wrote against"
  echo "agentic-development:no-bullshit-comments; leave the code alone."
} >&2
exit 2
