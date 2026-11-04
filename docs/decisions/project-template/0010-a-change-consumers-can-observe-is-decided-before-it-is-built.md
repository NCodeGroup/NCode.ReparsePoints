# 0010. A change consumers can observe is decided before it is built

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

Some changes reach past the code that makes them. A changed public API or surface, a change in behavior or semantics,
a tightened or loosened validation or security posture, or a new shape for stored data or a wire format is seen by
consumers: callers, integrators, operators, and the data already written. Once such a change has shipped, undoing it
is itself a change they observe.

When the decision behind such a change is made inside the pull request that builds it, three things go wrong. The
options were never compared, because the code already commits to one. The reasoning lives in review comments, which
are not where the next contributor or agent looks. And a reviewer judging the diff is asked to approve a decision and
its implementation at once, so the decision gets the attention left over from the code.

Most changes are not like this. A bug fix restores the behavior consumers already expect, and an internal change is
invisible to them; a decision record for each would bury the records that matter.

## Decision

A change that consumers can observe is decided before it is built, and the decision is recorded.

1. A change to public API or surface, behavior or semantics, validation or security posture, or stored data or wire
   formats starts as an issue ([ADR-0007](0007-pending-work-is-tracked-as-issues.md)). Its decision is agreed there.
2. The agreed decision is recorded as an architecture decision record in `docs/decisions/`, before or with the pull
   request that builds it ([ADR-0001](0001-conventions-and-lessons-live-in-the-repository.md)). The pull request refers
   to the issue, and the issue links the record.
3. `/analyze-decision` compares the options and writes the record into `docs/decisions/`. The template's records in
   `docs/decisions/project-template/` are never edited: a project that decides otherwise writes its own record with a
   `Supersedes: project-template ADR-NNNN` line.
4. Bug fixes, patches and internal changes go straight to a pull request that refers to the issue, with no record.
5. `.template/Test-AdrIndex.ps1` runs in CI for every stack and checks the project's index: `docs/decisions/README.md`
   lists every record and links none that is missing.

## Options considered

- Decide in the pull request. Rejected: the code commits to one option before any other is compared, and the reasoning
  ends up in review comments nobody reads again.
- A decision record for every change. Rejected: fixes and internal changes would bury the records consumers care about,
  and the rule would soon be skipped.
- Decide in an issue and record the decision for changes consumers can observe (chosen). The decision gets its own
  review, the record outlasts the issue, and everything else lands without ceremony.

## Consequences

- A pull request that changes what consumers observe arrives with a record that says why, and its review judges the
  implementation against an agreed decision.
- The question to ask before starting is whether a consumer could notice the change. When the answer is yes, the work
  starts with an issue and a decision, not with code.
- Records accumulate as the project's history of what it decided and why; a later reversal is a new record that
  supersedes the old one, so the history stays readable.
- An index that misses a record, or links one that does not exist, fails CI.
- Smell: a pull request that changes a public signature, a validation rule or a stored format with no record linked from
  its issue.

## References

- `docs/decisions/`, `docs/decisions/README.md`, `.template/Test-AdrIndex.ps1`, `/analyze-decision`
- [ADR-0001](0001-conventions-and-lessons-live-in-the-repository.md): conventions and lessons live in the repository.
- [ADR-0007](0007-pending-work-is-tracked-as-issues.md): pending work is tracked as issues.
