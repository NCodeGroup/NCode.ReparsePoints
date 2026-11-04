# 0116. Visibility starts at the narrowest that works; public is a deliberate decision

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

C# lets any type or member be `public`, and an IDE's templates and an agent's completions often make it so. A type
becomes public because that compiled first, or because a test needed to reach it, and nobody decided it should be part
of the assembly's contract.

The two mistakes do not cost the same. An accidental `internal` is found the moment someone needs the type, and the fix
is a one-line widening. An accidental `public` is found only after something depends on it: from then on it is a
contract, supported until the next major version and withdrawn only through `[Obsolete]` across a major.

This holds for applications too. Public types in an application's assemblies become what its tests, its other projects
and reflection-based tooling bind to, so an accidental public surface there turns refactors into breaks just as it does
in a library.

## Decision

`public` is a deliberate decision, never a default. In every project, library or application, every type and member
starts at the narrowest visibility that works, `private` and then `internal`, and widens only with a reason.

- A reason is a consumer's need: a contract consumers implement or resolve, an entry point, or data they construct and
  read.
- "It compiled" is not a reason, and neither is "a test needed it". Tests reach internals through
  `InternalsVisibleTo`, which is reserved for test projects
  ([ADR-0104](0104-no-cross-assembly-internalsvisibleto.md)).
- A concrete implementation that consumers reach through dependency injection stays `internal`; the interface is the
  surface ([ADR-0105](0105-the-canonical-implementation-is-named-defaultfoo.md)).
- A library additionally tracks its public surface in files the build checks (ADR-0131), so every widening shows in the
  diff.

## Options considered

- Public by default, narrowed when it matters. Rejected: by the time it matters, something depends on it, and narrowing
  is a breaking change.
- Narrowest by default for libraries only. Rejected: an application's public types are bound to by its tests, its other
  projects and its tooling, and the same accidental contracts form there.
- Enforce it with `CA1515` ("consider making public types internal"). Not enabled by the template, and the rule
  applies to applications only. A project may raise it in `.editorconfig`.
- Narrowest visibility that works, widened with a reason (chosen). The default mistake is the cheap one.

## Consequences

- Every public type and member is one somebody chose, so the public surface is the assembly's contract and nothing
  more.
- Widening a type is a small, visible change with a stated reason; a pull request that makes something public is asked
  why.
- Internal types refactor freely, since nothing outside the assembly and its tests can bind to them.
- Smell: a public type no consumer constructs, implements or resolves, or a member made public so a test could call it.

## References

- `.github/instructions/csharp.instructions.md`
- [Accessibility levels](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/accessibility-levels)
- [CA1515: Consider making public types internal](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1515)
- [ADR-0104](0104-no-cross-assembly-internalsvisibleto.md): no cross-assembly `InternalsVisibleTo` in production code.
- [ADR-0105](0105-the-canonical-implementation-is-named-defaultfoo.md): the canonical implementation is the internal
  `DefaultFoo`.
