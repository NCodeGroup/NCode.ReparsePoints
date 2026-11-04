# 0005. The default branch accepts changes only through pull requests that pass CI

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

CI runs the build, the tests and the commit attribution check on every pull request, but a direct push to the default
branch skips all of it. The push is the one path by which an unchecked commit reaches the trunk. Every other
contributor already works through branches: plans land through `/ship-plan`, `/run-issues` opens a pull request per
issue, and dependency bots and cloud agents open pull requests of their own.

A rule that requires an approving review cannot be met in a repository with one maintainer, because a host does not
let the author approve their own pull request. A pull request rule with zero required approvals, combined with
required status checks, can be met by one person and still enforces the gate.

## Decision

The default branch accepts changes only through a pull request whose required checks pass on a branch up to date with
it, or, in a project that merges through a merge queue, on the merged result the queue tests.

1. On GitHub, one repository ruleset protects the default branch, with no bypass actors, as the template's repository
   baseline writes it:
   - the branch cannot be deleted or force-pushed;
   - a pull request is required, with zero required approvals and every review conversation resolved before the merge,
     each one remediated and replied to first
     ([ADR-0014](0014-every-pull-request-discussion-is-remediated-and-replied-to-before-it-merges.md));
   - merges use the methods [ADR-0013](0013-pull-requests-merge-with-a-merge-commit-or-by-rebasing.md) sets: a merge
     commit or a rebase;
   - the CI jobs, `build-and-test` and `Commit attribution` by default, are required status checks on a branch that is
     up to date with the default branch;
   - where CodeQL's default setup is configured, a code-scanning rule blocks a pull request that adds an alert at
     warning level or above, or a security alert of any severity.
   The repository also deletes a pull request's head branch when it merges.
2. `AGENTS.md`'s Landing section says `integrate: pull-request`, so `/ship-plan` pushes the plan's branch and opens a
   pull request; it never pushes the default branch.
3. A required check reports on every pull request. A job whose workflow has `paths` or `branches` filters reports
   nothing on a pull request the filters skip, which then waits forever, so a required job runs unconditionally and
   decides inside the job what work to skip.
4. On a host that cannot require pull requests, such as a private repository on GitHub Free, the Landing section sets
   `protect: hook`, and `.githooks/pre-push` refuses any push to the default branch from a clone that runs the
   template's hooks. On GitLab, the default branch's protection with "Allowed to push and merge" set to "No one",
   and the project's "Pipelines must succeed" merge check, play the ruleset's part; `tools/Set-GitLabBaseline.ps1` in
   the project template's repository sets both.
5. An approval requirement is added when a second maintainer exists.

## Options considered

- No protection, relying on people and agents to run the checks before pushing. Rejected: a direct push skips the gate
  that CI already runs.
- Require one approving review. Rejected while there is one maintainer: it cannot be met.
- The merge method. Decided in [ADR-0013](0013-pull-requests-merge-with-a-merge-commit-or-by-rebasing.md), so a project
  that squash-merges supersedes that record alone.
- `integrate: direct`, pushing reviewed plans straight to the default branch. A Landing option for a project that
  chooses it, but not the default: it forgoes the server-side gate, and a project that uses it records why.
- Pull requests with required checks and zero approvals (chosen).

## Consequences

- Every change, a person's, an agent's or a bot's, reaches the default branch only through a green pull request,
  tested up to date with the default branch or in a merge queue.
- A branch behind the default branch takes it in before it merges, unless a merge queue tests the merged result.
- A CI job added later that should gate merges is added to the ruleset's required checks, and must report on every pull
  request; a job that runs only on a release or a schedule is never required, since it would block every merge.
- Changing the ruleset is an administrator's action in the host's settings, and the host records it.

## References

- `AGENTS.md` Landing section, `.githooks/pre-push`, `.github/workflows/ci.yml` or `.gitlab-ci.yml`
- `tools/Set-RepositoryBaseline.ps1` in the project template's repository, which writes the ruleset
- `tools/Set-GitLabBaseline.ps1` in the project template's repository, which lets no one push to a GitLab project's
  default branch and turns on its merge checks
- [ADR-0002](0002-commits-are-attributed-to-people-not-agents.md): commits are attributed to people, not agents.
- [ADR-0004](0004-trunk-based-development-on-the-default-branch.md): trunk-based development on the default branch.
- [ADR-0006](0006-a-person-merges-every-pull-request.md): a person merges every pull request.
- [ADR-0013](0013-pull-requests-merge-with-a-merge-commit-or-by-rebasing.md): pull requests merge with a merge commit or
  by rebasing.
- [ADR-0014](0014-every-pull-request-discussion-is-remediated-and-replied-to-before-it-merges.md): every pull request
  discussion is remediated and replied to before it merges.
