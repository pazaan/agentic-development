# Worked Examples

Examples for the finding-writing rules in `reviewing-code`. Load this when a
finding's shape is in doubt.

## Symptom first

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

## The wall of text is the tell

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
the author already rejected on purpose.

## Its mirror: short and unreadable

"The modes dedup through different cell paths, record rows by
`value.docId`, manual rows by `value.fields.manufacturersProductId.value`,
and neither shape has the other's field, so the table-wide identity the PR
describes holds only within one mode" is short and still costs two
readings, because six facts and four citations arrive before the verb.
Length was never the target. The reader's working memory is.
