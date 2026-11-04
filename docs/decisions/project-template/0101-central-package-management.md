# 0101. Package versions are managed centrally

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

A solution of several projects references many of the same NuGet packages. When each project file names its own
versions, two concerns are tangled in every `.csproj`: which version of a package the repository uses, and which
projects use it. Versions drift between projects, a consumer of two of the repository's packages can meet a
diamond-dependency conflict, and a dependency bump becomes an edit to many files that is easy to leave half done.

## Decision

Package versions live in one place, `Directory.Packages.props` at the repository root, through NuGet's Central Package
Management.

- `Directory.Packages.props` sets `ManagePackageVersionsCentrally` to `true` and holds one `<PackageVersion>` item per
  package.
- A project's `<PackageReference>` names the package and carries no `Version`. NuGet fails the restore with `NU1008`
  when one does.
- A package every project needs, such as an analyzer, is a `<GlobalPackageReference>` in `Directory.Packages.props`,
  which adds it to every project with its version. The template's banned-API analyzer arrives this way
  ([ADR-0102](0102-disallowed-apis-are-banned-at-build-time.md)).
- `dotnet add package` writes the version to `Directory.Packages.props` already. A `dotnet new` template puts a
  `Version` on each `<PackageReference>`; move each one into a `<PackageVersion>` item before the first build.
- A project that needs a different version of one package overrides it with `VersionOverride` on its reference, with a
  comment saying why. This is the exception, not a pressure valve.
- `CentralPackageTransitivePinningEnabled` is off by default. A project turns it on in `Directory.Packages.props` when
  it needs to force a vulnerable transitive dependency to a patched version from one place.

How the repository's own packages are versioned is a separate decision: release versions come from the plan's
`Release:` line and the tags `/ship-plan` creates.

## Options considered

- Versions on each `<PackageReference>`. Rejected: versions drift across projects, and a bump is an edit to every file
  that names the package.
- A shared `.props` file with `$(PackageNameVersion)` properties. Works, but it reinvents Central Package Management
  without its tooling, its `NU1008` guard or transitive pinning.
- Central Package Management (chosen). It is NuGet's own mechanism: `dotnet add package`, Visual Studio and Dependabot
  all understand it.

## Consequences

- Adding or upgrading a dependency is a one-line change in `Directory.Packages.props`, and every project moves
  together.
- Dependabot proposes each package update once, in the file that holds the version.
- A project scaffolded by `dotnet new` fails its first restore with `NU1008` until its versions move into
  `Directory.Packages.props`.
- `Directory.Packages.props` is a merged file: the template's changes to it merge with the project's packages.

## References

- [Central Package Management](https://learn.microsoft.com/nuget/consume-packages/central-package-management)
- `Directory.Packages.props`
- [ADR-0008](0008-external-inputs-are-pinned-and-kept-current.md): external inputs are pinned exactly and kept current.
