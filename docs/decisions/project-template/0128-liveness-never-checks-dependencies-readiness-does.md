# 0128. Liveness never checks dependencies; readiness does

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

This decision applies to projects that host ASP.NET Core and run behind an orchestrator or load balancer that probes
them.

An orchestrator asks a running instance two different questions. Liveness: is this process stuck, so that restarting it
would help? Readiness: can this instance serve a request now, so that traffic should reach it? A single health endpoint
that checks the database answers both at once, and answers liveness wrongly:

- When the database goes down, every instance fails its liveness probe and is restarted. The restarts fix nothing,
  add cold starts and connection storms, and turn a database outage into an application outage that outlasts it.
- When readiness checks nothing, an instance that cannot reach a dependency it needs keeps receiving traffic and fails
  every request.

A health endpoint that returns the checks' details, such as exception messages, host names or a connection string in
an error, tells anyone who can reach it how the system is built.

## Decision

Liveness and readiness are separate endpoints: liveness checks only the process, readiness checks what a request
needs, and neither shows details to the public.

1. Two endpoints. `MapHealthChecks("/health/live")` and `MapHealthChecks("/health/ready")`, each with a predicate over
   the registered checks' tags. A startup probe, where the orchestrator has one, uses the liveness endpoint.
2. Liveness checks no dependency. Its predicate selects no dependency check. It answers healthy while the process can
   answer HTTP, and a check is added to it only for a state that a restart fixes, such as a deadlocked worker.
3. Readiness checks what requests need. Every dependency that a request cannot be served without is a check tagged
   `ready`: the database, a shared store that a correctness guard needs
   ([ADR-0144](0144-correctness-guards-fail-closed-capacity-guards-fail-open.md)), a downstream service with no
   fallback. Each check has a short timeout. A dependency with a fallback, or one that only a capacity guard uses, is
   not a readiness dependency.
4. Not ready until warmed. Readiness also fails until the host's startup work (loading keys, warming a cache the first
   request needs) has finished, through a check that reads a flag the startup work sets.
5. No details in public. The response is the overall status only. Each check's description and exception go to the
   logs, and a detailed view, when a project wants one, is on a separate endpoint that requires authorization or
   listens only on an internal port.
6. Probes pass host filtering. A probe sends a `Host` header that `AllowedHosts` admits, or the health endpoints are
   mapped with `RequireHost` for the address the orchestrator uses
   ([ADR-0126](0126-published-urls-come-from-a-configured-origin.md)).
7. Draining on shutdown. On a stop signal the host keeps serving for a short, configured delay while the load balancer
   removes it, then shuts down within `HostOptions.ShutdownTimeout`, so requests in flight finish.

## Options considered

- One endpoint that checks everything. Rejected: a dependency outage restarts every instance.
- One endpoint that checks nothing. Rejected: an instance that cannot serve keeps receiving traffic.
- Detailed responses for the orchestrator's convenience. Rejected: the endpoint is anonymous, and the details are
  reconnaissance.
- Separate liveness and readiness, detail-free (chosen).

## Consequences

- A database outage takes instances out of rotation without restarting them, and they return when it recovers.
- A process that hangs is restarted; one that only lacks a dependency is not.
- Adding a dependency means deciding whether it is a readiness check, in the same change.
- Diagnosing a failed probe means reading the logs, which carry the check's name and error.

## References

- [Health checks in ASP.NET Core](https://learn.microsoft.com/aspnet/core/host-and-deploy/health-checks)
- [Kubernetes: configure liveness, readiness and startup probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [ADR-0126](0126-published-urls-come-from-a-configured-origin.md): published URLs come from a configured origin.
- [ADR-0144](0144-correctness-guards-fail-closed-capacity-guards-fail-open.md): correctness guards fail closed,
  capacity guards fail open.
