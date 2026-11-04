# 0008. External inputs are pinned exactly and kept current

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

A build depends on inputs the repository does not hold: packages, CI actions, the SDK or runtime, container base images
and the project template itself. A floating reference (a version range, an action's `v4` tag, an image tag, `latest`)
moves when its publisher moves it. Two builds of one commit can then differ, and a compromised or broken release reaches
the build without anyone reviewing it. An action's tag is especially exposed: a tag can be repointed at any commit, and
the action runs with the job's permissions.

Pinning fixes the inputs, but a pin never updates itself. Without something that notices each upstream release, a
pinned project stays on the versions of the day it was pinned and never receives a fix.

## Decision

Every external input is pinned exactly, and on GitHub Dependabot moves the pins in reviewed pull requests.

1. Packages are pinned to exact versions in the file the stack's package manager installs from: for .NET in
   `Directory.Packages.props`, for Node.js in the lockfile CI installs from (`npm ci`, `--frozen-lockfile`), for Python
   with `==` versions in `requirements.txt`.
2. CI actions are pinned to a full commit SHA, with the tag in a comment beside it (`uses: owner/action@<sha> # v7.0.1`),
   so the reference cannot move and a reader and Dependabot both know which release it is.
3. An SDK the stack pins is pinned in its own file, such as the .NET SDK in `global.json`, and CI installs exactly what
   it names.
4. A container base image, when the project adds a Dockerfile, names its tag and the digest of its multi-architecture
   index (`image:tag@sha256:...`). No `ARG` builds a `FROM` line, because Dependabot cannot update one, and the tag
   beside a digest must be the digest's own, since the digest wins. The project adds a `docker` entry for the
   Dockerfile's folder to `.github/dependabot.yml`, ignoring major updates as the .NET SDK entry does (item 7).
5. The template version is pinned in `.copier-answers.yml` and `.template-version`, and moves through
   `.template/Update-Project.ps1`; on GitHub the weekly `template-update` workflow opens an issue when a newer version
   exists.
6. Dependabot runs weekly for every ecosystem the project uses, groups each ecosystem's updates into one pull request,
   gives its security updates a pull request of their own (groups otherwise apply only to version updates), and waits out a three-day cooldown ([ADR-0009](0009-new-dependency-versions-wait-a-cooldown.md)). CI tests the pull
   request and a person merges it ([ADR-0006](0006-a-person-merges-every-pull-request.md)).
7. A major-version move of a runtime or target framework is a planned migration (`/plan-migration`), not a Dependabot
   bump: the .NET SDK's Dependabot entry ignores major updates.

## Options considered

- Floating references. Rejected: builds of one commit differ, and an upstream compromise reaches the build unreviewed.
- Pins without automation. Rejected: the project stays on old versions and misses security fixes.
- One Dependabot pull request per package. Rejected: a dozen pull requests a week for one kind of change; grouping gives
  one review per ecosystem.
- Exact pins moved by Dependabot (chosen).

## Consequences

- A build today matches a build next month, and every input change is a reviewed diff that CI has tested.
- A week's updates arrive as one pull request per ecosystem.
- Pins in merged files, such as the CI workflow, are moved by the project's Dependabot; a template release that moves
  the same pin can conflict on that line, and the newer version wins.
- Some inputs of the template's CI float: the Node.js and Python runtimes follow a release line (`lts/*`, `3.x`), the
  PowerShell job installs the newest Pester and PSScriptAnalyzer, and GitLab CI images use tags such as `python:3`. A
  project that needs one of them fixed pins it in its CI file.
- On GitLab there is no built-in Dependabot, so pins move by hand, and the template-update issue is not opened; a
  project there checks for template updates itself.

## References

- `.github/dependabot.yml`, `.github/workflows/ci.yml`, `.copier-answers.yml`, `.template-version`
- [ADR-0006](0006-a-person-merges-every-pull-request.md): a person merges every pull request.
- [ADR-0009](0009-new-dependency-versions-wait-a-cooldown.md): a new dependency version waits three days before it is
  adopted.
