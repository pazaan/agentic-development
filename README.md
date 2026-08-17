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
- **reviewing-code** — front door for code review dispatch; composes `superpowers:requesting-code-review` with `superpowers:receiving-code-review` so no reviewer-subagent finding leaves the workflow without verification against the cited file:line.
- **stacked-prs** — detects which stack tool owns the repo (git-spice, GitHub Stacks, or plain PRs) and routes raw-git operations (`rebase`, `push --force`, `commit --amend`, `merge main`) to that tool's equivalent so stack tracking doesn't silently break.
- **team-handoff** — Lead's binding load and spawn/message/plan-storage primitives.
- **ticket-as-contract** — Plan-note template enforcing AC traceability; Reviewer adjudication routing.
- **pre-commit-grep** — Coder's existing-pattern reuse + third-party-claim verification checks.
- **pr-body-protocol** — PR description shape + per-stack-tool composition command + commit-body KEEP/DROP rules.
- **tester-browser-sweep** — Tester's functional matrix + axe a11y + console/network capture via the Claude Code Chrome extension (`claude-in-chrome` MCP).

### Hooks (auto-wired on install via `plugin.json`)

- `task-completed-checklist.sh` (`Stop`) — checks last assistant message against `$PROJECT_PRECOMMIT_CHECKLIST`.
- `task-completed-caveman-bleed.sh` (`Stop`) — flags caveman-mode bleed in artifacts.

### Agents

Canonical role bodies under `agents/`: lead, coder, reviewer, tester,
backend-tester (persistent); adr-steward, ci-triager, db-migration-reviewer,
explorer, memory-consolidator, pm-reviewer, retro-writer, security-reviewer,
skill-drift-check, upgrader (ephemeral).

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
`TeamCreate` belonged to an earlier runtime and are no longer used. If a
session is refusing to spawn over a missing teams flag, it is running a
pre-2.4.0 copy of this plugin.

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
