# 0104. No cross-assembly InternalsVisibleTo in production code

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

A solution split into several projects has assemblies that collaborate at runtime. It is tempting to let one assembly
reach another's `internal` types through `InternalsVisibleTo` instead of designing a contract between them. That
coupling is invisible to readers and consumers, and it turns every internal refactor of one assembly into a possible
break of another: a change that is safe within one assembly silently breaks a second one that compiled against its
internals.

## Decision

Production assemblies collaborate only through deliberately designed public contracts, never through
`InternalsVisibleTo`.

- `InternalsVisibleTo` is reserved for test projects: the matching test assembly, plus the proxy assembly of a mocking
  library that needs it to proxy `internal` types (`DynamicProxyGenAssembly2` for Moq and other Castle-based
  libraries), as the C# conventions show.
- In a library published as a package, a type that must be public only for collaboration between the library's own
  assemblies, never for application code, is marked `[EditorBrowsable(EditorBrowsableState.Never)]`, and its
  `<summary>` opens with "This API supports the infrastructure of this library and is not intended to be used directly
  from your code." This is the pattern ASP.NET Core and Entity Framework Core use.

## Options considered

- Cross-assembly `InternalsVisibleTo`. Rejected: hidden coupling that makes the assembly boundary meaningless, and that
  no public-API review sees.
- Merge the assemblies into one. Rejected where the split exists for a reason, such as letting consumers take a
  contract without an implementation or one feature without another. Where the split has no reason, merging is the
  right fix instead of `InternalsVisibleTo`.
- Public contracts, with infrastructure-only types hidden from IntelliSense (chosen). The collaboration surface is
  explicit and reviewable.

## Consequences

- Every interaction between assemblies is a designed, documented contract.
- Genuinely internal collaboration needs a little more up-front design; in return, internal refactors stay internal.
- An `InternalsVisibleTo` that names a non-test assembly is a review finding.
- In a family of packages, the same reasoning keeps implementation packages from referencing each other; they meet
  through abstractions instead.

## References

- `.github/instructions/csharp.instructions.md`, InternalsVisibleTo
- [`InternalsVisibleToAttribute`](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.internalsvisibletoattribute)
- [`EditorBrowsableAttribute`](https://learn.microsoft.com/dotnet/api/system.componentmodel.editorbrowsableattribute)
