# 0121. Every HTML page the application writes has a strict Content-Security-Policy and is framed only by design

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

This decision applies to projects that host ASP.NET Core and write HTML pages. An API that returns only JSON skips it.

A page any origin can frame is a clickjacking target: an attacker's page overlays it and steers the user's clicks and
keystrokes. A page without a Content-Security-Policy runs any script an injection manages to place in it. Several
forces bear on how pages are protected:

- Framework components set some headers only incidentally. ASP.NET Core antiforgery adds `X-Frame-Options: SAMEORIGIN`
  only to a response on which it stores its cookie, so a returning browser that already has the cookie is served the
  same page with no framing policy.
- A page that writes its own headers carries what its author remembered. `frame-ancestors` does not fall back to
  `default-src`, so a policy that lists `default-src` but forgets `frame-ancestors` still allows framing.
- Pages need different policies: a page embedded by design, a page that frames another origin, a page whose form posts
  to another origin.
- Modern front-end bundles use module scripts and libraries that insert `<style>` elements at run time. A policy can
  admit them without `'unsafe-inline'`, which admits every injected script and style too, only by marking them with a
  nonce.

## Decision

Every HTML page states its policy as a value, and one writer sets its security headers. A page starts from a strict
default that allows nothing and forbids framing, and lists only the sources it needs.

1. One model and one writer. A policy type holds a list of directives (a validated name and its sources) and the
   page's framing choice, and renders the header. One extension method, `HttpResponse.SetHtmlPageSecurity(policy)`, is
   the only code that writes a page's security headers. Directives are a list, not a property each, because the CSP
   vocabulary grows.
2. The default is strict. The rendered policy is `default-src 'none'`, then the page's directives, then
   `base-uri 'none'`, `form-action 'self'`, and `frame-ancestors 'none'` unless the page lists them. Directive names
   and sources are validated against the CSP grammar, so no value can inject another directive.
3. Headers are assigned, not appended. The writer sets `Content-Security-Policy`, `X-Frame-Options: DENY` (removed
   when the page allows framing), `X-Content-Type-Options: nosniff`, and `Referrer-Policy: same-origin`, replacing
   anything a framework component added earlier. A page that shows per-user data also sets
   `Cache-Control: no-store`.
4. Scripts and styles are admitted by nonce or hash. A page that runs a bundle uses `script-src 'nonce-N'
   'strict-dynamic'` and `style-src 'nonce-N'`, where N is 16 random bytes, base64url-encoded, created per response. The
   bundle build writes a placeholder nonce on its script and preload tags (Vite: `html.cspNonce`) and exposes it to
   libraries that insert styles; the server replaces the placeholder in the bundle's own markup only, never inside a
   rendered value. A page with one fixed inline script admits it by its SHA-256 hash.
5. Framing is opt-in per page. A page that is embedded by design lists the origins allowed to frame it in
   `frame-ancestors` (which `X-Frame-Options` cannot express) or, only when any origin may, allows framing outright.
6. `form-action` follows redirects. Browsers check `form-action` against every redirect that follows a form
   submission, so a page whose form submission redirects off-origin either lists those origins or, when they cannot be
   known in advance, omits `form-action`, relying on HTML encoding, nonce-only scripts, and `base-uri`.
7. Not pages, no policy. JSON responses and plain-text answers get no page policy. `Strict-Transport-Security` is a
   transport header and belongs to the pipeline ([ADR-0122](0122-strict-transport-security-outside-development.md)).

## Options considered

- Rely on antiforgery's header. Rejected: it protects a first visit, not a return, and states no script policy.
- One middleware that stamps every `text/html` response. Rejected: pages need different policies, and a middleware
  also clamps pages the application does not own (an API reference UI); a page that states its own policy is read next
  to the markup it describes.
- `script-src 'self'` with `style-src 'unsafe-inline'`. Rejected: admits every injected style and any script the
  origin serves.
- `Referrer-Policy: no-referrer`. Rejected: like `same-origin` it sends no referrer cross-origin, but it makes a
  same-origin form or fetch POST send `Origin: null`, which breaks origin checks.

## Consequences

- Every page's policy is a value a test reads, and a returning browser gets the same headers as a first visit.
- A page added later calls `SetHtmlPageSecurity`; a `text/html` write that does not is a defect.
- A bundle built without the nonce placeholder runs none of its scripts, so the placeholder is a contract between the
  front-end build and the server, covered by a test of the built bundle.
- `Cross-Origin-Opener-Policy` and `Permissions-Policy` are decided per application, since some flows (pop-up sign-in)
  need `window.opener`.

## References

- [Content Security Policy Level 3](https://www.w3.org/TR/CSP3/)
- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)
- [MDN: `form-action`](https://developer.mozilla.org/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/form-action)
- [Vite: `html.cspNonce`](https://vite.dev/config/shared-options#html-cspnonce)
- [ADR-0122](0122-strict-transport-security-outside-development.md): Strict-Transport-Security is sent outside
  Development.
