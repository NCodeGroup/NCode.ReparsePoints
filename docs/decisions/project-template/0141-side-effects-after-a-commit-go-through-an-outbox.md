# 0141. A side effect that must follow a commit goes through an outbox

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

Many changes must be followed by an effect outside the database that holds them: a message to another service, a
webhook to a customer's endpoint, an email, a notification, an audit record sent to an external sink. The change and
the effect are two writes to two systems, and no local transaction spans both:

- An effect sent before the commit is a phantom when the transaction then rolls back.
- An effect sent inline after the commit is lost when the process crashes between the two, when the remote system is
  down, or when it answers with an error the request does not retry.
- An effect handed to an in-memory queue is lost on every restart and deployment, and nothing records that it was.

The conventions already say that an effect after a commit runs with `CancellationToken.None`, bounded by its own
timeout, so a client that disconnects cannot leave the change committed without its effect. That rule protects
against cancellation, not against a crash or a remote failure.

## Decision

An effect that must not be lost, and that the request cannot complete and verify before it answers, is written to an
outbox in the same transaction as the change and delivered after the commit, at least once.

1. Inline or outbox. An effect the same request completes and verifies before it answers stays inline, after the
   commit, with `CancellationToken.None` and its own timeout: evicting a local cache entry, reading the committed
   value back, sending a best-effort hint ([ADR-0140](0140-replicas-converge-through-reconciliation.md)). An effect
   on another system that must happen, such as a message, webhook, email, notification or external audit record, goes
   through the outbox. An effect that may be lost without harm is neither: it is best effort, and its failure is
   logged.
2. Written with the change. The outbox row is added to the same unit of work as the change, so both commit or neither
   does. The row carries a stable identifier, the effect's kind, its creation time and plain serializable data: the
   identifiers and values the handler needs, never a secret it could read again
   ([ADR-0146](0146-secrets-are-never-logged-compared-in-constant-time-and-shown-once.md)).
3. Delivered by a background worker. A hosted service drains the outbox. It claims a batch with an expiring claim, so
   one instance delivers each row and a row whose instance died is claimed again when the claim expires. It runs each
   row's handler in a fresh dependency-injection scope with the application's stopping token, never a request's, and
   marks the row delivered in its own unit of work.
4. Bounded, jittered retry. A failed attempt is retried with exponential back-off and random jitter, up to a fixed
   number of attempts. After the last one the row is parked as failed: kept, logged at Error, and counted in a metric,
   never deleted silently. Retrying a parked row is a deliberate operation.
5. Idempotent handlers. Delivery is at least once, so a handler may run twice for one row. Its effect is idempotent,
   keyed by the row's identifier: the receiver de-duplicates on it, or the handler checks before it acts. A receiver
   that de-duplicates records the identifier only after it has handled the delivery, so a failed attempt is not later
   refused as a repeat.
6. Kept for a while, then pruned. Delivered rows are pruned after a retention period
   ([ADR-0142](0142-data-that-grows-with-use-is-pruned-in-bounded-batches.md)); parked rows stay until a person acts.
7. Library or table. A project may implement the outbox as a table and a hosted service, or adopt a library or broker
   integration that provides one, recorded in its own decision record. Either way it keeps the guarantees above.

## Options considered

- Send inline after the commit, best effort. Rejected for effects that must happen: a crash or a remote outage loses
  them with no trace.
- Send before the commit. Rejected: a rollback leaves an effect for a change that never happened.
- An in-memory background queue. Rejected for effects that must happen: a restart loses its contents.
- A distributed transaction across the database and the remote system. Rejected: most brokers and every HTTP endpoint
  lack two-phase commit, and it couples the request's latency to the remote system's.
- A transactional outbox delivered at least once (chosen).

## Consequences

- An effect is never lost after its change commits, and never sent for a change that rolled back.
- The effect happens after the request answers, so the response reports that it is accepted, not that it is done.
- Rows are delivered roughly in order, not strictly; an effect that needs ordering carries a sequence its handler
  checks.
- A remote outage grows the outbox instead of failing requests; the parked-row metric and the oldest pending row's age
  are what an operator alerts on.
- Smell: a `try`/`catch` that logs and swallows the failure of an effect a customer depends on, or a background queue
  that holds the only copy of a pending effect.

## References

- [Transactional outbox pattern](https://microservices.io/patterns/data/transactional-outbox.html)
- [Background tasks with hosted services in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/host/hosted-services)
- [ADR-0140](0140-replicas-converge-through-reconciliation.md): replicas converge through reconciliation.
- [ADR-0142](0142-data-that-grows-with-use-is-pruned-in-bounded-batches.md): data that grows with use has a retention
  period and is pruned in bounded batches.
- [ADR-0146](0146-secrets-are-never-logged-compared-in-constant-time-and-shown-once.md): secrets are never logged,
  compared in constant time, and shown once.
