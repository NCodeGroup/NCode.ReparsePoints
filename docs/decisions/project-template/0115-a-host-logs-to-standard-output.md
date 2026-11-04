# 0115. A host logs to standard output, one JSON line per entry where a collector reads it

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

`WebApplication.CreateBuilder` and `Host.CreateApplicationBuilder` register the console, debug and EventSource logging
providers, and on Windows the Event Log provider too, so the sinks a host writes to depend on the operating system it
runs on. On a developer machine or a CI runner on Windows, every warning and error of a host, or of a test that starts
one, goes to the machine's Application log. The Event Log provider also throws on a write after it is disposed, which
makes tests that tear a host down fail at random.

Where a host runs under a container runtime or a service manager, a log collector reads standard output a line at a
time. The console provider's default `simple` format spreads one entry over several lines (level and category, message,
then each line of an exception), so the collector splits one entry into several records and the exception lands in a
different record from the error it explains.

This decision applies to a project with an executable host: a web application, a worker service or a tool that runs as
a service. A library has no host.

## Decision

1. A host chooses its logging providers explicitly, the same on every operating system:
   `builder.Logging.ClearProviders().AddConsole()`, plus `AddEventSourceLogger()` so `dotnet-trace` and `dotnet-monitor`
   can collect logs when attached. The console writes to standard output.
2. The console's format is configuration (`Logging:Console:FormatterName`), not code.
3. Where a machine reads the output, the artifact that runs the host selects the `json` formatter with UTC timestamps in
   round-trip format, so each entry, its exception and stack trace included, is one JSON object on one line. For a
   container image that is its environment: `Logging__Console__FormatterName=json`,
   `Logging__Console__FormatterOptions__UseUtcTimestamp=true` and
   `Logging__Console__FormatterOptions__TimestampFormat=O`. The format belongs to the artifact, not to one deployment of
   it, so the image writes the same lines however it is run.
4. A run a person reads (`dotnet run`, the debugger, a test) keeps `simple`. An operator who wants text from the
   artifact overrides the formatter through the environment.
5. A library never registers or removes a logging provider. A host that needs another sink, such as the Event Log of a
   Windows service, adds it in its own composition root.

## Options considered

- Keep the defaults. Rejected: the sinks depend on the platform, and the Windows sink fills the machine's Event Log and
  breaks test teardown.
- Remove only the Event Log provider. Rejected: the debug provider writes only to an attached debugger, which a
  container never has; the provider set should be stated, not subtracted from.
- Set the JSON format in each deployment's configuration. Rejected: the same artifact run another way would write text.
- A library extension that chooses providers or the format. Rejected: a library would be choosing its host's sinks.

## Consequences

- No host or test writes to the Windows Event Log, and the provider set is the same on every machine; a test can pin it.
- A collector keeps an entry and its exception in one record and can index level, category and event ID as fields.
- Raw container logs are JSON, harder to read by eye; an operator reading them directly switches the formatter.
- Exporting logs over OTLP is a separate decision.

## References

- [Console log formatting](https://learn.microsoft.com/dotnet/core/extensions/console-log-formatter)
- [The Twelve-Factor App: logs](https://12factor.net/logs)
