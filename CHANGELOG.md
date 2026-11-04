# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- The repository is under the NCodeGroup project template: GitHub Actions CI (build, test, commit attribution), Dependabot, an NCode Review workflow, a publishing workflow, agent instructions, `CONTRIBUTING.md`, `SECURITY.md` and architecture decision records.
- The public API of `NCode.ReparsePoints` is tracked in `PublicAPI.Shipped.txt`, so the build fails on an unrecorded public change.
- Source Link and a symbols package for `NCode.ReparsePoints`.

### Changed

- The projects are SDK-style and still target .NET Framework 4.5.1 (the tests target .NET Framework 4.8). The solution moved to the repository root and the test project to `tests/`.
- The tests moved from NUnit 2.6.4 to NUnit 3.14.0 and run with `dotnet test`.
- The package's metadata (license expression, readme, icon, repository) comes from the project instead of a nuspec; the license expression is `Apache-2.0`.
- `ReparseLink.Target` is annotated as nullable: it is `null` for hard links, as its documentation always said. No runtime behavior changes.
- Argument-validation and diagnostic messages are formatted with the invariant culture, and the trailing-backslash check on DOS device paths compares ordinally.

[Unreleased]: https://github.com/NCodeGroup/NCode.ReparsePoints/compare/v1.0.6...HEAD
