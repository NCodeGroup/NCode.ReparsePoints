# 0125. An API write that loses a concurrency race is answered 412

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

This decision applies to projects that host ASP.NET Core and expose HTTP APIs that write through optimistic
concurrency.

A store reports a lost concurrency race as a store-neutral exception
([ADR-0109](0109-a-lost-concurrency-race-is-a-store-neutral-exception.md)). If an endpoint lets it propagate, the
client receives `500`, although it can recover by reading the resource again. If each endpoint catches it, every
endpoint repeats the same code, and the one that forgets answers `500`.

## Decision

One endpoint filter, installed once on the API's root route group, answers a lost race with `412 Precondition Failed`.

- The filter catches `StoreConcurrencyException` and returns a problem details response: "The resource was changed
  by another request after this request read it. Read it again and retry." It logs the event at Debug, because it is a
  normal outcome.
- It is installed on the root `RouteGroupBuilder` of the API (`app.MapGroup("/api").AddEndpointFilter<...>()`), so
  every endpoint under it, including those added later, inherits it. No endpoint catches the exception itself. An
  application that maps exceptions centrally through `IExceptionHandler` maps this one there instead, to the same
  response.
- `412` is the answer because a lost race is the condition a stale `If-Match` reports: the resource changed after the
  caller's view of it, and the caller recovers the same way, by reading again and retrying.
- Endpoints whose contract defines another answer for a lost race (a single-use operation answered as a second
  attempt, [ADR-0109](0109-a-lost-concurrency-race-is-a-store-neutral-exception.md)) handle it where the operation
  runs, before the filter sees it.
- An `ETag` versions exactly one stored entity: it is derived from that entity's concurrency token, and an `If-Match`
  against it is checked under the same token. A view built from several entities (an effective configuration merged
  from a parent and a child, a summary across records) carries no `ETag` and does not honor conditional headers,
  because no single token changes when each of its parts does.

## Options considered

- `409 Conflict`. Rejected: it reports a state the caller must change (dependents that block a delete, a duplicate
  name), whereas a lost race resolves on a retry.
- A catch in each handler. Rejected: repetitive and easy to forget.
- A retry in the server. Rejected for writes computed from the caller's view: the caller decides whether its change
  still applies. Writes that must win a race retry inside the operation
  ([ADR-0110](0110-shared-state-is-changed-by-read-modify-write.md)).
- An `ETag` on a view composed from several entities. Rejected: no one entity's version covers the view, so a
  conditional read would get a stale `304` after a change to another of them.

## Consequences

- No API write reaches its client as `500` for a lost race.
- Clients treat `412` uniformly: re-read, re-apply, retry.
- Endpoints that should also enforce caller staleness accept `If-Match` and answer a mismatch with the same `412`.

## References

- [RFC 9110 §15.5.13, 412 Precondition Failed](https://www.rfc-editor.org/rfc/rfc9110#name-412-precondition-failed)
- [Minimal API filters](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis/min-api-filters)
- [ADR-0109](0109-a-lost-concurrency-race-is-a-store-neutral-exception.md): a lost concurrency race surfaces as a
  store-neutral exception.
- [ADR-0110](0110-shared-state-is-changed-by-read-modify-write.md): stored state is changed by a read-modify-write that
  loses no concurrent write.
