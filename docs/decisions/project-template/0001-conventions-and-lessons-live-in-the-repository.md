# 0001. Conventions and lessons live in the repository, not in volatile memory

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

Contributors, people and coding agents alike, learn durable things while they work: coding conventions, the reasons
behind non-obvious choices, and recurring gotchas in tools and analyzers. Where that knowledge is written down decides
whether it survives.

An agent's session or memory, a personal note, a chat transcript and an external wiki are volatile as a system of
record. They are unversioned, unreviewed, invisible to other contributors and to other tools, and not diffed alongside
the code they describe. A rule that lives only there drifts from the code, does not reach the next session or the
other tool, and is learned again and again.

## Decision

All durable knowledge is kept in versioned files in the repository, changed in the same change as the code it
describes. Each kind has one home:

- A convention every agent follows: `AGENTS.md`, or an instruction file it lists, such as
  `.github/instructions/<name>.instructions.md`. A rule for Claude Code only goes in `.claude/rules/<name>.md`.
- The reasoning behind a non-obvious decision: an architecture decision record in `docs/decisions/`. The template's
  own decisions are in `docs/decisions/project-template/`.
- Build and test commands and how the work lands: `AGENTS.md`'s Commands and Landing sections.
- Work still to do: an issue ([ADR-0007](0007-pending-work-is-tracked-as-issues.md)).
- The plan in progress: `PLAN.md`, a gitignored working file that `/finish-plan` deletes once its work lands. A plan
  decision that must outlast it is written to one of the homes above by one of its steps, and `/ship-plan` files its
  follow-ups as issues.

The template's own rules arrive in template-owned files, such as
`.github/instructions/project-template.instructions.md` and the records in `docs/decisions/project-template/`, which
template updates replace. A project never edits them: it overrides a template rule in `AGENTS.md` or a file
`AGENTS.md` lists, and the project's instruction wins. A project that decides against one of the template's records
writes its own record that supersedes it.

When a contributor or an agent learns something durable during a task, it is written to its home as part of the same
change. Session memory may serve as a scratchpad within a task; anything meant to outlast the task is moved into the
repository before the task is done.

## Options considered

- Agent or personal memory as the record. Rejected: volatile, unreviewed, and unseen by other contributors, other tools
  and CI.
- An external wiki or documentation site. Rejected: it is not part of the change, so it is not reviewed with the code
  and drifts from it.
- Versioned files in the repository (chosen). They are reviewed in the same pull request as the code, versioned with
  it, and read by every agent through `AGENTS.md`.

## Consequences

- Conventions and their reasons are reviewable, versioned, and shared with every contributor and every future agent
  session, whichever tool it runs in.
- There is no shadow rule set in an agent's memory to fall out of step with the instruction files.
- `AGENTS.md` stays an index under 200 lines; longer guidance goes in a file it lists.
- Smell: a rule that holds only because an agent happens to remember it, or a lesson that exists only in a chat, a note
  or a memory. Move it into the repository, or it does not exist.

## References

- `AGENTS.md`, `.github/instructions/`, `.claude/rules/`, `docs/decisions/`
- [ADR-0003](0003-agent-work-is-planned-on-a-frontier-model-and-executed-on-a-cheaper-one.md): agent work is planned
  on a frontier model and executed on a cheaper one.
- [ADR-0007](0007-pending-work-is-tracked-as-issues.md): pending work is tracked as issues.
