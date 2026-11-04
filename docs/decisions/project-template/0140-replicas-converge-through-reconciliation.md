# 0140. Replicas converge through reconciliation, not through messages

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

A service that runs as several instances keeps some state per instance for speed: a cache of materialized objects, a
compiled configuration, a loaded key set. When one instance changes the shared state behind such a cache, the others
keep serving their copy. The usual remedies each fail in a way that is easy to miss:

- A sliding expiration keeps a busy entry loaded forever, so an instance that missed a change serves the old value
  for as long as it is used.
- A change message from one instance to the others is lost when an instance is disconnected, restarting, or not yet
  subscribed. A message that carries the changed data is also out of date when a later change overtakes it, and an
  instance that applies it serves something the store never held.
- State derived from shared data (a key that must exist for each enabled algorithm, a projection, a count) is often
  updated by replaying change events or by a job queued in memory. A lost event leaves the derived state wrong
  forever, and a restart loses the queue.
- A job that every instance runs on each change does the same work once per instance, and the copies race.

The conventions already say that correctness never depends on process-local state and that an in-memory cache holds
only data that can be rebuilt on a miss. This record decides how instances converge when the shared state changes.

## Decision

Every per-instance copy has a bounded lifetime, a change notice is only a hint that shortens it, and derived state is
rebuilt from current state by one instance at a time.

1. An absolute lifetime. Every per-instance cache entry has an absolute expiration, set from an option validated when
   the host starts ([ADR-0106](0106-configuration-binds-strictly-and-is-validated-at-startup.md)). It is the longest
   an instance may serve a value after the store changed, whatever messages it missed. A sliding expiration may
   shorten an idle entry's life, never extend it past the absolute one.
2. A notice is a hint. After a change commits, the instance that made it sends a notice on a channel named for the
   kind of change. The notice carries an identifier, never the data: each instance that receives it evicts the entry
   or reads the committed value from the store. Delivery is best effort, at most once and unordered, so a handler is
   idempotent and tolerates a lost, repeated or late notice. The instance that made the change handles it through the
   same handler as every other instance. A failed send is logged and never fails the committed write.
3. A missed notice drops what it would have invalidated. When an instance may have missed notices (its subscription
   was established after it started serving, or its connection to the message channel was restored), it evicts every
   entry the channel could have invalidated.
4. Derived state is reconciled, not replayed. Data computed from shared data is kept correct by an idempotent pass
   that reads the current state, checks the invariant, and repairs only what does not hold. The pass runs when the
   instance starts and on each change signal, in its own hosted service.
5. One instance runs a pass, under a lease. A pass takes an expiring lease in the shared store, keyed by what it
   reconciles and by the version of its inputs, so instances that observe one change share one lease and a later change
   is a new key. The pass records the version it reconciled with an optimistic write
   ([ADR-0110](0110-shared-state-is-changed-by-read-modify-write.md)), so the record never overwrites a newer change.
   An instance that found the lease held, whose pass failed, or whose record lost a race tries again when the lease
   expires or at the next signal, so a pass interrupted by a restart is run again within one lease.
6. No queued job carries convergence. A reconciliation is never a job in an in-memory queue, and a step that must
   reach another system is an outbox delivery ([ADR-0141](0141-side-effects-after-a-commit-go-through-an-outbox.md)),
   not a notice.

## Options considered

- A shared distributed cache instead of per-instance copies. Rejected as the general answer: a materialized object
  with live providers or keys is not serializable, and every read pays a round trip. A value that is plain data may
  still live in a shared cache.
- Notices that carry the data. Rejected: a late notice installs a value the store has since replaced.
- Notices with a sliding expiration only. Rejected: a lost notice leaves an instance stale for as long as the entry is
  busy.
- Replaying change events into derived state. Rejected: one lost or reordered event corrupts the result for good.
- Every instance reconciles on every change. Rejected: the work multiplies with the instance count, and the copies race.
- Bounded lifetimes, hint notices and leased reconciliation (chosen).

## Consequences

- An instance serves a value at most one absolute lifetime after the store changed, and usually only until the notice
  arrives.
- A notice transport that loses messages costs latency, never correctness, so the transport can be simple.
- A reconciliation reads current state, so it repairs drift from any cause: a lost notice, a configuration change that
  no write announced, a restart in the middle of a pass.
- A pass costs a read of what it checks; it pages through large sets and repairs only what is wrong.
- Smell: a handler that applies the data a message carries, a cache entry with no absolute expiration, or derived state
  that only an event handler ever writes.

## References

- [Caching in .NET](https://learn.microsoft.com/dotnet/core/extensions/caching)
- [ADR-0106](0106-configuration-binds-strictly-and-is-validated-at-startup.md): configuration binds strictly and is
  validated when the host starts.
- [ADR-0110](0110-shared-state-is-changed-by-read-modify-write.md): stored state is changed by a read-modify-write that
  loses no concurrent write.
- [ADR-0141](0141-side-effects-after-a-commit-go-through-an-outbox.md): side effects after a commit go through an
  outbox.
- [ADR-0144](0144-correctness-guards-fail-closed-capacity-guards-fail-open.md): correctness guards fail closed,
  capacity guards fail open.
