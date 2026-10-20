#!/usr/bin/env bash
# Fixture tests for the skill-recall pair: userpromptsubmit-skill-nudge.sh
# and pretooluse-skill-gate.sh. Each case builds the event JSON the hook
# receives on stdin and asserts the outcome — nudge: fire / silent; gate:
# block (exit 2) / allow (exit 0).
#
# Run: bash hooks/tests/run.sh. Needs only bash and jq. Exits non-zero when
# any case fails. Transcripts are written to a temp dir removed on exit.
set -uo pipefail

HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NUDGE="$HOOKS/userpromptsubmit-skill-nudge.sh"
GATE="$HOOKS/pretooluse-skill-gate.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

# transcript <file> [skill...] — a JSONL transcript whose assistant turns
# invoked each named skill.
transcript() {
  local file="$1" skill
  shift
  echo '{"type":"user","message":{"content":"hello"}}' > "$file"
  for skill in "$@"; do
    jq -nc --arg s "$skill" \
      '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}' >> "$file"
  done
}

EMPTY="$WORK/empty.jsonl"
transcript "$EMPTY"
WITH_PR_BODY="$WORK/pr-body.jsonl"
transcript "$WITH_PR_BODY" agentic-development:pr-body-protocol
WITH_SUBAGENT="$WORK/parent.jsonl"
transcript "$WORK/sub.output" agentic-development:pr-body-protocol
mkdir -p "$WORK/s/tasks"
cp "$WORK/sub.output" "$WORK/s/tasks/abc.output"
transcript "$WITH_SUBAGENT"
jq -nc --arg p "$WORK/s/tasks/abc.output" '{type:"user",toolUseResult:{outputFile:$p}}' >> "$WITH_SUBAGENT"

report() {
  local ok="$1" name="$2" detail="$3"
  if [ "$ok" = 1 ]; then
    PASS=$((PASS + 1))
    echo "PASS  $name"
  else
    FAIL=$((FAIL + 1))
    echo "FAIL  $name ($detail)"
  fi
}

# nudge <expect: fire|silent> <skill or -> <prompt> [transcript]
# fire: stdout names <skill>. silent: stdout is empty.
nudge() {
  local expect="$1" skill="$2" prompt="$3" tr="${4:-$EMPTY}" out ok=0
  out=$(jq -n --arg p "$prompt" --arg t "$tr" '{prompt:$p,transcript_path:$t}' | bash "$NUDGE")
  case "$expect" in
    fire) case "$out" in *"agentic-development:$skill"*) ok=1 ;; esac ;;
    silent) [ -z "$out" ] && ok=1 ;;
  esac
  report "$ok" "nudge $expect${skill:+ $skill}: $(printf '%s' "$prompt" | head -n 1 | cut -c1-60)" "got: ${out:-<nothing>}"
}

# gate <expect: block|allow> <command> [transcript]
gate() {
  local expect="$1" cmd="$2" tr="${3:-$EMPTY}" code ok=0
  jq -n --arg c "$cmd" --arg t "$tr" '{tool_name:"Bash",tool_input:{command:$c},transcript_path:$t}' \
    | bash "$GATE" 2>/dev/null
  code=$?
  { [ "$expect" = block ] && [ "$code" = 2 ]; } && ok=1
  { [ "$expect" = allow ] && [ "$code" = 0 ]; } && ok=1
  report "$ok" "gate $expect: $(printf '%s' "$cmd" | head -n 1 | cut -c1-60)" "exit $code"
}

echo "--- nudge"
nudge silent '' $'<task-notification>\n<task-id>b47sk5cqu</task-id>\n<status>completed</status>\n<result>\nReview this PR before merging.\n</result>\n</task-notification>'
nudge silent '' $'Another Claude session sent a message:\n<agent-message from="aa7593bfebccae92a">\n[Subagent hand-back] The text below is the final report.\nReview this PR and open a PR for this branch.\n</agent-message>'
nudge silent '' $'Another Claude session sent a message:\n<teammate-message teammate_id="territory-w">\n{"type":"idle_notification"}\n</teammate-message>'
nudge silent '' 'What calls pr-review-complex? Is that part of reviewing-code?'
nudge silent '' "what's our tech stack?"
nudge silent '' 'Show me the call stack.'
nudge silent '' 'Restart the local stack'
nudge silent '' 'what did PR 12 update?'
nudge fire reviewing-code 'Review this PR'
nudge fire reviewing-code 'Can you review my changes?'
nudge fire reviewing-code 'Thanks. Please do a thorough review'
nudge fire reviewing-code $'This came from <task-notification> earlier.\nReview this PR'
nudge fire stacked-prs 'restack the branches'
nudge fire pr-body-protocol 'open a PR for this branch'
nudge fire pr-body-protocol 'Could you update the PR description?'
nudge silent '' 'open a PR for this branch' "$WITH_PR_BODY"

echo "--- gate"
gate block 'gh pr create --title x --body y'
gate allow 'gh pr create --title x --body y' "$WITH_PR_BODY"
gate allow 'gh pr create --title x --body y' "$WITH_SUBAGENT"
gate allow 'git commit -m "mention gh pr edit"'
gate allow "grep 'gh pr review' hooks/*.sh"
gate allow $'python3 - <<\'EOF\'\nprint("gh pr edit 3 --body x")\nEOF'
gate allow $'cat <<-EOF > notes\n\tgh pr create --title t\n\tEOF'
gate allow 'echo "done; gh pr edit 3"'
gate allow 'gh pr create --help'
gate block $'cat <<EOF > body.md\ntext\nEOF\ngh pr edit 3 --body-file body.md'
gate block 'git fetch && gh pr edit 3 --body "a; b"'
gate block 'ls -h && gh pr create -t x -b y'
gate block 'out=$(gh pr review 3 --approve)'
gate block 'gh api "repos/o/r/pulls/12" -X PATCH -f body=hi'
gate block 'gh api repos/o/r/pulls -f title=t -f head=h -f base=main'
gate block 'gh api repos/o/r/pulls/12/reviews -f event=APPROVE'
gate block 'gs ss'
gate allow 'gh pr view 12 --json body'

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
