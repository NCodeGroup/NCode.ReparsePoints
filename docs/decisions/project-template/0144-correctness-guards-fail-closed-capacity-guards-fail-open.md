# 0144. Correctness guards fail closed; capacity guards fail open

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

Many checks a request passes through ask a store or another service for an answer: is this caller allowed, has this
token been used before, is this code still redeemable, has this account failed too many sign-ins, has this tenant used
up its rate. When that store is unreachable or slow, the check has no answer, and the code chooses one by accident:

- A store exception caught as "not found" turns an outage into data loss in the caller's eyes: a session reads as
  absent and the user is signed out, or a resource reads as missing and the client deletes its copy.
- An outage answered `401 Unauthorized` sends every browser to the sign-in page, which fails for the same reason, in
  a loop.
- A replay or single-use check that treats an unreachable store as "not seen before" accepts a replayed credential for
  as long as the outage lasts.
- A rate limiter that fails closed turns an outage of a cache that only counts requests into an outage of the whole
  service. One that waits for the store's own timeout on every request makes every request seconds slower.

Allow-lists have the same trap at configuration time. A list of trusted proxies, origins allowed to send credentials,
or hosts allowed to frame a page grants trust; read as "unrestricted" when it is empty, a missing setting trusts
everyone.

## Decision

A guard that protects correctness or security fails closed and reports the outage; a guard that only protects capacity
fails open, cheaply; and a list that grants trust grants nothing until it is configured.

1. Classify the guard. A correctness guard decides whether a request is allowed or valid: authorization, replay and
   nonce checks, single-use redemption, sign-in lockout, session lookup, revocation checks. A capacity guard only
   protects resources: rate limiters, time-window quotas that are not billed, load shedding, a cache in front of a
   store that can be read directly.
2. Correctness fails closed. When the store behind a correctness guard fails, the exception propagates and the request
   fails. A read that failed is never treated as absent. One exception mapping answers it `503 Service Unavailable`
   with a problem details body and a stable code ([ADR-0111](0111-failures-carry-a-machine-readable-code.md)), never
   `401`, `403` or `404`, so an outage neither signs anyone out nor reads as missing data.
3. Capacity fails open, cheaply. Each call a capacity guard makes is bounded by a short timeout, on the order of a
   hundred milliseconds. A call that fails or times out admits the request and opens a breaker: for a fixed interval
   the guard admits requests without calling the store, then tries again. Only an answer to a call made after the
   breaker opened closes it, so a slow call from before cannot undo a newer failure. The breaker logs one warning when
   it opens and one message when it closes, per instance, and every request admitted uncounted is counted in a metric
   with a bounded attribute such as `store_unavailable`
   ([ADR-0113](0113-metrics-have-one-owner-per-signal-and-bounded-dimensions.md)). The timeout and interval are
   constants, not settings: they bound the cost of an outage rather than express a policy.
4. Readiness follows correctness. A store that a correctness guard needs is a readiness dependency, so an instance
   that cannot reach it leaves the load balancer's rotation; a store that only a capacity guard uses is not
   ([ADR-0128](0128-liveness-never-checks-dependencies-readiness-does.md)).
5. Trust lists start empty. A list that grants trust, such as trusted proxies or networks, origins allowed to send
   credentials, or hosts allowed to frame or embed, permits nothing while it is unset or empty, and a wildcard is an
   explicit, validated value. "Unset means unrestricted" applies only to a list that narrows something already
   guarded, such as a host allow-list on top of a fixed address block
   ([ADR-0145](0145-outbound-calls-are-bounded-and-caller-supplied-urls-are-guarded.md)).

## Options considered

- Fail closed everywhere. Rejected: an outage of a store that only counts requests becomes an outage of the service.
- Fail open everywhere. Rejected: an outage lifts replay protection and lockouts exactly when an attacker can cause one.
- Decide per guard, case by case. Rejected: the answer then depends on whoever wrote the `catch`.
- Fail open with the store client's own timeout. Rejected: every request pays the timeout, so failing open still costs
  an outage's worth of latency.
- Classify, then fail closed with `503` or fail open behind a timeout and a breaker (chosen).

## Consequences

- An outage of a store behind a correctness guard fails the requests that need it, visibly, and users stay signed in.
- An outage of a capacity store lets traffic through unlimited for at least one breaker interval; a control that must
  hold during an outage, such as brute-force protection, is a correctness guard, not a rate limit.
- Every guard's classification is visible in its code: a guard that catches a store exception names which kind it is.
- A trust setting forgotten in a deployment trusts nothing, so the failure shows up as a refused request, not a hole.

## References

- [RFC 9110 §15.6.4, 503 Service Unavailable](https://www.rfc-editor.org/rfc/rfc9110#name-503-service-unavailable)
- [Circuit breaker pattern](https://learn.microsoft.com/azure/architecture/patterns/circuit-breaker)
- [ADR-0111](0111-failures-carry-a-machine-readable-code.md): failures carry a machine-readable code.
- [ADR-0113](0113-metrics-have-one-owner-per-signal-and-bounded-dimensions.md): metrics have one owner per signal and
  only bounded dimensions.
- [ADR-0128](0128-liveness-never-checks-dependencies-readiness-does.md): liveness never checks dependencies; readiness
  does.
- [ADR-0145](0145-outbound-calls-are-bounded-and-caller-supplied-urls-are-guarded.md): outbound calls are bounded, and
  calls to caller-supplied URLs are guarded.
