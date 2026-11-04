# 0129. Browser-facing requests are safe by construction

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

This decision applies to projects that host ASP.NET Core. Decisions 1 to 4 apply to endpoints a browser reaches with
cookies; decisions 5 and 6 apply to every API.

A browser sends the user's cookies with requests the user never meant to make, follows any redirect it is given, and
lets sibling subdomains set cookies for the parent domain. An API binds whatever fields a request body carries. Each of
these turns an ordinary endpoint into a vulnerability unless it is built to refuse:

- A sign-in page that redirects to a `returnUrl` parameter as given is an open redirect: a link on the real domain
  that lands the user on an attacker's page, often a copy of the sign-in form.
- A `GET` that changes state (sign out, approve, delete) runs when a link is prefetched, crawled, or embedded in an
  image tag, and `SameSite=Lax` cookies are sent with top-level `GET` navigations from other sites.
- A cookie-authenticated form post without an antiforgery token can be submitted by any page the user visits.
- A cookie without the `__Host-` prefix can be overwritten by a sibling subdomain, fixing the user's session to one
  the attacker knows.
- A handler that binds an entity from the request body lets the caller set fields the server owns: the owner, the
  tenant, the role, the status.
- A handler that loads a resource and then checks access has already read another caller's data, and one that answers
  `403` tells a stranger that the resource exists.

## Decision

1. Local return URLs only. A return URL is followed only when `Url.IsLocalUrl` accepts it, through `LocalRedirect` or
   `Results.LocalRedirect`; any other value is replaced by the application's root. A return URL kept across a sign-in
   round trip passes the same check when it is restored. A redirect to another origin goes only to a URL registered for
   that purpose and compared exactly.
2. No state change on `GET`. `GET` and `HEAD` are safe: they read and never change state. Signing out, approving,
   deleting and every other change use `POST` or another unsafe method.
3. Antiforgery on cookie-authenticated writes. A form post authenticated by a cookie validates an antiforgery token
   (`UseAntiforgery` and form binding, or Razor Pages and MVC's automatic validation), and no endpoint disables it
   without a recorded reason. A JSON endpoint authenticated by a cookie requires a custom request header, which a
   cross-site page cannot send without a CORS preflight, and refuses a request whose `Sec-Fetch-Site` is `cross-site`.
   An endpoint authenticated by a bearer token needs neither.
4. Host-only session cookies. Authentication, session and antiforgery cookies are named with the `__Host-` prefix and
   are `Secure`, `Path=/` and without `Domain`; they are `HttpOnly`, and `SameSite=Lax`, or `Strict` where no
   cross-site navigation needs them.
5. No overposting. A request is bound to a type that holds only the fields the caller may set, never to an entity.
   Server-managed fields (identifier, owner, tenant, role, status, timestamps, concurrency token) come from the
   authenticated context and the stored record, never from the request. State the server showed the caller (a price,
   a set of scopes, an approval's subject) is read again from the store, never trusted from a posted copy.
6. Authorization scopes the read. A query is filtered by what the caller may see in the database
   ([ADR-0107](0107-filtered-reads-push-filtering-to-the-database.md)), so another caller's row is never loaded. A
   resource the caller may not see is answered `404 Not Found`, so its existence cannot be probed; `403 Forbidden` is
   for a resource the caller may see but not change in the way it asked.

## Options considered

- Validate at each endpoint as needed. Rejected: the endpoint that forgets is the vulnerable one, and review rarely
  sees the omission.
- Rely on `SameSite` cookies alone against cross-site requests. Rejected: `Lax` cookies are sent with top-level `GET`
  navigations, and a sibling subdomain is same-site.
- Bind entities directly and ignore unexpected fields. Rejected: the binder sets whatever matches, and an ignore list
  is out of date the day a field is added.
- Load, then check access, and answer `403`. Rejected: the row is in memory before the decision, and `403` confirms the
  resource exists.
- Safe defaults built into every endpoint's shape (chosen).

## Consequences

- An open redirect, a cross-site state change, a fixed session and an overposted field each need a deliberate,
  visible exception to appear.
- Every write endpoint has a request type of its own, separate from the stored entity and from the response type.
- A caller who lacks access sees the same `404` as for a resource that does not exist, so support works from logs, not
  from the status code.

## References

- [Prevent open redirect attacks in ASP.NET Core](https://learn.microsoft.com/aspnet/core/security/preventing-open-redirects)
- [Prevent Cross-Site Request Forgery attacks in ASP.NET Core](https://learn.microsoft.com/aspnet/core/security/anti-request-forgery)
- [MDN: cookie prefixes](https://developer.mozilla.org/docs/Web/HTTP/Reference/Headers/Set-Cookie#cookie_prefixes)
- [OWASP Mass Assignment Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html)
- [ADR-0107](0107-filtered-reads-push-filtering-to-the-database.md): filtered reads push their filter into the database.
- [ADR-0121](0121-html-pages-have-a-strict-content-security-policy.md): every HTML page has a strict
  Content-Security-Policy.
- [ADR-0123](0123-resource-ids-are-server-generated-and-opaque.md): resource identifiers are server-generated and
  opaque.
