# 0013. Pull requests merge with a merge commit or by rebasing

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

A host merges a pull request by a merge commit, by rebasing its commits, or by squashing them into one; a merge queue
lands a pull request with one of these after testing the merged result.

A plan lands as `Plan step N` commits, each one a verified change
([ADR-0003](0003-agent-work-is-planned-on-a-frontier-model-and-executed-on-a-cheaper-one.md)). A merge commit or a
rebase keeps them; a squash makes one commit of them. GitHub's squash commit copies the co-author trailers of every
branch commit and, with the squash commit message set to the pull request's title and description, the description too
([ADR-0002](0002-commits-are-attributed-to-people-not-agents.md)).

Some projects need squash: a linear history with a merge queue that squash-merges. If the rule were stated in three
records, such a project would have to override three of them.

## Decision

A pull request into the default branch merges with a merge commit or by rebasing, never by squashing. The repository
baseline's ruleset allows only those two methods, and a person who approves by turning on auto-merge picks a merge
commit ([ADR-0006](0006-a-person-merges-every-pull-request.md)). On GitLab, `tools/Set-GitLabBaseline.ps1` in the
project template's repository sets the project's "Squash commits when merging" to "Do not allow".

This record is the one place the template sets the merge method; ADR-0004, ADR-0005 and ADR-0006 refer to it.

A project that squash-merges, for example through a merge queue, writes one record that says
`Supersedes: project-template ADR-0013` and lists it in `AGENTS.md`. Such a project:

- makes `Commit attribution` a required check, the guard it needs: the check also reads the pull request's title and
  description that the squash commit takes, runs again on GitHub when they are edited, and in a merge queue checks the
  queue's commits themselves;
- accepts that the `Plan step N` commits stay on the pull request, not on the default branch;
- lets the queue's run on the merged result stand for an up-to-date branch
  ([ADR-0005](0005-the-default-branch-accepts-changes-only-through-pull-requests.md)).

## Options considered

- A merge commit or a rebase by default. Chosen: it keeps each verified step commit and copies nothing from the pull
  request into the default branch.
- Squash by default. Rejected: it collapses the verified step commits and copies trailers and the description into the
  default branch.
- A Landing or Copier setting for the method. Rejected: the method is the host's and the ruleset's setting, and the
  records would still have to agree; one superseding record is the override.
- The rule in each of ADR-0004, ADR-0005 and ADR-0006. Rejected: three overrides for one choice.

## Consequences

- A project that squash-merges supersedes one record.
- Such a project depends on the required `Commit attribution` check, which only a squash commit's host-written message
  makes necessary.
- `/finish-plan` still counts a squash-merged branch as landed.

## References

- [ADR-0002](0002-commits-are-attributed-to-people-not-agents.md): commits are attributed to people, not agents.
- [ADR-0004](0004-trunk-based-development-on-the-default-branch.md): trunk-based development on the default branch.
- [ADR-0005](0005-the-default-branch-accepts-changes-only-through-pull-requests.md): the default branch accepts changes
  only through pull requests that pass CI.
- [ADR-0006](0006-a-person-merges-every-pull-request.md): a person merges every pull request.
- `.template/Test-CommitAttribution.ps1`: the commit attribution check.
- `tools/Set-RepositoryBaseline.ps1` in the project template's repository: the baseline's ruleset.
- `tools/Set-GitLabBaseline.ps1` in the project template's repository: the GitLab project's squash setting.
- [project-template#200](https://github.com/NCodeGroup/project-template/issues/200) and
  [project-template#201](https://github.com/NCodeGroup/project-template/issues/201)
