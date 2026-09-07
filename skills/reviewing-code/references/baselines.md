# Real-World Baseline

Six runs of `reviewing-code` on real pull requests, and what each one
cost before the rule that now prevents it existed. Load this when a rule
in the skill looks arbitrary, when deciding whether to drop a finding you
cannot quite justify, or when calibrating how much verification a review
warrants.

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

**Baseline 5** — a 103-file feature PR on a Firebase and React monorepo; the
baseline for verifying remedies. Sixteen findings relayed over two cycles,
each cycle applied by a junior-persona agent to a throwaway branch whose fix
diff was then reviewed. No relayed finding was ever shown false. Eleven
defects were found in the review anyway, every one in what followed the
finding.

Two are worth repeating because they are counterintuitive. "Delete the
unreachable branch" was impossible as written: the branch was the runtime
half of a type narrowing, so deleting it forced two new types, a predicate
and a signature change across four functions — a refactor set in motion by a
nit. And a prescribed test setup ("a part whose price fetch throws") could
not occur at all, because the code turned every such rejection into a field
and returned success; the finding should have been that the path was
unreachable.

Six of the eleven were one mistake repeated: a finding invalidated a stated
claim or moved a written-out number, and grepping the symbol found none of
the prose restating it.

**Baseline 6** — the next PR on that monorepo; the baseline for step 6 and
the posting mechanics. Fourteen findings, thirteen sound premises, and
four defects step 5 could not see because each belonged to the set rather
than to a finding. Two comments on one file cancelled — one deleted a
cache tier, the other's block re-asserted the "all three kinds" prose that
deletion falsifies. One fix moved a timeout past a body read and admitted
an abort the classifier buckets as `permanent`, which was the next
comment's entire subject. One block closed a race and, in the same four
lines, turned a `not-found` throw into a silent success. And "wire it or
delete it" was decided by the junior applying it, who wrote an overclaimed
justification into a JSDoc.

Mechanically: the body cited "comment 1" and "comment 3", labels GitHub
does not render, so most of it was unresolvable; and the highest-impact
finding could carry no block at all, its lines being unchanged context
outside every hunk — found only after the blocks were written.

The single false premise failed on a Red Flag already listed. A
store-registry finding cited the `registry.set` inside `connect` as the
only one; construction registers too, forty lines below, which makes the
described failure impossible.
