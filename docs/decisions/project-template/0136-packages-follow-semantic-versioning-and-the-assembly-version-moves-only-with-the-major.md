# 0136. Packages follow Semantic Versioning, and the assembly version moves only with the major

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

This decision applies to projects published as NuGet packages.

A package's version is a promise to its consumers: it tells them whether an upgrade is safe to take without reading the
code. That promise holds only when the number follows rules that every release keeps, and when the rules for evolving
the API are the ones the number expresses.

.NET carries a second version, the assembly version, which the runtime binds against. When it changes with every
release, an application that gets two packages compiled against different minor versions of a library needs binding
redirects on .NET Framework, and a minor upgrade is not a drop-in replacement. When it never changes, two major
versions with incompatible APIs cannot be told apart and cannot load side by side.

## Decision

A library's packages follow Semantic Versioning 2.0, and their assembly version moves only with the major version.

### The version number

- The version comes from the release tag, `v1.2.3`, or `v1.2.3-rc.1` for a prerelease. On GitHub,
  `.github/workflows/publish.yml` packs the tag's version (ADR-0135).
- A breaking change is a major version. So is a change to validation or security behavior that a consumer can observe,
  even when no signature changes.
- An addition is a minor version; a fix is a patch.
- Removal goes through `[Obsolete]` in a minor version and deletion in the next major.
- A release tag is never moved or deleted: one tag, one published set of packages. A published version is never
  replaced; a bad release is fixed by the next version.
- A release candidate gates a major version. Minor and patch versions ship directly.
- Before 1.0.0, a breaking change may land in a minor version, as Semantic Versioning allows for `0.y.z`, but the
  changelog still calls it out.
- The changelog is `CHANGELOG.md`, in the Keep a Changelog format. Every plan's last step writes its section, and
  `/ship-plan`, with `release: tag+release` in `AGENTS.md`'s Landing section, tags the merged commit with the plan's
  version and publishes the release from that section.

### The assembly version

When a project does not set `AssemblyVersion` itself, an MSBuild target in `build/ProjectTemplate.props` derives the
assembly's versions from the final `Version`:

- `AssemblyVersion` is `<major>.0.0.0`;
- `FileVersion` is the exact `major.minor.patch`;
- `InformationalVersion` keeps the full version.

`Version` `2.5.0-rc.1` gives `AssemblyVersion` `2.0.0.0`, `FileVersion` `2.5.0` and `InformationalVersion`
`2.5.0-rc.1`. It is a target, not a property, so a `Version` set in the project file or on the command line, as
publishing passes the tag's, counts. A minor or patch upgrade is then a drop-in replacement with no binding redirect,
and different major versions load side by side.

### The compatibility rules the number expresses

A minor or patch version keeps every consumer compiling and running. The public API evolves by these rules, and the
public surface is tracked so that every change to it is visible
([ADR-0131](0131-public-api-is-tracked-and-evolves-compatibly.md)):

- Add, don't change: a new overload rather than a changed signature.
- Required inputs are constructor parameters; optional inputs are `init` properties. A new optional constructor
  parameter is a binary-breaking change ([ADR-0134](0134-evolving-optional-parameters-are-a-dto.md)).
- A configuration callback takes one options type that can grow.
- Members of a wire format or an enum are appended, never renumbered or reordered, and persisted by name.
- Deprecate, then remove across a major: `[Obsolete]` first, deletion in the next major.
- One type is never shared between two packages that version independently.
- Nullability is part of the signature: `string` to `string?` on the public surface is a tracked, potentially breaking
  change.

A pull request that touches the public API is reviewed against this checklist:

- it adds rather than alters;
- optional inputs are `init` properties;
- removals go through `[Obsolete]` across a major;
- the `PublicAPI.Unshipped.txt` diff is in the pull request and intended;
- a removal or a changed signature bumps the major version.

## Options considered

- A version chosen by hand per release, with no stated rules. Rejected: consumers cannot tell a safe upgrade from a
  breaking one.
- A computed version per commit. Rejected: published versions are permanent, and a version per commit buries the ones
  consumers need.
- `AssemblyVersion` equal to the full version. Rejected: every minor or patch upgrade changes the binding identity, so
  it needs binding redirects on .NET Framework and is not a drop-in replacement.
- A fixed `AssemblyVersion` for every release. Rejected: incompatible major versions share one identity and cannot load
  side by side.
- Semantic Versioning from the release tag, with the assembly version pinned to the major (chosen).

## Consequences

- A consumer reads the version and knows whether an upgrade can break them; the changelog says how.
- The tag, the package, the release and the changelog section name one version, and there is no version file to forget.
- A minor or patch upgrade replaces the assembly in place; a major upgrade is a new identity.
- A change in observable validation or security behavior is a major version even when the API diff is empty, so the
  review asks about behavior, not only signatures.
- A project that sets `AssemblyVersion` itself opts out of the pinning and owns the consequences.
- The 1.0.0 release is the point where the compatibility rules start to bind, and the point where the tracked surface
  moves to `PublicAPI.Shipped.txt`.

## References

- `build/ProjectTemplate.props`, `CHANGELOG.md`, `AGENTS.md` Landing section: `release`, `changelog`
- [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html)
- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
- [.NET library guidance: versioning](https://learn.microsoft.com/dotnet/standard/library-guidance/versioning)
- [.NET library guidance: breaking changes](https://learn.microsoft.com/dotnet/standard/library-guidance/breaking-changes)
- [ADR-0131](0131-public-api-is-tracked-and-evolves-compatibly.md): the public API surface is tracked and evolves
  backward-compatibly.
- [ADR-0134](0134-evolving-optional-parameters-are-a-dto.md): a growing set of optional criteria is an init-only DTO.
