# 0122. The application sends Strict-Transport-Security outside Development

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

This decision applies to projects that host ASP.NET Core and are served over HTTPS.

`UseHttpsRedirection` redirects a plain-HTTP request to HTTPS, but a redirect protects only the requests that reach it.
A browser given a bare host name, or following an `http://` link, sends its first request in plain text, and an
attacker on the path answers it before the redirect does. HTTP Strict Transport Security closes that window: a browser
that has received `Strict-Transport-Security` over HTTPS sends every later request for the host, and for its
subdomains when the policy includes them, over HTTPS only.

Three facts decide where the header is sent:

- Behind a TLS-terminating proxy, the application sees plain HTTP; it knows a request arrived over HTTPS only from the
  `X-Forwarded-Proto` header of a trusted proxy, which the forwarded-headers middleware applies first.
- RFC 6797 forbids the header on a plain-HTTP response, and browsers ignore it there.
- The framework's `AddHsts` defaults to a `max-age` of 30 days, and its options are neither bound strictly nor
  validated.

## Decision

The pipeline sends `Strict-Transport-Security: max-age=31536000; includeSubDomains` on every response to a request
that arrived over HTTPS, outside the Development environment, as a configuration section sets it.

1. A registration and a pipeline step. The application binds its own `StrictTransportSecurityOptions` strictly from a
   top-level section and validates them at startup
   ([ADR-0106](0106-configuration-binds-strictly-and-is-validated-at-startup.md)), and configures ASP.NET Core's HSTS
   middleware from them. `UseHsts()` runs right after `UseForwardedHeaders()`, so a request a trusted proxy received
   over HTTPS counts as HTTPS.
2. Defaults follow OWASP: `Enabled = true`, `MaxAge` 365 days, `IncludeSubDomains = true`, `Preload = false`.
3. Preload is the domain owner's decision. It commits every subdomain of the registrable domain to HTTPS in browsers'
   built-in lists, and removal takes months. The validator refuses `Preload` without `IncludeSubDomains` or with a
   `MaxAge` under 365 days, as the preload list requires.
4. `MaxAge` may be zero, never negative. `max-age=0` tells browsers to forget the policy, which is how it is withdrawn.
5. Development and loopback hosts never receive it. Nothing is added in Development, where a browser would remember the
   policy for host names a developer also uses for plain-HTTP servers. `localhost`, `127.0.0.1`, and `[::1]` are always
   excluded, and configured excluded hosts are host names or addresses without a scheme or port.
6. One component owns the header. A deployment whose proxy sends `Strict-Transport-Security` sets `Enabled` to
   `false`; otherwise the proxy is trusted for forwarded headers and the application sends it.

## Options considered

- `AddHsts` and `UseHsts` with framework defaults. Rejected: a 30-day `max-age` and no validation.
- Binding `HstsOptions` directly from configuration. Rejected: binding appends configured hosts to its default
  excluded hosts, and nothing checks the preload requirements.
- Setting the header per page. Rejected: the policy protects every request to the host, JSON endpoints included.
- Preload by default, or sending it in Development. Rejected (decisions 3 and 5).

## Consequences

- A browser that has reached the application over HTTPS sends it no plain-HTTP request for a year, subdomains included.
- An operator who serves a subdomain over plain HTTP sets `IncludeSubDomains` to `false`.
- Behind a proxy whose forwarded headers are not trusted, the application sees HTTP and sends no header; the proxy sends
  it, or the deployment trusts the proxy.

## References

- [RFC 6797, HTTP Strict Transport Security](https://www.rfc-editor.org/rfc/rfc6797)
- [OWASP HSTS Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Strict_Transport_Security_Cheat_Sheet.html)
- [Enforce HTTPS in ASP.NET Core](https://learn.microsoft.com/aspnet/core/security/enforcing-ssl)
- [HSTS preload requirements](https://hstspreload.org/)
- [ADR-0106](0106-configuration-binds-strictly-and-is-validated-at-startup.md): configuration binds strictly and is
  validated when the host starts.
- [ADR-0121](0121-html-pages-have-a-strict-content-security-policy.md): every HTML page has a strict
  Content-Security-Policy.
