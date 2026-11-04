# 0106. Configuration binds strictly and is validated when the host starts

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

The .NET configuration binder ignores keys that map to no property. A misspelled key, a key placed under the wrong
section, or a key left behind by a refactor is therefore indistinguishable from an absent key: the host starts, serves
traffic, and looks healthy while the setting is discarded. It behaves only as long as the default happens to match what
the configuration asked for, and an operator who copies that shape with a non-default value has the setting ignored
with no signal.

A related class of error fails late instead of silently. Options are bound and validated on first use by default, so a
value the application cannot honor (an unknown mode, a malformed pattern, a relative URL where an absolute one is
needed, a zero or negative timer period) is discovered by the first request or background run that needs it, after
health checks have reported the instance ready.

## Decision

A key that maps to no option stops the host from starting, and so does a value the application cannot honor. Both are
checked before the host accepts traffic.

1. Strict binding. Every options type bound from configuration is bound with
   `BinderOptions.ErrorOnUnknownConfiguration = true`, at every depth, through one helper that names the offending
   section and key:
   `services.AddOptions<SmtpOptions>().Bind(section, o => o.ErrorOnUnknownConfiguration = true).ValidateOnStart();`
2. One owner per section. A configuration section is bound by one options type, which declares its whole shape. Code
   that needs a value from it takes the options, not the raw section. A library's extension does not add keys to a
   section the library binds; it binds its own section.
3. Validated on start. Every bound options type is registered with `ValidateOnStart()`. Rules beyond types live in an
   `IValidateOptions<T>` implementation (or data annotations, for simple ranges) that checks the whole object and
   reports every failure with the configuration key. A validator takes no constructor dependencies on other options,
   which can deadlock the host while it starts. A period that a timer runs on is checked against the range the timer
   accepts, so a bad interval stops the host instead of faulting a background service later.
4. Only the selected variant is validated. When options select one of several strategies, each with its own
   subsection, only the selected strategy's subsection is validated. Configuration layers cannot delete a key from a
   lower layer, so rejecting an unselected strategy's subsection would stop an environment overlay from switching
   strategies.
5. A failed reload keeps the previous values. When configuration reloads while the host runs (a changed file, a
   refreshed secret store), the new values are validated as a whole before any is applied. A reload that fails
   validation is logged at Error with every failure and its key, and the values loaded before stay in force: a running
   host cannot refuse to start, and applying part of a reload is worse than applying none of it. Code that reacts to
   changes reads a validated snapshot (`IOptionsMonitor<T>` over validated options), never the raw sections.
6. One rule set for every entry point. A rule about what the application can honor is written once and applied
   wherever the value enters: startup configuration, an API write, a seeder, an import. An API write that breaks it is
   answered `400` with a validation problem keyed by field, before any check against stored state; invalid seed data
   stops the host with an error that names the entry. Stored data that no longer passes the rules fails closed when it
   is read, rather than being loaded without the part that broke.

## Options considered

- Fix each misconfiguration as it is found. Rejected: it repairs the instance and keeps the defect class.
- Strict binding that fails on first use. Rejected: the instance passes readiness checks and fails on live traffic,
  the worst moment to learn of a configuration error.
- Rejecting the options of unselected strategies. Rejected for the layering reason above.
- Applying the valid part of a reload. Rejected: settings that only make sense together would be half changed.
- Separate validation for configuration and for API writes. Rejected: the two copies drift, and a value refused at one
  entry point is stored through another.

## Consequences

- A misspelled or misplaced key stops the host with an error naming the section, the options type, and the key.
- Every key in `appsettings*.json`, environment variables, and deployment manifests must map to an option; stale keys
  are removed rather than tolerated.
- Configuration consumed directly through `IConfiguration["..."]` bypasses all of this; it is reserved for host
  bootstrap code that runs before options exist.
- A bad edit to a reloadable source leaves the host running on its previous configuration, with an error in the log
  that an operator alerts on.
- A value that one entry point accepts is accepted by all of them, and one that one refuses is refused by all.

## References

- [Options pattern in .NET](https://learn.microsoft.com/dotnet/core/extensions/options)
- [Options validation](https://learn.microsoft.com/dotnet/core/extensions/options#options-validation)
- [`BinderOptions.ErrorOnUnknownConfiguration`](https://learn.microsoft.com/dotnet/api/microsoft.extensions.configuration.binderoptions.erroronunknownconfiguration)
