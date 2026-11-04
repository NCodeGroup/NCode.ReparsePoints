# 0130. Packages are source-linked and ship symbol packages

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

Consumers of a published library want to step into the exact source of the version they use when they debug, and to
trust that a package was built deterministically from a known commit. The .NET SDK includes Source Link, which records
in each PDB where every source file can be fetched from the repository host, and nuget.org runs a symbol server for
`.snupkg` symbol packages.

There are two ways to get source to a debugger: point the PDB at the host, or embed the source in the PDB. Pointing at
the host keeps packages small, but it needs the host to serve the file to whoever debugs; embedding works offline and
behind authentication, but every package carries its whole source.

## Decision

A project that publishes NuGet packages ships deterministic, source-linked builds with a portable symbol package, and
embeds only the source files that have no URL on the host. The template's build settings for packages, which the
`nuget_package` answer turns on in `build/ProjectTemplate.props`, set:

- `PublishRepositoryUrl`, so each package names the repository it was built from, and the SDK's Source Link maps
  every tracked source line to a URL on the host.
- `EmbedUntrackedSources`, so generated files that are not in Git, such as assembly info, are embedded and stepping
  into them still works. Tracked sources are not embedded.
- `IncludeSymbols` with `SymbolPackageFormat` `snupkg`, so each `.nupkg` has a companion `.snupkg` for the symbol
  server.
- `ContinuousIntegrationBuild` whenever `CI` is `true`, so CI output is deterministic and its paths are normalized.
- A license expression, a README (the project's own `README.md`, or the repository's when it has none) and, when the
  template was given one, an icon in every package, so the package page describes it.
- XML documentation, with the missing-comment warning `CS1591` left on, so every public member is documented and
  IntelliSense shows it.

Projects whose names end in `.Tests` are not packable and need no XML comments (`CS1591` is off there), but they still generate the documentation file, so `IDE0005` reports unused usings in their build too.

## Options considered

- No Source Link and no symbols. Rejected: consumers cannot step into the code, and nothing ties a package to its
  commit.
- Embed all sources in the PDB inside the main package. The right choice when the source host needs authentication,
  because a debugger's fetch would fail there. Rejected as the default: for a public repository it bloats every package
  for nothing.
- Source Link with a symbol package (chosen). The main package stays small, symbols follow nuget.org's standard symbol
  server path, and stepping into a public repository needs no setup.

## Consequences

- Consumers debug into the tagged source with no configuration beyond enabling Source Link and the nuget.org symbol
  server in their debugger.
- Publishing pushes each `.snupkg` with its `.nupkg`.
- A public member without an XML comment fails the build, since warnings are errors
  ([ADR-0100](0100-warnings-are-errors-in-every-project.md)).
- A private repository needs a different trade: a debugger cannot fetch its source without credentials. Such a project
  sets `EmbedAllSources` in `Directory.Build.props`, after the import of the template's settings.
- A package built outside CI keeps the machine's local paths in its PDB, so the packages a project publishes come from
  a CI build.

## References

- `build/ProjectTemplate.props`, `Directory.Build.props`
- [Source Link](https://learn.microsoft.com/dotnet/standard/library-guidance/sourcelink)
- [Symbol packages (.snupkg)](https://learn.microsoft.com/nuget/create-packages/symbol-packages-snupkg)
- [ADR-0100](0100-warnings-are-errors-in-every-project.md): warnings are errors in every project.
