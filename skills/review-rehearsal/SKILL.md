---
name: review-rehearsal
description: Use when explicitly asked to rehearse, dry-run, or pressure-test a code review before it is posted — a junior-persona agent applies the review to a throwaway branch, a senior-persona agent reviews the result, and the output is a corrected review. The artifact under test is the REVIEW, not the code. Request-only; it costs two subagents and a worktree.
---

# Review rehearsal

## Overview

A written review reads as finished long before it is applicable. Its
premises can all check out while its remedies contradict each other, close
a fork nobody chose, or patch a race and silently swallow a `not-found`.
Reading harder does not find those. Applying the review does.

**The artifact under test is the review.** The code is the instrument. The
diff is thrown away at the end; the deliverable is a corrected review plus
a list of what the original got wrong.

**Core principle:** a review you have not applied is a hypothesis about
what someone else will do with it.

## When to use it

On explicit request — "rehearse this", "dry-run the review", "see if a
junior could apply this". It spends two subagents, a worktree and a full
gate run, so it is never automatic and `reviewing-code` does not call it.

Worth requesting when the review carries suggestion blocks that touch
concurrency, shared types, or a file two comments both land on; when a
finding offers a choice; or when the review is large enough that you have
stopped holding all of it in mind at once. A three-finding review on one
file does not need it.

## Setup

Three mechanics, none of them the obvious choice.

**Branch off the head under review, never the trunk.** A feature PR's
files usually do not exist on the trunk at all, so a branch off `main` has
nothing to patch. Take the PR head SHA.

**Work in a temporary worktree, never a named or numbered checkout.**
Another session owns those, and it will switch branches under you.

```bash
git worktree add <scratch>/wt-<pr> -b throwaway/<pr>-review-apply <HEAD_SHA>
```

**Symlink dependencies from the real checkout.** This is the difference
between green gates in two minutes and a report that says "could not
verify" — which is what an unprepared reviewer subagent will honestly tell
you. First confirm the PR changes no lockfile:

```bash
git diff --name-only BASE..HEAD | grep -E 'package(-lock)?\.json|yarn\.lock|Cargo\.lock'
```

If that is empty, link each package's installed tree into the worktree.
Never install; the point is to borrow, not to provision.

## The junior brief

A fresh agent with no session context, holding only the review file and
the code. That isolation is the test: if the review needs your
conversation to be applicable, it is not applicable.

Give it the worktree path, forbid it from touching any other checkout, and
tell it not to install anything. Then ask for two things and say the
second matters as much as the first:

1. **Apply the review.** Every finding. A suggestion block is replacement
   text for its anchor lines; a finding without one gets its instruction
   implemented.

2. **Report where the review failed you.** Not "was anything unclear" —
   that returns nothing. Enumerate the classes:
   - A block that did not fit its anchor: wrong lines, text that did not
     match, indentation that broke the surroundings, an identifier not in
     scope.
   - An instruction you could not act on without inventing a decision the
     review should have made.
   - A comment you believe is simply wrong about the code. Give it
     explicit permission to refuse one, and to say so rather than comply.
   - A fix far larger than its comment implied — with the real size.
   - Something you could not find, or that was already as asked.

Two more instructions earn their place. **Do not bend a test to pass**: a
test failing because the review changed behaviour the review asked to
change is a finding, not an obstacle. And **do not soften the report** — a
review that reads well and cannot be applied is the failure being hunted.

## The senior brief

Point it at the applied diff — which is uncommitted if the junior's own
rules forbid moving refs, so `git diff <HEAD_SHA>` rather than a commit
range. Read-only, same isolation rules, same borrowed dependencies.

State that it judges the review as well as the diff. Without that it
reviews the junior and never notices the instructions were bad. Ask for
four things:

- Did each change do what its comment intended, and is it correct in
  place — not just in its hunk? Guards dropped, transactions that do not
  close the race they were added for, behaviour changed past what was
  asked.
- Did the junior invent anything the review did not authorise, and does
  that choice strand anything nobody named — a dead constant, prose left
  contradicting the code?
- Are the test changes honest, or was a test bent to pass?
- Separately: **what did the review itself get wrong**, written as
  instructions to the reviewer.

## Verify their claims yourself

Both agents are sometimes wrong, and a rehearsal that launders their
output is worse than none. `reviewing-code`'s discipline applies
unchanged: a claim from either agent is a claim.

The two most valuable results of a rehearsal are the ones you must
personally confirm — a finding declared false, and a defect declared
present in a block you wrote. Open the file. In Baseline 6 the withdrawal
of a finding held only because the registry write forty lines below the
cited one was read directly, and the regression in a suggestion block held
only because the pre-change throw was confirmed.

## Output, then clean up

The deliverable is the corrected review and a list of what the original
got wrong. Withdraw what was shown false, repair the remedies, merge
comments that cannot both land, and close any fork the junior had to close
for you.

Then remove the worktree and delete the branch. The applied changes go
with them, which is intended — they were the instrument.

```bash
git worktree remove --force <scratch>/wt-<pr>
git branch -D throwaway/<pr>-review-apply
git worktree prune
```

A reviewer subagent that made its own worktree leaves one too. Check
`git worktree list` before you call it clean.

## Red Flags

- Branching off the trunk. The files are not there.
- Borrowing a numbered or named checkout because it looked idle.
- Briefing the junior with your session context. The isolation is the
  test.
- A junior brief that says "apply this" and nothing about reporting back.
  You get compliance and learn nothing.
- A senior brief that does not say the review is also under review.
- Relaying "the reviewer says finding 4 is wrong" without opening the
  file.
- Editing a test so the applied review passes.
- Keeping the branch because the fixes look good. They are unreviewed
  work on a throwaway; the author applies the corrected review.

## Baseline

The 103-file Signify PR, twice. The first cycle produced eleven defects in
a sixteen-finding review and not one false finding. The second produced
four in fourteen, plus one finding withdrawn outright — its premise cited
a line that had a twin further down the same file.

Every defect in both cycles sat in what followed the defect sentence: the
prescribed fix, the test setup it named, the companion locations it
listed, the string it pasted. That is the shape of what a rehearsal finds,
and it is why the loop is worth its cost on a review whose remedies are
load-bearing — and not worth it on one whose findings are the whole
product.
