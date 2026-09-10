# Hooks

These hooks are declared in `.claude-plugin/plugin.json` and auto-wired by
`/plugin install`. No manual `~/.claude/settings.json` edit needed.

Each hook reads its event JSON from stdin, resolves `transcript_path`,
and runs its check against the JSONL transcript.

## Kept hooks

| Hook                                | Event               | Reads                                | Notes                                  |
|-------------------------------------|---------------------|--------------------------------------|----------------------------------------|
| `userpromptsubmit-skill-nudge.sh`   | `UserPromptSubmit`  | `prompt`, `transcript_path`          | Soft nudge — injects skill names when the user's prompt looks skill-shaped and the skill is stale. |
| `pretooluse-skill-gate.sh`          | `PreToolUse`        | `tool_name`, `tool_input.command`    | Hard gate — blocks PR-write / review-write commands until the required skill has been invoked. |
| `posttooluse-comment-check.sh`      | `PostToolUse`       | `tool_input.{file_path,old_string,new_string,content}` | Judges the comment lines an edit added; silent on code-only edits. |
| `task-completed-checklist.sh`       | `Stop`              | `$PROJECT_PRECOMMIT_CHECKLIST`       | No-op when env unset or file missing.  |
| `task-completed-caveman-bleed.sh`   | `Stop`              | `$CAVEMAN_BLEED_THRESHOLD` (def. 40) | Heuristic; tune per project.           |

### Skill-recall pair (`userpromptsubmit-skill-nudge` + `pretooluse-skill-gate`)

Two-stage forcing function for skills the agent has been observed to skip
even when the instruction was explicit. Failure mode: project-specific
skills (PR-body shape, code-review pass, stacked-PR ops) get loaded at
session start, decay out of attention over long sessions, and the agent
falls back on training priors that don't match project convention.

**Nudge** (early, soft):
Fires on every `UserPromptSubmit`. Pattern-matches the prompt against
trigger phrases and checks whether the matching skill has been invoked in
the last `$SKILL_NUDGE_RECENCY` transcript entries (default 50). If
absent, writes a `<system-reminder>` block to stdout — Claude Code
appends UserPromptSubmit stdout to the user's prompt as additional
context. No block, no extra turn.

**Gate** (late, hard):
Fires on `PreToolUse` for `Bash`. If the command matches a gated pattern
and the required skill has not been invoked anywhere in the session,
exits `2` with a stderr message instructing what to invoke.

Current gates / nudges:

| Trigger surface                                                                                  | Required skill                            |
|--------------------------------------------------------------------------------------------------|-------------------------------------------|
| `gh pr create` / `gh pr edit`                                                                    | `agentic-development:pr-body-protocol`    |
| `gh api -X PATCH .../pulls/<N>`                                                                  | `agentic-development:pr-body-protocol`    |
| `git-spice {branch,stack} submit`, `git spice ...`, `gs {ss,bs,branch submit,stack submit}`      | `agentic-development:pr-body-protocol`    |
| `gh stack submit` / `gs submit`                                                                  | `agentic-development:pr-body-protocol`    |
| Prompt mentions push/submit/create + PR/stack/branch                                             | `agentic-development:pr-body-protocol`    |
| `gh pr review` / `gh api .../pulls/<N>/reviews`                                                  | `agentic-development:reviewing-code`      |
| Prompt mentions review/audit + PR/diff/code                                                      | `agentic-development:reviewing-code`      |
| Prompt mentions restack / git-spice / `gh stack` / `gs ss`                                       | `agentic-development:stacked-prs`         |
| Prompt mentions acceptance criteria / `AC-<n>`                                                   | `agentic-development:ticket-as-contract`  |

The gate exempts help and dry-run invocations: a command carrying
`--help`, `-h`, or `--dry-run` (and no `--title` / `--body`) is inspecting
a tool, not authoring a PR, so it passes through. Without that exemption
`git-spice branch submit --help` blocks — observed live.

To add a rule:

1. **Gate** — append an `elif … REQUIRED_SKILL=… GATE_REASON=…` arm in
   `pretooluse-skill-gate.sh`. Keep matches anchored on `\b` so unrelated
   commands (`gh issue edit`, `gh api .../issues/N`) pass through.
2. **Nudge** — append a `check '<regex>' '<skill>' '<label>'` call in
   `userpromptsubmit-skill-nudge.sh`.

The nudge tolerates over-triggering (cost = one extra system reminder);
the gate does not (cost = a blocked tool call), so nudge patterns can be
looser than gate patterns.

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

When nothing is flagged but comments were added, the hook surfaces the
rules once per `$COMMENT_CHECK_RECENCY` transcript entries (default 100),
so the reminder lands while comments are being written rather than at
branch end.

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
- The configured env var or referenced checklist file is missing.
- (`pretooluse-skill-gate`) the command doesn't match any gated pattern.
- (`userpromptsubmit-skill-nudge`) the prompt doesn't match any trigger
  OR the matched skill was already invoked within the recency window.
- (`posttooluse-comment-check`) the edit added no comment lines, the file
  extension has no known comment syntax, or `$COMMENT_CHECK_DISABLE` is set.

## Dropped hooks (was v0.3.1, removed v0.3.2)

| Hook                              | Reason                                                                 |
|-----------------------------------|------------------------------------------------------------------------|
| `task-completed-retro.sh`         | Superseded by `/retro` slash command (`agentic-development:retro`).    |
| `task-created-criteria-mapping.sh`| `TaskCreate` is not a Claude Code event; CC `Agent` tool payload lacks `criterion`/`link` fields the check expects. |
| `teammate-idle-summary.sh`        | `TeammateIdle` is Claude Agent Teams-only. No Claude Code equivalent.  |

See `~/.claude/specs/2026-05-18-hooks-respec-design.md` (out-of-tree) for the
full rationale, or the commit that landed this change.
