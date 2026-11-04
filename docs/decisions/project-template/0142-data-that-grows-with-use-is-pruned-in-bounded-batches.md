# 0142. Data that grows with use has a retention period and is pruned in bounded batches

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

Some tables gain rows with every use of the system: issued tokens and codes, sessions, delivered outbox rows, audit
records, usage counters, idempotency keys. Without removal they grow without bound. The cost arrives late and
everywhere: indexes and backups grow, queries that once fit in memory stop fitting, and an operation that loads an
owner's rows (deleting a customer, exporting an account) becomes one enormous unit of work.

Removal has its own traps:

- A row that has ended is often still read for a while: a replayed token must be recognized as a replay, and an audit
  record must be kept for as long as policy says. Removing it at once breaks those checks.
- One `DELETE` of every ended row locks a large range, runs for minutes, and fails as a whole.
- A bulk delete statement that one provider supports is missing from another, such as a test provider.
- When every instance prunes, two instances try to remove the same rows, and one of them loses a race.
- A prune that runs inside a request makes that request as slow as the backlog.

## Decision

Every table that grows with use declares how long a row is kept after it ends, and a hosted service removes the rows
past that period, in bounded batches.

1. A retention per table. A row ends at a recorded time: when it expires, is revoked, is delivered, or is completed,
   whichever comes first. The retention is how long it is kept after that, chosen from what still reads ended rows
   (a replay window, a dispute period, an audit policy) and written with its reason beside the option. A row that never
   ends is not pruned by this mechanism; its design gives it an end.
2. Configured and validated. The retention and the prune interval are options bound strictly and validated when the
   host starts ([ADR-0106](0106-configuration-binds-strictly-and-is-validated-at-startup.md)): the retention is not
   negative, and the interval is a period a timer accepts. The service reads them when it runs, not in its
   constructor.
3. A hosted service on a timer. A `BackgroundService` ticks a `PeriodicTimer` on the configured interval, through the
   registered `TimeProvider`, and runs one prune per tick. Pruning never runs inside a request.
4. Bounded batches, each its own unit of work. A prune removes up to a fixed number of rows that ended before the
   current time minus the retention, saves, and repeats while a batch is full. The store method takes the cutoff and
   the limit and returns the count. Each batch commits on its own, so a failure loses at most one batch of work. The
   removal uses a statement every provider the project runs supports, or reads the batch and removes it through the
   change tracker.
5. A lost race is progress. A batch whose save loses a concurrency race
   ([ADR-0109](0109-a-lost-concurrency-race-is-a-store-neutral-exception.md)) means another instance removed rows of
   it. It counts as a full batch, and the next batch is read. Every instance may run the prune; concurrent prunes waste
   at most one batch each.
6. Failures wait for the next tick. Any other failure is logged at Warning with a stable event id, and the prune runs
   again at the next tick. The loop never lets an exception escape and stop the host.
7. The end time is indexed. The column the prune filters on (the end time, and any column it is combined with) has an
   index, added by an expanding migration
   ([ADR-0143](0143-migrations-run-before-the-rollout-and-only-expand.md)), so a prune reads only the rows it removes.

## Options considered

- Keep everything. Rejected: the growth is unbounded, and every operation over an owner's rows grows with it.
- Remove a row as soon as it ends. Rejected: checks that read ended rows, such as replay detection, stop working.
- One delete of every ended row. Rejected: long locks, a long transaction, and all-or-nothing failure.
- A database job outside the application. Rejected as the default: it is a second place that knows the schema and the
  retention, and tests do not run it. A project whose database team owns pruning records that choice.
- A hosted service pruning in bounded batches after a retention period (chosen).

## Consequences

- Each growing table stays near the size its retention implies, and an operator can read that size from the options.
- A new table that grows with use comes with its retention, its prune and its index in the same change.
- A prune that falls behind catches up a batch at a time, without long locks.
- Rows a prune removes are gone from the live database; backups keep them until the backups expire.

## References

- [Background tasks with hosted services in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/host/hosted-services)
- [`PeriodicTimer`](https://learn.microsoft.com/dotnet/api/system.threading.periodictimer)
- [ADR-0106](0106-configuration-binds-strictly-and-is-validated-at-startup.md): configuration binds strictly and is
  validated when the host starts.
- [ADR-0109](0109-a-lost-concurrency-race-is-a-store-neutral-exception.md): a lost concurrency race surfaces as a
  store-neutral exception.
- [ADR-0143](0143-migrations-run-before-the-rollout-and-only-expand.md): migrations run before the rollout and only
  expand until a later release contracts.
