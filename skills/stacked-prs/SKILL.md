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

| Result | Verdict | Then read |
|---|---|---|
| `git-spice=yes gh-stack=no` | git-spice repo | `references/git-spice.md` |
| `git-spice=no gh-stack=yes` | GitHub Stacks repo | `references/gh-stack.md` |
| `git-spice=no gh-stack=no` | plain PRs | [Plain PRs](#plain-prs) — no reference file needed |
| `git-spice=yes gh-stack=yes` | **both — stop** | [Both detected](#both-detected) |

The two reference files hold each tool's command tables, gotchas and
recovery steps. Read **only** the one Step 0 resolved to — they are
mutually exclusive, and the wrong tool's commands corrupt the stack.
Everything below in this file applies under either tool.

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
