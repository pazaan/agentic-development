# agentic-development

Personal Claude Code plugin. Distributes my skills and hooks across machines.

## Contents

### Skills

- **reviewing-code** — front door for code review dispatch; composes `gangsta:audit-review` with `gangsta:receiving-orders` so no finding leaves the workflow without its premise, consequence and remedy verified against the cited file:line. Evidence and worked examples load on demand from `references/`.
- **review-rehearsal** — request-only dry run of a *written review* before it is posted: a junior-persona agent applies the review on a throwaway branch, a senior-persona agent reviews the result, and the output is a corrected review. Costs two subagents and a worktree.
- **stacked-prs** — detects which stack tool owns the repo (git-spice, GitHub Stacks, or plain PRs) and routes raw-git operations (`rebase`, `push --force`, `commit --amend`, `merge main`) to that tool's equivalent so stack tracking doesn't silently break.
- **no-bullshit-comments** — a comment earns its place only by saying what the code cannot; kills line-narration, self-defending phrasing, references a reader cannot resolve from the repo, and counts that go stale where a symbol name belongs.
- **pr-body-protocol** — PR description shape + per-stack-tool composition command + commit-body KEEP/DROP rules.

`reviewing-code` depends on `gangsta:audit-review` and
`gangsta:receiving-orders` from the `gangsta` plugin.

### Hooks (auto-wired on install via `plugin.json`)

- `userpromptsubmit-skill-nudge.sh` (`UserPromptSubmit`) — soft nudge: names the skill when a user request needs one that has not been invoked recently.
- `pretooluse-skill-gate.sh` (`PreToolUse`, `Bash`) — hard gate: blocks PR-write and review-write commands until the required skill has been invoked.
- `posttooluse-comment-check.sh` (`PostToolUse`, `Edit|Write`) — judges the comment lines an edit added against `no-bullshit-comments`.
- `task-completed-caveman-bleed.sh` (`Stop`) — flags caveman-mode bleed in artifacts.

Triggers, tuning, no-op conditions and tests: `hooks/README.md`.

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
