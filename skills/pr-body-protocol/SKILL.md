---
name: pr-body-protocol
description: Use when authoring or curating a GitHub PR description, and when trimming commit bodies for an agent-driven workflow. Defines the 150-word PR body shape, names Coder as primary author + Lead as curator, and separates audit ceremony (drop) from decision context (keep) in commit messages.
---

# PR body protocol

PR description and commit body have different readers. They should not
share content.

| Artifact       | Reader                                    | Lifetime         | Optimised for                 |
|----------------|-------------------------------------------|------------------|-------------------------------|
| PR description | Human reviewer, skim                      | One review pass  | 30-second understanding       |
| Commit body    | Future agent at git blame / bisect        | Forever          | Decision context recovery     |

## PR description

**Primary author**: Coder, on first push of a branch.

**Body text** — the same in every environment:

    ## What changed
    - <bullet>
    - ...

    ## Test plan
    - [ ] <how a human reviewer verifies behaviour>

    ## Notes
    <only if material — out-of-scope items, follow-up tickets, gotchas>

    Linear: [TICKET-NN](https://linear.app/...) (PR<n> of stack)

**Composition** — the command depends on which stack tool owns the repo.
Resolve it with Step 0 of `agentic-development:stacked-prs` before
pushing; do not assume from memory.

| Environment | Command |
|---|---|
| git-spice | `git-spice branch submit --title "<commit subject>" --body "$(cat <<'EOF' … EOF)"` |
| GitHub Stacks | `gh stack submit --auto`, then `gh pr edit <num> --body "…"` per PR |
| Plain PR | `gh pr create --title "<commit subject>" --body "$(cat <<'EOF' … EOF)"` |

Passing `--title` and `--body` is what skips git-spice's interactive
metadata prompt (there is no `--no-fill` flag). Never use git-spice's
`--fill` / `-c`: it mechanically concatenates commit bodies into the PR
description, producing unscannable PRs.

`gh stack submit` without `--auto` opens a full-screen editor that a
harness shell cannot drive. `--auto` skips it but auto-generates the
titles and creates PRs as drafts unless you also pass `--open` — so with
GitHub Stacks the body is always a follow-up `gh pr edit`, one per PR in
the stack.

**Shape** (enforced regardless of author):

- `## What changed` (3-4 bullets) → `## Test plan` (2-3 lines) → `## Notes`
  (only if material).
- Cap ~150 visible words absolute.
- Spec → `$PROJECT_TECH_DESIGN_FILE`; agent state →
  `$PROJECT_AGENT_STATE_BRANCH` (never the PR diff). Binding unset ⇒ omit;
  don't substitute.
- No restating GitHub-UI / stack-tool / base-branch metadata. No ITER-####
  markers, plan-section refs, or tracker links.

**Subsequent pushes** to the same PR: leave body alone unless externally
observable shape changed. If it did, update via
`gh pr edit <num> --body "..."` with the same shape.

**Lead curation**: Lead may rewrite via `gh pr edit <num> --body "..."` when:

- Coder body fails the shape gate (used `--fill`, exceeded ~150 words,
  pasted commit-body ceremony) and Lead opts to fix directly rather than
  loop Coder.
- Coder has been dismissed and the body needs post-push correction.
- One-off retroactive cleanup on already-open PRs.

**Pre-push gate** (between Reviewer LGTM and push authorization): Lead
reviews PR body shape. If Coder skipped the protocol / used `--fill`,
instruct Coder to rewrite, OR (Coder unavailable / trivial fix) Lead
rewrites directly.

## Commit body

Write for the future agent at git blame / bisect — not for the Reviewer
(who reads diff + in-band claims) and not for the human PR reviewer (who
reads the PR description).

**KEEP**:

- Root cause / system trace (the WHY of the diff)
- Plan divergences (where Coder deviated from plan, with reason)
- Critical deletions (file + reason)
- Outcomes from pre-commit checks (grep results, refs verified) — the FACT,
  not the ceremony

**DROP** — relay to Lead via completion report / `SendMessage`, not into
commit:

- Tool-usage report ("svelte-autofixer ✓"). Tool-call logs in transcripts
  are authoritative; if a tool didn't run, Reviewer catches it in-band.
- Local QA matrix (lint/check/test counts). CI runs the same checks on the
  same SHA; CI status is authoritative.
- "Step ran" markers / checklist boilerplate. Outcomes carry signal;
  markers carry none.

**Target shape**: 10-25 lines, decision-density high.
**Linear ref last line**: `Linear: TICKET-NN (PR<n> of stack)`.
