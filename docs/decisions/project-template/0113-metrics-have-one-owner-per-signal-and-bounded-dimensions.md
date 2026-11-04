# 0113. Metrics have one owner per signal and only bounded dimensions

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

.NET and ASP.NET Core already emit metrics through `System.Diagnostics.Metrics`, which OpenTelemetry reads:
`http.server.request.duration` for every inbound request, `http.client.request.duration` for every outbound
`HttpClient` call, plus Kestrel, routing, rate limiting, and runtime instruments. An application adds its own
instruments for what those do not see. Four forces shape how:

- A signal must not be counted twice. A second counter of the same fact drifts from the first and doubles the series a
  deployment pays for.
- Cardinality must stay bounded by the application, not by its data. Users, customers, order ids, and remote addresses
  are unbounded; a series per user grows until the metrics backend drops data or bills for it.
- Request input must never name a series. An attribute whose value comes from the request lets any caller create
  series at will.
- Libraries must not force a telemetry SDK on their consumers.

## Decision

Every signal has exactly one owner, every metric attribute comes from a vocabulary the application controls, and the
application measures only what the platform does not.

1. One owner per signal. Request count, latency, and status are ASP.NET Core's `http.server.request.duration`; outbound
   calls are `System.Net.Http`'s instrument, through named or typed `HttpClient`s. The application does not add its own
   request counter or duration histogram. It enriches the built-in request instrument with bounded attributes through
   `IHttpMetricsTagsFeature` (for example the domain outcome of an endpoint). A domain outcome is counted once, where it
   is decided; if the application has an audit or event pipeline, the count derives from it rather than from a parallel
   counter at the call site.
2. Meters. Each project that owns instruments has one meter named after the project (`Contoso.Ordering`). Meter names
   are public constants sharing one root, so a host subscribes to all of them with one wildcard (`Contoso.*`). Meters
   come from `IMeterFactory`, never `new Meter(...)`, so two hosts in one process (integration tests) never share
   instruments. A project's instruments live in one internal singleton metrics class created from the factory's meter;
   call sites call its methods, never `Meter` APIs.
3. Names and units. Instrument and attribute names share a lowercase dotted namespace
   (`contoso.ordering.checkout.duration`). An attribute that the OpenTelemetry semantic conventions define keeps its
   standard name (`error.type`, `http.route`). Units are UCUM: durations are histograms in seconds (`s`) with explicit
   bucket advice; counts use an annotation (`{order}`, `{request}`).
4. Bounded attributes only. An attribute value is a member of a vocabulary the application defines: an enum-like name,
   a registered kind, an error code ([ADR-0111](0111-failures-carry-a-machine-readable-code.md)). A value from the
   request that is not a known member is recorded as `_OTHER`. Identifiers of users, customers, and resources, and
   remote addresses, are never metric attributes; they belong on traces and logs, where cardinality has no per-series
   cost, and a metric exemplar links a slow bucket to its trace. Per-customer usage that the business needs (billing,
   quotas) is stored data, not a metric.
5. Hosts opt in. Library projects depend only on `System.Diagnostics.Metrics`; recording costs nothing until a listener
   subscribes. The host adds the OpenTelemetry SDK, subscribes to the application's meters and the built-in .NET ones,
   and adds the OTLP exporter only when `OTEL_EXPORTER_OTLP_ENDPOINT` is configured, so a host without a collector does
   not retry a missing endpoint. A view drops unbounded attributes from built-in instruments when the application calls
   arbitrary hosts (`server.address` on outbound calls).
6. Tested and catalogued. Each instrument has a unit test that reads it through `MetricCollector<T>` and asserts its
   name, unit, and attributes. The catalog `docs/metrics.md`, which the project owns and the template starts empty,
   lists every meter, instrument, unit, and attribute with its allowed values, and every activity source and span
   ([ADR-0114](0114-one-activity-source-named-like-its-meter.md)), so dashboards and alerts are built against a
   reviewed contract. A change that adds or renames an instrument, an attribute or a span updates the catalog in the
   same pull request.

## Options considered

- An application request counter and histogram per endpoint. Rejected: duplicates `http.server.request.duration` and
  can disagree with it.
- A counter per domain outcome at each call site. Rejected where an event or audit pipeline already observes the
  outcome: two counts drift.
- An opt-in per-customer attribute. Rejected: whoever enables it multiplies every series by the customer count.
- Depending on the OpenTelemetry API in libraries. Rejected: `System.Diagnostics.Metrics` is the .NET instrumentation
  API; a library that depends on the SDK forces it on every consumer.

## Consequences

- Latency, traffic, and errors per endpoint and outcome come from one histogram, on which service-level indicators are
  built.
- The number of series is bounded by the application's vocabularies, not by its data.
- Adding or renaming an instrument or attribute is a deliberate change to the catalog and its tests.

## References

- [OpenTelemetry semantic conventions for HTTP metrics](https://opentelemetry.io/docs/specs/semconv/http/http-metrics/)
- [ASP.NET Core built-in metrics](https://learn.microsoft.com/aspnet/core/log-mon/metrics/built-in)
- [.NET metrics instrumentation: `IMeterFactory` and `MetricCollector<T>`](https://learn.microsoft.com/dotnet/core/diagnostics/metrics-instrumentation)
- [ADR-0114](0114-one-activity-source-named-like-its-meter.md): one activity source per project, named like its meter.
