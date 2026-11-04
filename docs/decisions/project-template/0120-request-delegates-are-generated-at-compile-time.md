# 0120. Minimal-API request delegates are generated at compile time

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

This decision applies to projects that host ASP.NET Core and map minimal-API endpoints. Other projects ignore the
setting it describes.

With runtime binding, ASP.NET Core's `RequestDelegateFactory` builds an expression tree for each endpoint at every host
start, and compiles it to a dynamic method. Dynamic methods skip tiered compilation, so the JIT compiles each one fully
optimized before the endpoint answers its first request. Production pays this on every cold start and every scale-out
replica; an integration test suite that starts a host per test pays it again for every host, and with many endpoints
the JIT dominates the suite's run time.

The Request Delegate Generator (RDG) is the ASP.NET Core source generator that emits the same request delegates at
compile time. It intercepts each `Map*` call with a C# interceptor, which works only in the project that makes the
call, so it is enabled per project. It reports a warning for a handler shape it cannot generate.

RDG has a known behavioral gap in ASP.NET Core 10.0: its generated form binding reads the form without checking
`IAntiforgeryValidationFeature`. For a request whose antiforgery validation failed, reading the form then throws, and
the endpoint answers 500 instead of the runtime factory's 400.

## Decision

Every project generates its minimal-API request delegates at compile time, except a project with form-bound endpoints,
which binds at runtime until the generated form binding honors antiforgery validation.

1. On by default. `build/ProjectTemplate.props` sets
   `<EnableRequestDelegateGenerator>true</EnableRequestDelegateGenerator>` for every project; only the Web SDK reads
   it, so every project that maps endpoints gets generated delegates without opting in.
2. Form-bound projects opt out. A project with an endpoint that binds `[FromForm]`, `IFormFile`, or `IFormCollection`
   sets `<EnableRequestDelegateGenerator>false</EnableRequestDelegateGenerator>` in its project file, with a comment
   naming this decision. Every such endpoint has an integration test that posts without the antiforgery token and
   expects a 4xx response and no change. The opt-out is removed when an SDK update closes the gap and those tests pass
   with the generator on.
3. An unsupported handler shape fails the build. RDG's diagnostics are warnings, and warnings are errors
   ([ADR-0100](0100-warnings-are-errors-in-every-project.md)), so a handler RDG cannot generate stops the build instead
   of silently falling back to runtime binding.

## Options considered

- Runtime binding with one shared test host. Rejected: it gives up per-test isolation and does nothing for production
  cold starts.
- Native AOT for the whole application. Out of scope here: it implies RDG but brings many other constraints; a project
  that needs it records that decision separately.
- Compile-time generation (chosen). It removes expression-tree compilation from every host start, in tests and in
  production, for one build property.

## Consequences

- Hosts start faster and integration suites that start many hosts run much faster.
- A new endpoint whose handler shape RDG cannot generate fails the build; the fix is a supported shape, not a
  suppression.
- A new form-bound endpoint in a project that generates delegates is the smell this decision guards against: move it,
  or opt the project out and add the no-token test.

## References

- `build/ProjectTemplate.props`
- [Request Delegate Generator](https://learn.microsoft.com/aspnet/core/fundamentals/aot/request-delegate-generator/rdg)
- [Antiforgery with minimal APIs](https://learn.microsoft.com/aspnet/core/security/anti-request-forgery#antiforgery-with-minimal-apis)
- [ADR-0100](0100-warnings-are-errors-in-every-project.md): warnings are errors in every project.
