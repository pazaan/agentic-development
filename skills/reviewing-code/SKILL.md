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
can be.

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

5. **Emit it in the shape below.** Verification decides *what* is relayed;
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
   entire review. Otherwise, one line of remediation.

Order findings most-severe first. That ordering is the severity signal.

A finding whose fix spans non-contiguous lines names the companion
locations inside part 2. A finding you could not reduce to a defect —
a design decision worth questioning — still gets the same three parts,
with part 2 stating what makes it a question.

**Length tracks severity.** Size is the first severity signal the reader
takes in, ahead of any of the words, so it has to match the finding.
Part 2 is one sentence. A bug may take two — the defect, then the
trigger. Nothing takes three. A table, a multi-paragraph rationale, or a
multi-file remediation plan claims blocker status; when the finding is
not a blocker, that size is telling you something. Usually the finding is
fine and only its size is wrong, so shrink it rather than dropping it —
but check which, because sometimes the size is the symptom.

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

## Posting to GitHub

Submit one review, not N comments: `POST /repos/{owner}/{repo}/pulls/{n}/reviews`
with a `comments` array. One notification, one thread group.

The review body carries only what cannot be derived from the inline
comments — which suggestions must be applied together, and manual steps no
suggestion covers (a new config key, an added import). When there is
nothing of that kind, the body is empty. A body already submitted can be
replaced without touching the inline comments:
`PUT /repos/{owner}/{repo}/pulls/{n}/reviews/{review_id}`.

## Red Flags — stop and re-verify

- About to relay a finding that cites a flag, method, or line you haven't
  read.
- About to assert a failure path you reasoned about but never executed,
  when the trigger is reproducible in a scratch script.
- Verifying hardest on the findings you expect to reject and least on the
  ones you are about to relay. The relayed ones are the ones that reach
  the author.
- Illustrating a test gap with a mutation nobody would make ("change this
  constant and no test fails"). An absurd mutation argues the constant is
  obvious, not that the gap matters.
- Writing a concession into a finding — "low impact", "clients tolerate
  this", "consistent with the existing model" — and then continuing past
  it. The concession has already decided the size: one line, then stop.
- Your finding cites a file other than the anchor. Cutting the second
  citation almost never loses the point, and keeping it is usually you
  showing your verification rather than the author needing it.
- Reviewer claims a docstring "lies" — read it carefully. "Lets tests
  verify X without reaching in" describes encapsulation (the function
  absorbs the brittle access), not avoidance.
- Two findings reference each other (A is a problem because of B). Check
  if A is real standalone.
- "Could in principle" / "a future maintainer might" / "if someone runs
  with -O" — drop unless the condition is plausible for this codebase.

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

## Anti-patterns

- Listing N findings none of which carry a concrete observation.
- "I dispatched the reviewer, here's what it said" — delegates filtering
  to the user.
- Claiming "I verified" where the finding shows nothing that could only
  come from reading the line.
- Padding minor findings to make the review feel thorough.

## Real-World Baseline

**Baseline 1** — a PR on an infra-scripts repo:
subagent returned 19 findings; verification surfaced 3 that hold up
(after user-side correction on one). Net 16 dropped as hypothetical,
premise-incorrect, out-of-scope, or style-nit. User filter work: zero
instead of 19.

**Baseline 2** — a PR on a web-client repo; the baseline for the Output
Contract. Verification worked (22 of 28 findings survived), but
the relay took three user corrections to reach a usable shape: verbose
severity-grouped prose, then the same content re-asked for as inline
suggestions, then a submitted review body opening "Reviewed the full diff
… no blockers on data integrity or authorization". On that last one:
"It's obvious the review has been done BECAUSE THERE ARE REVIEW COMMENTS.
Blockers are self evident." The findings were right all three times; only
the shape was wrong, which is why the fix is a recipe rather than a
prohibition (see `superpowers:writing-skills`, Match the Form to the
Failure).

**Baseline 3** — a PR on a backend monorepo; the baseline for
checking consequences. Every cited line was read, and every premise was
correct; of four relayed findings one still had to be withdrawn outright
and another corrected, because the error sat one step downstream of the
observation. A pagination claim ("page 2 re-returns the user") was
inferred from a correctly-observed missing guard and died on tracing
`PagedResults.complete()`, which emits no next link for a single-result
search. A test-gap finding was illustrated with a mutation dismissed on
sight as absurd — of course the IdP alias has to match the provider;
that's the whole idea. And a fifth, real finding had been dropped as
unverifiable only because `yarl` was not installed; a scratch venv later
confirmed it retargets the request to any route on the service.

The tell was an asymmetry visible in the transcript: execution-tier checks
(interpreter version, dependency features, column types) were run freely
on the findings expected to be *rejected*, and not once on the findings
about to be *relayed*.

The resurrected finding then failed the same way one layer down. Its
outcome half was executed — `yarl` does resolve `../../login/events`
against the request path — while its trigger half, whether the search
parser could put that string in the field at all, was assumed. It could,
as it turned out. Being right by luck is not verification, and "what
would have to be true for an operator to reach this?" is the question the
vivid half makes easy to skip.

The relay then failed on size rather than substance. Two nits ran to
three paragraphs each — one carrying a traversal table, the other a
three-location refactor plan appended to a finding whose own text
conceded "clients demonstrably tolerate it". Both were deleted as
overreach before the actual verdict arrived: "I don't mind the finding
of the issue, but the wall of text makes it appear to be major whereas
in reality, they're nits." Neither finding was wrong. Re-posted at one
or two lines, both were fine.

**Baseline 4** — the next PR on the same monorepo; the baseline for
reading the PR's purpose, and for whose benefit a finding is written.
Seven reviewer findings went in and two came out, and the top one was
both too long and wrong. Too long because step 3 said to relay "with
proof", and proof had been read as something the comment must display:
"This is still not something I would post to a professional human
software developer. I don't need to educate them, just point out the
problem and the fix." Wrong because the PR was titled "Add an env var to
disable stats metrics", and the finding argued the metrics
should stay on — "the WHOLE POINT of the PR … Did you just not take that
in as context?" The subagent raised it as its own top Important finding
and every cited line checked out, so verification-as-practised waved it
through; nothing in the workflow asked whether the change was the point
of the change. Net after correction: one nit.
