# 0126. Published URLs come from a configured origin, never from the request's Host header

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

This decision applies to projects that host ASP.NET Core and publish absolute URLs.

An application hands out absolute URLs in many places: links in emails, callback and redirect URLs it gives to another
party, discovery and metadata documents, the base URL in a front end's bootstrap configuration, an issuer or audience
value that other systems compare byte for byte. ASP.NET Core makes the request's own origin the easy source for all of
them: `HttpRequest.Host` and `Scheme`, and `LinkGenerator.GetUriByName(HttpContext, ...)`, which builds from them.

The `Host` header is chosen by the client, and so is `X-Forwarded-Host` unless a proxy overwrites it. A URL built from
either is an attacker's URL:

- A password-reset email built from the request's host sends the reset token to whatever host the attacker's request
  named.
- A metadata document whose identity value is configured, but whose endpoint URLs come from the request, looks genuine
  to a client that checks the identity, and points the client's credentials at the attacker.
- A shared cache that keys a response by path alone serves one host's document to every host.

The conventions accept a forwarded value only from a proxy the host trusts; that decides which client address and
scheme to believe, not where the application is published.

## Decision

Every absolute URL the application publishes is built from a configured, validated origin, through one service; the
request contributes nothing to it.

1. A configured origin. The public origin (scheme, host, optional port and base path) is an option, validated when the
   host starts ([ADR-0106](0106-configuration-binds-strictly-and-is-validated-at-startup.md)) as an absolute `https`
   URI outside Development. A multi-tenant or multi-origin application stores each origin with the record it belongs
   to, validates it on write, and builds from the stored value of the record the request resolved.
2. One service builds them. A single service turns a route or path into an absolute URL from that origin, for
   example with `LinkGenerator.GetUriByAddress` given the configured scheme, host and path base. No other code reads
   `HttpRequest.Host` or `Scheme` to build a URL. A link within the same origin may stay relative.
3. `AllowedHosts` is explicit. Outside Development, host filtering lists the host names the application serves, and a
   wildcard refuses to start ([ADR-0119](0119-production-refuses-development-only-settings.md)). Health probes send an
   allowed `Host` ([ADR-0128](0128-liveness-never-checks-dependencies-readiness-does.md)).
4. A response that varies by host is not cached. When an application answers several hosts and a response's content
   depends on which, the response carries `Cache-Control: no-store`, so no shared cache serves it for another host.
5. Forwarded headers from known proxies only. `UseForwardedHeaders` trusts only the proxies and networks listed in its
   options; with none listed it trusts none beyond loopback
   ([ADR-0144](0144-correctness-guards-fail-closed-capacity-guards-fail-open.md)). A forwarded host, even from a
   trusted proxy, never builds a published URL.
6. No origin, no URL. When no origin is configured for what the request needs, the endpoint fails with an error that
   names the setting; it never falls back to the request's origin outside Development.

## Options considered

- Build from the request and validate `Host` against `AllowedHosts`. Rejected as the control: `AllowedHosts` is one
  setting, often `*`, and a value it admits is still the client's choice among several names.
- Build from the forwarded host when a proxy is present. Rejected: it moves the trust to a header and to every proxy
  configuration.
- A configured origin, used by one service (chosen). The published URL is the one the operator chose, whatever the
  request says.

## Consequences

- A forged `Host` or `X-Forwarded-Host` cannot change a link, a redirect target or a published document.
- Every deployment configures its public origin, and a missing one is an error at startup or at the request that needs
  it, not a silently wrong link.
- Tests of published URLs configure an origin that differs from the test server's host, or they prove nothing.
- An application reachable under several names publishes one of them; the others serve but are never handed out.

## References

- [Host filtering in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/servers/kestrel/host-filtering)
- [Configure ASP.NET Core to work with proxy servers and load balancers](https://learn.microsoft.com/aspnet/core/host-and-deploy/proxy-load-balancer)
- [OWASP Web Security Testing Guide: Testing for Host Header Injection](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/07-Input_Validation_Testing/17-Testing_for_Host_Header_Injection)
- [ADR-0119](0119-production-refuses-development-only-settings.md): Production refuses development-only settings.
- [ADR-0128](0128-liveness-never-checks-dependencies-readiness-does.md): liveness never checks dependencies; readiness
  does.
- [ADR-0144](0144-correctness-guards-fail-closed-capacity-guards-fail-open.md): a list that grants trust starts empty.
