---
name: pre-commit-grep
description: Use when Coder is preparing a commit. Runs the two grep-driven pre-commit checks — existing-pattern reuse and third-party-claim verification — that catch the most common kinds of bug-by-omission.
---

# Pre-commit grep

Two passes. Both block the commit when they fire; both produce a one-line
report cited in the commit body.

## Pass 1 — Existing-pattern reuse

For each new function / helper / utility in the diff:

1. Pick the most specific name token (e.g. `formatDuration`, `validateUuid`).
2. `git grep -nE "(function|const|export).*<name-token>" -- ':!*test*'` across the repo.
3. If a similar helper exists:
   - **Reuse** it; cite the path:line in the commit body.
   - **OR** justify why the new one is needed (different semantics, different
     side-effects); cite the existing one and explain.

Single-consumer thin wrappers around an existing helper add indirection
cost without proportional value. Extract on third repetition, inline
before that.

## Pass 2 — Third-party-claim verification

For every comment / docstring / commit-body sentence that names a value
from a third party (library hex value, framework class name, version
string, default constant):

1. `git grep -nE '<claimed-value>' node_modules/<library>/` or fetch
   upstream source.
2. Confirm the value is what the comment says it is.
3. If wrong: fix the claim before commit; do not ship false statements
   "at zero runtime cost".

## Output

Append to the commit body, under a `Grep checks:` heading, e.g.:

```
Grep checks:
- reuse: formatDuration reused from web/src/lib/format/duration.ts:14
- third-party: Pico `--pico-color-primary` confirmed against
  node_modules/@picocss/pico/css/pico.css:227 (`#1095c1`)
```

## Refuse-to-commit triggers

- Existing helper found that the new code duplicates without
  justification.
- Third-party claim fails grep verification.

Coder reports the failure to Lead via the normal completion channel; Lead
decides whether to rework or override.
