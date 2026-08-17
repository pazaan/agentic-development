# Project Bindings

Canonical agents in `agents/*.md` are project-agnostic. Every project-shaped
value (CI command, DB stack, principles doc, etc.) is resolved at runtime
against a per-project config file via handles.

## Config file

Location: `<project-root>/agentic-development.config.yml` (or `.json`).
Loaded by `agentic-development:team-handoff` skill into
env vars. Schema validation against `bindings.schema.json`.

If the file is absent, defaults take over (see table). Canonical agents
must tolerate every binding being unset.

## Handles

| Handle                          | Semantics                                                       | Default if absent                                |
|---------------------------------|-----------------------------------------------------------------|--------------------------------------------------|
| `TICKET_SOURCE`                 | Ticket store: `linear` / `gh-projects` / `gh-issues` / `manual` | `manual` (Lead reads AC pasted in chat)          |
| `TICKET_SOURCE_PROJECT`         | Project / board identifier within the ticket store              | (none)                                           |
| `PROJECT_CI_CMD`                | CI invocation Coder / Upgrader runs                             | (Coder skips; runs tests directly)               |
| `PROJECT_DB_START_CMD`          | Local DB stack start                                            | (Backend-Tester aborts)                          |
| `PROJECT_DB_MIGRATIONS_DIR`     | Path to DB migration files                                      | (db-migration-reviewer skipped)                  |
| `PROJECT_DB_STACK`              | DB stack identifier                                             | `none`                                           |
| `PROJECT_ADR_DIR`               | ADR directory                                                   | (adr-steward refuses)                            |
| `PROJECT_PRINCIPLES_FILE`       | Engineering-principles doc                                      | (Reviewer skips principles pass)                 |
| `PROJECT_RULES_FILE`            | Hard-rules / contributing doc                                   | (Coder skips rules-check)                        |
| `PROJECT_TECH_DESIGN_FILE`      | Technical-design doc                                            | (Lead skips tech-design re-read)                 |
| `PROJECT_FRAMEWORK_MCPS`        | Comma-list of MCP server globs Coder should reference           | (none)                                           |
| `PROJECT_PRECOMMIT_CHECKLIST`   | Path to YAML listing pre-commit items                           | (`task-completed-checklist.sh` no-op)            |
| `PROJECT_PUSH_ALLOWED`          | Whether Lead may push / open PRs at all                         | `false` (Lead refuses to push)                   |
| `PROJECT_PR_PUSH_CMD`           | Optional override for the push command; not an authorization    | (Lead derives the command from stack detection)  |
| `PROJECT_AGENT_STATE_BRANCH`    | Branch name for agent coordination state                        | (Lead omits agent-state refs from PR bodies)     |

### Push authorization vs push command

These are two different questions and used to be one key:

- **May we push?** `PROJECT_PUSH_ALLOWED`. A boolean. Nothing else grants it.
- **What command pushes?** Derived at runtime from Step 0 of
  `agentic-development:stacked-prs`, which reads `refs/spice/data` and
  `.git/gh-stack` to identify the tool the repo actually uses. Set
  `PROJECT_PR_PUSH_CMD` only to override that with a non-canonical wrapper.

Conflating them made a stale command double as an authorization flag: the
key had to stay populated to keep pushing enabled, so it kept naming a tool
long after the repo had moved to a different one, and nothing forced a
correction because its only real job was being non-empty.

**Legacy configs**: if `PROJECT_PUSH_ALLOWED` is absent but
`PROJECT_PR_PUSH_CMD` is set, treat pushing as allowed and warn the user
once that the config should be migrated. Do not silently refuse — that
would break every project written against the older schema.

## Where each handle is consumed

- **Lead** — `TICKET_SOURCE`, `PROJECT_PUSH_ALLOWED`, `PROJECT_PR_PUSH_CMD` (override only), `PROJECT_TECH_DESIGN_FILE`, `PROJECT_AGENT_STATE_BRANCH`, plan-banner schema.
- **Coder** — `PROJECT_CI_CMD`, `PROJECT_RULES_FILE`, `PROJECT_FRAMEWORK_MCPS` (informational).
- **Reviewer** — `PROJECT_PRINCIPLES_FILE`, `PROJECT_RULES_FILE`, `PROJECT_TECH_DESIGN_FILE`.
- **Tester** — `PROJECT_FRAMEWORK_MCPS`.
- **Backend-Tester** — `PROJECT_DB_START_CMD`, `PROJECT_DB_STACK`.
- **db-migration-reviewer** — `PROJECT_DB_MIGRATIONS_DIR`, `PROJECT_DB_STACK`.
- **adr-steward** — `PROJECT_ADR_DIR`.
- **Hooks** — `PROJECT_PRECOMMIT_CHECKLIST`, caveman-bleed thresholds.

## Example config (generic placeholder values)

```yaml
TICKET_SOURCE: linear              # or: gh-projects, gh-issues, manual
TICKET_SOURCE_PROJECT: <board-id>
PROJECT_CI_CMD: <ci-command>
PROJECT_DB_START_CMD: <db-start-command>
PROJECT_DB_STACK: <stack-name>     # or: none
PROJECT_DB_MIGRATIONS_DIR: <migrations-path>
PROJECT_ADR_DIR: <adr-directory>
PROJECT_PRINCIPLES_FILE: <principles-doc-path>
PROJECT_RULES_FILE: <rules-doc-path>
PROJECT_TECH_DESIGN_FILE: <tech-design-doc-path>
PROJECT_FRAMEWORK_MCPS: "<comma-list-of-MCP-globs>"
PROJECT_PRECOMMIT_CHECKLIST: <yaml-path>
PROJECT_PUSH_ALLOWED: true                    # or: false / unset, to forbid pushing
# PROJECT_PR_PUSH_CMD: <wrapper-command>      # override only; normally leave unset
PROJECT_AGENT_STATE_BRANCH: <branch-name>     # or: (unset, if no team agent workflow)
```

A concrete project overlay ships its own config file at the path noted
above.
