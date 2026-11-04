# 0145. Outbound calls are bounded, and calls to caller-supplied URLs are guarded against request forgery

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

An application that calls other services inherits their failures. `HttpClient`'s default timeout is 100 seconds, a
retry loop written by hand retries without limit or all at once, and a response read with `ReadAsStringAsync` is held
in memory whatever its size. One slow or hostile dependency then exhausts threads, connections or memory for every
request.

A URL that a user, tenant or client supplies (a webhook endpoint, a metadata document, a key set, an avatar, a callback)
is worse: the application fetches it from inside the network, with the network's reach. A caller who registers
`http://169.254.169.254/` reads the cloud metadata service; one who registers an internal host name probes services
that were never exposed. Common defenses leak:

- Checking the host name, or resolving it and checking the address, before connecting is defeated by DNS rebinding:
  the name resolves to a public address for the check and a private one for the connection.
- Following redirects lets a vetted public URL bounce the request to an internal one.
- Checking `Content-Length` alone lets a response with no length, or a false one, stream without bound.
- A key set or metadata document that many requests need is fetched once per concurrent request, and an unreachable
  source makes every request wait for its timeout.

## Decision

Every outbound call is bounded in time, retries and size; a call to a caller-supplied URL also goes through one guarded
client whose address checks cannot be configured away.

1. Through the factory, bounded. Every outbound HTTP call uses a named or typed client from `IHttpClientFactory`. Each
   client has a timeout per attempt and a total timeout, and its retries are bounded in number, exponential and
   jittered, through `Microsoft.Extensions.Http.Resilience` (`AddStandardResilienceHandler`, or a pipeline configured
   with the same parts). Only idempotent requests are retried: a `POST` is retried only when it carries an idempotency
   key the receiver honors.
2. Size capped while streaming. A response body is read with `HttpCompletionOption.ResponseHeadersRead` and a cap the
   reader enforces as the bytes arrive; `Content-Length` is only a hint for rejecting early.
3. One guarded client for caller-supplied URLs. A named client serves every fetch of, and every delivery to, a URL that
   a user, tenant or client supplied, `POST` deliveries included:
   - only absolute `https` URLs are accepted;
   - its `SocketsHttpHandler.ConnectCallback` resolves the host once, refuses loopback, private, carrier-grade NAT,
     link-local, unique-local, multicast and reserved addresses (IPv4 and IPv6, IPv4-mapped included), and connects to
     the address it vetted, so the name cannot be resolved again to another;
   - `AllowAutoRedirect` is `false`, so a redirect is a failed call;
   - this address floor has no setting that turns it off; configuration may only add denied ranges or an allow-list of
     hosts that narrows it further.
4. Shared fetches are single-flight. A remote resource that many requests share (a metadata document, a key set, a
   revocation list) is fetched once for all concurrent misses: callers share one task, keyed by the resource, which
   runs with `CancellationToken.None` bounded by its own timeout, so one caller's cancellation does not fail the others.
   Each caller waits on it with `WaitAsync(cancellationToken)`.
5. Failures are remembered briefly. A fetch that fails is remembered for a short, configured time, during which
   requests do not retry it. A refresh that fails may serve the last good value within a configured stale lifetime;
   validation is never relaxed to make a stale or partial value acceptable.
6. Limits are options. Timeouts, size caps, failure and stale lifetimes are options validated when the host starts
   ([ADR-0106](0106-configuration-binds-strictly-and-is-validated-at-startup.md)). A delivery that must not be lost
   runs from the outbox ([ADR-0141](0141-side-effects-after-a-commit-go-through-an-outbox.md)), whose retry wraps the
   client's.

## Options considered

- Default `HttpClient` settings. Rejected: a 100-second timeout and unbounded bodies let one dependency exhaust the
  service.
- Validate the URL's host or resolved address before the request. Rejected: DNS rebinding and redirects bypass it.
- An allow-list of hosts as the only defense. Rejected as the floor: it is a setting, and an empty or wide list removes
  the protection. It remains an optional narrowing.
- An outbound proxy that enforces the policy. Not chosen as the default: it is infrastructure a project may add, and
  the application's own floor still holds without it.
- Bounded clients, a guarded client with a fixed address floor, single-flight shared fetches (chosen).

## Consequences

- A slow or hostile dependency costs each request at most its timeout and its size cap.
- A caller-supplied URL cannot reach the private network, through a redirect or a rebinding name either.
- A receiver whose endpoint redirects, or serves plain `http`, is refused; it registers its final `https` URL.
- Tests of the guarded client use a stub handler for the transport and a separate test of the address floor.

## References

- [OWASP Server-Side Request Forgery Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)
- [Build resilient HTTP apps](https://learn.microsoft.com/dotnet/core/resilience/http-resilience)
- [`SocketsHttpHandler.ConnectCallback`](https://learn.microsoft.com/dotnet/api/system.net.http.socketshttphandler.connectcallback)
- [ADR-0106](0106-configuration-binds-strictly-and-is-validated-at-startup.md): configuration binds strictly and is
  validated when the host starts.
- [ADR-0141](0141-side-effects-after-a-commit-go-through-an-outbox.md): side effects after a commit go through an
  outbox.
- [ADR-0144](0144-correctness-guards-fail-closed-capacity-guards-fail-open.md): correctness guards fail closed,
  capacity guards fail open.
