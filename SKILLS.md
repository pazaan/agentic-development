# Skills Catalog

Every skill this plugin ships or composes, mapped to its trigger and
whether drift is **upstream-controlled** (skill lives in another plugin we
don't own) or **user-controlled** (skill lives in this plugin).

| Skill                                          | Trigger                                                            | Drift            | Pinned SHA  |
|------------------------------------------------|--------------------------------------------------------------------|------------------|-------------|
| `agentic-development:reviewing-code`           | review request                                                     | user-controlled  | (this repo) |
| `agentic-development:review-rehearsal`         | explicit request to rehearse a review before posting               | user-controlled  | (this repo) |
| `agentic-development:stacked-prs`              | raw git rebase / push --force / amend / merge; any stack operation | user-controlled  | (this repo) |
| `agentic-development:no-bullshit-comments`     | comment written, edited or reviewed                                | user-controlled  | (this repo) |
| `agentic-development:pr-body-protocol`         | PR body or commit body written or edited                           | user-controlled  | (this repo) |
| `gangsta:audit-review`                         | reviewer dispatch inside reviewing-code                            | upstream         | TODO pin    |
| `gangsta:receiving-orders`                     | findings verification inside reviewing-code                        | upstream         | TODO pin    |

## Drift policy

- **user-controlled** drift: edit in this repo, version-bump plugin.
- **upstream-controlled** drift: compare the upstream skill against the
  pinned SHA by hand, then decide whether to re-pin.

## Plugin dependencies

Skills marked `upstream` ship from other plugins, declared in
`.claude-plugin/plugin.json` `dependencies`. Only plugins this one
actually consumes belong there; the `task-completed-caveman-bleed.sh` hook
detects bleed without the `caveman` plugin, so it is not a dependency.
