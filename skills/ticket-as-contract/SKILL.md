---
name: ticket-as-contract
description: Use when Lead is writing a plan note or when Reviewer is adjudicating findings. Enforces that the ticket (from whichever ticket-source binding is active) is the contract; the plan and review are derivative artifacts that must trace back to ticket acceptance criteria.
---

# Ticket as contract

The ticket — fetched via `agentic-development:ticket-source` — is the
authoritative scope. The plan note, the review findings, and the merge
gate all trace back to its acceptance criteria.

## Lead: Plan note template

Every plan note ships with two sections that this skill validates:

### `## Ticket Criteria Mapping`

For each AC in the ticket, copy the AC verbatim and name the plan section
that addresses it:

```
- AC-1: <verbatim AC text>
  addressed by: <plan section heading>
- AC-2: <verbatim AC text>
  addressed by: <plan section heading>
```

Refuse to ship the plan if:
- A plan deliverable does not map to any AC → drop the deliverable, or
  HALT and reconsider scope.
- An AC has no matching plan deliverable → add it, or HALT and split
  into a follow-up ticket (with user authorization).

### `## Build Order`

Concrete sequence ending with the gate sequence appropriate for the
project's role topology. The default sequence:

1. Lead spawns Coder + Reviewer (and Tester if UI-affecting).
2. Lead briefs Coder; Coder implements with TDD.
3. Reviewer reviews staged diff pre-commit.
4. Lead adjudicates findings; relays actionable items to Coder.
5. Coder fixes; loop 3-4 until clean.
6. Coder commits + pushes, using the command resolved by Step 0 of
   `agentic-development:stacked-prs` and gated on `$PROJECT_PUSH_ALLOWED`
   (skip if `mode: local-stack`).
7. Lead dismisses persistent teammates (skip if `mode: local-stack`).

## Reviewer: Adjudication routing

Reviewer findings flow Reviewer → Lead → Coder, never Reviewer → Coder
directly. Lead adjudicates against the ticket-contract before relaying:

- **In-scope** findings reach Coder.
- **Out-of-scope** findings get dropped or split into follow-up tickets
  (with user authorization).
- **Disputed** findings get one re-look from Reviewer; if still disputed,
  user decides.

## Refuse triggers

- Plan note missing `## Ticket Criteria Mapping` or `## Build Order`.
- Plan deliverable with no AC mapping.
- AC with no plan deliverable.
- Reviewer attempting `gh pr review` or direct Coder contact.
- Coder accepting findings without Lead adjudication.

## Output shape

For Lead: a complete plan note with both required sections. For Reviewer:
the adjudication routing table populated for each finding.
