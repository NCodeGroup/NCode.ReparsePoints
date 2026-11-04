# 0132. Implementation packages depend only on abstractions; the composition root wires them

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

This decision applies to a library split into several packages, each an abstractions package and an implementation
package. A library published as one package skips it.

When one implementation package needs a capability owned by another, the tempting shortcut is a direct project
reference from one implementation to the other. That reference welds the two together: a consumer that wants one
capability transitively takes the other's whole dependency closure, the package boundary stops meaning anything, and
two implementations that should each be replaceable can no longer be swapped independently. It also invites two
callers to reach one shared behavior through two different concrete paths.

## Decision

An implementation package references only abstractions packages, never another implementation package.

- `Foo.Abstractions` owns `IFoo` and its options and value types.
- `Foo` provides the implementation (`DefaultFoo`,
  [ADR-0105](0105-the-canonical-implementation-is-named-defaultfoo.md)) and references only abstractions packages.
- A consumer of the capability takes `IFoo` by constructor injection and references `Foo.Abstractions`, never `Foo`.
- Each implementation package registers its own types from one `IServiceCollection` extension method
  (`services.AddFoo()`) using `TryAdd*`, so a consumer's earlier registration wins.
- The composition root (the application's host, or a convenience package such as `AddContoso()`) is the one place
  that references the implementation packages and calls their registrations.

## Options considered

- A direct reference between implementation packages. Rejected: transitive dependency bloat, a meaningless boundary,
  and lost independent replaceability.
- One package holding contract and implementation together. Rejected: a consumer of the contract is forced to take the
  implementation and its dependencies.
- Abstraction seams plus DI composition (chosen). Each package stays independently buildable, testable, and
  replaceable, and a shared capability has one concrete binding.

## Consequences

- A capability used by more than one implementation package ships as an abstractions and implementation pair.
- The reference graph of implementation packages is a flat fan-out from the composition root, not a web.
- One extra package per shared capability, in return for boundaries that keep their meaning.
- The rule is mechanically checkable: an implementation project whose `ProjectReference` names a project that is not an
  abstractions project is a violation.

## References

- [ADR-0104](0104-no-cross-assembly-internalsvisibleto.md): no cross-assembly `InternalsVisibleTo`.
- [ADR-0105](0105-the-canonical-implementation-is-named-defaultfoo.md): the `DefaultFoo` naming of the implementation
  behind a seam.
- [ADR-0133](0133-abstractions-are-framework-free-and-tiered.md): abstractions packages are framework-free and tiered.
