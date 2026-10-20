# agentic-development

Personal Claude Code plugin. Distributes my skills, hooks and one agent across machines.

## Contents

### Skills

- **reviewing-code** — front door for code review dispatch; composes `gangsta:audit-review` with `gangsta:receiving-orders` so no finding leaves the workflow without its premise, consequence and remedy verified against the cited file:line. Evidence and worked examples load on demand from `references/`.
- **review-rehearsal** — request-only dry run of a *written review* before it is posted: a junior-persona agent applies the review on a throwaway branch, a senior-persona agent reviews the result, and the output is a corrected review. Costs two subagents and a worktree.
- **stacked-prs** — detects which stack tool owns the repo (git-spice, GitHub Stacks, or plain PRs) and routes raw-git operations (`rebase`, `push --force`, `commit --amend`, `merge main`) to that tool's equivalent so stack tracking doesn't silently break.
- **no-bullshit-comments** — a comment earns its place only by saying what the code cannot; kills line-narration, self-defending phrasing, references a reader cannot resolve from the repo, and counts that go stale where a symbol name belongs.
- **pr-body-protocol** — PR description shape + per-stack-tool composition command + commit-body KEEP/DROP rules.

`SKILLS.md` maps every skill — including the upstream ones from `gangsta` —
to its trigger and drift owner.

### Hooks (auto-wired on install via `plugin.json`)

Skill-recall pair — two-stage forcing function for skills the agent is
observed to skip once they decay out of attention:

- `userpromptsubmit-skill-nudge.sh` (`UserPromptSubmit`) — soft nudge. Injects a `<system-reminder>` naming the skill when the prompt is a skill-shaped request and that skill hasn't been invoked in the last `$SKILL_NUDGE_RECENCY` transcript entries (default 50).
- `pretooluse-skill-gate.sh` (`PreToolUse`, matcher `Bash`) — hard gate. Exits `2` on PR-write / review-write commands when the required skill was never invoked this session. Exempts `--help`, `-h`, `--dry-run`.
- `posttooluse-comment-check.sh` (`PostToolUse`, matcher `Edit|Write`) — judges the comment lines an edit *added* against `no-bullshit-comments`; exits `0` without a word unless it has a finding, so code-only and clean edits are untouched. Off via `$COMMENT_CHECK_DISABLE`.
- `task-completed-caveman-bleed.sh` (`Stop`) — flags caveman-mode bleed in artifacts, over `$CAVEMAN_BLEED_THRESHOLD` (default 40).

All four no-op (exit 0) when `jq` is missing; the three that read the
transcript also no-op when `transcript_path` is absent. See
`hooks/README.md` for the full gate/nudge trigger table and how to add a
rule.

## Install

In any Claude Code session:

```text
/plugin marketplace add pazaan/agentic-development
/plugin install agentic-development
```

Then `/plugin list` to confirm it's enabled.

## Update

After pushing changes here:

```text
/plugin marketplace update
/plugin update agentic-development
```
