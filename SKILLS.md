# Skills Catalog

Every skill the canonical role set references, mapped to its trigger, the
role-section it replaces, and whether drift is **upstream-controlled** (skill
lives in another plugin we don't own) or **user-controlled** (skill lives in
this plugin).

| Skill                                          | Trigger                                    | Replaces role-section                       | Drift            | Pinned SHA  |
|------------------------------------------------|--------------------------------------------|---------------------------------------------|------------------|-------------|
| `agentic-development:caveman-micro`            | terse-response request                     | Lead caveman mode block                     | user-controlled  | (this repo) |
| `agentic-development:reviewing-code`           | review request                             | Reviewer five-pass body                     | user-controlled  | (this repo) |
| `agentic-development:stacked-prs`              | raw git rebase / push --force / amend / merge; any stack operation | Coder git-spice safety block   | user-controlled  | (this repo) |
| `agentic-development:tester-browser-sweep`     | Tester loop                                | Tester axe/console/functional inline body   | user-controlled  | (this repo) |
| `agentic-development:pre-commit-grep`          | Coder pre-commit                           | Coder existing-pattern + third-party verify | user-controlled  | (this repo) |
| `agentic-development:ticket-as-contract`       | Lead plan or Reviewer adjudication         | Lead Ticket Criteria Mapping + Build Order  | user-controlled  | (this repo) |
| `agentic-development:team-handoff`             | Lead first-action / spawn / message peers / plan storage | Lead spawn + binding load + plan storage | user-controlled  | (this repo) |
| `agentic-development:pr-body-protocol`         | first push / PR-body curation / commit body audit | Lead PR body + Coder commit body            | user-controlled  | (this repo) |
| `superpowers:brainstorming`                    | new feature / design exploration           | Lead brainstorming block                    | upstream         | TODO pin    |
| `superpowers:writing-plans`                    | plan needed                                | Lead plan-structure block                   | upstream         | TODO pin    |
| `superpowers:receiving-code-review`            | reviewer / tester findings inbound         | Lead adjudication block                     | upstream         | TODO pin    |
| `superpowers:test-driven-development`          | Coder writes implementation                | Coder TDD block                             | upstream         | TODO pin    |
| `superpowers:verification-before-completion`   | Coder claims done                          | Coder verification block                    | upstream         | TODO pin    |
| `simplify`                                     | Coder finishes change                      | Coder reuse / simplify block                | upstream         | TODO pin    |

## Drift policy

- **user-controlled** drift: edit in this repo, version-bump plugin.
- **upstream-controlled** drift: `skill-drift-check` fetches upstream
  SHA on a schedule, reports the diff, user decides when to re-pin.

## Plugin dependencies

Skills marked `upstream` ship from other plugins. Declared in
`.claude-plugin/plugin.json` `dependencies`. Only plugins this one
actually consumes belong there — terse-response mode is served in-repo by
`caveman-micro`, so the `caveman` plugin is not a dependency, and the
`task-completed-caveman-bleed.sh` hook detects bleed without it. Subagent `skills:` and
`mcpServers:` frontmatter is ignored for spawned teammates — skills must
be installed at user or project level. MCP servers go in the user's
`settings.json`. Spawned roles also lack the `Skill` tool, so they
practise a skill's content rather than invoking it; briefs should ask for
"applied + evidence", not "invoke skill X".

## TODO

- Replace `TODO pin` placeholders in the skills table with concrete
  upstream SHAs once `skill-drift-check` baselines them.
