---
name: no-bullshit-comments
description: Use when writing or editing a code comment or docstring, and when judging one in a diff under review. Symptoms include a comment that narrates the lines below it, cites an acceptance-criterion number or a plan or spec path, says "in this PR" or "on this branch", argues with an imagined critic about its own necessity, or hardcodes a count of things that can grow.
---

# No-bullshit comments

## Overview

A comment earns its place only by saying what the code cannot: rationale,
hazard, non-obvious constraint, a decision plus its reason, or a
measurement the reader cannot re-derive. Code already documents what
happens; a comment restating it is duplication that goes stale at the
next edit.

Scope: comments you write or touch. This is not a mandate to sweep
comments already in the repo.

## What a comment may carry

| Kind | Example |
|------|---------|
| Rationale | why this approach and not the obvious alternative |
| Hazard | what breaks if the next reader "simplifies" this |
| Non-obvious constraint | an external rule the code obeys but cannot show |
| Decision plus reason | the option taken, and what ruled the others out |
| Measurement | a benchmark or observed limit, with where the number came from |

Anything else — a paraphrase of the statement below, a heading for a block
that is already three readable lines — delete.

## State the fact once

Do not argue with an imagined critic. Phrasings like "not
belt-and-braces" or "a requirement, not thoroughness" are the comment
defending its own length: they add words about whether the comment should
exist instead of words the reader needs. One statement of the fact carries
it; if a second sentence is needed to justify the first, the first was not
worth writing.

## Every reference must resolve from the code alone

Never commit a reference the reader cannot follow from where they are
standing:

- No acceptance-criterion numbers.
- No plan or spec paths that live outside the repo.
- No "in this PR", "on this branch", "as discussed" — all meaningless
  once merged.

Reasoning that belongs to the task, not to the code, goes in the PR body.

### A design-doc section number is a pointer, never the content

The comment must state a fact that stands on its own; the section number
only says where to read more.

**Test: delete the number.** Does the comment still inform the reader? If
not, the comment was broken before you deleted anything.

Fails the test:

```rust
// none of the six §4.4 requires apply here
```

The reader has to leave the code to learn what the six are, and "requires"
means nothing as a noun.

Passes:

```rust
// carries a single `private` set, not the full preset list
```

Append `(§4.4)` only if the pointer adds something the sentence does not.

## Name the symbol, not a count

Counts in comments go stale silently. The next person adds a seventh
preset, ten comments still say "six", nothing fails and nothing warns.

Fails:

```rust
// six presets, keep this in sync
```

Passes:

```rust
// keep in sync with PRESET_KEY_* in preset_sets.rs
```

A symbol cannot drift from the implementation. A doc-section number and a
hardcoded count both can.

## Red flags

- The comment restates the line under it in prose.
- The comment explains why it is not excessive.
- A number, path, or identifier in the comment cannot be resolved from
  inside the repo.
- A section number is doing the informing instead of pointing.
- A count stands where a symbol name would.

All of these mean: rewrite the comment to a single fact the code cannot
state, or delete it.
