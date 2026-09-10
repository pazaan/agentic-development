---
description: Start an agentic workflow on <task>. Activates Lead behavior, loads bindings, fetches ticket if argument is an ID, then drafts a plan note — or spawns an explorer when the spec is a spike.
---

Argument: `$ARGUMENTS`

You are now Lead per the `agentic-development` plugin (`agents/lead.md`).
Hard rules apply: no code edits, no source commits, ticket is contract,
never bypass signing/hooks.

Work through every step below in order. Do not skip a step. Do not spawn
any persistent teammate before step 6.

## 1. Bindings

Load `agentic-development:team-handoff`. Source
`agentic-development.config.yml` and export every binding from
`BINDINGS.md` as env vars (use the skill's `load_bindings` helper).

**Refuse trigger:** the `Agent` tool unavailable in this harness → surface
to the user before any persistent spawn. A missing `TeamCreate` tool, or an
unset `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`, is **not** a refuse trigger —
neither is used any more.

## 2. Resolve the argument

Inspect `$ARGUMENTS`. Pick exactly one resolver based on `$TICKET_SOURCE`:

| `$TICKET_SOURCE` | ID pattern               | Fetch                                                   |
|------------------|--------------------------|---------------------------------------------------------|
| `linear`         | `^[A-Z]+-\d+$`           | `mcp__linear__get_issue`                                |
| `gh-issues`      | `^#?\d+$` or `<o>/<r>#N` | `gh issue view <id> --json title,body`                  |
| `gh-projects`    | numeric item-id          | `gh project item-view <id> --format json`               |
| `manual` or any  | (no match)               | Treat `$ARGUMENTS` verbatim as the spec text            |

Save the resolved spec text as **`SPEC`** for the rest of this command.

**Refuse trigger:** ID pattern matches but the fetch fails → surface the
error verbatim; do not silently fall back to manual.

## 3. Read project context

If `$PROJECT_TECH_DESIGN_FILE` is set and the file exists → read it.
If `$PROJECT_ADR_DIR` is set → list ADRs; read any whose title or
first-line summary relates to `SPEC`.

## 4. Classify scope

Apply the rules below to `SPEC` **in order**. First match wins.

### 4a. Spike intent → spawn `explorer`

If `SPEC` contains any of: `spike`, `explore`, `investigate`,
`research`, `prototype` (as standalone words, case-insensitive),
**and** has no ACs:

→ Skip step 5. Spawn `explorer` subagent via the Agent tool with
   `subagent_type: explorer`, pass `SPEC` as prompt. Report findings.
   Done. Do not draft a plan; do not spawn persistent teammates.

### 4b. Anything else → direct plan

- Invoke `agentic-development:ticket-as-contract`.
- Draft a plan note containing `## Ticket Criteria Mapping` (every AC
  verbatim, paired with the plan section that addresses it) and
  `## Build Order` (the concrete spawn-and-gate sequence).
- Front-matter must include: `ticket`, `class`
  (`ui` | `backend` | `docs` | `mechanical` | `spike` | `upgrade`), `mode`
  (`default` | `local-stack`), `push-cmd`.
- `class` bounds which paths Coder may modify, via
  `$PROJECT_CLASS_FORBIDDEN_PATHS`. Choose it against the work the ACs
  actually require, not against the ticket's title. If delivering the ACs
  needs a migration or an edge function, the ticket is not `class: ui` —
  re-class it, or split it, before spawning anyone.

If `SPEC` is too large to hold as one contract — multiple epics,
milestones or releases, two or more disjoint subsystems, or an AC list
that is missing or reads as goals rather than verifiable criteria — stop
and ask the user via `AskUserQuestion` whether to split it into separate
tickets or to proceed on the whole thing as one plan. Quote the part that
triggered the question. Dispatch `pm-reviewer` in step 6 when the ACs
stay ambiguous.

## 5. Present the plan

Present the plan note to the user verbatim and wait for explicit
approval. Do not spawn any persistent teammate before that approval
lands.

## 6. Execute on approval

Once the user approves:

- Spawn persistent teammates via the spawn primitives in
  `agentic-development:team-handoff`.
  Default persistent set: Coder, Reviewer. Add Tester if `class: ui`,
  add Backend-Tester if `class: backend` and `$PROJECT_DB_START_CMD`
  is set.
- Dispatch ephemeral specialists per the conditional dispatch table
  in `agents/lead.md`:
  - auth/RLS/secrets diff → `security-reviewer`
  - `$PROJECT_DB_MIGRATIONS_DIR` diff → `db-migration-reviewer`
  - CI red → `ci-triager`
  - ambiguous AC → `pm-reviewer`
  - class=spike → `explorer`; class=upgrade → `upgrader`
  - ADR-worthy decision → `adr-steward`
- Follow the Build Order to its merge gate.

**Refuse trigger:** pushing not authorized AND plan front-matter is not
`mode: local-stack` → halt before spawn; require explicit binding or mode
override. Pushing is authorized when `$PROJECT_PUSH_ALLOWED` is true, or —
for configs predating the split — when `$PROJECT_PUSH_ALLOWED` is absent
and `$PROJECT_PR_PUSH_CMD` is set.
