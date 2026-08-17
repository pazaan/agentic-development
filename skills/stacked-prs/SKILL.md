---
name: stacked-prs
description: Use before any git operation that rewrites history or changes branch parentage (`git rebase`, `git push --force`, `git commit --amend`, `git merge main`), and whenever the work involves stacked pull requests. Triggers on "stack", "restack", "stacked PR", "git-spice", "gh stack", `gs`. Resolves which stack tool the repo actually uses — git-spice, GitHub Stacks, or neither — and routes to that tool's equivalent commands.
---

# Stacked PRs

## Overview

A stack is a chain of dependent branches, each PR based on the one below
it. Two tools manage stacks here and they are **not interchangeable**:

| Tool | CLI | Local state |
|---|---|---|
| [git-spice](https://abhinav.github.io/git-spice/) | `git-spice` | `refs/spice/data` git ref |
| [GitHub Stacks](https://docs.github.com/en/pull-requests/get-started/about-stacked-prs) | `gh stack` (extension) | `.git/gh-stack` JSON file |

A repo may also use neither — plain, independent PRs against trunk.

**Core rule:** detect first, then act. Running the wrong tool's commands,
or raw git history-rewriting commands, silently corrupts stack metadata
so downstack branches diverge from their tracked parent.

**Announce at start:** "Using the stacked-prs skill — detecting the stack
environment first."

## Step 0: Detect the environment

Run this before applying any rule below. It is two file/ref checks — no
network, no subprocess into either tool:

```bash
gitdir=$(git rev-parse --git-common-dir 2>/dev/null) || { echo "NOT-A-REPO"; exit 1; }
spice=no; ghstack=no
git rev-parse --verify --quiet refs/spice/data >/dev/null 2>&1 && spice=yes
[ -f "$gitdir/gh-stack" ] && ghstack=yes
echo "git-spice=$spice gh-stack=$ghstack"
```

| Result | Verdict | Go to |
|---|---|---|
| `git-spice=yes gh-stack=no` | git-spice repo | [git-spice](#git-spice) |
| `git-spice=no gh-stack=yes` | GitHub Stacks repo | [GitHub Stacks](#github-stacks-gh-stack) |
| `git-spice=no gh-stack=no` | plain PRs | [Plain PRs](#plain-prs) |
| `git-spice=yes gh-stack=yes` | **both — stop** | [Both detected](#both-detected) |

Never assume from memory which tool a repo uses — re-run the probe every
time. Users evaluate multiple stack tools side by side, and a repo's
answer can change between sessions.

### Which branches are in the stack

Knowing the tool isn't the same as knowing the current branch is stacked.
A git-spice repo can hold untracked branches; a `gh stack` repo can hold
branches outside any stack.

- git-spice: `git-spice log short` — the current branch appears in the
  listing if it's tracked.
- GitHub Stacks: `gh stack view` — **exit code 2 means "not in a stack"**,
  which is a normal answer, not an error to retry.

If the current branch isn't in a stack, treat the work as a plain PR even
in a stack-managed repo.

### Neither tool initialized, but the user wants a stack

Check what's installed before proposing anything:

```bash
command -v git-spice
gh extension list | grep -q gh-stack && echo "gh stack installed"
```

Then **ask the user which tool to use**. Never run `git-spice repo init`
or `gh stack init` unilaterally — picking a repo's stack tool is a
workflow decision, not a fix-up. Install commands, if the chosen one is
missing:

```bash
brew install git-spice                      # or: go install, official installer
gh extension install github/gh-stack        # requires gh v2.0+
```

### Both detected

`refs/spice/data` and `.git/gh-stack` both present means the repo was
driven by both tools at some point. Do not run either tool's restack /
sync / submit until this is resolved — each will rewrite branches
according to its own idea of the parentage.

Report both to the user with the current branch shape
(`git log --graph --oneline --all -20`) and ask which tool owns this
repo. Leftover metadata is removed with `git-spice repo init --reset`
(git-spice) or `gh stack unstack --local` (GitHub Stacks) — only after
the user picks.

## Cross-tool hazards

- **`gs` is ambiguous.** The user aliases `gs` to `git-spice`
  (`~/.bashrc`), and `gh stack alias` creates a `gs` alias for
  `gh stack` by default. `gs push` could mean either tool. Never type
  `gs` in a command you run or recommend — always the full
  `git-spice <sub>` or `gh stack <sub>` — and when the user types `gs`,
  resolve it via Step 0 rather than assuming.
- **Never mix tools in one repo.** git-spice's restack and `gh stack
  rebase` both rewrite the same branches from different metadata.
- **Raw git breaks both.** `git rebase`, `git commit --amend` +
  `git push --force`, `git merge main`, `git checkout -b` from a stacked
  branch, and `git branch -D` on a tracked branch all corrupt tracking
  regardless of which tool is in play. Use the tool's equivalent.

---

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

| Raw git (DO NOT) | Why it breaks the stack | Use instead |
|---|---|---|
| `git rebase <base>` / `git rebase -i` | Spice doesn't see the new commits → downstack branches still point at the old parent. | `git-spice upstack restack` (rebase current + everything above) or `git-spice stack restack` (whole stack) |
| `git commit --amend` then `git push --force` | Amended SHA isn't propagated to children → downstack rebases against the old commit. | `git-spice commit amend` — amends and auto-restacks upstack branches |
| `git push --force` / `--force-with-lease` on a stack branch | Bypasses the PR-update logic; can desync the PR description's stack navigation comment. | `git-spice branch submit` (just this branch) or `git-spice stack submit` (whole stack) |
| `git merge main` (or trunk) into a stack branch | Pollutes branch with merge commits; spice expects linear rebases. | `git-spice repo sync` then `git-spice stack restack` |
| `git checkout -b foo` from a tracked branch, then commit | Spice has no record of `foo`'s parent → submit will fail or pick the wrong base. | `git-spice branch create foo` (creates and tracks parentage) |
| `git branch -D foo` on a tracked branch | Leaves a dangling tracking entry in `refs/spice/data`. | `git-spice branch delete foo` (or `git-spice branch untrack foo` then `git branch -D`) |

### git-spice vs git — decision table for common intents

| You want to… | Command | Built-in abbrev |
|---|---|---|
| Make a normal commit on the current branch | `git commit` (spice tracks automatically) | — |
| Start a new branch on top of the current one | `git-spice branch create <name>` | `git-spice bc <name>` |
| Amend the last commit (and re-rebase everything above) | `git-spice commit amend` | `git-spice ca` |
| Restack everything above current branch | `git-spice upstack restack` | `git-spice us r` |
| Restack the entire stack from its base | `git-spice stack restack` | `git-spice s r` |
| Move current branch onto a different parent | `git-spice upstack onto <new-parent>` | `git-spice us o <new-parent>` |
| Sync trunk, prune merged branches, restack survivors | `git-spice repo sync` | `git-spice rs` |
| Submit / update a single branch's PR | `git-spice branch submit` | `git-spice bs` |
| Submit / update every branch in the stack as PRs | `git-spice stack submit` | `git-spice ss` |
| List branches in current stack | `git-spice log short` | `git-spice ls` |
| Interactive branch picker | `git-spice branch checkout` | `git-spice bco` |
| Move up / down within the stack | `git-spice up` / `git-spice down` | — |
| Track a branch that was created outside spice | `git-spice branch track` | `git-spice b tr` |
| Untrack a branch (stop spice from managing it) | `git-spice branch untrack` | `git-spice b untr` |
| Initialize spice in a repo (one-time, ask user first) | `git-spice repo init --trunk=<trunk>` | `git-spice r i` |

Note: trunk (main/master) is **not** auto-detected — `git-spice repo init`
needs an explicit `--trunk=` flag.

The "built-in abbrev" column is git-spice's own short form (built into
the CLI, not a user alias). Prefer the long form in commit messages and
explanations so the user can read what you ran later.

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
| Stacked PR merged into its parent branch instead of trunk | See "Recipe: PR merged to wrong base" below. |
| Truly stuck or hitting an unfamiliar subcommand | WebFetch <https://abhinav.github.io/git-spice/llms-full.txt> and look up the exact command. The TOC at <https://abhinav.github.io/git-spice/llms.txt> is just headings — fetch the full version for actual command syntax. |

## GitHub Stacks (`gh stack`)

GitHub's native stacked PRs, driven by the `github/gh-stack` CLI
extension (public preview). Stack metadata lives in `.git/gh-stack` (a
JSON file, not committed); interrupted-rebase state lives in
`.git/gh-stack-rebase-state`. On submit, GitHub links the PRs into a
**Stack** object server-side and sets each PR's base to the branch below
it.

```bash
gh extension install github/gh-stack   # CLI, gh v2.0+
gh skill install github/gh-stack       # the upstream agent skill — install this for depth
```

The upstream skill and
[README](https://github.com/github/gh-stack) are the authority on flags
and edge cases. What follows is only what you need to route correctly.

### Intent → command

| You want to… | Command |
|---|---|
| Start a stack in this repo | `gh stack init` (ask the user first) |
| Add a branch on top of the stack | `gh stack add <name>` (must be on the top branch) |
| Commit + create the next layer in one step | `gh stack add -m "<msg>"` (`-A` stage all, `-u` tracked only) |
| See the current stack | `gh stack view` (exit 2 = not in a stack) |
| Rebase the whole stack after trunk moved | `gh stack rebase` (`--downstack` / `--upstack` to scope) |
| Continue / abort a conflicted rebase | `gh stack rebase --continue` / `--abort` |
| Fetch + rebase + push + sync PR state in one go | `gh stack sync` (`--prune` to delete merged local branches) |
| Push branches without touching PRs | `gh stack push` (per-branch `--force-with-lease`, non-atomic) |
| Create / update the PRs and the GitHub Stack | `gh stack submit` (`--auto` for non-interactive) |
| Restructure the stack (drop / reorder / squash / rename) | `gh stack modify` |
| Link PRs you manage with another tool into a Stack | `gh stack link <branch-or-pr>…` (writes no local state) |
| Merge the stack (or up to a given PR) | `gh stack merge [<stack-number>\|<pr-number>]` |
| Check out a stack by number, PR, URL, or branch | `gh stack checkout [<id>]` |
| Navigate | `gh stack up` / `down` / `top` / `bottom` / `trunk` / `switch` |
| Remove stack tracking | `gh stack unstack` (`--local` to leave GitHub alone) |

### Things that bite

- **Exit code 2 is "not in a stack", not a failure.** Other codes:
  1 generic, 3 rebase conflict, 4 API failure, 5 bad args,
  6 disambiguation required, 7 rebase already in progress, 8 stack
  locked by another process.
- **`sync` vs `submit`.** `sync` never opens PRs — it only rebases,
  pushes, and links PRs that already exist. Use `submit` to create them.
- **`sync` on a diverged stack.** In a non-interactive shell (i.e. any
  harness Bash call) a divergence aborts the sync with exit **success**
  and pushes nothing. Check `gh stack view` after, don't assume it
  worked.
- **Don't set a `gs` alias.** `gh stack alias` defaults to `gs`, which
  collides with the user's `git-spice` alias.
- **Raw git still breaks it.** `gh stack` tracks branch ordering
  locally and PR bases remotely; a manual `git rebase` or amend +
  force-push desyncs both. Use `gh stack rebase` / `gh stack push`.

## Plain PRs

Neither tool initialized, and the branch isn't in a stack: this skill
does not apply. Use normal git and `gh pr create`. Don't initialize a
stack tool to make a single-branch PR fit a stack workflow, and don't
report stack-shaped state ("restacked", "submitted the stack") for work
that is one branch.

## Recipe: PR merged to wrong base

**Symptom:** a stacked PR landed on its parent branch (e.g. the PR1 head
branch) instead of the intended trunk (`main`), because the GitHub base
was not retargeted before merge. Net result: the merged PR's content is
not on trunk.

**Do not revert.** Revert PRs on dead branches are busywork — the parent
branch is post-merge dead, so reverting there changes nothing on trunk.
Also, GitHub will not let you retarget the base of a closed PR, so
reusing the original PR is not an option.

Written for git-spice; under `gh stack` the equivalent steps are
`gh stack sync` (1), `gh stack rebase` (3) and `gh stack push` /
`gh stack submit` (5).

1. `git-spice repo sync` — detects the merged PRs and prunes dead tracking entries.
2. `git switch <affected-branch>` — the branch whose PR landed on the wrong base.
3. `git-spice upstack onto <correct-base>` — replays the affected commits onto the right base, dropping any commits already folded into the squash-merge of the parent PR. If git-spice complains about parent tracking, fall back to `git-spice branch track --base <correct-base>` then `git-spice branch restack`.
4. **Verify the commit set.** `git log --oneline <correct-base>..HEAD` must show only the affected PR's own commits — no commits belonging to the already-merged parent PR. If parent commits are still present, the rebase did not drop them; investigate before pushing.
5. **Decide on push target.**
    - If the affected remote branch can be safely overwritten (no merged PR attached, no policy against force-push), `git-spice branch submit` will push and re-render.
    - If the affected remote branch already has a merged PR attached, or the user's policy is to keep merged-PR branches on origin indefinitely as an evidence trail, **do not** force-push. Instead, push to a fresh branch (e.g. `<original-name>-rebase`) and open a new PR against the correct base. The original remote branch stays on origin untouched.
6. **Tree-equivalence check before requesting review.** The new PR's tree must be byte-identical to the merged tip of the original PR, otherwise the rebase changed semantics:

    ```bash
    git diff --stat origin/<fresh-branch>..<original-merge-commit-sha>
    # must be empty
    ```

7. **New PR body.** Note that it is a recovery re-open after
   merge-to-wrong-base, and link the original PR for reviewer context.
   Re-use the original PR body wholesale to preserve the audit trail.

## Red Flags

**Never:**
- Act on a stack before running Step 0. "This repo uses git-spice" from
  memory is a guess; the ref check is one command.
- Run `git rebase`, `git commit --amend` + `git push --force`, or
  `git merge main` on a tracked branch — these silently break the stack
  under either tool.
- Run `git-spice repo init` or `gh stack init` without explicit user
  consent — it's a project-level decision, not a fix-up.
- Use `gs` in a command you run or recommend — it resolves to a different
  tool depending on whose alias is loaded.
- Assume the command syntax you remember is correct. If you're not
  certain, fetch the tool's docs before running it.
- Trust a `PROJECT_PR_PUSH_CMD` override without verifying the command
  exists. User wrappers (e.g. `gss`) live in interactive shell config and
  won't resolve in a non-interactive harness.
- Treat a configured push command as evidence of which stack tool the repo
  uses. It is a stale cache of a decision Step 0 re-derives correctly every
  time.

**Always:**
- Prefer the canonical long form (`git-spice branch submit`,
  `gh stack submit`) in commit messages and explanations so the user can
  read what you ran later.
- After any restack, confirm the stack shape before pushing —
  `git-spice log short` or `gh stack view`.
- After `git-spice commit amend`, **verify the tree actually changed**
  before claiming success — Coder agents have been observed amending
  with nothing staged (SHA rebake, identical tree):

    ```bash
    pre_tree=$(git rev-parse HEAD^{tree})    # capture BEFORE amend
    # ... edit + git add <files> + git-spice commit amend ...
    post_tree=$(git rev-parse HEAD^{tree})   # AFTER
    [ "$pre_tree" != "$post_tree" ] || echo "AMEND WAS A NO-OP — did you git add?"
    git show HEAD --stat -- <expected-files>  # must show the lines you edited
    ```

    A passing local build or test does NOT prove the change is in the
    commit — most tools read the working tree, not the index. Tree-hash
    verification is the only reliable post-amend check.
