# 0118. The null-forgiving operator is banned outside tests

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

Nullable reference types let the compiler prove that a reference is not null before it is dereferenced. The
null-forgiving operator `!` switches that proof off for one expression: it tells the compiler "trust me", and the
warning goes away whether or not the claim is true. The claim is often true when it is written and stops being true
after a refactor nobody connects to it, and the result is the `NullReferenceException` the annotations were meant to
prevent, with no warning anywhere to point at it.

`!` is also the shortest way to silence a nullable warning, so it is what an agent or a hurried person reaches for
first. With warnings as errors ([ADR-0100](0100-warnings-are-errors-in-every-project.md)), a build stays clean while
the nullable analysis it reports on is quietly hollowed out.

Tests have one legitimate use: an argument-validation test passes a deliberate `null` to a non-nullable parameter, as
`null!`, to check that the method throws.

## Decision

The null-forgiving operator fails the build in every project whose name does not end in `.Tests`.

- `Nullable.Extended.Analyzer` is referenced by every project whose name does not end in `.Tests`, with its version in
  `Directory.Packages.props` ([ADR-0101](0101-central-package-management.md)). Its diagnostics `NX0001` to `NX0004` flag
  every use of `!`, and with warnings as errors each one fails the build.
- The analyzer accepts a `// !` comment that justifies a use. The C# conventions do not: a justified `!` is still a
  claim the compiler cannot check.
- Production code restructures so the compiler proves the value is not null: `?? throw` at the point a null would be a
  bug, `[MemberNotNullWhen]` on a member that establishes the guarantee, a pattern such as `is { } value`, or an early
  return.
- Test projects are exempt. There `null!` passes a deliberate null to an argument-validation test, the one exception
  the C# conventions state.

## Options considered

- A rule in the C# conventions alone. Rejected: it binds only the readers who remember it, and `!` is the easiest way
  past a nullable warning.
- Allow `!` with a justifying comment. Rejected: the comment documents the claim but does not check it, and the next
  refactor invalidates both.
- Ban it in test projects too. Rejected: argument-validation tests need a deliberate null, and `null!` is the plain way
  to write one.
- An analyzer that fails the build outside tests (chosen). Every remaining `!` is in a test.

## Consequences

- Nullability in production code is proved by the compiler, not asserted by the author, so a refactor that breaks a
  guarantee shows up as a warning.
- Some code takes a few more lines: a `?? throw`, an attribute or a pattern instead of one character. The extra lines
  say where a null would be a bug and what happens then.
- An agent learns the rule from the build error, not from instructions it may not have loaded.
- Adopting the template on existing code can surface many uses of `!` at once; each is fixed by restructuring, not by a
  suppression.

## References

- `build/ProjectTemplate.props`, `Directory.Packages.props`, `.github/instructions/csharp.instructions.md`,
  `.github/instructions/csharp-tests.instructions.md`
- [Nullable.Extended](https://github.com/tom-englert/Nullable.Extended)
- [Nullable reference types](https://learn.microsoft.com/dotnet/csharp/nullable-references)
- [Attributes for nullable static analysis](https://learn.microsoft.com/dotnet/csharp/language-reference/attributes/nullable-analysis)
- [ADR-0100](0100-warnings-are-errors-in-every-project.md): warnings are errors in every project.
- [ADR-0101](0101-central-package-management.md): package versions are managed centrally.
