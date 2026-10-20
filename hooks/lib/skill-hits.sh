# Sourced by userpromptsubmit-skill-nudge.sh and pretooluse-skill-gate.sh.
#
# skill_hits <transcript> [window]
#   Prints each skill name the transcript's assistant turns invoked through
#   the Skill tool, once per name. With a window, only the last <window>
#   JSONL entries count; without one, the whole transcript does. Lines that
#   are not valid JSON are skipped, so a half-written last entry never
#   hides earlier hits. Prints nothing on any failure: callers treat no
#   output as "not invoked" and decide for themselves whether that blocks.
skill_hits() {
  local transcript="$1" window="${2:-}"
  {
    if [ -n "$window" ]; then
      tail -n "$window" "$transcript"
    else
      cat "$transcript"
    fi
  } 2>/dev/null | jq -rR '
    fromjson?
    | select(.type == "assistant")
    | .message.content // []
    | (if type == "array" then . else [] end)
    | .[]
    | select(.type == "tool_use" and .name == "Skill")
    | .input.skill // empty
  ' 2>/dev/null | sort -u || true
}
