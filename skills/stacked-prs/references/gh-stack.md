<!-- Loaded on demand by skills/stacked-prs/SKILL.md Step 0.
     Read this only when Step 0 resolves the repo to GitHub Stacks. -->

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
