---
description: C# conventions for test projects, from the project template
applyTo: "**/*.Tests/**/*.cs"
---

# C# Test Conventions

These conventions come from the project template, for `<Name>.Tests` projects, which use xUnit and Moq. `.github/instructions/csharp.instructions.md` applies to tests too. Where the project's own instruction files differ, they win.

## Project Layout

### File Location and Namespace

Test files mirror the folder structure and namespace of the code under test:

- A test file goes in the same relative folder within the test project, named after the type under test with a `Tests` suffix.
- Its namespace is the production namespace with a `.Tests` suffix.

```csharp
// Production: MyApp/Wrappers/CommandExceptionHandlerWrapper.cs
namespace MyApp.Wrappers;

// Test: MyApp.Tests/Wrappers/CommandExceptionHandlerWrapperTests.cs
namespace MyApp.Tests.Wrappers;
```

### InternalsVisibleTo

A project under test grants its tests and Moq access to internal types:

```csharp
using System.Runtime.CompilerServices;

[assembly: InternalsVisibleTo("DynamicProxyGenAssembly2")]
[assembly: InternalsVisibleTo("MyApp.Tests")]
```

`DynamicProxyGenAssembly2` lets Moq proxy internal types; the second name must match the real test assembly. Keep test-only access `internal`. Never make a member `public` for a test.

### Regions

Group tests in a class with `#region` blocks per member under test:

- `Constructor Tests` for constructors
- `{MethodName} Tests` for methods, for example `Dispose Tests`
- `{PropertyName} Property Tests` for properties, for example `Span Property Tests`
- `Generic Type Tests` for tests of generic type parameter behavior

## Test Style

- Name tests `Method_State_Expected`, for example `Parse_WhenInputIsEmpty_ReturnsNull`.
- Test one behavior per test.
- No `// Arrange`, `// Act`, `// Assert` comments; separate the sections with blank lines.

```csharp
[Fact]
public void MyMethod_WhenCondition_ExpectedBehavior()
{
    const string input = "test";

    var result = MyMethod(input);

    Assert.Equal("expected", result);
}
```

- The production code style applies in tests too: collection expressions, `const` for literals, and `u8` literals for UTF-8 bytes. An array literal passed straight to an assertion stays inline.
- A stub, fake or sample type that one test file needs is a `private sealed` nested type in that file.

## Warnings and Analyzers

- Warnings are errors in test projects too. An analyzer warning in a test, especially from `xunit.analyzers`, usually reports a defect in the test itself.
- `build/ProjectTemplate.Tests.globalconfig` turns off six rules that are noise in tests, for every `*.Tests` project: CS1591 (tests need no XML comments, though the documentation file is still generated for IDE0005), CA1707 (the underscores in `Method_State_Expected`), CA1816 (`GC.SuppressFinalize` in a test class without a finalizer), CA1859 (tests hold collaborators by their interface), CA1861 (inline array literals passed to assertions) and CA1869 (each test builds its own `JsonSerializerOptions`). CA2012 stays on: return completed values with `.ReturnsAsync`. CA2215 stays on: an override of `Dispose(bool)` that skips the base would skip mock verification.
- To silence another rule across all tests, set its severity in `.editorconfig` for the test projects' files, with a one-line reason. For one site, wrap it in `#pragma warning disable` and `#pragma warning restore` with a reason.
- Never set `TreatWarningsAsErrors` to `false` in a test project.
- Fix nullable warnings rather than suppress them. Narrow a maybe-null result with `Assert.NotNull(x)` before you use it, and give a `[MaybeNullWhen(false)]` `out` argument a nullable local. `null!` is the one exception to the production rule against the null-forgiving operator: use it only to pass a deliberate null to the code under test, such as in an argument-validation test, never to silence a warning.

## Running Tests

- A filtered run must fail when its filter matches no test. Otherwise it exits 0, and a Done-when check passes before its test exists. `./build/dod.ps1 -Filter` fails such a run itself. A bare `dotnet test --filter` names the test project and adds `-- RunConfiguration.TreatNoTestsAsError=true` (xUnit on VSTest); run over the whole solution, that setting also fails every test project the filter doesn't reach.

## What a Test Proves

- Test a type through its public or internal members. Cover private methods through the members that call them. When a private method needs tests of its own, extract it into a collaborator and test that. A private branch that no test through those members can reach is dead code: delete it.
- A test must fail when the behavior it names is removed. Arrange the inputs so that only the rule under test can produce the outcome:
  - When the rule refuses a fallback, make the fallback work, and add a control test where the fallback succeeds because the rule doesn't apply. Otherwise the test passes because the fallback fails on its own.
  - When several checks could reject the input, build input that passes every check except the one under test, and assert the specific error message or code, not just that it failed.
  - When a change moves where or when something happens, use input that the old code handled differently. Input that the old code also rejected passes with or without the change.
  - When the test depends on a precondition, such as stored data being invalid, assert the precondition first.
  - When a test depends on a setting reaching the code, assert an effect that only that setting produces.
- Unit-test logic with data the test declares, such as its own rules or catalog entries. Test built-in defaults and tables in tests of their own.
- Pin a parser or encoder to bytes produced by another implementation, one known to conform to the specification. A parser and a test builder that share one misreading of a specification both pass. Keep a few fixtures from a reference tool, put the command that produced each one in a comment, and never edit them by hand.
- Test an adapter over a framework type against the real type as well as a mock. A mock hides what the real methods do, such as validation and side effects.

## Assertions

- Use `Assert.Empty(collection)` for a count of 0 and `Assert.Single(collection)` for 1, not `Assert.Equal(0, collection.Count)`. For larger counts, `Assert.Equal(expectedCount, collection.Count)` is fine.
- `Assert.Throws<T>` requires the exact type and fails on a derived exception. Use it when the exact type is the contract, such as `ArgumentNullException` or the project's own exception types. When the concrete type varies by platform or provider, assert the documented base type with `Assert.ThrowsAny<T>`.
- Compare an `ImmutableArray<T>` by its elements with `Assert.Equal<T>(expected, actual)`. `ImmutableArray<T>` equality compares the backing array, so an equal-elements comparison can fail without the explicit element type.
- Assert a URI that the code must emit exactly as written on `Uri.OriginalString`. `AbsoluteUri` and `ToString()` normalize it.

## Mocking with Moq

### Strict Mocks, Verified Automatically

- Mock collaborators with `MockBehavior.Strict`, so an unexpected call fails the test.
- End every setup with `.Verifiable()`, and name the lambda parameter `x`.
- Create mocks from one `MockRepository` that the test class verifies when it is disposed, so an unmet setup fails the test. Don't add manual `mock.Verify(...)` calls for what that already checks; use one only to check a call count, such as `Times.Exactly(2)`.

```csharp
public abstract class UnitTestBase : IDisposable
{
    private readonly MockRepository _mocks = new(MockBehavior.Strict);

    protected Mock<T> CreateStrictMock<T>(params object[] args)
        where T : class => _mocks.Create<T>(args);

    protected Mock<T> CreateLooseMock<T>(params object[] args)
        where T : class => _mocks.Create<T>(MockBehavior.Loose, args);

    protected Mock<T> CreatePartialMock<T>(params object[] args)
        where T : class
    {
        var mock = CreateLooseMock<T>(args);
        mock.CallBase = true;
        return mock;
    }

    public void Dispose()
    {
        Dispose(disposing: true);
        GC.SuppressFinalize(this);
    }

    protected virtual void Dispose(bool disposing)
    {
        if (disposing)
            _mocks.Verify();
    }
}
```

```csharp
mockService
    .Setup(x => x.DoSomething(It.IsAny<string>()))
    .Returns("result")
    .Verifiable();
```

- A test class verifies its mocks through `IDisposable` or `IAsyncLifetime`. xUnit v2 never calls `IAsyncDisposable.DisposeAsync` on a test class, so verification placed only there never runs.
- An override of `Dispose(bool)` calls `base.Dispose(disposing)`, or the mocks are never verified.
- Use `MockBehavior.Loose` in two cases only:
  - A partial mock of an abstract class, where members without a setup run the real implementation (`CreatePartialMock<T>()`). Moq supports this only under Loose.
  - A stub whose members only supply values the test never asserts on.
- When a setup is used only on some code paths, move it out of the shared setup and into the tests that take those paths. Never drop `.Verifiable()` to get past an unmet setup.
- Return a completed value with `.ReturnsAsync(value)` and fail with `.ThrowsAsync(exception)`, rather than `.Returns(ValueTask.FromResult(value))`.

### Setup Techniques

- Compute an expected argument in a local before the setup, and match the local. A setup is an expression tree, which cannot hold a ref struct, a `params` span call or an `out` argument.
- Moq cannot match a `Span<T>` or `ReadOnlySpan<T>` argument. Test the caller against the real collaborator or a hand-written recording fake. Never change the collaborator's signature for the mock.
- `OfType<T>()` and `Cast<T>()` enumerate through the non-generic `IEnumerable.GetEnumerator()`. A strict mock of a collection consumed that way needs `mock.As<IEnumerable>().Setup(x => x.GetEnumerator())`.
- Match an argument whose type compares by reference, such as `JsonElement`, by content through a static helper: `It.Is<JsonElement>(e => HasProperty(e, "name"))`.
- To make one call fail, add a narrower setup after the general one. Moq uses the last matching setup, and both setups are consumed.
- When code reads an object, changes it and reads again, return a new object for each read with `SetupSequence(...)`. One shared instance lets the second read see the first attempt's change.
- To inspect a value the unit passes to a collaborator midway, capture it in `.Callback(...)` and return a faulted task from the setup, so the unit stops there and nothing after it needs a mock.
- When the unit passes a delegate that the collaborator calls, such as an update function, capture it in the setup and invoke it in the test with the input the scenario means. Assert on what it returns.
- To raise an event on a strict mock, capture the handler with `SetupAdd(x => x.Changed += It.IsAny<EventHandler>()).Callback<EventHandler>(h => handler = h)` and invoke it. Add a `SetupRemove` when the unit detaches.
- Set up a protected member with `mock.Protected().Setup<ValueTask>("DisposeAsyncCore")`, for example when a non-virtual public method calls it.
- A change-token producer in a test returns a new token after each change. `ChangeToken.OnChange` asks for a new token after its callback, and a producer that returns the cancelled token fires forever.

### Loggers

- When a test doesn't assert on logging, pass `NullLogger<T>.Instance`.
- When the log entry is the behavior under test, use `FakeLogger<T>` from `Microsoft.Extensions.Diagnostics.Testing` and assert on its records.

## Real Collaborators

- Isolate a unit by mocking its external collaborators. When the composition itself is the behavior, such as registration, dispatch or end-to-end serialization, use the real container (`new ServiceCollection().Add...().BuildServiceProvider()`). Share small builders instead of repeating the registration in every test.
- Dispose a real service provider with `await using`. A provider that holds an `IAsyncDisposable`-only service throws from a synchronous `Dispose()`.
- When the container's validation requires a dependency the test must not touch, register a strict mock with no setups instead of turning off validation.
- To prove that composition doesn't construct a service, register a factory for it that throws.
- Seed stored data in the format the code reads, through the production serializer. A test that hands the code a hand-built shape passes while the code fails on real stored data.
- Data a test sends through a public entry point meets that entry point's validation, for example a password policy. Seeding a store directly skips it.

## Isolation

- Tests are hermetic: no network, no machine state, no ambient host. Use `DefaultHttpContext` with test `RequestServices`, in-memory fakes and constructed `ClaimsPrincipal`s.
- Serve HTTP through a stub `HttpMessageHandler` that answers by `RequestUri`. To check what the code sends, record each request in the handler.
- A test writes nothing outside its own temporary state: no event log, no user key directory, no shared files.
- Each test builds its own state. Never share mutable static state between tests.
- Tests run in parallel, so a listener on a process-wide source, such as a `MeterListener` on a framework meter, also sees other tests. Find this test's own item with `Assert.Contains`, and never use `Assert.Single` over shared output.

## Time and Concurrency

- Code under test reads time from an injected `TimeProvider`, never `DateTime.UtcNow` or `DateTimeOffset.UtcNow`. Tests use `FakeTimeProvider` from `Microsoft.Extensions.TimeProvider.Testing`, started at a fixed time and moved with `Advance`:

```csharp
var time = new FakeTimeProvider(new DateTimeOffset(2025, 1, 1, 0, 0, 0, TimeSpan.Zero));
var cache = new TokenCache(time);

time.Advance(TimeSpan.FromMinutes(5));

Assert.False(cache.TryGet("key", out _));
```

- Never sleep in a test. `FakeTimeProvider.Advance` fires timers and delays created through the provider.
- Never measure elapsed time to prove a property, such as a constant-time comparison. Record that the code took the path, with a strict setup or a recording fake.
- Test concurrency with gates. A stub awaits a `TaskCompletionSource`; start the calls, assert the state while they wait, then release the gate. To prove a limit, set it to one and assert that a second call does not complete while the first waits.
- Fail an async collaborator with a faulted task (`Task.FromException`, `ValueTask.FromException` or `.ThrowsAsync`), as real async code fails. A synchronous throw can surface differently, for example wrapped in `TargetInvocationException` when the caller uses reflection.
- In an integration test, wait for a background effect by polling with a deadline, never with a fixed delay:

```csharp
var elapsed = Stopwatch.StartNew();
while (!await IsProcessedAsync(id))
{
    Assert.True(elapsed.Elapsed < TimeSpan.FromSeconds(15), "The job did not run.");
    await Task.Delay(100);
}
```

## Entity Framework Core

- Test a store against a real provider, not a mock. Behavior that depends on `SaveChanges`, such as concurrency tokens, cascade deletes, interceptors and value converters, is visible only there. Keep both layers: mock the store to test the code above it, and test the store against a provider.
- Test code whose correctness depends on the order of writes across stores or units of work through the real composition. A test that mocks the stores cannot see the order.
- The EF InMemory provider enforces no concurrency token, unique index (filtered or not) or foreign key. Test those against SQLite in-memory: keep one `SqliteConnection` open, call `EnsureCreated`, and use two `DbContext` instances for racing writers.
- EF Core's SQLite provider cannot compare or order a `DateTimeOffset`. Test such a query on EF InMemory or on the real database.
- Name an InMemory database once, in a local outside the options lambda. `AddDbContext(options => options.UseInMemoryDatabase(Guid.NewGuid().ToString()))` gives every scope a new, empty database.
- A test that adds an entity to a context's model calls `EnableServiceProviderCaching(false)`. EF Core caches the model per context type across service providers.
- A global query filter doesn't apply to an entity the context already tracks. After seeding, call `ChangeTracker.Clear()` or use a new context, so the query reaches the database where the filter runs.

## Integration Tests

- Give a test its own `WebApplicationFactory` when it changes state the host keeps, such as a data-protection key ring or a cache. A shared class fixture leaks that state between tests.
- Seed data before the host serves its first request. A host reads and caches some data on first use. `WithWebHostBuilder` builds a separate host with its own services and caches.
- Never assert a startup failure through `WebApplicationFactory`. Its startup can hit an already disposed provider and throw `ObjectDisposedException`, which hides the real error, and the test fails only under load. Build the host directly (`Host.CreateEmptyApplicationBuilder`, the registration under test, then `StartAsync`).
- Dispose the factory, never the host it built. The host's own run loop stops and disposes it, and a second stop disposes services under shutdown work still in flight.
- The factory runs the host in the Development environment: `appsettings.Development.json` applies, and an unhandled exception reaches the client as the developer exception page's `500`. The test host doesn't read `launchSettings.json`. Configure what a test depends on in the factory.
- To test an HTTP client the project ships against the project's own server, route the client's named `HttpClient` to `factory.Server.CreateHandler()` (`ConfigurePrimaryHttpMessageHandler`), and record the exchanges with a delegating handler (`AddHttpMessageHandler`), so the test proves the requests as well as the result.
- Prove a response header that appears only for a returning browser (antiforgery adds `X-Frame-Options` only when it stores its cookie) with a second request that sends back the first response's cookies. Prove a header that depends on the forwarded scheme, such as HSTS, with a forwarded request and a control request without the proxy headers.
- A setting that the composition root reads while it registers services is a host setting: supply it with `builder.UseSetting(key, value)`. A `ConfigureAppConfiguration` overlay arrives too late for it.
- To change configuration at runtime, set the key on the host's `IConfiguration` cast to `IConfigurationRoot` and call `Reload()`.
- Read response headers from `HttpResponseMessage.Headers` and content headers from `Content.Headers`.
- Put multi-step flows, such as signing in or posting a form with antiforgery tokens, in shared helpers instead of copying them into each test.
- Write test text that depends on Unicode normalization with escapes (`"caf\u00e9"`, `"cafe\u0301"`), never as pasted characters an editor may normalize.
- A test that needs an artifact the .NET build doesn't produce skips unless an environment variable names it, through a custom fact attribute that sets `Skip`.
- Never depend on `Debug.Assert` or `#if DEBUG` code in a test. Release builds remove it; run `dotnet test --configuration Release` when the project ships Release builds.
