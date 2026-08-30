<!-- Loaded on demand by skills/stacked-prs/SKILL.md Step 0.
     Read this only when Step 0 resolves the repo to git-spice. -->

## git-spice

git-spice stores stack metadata in the `refs/spice/data` git ref. The
most common failure mode is reaching for raw git on a stacked branch and
silently corrupting the stack so that downstack branches diverge from
their tracked parent.

**Binary name.** git-spice ships as a single binary called `git-spice`
(homebrew, `go install`, or the official installer). Many users alias or
symlink it to `gs` for brevity — that's user convention, not part of the
distribution, and it collides with `gh stack`'s own default alias. Always
invoke `git-spice <subcommand>` (or `git spice <subcommand>` — git
auto-resolves `git-foo` as a subcommand).

If `command -v git-spice` fails:

```bash
command -v git-spice \
  || ls -1 ~/.local/bin/git-spice ~/go/bin/git-spice \
            /opt/homebrew/bin/git-spice /usr/local/bin/git-spice 2>/dev/null | head -1
```

If it's off-PATH, invoke via full path for the rest of the session —
don't mutate PATH at the shell level.

**User-defined wrappers** (functions or aliases in `~/.bashrc` /
`~/.zshrc`, e.g. `gss = git-spice stack submit + cancellation cleanup`)
are **not visible to non-interactive harness shells**. If an override like
`PROJECT_PR_PUSH_CMD: gss` doesn't resolve via `command -v`, try
`bash -ilc 'command -v <name>'` to discover whether it's an alias. If
still nothing, fall back to the canonical `git-spice stack submit` and
tell the user their override is unreachable from a harness shell.

Note that `PROJECT_PR_PUSH_CMD` is an override, not the normal source of
the push command. Step 0 above is. A repo with no override is the expected
case, not a misconfiguration.

### Red Flags — raw git ops that break git-spice stacks

| Raw git (DO NOT) | Why it breaks the stack |
|---|---|
| `git rebase <base>` / `git rebase -i` | Spice doesn't see the new commits → downstack branches still point at the old parent. |
| `git commit --amend` then `git push --force` | Amended SHA isn't propagated to children → downstack rebases against the old commit. |
| `git push --force` / `--force-with-lease` on a stack branch | Bypasses the PR-update logic; can desync the PR description's stack navigation comment. |
| `git merge main` (or trunk) into a stack branch | Pollutes branch with merge commits; spice expects linear rebases. |
| `git checkout -b foo` from a tracked branch, then commit | Spice has no record of `foo`'s parent → submit will fail or pick the wrong base. |
| `git branch -D foo` on a tracked branch | Leaves a dangling tracking entry in `refs/spice/data`. |

### git-spice vs git — decision table for common intents

| You want to… | Command |
|---|---|
| Make a normal commit on the current branch | `git commit` (spice tracks automatically) |
| Start a new branch on top of the current one | `git-spice branch create <name>` |
| Amend the last commit (and re-rebase everything above) | `git-spice commit amend` |
| Restack everything above current branch | `git-spice upstack restack` |
| Restack the entire stack from its base | `git-spice stack restack` |
| Move current branch onto a different parent | `git-spice upstack onto <new-parent>` |
| Sync trunk, prune merged branches, restack survivors | `git-spice repo sync` |
| Submit / update a single branch's PR | `git-spice branch submit` |
| Submit / update every branch in the stack as PRs | `git-spice stack submit` |
| List branches in current stack | `git-spice log short` |
| Interactive branch picker | `git-spice branch checkout` |
| Move up / down within the stack | `git-spice up` / `git-spice down` |
| Track a branch that was created outside spice | `git-spice branch track` |
| Untrack a branch (stop spice from managing it) | `git-spice branch untrack` |
| Initialize spice in a repo (one-time, ask user first) | `git-spice repo init --trunk=<trunk>` |

Note: trunk (main/master) is **not** auto-detected — `git-spice repo init`
needs an explicit `--trunk=` flag.

### The flow for the most common situation

You've made changes on a stack branch and main has moved on. To bring the
branch up to date and update its PR:

```bash
git-spice repo sync           # fetch trunk, prune merged, restack survivors
git-spice stack restack       # only needed if sync didn't restack everything you care about
git-spice stack submit        # push & update every PR in the stack
```

If you only touched one branch in the stack and don't want to push the
others:

```bash
git-spice commit amend        # amends + auto-restacks upstack
git-spice branch submit       # pushes just this branch and updates its PR
```

### First-submit upstream gotcha

`git-spice stack submit` (and `git-spice branch submit`) push each branch
to a remote of the same name. If a branch's git upstream is set to a
**different** name — most commonly `main` because the branch was checked
out from `origin/main` and git auto-set tracking — `git-spice` will
print:

```
INF <branch>: Using upstream name '<other>'
INF <branch>: If this is incorrect, cancel this operation and run
    'git branch --unset-upstream <branch>'.
```

This is **not** just informational. If `<other>` is your trunk (`main`,
`master`), `git-spice` will try to push your local branch tip to
`refs/heads/<trunk>` on the remote — branch protection will reject it
(`GH006: Protected branch update failed`).

**Action when you see this:** cancel, run the suggested
`git branch --unset-upstream <branch>`, then re-run the submit. Once
submitted with no upstream, git-spice creates the remote branch under the
local name.

### Recovery

| Symptom | Fix |
|---|---|
| Stack looks tangled / branches diverge | `git-spice log short` to see current shape, then `git-spice upstack restack` (or `git-spice stack restack` from the base) |
| Branch shows as untracked after a manual `git checkout -b` | `git-spice branch track` to register it; spice will prompt for the parent |
| PR navigation comment is stale | `git-spice stack submit` re-renders the comment from current state |
| First-submit push rejected against `refs/heads/main` | Check `git rev-parse --abbrev-ref <branch>@{upstream}` — if it's `origin/<trunk>`, run `git branch --unset-upstream <branch>` and retry. |
| Stacked PR merged into its parent branch instead of trunk | See "Recipe: PR merged to wrong base" in `SKILL.md`. |
| Truly stuck or hitting an unfamiliar subcommand | WebFetch <https://abhinav.github.io/git-spice/llms-full.txt> and look up the exact command. The TOC at <https://abhinav.github.io/git-spice/llms.txt> is just headings — fetch the full version for actual command syntax. |
