# 0102. Disallowed APIs are banned at build time

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

Some APIs are almost always the wrong call in this codebase, yet they are the most discoverable ones: an IDE completes
them first, examples on the web use them, and an agent reaches for them because they compile. A convention that says
"don't" is read by some contributors some of the time; the misuse returns in unrelated code, and review catches it only
when the reviewer remembers.

Three groups recur:

- Blocking on asynchronous work. `Task<T>.Result`, `Task.Wait`, `GetAwaiter().GetResult()`, `Task.WaitAll` and
  `Task.WaitAny` block a thread until a task completes. Where a synchronization context exists the continuation waits
  for the blocked thread, a deadlock; on the thread pool, each blocked request holds a thread, and under load the pool
  starves while it grows slowly.
- `JsonDocument`. It parses into buffers rented from a shared pool, which go back to the pool only when the document is
  disposed. A document that is never disposed loses its buffers to the pool, and a `JsonElement` taken from a document
  that was disposed throws when it is read. `JsonElement.Parse` returns an element that owns its memory, with nothing to
  dispose and no lifetime to track.
- A second JSON stack. Newtonsoft.Json and `System.Text.Json` differ in naming, number handling, defaults and
  attributes. Code that mixes them serializes one type two ways.

## Decision

The template bans these APIs at build time with the banned-API analyzer, in every project, tests included.

1. `Microsoft.CodeAnalysis.BannedApiAnalyzers` is a `<GlobalPackageReference>` in `Directory.Packages.props`
   ([ADR-0101](0101-central-package-management.md)), so it runs in every project.
2. `build/BannedSymbols.txt` is the template's list, added to every project by `build/ProjectTemplate.props`. It bans:
   - sync-over-async: `Result` on `Task<T>` and `ValueTask<T>`, `Task.Wait`, `GetAwaiter().GetResult()` on tasks and
     value tasks, `Task.WaitAll` and `Task.WaitAny`; the replacement is `await`, `Task.WhenAll` and `Task.WhenAny`,
     all the way up;
   - `JsonDocument.Parse`, `ParseAsync`, `ParseValue` and `TryParseValue`; the replacements are `JsonElement.Parse`,
     `JsonElement.ParseValue` and `JsonElement.TryParseValue`, and `JsonSerializer.Deserialize<JsonElement>` or
     `DeserializeAsync<JsonElement>` for a stream;
   - Newtonsoft.Json's main types (`JsonConvert`, its `JsonSerializer`, `JToken`, `JObject`, `JArray`); the JSON stack
     is `System.Text.Json`, with `JsonNode` for a mutable document.
   Each entry carries a message naming the replacement, so the analyzer's error (`RS0030`) says what to use. With
   warnings as errors ([ADR-0100](0100-warnings-are-errors-in-every-project.md)), a banned call fails the build.
3. A project bans APIs of its own in a `BannedSymbols.<name>.txt` file, added in `Directory.Build.props` after the
   template's import:
   `<ItemGroup><AdditionalFiles Include="$(MSBuildThisFileDirectory)BannedSymbols.Project.txt" /></ItemGroup>`.
   The analyzer reads every file named `BannedSymbols.txt` or `BannedSymbols.*.txt`. The template's list is
   template-owned and never edited.
4. A project that decides against the template's list drops it in `Directory.Build.props`, after the import:
   `<ItemGroup><AdditionalFiles Remove="$(MSBuildThisFileDirectory)build/BannedSymbols.txt" /></ItemGroup>`, and
   records why in its own decision record that supersedes this one. To drop one entry, it keeps the list and
   suppresses `RS0030` at the sites that need the API.
5. A site that genuinely needs a banned API, such as a synchronous interface member that must call asynchronous code,
   or an integration whose library takes Newtonsoft.Json types, uses a tight `#pragma warning disable RS0030` with a
   comment that gives the reason.

## Options considered

- A rule in the C# conventions alone. Rejected: it binds only the readers who remember it, and review misses it.
- Production projects only. Rejected: a test that blocks on a task can deadlock or hide a race, and a test that uses a
  different JSON stack passes on JSON the product would read differently.
- One banned list the project edits. Rejected: template updates would overwrite its entries, or the project would miss
  the template's new ones; two files keep both.
- The banned-API analyzer with a template list and project lists (chosen). A misuse fails the build where it is
  written, with the replacement in the message.

## Consequences

- Sync-over-async, an undisposed `JsonDocument` and a second JSON stack cannot enter the code without a visible,
  commented suppression.
- An agent learns the rule from the build error, not from instructions it may not have loaded.
- A dependency may still use the banned APIs internally; the ban covers only the project's own source.
- Adding an entry to `build/BannedSymbols.txt` in a template update can fail the build of existing code; the update
  that brings it lands with the fixes or with commented suppressions.

## References

- `build/BannedSymbols.txt`, `build/ProjectTemplate.props`, `Directory.Packages.props`, `Directory.Build.props`
- [BannedApiAnalyzers](https://github.com/dotnet/roslyn-analyzers/blob/main/src/Microsoft.CodeAnalysis.BannedApiAnalyzers/BannedApiAnalyzers.Help.md)
- [`JsonElement.Parse`](https://learn.microsoft.com/dotnet/api/system.text.json.jsonelement.parse)
- [Use a JSON DOM in System.Text.Json](https://learn.microsoft.com/dotnet/standard/serialization/system-text-json/use-dom)
- [Task-based asynchronous pattern](https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/task-based-asynchronous-pattern-tap)
- [ADR-0100](0100-warnings-are-errors-in-every-project.md): warnings are errors in every project.
- [ADR-0101](0101-central-package-management.md): package versions are managed centrally.
