# agentic-development

Personal Claude Code plugin. Distributes my skills/commands/agents/hooks across machines.

## Canonical entrypoint

```text
/start-agentic-task <description-or-ticket-id>
```

Activates Lead behavior: loads project
bindings (`agentic-development.config.yml`), fetches the ticket if the
argument matches `$TICKET_SOURCE`'s ID pattern, then **self-routes** to
either a direct plan note or `iterative-development:iterative-development`
based on scope rules (subsystem count, AC bullet count, word count,
explicit phase/milestone framing, `--iterative` flag). Borderline cases
ask you once instead of guessing.

Lead presents the plan; nothing spawns until you approve.

## Contents

### Commands

- **`/start-agentic-task <task>`** — canonical entry, see above.
- **`/retro`** — spawn `retro-writer` for a 3-line retrospective on the most recently merged ticket.
- **`/consolidate-memory`** — scan project memory directory for duplicate / stale entries.

### Skills

- **caveman-micro** — lightweight token-efficient response mode; drops filler/articles/pleasantries while keeping technical substance exact.
- **reviewing-code** — front door for code review dispatch; composes `superpowers:requesting-code-review` with `superpowers:receiving-code-review` so no finding leaves the workflow without its premise, consequence and remedy verified against the cited file:line. Baselines load on demand from `references/baselines.md`.
- **review-rehearsal** — request-only dry run of a *written review* before it is posted: a junior-persona agent applies the review on a throwaway branch, a senior-persona agent reviews the result, and the output is a corrected review. Costs two subagents and a worktree.
- **stacked-prs** — detects which stack tool owns the repo (git-spice, GitHub Stacks, or plain PRs) and routes raw-git operations (`rebase`, `push --force`, `commit --amend`, `merge main`) to that tool's equivalent so stack tracking doesn't silently break.
- **team-handoff** — Lead's binding load and spawn/message/plan-storage primitives.
- **ticket-as-contract** — Plan-note template enforcing AC traceability; Reviewer adjudication routing.
- **pre-commit-grep** — Coder's existing-pattern reuse + third-party-claim verification checks.
- **no-bullshit-comments** — a comment earns its place only by saying what the code cannot; kills line-narration, self-defending phrasing, references a reader cannot resolve from the repo, and counts that go stale where a symbol name belongs.
- **pr-body-protocol** — PR description shape + per-stack-tool composition command + commit-body KEEP/DROP rules.
- **tester-browser-sweep** — Tester's functional matrix + axe a11y + console/network capture via the Claude Code Chrome extension (`claude-in-chrome` MCP).

`SKILLS.md` maps every skill the role set references — including the
upstream ones from `superpowers` — to its trigger and drift owner.

### Hooks (auto-wired on install via `plugin.json`)

Skill-recall pair — two-stage forcing function for skills the agent is
observed to skip once they decay out of attention:

- `userpromptsubmit-skill-nudge.sh` (`UserPromptSubmit`) — soft nudge. Injects a `<system-reminder>` naming the skill when the prompt looks skill-shaped and that skill hasn't been invoked in the last `$SKILL_NUDGE_RECENCY` transcript entries (default 50).
- `pretooluse-skill-gate.sh` (`PreToolUse`, matcher `Bash`) — hard gate. Exits `2` on PR-write / review-write commands when the required skill was never invoked this session. Exempts `--help`, `-h`, `--dry-run`.
- `posttooluse-comment-check.sh` (`PostToolUse`, matcher `Edit|Write`) — judges the comment lines an edit *added* against `no-bullshit-comments`; exits `0` without a word when the edit added none, so code-only edits are untouched. Off via `$COMMENT_CHECK_DISABLE`.

Stop hooks:

- `task-completed-checklist.sh` (`Stop`) — checks last assistant message against `$PROJECT_PRECOMMIT_CHECKLIST`.
- `task-completed-caveman-bleed.sh` (`Stop`) — flags caveman-mode bleed in artifacts, over `$CAVEMAN_BLEED_THRESHOLD` (default 40).

All five no-op (exit 0) when `jq` is missing, `transcript_path` is absent,
or the relevant env var / file is unset. See `hooks/README.md` for the
full gate/nudge trigger table and how to add a rule.

### Agents

Canonical role bodies under `agents/`:

- **Persistent** (spawned with a `name`, addressable via `SendMessage`): lead, coder, reviewer, tester, backend-tester.
- **Ephemeral** (spawned without a `name`, report via task-notification): adr-steward, ci-triager, db-migration-reviewer, explorer, pm-reviewer, security-reviewer, upgrader.
- **Scheduled / command-triggered**: memory-consolidator (`/consolidate-memory`), retro-writer (`/retro`), skill-drift-check (cron — see `docs/schedule-drift-check.md`).

`ROLES.md` holds the spawn convention and the cross-role interaction rules.

## Install

In any Claude Code session:

```text
/plugin marketplace add pazaan/agentic-development
/plugin install agentic-development
```

Then `/plugin list` to confirm it's enabled.

### Spawning

Lead spawns every role with the `Agent` tool. No setup, no env flag, and
no team-creation call — `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` and
`TeamCreate` belonged to an earlier runtime and are no longer used. A
session refusing to spawn over a missing teams flag is following stale
instructions, not this plugin.

### Chrome extension (Tester)

For UI work, the Tester subagent drives the browser via the
[Claude Code Chrome extension](https://code.claude.com/docs/en/chrome).
Launch Lead with `claude --chrome`, or run `/chrome` mid-session to
enable.

## Project configuration

Each project consuming this plugin must ship
`<project-root>/agentic-development.config.yml`. See `BINDINGS.md` for
the schema and per-handle defaults. The handoff skill validates against
`bindings.schema.json` and exports each handle as an env var.

## Update

After pushing changes here:

```text
/plugin marketplace update
/plugin update agentic-development
```
