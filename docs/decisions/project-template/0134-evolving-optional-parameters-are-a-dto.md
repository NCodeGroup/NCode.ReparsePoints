# 0134. A growing set of optional criteria is an init-only DTO, not positional parameters

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

This decision matters most for libraries published as packages, whose interfaces consumers call and implement. An
application may follow it for the same readability reasons, but a new parameter there costs only a refactor.

Some methods have a growing set of optional selection criteria. A query method's filter grows from `(customerId)` to
`(customerId, status)` to `(customerId, status, region)`, each addition a new positional parameter. In a published
library, every new parameter, even an optional one, changes the method signature, which breaks source and binary
compatibility for callers and for every consumer that implements the interface.

## Decision

An evolving set of optional selection criteria is a dedicated DTO with init-only properties, not positional
parameters.

- The DTO is a `readonly record struct` (or `record`) with init-only, non-`required` properties, for example
  `OrderFilter { CustomerId, Status, Region }`. Adding a criterion later is source-compatible: existing object
  initializers keep compiling and the method signature does not change.
- It is constructed with an object initializer or `with`, never a positional primary constructor, because a new
  constructor parameter is itself a breaking change.
- Where an empty filter would be dangerous (an unscoped bulk delete), the DTO exposes an `IsEmpty` check and the
  method refuses an empty filter.
- Pagination inputs are one shared DTO too (`PageRequest { Cursor, Limit }`), so paging can grow (a sort direction)
  without a signature change.

The rule is not applied everywhere:

- A required key the operation is about (the `orderId` of `GetOrderAsync`) stays a positional parameter.
- Request and command inputs that are already init-only records need no wrapper.

## Options considered

- Positional parameters, optional parameters, or overloads. Rejected: each addition changes a signature or multiplies
  overloads.
- A `Dictionary<string, object>` of criteria. Rejected: untyped and undiscoverable.
- An init-only criteria DTO (chosen).

## Consequences

- Interfaces whose filters keep growing can gain criteria without a breaking change after the first stable release.
- One rule to remember: optional and growing, an init-only DTO; required key, positional.
- Implementations must treat an unset criterion as "not filtered", which the DTO's documentation states.

## References

- [Init-only setters](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/init)
- [ADR-0131](0131-public-api-is-tracked-and-evolves-compatibly.md): the public API surface evolves
  backward-compatibly.
