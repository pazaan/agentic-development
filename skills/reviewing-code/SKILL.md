---
name: reviewing-code
description: Use whenever a code review is requested on a PR, branch, diff, or completed work. Symptoms include being about to dispatch a reviewer subagent or about to invoke requesting-code-review directly. This is the front door for all review-dispatch tasks.
---

# Reviewing Code

## Overview

Composes `superpowers:requesting-code-review` (dispatch) with
`superpowers:receiving-code-review` (verification). The reviewer subagent
is an EXTERNAL reviewer; its output is suggestions to evaluate, not
orders to relay.

**Core principle:** no finding leaves this workflow unverified — its
premise read at the cited file:line, its consequence executed wherever it
can be, and its remedy read in place.

Verifying findings is the part that already works. Two full cycles of this
skill (Baseline 5) produced eleven defects and not one was a false finding:
every one sat in something added *after* the finding — the fix it
prescribed, the test setup it named, the companion locations it listed, the
string it pasted. Assume that is where your errors are.

## Workflow

1. **Dispatch the reviewer.** Follow `superpowers:requesting-code-review`'s
   instructions verbatim — get the git SHAs, fill the template at
   `code-reviewer.md`, dispatch a `general-purpose` subagent.

   Fill `{PLAN_OR_REQUIREMENTS}` with what the PR says it is for, and
   stop. Adding your own suspicions ("check whether this silently breaks
   X") commissions findings rather than requesting a review — the
   subagent will return what you asked for, dressed as its own
   conclusion, and it will read as independent corroboration when you
   come to verify it.

2. **Receive its output as external feedback.** Apply
   `superpowers:receiving-code-review`'s External-Reviewer checklist to
   every Critical/Important finding before relaying:
   - Open the cited file:line. Read it. That settles the premise — the
     reviewer quoted real code — and nothing else.
   - Then settle the consequence. Does the failure path actually manifest,
     or is it hypothetical ("under -O flag", "future maintainer might")?
     Where the trigger and the outcome are executable — a parser, an
     exception hierarchy, a URL normaliser, a paging calculation — run
     them instead of reasoning about them. When the dependency is
     installable, install it; a scratch venv costs a minute.
   - Run the whole chain, not just the half that interests you. A finding
     is `input → reaches the defect → wrong outcome`. Confirming the
     outcome is vivid and confirming the input is reachable is dull, so
     the dull end is the one that goes unchecked.
   - Is there an existing reason for the current code the reviewer missed?
   - Read the PR title and body as the spec before judging any finding
     that says the change is wrong. "Add an env var to disable X" states
     what the PR is *for*; a finding arguing X should still be on is
     arguing with the deliverable, not reviewing it. Where the title and
     the code agree, and a doc comment or log line agrees with both, the
     author decided — you need evidence they were wrong, not a reading in
     which they were careless.
   - Are two findings coupled? If only the compound is real, present only
     the compound, not both.
   - Re-evaluate severity based on actual blast radius, not reviewer's
     framing.

3. **Relay only what survives.** The concrete observation from the line
   you opened — the quoted token, the actual value, the guard that isn't
   there — is how *you* decide the finding is real. No observation = not
   verified = not relayed.

   It is not the comment's content. The author wrote this code: they do
   not need your git log, your survey of how other services do it, or any
   file:line but the anchor. Cite a second location only for a fact they
   cannot see from the diff — a value that lives in another repo, a
   behaviour you had to execute to establish.

4. **Volume floor: zero.** If verification leaves zero findings, say so.
   Don't pad. If 20 survive, surface 20. Coverage on real bugs, zero noise
   from imagined ones.

5. **Verify the remedy, not just the finding.** Everything after the defect
   sentence is unverified assertion until you check it, and it is where this
   skill's errors actually live. Before the review leaves:
   - **Read each suggestion block in place**, against the anchor lines it
     replaces. It is code. A block that duplicates a sibling literal, drops
     a guard the surrounding lines rely on, or removes a check the code
     below needs for its types will not be caught by reading the block on
     its own.
   - **Trace any setup you prescribe.** "Add a test for a part whose fetch
     throws" is a reachability claim and needs the same trace as a finding's
     own consequence. Twice in Baseline 5 the prescribed trigger could not
     occur: the code turned every such failure into a value and returned
     normally.
   - **Enumerate companions by grepping the value, not the symbol.** When a
     finding moves a documented number or falsifies a stated claim, grep the
     number and the claim's words. Grep finds `FOO_TTL_MS`; it does not find
     "authenticated clients may read it", a 60s spelled out in prose, or a
     test title describing the behaviour you just deleted. Six of Baseline
     5's eleven defects are this one mistake.
   - **Size what the fix sets in motion.** If a one-line nit forces new
     types, a predicate and threading them through four functions, the
     finding was wrong rather than underspecified. Drop it.
   - **Ask what happens when the fix's own mechanism fails.** "Write X
     instead" is not a fix when writing X fails the same way that got you
     here. Name the case it closes and the case it does not.
   - **Anchor on a path, not a basename.** In a repo with a mirrored test
     tree, `useThing.test.tsx` sends the reader to the wrong one.

6. **Verify the assembled review.** Step 5 verifies one remedy at a time.
   These three are properties of the whole set, and they survive a step 5
   you followed faithfully — Baseline 6 shipped all three:
   - **Two comments touching one file are one patch.** Read them against
     each other. Each can be right alone and contradict the other when
     both land — one deleting a thing the other's block re-asserts.
   - **What new inputs does each fix admit, and where do they land?**
     Including into another finding. A fix that moves a timeout past a body
     read admits an abort from the body read, which the error classifier
     buckets as the exact misclassification a sibling comment is about.
   - **Enumerate every path through old and new, not just the defect
     path.** "Does this block close the race" is a different question from
     "what else does this now do", and a block can pass the first while
     turning a `not-found` throw into a silent success.

7. **Emit it in the shape below.** Verification decides *what* is relayed;
   the output contract decides *how*.

## Output Contract

The relay is a list of findings. The list is the entire deliverable: it
starts at the first finding and ends at the last one.

Each finding is three parts, in this order:

1. `path:line`, or `path:start-end` for a range.
2. One line naming the defect. It should be a line only someone who read
   the code could write — but what it carries is the defect, not the
   trail you followed to confirm it.
3. The fix. When the review targets a PR, this is a GitHub ` ```suggestion `
   block holding the exact replacement text for those anchor lines —
   verify the anchors against the file first, since one bad anchor 422s an
   entire review. Otherwise, one line of remediation. Lines outside every
   diff hunk take no block; see **Posting to GitHub**.

A fix that offers a choice is not finished. Whoever applies the review
closes the fork, and then invents a rationale for the branch they picked.
Recommend one. If your own argument for the finding favours a branch, say
which, and check that branch is buildable before you name the other.

Order findings most-severe first. That ordering is the severity signal, and
the only one. A blocker does not earn more words than a nit — it earns the
top of the list.

A finding whose fix spans non-contiguous lines names the companion
locations inside part 2. A finding you could not reduce to a defect —
a design decision worth questioning — still gets the same three parts,
with part 2 stating what makes it a question.

### How a finding is written

Five rules. A ceiling on words is the weakest of them, and on its own it
makes things worse: told "one sentence", a finding holding six facts becomes
six clauses chained with commas and dashes — shorter than the long version
and harder to read.

**Two sentences, whatever the severity.** The defect, then its trigger if it
needs one. Nothing takes three. This is a ceiling, not a target: describing
something accurately in fewer words is always available, and a finding that
will not fit is telling you something (see the tell below).

**The first sentence names the symptom** — what breaks, and for whom.
Mechanism is the second sentence. A reader scanning twenty comments needs
the consequence in the first six words; a comment that opens with an
identifier makes them assemble it themselves.

**One fact per sentence.** Two only when they are the same fact from both
ends.

**References go at the end**, on their own line, never mid-clause. Each
inline `path.ts:41` is a context switch the eye must park and come back from.

**Nothing stands in front of the defect.** No epistemic preface ("a question
rather than a finding", "a missing affordance rather than a wrong rule"), and
never the author's own comment quoted back inside one of your clauses — that
reads as litigation, not information.

Before:

> The phase decision uses `job.phase` read at line 76, so when
> `closeDispatch` commits `completed` in that window the update omits
> `phase`, the enqueued dispatch early-exits at `runSignifyFetchJob.ts:505`,
> and the parts just reset to `pending` are stranded. Reading it inside the
> committing transaction keeps this file's "phase is left alone while a job
> is running" intact.

After:

> Retry can be silently lost. `phase` comes from the read at line 76 — if the
> dispatch commits `completed` in between, this update omits `phase`, the
> enqueued task early-exits, and the reset parts stay `pending`. Read it
> inside the transaction.

Same facts, same length. The second answers "what breaks" before explaining
anything, so the reader can stop after four words and still know whether
this one is theirs.

**Compression is a new edit.** Shortening introduces claims exactly the way
writing did: a trimmed citation loses the qualifier that made it true, a
merged sentence invents a causal link. One compression pass in Baseline 5
silently reverted four already-corrected claims and broke an anchor. Re-read
against the file *after* shortening.

### The wall of text is the tell

This ran as the top finding on a three-file PR titled "Add an env var to
disable stats metrics":

> Default-off inverts the PR title ("an env var to **disable**" is
> opt-out, this is opt-in) and stops metrics that are live today.
> `metrics_loop` has spawned unconditionally since the service's first
> release, and `statsd::init` installs a real `BufferedUdpMetricSink`
> whenever `dd_agent_host` is set (`statsd.rs:8-21`), so the service's
> four gauges are emitting in every environment with a DD agent. Nothing
> sets the new var — grep returns only the three diff lines, and the
> service's env is supplied out-of-tree by a separate environments repo
> (`.github/workflows/deploy.yaml:5-8`). House precedent splits
> exactly on this: `common/src/database/mod.rs:88-89` defaults
> `recycling_check_enabled` to `true` because it gates existing
> behaviour, whereas `backend/src/config.rs:250-254` defaults
> `permission_v2_enabled` to `false` and justifies it as new
> infrastructure.

Every sentence is true and the correct action was to delete all of it.
Turning those metrics off was the PR's purpose; the doc comment said "Off
by default" and the log line said how to turn them back on. The finding
was arguing with the deliverable.

The length is what should have caught it. Two hundred words of git
archaeology and cross-service precedent is not what a real defect needs —
it is what a finding needs when it has to talk the reader into a premise
the author already rejected on purpose. When a finding will not fit in a
sentence, suspect the finding before you start trimming the prose.

Its mirror is a forty-word comment nobody can read. "The modes dedup through
different cell paths, record rows by `value.docId`, manual rows by
`value.fields.manufacturersProductId.value`, and neither shape has the
other's field, so the table-wide identity the PR describes holds only within
one mode" is short and still costs two readings, because six facts and four
citations arrive before the verb. Length was never the target. The reader's
working memory is.

## Posting to GitHub

Submit one review, not N comments: `POST /repos/{owner}/{repo}/pulls/{n}/reviews`
with a `comments` array. One notification, one thread group.

**A comment lands only on a line inside a diff hunk.** Compute the ranges
before writing blocks — `git diff -U3 BASE..HEAD -- <path> | grep '^@@'` —
because on a PR that modifies existing files the lines you most want to fix
are unchanged context, and the hunk's few context lines are all you get. A
finding anchored outside every hunk becomes a plain comment on the nearest
in-hunk line, naming the out-of-hunk lines in its text. New files are
wholly in the diff, so this bites exactly the long-lived files.

The review body carries only what cannot be derived from the inline
comments — manual steps no suggestion covers (a new config key, an added
import), and a caveat about the code that no single anchor owns. When there
is nothing of that kind, the body is empty. Two comments that must be
applied together say so in their own text; a body repeating it is
redundant. **GitHub renders no numbering on inline comments**, so a body
that says "comment 3" points at a label the reader cannot see — refer to a
comment by its file and the symbol it lands on. A body already submitted
can be replaced without touching the inline comments:
`PUT /repos/{owner}/{repo}/pulls/{n}/reviews/{review_id}`.

## Red Flags — stop and re-verify

Triggers, not arguments. Each one's reasoning lives in the step it belongs
to; if a flag fires and you want the case for it, that is where it is.

- Citing a flag, method or line you have not read to the end of.
- Asserting a failure path you never executed, when a scratch script would
  run it.
- Verifying hardest on the findings you expect to reject. The relayed ones
  are the ones that reach the author.
- Illustrating a test gap with a mutation nobody would make. An absurd
  mutation argues the constant is obvious, not that the gap matters.
- Writing a concession into a finding — "low impact", "clients tolerate
  this" — and continuing past it. The concession already decided the size.
- Citing any file but the anchor.
- Calling a docstring a lie. "Lets tests verify X without reaching in"
  describes encapsulation, not avoidance.
- Two findings that reference each other. Check whether A stands alone.
- "Could in principle" / "a future maintainer might".
- Pasting a suggestion block you have not read against the lines it
  replaces.
- A fix whose recovery path calls the thing that just failed.
- Asking for a test on a path you have not traced.
- A nit whose fix needs a new type, abstraction, or signature change.
- Shortening a comment. Everything in it is a fresh claim again.
- An anchor that is a bare filename, or a line no hunk covers.
- Two comments on one file you have not read as a single patch.
- A finding that says "either X or Y".
- A body that describes your review instead of their code.
- A finding with no observation only reading the code could have produced.
- Padding to make the review feel thorough.
- A first sentence that is a mechanism, with the symptom never arriving.

## Rationalization Table

| Excuse | Reality |
|---|---|
| "Reviewer cited file:line, that's verification enough" | Citation is a claim, not a verification. Read the line. |
| "User can filter the noise themselves" | That defeats the value of the review. |
| "Dropping findings feels like suppressing bugs" | Unverified ≠ real. Verification is the opposite of suppression. |
| "Reviewer subagent has more context than me" | And is more hallucinatory under volume pressure. Verify. |
| "I just verified the previous one, I'll catch the next" | Past-tense verification doesn't apply to the next finding. |
| "Skipping verification this once because the PR is small" | Small PRs still produce noisy reviews. |
| "Reading the cited line is the verification this skill asks for" | It settles the premise. The finding also asserts a consequence, and that needs its own check. |
| "The library isn't installed, so this one is unverifiable" | Unverifiable means you tried. Install it, then decide. |
| "I reasoned through the call chain, checking it would tell me the same thing" | In Baseline 3 below it did not: one relayed finding died and one dropped finding came back once the behaviour was checked rather than inferred. |
| "The title is loose wording; the code is what I review" | The title is the requirement. When it and the code agree, a finding against both is a finding against the deliverable. |
| "The suggestion is only a few lines, I can see it is right" | So is most broken code. Read it against the lines it replaces. Baseline 5's duplicated UI string was three words. |
| "The author will work out the rest of the fix" | They will implement what you wrote. An underspecified remedy becomes a refactor you did not ask for, or a test that covers nothing. |
| "I grepped the symbol, that is the companion list" | Prose has no symbol. Grep the number and the words of the claim, or you will ship a finding that leaves three stale restatements behind. |
| "It is shorter now, so it is clearer" | Six facts in forty words is denser, not clearer. Symptom first, one fact per sentence, references at the end. |
| "Trimming cannot introduce an error, it only removes words" | It removed the qualifier that made the claim true. Baseline 5 lost four corrected claims and an anchor to one compression pass. |
| "I'll let the author pick which branch to take" | Whoever applies it picks, and then writes a justification for the branch they chose. Baseline 6's was overclaimed and shipped in a JSDoc. |
| "Every comment checks out on its own" | They land together. Two comments on one file are one patch, and Baseline 6's pair cancelled each other. |
| "The fix is small, it cannot reach another finding" | Baseline 6's three-line timeout move admitted an abort that the classifier bucketed as the exact thing the next comment was about. |

## Real-World Baseline

Six runs on real pull requests, with what each cost: how many findings a
subagent returned, how many survived verification, and which specific
error each surviving rule above was written to stop. Read
`references/baselines.md` when a rule here looks arbitrary or when you are
weighing whether to drop a finding you cannot quite justify — the
baselines are the evidence for every rule in this file, and Baselines 5
and 6 are the evidence for steps 5 and 6 specifically.
