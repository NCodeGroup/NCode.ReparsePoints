# 0133. Abstractions packages are framework-free, tiered by dependency, and hold no logic

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

This decision applies to a library published as several packages.

An abstractions package tends to grow to mix dependency tiers in one assembly: base class library primitives, a
subsystem that needs `System.Text.Json` or another package, and types that need ASP.NET Core. When the lowest
abstractions package carries `<FrameworkReference Include="Microsoft.AspNetCore.App" />` for a handful of HTTP types,
it drags ASP.NET Core into every package beneath it, and a low-level package that has nothing to do with HTTP (a
cryptography or serialization package) can no longer reference it without inverting the layering. The same wall then
produces duplicated helpers, one copy on each side.

Helper logic placed in an abstractions package has the same effect on a smaller scale: the package stops being a pure
contract, and its consumers take code they did not ask for.

## Decision

Abstractions packages carry only the dependencies their own types need, and only contracts.

- The base abstractions package depends on the base class library alone. It holds the primitives every other package
  may need.
- A subsystem with its own dependency (a JSON-based model, a collections package) lives in its own abstractions
  package that carries that dependency.
- Types that need ASP.NET Core (results, HTTP models, endpoint contracts) live in an `*.AspNetCore.Abstractions`
  package, the only abstractions package with the ASP.NET Core `FrameworkReference`.
- An abstractions package holds interfaces, options, value types, constants, and exceptions, and no helper logic. A
  general helper that several implementation packages share (time arithmetic, JSON element accessors) lives in a small
  dependency-free utility package that any package may reference.
- Splitting a package keeps namespaces unchanged where possible, so consumers change project references, not `using`
  directives.

## Options considered

- One abstractions package with every dependency. Rejected: the heaviest dependency of any type becomes a dependency of
  every consumer.
- Helpers in the abstractions package that first needs them. Rejected: it couples contracts to logic and invites
  copies when a package that cannot reference it needs the same helper.
- Tiered, framework-free contract packages (chosen).

## Consequences

- Low-level packages reference the base abstractions without inheriting ASP.NET Core.
- More, smaller packages. Consumers that use a higher tier get the lower ones transitively.
- A `FrameworkReference` or a package reference added to an abstractions package is a review question: does every type
  in it need that dependency?

## References

- [Use ASP.NET Core APIs in a class library](https://learn.microsoft.com/aspnet/core/fundamentals/target-aspnetcore)
- [ADR-0132](0132-implementation-packages-depend-only-on-abstractions.md): implementation packages depend only on
  abstractions.
