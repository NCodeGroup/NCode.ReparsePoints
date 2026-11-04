# 0119. Production refuses development-only settings and reports them all at once

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

A host that is pleasant to run on a laptop needs conveniences that are dangerous anywhere else: signing or encryption
keys generated at startup, seed data and test clients, a permissive CORS policy for a front-end dev server, a secret
written inline in `appsettings.Development.json`, an in-memory Data Protection key ring, a wildcard `AllowedHosts`.
Each is right in Development, and each reaches Production in a predictable way:

- It is registered by default, by a method every host calls, so a production host gets it unless someone remembers to
  turn it off.
- It is gated by an environment check at its own registration, so each convenience is safe only as far as its author
  remembered the check, and one added later is not.
- A development overlay is copied into a production deployment, or an environment variable is set wrong, and every
  guardrail that the overlay relaxes is dropped together.
- Seed data is written to a database and outlives the process that wrote it, so a seeder that ran once in the wrong
  environment leaves its clients and users behind.
- A library ships one host's values as its defaults (a client id, a dev-server port, an origin), so every consumer
  inherits them.

When a production host does notice such a setting, it usually fails on the first one. An operator then fixes one
finding per deployment, and learns of the next only from the next failure.

## Decision

A development convenience does nothing unless it is configured, and a production host refuses to start while any of
them is configured, naming every finding in one failure.

1. Inert unless configured. Each convenience is an explicit, named opt-in (`AddDevelopmentSeed()`, a `DeveloperCors`
   section) that registers nothing, or does nothing, while its configuration section is absent. A registration that a
   production host also calls never turns one on. A collection option that a convenience reads starts empty, and a
   library carries no host's identifiers as defaults: the host's Development overlay declares them.
2. Through the production path. A convenience writes through the same stores and validators as production code: a
   seeder creates its data through the store, idempotently, rather than intercepting a read, so what Development runs
   is what Production runs, and a re-run changes nothing.
3. One production check. When the host environment is Production, one startup check, registered once in the
   composition root and run before the host accepts traffic, collects every finding and then throws one exception that
   lists them all, each with the configuration key to change. It reports at least:
   - a configured development-only section: a seeder, developer keys, a developer CORS policy, a test client;
   - an ephemeral or local-only key provider, and a Data Protection key ring that is not persisted or not protected
     ([ADR-0127](0127-the-data-protection-key-ring-is-shared-and-encrypted-at-rest.md));
   - a secret written inline in a committed configuration file rather than referenced from a secret store or the
     environment;
   - a wildcard `AllowedHosts` ([ADR-0126](0126-published-urls-come-from-a-configured-origin.md));
   - a setting that selects relaxed guardrails, such as an environment kind or a strictness mode set to a development
     value.
4. Guardrails default safe. A setting that selects guardrails (an environment kind, a "require HTTPS" switch, a
   validation mode) defaults to its strict value when nothing declares it, so a forgotten declaration keeps the
   guardrails. An undeclared host environment is Production, which is the .NET host's own default; nothing in the
   project falls back to Development.
5. One place decides the environments. The check runs in Production. A project whose Staging must behave like
   Production runs it there too, and says so where the check is registered; Development and test hosts are never
   checked.
6. No committed secret. No secret is committed to the repository, not even a development one. A development secret
   comes from user secrets, an environment variable, or a value generated per machine outside the repository.

The check is not options validation ([ADR-0106](0106-configuration-binds-strictly-and-is-validated-at-startup.md)):
validation rejects a value the application cannot honor in any environment, while this check rejects a value that is
valid but meant only for Development.

## Options considered

- An environment check at each registration. Rejected: each convenience is as safe as its author's memory, and the
  rule is spread across the code where no review sees it whole.
- Fail on the first finding. Rejected: an operator learns the findings one deployment at a time.
- Rely on deployment review to catch development settings. Rejected: a development overlay copied into a deployment
  looks like ordinary configuration.
- No development conveniences. Rejected: a host that needs a key store, seed data and a front end before it answers a
  request is slow to run locally, and people work around it with worse shortcuts.
- Inert opt-ins and one production check that reports everything (chosen).

## Consequences

- A development convenience copied into Production stops the host before it serves, with a message that lists every
  setting to remove.
- Adding a convenience means adding its finding to the check in the same change; a convenience the check does not know
  is a defect.
- A host started without an environment gets Production's guardrails, so a developer sets `ASPNETCORE_ENVIRONMENT` or
  `DOTNET_ENVIRONMENT` to `Development` (as `launchSettings.json` does) to get the conveniences.
- Tests that start the host in Production supply production-shaped configuration, or assert the refusal.

## References

- [Use multiple environments in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/environments)
- [Safe storage of app secrets in development](https://learn.microsoft.com/aspnet/core/security/app-secrets)
- [ADR-0106](0106-configuration-binds-strictly-and-is-validated-at-startup.md): configuration binds strictly and is
  validated when the host starts.
- [ADR-0126](0126-published-urls-come-from-a-configured-origin.md): published URLs come from a configured origin.
- [ADR-0127](0127-the-data-protection-key-ring-is-shared-and-encrypted-at-rest.md): the Data Protection key ring is
  shared, encrypted at rest and checked at startup.
