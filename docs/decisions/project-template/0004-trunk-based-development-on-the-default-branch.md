# 0004. Trunk-based development on the default branch

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

A repository needs one answer to where work lands. A GitFlow-shaped model keeps a long-lived integration branch beside
the released line, so in-progress work is staged away from a trunk that consumers build against. That model costs a
second branch kept in sync by hand, a merge step between them, and a default branch whose build status, dependency
updates and code scanning describe a branch that receives few commits.

Repository hosts attach their defaults to the default branch: the landing page, build status, dependency updates, code
scanning and branch rules. The plan-then-execute workflow also branches each plan from the default branch and lands it
there.

## Decision

Develop on one trunk, the default branch, `main`. There is no long-lived integration branch.

- Every change starts on a short-lived branch cut from `main`: a plan's branch (`worktree-<name>` in Claude Code,
  `issue-<number>` from `/run-issues`), a Dependabot branch, or a person's topic branch.
- A branch lives for one change. It lands on `main` as the Landing section of `AGENTS.md` says, then it is deleted:
  `/finish-plan` deletes a plan's merged branch, and the host deletes a pull request's head branch when it merges.
- How a change reaches `main` (a pull request whose checks pass, by default) is
  [ADR-0005](0005-the-default-branch-accepts-changes-only-through-pull-requests.md). The method that merges it, which
  decides whether the plan's `Plan step N` commits stay on `main`, is
  [ADR-0013](0013-pull-requests-merge-with-a-merge-commit-or-by-rebasing.md); `/ship-plan` drops the empty `Plan:` and
  `Re-plan step` commits before the branch is first pushed.
- A branch that falls behind `main` takes `main` in by a merge, never a rebase of pushed commits. `/ship-plan` adds that
  merge as a plan step only when it is needed: when the push must fast-forward, when the branch conflicts with `main`,
  or when another plan took its release version.
- A project that releases tags a commit on `main` (`release: tag` or `tag+release`); a release is a tag, not a
  branch.

A long-lived branch is introduced only by a decision of its own, such as a release line that services an older major
version while `main` moves on.

## Options considered

- A long-lived integration branch beside `main`. Rejected: it isolates work that nothing needs isolated from, splits
  history across two branches, and points the host's reporting at an idle default branch.
- Making the integration branch the default branch. Rejected: two branches whose roles cannot be told apart, and
  releases still need a merge between them.
- One trunk with short-lived branches (chosen). It matches how plans branch and land, and the host's defaults describe
  the branch that receives the work.

## Consequences

- CI runs on every push to `main` and on every pull request into it; `main` is always the newest verified state.
- Several plans can be in flight at once, each on its own branch, and each lands independently.
- A branch that lives longer than one change is a smell: split the work into plans that each land on their own.
- A project that later needs to service released versions adds release lines by a new decision; it does not bring
  back an integration branch.

## References

- `AGENTS.md`, Landing section
- [ADR-0003](0003-agent-work-is-planned-on-a-frontier-model-and-executed-on-a-cheaper-one.md): agent work is planned
  on a frontier model and executed on a cheaper one.
- [ADR-0005](0005-the-default-branch-accepts-changes-only-through-pull-requests.md): the default branch accepts changes
  only through pull requests that pass CI.
- [ADR-0013](0013-pull-requests-merge-with-a-merge-commit-or-by-rebasing.md): pull requests merge with a merge commit
  or by rebasing.
