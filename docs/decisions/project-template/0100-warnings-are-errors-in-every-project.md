# 0100. Warnings are errors in every project, including tests

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

A build that always prints warnings trains everyone, people and agents, to stop reading them. The warnings that then
go unread include the ones that matter: nullable dereferences, analyzer findings, and NuGet vulnerability advisories
(`NU1901` to `NU1904`).

Test projects are the usual exemption, on the grounds that they are never shipped. That is the wrong criterion.
Warnings in tests are disproportionately correctness defects: the xUnit analyzers report unused theory parameters,
`null` passed to a value-type parameter and assertions that cannot fail, and a silently broken test stops protecting
the code it covers. An agent executing a plan step also reads a clean build as success; a standing pile of warnings
hides the one its change introduced.

## Decision

Every project in the repository builds with zero warnings. The criterion is code the project maintains, not code it
ships.

The template's shared build settings, `build/ProjectTemplate.props`, imported by `Directory.Build.props`, apply to every
project, test projects included:

- `TreatWarningsAsErrors` is on. No project sets it back to `false`.
- `AnalysisLevel` is `latest-recommended`, so the .NET analyzers' recommended rules report, and move with the SDK.
- `EnforceCodeStyleInBuild` is on, so the code-style rules (`IDE*`) that `.editorconfig` raises to warning fail the
  build, not only the editor.
- `build/ProjectTemplate.globalconfig` sets the template's own analyzer severities, such as unused `using` directives
  (`IDE0005`) as a warning. Roslyn reports `IDE0005` in a build only when it generates XML documentation, so the
  template generates it for every project, tests included, and suppresses the missing-comment warning `CS1591` in
  test projects and unless the project publishes packages.
- Analyzers turn two more mistakes into warnings, and so into errors: the null-forgiving operator `!` outside test
  projects ([ADR-0118](0118-the-null-forgiving-operator-is-banned-outside-tests.md)), and, in a project that publishes
  packages, a public API change its `PublicAPI.*.txt` files do not record (ADR-0131).
- NuGet advisories are errors when `CI` is `true`. A local build reports them as warnings, so an advisory published
  overnight does not stop a person or an agent from building unchanged code, while CI refuses to merge it.

When a warning appears, the remedies are, in order:

1. Fix the code. This is the default, and the right answer almost every time.
2. Lower one rule's severity for a set of files in `.editorconfig`, such as for `[tests/**/*.cs]`, with a comment that
   says why the rule is noise there. `.editorconfig` overrides the template's global configuration. This is for a rule
   that is right for production code and wrong for tests.
3. A tight `#pragma warning disable` and `restore` around one site, with a comment that gives the reason, when the rule
   should stay live everywhere else.

A project-wide `NoWarn` or `WarningsNotAsErrors` is not a pressure valve. A rule turned off for the whole project needs
a stated reason, as a severity in `.editorconfig` or, failing that, in `Directory.Build.props` after the import of the
template's settings. The template's own list for `*.Tests` projects is such a list, in
`build/ProjectTemplate.Tests.globalconfig` with a reason per rule: `CS1591`, since tests document behavior through their
names, `CA1707`, since test method names use underscores, and `CA1816`, `CA1859`, `CA1861` and `CA1869`, which guard
production performance or disposal patterns that do not apply to tests. `.editorconfig` can turn any of them back on.

## Options considered

- Warnings as errors for shipped projects only. Rejected: test warnings are the ones most likely to hide a broken test,
  and the exemption grows a standing pile of warnings nobody reads.
- Warnings as errors in CI only. Rejected: a build that passes locally and fails in CI costs a round trip, and an agent
  checks its step against the local build. NuGet advisories are the one exception, because they change without any
  change to the code.
- Zero warnings in every project (chosen). A new warning fails the build where it is introduced.

## Consequences

- A new warning anywhere breaks the build at once, so analyzer findings surface against a clean baseline.
- Relaxing a rule means naming it and writing down why, so the exceptions stay reviewable.
- A NuGet vulnerability advisory published for a package the project already uses fails CI for unchanged code. The fix
  is a package update, usually Dependabot's; a project that must merge before a fixed version exists suppresses that one
  advisory with `NuGetAuditSuppress` and a comment, and removes the suppression when it updates.
- A new SDK or analyzer version can add warnings, since `latest-recommended` follows the SDK. Moving the SDK is a
  reviewed change (Dependabot or a planned migration), so the fixes land in the same change.

## References

- `build/ProjectTemplate.props`, `build/ProjectTemplate.globalconfig`, `Directory.Build.props`, `.editorconfig`
- `.github/instructions/csharp.instructions.md`, `.github/instructions/csharp-tests.instructions.md`
- [Code analysis in .NET](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview)
- [NuGet audit](https://learn.microsoft.com/nuget/concepts/auditing-packages)
- [ADR-0102](0102-disallowed-apis-are-banned-at-build-time.md): disallowed APIs are banned at build time.
- [ADR-0118](0118-the-null-forgiving-operator-is-banned-outside-tests.md): the null-forgiving operator is banned outside
  tests.
