# 0012. The template's decision records are numbered below 1000, a project's from 1000

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

A project keeps two sets of decision records: its own in `docs/decisions/`, and the template's in
`docs/decisions/project-template/`, which every template update replaces. Both are numbered with four digits, and
records, issues, commit messages, changelog entries and instruction files cite them by number, as "ADR-0102". When
both sets count from 0001, one number names two records: a project's ADR-0007 and the template's ADR-0007 are different
decisions, and a template update that adds a record can bring a number the project already uses. Neither a reader nor
an agent can tell from a bare number which record is meant, and the template's own files cite its records that way.

## Decision

The template and a project number their decision records from separate ranges.

1. The template's records in `docs/decisions/project-template/` take numbers below 1000: 0001–0099 for every project,
   and 0100–0999 for the records of a stack or an option, such as .NET's from 0100. Outside that folder,
   `docs/decisions/0000-template.md`, the file a project copies for a new record, is the one file numbered 0000.
2. A project's records in `docs/decisions/` take numbers from 1000: the first is 1000, and each next one is the next
   number above the highest record numbered 1000 or more on the default branch or on any open branch, pull request or
   worktree.
3. A project whose records started below 1000 keeps their numbers, because links, issues and commits cite them, and
   numbers its next records from 1000. Where such a project cites one of the template's records, it writes
   "project-template ADR-NNNN".
4. `.template/Test-AdrIndex.ps1` checks the project's index and fails a new project record numbered below 1000: one
   whose number no record had at the merge base with the default branch. Records a project already had below 1000
   still pass, and without a merge base, as in a shallow clone, it skips that check and says so.

## Options considered

- Both count from 0001, told apart by folder. Rejected: a cited number does not carry its folder, so "ADR-0007" stays
  ambiguous.
- A prefix in every citation, such as "PT-0007" for the template's. Rejected: it renames every record and citation the
  template ships, and a citation without the prefix is ambiguous again.
- Separate ranges, the template's below 1000 and a project's from 1000 (chosen). The template's numbers and file names
  stay as they are, a bare number names one record, and four digits leave a project 9000 numbers.

## Consequences

- An ADR number in a project, in its own files or the template's, names one record: below 1000 the template's, 1000
  and up the project's.
- A template update never adds a record with the number of a project record numbered from 1000.
- `/analyze-decision` gives a project's next record a number from 1000, and a new project's `docs/decisions/README.md`
  says so. That README is the project's own, so a project made from an earlier template version changes its "starting
  from `0001`" line by hand.
- A branch that adds a project record numbered below 1000 fails `.template/Test-AdrIndex.ps1`. Smell: a template record
  numbered 1000 or more.

## References

- `docs/decisions/README.md`, `docs/decisions/project-template/README.md`, `.template/Test-AdrIndex.ps1`,
  `/analyze-decision`
- [ADR-0001](0001-conventions-and-lessons-live-in-the-repository.md): conventions and lessons live in the repository.
- [ADR-0010](0010-a-change-consumers-can-observe-is-decided-before-it-is-built.md): a change consumers can observe is
  decided before it is built.
