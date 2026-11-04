# NCode.ReparsePoints

Create and inspect Win32 file and folder reparse points such as hard links, junctions and symbolic links.

Instructions for every coding agent in this repository. This file is an index: read each file it lists, in order, then the sections below. Where the project's instructions differ from the template's, the project's win. Claude Code reads this file through `CLAUDE.md` and imports each `@` file. GitHub Copilot reads it directly and loads every `.github/instructions/*.instructions.md` file on its own.

This file belongs to the project: template updates never change it. Keep it under 200 lines; put anything longer in a listed file.

## Instructions

- @.github/instructions/project-template.instructions.md — the plan-then-execute workflow and base conventions, from the project template. Template updates replace it; never edit it. To change one of its rules, override it below or in a listed file.
- `.github/instructions/csharp.instructions.md` — C# conventions, from the project template; read it before editing `.cs` files.
- `.github/instructions/csharp-tests.instructions.md` — C# test conventions, from the project template; read it too before editing a test project's `.cs` files.
- `docs/decisions/` — this project's architecture decision records, and in `project-template/` the template's; read the ones a change touches before deciding otherwise.
- Project instruction files: add one line for each, `@<path> — what it covers`.

## Commands

Run from the repository root in PowerShell 7.

- Build: `dotnet build`
- Test: `dotnet test`
- Definition of Done: `./build/dod.ps1` (the full gate CI runs) or `./build/dod.ps1 -Fast` (Debug, no pack); it ends with `Definition of Done: PASSED`. Record a public API change with `./build/Update-PublicApi.ps1`

## Landing

How `/ship-plan` lands a reviewed plan. `integrate`: `pull-request` pushes the plan's branch and opens a pull request; `direct` pushes to the default branch. `release`: `none`; `tag` tags the plan's `Release:` version, or the next free one when another plan landed it first; `tag+release` also publishes a release from that version's section of `changelog`. `changelog`: the file every plan's last step writes, in the Keep a Changelog format, `CHANGELOG.md` by default. `draft`: `no`, the default, which a template update never changes, so a project lands as it did; `yes` opens every pull request as a draft, as `/ship-plan draft` does, and `/run-issues` opens its pull requests as drafts either way. `follow-ups`: `issues` files a plan's follow-ups as issues in this repository; `<owner/repo>` files them in that repository; `none` files none, and `/ship-plan` lists them for you to record. `follow-up-label`: the label those issues get, `follow-up` by default; write a name with spaces as it is, such as `tech debt`. `gate`: `none`; a command, such as `./build/dod.ps1 -Fast`, that `/ship-plan` and `/run-issues` run from the repository root before each push, stopping when it exits non-zero or changes a file. `protect`: `none`; `hook` makes `.githooks/pre-push` refuse any push to the default branch, for a host that can't require pull requests, such as a private repository on GitHub Free. `pr-format`: `none`; `<file>#<heading>`, such as `AGENTS.md#Pull requests`, names the section that sets the title and description of the pull requests `/ship-plan` opens, which still end with their `Closes` lines. `review-bots`: the review bots, by login and separated by commas, whose findings `/run-issues`, `/address-feedback` and `/run-feedback` may fix, `ncode-review` by default, or `none`; `/run-issues` acts only on NCode Review's `blocker` and `should-fix` findings, and neither ever fixes a bot's finding on CI, the template, agent configuration, the build or the dependencies. `max-review-rounds`: `3`; after that many rounds of review feedback on a pull request, `/run-issues` and `/run-feedback` recommend the merge, and `/run-issues` leaves the bots' further findings as follow-ups. `prelude`: `none`; one PowerShell command that sets up the shell the workflow's commands run in, such as `./build/env.ps1`, a script in the repository, or `nvs use 26`, to put a tool installed through a version manager on `PATH`. `/ship-plan` and `/run-issues` run it before the gate, and executors and coordinators before each Done-when command, dot-sourced in the same PowerShell; a plan names it under Context for the executor, so no step repeats it. When it fails, they stop and show its error. Write it on one line, without a leading `. ` or `& ` operator, a `#` comment, or `;`, `|`, `&`, `&&` or `||`; `.template/Get-PlanState.ps1` prints any other value as `prelude=invalid`, and `/ship-plan` stops on it. `/run-issues` runs only when the host requires pull requests into the default branch, or `protect` is `hook` and the hooks are enabled.

- integrate: pull-request
- release: tag+release
- changelog: CHANGELOG.md
- draft: no
- follow-ups: issues
- follow-up-label: follow-up
- gate: ./build/dod.ps1 -Fast
- protect: none
- pr-format: none
- review-bots: ncode-review
- max-review-rounds: 3
- prelude: none

## Conventions

- The library wraps Win32 reparse-point APIs (hard links, junctions, symbolic links) through P/Invoke, so it runs only on Windows. `NCode.ReparsePoints` targets .NET Framework 4.5.1; its tests (NUnit 3, `tests/NCode.ReparsePoints.Tests`) create real links on disk and target .NET Framework 4.8, so they run only on Windows. `dotnet test` and `./build/dod.ps1` fail on Linux and macOS at the test stage; CI runs them on `windows-latest`.
- `src/NCode_cReparsePoints` is a PowerShell DSC resource (with its module in `src/cReparsePoints`), not part of the package: it is not packable and is exempt from the XML documentation rule (CS1591) and the underscore-in-name rule (CA1707), because PowerShell finds the resource by that name.
- The public API of `NCode.ReparsePoints` follows Semantic Versioning and is recorded in `src/NCode.ReparsePoints/PublicAPI.Shipped.txt`; record a change with `./build/Update-PublicApi.ps1`. The Win32 access-right enums list the SDK's aliases (equal values) on purpose, so CA1069 is off for `src/NCode.ReparsePoints/Win32/Enums.cs`.
- The default branch is `master`. `.github/workflows/ci.yml` is project-owned (`project_owned_files` in `.copier-answers.yml`) because the template's copy runs on Linux and watches `main`; keep it on `windows-latest` and `master`, and compare it with the template's copy on each template update.
