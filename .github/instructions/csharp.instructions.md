---
description: C# conventions for every C# file, from the project template
applyTo: "**/*.cs"
---

# C# Conventions

These conventions come from the project template, for every `.cs` file. Test projects also follow `.github/instructions/csharp-tests.instructions.md`. The build enforces what a machine can check: warnings are errors, the .NET analyzers run at `latest-recommended`, code style is enforced in the build, and `build/BannedSymbols.txt` bans APIs (RS0030). The reasons behind the rules are in `docs/decisions/project-template/`. Where the project's own instruction files differ, they win.

## Code Style

### Collection Expressions

Use collection expressions instead of array and collection initializers:

```csharp
byte[] data = [1, 2, 3, 4, 5];
List<string> names = ["Alice", "Bob"];
int[] empty = [];
```

Cast where generic type inference needs it, for example `(byte[])[1, 2, 3]` for a `ReadOnlyMemory<T>` parameter.

### Constants for Literals

Declare literal values with `const`, not `var`:

```csharp
const string expected = "hello";
const int count = 5;
```

### UTF-8 String Literals

Use `u8` literals for bytes that hold valid UTF-8 text:

```csharp
var bytes = "Hello"u8.ToArray();
var accented = "café"u8.ToArray();
```

Use explicit byte arrays only for invalid UTF-8 or error-condition tests. A fixed byte label used on every call is a `static ReadOnlySpan<byte> Label => "..."u8;` property, never a `const string` encoded each time.

### Layout

- File-scoped namespaces, one type per file, and a trailing comma on every multi-line initializer, collection or enum list.
- Put constants and statics at the top of the type, before instance members.

## Language and Async

- Async methods return `ValueTask` or `ValueTask<T>`, end in `Async`, and take a `CancellationToken` as the last parameter. Return `Task` only where a framework contract demands it: middleware `InvokeAsync`, a minimal-API handler, or an interface you don't own. Await a `ValueTask` exactly once; call `.AsTask()` when it must be awaited twice or stored.
- Never block on a task. `.Result`, `.Wait()`, `.GetAwaiter().GetResult()`, `Task.WaitAll` and `Task.WaitAny` are banned. Always `await`.
- Don't offload work unless it must leave the calling thread. When it must, use `Task.Run`, never `Task.Factory.StartNew` with an `async` delegate: `StartNew` returns a `Task<Task>` whose inner exceptions are lost.
- Code that runs only under ASP.NET Core or the generic host doesn't use `ConfigureAwait(false)`: neither installs a `SynchronizationContext`, so it does nothing there. A library that UI or other context-bound apps may consume uses `ConfigureAwait(false)` on every `await`.
- An `OperationCanceledException` for `HttpContext.RequestAborted` means the client went away. At an endpoint or middleware boundary, rethrow it; never turn it into an error response, a retry or an audit write.
- A background loop treats an `OperationCanceledException` as a failure unless its own stopping token is cancelled. An `HttpClient` timeout throws `TaskCanceledException` with that token untouched, and under the host's default `BackgroundServiceExceptionBehavior.StopHost` one escaped exception stops the process:

  ```csharp
  catch (Exception exception) when (!stoppingToken.IsCancellationRequested)
  {
      Logger.WorkItemFailed(exception);
  }
  ```

## Nullability and Invariants

- Never use the null-forgiving operator (`!`), not even with a justification comment. Restructure so the compiler proves the value non-null: `?? throw`, `[MemberNotNullWhen]`, an `is { } value` pattern or an early return. The one exception is in test projects: `null!` passes a deliberate null to the code under test, as in an argument-validation test.
- Under `where T : notnull`, `T?` on a value type is plain `T`, not `Nullable<T>`, so `field is null` is always false. Never use such a field as the "has a value" flag for an optional slot; track presence with a `bool`, or constrain to `where T : struct`.
- `Debug.Assert` checks internal invariants only, never input. It is compiled out of Release builds, so an assertion on parsed or caller-supplied data accepts bad data in production. Throw for anything derived from input.
- Validate untrusted text as written, not only as parsed:
  - Anchor a validating regular expression with `\z`, never `$`. In .NET `$` also matches before a trailing newline, so `^[a-z]+$` accepts `"acme\n"`.
  - Carry an identifier compared byte for byte, such as a callback URL or an origin, as a `string` wherever it is stored, compared or sent, and parse a `Uri` only to inspect a part. `Uri` trims whitespace, treats an empty query or fragment as absent, ignores case in the host, and `ToString()` and `AbsoluteUri` normalize it (`myapp://callback` becomes `myapp://callback/`).
- A value that is present but invalid fails closed. Never treat a malformed field or header as if it had not been sent. Reject a parameter or option the code doesn't honor yet; never accept it and ignore it.
- A rule that guards data has one implementation, and every path that accepts that data calls it: configuration at startup, API writes, imports, seeders, and stored data on read. A check that only startup runs lets a runtime write store exactly what startup refuses.

## Members and Constructors

- Prefer auto-properties to fields for state, static or instance, private included. Use a field only for what a property can't be: a `ref`, `Interlocked`, `fixed` or `stackalloc` target. A `Lock` is a property: `private Lock Gate { get; } = new();`.
- Pick the narrowest accessor: `{ get; }` for read-only state, `{ get; init; }` for immutable data, `{ get; set; }` only when mutation is needed. Use an expression body for a simple computed property.
- Use primary constructors wherever they can express the type. Feed the parameters straight into get-only or `init` properties (`public TimeProvider TimeProvider { get; } = timeProvider;`) and put the `<param>` docs on the type. Keep a classic constructor only for several public constructors, an initializer that reads another instance member, or a body with branching, loops or `out`/`ref` work.

## Public API

- `public` is a decision, never a default. Start every type and member at the narrowest visibility that works and widen only for a reason: a contract consumers implement or resolve, an entry point, data they construct. "A test needed it" is not a reason; tests use `InternalsVisibleTo`. An accidental `internal` is a one-line fix; an accidental `public` is a contract you support until the next major version.
- A concrete implementation consumers reach through DI stays `internal`; its interface is the public surface.
- A breaking change to the public surface needs a major version, and so does a change in validation or security behavior a consumer can observe, even when no signature changes. Remove a member by marking it `[Obsolete]` in a minor version, keeping it working, and deleting it in the next major.
- Add, don't change: a new type, member or overload is additive; changing an existing signature (parameters, return type, nullability) breaks callers. Nullability is part of the signature: `string` to `string?` on the public surface is a tracked, potentially breaking change.
- Append members to a wire or `enum` vocabulary; never renumber or reorder them.
- Never share one type between two packages that version independently; keep it in one owner, or duplicate it on purpose.
- A library tracks its public API (`PublicAPI.Shipped.txt` and `PublicAPI.Unshipped.txt` beside each packable project): a public symbol they don't list fails the build (RS0016), and so does a listed one that no longer exists (RS0017). Record a change with `./build/Update-PublicApi.ps1`, which adds the new symbols to `PublicAPI.Unshipped.txt` and lists the stale ones: delete an unshipped line, or mark a shipped symbol removed with a `*REMOVED*` line. The change that releases a version runs `./build/Update-PublicApi.ps1 -Release`, which moves the unshipped entries into `PublicAPI.Shipped.txt`. Prefer the IDE's "Add to public API" code fix or the script to editing by hand; when you edit by hand, write your best guess and let RS0016 and RS0017 dictate the exact text.
- Before a change to a library's public surface, check: it adds rather than alters; new optional inputs are `init` properties; removals go through `[Obsolete]` across a major; the `PublicAPI.Unshipped.txt` diff is in the pull request and intended; a removal or changed signature bumps the major version.
- Required inputs are constructor parameters; optional inputs are `init` properties. Never add an optional value as a new constructor parameter, which breaks binary compatibility once shipped. Model "unspecified" as `null` and resolve the default inside the library.
- A growing set of optional criteria is a type, not more positional parameters: a `readonly record struct` with optional `init` properties, built with an object initializer, so a new criterion is a non-breaking addition. Keep required identity keys positional.

  ```csharp
  public readonly record struct OrderFilter
  {
      public string? CustomerId { get; init; }
      public string? Status { get; init; }
  }

  ValueTask<IReadOnlyList<Order>> FindAsync(OrderFilter filter, PageRequest page, CancellationToken cancellationToken);
  ```

- At most one overload of a method name has optional parameters. Express an optional tail as explicit with- and without-argument overloads.
- A configuration callback takes one growable type, `Action<FooOptions>`, never extra parameters, so a new setting is a property, not a breaking signature change.
- No behavior-selecting flag parameters. A `bool` or `enum` whose only job is to switch a method between two behaviors becomes two intention-revealing methods. A `bool` carried as data is fine.
- `InternalsVisibleTo` is for test projects (and `DynamicProxyGenAssembly2`) only. Production assemblies collaborate through public contracts.
- An `*.Abstractions` assembly holds contracts and data only: no method bodies with logic, no logging.
- A type that is public only so the project's own assemblies can share it is marked `[EditorBrowsable(EditorBrowsableState.Never)]`, and its `<summary>` opens with "This API supports the {product} infrastructure and is not intended to be used directly from your code."
- When a public interface consumers may replace must apply a policy, put the policy behind its own public interface with an internal default, so a replacement resolves the policy instead of skipping it.

## Types and Collections

- Data, options, context, event and result types are `sealed`, with get-only or `init` members and concrete collections. Interfaces exist for replaceable DI seams or read-only slices, not for data.
- Seal by derivation intent, not visibility. A public leaf type is `sealed`; a public type designed for consumers to derive from is not. Never keep a public class unsealed or `public virtual` just so tests can mock it: mock its interface, or make it `internal`.
- Prefer a `readonly record struct` for a small immutable value, such as an id, key, command or outcome. Use a class for reference identity or a large or mutable payload.
- Buffer by default; stream deliberately. Return a lazy `IEnumerable<T>` or `IAsyncEnumerable<T>` only for a large, unbounded, I/O-backed or usually short-circuited sequence. Never return a lazy sequence that captures request state, or one the caller will enumerate twice or count.
- Own every collection you store. A constructor or method that keeps a collection, an injected `IEnumerable<T>` included, copies it once into an immutable collection chosen by use:
  - a lookup or membership set read many times: `FrozenDictionary<TKey, TValue>` or `FrozenSet<T>`;
  - a sequence you iterate: `ImmutableArray<T>` (`Items { get; } = [.. items];`);
  - a genuinely mutable working set: `List<T>`.
- Signatures speak in read-only interfaces; storage stays concrete. A parameter or computed return value uses `IReadOnlyList<T>`, `IReadOnlyCollection<T>` or `IReadOnlySet<T>`. A stored collection property exposes its concrete immutable type. Prefer `params IEnumerable<T>` to `params T[]` and buffer inside.
- A set of named values that other code could extend (kinds, modes, formats) is `public const string` names in a static class, compared ordinally, with behavior in a strategy resolved by name; input naming an unknown member is rejected, never ignored. Document the names as the known values, not all of them. Never `switch` over the names or encode relationships between members (order, compatibility) in code, and never infer a trait from a name (`EndsWith(".json")`): the strategy declares its traits. Validate the registered set when it is composed: an empty or duplicate name, or a reference to an unregistered member, throws an exception that names it. Use an `enum` only when the members are fixed by something that can't grow without this code changing, such as a spec implemented in full or the outcomes of one operation. Never `[Flags]` a set that may grow.
- A persisted or wire value is the member's name, never its ordinal.
- No secret material on the public surface: no secret in a `ToString()`, a public property of a loggable type or an exception message.

## Serialized and Stored Data

- Use `System.Text.Json`; Newtonsoft.Json is banned.
- A DTO that reads, changes and writes back JSON it doesn't own keeps unknown members with `[JsonExtensionData] public Dictionary<string, JsonElement>? ExtensionData { get; set; }`.
- A payload stored at rest evolves additively. A new member is optional (nullable or defaulted), never `required`, because `System.Text.Json` enforces `required` on read and every older row then fails. Enums are written as strings. Never rename, remove or retype a member in place; a non-additive change bumps a schema version stored with the payload and ships an upgrade step from the previous version.
- Parse JSON into a `JsonElement` (`JsonElement.Parse`, or `JsonSerializer.Deserialize<JsonElement>` for a stream); `JsonDocument.Parse` is banned. Check `ValueKind == JsonValueKind.Object` before reading members of JSON from the wire; `TryGetProperty` throws on anything else.
- Format and parse values meant for machines with `CultureInfo.InvariantCulture` and an exact `NumberStyles` (`Integer`, `Float`), never `Any`. Parse a string as a date only where it is declared to be one; never sniff whether text looks like a date (`"1.2"` and `"10:30"` parse).
- Match an opaque, case-significant key (a Base64Url id, a hash, a token) ordinally and verbatim. Case-fold only a value meant to match case-insensitively, such as an email address.
- A structured record the project emits for others to consume (an audit record, a webhook or event payload) is a contract documented in `docs/` and changed in the same change as the code: it carries a schema version bumped on each addition, omits an absent member rather than writing `null`, and uses the same field names in logs, span tags and metric attributes.
- Time arithmetic never overflows: `DateTimeOffset.FromUnixTimeSeconds` throws on out-of-range input, so range-check first; saturate when adding a margin near `DateTimeOffset.MaxValue`, or compare elapsed time instead (`now - issuedAt > limit`).

## File and Code Organization

- One type per file. An interface and its implementation are two files. `IFoo` and `IFoo<T>` may share a file.
- The single implementation of `IFoo` that consumers resolve through DI and never name is `DefaultFoo`, and it is `internal`. Exceptions: one of several variants is named for what makes it specific (`CardPaymentHandler`, `InvoicePaymentHandler`); an implementation of a framework interface follows the framework's naming; a public data or result type consumers construct keeps its plain name even when it implements an interface.
- No nested types, except a private type that must close over the enclosing type's generic parameter, or a nested static class of related `const` values.
- Organize folders by purpose, so a reader finds "the stores" or "the serializers" by folder. Entry points consumers use by name live at the project root. Never create a catch-all folder or namespace (`Helpers`, `Utils`, `Common`, `Misc`, `Logic`); name the group for its purpose, and split a folder that has gathered unrelated purposes. A feature folder holds its contract, its data types and its default implementation, and registers its own services (`AddPricingServices()`).
- Internal types live in a namespace that matches their folder. A library's public namespace is a stable contract: keep it shallow under the root namespace, so moving a public type to another folder doesn't change its namespace.
- Name an interface for its role (`IPaymentHandler`, `IOrderStore`). Add a qualifier only when the bare noun would collide with a well-known framework type.

## DI Registration and Extension Methods

- `Program.cs` is composition only: a flat list of `AddX(...)`, `UseX()` and `MapX()` calls. Once startup needs an `if`, a loop, a policy builder, a `new`, a constant or a configuration read, move that code into the owning project as an `Add*`, `Use*` or `Map*` extension and call it in one line. Only host-specific, unsafe-to-default inputs stay in the host: the database provider and connection string, production secrets, and Kestrel's HTTPS defaults. A library never calls `ConfigureHttpsDefaults`: it keeps only its last action, so it silently replaces, or is replaced by, the host's TLS settings.
- A project registers its own services from one registration class, using `TryAdd*` so a consumer can replace any default; a host replaces one by registering its own before the project's `Add*` call. Register a stateless capability as a singleton and a long-running loop as `AddHostedService<T>` over a `BackgroundService`. Registration stays out of the type that does the work.
- The project that owns a feature registers its framework dependencies (routing, `IHttpClientFactory`, a `TimeProvider`) with `TryAdd*`, so composing it is turnkey. Never rely on a host call that pulls in a dependency by accident.
- Choose the DI shape on purpose: a service (`TryAddSingleton<IFoo, DefaultFoo>()`) for a capability you call for an answer; a strategy collection (`TryAddEnumerable`) for many implementations the caller iterates or selects from; a mediator pipeline only where cross-cutting behaviors wrap every request. When one handler depends on another's effect, state the order explicitly, never through registration order.
- `TryAddEnumerable` keeps one registration per implementation type, an instance's type included, so each built-in strategy is its own class; a second instance of the same class is silently dropped.
- Use C# 14 `extension(Receiver receiver) { ... }` blocks for extension members, with one receiver type per static class (CA1708).
- When two receiver interfaces are unrelated but a concrete type implements both (`IDictionary<,>` and `IReadOnlyDictionary<,>`), write one member on their common base and fast-path the specific types inside. An overload per interface makes every call on the concrete type ambiguous (CS0121).
- Guard the receiver against `null`; extension members can be called on `null`. Pass `nameof(receiver)` when throwing about it; CA2208 doesn't treat an extension-block receiver as a parameter, so suppress it with a tight `#pragma warning disable/restore CA2208` and a reason, never by dropping the name.
- A singleton is stateless. Never cache per-request state on it (`_result ??= await ...`): the first request's answer leaks to every later one. Keep per-request state on the request or in a scoped service; making the service scoped doesn't help once a singleton captures it.

## Concurrency and Shared State

- An "accept once" check (a replay guard, an idempotency key) is an atomic add-if-absent on a shared store, never a read followed by a write; two concurrent requests both pass a get-then-set, and `IDistributedCache` can't express it. A shared count is an atomic increment.
- Build a shared-store key from length-prefixed components, hashed to a fixed size when a part comes from the caller, so it is neither ambiguous nor unbounded, and scope it by purpose so partitions sharing a store never collide. A library never registers a host-wide cache or store; the host chooses it.
- Take a single-use record (a code, a one-time link, an invitation) with one atomic take, never a read followed by a remove. Take it after every check passes and before its effect, so a refused request leaves it usable.
- Update a shared record with a compare-and-swap on the version you read; on a conflict, reload instead of overwriting. Change a stored record through a read-modify-write that takes an update function, which the store applies to the record as stored and again after a lost race; never write a value computed from an earlier read. An operation whose outcome doesn't depend on what it read (a revocation, a delete) retries a lost race instead of answering `412`.
- When a request and a background pass can both act on one record, only the caller whose write claimed it runs the effect, on the record as claimed, never on an earlier read.
- A store reports a lost optimistic-concurrency race with its own exception type, never an ORM type, so callers don't depend on the ORM. Answer it in one place, not in every handler.
- A write a background loop retries is idempotent: give it an identity the store records in the same unit of work, and skip a write whose identity is already there. A save can commit and still fail at its caller.
- An effect that must follow a committed change runs with `CancellationToken.None`, bounded by its own timeout, so a client disconnect can't leave the change committed without its effect. Steps before the commit keep the request's token.
- An effect that must happen even if the process stops right after the commit (a message, a webhook, a notification) goes to an outbox: write it in the same transaction as the change, and let a background worker deliver it at least once, retrying with back-off. Its handler is idempotent on the effect's id.
- A receiver of deliveries the sender retries (a webhook, a queue message) records the delivery's dedupe key only after handling succeeds, and on failure answers so the sender retries; a failed attempt is never refused later as a replay.

## Distributed State and Background Work

- Correctness never depends on process-local state when more than one instance can run. State that outlives a request or must be seen by another instance goes to the database or a shared store. In-memory caches and static or singleton fields hold only data that can be rebuilt on a miss. Never write durable data to the local file system.
- A per-instance cache entry has an absolute lifetime, which bounds how stale it can be. After the commit, announce a change to the other instances as a best-effort hint that carries the id, never the data; a failed announcement is logged and never fails the write. An instance that may have missed messages, such as after a reconnect, drops what they could have invalidated.
- State derived from other state converges by reconciliation, never by replaying events or draining an in-memory job queue: an idempotent background pass reads the current input, compares it with what it last reconciled (stored durably), repairs what differs and is safe to rerun after a restart. One instance runs each pass, under an expiring lease.
- Work proportional to the size of the data (a pass over every customer or every record) never runs inside a request. Run it in the background.
- Work handed from a request to the background carries a snapshot (ids, the actor, the trace context), never `HttpContext` or a request-scoped service. Each item runs in its own `CreateAsyncScope()` under the application's stopping token, and a failure for one item is logged while the rest continue. Queue in-process work in a bounded `Channel<T>` drained by a fixed number of consumers.
- A hosted service whose `StopAsync` does work runs it once and never throws. A host can be stopped twice at once, and the stop that returns first lets its caller dispose the service provider under the other. Memoize the stop task under a `Lock`, serialize it with the service's periodic work, and log what it couldn't finish.
- A table that grows with use (tokens, sessions, audit records) has a configured retention. A periodic hosted service deletes the rows that ended before it in bounded batches, each its own unit of work, and repeats while a batch is full; a batch lost to another instance's prune counts as progress. Index the column it filters on.

## Security Defaults

- Correct by default. No public API disables a security control or weakens it below its safe baseline; a setting may only supply values or swap in an equal or stronger control.
- When only some endpoints accept a kind of caller, refuse it everywhere by default and let each permitted endpoint opt in through endpoint metadata. A per-endpoint deny check is missing from the next endpoint someone adds.
- Where a list limits what a trust boundary accepts (algorithms, origins, schemes, callers), an unset or empty list permits nothing; never read a missing allow-list as "allow all".
- A guard that protects correctness (a replay check, authorization, a lockout counter) fails closed when its store is unreachable. A guard that protects only capacity (a rate limiter, a cache) fails open behind a short timeout, logs once per outage and counts what it let through in a metric. A store outage answers `503`, never `401`, `404` or "not found", so an outage neither signs users out nor reads as missing data.
- Decode untrusted bytes as text with a throwing encoding (`new UTF8Encoding(encoderShouldEmitUTF8Identifier: false, throwOnInvalidBytes: true)`); `Encoding.UTF8` silently substitutes replacement characters.
- A secret (a password, token, key or connection string, or the credential that authenticated a request) never reaches a log entry, an audit event or a stored copy of a request; record ids and metadata instead. Never put one into a served OpenAPI document or API-reference UI; pre-fill a development credential there only in Development.
- Compare a secret, MAC, hash or verifier with `CryptographicOperations.FixedTimeEquals`, never `==`, `string.Equals` or `SequenceEqual`.
- A credential the application generates (an API key, a client secret) is generated on the server, shown once in the response that creates it, stored only as a salted hash or a protected value, and never returned by a read, a list or a log. Rotate it by creating the new one before deleting the old.

## Outbound Calls

- Every outbound call has its own timeout, retries are bounded and jittered (`Microsoft.Extensions.Http.Resilience`), and a response body is read under a size limit.
- Fetch a URL that a user supplies, or post to one a user registered (a webhook), only through one named `HttpClient` whose handler refuses loopback, private and link-local addresses in its `ConnectCallback` and connects to the address it vetted, so DNS rebinding can't swap it. It requires `https`, sets `AllowAutoRedirect = false`, and enforces its byte limit while streaming; `Content-Length` is only a hint. No setting turns the address check off.
- A remote resource that concurrent requests share (a metadata document, a key set) is fetched once: key the fetch in a `ConcurrentDictionary<TKey, Lazy<Task<T>>>` that it removes itself from, bound it by its own timeout rather than a caller's token (callers stop waiting with `WaitAsync`), and remember a failure for a configured time, so an unreachable source doesn't cost every request a timeout.

## ASP.NET Core

- A web app follows the ASP.NET Core decisions in `docs/decisions/project-template/`: a strict Content Security Policy on every HTML page, HSTS outside Development, opaque server-generated resource ids, keyset pagination and `412` for a write that loses a race.
- Build every absolute URL the app publishes (a link in an email, a redirect, a discovery document) from a configured, validated origin, never from the request's `Host` header. Outside Development, `AllowedHosts` lists the real host names, never `*`; a response that still varies by host sends `Cache-Control: no-store`.
- Persist the Data Protection key ring to a store every instance shares, and encrypt it at rest (`ProtectKeysWith*`). Outside Development, the host refuses to start without both, and stops when it can't decrypt a live key, rather than letting Data Protection create a new key that invalidates every cookie and antiforgery token.
- Follow a return URL only when it is local (`LocalRedirect`, `Url.IsLocalUrl`), so a sign-in round trip can't become an open redirect.
- A `GET` never changes state. A cookie-authenticated form post, logout included, validates an antiforgery token.
- Session and authentication cookies are host-only: the `__Host-` prefix, `Secure`, `Path=/` and no `Domain`, so a sibling subdomain can neither read nor overwrite them.
- Scope a read by the caller in the query, never by fetching and then hiding. Answer a resource the caller may not see with `404`, not `403`, so its existence can't be probed.
- Never bind a server-managed field (owner, tenant, role, status, id) from a request body. Derive it from the authenticated context, and re-read state the server showed the client instead of trusting a posted copy.
- Health checks split liveness from readiness. Liveness checks only the process, never an external dependency, so a lost database doesn't restart every instance; readiness includes every dependency a request needs.

## Clean Code

- Small functions that do one thing at one level of abstraction.
- Few parameters: zero to two, rarely more than three. A recurring group of parameters becomes a type. A trailing `CancellationToken` and a Try-pattern `out` don't count.
- Command-query separation: a method acts or answers, never both.
- Push filtering into the database. A reader that needs a filtered subset calls an intent-named store method (`FindActiveByCustomerAsync`) that filters in the query; never load the whole set and filter in memory. Keep the store contract free of `IQueryable` and `Expression`, and project only the columns the caller needs.
- Don't pass or return `null` where an empty form exists; return an empty collection.
- Intention-revealing, searchable names: no `Manager` or `Helper` catch-alls, no type encodings.
- A string literal used in more than one place (a header name, a dictionary key) is a named `const` in one place. A key in a shared dictionary (`HttpContext.Items`) carries a project prefix so it can't collide.
- Exceptions, not error codes, typed for the caller and carrying context. Never an empty `catch`, never `async void`. A failure that callers act on carries a machine-readable code; code never matches message text.
- Decide a precondition (exists, unique, has no dependents) on a queried fact. Catch only the specific exception that signals a race, such as a unique or foreign-key violation; never infer a domain condition from a broad exception such as `InvalidOperationException`.
- Talk to immediate collaborators; avoid `a.B().C().D()` chains.
- Comments say why, never what. No commented-out code.
- Model a concept with invariants as a type, not a bare `string`, `int` or `bool`.
- Don't nest a call inside another call's arguments; hoist it into a named local first.
- Dispose what you own with a `using` or `await using` declaration, unless ownership moves to a type that disposes it.

## Memory and Performance

- Prefer `ReadOnlySpan<byte>` and `ReadOnlyMemory<byte>` inputs and an `IBufferWriter<byte>` output to returning a new `byte[]`. Rent transient buffers from `ArrayPool<T>.Shared` or use a small fixed `stackalloc`, and clear a buffer that held secret material before returning it.
- Produce a string once with `string.Create`, not by filling a rented `char` buffer and copying it.
- Size a collection when you know the count. Return a shared empty instance (`[]`, `FrozenSet<T>.Empty`) and create a collection lazily when it may stay empty. `list ?? []` allocates a new list; write `list ?? (IReadOnlyCollection<T>)[]`.
- On a path that runs per request, replace LINQ (`Any`, `Where(...).ToList()`) with a `foreach`.
- Split a fixed-segment string without allocating: `MemoryExtensions.Split` into a `stackalloc Range[expected + 1]`, then reject any count other than `expected`. Without the spare slot, extra segments fold into the last range and pass.

## Testability

- Prefer an instance service behind an interface, registered as a singleton, to a `static` utility class. Keep `static` for pure functions with no swappable dependency, constants, extension-member entry points, and an expensive, immutable, thread-safe shared instance such as a cached `static readonly JsonSerializerOptions` (CA1869 asks for it); never static mutable or ambient state.
- Never store request or ambient context (`HttpContext`, a request-scoped `IServiceProvider`, a `ClaimsPrincipal`) in a field. Read it where it is used, or take it as a parameter.
- Constructor-inject every dependency; no `new` of a collaborator inside a method and no service location, except a singleton that needs a scoped service, or one chosen by a generic type argument at call time, which resolves it where it is used. For a fixed set of singletons, inject `IEnumerable<T>`.
- Inject `TimeProvider` for the clock; never read `DateTime.UtcNow` or `DateTimeOffset.UtcNow`. Wrap any other dependency tests can't control (`Guid.NewGuid()`, a random number generator) in a thin `internal interface` with an `internal sealed` forwarding implementation, registered in DI.
- `internal virtual` is the local override seam for a helper a test must stub when extracting an interface would be overkill.
- Internal implementations stay unsealed so Moq can proxy them. CA1852 (seal internal types) stays on: it is quiet in an assembly that grants `InternalsVisibleTo`, as every assembly under test does, and an assembly without tests seals them. Public types are mocked through their interfaces.

## XML Documentation

- Every type or member you add, or whose signature or behavior you change, gets a `///` comment with a substantive `<summary>`, and `<param>`, `<returns>` and `<remarks>` where they help. A NuGet package's build fails on a public member without one (CS1591). Don't add comments to code you aren't otherwise changing; when you rename or change a member, update its comment to match.
- `///` and `//` comments describe the code as it is, never the change: no "now", "new", "previously", "no longer" or "renamed", and never the name of a removed or renamed member. Name a rejected design by its role.
- `<summary>` opens and closes on its own lines, even for one sentence. A property summary opens with "Gets or sets", "Gets" or "Sets" according to its accessors; an `init`-only property is read-only after construction, so it opens with "Gets".
- `///` ships to consumers through IntelliSense and OpenAPI, so it never cites an ADR, a repository path or an internal implementation name. Put those in a `//` comment.
- A minimal-API handler's `///` reaches its OpenAPI operation only when its project references `Microsoft.AspNetCore.OpenApi` and calls `AddOpenApi(...)`, the handler is `internal` or wider, and the endpoint has no `.WithSummary()` or `.WithDescription()`; use XML or fluent metadata, never both. Declare a non-200 response with `.Produces(...)` before describing it with `<response code="...">`.

## Logging

- A library never adds or removes logging providers; the host chooses them. A host logs to standard output.
- Log through source-generated `[LoggerMessage]` methods, never `ILogger.Log*` with an interpolated message. Group a project's methods in `Logging/Log.cs` as an `internal static partial class Log` of extension methods on `ILogger`.
- A message template is a constant with named placeholders (`"Order {OrderId} was rejected"`). Pass each value as its own type, not a pre-built `ToString()`.
- Event IDs are named constants in `Logging/EventIds.cs`, `Base + n`, named like their log methods, and append-only: never renumber or reuse a shipped value. `[LoggerMessage(EventId = EventIds.OrderRejected, ...)]` references the constant, never a literal. In a solution with several runtime projects, each claims a disjoint 1000-wide band, so an ID is unique across the solution.
- A logged request context carries the path, never the query string, which can carry codes or tokens.

## Metrics and Traces

- Measure a signal once, through its owner. Request count, latency and status belong to ASP.NET Core's `http.server.request.duration`, outbound calls to `System.Net.Http`. Add your own instrument only for a mechanism neither covers.
- Create meters through `IMeterFactory`, one meter per project named after the project as a public constant. Name instruments `{product}.{area}.{name}`, reuse OpenTelemetry semantic-convention names (`error.type`), and use UCUM units: durations as histograms in seconds.
- Metric attribute values come from a vocabulary the code controls; a request value that names no known member is recorded as `_OTHER`. Never a user id, customer id, address or any value echoed from the request; those belong in logs and traces.
- Trace only your own mechanisms, through one static `ActivitySource` per project named like its meter. A span never carries a token, cookie, key or personal data.
- Every instrument and span is listed in the project's `docs/metrics.md` catalog (name, unit, attributes and their bounded values, owner), updated in the same change that adds, renames or removes one.
- Test instruments with `MetricCollector<T>` and spans with an `ActivityListener`.

## Configuration and Options

- Configuration is a strongly typed options class, never `IConfiguration` read deep in the code. Inject `IOptions<T>` for values fixed at startup and `IOptionsMonitor<T>` for values that change at runtime. An options class is a data type: `sealed`, `init` or get-only members, correct by default.
- Bind strictly and validate when the host starts, so a misspelled key stops the host instead of passing for an absent one. Express rules the binder can't in an `IValidateOptions<T>`:

  ```csharp
  services
      .AddOptions<OrderOptions>()
      .Bind(configuration.GetSection(OrderOptions.SectionName), o => o.ErrorOnUnknownConfiguration = true)
      .ValidateOnStart();
  ```

- Bind a whole section, never single keys (`configuration["Orders:Limit"]`). Each section has one owner that declares its whole shape. Bind eagerly at registration only when the value decides what gets registered.
- A collection option starts empty: the binder appends configured values to whatever the initializer put there, so apply a default only when nothing is configured. A host's own identifiers (a client id, a callback URL) are never a library default.
- Validate a value the way it will be used. Lenient parsers turn typos into other values: `IPAddress.TryParse("10.0.0")` is `10.0.0.0`, `IPNetwork.TryParse` masks `10.0.0.4/8` to `10.0.0.0/8`, and `Uri.TryCreate(value, UriKind.Absolute, ...)` trims whitespace and accepts a file path. Reject a value that parses to something other than what was written. The binder reads an enum from a number too, so validate with `Enum.IsDefined`.
- Validate a period handed to a timer at startup: 1 ms to 4,294,967,294 ms, the range `PeriodicTimer` and `CancellationTokenSource` accept, with an error that names the option's configuration key.
- Validate only what is in force: each strategy registers its own `IValidateOptions<T>` beside it, which skips when another strategy is selected. A shared validator never branches on the strategy name.
- An options validator reads only dependency-free registrations (descriptors, constants), never the services that read the options it validates. Resolving a service with dependencies inside validation builds its graph inside `IOptions<T>.Value` and deadlocks when a constructor on that path reads the options.
- When configuration supplies a default for a value a write omits, resolve it at write time, validate it and store it like an explicit value. Never fill the gap at read time, or a later configuration change silently moves existing data.
- An unset target never means "everything": a seeder or job that writes credentials, accounts or grants requires the target it writes to, validated when the host starts.
- A development convenience (generated keys, seeded users, a permissive CORS policy) is an explicit, named opt-in, inert until its section is configured, and seeds through the production code path. A setting that selects a guardrail defaults to the safe value when it isn't declared.
- In Production, the host refuses to start on a setting meant only for development (an ephemeral key provider, a secret written inline in configuration, a wildcard `AllowedHosts`, a development seeder), and reports every such finding in one failure, not the first one.

## Build

- `./build/dod.ps1` is the Definition of Done: it checks the decision index, builds in Release with every analyzer, runs the tests and, for a library, packs. CI runs it, and `./build/dod.ps1 -Fast` (Debug, no pack) is the local gate before a push; `-Filter` narrows the tests in the inner loop. Its last line is `Definition of Done: PASSED`; a script tests its exit code instead.
- A library's versions follow Semantic Versioning, taken from the release tag (`v1.2.3`); `AssemblyVersion` moves only with the major version, so a minor or patch upgrade is a drop-in replacement, while `FileVersion` and `InformationalVersion` keep the exact version. Never set `AssemblyVersion` by hand.
- The null-forgiving operator fails the build outside test projects (Nullable.Extended.Analyzer, NX0001-NX0004).
- Warnings are errors in every project, tests included. Relax a single rule with a justified `.editorconfig` entry or a tight `#pragma warning disable/restore` with a reason, never with `TreatWarningsAsErrors=false`.
- Unused `using` directives fail the build (IDE0005). Clean them with `dotnet format style --diagnostics IDE0005`.
- Package versions live in `Directory.Packages.props`; a `PackageReference` never carries a `Version`.
- Ban an API the project rules out in a `BannedSymbols.<name>.txt` of its own, added in `Directory.Build.props`. List each overload's full documentation ID: a bare `M:Type.Method` matches only the overload without parameters.
- Never run two `dotnet build` or `dotnet test` commands at once in one clone: they share every project's `obj/` folder and fail spuriously.
- Before calling a structural change (moved, renamed or deleted files) done, run a clean Release build of the whole solution.

## Entity Framework Core

These apply when the project uses EF Core.

- A change to an entity or its configuration ships with its migration. Run `dotnet ef migrations has-pending-model-changes` before committing a model change; it fails when the model differs from the last migration. A project with EF Core may add it to CI.
- A migration keeps the previous release working, since it serves during the migration and after a rollback: add tables, nullable or defaulted columns and indexes; never drop, rename or tighten what the previous release reads. Tightening ships in a later release than the expansion it follows.
- Besides a drop or a rename, these tighten a table: making a column required, even with a default (EF writes an explicit `NULL` for a column the previous release maps as nullable); narrowing a type or precision; adding a unique index, or a unique, primary-key, check or foreign-key constraint, to an existing table.
- Outside Development, the host never applies migrations at startup. Apply them as a deliberate step (a migration bundle or an idempotent script the pipeline runs) before the new release rolls out. The host project owns the migrations, not a library.
- Raw SQL in the model (`HasFilter`, `HasDefaultValueSql`, `HasComputedColumnSql`) quotes identifiers when the provider folds unquoted names: PostgreSQL folds them to lower case, so the fragment passes on SQLite and fails in production.
- Deleting an aggregate root removes what it owns in the same unit of work, and answers `409` while the root still holds records that belong to another party; never leave orphans or surface a foreign-key violation as a `500`.
- A `SaveChangesInterceptor` overrides both `SavingChanges` and `SavingChangesAsync`; overriding only the synchronous one never runs on `SaveChangesAsync`.
