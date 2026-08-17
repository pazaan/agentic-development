# Scheduling skill-drift-check

`agents/skill-drift-check.md` is the subagent. Wire it to your `schedule`
skill's project state file so it fires on a cadence — e.g. weekly.

## Routine entry

Add to your `schedule` state (the exact file location is documented by
the `schedule` skill):

```yaml
- name: skill-drift-check
  agent: skill-drift-check
  cron: "0 9 * * 1"        # Mondays 09:00 local
  context: |
    Run the skill-drift-check subagent against SKILLS.md and report
    drift. Read-only; do not re-pin SHAs.
```

## What you get back

A per-skill report:

```yaml
verdict: DRIFT
per-skill:
  - skill: superpowers:test-driven-development
    pinned-sha: abc1234
    upstream-sha: def5678
    drift-summary: 12 additions, 3 deletions in "Workflow" section
```

## Acting on a drift report

1. Read the upstream diff in full.
2. Decide whether the changes are desirable / safe.
3. If yes: bump the `Pinned SHA` column in SKILLS.md and verify the role
   bodies that reference the skill still produce the expected behavior.
4. If no: leave the pin; record the reason in a memory entry so the next
   run does not re-prompt.
