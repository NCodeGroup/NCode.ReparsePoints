# 0009. A new dependency version waits three days before it is adopted

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

A compromised or broken package release is usually found and withdrawn within hours to days of its publication.
Waiting before adopting a new version, a release-age gate or cooldown, keeps most such releases out of a project at
little cost: dependency updates arrive weekly, so a few days' wait delays almost nothing.

Two kinds of tool resolve versions. Dependabot proposes updates, and its `cooldown` setting delays a version until it
is old enough. Some package managers have a gate of their own for versions a person resolves, such as pnpm's
`minimumReleaseAge`. When the two gates disagree, a person can lock a version that Dependabot's resolution then
rejects, and Dependabot's updates fail until that version ages.

## Decision

A new version of a dependency or CI action is adopted only once it is at least three days old.

1. Dependabot states the window. Every ecosystem in `.github/dependabot.yml` sets `cooldown: default-days: 3`, rather
   than relying on Dependabot's default, so a change to the default does not change the project.
2. A package manager's own gate, where the project turns one on, is never shorter than Dependabot's window, so a
   version a person locks is one Dependabot also accepts.
3. A version needed before it is three days old, such as a fix that does not arrive as a Dependabot security update,
   is adopted by an explicit, commented exception, removed once the version ages. Dependabot's security updates are not
   delayed.

## Options considered

- No cooldown (`default-days: 0`). Rejected: it removes a supply-chain control for a few days' freshness.
- Rely on Dependabot's default without stating it. Rejected: the window could change with no change in the repository.
- A longer window. Not chosen: three days covers most withdrawals, and a longer one delays fixes more than it protects.
- A stated three-day window (chosen).

## Consequences

- A weekly Dependabot pull request carries only versions at least three days old.
- A person who adds a package through a package manager with a gate gets the newest version that is old enough, and an
  explicit request for a newer one fails until the exception is written.
- Projects on GitLab have no Dependabot; the window applies to the versions people choose there by hand.

## References

- `.github/dependabot.yml`
- [Dependabot `cooldown`](https://docs.github.com/code-security/dependabot/working-with-dependabot/dependabot-options-reference)
- [ADR-0008](0008-external-inputs-are-pinned-and-kept-current.md): external inputs are pinned exactly and kept current.
