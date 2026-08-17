---
description: Start an agentic workflow on <task>. Activates Lead behavior, loads bindings, fetches ticket if argument is an ID, then routes to either a direct plan or iterative-development depending on scope.
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

### 4b. Big-spec → `iterative-development`

Route to `iterative-development:iterative-development` if **any** of:

- `--iterative` appears anywhere in `$ARGUMENTS` (explicit user override).
- `SPEC` mentions two or more distinct subsystems. Subsystem keywords:
  `frontend`, `UI`, `backend`, `API`, `database`, `DB`, `migration`,
  `schema`, `mobile`, `worker`, `cron`, `infrastructure`, `auth`,
  `billing`. Two or more from disjoint pairs count.
- `SPEC` describes multiple epics, milestones, phases, or releases.
- `SPEC`'s explicit AC list is missing or vague (no enumerable
  bullets, or bullets read as goals rather than verifiable criteria).
- `SPEC` length exceeds **800 words** OR contains **more than 10** AC
  bullets.

When routing here:
- Invoke the `iterative-development:iterative-development` skill.
- Pass `SPEC` as the spec input.
- That skill will run `extracting-requirements` → `scoping-the-simplest-core`
  → present a roadmap and first iteration.
- Stop and present the first iteration plan to the user before step 6.

### 4c. Borderline / contradictory signals → ASK

Before defaulting to a small-spec plan, sanity-check the signals.
If **any** of the below hold, do **not** auto-route. Stop and ask the
user via `AskUserQuestion` with two options: "Direct plan (small spec)"
vs "iterative-development (big/ambiguous spec)". Quote the ambiguity in
the question prompt so the user has the same view of it.

- Exactly one subsystem keyword matched, but `SPEC` is between 500 and
  800 words.
- AC list is present but mixes verifiable criteria with goal-shaped
  statements (e.g., "users can …" alongside "system is fast").
- Phase / milestone language present but only one subsystem.
- `SPEC` describes a single subsystem with 8-10 ACs (right at the
  boundary).

Wait for the answer. Then continue at the chosen route.

### 4d. Small spec → direct plan

Otherwise (single subsystem, ≤ 8 concrete ACs, ≤ 500 words, no
phase/milestone framing):

- Invoke `agentic-development:ticket-as-contract`.
- Draft a plan note containing `## Ticket Criteria Mapping` (every AC
  verbatim, paired with the plan section that addresses it) and
  `## Build Order` (the concrete spawn-and-gate sequence).
- Front-matter must include: `ticket`, `class`
  (`ui` | `backend` | `docs` | `mechanical` | `spike`), `mode`
  (`default` | `local-stack`), `push-cmd`.

## 5. Present the plan

Whichever route ran in step 4 (4b or 4c), present its output to the user
verbatim and wait for explicit approval. Do not spawn any persistent
teammate before that approval lands.

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
