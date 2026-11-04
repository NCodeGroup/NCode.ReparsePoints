# 0135. Packages are published from a GitHub release through trusted publishing

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

A library's packages reach nuget.org from somewhere, and that path decides three things: which commit a published
version was built from, who or what can publish, and what an attacker gains by compromising the build.

- A version on nuget.org is permanent. It can be unlisted, never replaced, so a package published from the wrong commit
  or with the wrong version stays there.
- The usual credential is a long-lived API key in a repository secret. It lives for months, any workflow step that can
  read secrets can leak it, it must be rotated by hand, and when it expires the next release fails.
- Building a .NET project runs code the repository does not own: MSBuild tasks, analyzers and source generators from
  packages, and the test suite's dependencies. A job that builds and also holds a publishing credential hands that
  credential to every one of them.
- The project's releases already have one deliberate step: with `release: tag+release` in `AGENTS.md`'s Landing
  section, `/ship-plan` tags the merged commit with the plan's version and publishes a GitHub release from that
  version's changelog section.

nuget.org trusted publishing lets a GitHub Actions job exchange its OIDC token for an API key that is valid for about
an hour and is scoped by a policy to one repository and workflow file.

## Decision

A published GitHub release publishes the packages, through `.github/workflows/publish.yml` and nuget.org trusted
publishing, with no long-lived API key.

1. The trigger is a published release. The workflow runs on `release: published`, never on a push or a merge, so
   publishing follows the same deliberate act that publishes the release notes.
2. The version is the release tag. The tag must be a version, `v1.2.3` or `v1.2.3-rc.1`, and the leading `v` is
   dropped: `v1.2.3` packs `1.2.3`. There is no version file to bump and forget, and the package, the tag, the release
   and the changelog section all name one version.
3. Two jobs. `pack` checks out the tagged commit with read-only permissions and no credential, runs the tests and
   `dotnet pack` in Release with `-p:Version=<version>`, and uploads the `.nupkg` and `.snupkg` files. `publish` runs
   no build code: in the protected `nuget` environment, with only `id-token: write`, it downloads the packages,
   exchanges the job's OIDC token for a short-lived key with `NuGet/login`, and runs `dotnet nuget push
   --skip-duplicate`, which also pushes each symbol package beside its package.
4. One publication at a time. A second run waits for the first instead of racing it to nuget.org.

The maintainer sets up once:

- on nuget.org, a trusted publishing policy for the repository and the workflow file `publish.yml`, owned by the
  account that owns the package IDs;
- in the repository, the `nuget` environment with required reviewers, so a person approves each publication, and the
  repository variable `NUGET_USER` naming that nuget.org account;
- in `AGENTS.md`'s Landing section, `release: tag+release`, so `/ship-plan` publishes the release that triggers the
  workflow.

## Options considered

- A long-lived API key in a secret. Rejected: it outlives every job that uses it, leaks with any step that can read
  secrets, and expires on its own schedule.
- One job that builds and pushes. Rejected: build-time code from any package would run beside the publishing
  credential.
- Publishing on every merge to the default branch, with a computed version. Rejected: nuget.org versions are permanent,
  and a version per merge buries the ones consumers need.
- A version in a file such as `Directory.Build.props`. Rejected: a second source of truth that drifts from the tag.
- Publishing from a release through trusted publishing (chosen).

## Consequences

- No secret holds a nuget.org key, and nothing needs rotating; a leaked short-lived key expires within the hour.
- Each publication waits for an approval in the `nuget` environment.
- A tag that is not a version fails the `pack` job, and nothing is published.
- `pack` fails when a package doesn't carry the tag's version, as when a project sets its own `Version`, and `publish`
  fails when every package is already on nuget.org at that version, so a release that would publish nothing never looks
  like a success. A run that failed part way is run again: `--skip-duplicate` skips the packages already pushed, and
  the job summary says how many it pushed. A published version cannot be replaced; a bad release is fixed by the next
  version.
- `publish.yml` is project-owned: template updates never change it, and Dependabot moves its action pins. A project
  that publishes from a workflow of its own deletes it and records that in its own decision record.
- On GitLab the template generates no publishing pipeline; a project there publishes from a pipeline of its own and
  records how in its own decision record.

## References

- `.github/workflows/publish.yml`, `AGENTS.md` Landing section, `build/ProjectTemplate.props`
- [nuget.org trusted publishing](https://learn.microsoft.com/nuget/nuget-org/trusted-publishing)
- [GitHub Actions OIDC](https://docs.github.com/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [GitHub Actions deployment environments](https://docs.github.com/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [ADR-0006](0006-a-person-merges-every-pull-request.md): a person merges every pull request.
- [ADR-0130](0130-source-link-and-symbol-packages.md): packages are source-linked and ship symbol packages.
