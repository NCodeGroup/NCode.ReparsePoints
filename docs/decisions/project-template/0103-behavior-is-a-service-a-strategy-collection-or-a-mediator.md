# 0103. Behavior is a service by default, a strategy collection when open, and a mediator only at a pipeline seam

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

A .NET codebase has several superficially interchangeable ways to structure behavior, and it is often unclear which to
reach for:

1. A dependency-injected service: an `IFoo` interface with one implementation, injected and called directly.
2. A strategy collection: several implementations of one interface registered with `TryAddEnumerable` and injected as
   `IEnumerable<IFoo>`, which the caller iterates or selects from.
3. A mediator or pipeline: the caller sends a message and does not know which handlers run, in what order, or with
   what pre- and post-processing.
4. Observation: the caller announces that something happened, and observers (audit, metrics, notifications) react
   without returning anything to it.

Choosing wrong is costly in either direction. Overusing a mediator buys flexibility the feature never needed and
destroys discoverability: "Go to definition" on a `Send` call does not reach the code that runs, and a stack trace
passes through dispatch machinery. Underusing it hard-codes a step that other code later needs to extend, which forces
an invasive refactor. Observation is mistaken for a mediator message most often: a mediator awaits its handlers in
turn, so the first observer that throws fails the operation it was only meant to watch and stops the observers after
it.

## Decision

Answer one question: is this a deliberate extension seam on a pipeline, a capability the caller calls for an answer, or
the observation of an outcome already decided? Seam: mediator or explicit pipeline. Capability: service. Observation:
an observer collection.

The supporting discriminator is coupling direction. With a service or a strategy collection the caller knows and names
what it wants, and depends on the abstraction directly. With a mediator the caller must stay ignorant of who
participates; handlers can be added, reordered, wrapped, or replaced without the sender changing.

Prefer the cheapest option and escalate only when a requirement forces it:

1. One deterministic implementation and the caller wants the result: a service (`TryAddSingleton`, `TryAddScoped`).
   This is the default and covers most code.
2. Several independent implementations, and the caller owns the orchestration (it iterates or picks one), with no need
   for ordering, pre- and post-processing, or unified exception handling: a strategy collection (`TryAddEnumerable`).
3. A pipeline seam where the sender must not know the handlers, participants must be addable or reorderable, it needs
   ordering or pre- and post-processing, or many contributors mutate one shared result: a mediator or an explicit
   pipeline. The project adopts a mediator library only when such a seam exists, and records that choice in its own
   decision record.

Observation is a fourth shape beside the ladder, chosen by intent rather than by escalation: the caller publishes an
event after the outcome is decided (after the commit, for a persisted change), and observers registered with
`TryAddEnumerable` receive it. An observer cannot change the outcome: it returns nothing the caller reads, and the
publisher catches and logs each observer's failure, so one failing observer neither fails the operation nor stops the
others. An event carries identifiers and metadata, never a secret
([ADR-0146](0146-secrets-are-never-logged-compared-in-constant-time-and-shown-once.md)). An observer whose work must
not be lost, such as an audit record a regulation requires, is an outbox delivery
([ADR-0141](0141-side-effects-after-a-commit-go-through-an-outbox.md)), not a best-effort observer.

Layering: endpoints and services orchestrate and compute; a mediator marks only the seams that must stay open; handlers
may call services; services reach handlers only through the mediator.

## Options considered

- Everything through a mediator. Rejected: maximal indirection for behavior that is fixed and single-owner, at the cost
  of discoverability, traceability, and per-call overhead.
- Everything as plain services. Rejected: genuinely open-ended concerns end up as `switch` statements over types, with
  no place to plug in a new case without editing the class.
- Observation through the mediator. Rejected: a throwing observer aborts the operation and the remaining observers.
- A three-step ladder plus fault-isolated observation (chosen). The common case stays a direct call, strategy
  collections give a lightweight extension point, the mediator is reserved for seams that need pipeline semantics, and
  observers watch outcomes without being able to break them.

## Consequences

- Contributors answer one question and default to the simplest tool.
- New extension points that need only caller-owned fan-out are strategy collections, and can be promoted later if
  ordering or observation becomes a requirement.
- The set of mediator messages, if any, stays small and meaningful.

"You chose wrong" smells:

- Mediator smell: a message returns a value, the sender knows exactly what it wants, nothing is expected to add,
  reorder, or replace a handler, and nothing needs pre- or post-processing. It is a service in disguise; collapse it.
  The test is intent, not handler count: a real seam stays a seam while it has one handler.
- Service smell: a class `switch`es over kinds or types, or callers keep asking how to add their own case. A seam was
  hard-coded; promote it to a strategy collection, or to a pipeline if it needs ordering.
- Observer smell: an observer whose exception reaches the caller, or a caller that reads something an observer set. It
  is either a pipeline step or a broken observer; make it one or the other.

## References

- [Dependency injection in .NET](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection)
- [ADR-0105](0105-the-canonical-implementation-is-named-defaultfoo.md): the naming of the implementation behind a
  service interface.
- [ADR-0141](0141-side-effects-after-a-commit-go-through-an-outbox.md): side effects after a commit go through an
  outbox.
- [ADR-0146](0146-secrets-are-never-logged-compared-in-constant-time-and-shown-once.md): secrets are never logged,
  compared in constant time, and shown once.
