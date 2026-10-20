---
name: reviewing-code
description: Use when asked to review a PR, branch, diff or completed work, before dispatching a reviewer subagent or invoking gangsta:audit-review directly.
---

# Reviewing Code

Composes `gangsta:audit-review` (dispatch to `gangsta:the-inspector`) with
`gangsta:receiving-orders` (verification). The inspector is an external
reviewer: its output is suggestions to evaluate, not orders to relay.

**Core principle:** no finding leaves unverified — premise read at the cited
file:line, consequence executed wherever it can be, remedy read in place.
Verifying findings already works; the errors sit in what is added *after* the
finding — the prescribed fix, the test setup, the companion list, the pasted
string. Look there.

## Workflow

1. **Dispatch.** Follow `gangsta:audit-review` verbatim: get the SHAs, fill
   `the-inspector-prompt.md`, dispatch `the-inspector`. Fill
   `{PLAN_OR_REQUIREMENTS}` with what the PR says it is for, and stop. Adding
   your suspicions commissions findings; they come back dressed as
   independent corroboration.

2. **Receive as external feedback.** Apply `gangsta:receiving-orders`' From
   External Sources checklist to every Critical/Important finding:
   - Open and read the cited file:line. That settles the premise, nothing else.
   - Settle the consequence: does the failure path manifest, or is it
     hypothetical? Where trigger and outcome are executable (parser, exception
     hierarchy, URL normaliser, paging), run them. Install the dependency if
     needed — a scratch venv costs a minute.
   - Run the whole chain `input → reaches the defect → wrong outcome`. The
     dull end (is the input reachable?) is the one that goes unchecked.
   - Look for an existing reason for the current code.
   - Read the PR title and body as the spec. A finding against what the PR is
     *for* argues with the deliverable. Where title, code and a doc comment or
     log line agree, the author decided; you need evidence, not a careless
     reading.
   - If two findings are real only as a compound, present only the compound.
   - Re-size severity by actual blast radius, not the reviewer's framing.

3. **Relay only what survives.** A concrete observation from the opened line
   (the quoted token, the actual value, the missing guard) is how *you*
   decide it is real; none means not relayed. It is not the comment's
   content: the author needs no git log, survey, or file:line beyond the
   anchor. Cite a second location only for a fact the diff cannot show.

4. **Volume floor: zero.** Zero survivors — say so. Twenty — surface twenty.
   Never pad, and never leave the filtering to the user. Dropping an
   unverified finding is not suppressing a bug.

5. **Verify each remedy.** Everything after the defect sentence is
   unverified until checked:
   - Read each suggestion block in place against the anchor lines it
     replaces — duplicated sibling literals, dropped guards, removed checks
     the types below need.
   - Trace any setup you prescribe; "add a test where X throws" is a
     reachability claim. Code that turns failures into values makes it
     impossible.
   - Enumerate companions by grepping the value and the claim's words, not
     the symbol: prose restatements, spelled-out numbers, test titles.
   - Size what the fix sets in motion. A nit forcing new types, a predicate
     and signature changes was a wrong finding. Drop it.
   - Ask what happens when the fix's own mechanism fails; name the case it
     closes and the one it does not.
   - Anchor on a path, never a basename.

6. **Verify the assembled review.** Properties of the set that survive step 5:
   - Two comments on one file are one patch; read them together.
   - What new inputs does each fix admit, and where do they land — including
     in another finding?
   - Enumerate every path through old and new, not just the defect path.

7. **Emit in the Output Contract shape.**

## Output Contract

The list of findings is the whole deliverable, first finding to last. Each
finding, in order:

1. `path:line` or `path:start-end`.
2. One line naming the defect — one only a reader of the code could write;
   the defect, not your trail. Companion locations for a non-contiguous fix
   go here. A design question gets the same shape, stating what makes it a
   question.
3. The fix. On a PR: a ` ```suggestion ` block with the exact replacement
   for the anchor lines (verify anchors — one bad anchor 422s the whole
   review). Otherwise one line of remediation. Out-of-hunk lines take no
   block (see Posting).

Recommend one fix; a choice is unfinished, and whoever applies it invents a
rationale for their pick. If your argument favours a branch, name it and check
it is buildable. Order most-severe first — the only severity signal; a
blocker earns position, not words.

### Writing a finding

A word ceiling alone makes it worse: six facts become six comma-chained
clauses. The rules:

- **Two sentences maximum**, any severity: defect, then trigger if needed.
  A ceiling, not a target.
- **First sentence names the symptom** — what breaks, for whom. Mechanism
  second.
- **One fact per sentence**; two only when the same fact from both ends.
- **References at the end**, on their own line, never mid-clause.
- **Nothing in front of the defect**: no epistemic preface, never the
  author's comment quoted back.
- **Compression is a new edit.** Shortening drops qualifiers and invents
  causal links. Re-read against the file after trimming.
- **The wall of text is the tell.** A finding that will not fit in two
  sentences is usually talking the reader into a premise the author rejected
  on purpose. Suspect the finding before trimming the prose.

Examples: `references/examples.md`.

## Posting to GitHub

- Submit one review (`POST /repos/{owner}/{repo}/pulls/{n}/reviews` with a
  `comments` array), not N comments.
- A comment lands only inside a diff hunk. Compute ranges first
  (`git diff -U3 BASE..HEAD -- <path> | grep '^@@'`). An out-of-hunk finding
  becomes a plain comment on the nearest in-hunk line naming the real lines.
  Long-lived modified files bite; new files never do.
- The body carries only what no inline comment can: manual steps no
  suggestion covers, a caveat no anchor owns. Otherwise empty. Comments that
  must land together say so themselves.
- GitHub renders no numbering; refer to a comment by file and symbol. Replace
  a submitted body with `PUT .../pulls/{n}/reviews/{review_id}`.

## Red Flags — stop and re-verify

- Citing a flag, method or line you have not read to the end.
- Asserting a failure path a scratch script could run, without running it.
- "The library isn't installed" — install it, then decide.
- Verifying hardest on findings you expect to reject; the relayed ones reach
  the author.
- Treating a read citation as verification of the consequence.
- Skipping verification because the PR is small or the last finding checked out.
- Illustrating a test gap with a mutation nobody would make.
- A concession in a finding ("low impact") with the finding kept anyway.
- Citing any file but the anchor.
- Calling a docstring a lie when it describes encapsulation.
- Two findings referencing each other — does A stand alone?
- "Could in principle" / "a future maintainer might".
- A suggestion block not read against the lines it replaces.
- A fix whose recovery path calls the thing that just failed.
- Asking for a test on an untraced path.
- A nit needing a new type, abstraction or signature change.
- Leaving the rest of the fix to the author; they implement what you wrote.
- Grepping only the symbol for companions.
- Shortening a comment without re-reading it against the file.
- A bare-filename anchor, or a line no hunk covers.
- Two comments on one file not read as one patch.
- "Either X or Y".
- A body describing your review instead of their code.
- A finding with no observation only reading the code could produce.
- Padding to look thorough.
- A first sentence that is mechanism, symptom never arriving.

## Evidence

`references/baselines.md` holds six real runs and the error each rule was
written to stop (Baselines 5 and 6 back steps 5 and 6). Read it when a rule
looks arbitrary or you are weighing a finding you cannot quite justify.
