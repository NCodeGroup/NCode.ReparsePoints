# 0006. A person merges every pull request; an agent never does

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

The default branch takes changes only through pull requests
([ADR-0005](0005-the-default-branch-accepts-changes-only-through-pull-requests.md)), and agents open many of them:
`/ship-plan` lands a reviewed plan, `/run-issues` opens one per issue, and `/address-feedback` pushes fixes to an open
one. In a repository with one maintainer, the host does not let the author approve their own pull request, so the
author's review cannot be a formal approval; the merge itself is the approval.

If an agent can merge, mark a pull request ready or turn on auto-merge, the pull request can merge while its author is
still reviewing it: once the checks pass and no conversation is open, nothing waits for the person.

## Decision

A person decides every merge. An agent opens and updates pull requests, and never merges one, marks it ready for review,
turns on auto-merge, resolves a review thread, dismisses a review or force-pushes its branch.

1. `/ship-plan` opens the pull request as the Landing section's `draft` key says: ready for review by default
   (`draft: no`), or as a draft with `draft: yes` or `/ship-plan draft`. `/run-issues` always opens drafts.
2. The author reviews. Requesting changes is a comment left as an unresolved review thread, which the ruleset's
   conversation rule keeps from merging. Approving is resolving every thread, marking a draft ready, and merging, or
   turning on auto-merge with the merge method
   [ADR-0013](0013-pull-requests-merge-with-a-merge-commit-or-by-rebasing.md) sets; those are the author's actions.
3. `/run-issues` answers review feedback and fixes the review bot's findings that hold, then recommends the merge after
   `max-review-rounds` rounds, or a round of only minor findings; the person merges.
4. After the merge, the next `/ship-plan` tags the release when the Landing section asks for one and closes any of the
   plan's issues still open, and `/finish-plan` cleans up.

A project with `integrate: direct` has no pull request to merge: `/ship-plan` pushes to the default branch only after
asking the person once, which keeps the same decision with the person.

### One exception: Dependabot's NCode Review pin bump

At the maintainer's request ([NCodeGroup/code-review#33](https://github.com/NCodeGroup/code-review/issues/33)), one
workflow turns on auto-merge: `.github/workflows/code-review-auto-merge.yml`. Its scope is narrow. It acts only on a
pull request that Dependabot opened from the repository itself, whose only change is the
`uses: NCodeGroup/code-review@<full commit SHA> # vX.Y.Z` line of a workflow, moving it to a minor or patch release, and
the pull request merges only after the checks the default branch requires pass, by the first merge method that both
the repository's settings and the branch's rules allow: a merge commit, else a rebase, else a squash.

The rule exists so that nothing merges while its author is still reviewing it, over a review thread no person read.
That reason doesn't hold here: the change is a pin to a release whose code was itself reviewed and merged by a person
in NCodeGroup/code-review, so the bump brings no change nobody reviewed. The review bot doesn't review a pull request a
bot opened unless someone asks with `/review`, and any thread on it, a person's or the bot's, still keeps it from
merging until it is resolved, as the ruleset requires. A major release, which can change the inputs the caller passes,
a pull request that updates anything else, and every other pull request are still merged by a person.

## Options considered

- An agent opens the pull request ready and turns on auto-merge. Rejected: it can merge before the author has
  reviewed.
- Every pull request a draft. Available with `draft: yes`; not the default, because a ready pull request that only a
  person can merge already keeps the merge with the person, and a draft adds a click to every change.
- A second account that approves. Rejected: it is a ritual the author performs on themselves, and a host's terms may not
  allow a second personal account for it.
- Require one approving review. Rejected while there is one maintainer: it cannot be met.

## Consequences

- No agent's change reaches the default branch without a person's explicit action. The one change that merges without
  one is a minor or patch bump of the NCode Review pin, which a person already reviewed as that release.
- Opening and merging are two steps, and the person may batch reviews; `/continue-plan` shows where each open plan
  stands and the command to run next.
- Auto-merge, once the person turns it on, merges as soon as the checks pass; a person who wants to look again first
  turns it off.

## References

- `AGENTS.md` Landing section: `draft`, `review-bots`, `max-review-rounds`
- [ADR-0002](0002-commits-are-attributed-to-people-not-agents.md): commits are attributed to people, not agents.
- [ADR-0005](0005-the-default-branch-accepts-changes-only-through-pull-requests.md): the default branch accepts changes
  only through pull requests that pass CI.
- [ADR-0013](0013-pull-requests-merge-with-a-merge-commit-or-by-rebasing.md): pull requests merge with a merge commit
  or by rebasing.
- [ADR-0014](0014-every-pull-request-discussion-is-remediated-and-replied-to-before-it-merges.md): every pull request
  discussion is remediated and replied to before it merges.
