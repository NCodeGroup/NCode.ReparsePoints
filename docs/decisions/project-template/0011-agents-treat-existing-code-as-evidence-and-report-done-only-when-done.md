# 0011. Agents treat existing code as evidence, pin what is current upstream, and report done only when done everywhere

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

A coding agent learns how a repository works mostly by reading it. That is usually right, and it fails in three
predictable ways.

Existing code is a snapshot. It records what someone decided at some point, with what they knew then. An agent told to
"follow the existing patterns" copies an outdated or insecure shape into new code, and the more often it is copied,
the more it looks like a rule. A comment or a document that describes the old shape keeps teaching it after the code
has moved on.

An agent also asks too much, or too little. Asking the person to choose between options that current practice already
settles, such as which hash to use or whether a cookie is `Secure`, spends their attention on noise. Choosing alone
between options that are genuinely different in value or risk takes a decision from them that they should make.

Versions go stale silently. A version an agent remembers, or one installed on the machine it runs on, says nothing
about what is current. A pin chosen that way is out of date the day it lands.

Finally, "done" drifts. An agent reports an item finished while its issue is still open, a todo list still shows it,
or a document still lists it as remaining, and the next reader cannot tell which is true.

## Decision

1. Existing code is evidence, not a constraint. Code, comments, settings and documents are evidence of what was
   intended when they were written. A shape that is outdated or insecure is corrected within the change's scope, or
   filed as an issue ([ADR-0007](0007-pending-work-is-tracked-as-issues.md)) when it is outside it, and is never copied
   as a pattern. The comments, documents and instruction files that state the old shape change in the same change
   ([ADR-0001](0001-conventions-and-lessons-live-in-the-repository.md)). A decision record is different: it binds until
   a new record supersedes it ([ADR-0010](0010-a-change-consumers-can-observe-is-decided-before-it-is-built.md)), and a
   record that conflicts with an external standard or current security practice is superseded to align with it, never
   cited to justify the deviation.
2. Decide, don't ask, where practice settles it. An agent defaults to the current authoritative practice for the domain,
   secure by default, and names the guidance it follows in the plan or the record. It surfaces a choice to the person
   only when the options are equally good in value, security and semantics, never because one of them is more work.
3. Pin what is current upstream. When an agent adds or moves a version pin (a package, an action, an SDK, a tool, an
   image), it reads the available releases from the upstream source at that moment: the package registry, the release
   feed, `gh release view`, `dotnet package search`, `npm view`. It never uses a version it remembers or finds
   installed. It then takes the newest release that has passed the cooldown
   ([ADR-0009](0009-new-dependency-versions-wait-a-cooldown.md)).
4. Done is binary and global. An item is reported done, in a reply, a todo list, a plan or by closing its issue, only
   when no work remains and nothing still frames it as pending: an open issue, an unchecked todo, a plan step, a
   "remaining" line in a document or the changelog. Before claiming done, the agent re-reads the item's issue and
   reconciles every tracker. An item with any remainder is partial: the agent says so and edits the issue down to the
   remaining work.

## Options considered

- Follow existing patterns for consistency. Rejected: consistency with an insecure or outdated shape spreads it.
- Ask the person about every design choice. Rejected: questions that current practice answers bury the ones that need
  a person.
- Pin the version that is installed or remembered. Rejected: it is stale by construction, and the cooldown then delays
  an already old version.
- Report done when the agent's own part is finished. Rejected: two sources that disagree about one item leave the
  reader unable to trust either.
- Evidence, not constraint; decide where practice settles it; pin from upstream; done everywhere or partial (chosen).

## Consequences

- New code reflects current practice rather than the oldest pattern in the repository, and the documents move with it.
- The person is asked fewer questions, and the ones asked are real trade-offs.
- Version pins are as current as the cooldown allows when they land.
- "Done" can be checked against any tracker and gives the same answer.
- Smell: a new file that repeats a pattern the change's own review would reject; a pin older than the newest release
  past its cooldown; an issue closed while a document still lists its work as remaining.

## References

- `AGENTS.md`, `.github/instructions/project-template.instructions.md`
- [ADR-0001](0001-conventions-and-lessons-live-in-the-repository.md): conventions and lessons live in the repository.
- [ADR-0007](0007-pending-work-is-tracked-as-issues.md): pending work is tracked as issues.
- [ADR-0008](0008-external-inputs-are-pinned-and-kept-current.md): external inputs are pinned exactly and kept current.
- [ADR-0009](0009-new-dependency-versions-wait-a-cooldown.md): a new dependency version waits three days.
- [ADR-0010](0010-a-change-consumers-can-observe-is-decided-before-it-is-built.md): a change consumers can observe is
  decided before it is built.
