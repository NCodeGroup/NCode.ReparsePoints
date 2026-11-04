# 0117. One Definition of Done gates every change

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

"Done" is checked in several places: a person runs a build before pushing, an agent verifies a plan step, `/ship-plan`
and `/run-issues` check the work before each push, and CI checks every pull request. When each of them runs its own
commands, they drift. A step passes locally and fails in CI because CI also packs, or restores tools, or builds in
Release; an agent declares success on a Debug build that never ran the analyzers the way CI does; and nobody can say in
one sentence what a change must pass.

A gate is only useful when its result is unambiguous. A script that prints a wall of output and leaves the reader to
judge whether it passed invites an agent to read success into a failure.

## Decision

`build/dod.ps1` is the Definition of Done: one gate, template-owned, run the same way by people, agents and CI.

1. It runs these stages in order and stops at the first failure, naming the stage that failed:
   - Tools: `dotnet tool restore`, when `.config/dotnet-tools.json` exists.
   - Decisions: `.template/Test-AdrIndex.ps1`, which checks that `docs/decisions/README.md` indexes every `NNNN-*.md`
     record and links none that is missing.
   - Build: Release, with warnings as errors, the analyzers and the banned APIs
     ([ADR-0100](0100-warnings-are-errors-in-every-project.md),
     [ADR-0102](0102-disallowed-apis-are-banned-at-build-time.md)), and, for a library, its tracked public API
     (ADR-0131).
   - Test: `--no-build`; `-Filter` narrows the tests run.
   - Pack: for a library only, into `artifacts/packages`, with symbol packages (ADR-0130).
2. Its last line is `Definition of Done: PASSED`, and it exits 0. Scripts test the exit code, not the output.
3. `-Fast` builds in Debug and does not pack: the local gate.
4. A repository with no solution at its root yet passes, with a note saying so.
5. CI's build-and-test job runs `./build/dod.ps1` for a .NET project whose build and test commands are the defaults,
   `dotnet build` and `dotnet test`. A project with commands of its own keeps them.
6. A new .NET project's `AGENTS.md` Landing section sets `gate: ./build/dod.ps1 -Fast`, which `/ship-plan` and
   `/run-issues` run before each push.

No formatter check is in the gate. The formatting style that matters is enforced by the analyzers in the build, with
`EnforceCodeStyleInBuild`, and the template does not pick a formatter such as CSharpier. `dod.ps1` is template-owned and
never edited: a project that adopts a formatter, or needs any other stage, adds it as a tool and wraps `dod.ps1` in a
script of its own that runs the extra stage, and names that script as its gate.

## Options considered

- Each place runs its own commands. Rejected: they drift, and a change passes one check and fails the next.
- The gate in CI only. Rejected: a failure found in CI costs a round trip, and an agent verifies its work locally.
- A formatter stage in the template's gate. Rejected: the template would choose a formatter for every project, and the
  style rules that matter already fail the build.
- One script with named stages, a fixed last line and an exit code (chosen). The same command answers "is this done?"
  everywhere.

## Consequences

- What a change must pass is one file, and "it passed the gate" means the same on a laptop, in an agent's session and
  in CI.
- A failure names its stage, so a person or an agent knows where to look without reading the whole log.
- The local gate skips Release and packing to stay fast; CI runs the full gate, so a change that passes `-Fast` can
  still fail there, rarely.
- A template update that adds a stage reaches every project that runs the default gate.
- A project with custom build or test commands does not get the gate in CI until it adopts it.

## References

- `build/dod.ps1`, `.template/Test-AdrIndex.ps1`, `AGENTS.md` Landing section: `gate`
- [ADR-0100](0100-warnings-are-errors-in-every-project.md): warnings are errors in every project.
- [ADR-0102](0102-disallowed-apis-are-banned-at-build-time.md): disallowed APIs are banned at build time.
