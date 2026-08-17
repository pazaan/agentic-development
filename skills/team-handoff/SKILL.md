---
name: team-handoff
description: Use when Lead boots a session, spawns teammates, or messages peers. Loads project bindings and provides the parametrised primitives for spawn / message / plan-storage. Every role goes through the `Agent` tool — persistent roles with a `name`, ephemeral specialists without one.
---

# Team handoff

Lead's binding load, spawn primitives, and plan-storage primitive live
here so agent bodies stay generic.

## Runtime

Teammates are spawned with the **`Agent` tool**, and each one has its own
context window and its own transcript. There is no team to create first
and no team handle to pass: current Claude Code exposes **no `TeamCreate`
tool**, and the `Agent` tool's `team_name` parameter is documented as
"Deprecated; ignored. The session has a single implicit team." Passing it
is harmless but does nothing.

Earlier builds gated a separate Teams runtime behind
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and required a `TeamCreate` call
before any persistent spawn. That flow is gone. If you find yourself
looking for `TeamCreate`, or reading advice that `team_name` is required,
it is stale — spawn through `Agent` and address teammates by name.

What decides a teammate's shape is whether you pass **`name`**:

| Spawn | Result | How its work comes back |
|---|---|---|
| `Agent` **with** `name` | Mailbox agent, addressable for follow-ups | Only via `SendMessage` to `"main"` — **the brief must ask for it** |
| `Agent` **without** `name` | Background agent, single-shot | Automatically, as a task-notification carrying its final report |

Both run in the background by default. Neither returns its result as the
tool's return value.

## Binding load

The skill sources `<project-root>/agentic-development.config.yml` and
exports every value as an env var:

```bash
load_bindings() {
  local cfg="${1:-agentic-development.config.yml}" line key val
  [ -f "$cfg" ] || return 0
  while IFS= read -r line; do
    line="${line%%[[:space:]]#*}"                  # drop trailing comment
    [[ "$line" =~ ^([A-Z_]+):[[:space:]]*(.*)$ ]] || continue
    key="${BASH_REMATCH[1]}"; val="${BASH_REMATCH[2]}"
    val="${val%"${val##*[![:space:]]}"}"           # rtrim only
    val="${val%\"}"; val="${val#\"}"
    [ -n "$val" ] && export "$key=$val"
  done < "$cfg"
}
load_bindings
```

Trim trailing whitespace; never strip interior spaces. An earlier version of
this sketch ran `val="${val// /}"`, which deleted every space in the value —
so `deno task ci` loaded as `denotaskci` and any multi-word command binding
was silently unrunnable.

(Real implementation should parse YAML properly; the above is sketch.)

Validation: schema-check `$cfg` against `bindings.schema.json`. Unknown
keys → emit warning + skip. Missing required keys → fall back to defaults
per `BINDINGS.md`.

**Resolving the push command.** `PROJECT_PUSH_ALLOWED` decides whether
Lead may push. It does not name a command, and no command names it.

The command itself comes from Step 0 of `agentic-development:stacked-prs`,
which reads `refs/spice/data` and `.git/gh-stack` to identify the tool the
repo actually uses. Detection beats configuration here: the repo's own
state cannot go stale, whereas a command written into the config keeps
naming last year's tool.

`PROJECT_PR_PUSH_CMD` is an optional override for repos needing a
non-canonical wrapper. When it is set, verify it exists before relying on
it — a wrapper like `gss` may be a shell function or alias visible only in
interactive shells:

```bash
command -v "$PROJECT_PR_PUSH_CMD" \
  || bash -ilc "command -v $PROJECT_PR_PUSH_CMD"
```

If neither resolves, fall back to the detected tool's canonical command and
tell the user their override is unreachable from a harness shell.

## Spawn primitives

### Persistent teammates (Coder, Reviewer, Backend-Tester, Tester)

No initialisation step. Spawn each persistent teammate directly, passing
`name` so it stays addressable:

```
Agent({
  description: "<5-word task summary>",
  subagent_type: "agentic-development:<role>",   // e.g. agentic-development:coder
  prompt: "<full brief — plan note path, scope, hard rules>",
  name: "<label for SendMessage>"                 // REQUIRED for persistent roles
})
```

Three things bite here, all of them silent:

**The name you asked for is not necessarily the name you got.** Spawning
with `name: "coder"` can return `coder-2` when the label is already taken
in the session. `SendMessage` to the requested name then fails or reaches
the wrong agent. **Read the actual name out of the spawn result and use
that** for every subsequent message. If you spawned several teammates in
one turn, re-check each result — the suffixes are assigned per spawn, so
some may shift and others not.

**A mailbox agent's report reaches Lead only if the brief asks for it.**
Nothing is delivered automatically. Every persistent brief must end with
an explicit instruction — "SendMessage to `main` with X when done; do not
go idle without sending it" — and should name the fields Lead needs. Left
out, the teammate finishes its turn and Lead sees only a contentless idle
notification, then waits for a report that will never arrive.

**Idle notifications are not reports.** They arrive after every turn and
carry at most a summary line. Treat them as "this agent stopped", nothing
more. When one arrives and you expected substance, verify the underlying
state yourself (`git status`, `git diff --cached`, the failing job's log)
rather than pinging for a status update — teammate replies routinely
cross Lead's messages, and a filesystem check is both cheaper and more
truthful than a self-report.

`subagent_type` values for persistent roles in this plugin:

- `agentic-development:coder` — Implementer (TDD, commits locally, no push without Lead authorization)
- `agentic-development:reviewer` — Five-pass diff reviewer (no edits, no commits, no `gh pr review`)
- `agentic-development:backend-tester` — DB stack + RPC/RLS testing
- `agentic-development:tester` — Frontend / a11y / browser sweep (Chrome extension required)

The teammate stays addressable via `SendMessage` for the rest of the
session. Teammates go idle after each turn — that's normal.

**Deferred MCP tools.** Roles that need `mcp__claude-in-chrome__*`,
`mcp__playwright__*` or `mcp__chrome-devtools__*` reach them through
`ToolSearch`. Tester is the canary: if it reports that it cannot load the
chrome tools, say so to the user rather than substituting a screenshot-free
"PASS" — an a11y sweep that never opened a browser is not a sweep.

### Ephemeral specialists

Same `Agent` tool, **without `name`**. Single-shot, no follow-up. Their
final report arrives on its own as a task-notification, so no
"SendMessage to main" instruction is needed in the brief. The dispatch
criteria live in `agents/lead.md` — match the finding/trigger, dispatch,
integrate result.

Available ephemerals:

- `agentic-development:security-reviewer`
- `agentic-development:db-migration-reviewer`
- `agentic-development:ci-triager`
- `agentic-development:pm-reviewer`
- `agentic-development:explorer`
- `agentic-development:upgrader`
- `agentic-development:adr-steward`
- `agentic-development:retro-writer`

## Messaging primitives

To resume a teammate previously spawned with `Agent`, use the
`SendMessage` tool:

```
SendMessage({
  to: "<name from the spawn result>" or "<agentId>",
  summary: "<5-10 word preview>",
  message: "<one-line follow-up or structured continuation>"
})
```

The message resumes the teammate in the background with full transcript
context — you don't need to re-state earlier scope. You'll be notified
when the teammate completes.

`to` must be the name the spawn **returned**, not the one you requested
(see the suffix trap above). The same applies to names you put inside a
brief: telling Backend-Tester to "ping Coder when the stack is up" fails
if Coder actually booted as `coder-2`. Spawn first, then relay the real
names.

Keep messages one-line; longer content lives in the plan artifact (see
below).

## Plan storage primitive

Plan content (ticket-criteria mapping, Build Order, divergence notes) is
written once per ticket, to a file the teammates can read directly:

```bash
plan_create() {
  local title="$1" body="$2"
  # Defaults to ~/.claude/plans/<kebab-title>.md unless overridden by
  # user, or ~/.claude/specs/<project>/<title>.md for longer-lived plan
  # notes.
  local slug="${title// /-}"
  slug="$(echo "$slug" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')"
  local path="${HOME}/.claude/plans/${slug}.md"
  printf '%s\n' "$body" > "$path"
  echo "$path"
}
```

The returned path is what Lead references when relaying context to
teammates.

## Ticket-source binding

The companion `ticket-source` resolver (called by Lead and pm-reviewer):

- `linear`     → `mcp__linear__get_issue`
- `gh-projects`→ `gh project item-view <id> --format json`
- `gh-issues`  → `gh issue view <id> --json title,body`
- `manual`     → return the AC text the user pasted into chat

## Refuse triggers

- `$PROJECT_PUSH_ALLOWED` absent or false and Lead is about to push →
  refuse; require explicit configuration. Legacy exception: if
  `$PROJECT_PUSH_ALLOWED` is absent but `$PROJECT_PR_PUSH_CMD` is set,
  treat pushing as allowed and warn once that the config predates the
  split. `$PROJECT_PR_PUSH_CMD` alone never authorizes anything in a
  config that also sets `$PROJECT_PUSH_ALLOWED`.
- `Agent` tool unavailable in the current harness → halt boot. Don't fall
  back to a `claude agent-team add` shell-out; that surface isn't the
  canonical invocation path. `Agent` is the only supported spawn
  primitive in this plugin.
- **Not** a refuse trigger: a missing `TeamCreate` tool, or
  `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` being unset. Neither is used any
  more, and an earlier version of this skill told Lead to halt boot on
  exactly that condition — which would strand a session that is in fact
  fully able to spawn. Spawn through `Agent` and continue.
