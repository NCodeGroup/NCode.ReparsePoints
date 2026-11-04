# NCode.ReparsePoints Metrics and Traces

This catalog is the contract for every metric and span NCode.ReparsePoints defines. Dashboards and alerts are built
against it, so a change that adds, renames or removes a meter, an instrument, an attribute, an attribute value, an
activity source or a span updates this file in the same pull request. The reasons behind the rules are in
[ADR-0113](decisions/project-template/0113-metrics-have-one-owner-per-signal-and-bounded-dimensions.md) and
[ADR-0114](decisions/project-template/0114-one-activity-source-named-like-its-meter.md).

## What Belongs Here

- Every meter and instrument the project's code creates, with its unit and attributes.
- Every attribute the project adds to a built-in instrument, such as the request instrument
  `http.server.request.duration` through `IHttpMetricsTagsFeature`.
- Every activity source and span the project's code starts.

Built-in instruments and spans of .NET and ASP.NET Core are not listed unless the project enriches them.

## Naming Rules

- A meter and an activity source are named after the project that owns them, as public constants sharing one root
  (`Product.Area`), so a host subscribes to all of them with one wildcard (`Product.*`).
- An instrument is named `{product}.{area}.{name}` in lowercase dotted form; an attribute that the OpenTelemetry
  semantic conventions define keeps its standard name (`error.type`, `http.route`).
- Units are UCUM: a duration is a histogram in seconds (`s`), and a count uses an annotation (`{request}`, `{item}`).
- A span is named after the duration histogram it mirrors, without the `.duration` suffix, and carries the same
  attributes.
- Every attribute value comes from a vocabulary the project defines; a value from a request that is not a known member
  is recorded as `_OTHER`. No attribute carries an identifier of a user, customer or resource, a remote address, or a
  secret.

## Meters and Instruments

| Name | Type | Unit | Attributes and their values | Owner |
| --- | --- | --- | --- | --- |

## Activity Sources and Spans

| Activity source | Span | Mirrors histogram | Attributes and their values | Owner |
| --- | --- | --- | --- | --- |
