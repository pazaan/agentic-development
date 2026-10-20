# Hooks

These hooks are declared in `.claude-plugin/plugin.json` and auto-wired by
`/plugin install`. No manual `~/.claude/settings.json` edit needed.

Each hook reads its event JSON from stdin; the transcript-backed ones
resolve `transcript_path` and run their check against the JSONL. The
comment check reads only the event.

## Hooks

| Hook                                | Event               | Reads                                | Notes                                  |
|-------------------------------------|---------------------|--------------------------------------|----------------------------------------|
| `userpromptsubmit-skill-nudge.sh`   | `UserPromptSubmit`  | `prompt`, `transcript_path`          | Soft nudge — injects skill names when the user's prompt is a skill-shaped request and the skill is stale. |
| `pretooluse-skill-gate.sh`          | `PreToolUse`        | `tool_name`, `tool_input.command`    | Hard gate — blocks PR-write / review-write commands until the required skill has been invoked. |
| `posttooluse-comment-check.sh`      | `PostToolUse`       | `tool_input.{file_path,old_string,new_string,content}` | Judges the comment lines an edit added; silent unless it has a finding. |
| `task-completed-caveman-bleed.sh`   | `Stop`              | `$CAVEMAN_BLEED_THRESHOLD` (def. 40) | Heuristic; tune per project.           |

### Skill-recall pair (`userpromptsubmit-skill-nudge` + `pretooluse-skill-gate`)

Two-stage forcing function for skills the agent has been observed to skip
even when the instruction was explicit. Failure mode: project-specific
skills (PR-body shape, code-review pass, stacked-PR ops) get loaded at
session start, decay out of attention over long sessions, and the agent
falls back on training priors that don't match project convention.

Both read Skill invocations from the transcript through
`lib/skill-hits.sh`: one pass that lists every invoked skill name, with an
optional recency window.

**Nudge** (early, soft):
Fires on every `UserPromptSubmit`. If the prompt is a request for a gated
task and the matching skill has not been invoked in the last
`$SKILL_NUDGE_RECENCY` transcript entries (default 50), writes a
`<system-reminder>` block to stdout — Claude Code appends UserPromptSubmit
stdout to the user's prompt as additional context. No block, no extra turn.

**Gate** (late, hard):
Fires on `PreToolUse` for `Bash`. If the command runs a gated command and
the required skill has not been invoked anywhere in the session (including
this session's subagent transcripts), exits `2` with a stderr message
instructing what to invoke.

#### Trigger rule

- **Nudge: requests, not mentions.** A trigger fires only when its verb
  opens a sentence — at the start of the prompt or a line, or after
  `.` `!` `?` `;` `:` — optionally after a lead-in such as "please",
  "can you" or "could you". "Review this PR" and "Can you review my
  changes?" fire; "What calls pr-review-complex?", "what's our tech
  stack?" and "what did PR 12 update?" do not. The shared lead-in is
  `REQUEST`; each skill has one `check` holding its verbs and objects.
- **Nudge: harness messages are skipped.** A prompt that opens with a
  harness envelope (`<task-notification>`, `Another Claude session sent a
  message:`, `<agent-message`, `<teammate-message`, `<system-reminder>`,
  local-command output) exits before any trigger runs. Only the opening
  counts, so user text that quotes a tag mid-prompt is still read.
- **Gate: commands, not text.** The command is reduced to what executes:
  heredoc bodies are dropped and each quoted string collapses to one opaque
  word. Every pattern is then anchored at a command position — the start,
  or after `;`, `&`, `|`, `&&`, `||`, `$(`, `(` or a newline. So
  `git commit -m "... gh pr edit ..."`, `grep 'gh pr review' …` and a
  heredoc that mentions `gh pr edit` pass; `cd x && gh pr create …` is
  gated. A command position carrying `--help`, `-h` or `--dry-run` is
  inspecting a tool, not authoring a PR, and passes.

| Gated surface                                                                                     | Required skill                            |
|---------------------------------------------------------------------------------------------------|-------------------------------------------|
| `gh pr create` / `gh pr edit`; `gh api` PATCH on `pulls/<N>` or POST on `pulls`                   | `agentic-development:pr-body-protocol`    |
| `git-spice {branch,stack} submit`, `git spice …`, `gs {ss,bs}`, `gh stack submit` / `gs submit`   | `agentic-development:pr-body-protocol`    |
| Request to push / submit / open / create / update a PR                                            | `agentic-development:pr-body-protocol`    |
| `gh pr review` / `gh api .../pulls/<N>/reviews`                                                   | `agentic-development:reviewing-code`      |
| Request to review / audit code, a PR, a diff or changes, or to "do a review"                      | `agentic-development:reviewing-code`      |
| Request to restack / stack branches, or to use git-spice / GitHub Stacks                          | `agentic-development:stacked-prs`         |

To add a rule:

1. **Gate** — append an `elif … REQUIRED_SKILL=… GATE_REASON=…` arm in
   `pretooluse-skill-gate.sh`, anchored at `^` (each segment it tests
   already starts at a command position).
2. **Nudge** — add the verb or object to that skill's `check` alternation in
   `userpromptsubmit-skill-nudge.sh`, or add one `check` for a new skill.
3. **Test** — add a fire and a silent case to `tests/run.sh`.

The nudge tolerates over-triggering (cost = one extra system reminder);
the gate does not (cost = a blocked tool call).

#### Tests

`bash hooks/tests/run.sh` feeds fixture events to both hooks and asserts
each outcome — nudge fire / silent, gate block / allow — against temporary
transcripts. It needs only bash and jq, prints one `PASS` / `FAIL` line per
case, and exits non-zero when any case fails.

### Comment check (`posttooluse-comment-check.sh`)

Fires after every `Edit` / `Write`. Two stages, and the first one is what
keeps it quiet: extract the comment lines the edit **added** (for `Edit`,
`new_string` minus `old_string`), and exit 0 when there are none. A
code-only edit never reaches the second stage.

Stage two judges that comment text against
`agentic-development:no-bullshit-comments`:

| Check | Fires on |
|-------|----------|
| Unresolvable reference | `AC-<n>`, "acceptance criteria", "in this PR", "on this branch", `~/.claude/{specs,plans}`, dated spec/plan paths |
| Self-defending phrasing | "belt-and-braces", "requirement, not", "not thoroughness" |
| Spelled count | determiner + `two`…`ten` — a count that goes stale silently where a symbol would not |
| Section number as content | `§<n>` in a comment carrying no standing sentence of its own |
| Narration | comment words mostly echo the identifiers of the code line below, and no rationale word ("because", "otherwise", "must", …) appears |

Contiguous comment lines are judged as one comment, so a rationale on the
third line answers the first. Prose files (`.md`, `.txt`) are skipped
entirely — a Markdown document is all comment. Language markers come from
the file extension; an unknown extension exits 0.

The scope is the comment text and nothing else. Adjacent code is read as
the reference the comment is measured against and is never judged; the
remedy the agent is handed is always "rewrite or delete the comment".
Comments already in the file are out of scope.

`$COMMENT_CHECK_DISABLE` (any non-empty value) turns it off.

### Exit codes

- `0` — pass; event proceeds.
- `2` — block; stderr message is surfaced to the agent.

### Graceful degradation

Hooks no-op (exit 0) when:

- `jq` is unavailable on the host.
- `transcript_path` is missing from the event or the file does not exist.
- The extracted last assistant message is empty (`Stop` hooks).
- (`pretooluse-skill-gate`) the command runs no gated command.
- (`userpromptsubmit-skill-nudge`) the prompt is a harness message, makes
  no matching request, or the matched skill was already invoked within the
  recency window.
- (`posttooluse-comment-check`) the edit added no lines, the file extension
  has no known comment syntax, the added lines carry no comment, every
  comment among them passes, or `$COMMENT_CHECK_DISABLE` is set.
