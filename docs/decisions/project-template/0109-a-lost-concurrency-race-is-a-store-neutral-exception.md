# 0109. A lost concurrency race surfaces as a store-neutral exception

- **Status:** Accepted
- **Date:** 2026-10-31

This decision applies to code that reads and writes through a store or repository abstraction with optimistic
concurrency. Code that uses a `DbContext` directly handles Entity Framework's exception where it saves.

## Context

Optimistic concurrency makes a write atomic without locks: each row carries a concurrency token, the `UPDATE` includes
the token read earlier in its `WHERE` clause, and of two writers that read the same version at most one succeeds.
Entity Framework reports the loser as `DbUpdateConcurrencyException`.

Two problems follow when nothing translates that exception:

- An uncaught lost race reaches the client as `500`, although it is a normal outcome of concurrent use. For an
  operation that may happen only once (redeeming a code, consuming a one-time link, claiming a job), the request that
  lost the race should get the same answer as a second, sequential attempt.
- The exception is the type of one store technology. Code above the store abstraction would have to reference Entity
  Framework to handle it, and a store built on something else could not report the race in a way callers understand.

## Decision

1. A lost race is a `StoreConcurrencyException`, defined in the store abstraction (a public exception with the
   standard constructors). It is thrown when a unit of work writes an entity that another unit of work changed after
   it was read, as the concurrency token shows. The caller lost the race and must not blindly retry the same write,
   because it was computed from a stale read.
2. The unit of work translates a failed save. The store's save method catches `DbUpdateConcurrencyException` and throws
   `StoreConcurrencyException` with it as the inner exception. Any other failure propagates unchanged.
3. A store that compares a caller-presented token with the stored one (an `If-Match` value passed down) throws the same
   exception when they differ.
4. Single-use operations answer the loser as a second attempt. An operation that consumes something once catches
   `StoreConcurrencyException` around its update and save and returns the same result as for an item that is
   unknown, expired, or already consumed, so callers see one answer whether the second attempt was concurrent or
   sequential.

## Options considered

- A conditional set-based update (`ExecuteUpdateAsync` with the expected state in the predicate). Valid for a
  single-row state change, and cheaper, but it bypasses change tracking and `SaveChanges` interceptors. Whichever
  mechanism detects the race, it reports it as the same store-neutral exception.
- Catching `DbUpdateConcurrencyException` in the calling layer. Rejected: it couples that layer to one store technology.
- Letting the exception propagate. Rejected: a normal outcome becomes a `500`.

## Consequences

- Of two requests that consume one item at the same moment, one succeeds and the other receives the answer of a second
  attempt; neither receives `500`.
- A store not built on Entity Framework reports a race by throwing the same exception, and callers handle it without
  referencing the store technology.
- HTTP endpoints map the exception once ([ADR-0125](0125-a-write-that-loses-a-race-is-answered-412.md)), and writers
  that should win a race read again and retry ([ADR-0110](0110-shared-state-is-changed-by-read-modify-write.md)).
- Concurrency behavior needs a test against a provider that enforces concurrency tokens (SQLite or the production
  database); the EF Core InMemory provider does not enforce them.

## References

- [Handling concurrency conflicts in EF Core](https://learn.microsoft.com/ef/core/saving/concurrency)
- [ADR-0110](0110-shared-state-is-changed-by-read-modify-write.md): stored state is changed by a read-modify-write that
  loses no concurrent write.
- [ADR-0125](0125-a-write-that-loses-a-race-is-answered-412.md): an API write that loses a race is answered 412.
