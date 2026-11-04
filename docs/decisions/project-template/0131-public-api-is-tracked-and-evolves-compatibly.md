# 0131. A published library's public API surface is tracked and evolves backward-compatibly

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

This decision applies to projects published as NuGet packages.

For a shipped library, an accidental change to the public surface (a renamed method, a removed overload, a changed
signature, a flipped nullability annotation) is a breaking change for every consumer, and it is easy to make one
without noticing. Reviewer vigilance does not scale, and nullability and overload removals are the changes reviewers
miss most.

## Decision

The public surface is explicit, visible in every diff, and guarded by an analyzer; after the first stable release it
evolves additively.

- `build/ProjectTemplate.props` references `Microsoft.CodeAnalysis.PublicApiAnalyzers`, with its version in
  `Directory.Packages.props`, in every project whose `IsPackable` is not `false`. Test projects are not packable, and a
  project that is not published sets `IsPackable` to `false`.
- Each packable project keeps `PublicAPI.Shipped.txt` and `PublicAPI.Unshipped.txt` beside its project file, each
  starting with `#nullable enable`. A public symbol that neither file lists fails the build (`RS0016`), and a listed
  symbol that no longer exists fails it (`RS0017`). Without the files, every public symbol fails, and `RS0037` asks for
  `#nullable enable`. With warnings as errors ([ADR-0100](0100-warnings-are-errors-in-every-project.md)), the surface
  cannot drift without a deliberate edit to those files.
- `build/Update-PublicApi.ps1`, template-owned, keeps the files true. It creates missing files, runs
  `dotnet format analyzers --diagnostics RS0016` to add every unlisted symbol to `PublicAPI.Unshipped.txt` (`dotnet
  format` fills an empty file but does not create one), and lists the `RS0017` symbols to delete or mark `*REMOVED*`.
  With `-Release`, in the change that releases a version, it moves the `PublicAPI.Unshipped.txt` entries into
  `PublicAPI.Shipped.txt`, applying the `*REMOVED*` lines.
- The template's `Adopt-Project.ps1` runs it when it verifies an adopted library's build, so the API at adoption is
  the baseline.
- Before 1.0, the whole surface may stay in `PublicAPI.Unshipped.txt`, so every change is visible while the surface may
  still break. At 1.0 it moves to `PublicAPI.Shipped.txt`.
- After the first stable release, a shipped surface evolves backward-compatibly:
  - additions only; a new overload instead of a changed signature;
  - required inputs as constructor parameters, optional inputs as `init` properties, never a new constructor
    parameter;
  - enum members appended, never renumbered, when the value crosses a wire or is persisted;
  - removal by `[Obsolete]` first, then deletion in the next major version.
- A breaking change is a major version. How the version number and the assembly version follow these rules is
  [ADR-0136](0136-packages-follow-semantic-versioning-and-the-assembly-version-moves-only-with-the-major.md).

## Options considered

- Rely on code review. Rejected: people miss surface changes.
- Track the surface with the analyzer (chosen). The diff of `PublicAPI.*.txt` puts every surface change in front of the
  reviewer, and the build keeps the files true.

## Consequences

- A public change that the files do not record fails the build where it is made; `./build/Update-PublicApi.ps1`
  records it, and the result is a small, obvious diff.
- Reviewing a pull request includes reviewing the `PublicAPI.*.txt` diff.
- An adopted library starts from its API at adoption, recorded in bulk once; from then on only changes show.
- A new packable project fails its build until `./build/Update-PublicApi.ps1` creates and fills its files, or until
  it sets `IsPackable` to `false`.
- The change that releases a version runs the script with `-Release`, so `PublicAPI.Shipped.txt` always holds what the
  last release shipped.

## References

- `build/ProjectTemplate.props`, `build/Update-PublicApi.ps1`, `Directory.Packages.props`
- [PublicApiAnalyzers](https://github.com/dotnet/roslyn-analyzers/blob/main/src/PublicApiAnalyzers/PublicApiAnalyzers.Help.md)
- [.NET library guidance: breaking changes](https://learn.microsoft.com/dotnet/standard/library-guidance/breaking-changes)
- [ADR-0100](0100-warnings-are-errors-in-every-project.md): warnings are errors in every project.
- [ADR-0134](0134-evolving-optional-parameters-are-a-dto.md): a growing set of optional criteria is an init-only DTO.
- [ADR-0136](0136-packages-follow-semantic-versioning-and-the-assembly-version-moves-only-with-the-major.md): packages
  follow Semantic Versioning, and the assembly version moves only with the major.
