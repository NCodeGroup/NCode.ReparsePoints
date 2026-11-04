# 0114. A project traces its own mechanisms through one activity source named like its meter

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

ASP.NET Core already traces each inbound request and `System.Net.Http` each outbound call, so a request is traced
end to end without application code. What those spans cannot show is latency that hides inside a request: waiting for a
lock or a lease, a cache miss and its fill, a store operation behind an abstraction, a retry loop. Without spans of its
own, a slow request shows only its outbound calls, not the waits around them.

[ADR-0113](0113-metrics-have-one-owner-per-signal-and-bounded-dimensions.md) settles how the application measures: one
owner per signal, one meter per project, bounded attributes. Traces need the same discipline, or spans duplicate the
platform's, carry unbounded or sensitive values, and use a vocabulary different from the metrics.

## Decision

1. One activity source per project that traces, named like its meter. The name is the project name, a public constant
   beside the meter's name (`OrderingTelemetry.ActivitySourceName = "Contoso.Ordering"`), so a host adds every source
   with one wildcard (`AddSource("Contoso.*")`). The source is a static `ActivitySource`: unlike a meter it has no
   factory, and it costs nothing until a listener samples it.
2. A project traces only its own mechanisms. It never adds a span for what ASP.NET Core or `System.Net.Http` already
   traces. Its spans wrap the work around those: waits, store operations, retries.
3. A span mirrors a histogram. Each span measures what one of the project's duration histograms measures, is named
   after it without the `.duration` suffix (`contoso.ordering.checkout`), and carries the same bounded attributes. A
   failure sets the span status to `Error` and `error.type`, as the histogram does. One vocabulary describes both
   signals, and the metrics catalog, `docs/metrics.md`, lists both.
4. A span carries no secret and no personal data: no token, key, cookie, session handle, password, user or customer
   identifier, or request path. Traces could carry higher-cardinality values than metrics, but correlation with the
   request comes from the parent span, whose own attributes the platform sets.
5. The host opts in. Libraries depend only on `System.Diagnostics`; the host adds the sources to its OpenTelemetry
   tracing pipeline.

## Options considered

- A span per endpoint. Rejected: ASP.NET Core's request span already covers it.
- A span around each outbound HTTP call. Rejected: `System.Net.Http` traces it; the project's span is its parent.
- A span vocabulary independent of the metrics. Rejected: two names for one measurement drift apart.

## Consequences

- A slow request shows its waits and store operations as child spans, each with its result.
- A project that adds a span adds its histogram, or names the one it mirrors, and catalogs both.
- Tests observe spans with an `ActivityListener` filtered to a parent activity the test started, because a static
  source is shared by every test in the process.

## References

- [Distributed tracing instrumentation in .NET](https://learn.microsoft.com/dotnet/core/diagnostics/distributed-tracing-instrumentation-walkthroughs)
- [OpenTelemetry semantic conventions: recording errors](https://opentelemetry.io/docs/specs/semconv/general/recording-errors/)
- [ADR-0113](0113-metrics-have-one-owner-per-signal-and-bounded-dimensions.md): metrics have one owner per signal and
  only bounded dimensions.
