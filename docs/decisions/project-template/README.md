# Project Template Decisions

These records hold the decisions behind the project template's rules: why its instruction files, build settings,
workflow and repository setup are the way they are. They are template-owned: every template update replaces this
folder, so never edit a file in it. A project that decides otherwise writes its own record in `docs/decisions/` that
supersedes the template's by number (for example, "Supersedes: project-template ADR-0102"), and lists the override in
`AGENTS.md`, so every agent follows the project's decision instead of the template's.

Their numbers are below 1000: 0001–0099 for every project and 0100–0999 for the records of a stack or an option. A
project numbers its own records from 1000, so an ADR number names one record across both folders, and a template update
never brings a number the project already uses
([ADR-0012](0012-the-templates-records-are-numbered-below-1000-a-projects-from-1000.md)).

## Every Project

| ADR | Decision |
| --- | --- |
| [0001](0001-conventions-and-lessons-live-in-the-repository.md) | Conventions, decisions and lessons live in versioned files in the repository, not in an agent's memory |
| [0002](0002-commits-are-attributed-to-people-not-agents.md) | A commit records the people who wrote it; an AI agent is never an author, committer or co-author |
| [0003](0003-agent-work-is-planned-on-a-frontier-model-and-executed-on-a-cheaper-one.md) | A frontier model plans and re-plans; a cheaper model executes one verified step at a time and escalates |
| [0004](0004-trunk-based-development-on-the-default-branch.md) | One trunk, `main`, with short-lived branches; no long-lived integration branch |
| [0005](0005-the-default-branch-accepts-changes-only-through-pull-requests.md) | The default branch takes changes only through pull requests whose required checks pass |
| [0006](0006-a-person-merges-every-pull-request.md) | A person decides every merge; an agent never merges, marks ready or turns on auto-merge |
| [0007](0007-pending-work-is-tracked-as-issues.md) | Pending work is one issue per item on the repository host, closed by the pull request that completes it |
| [0008](0008-external-inputs-are-pinned-and-kept-current.md) | Packages, actions, SDKs, images and the template version are pinned exactly and moved by reviewed updates |
| [0009](0009-new-dependency-versions-wait-a-cooldown.md) | A new dependency version is adopted only once it is at least three days old |
| [0010](0010-a-change-consumers-can-observe-is-decided-before-it-is-built.md) | A change consumers can observe starts as an issue, and its decision is recorded before or with the pull request |
| [0011](0011-agents-treat-existing-code-as-evidence-and-report-done-only-when-done.md) | Existing code is evidence, not a constraint; pins come from upstream; done means done in every tracker |
| [0012](0012-the-templates-records-are-numbered-below-1000-a-projects-from-1000.md) | The template's records are numbered below 1000 and a project's from 1000, so an ADR number names one record |
| [0013](0013-pull-requests-merge-with-a-merge-commit-or-by-rebasing.md) | A pull request merges with a merge commit or by rebasing; a project that squash-merges supersedes this record alone |
| [0014](0014-every-pull-request-discussion-is-remediated-and-replied-to-before-it-merges.md) | Every pull request discussion is fixed, or answered with why not, and replied to before the merge; the person resolves it |

## .NET

| ADR | Decision |
| --- | --- |
| [0100](0100-warnings-are-errors-in-every-project.md) | Every project, tests included, builds with zero warnings |
| [0101](0101-central-package-management.md) | Package versions live in `Directory.Packages.props` through Central Package Management |
| [0102](0102-disallowed-apis-are-banned-at-build-time.md) | Sync-over-async, `JsonDocument` parsing and Newtonsoft.Json are banned at build time |
| [0103](0103-behavior-is-a-service-a-strategy-collection-or-a-mediator.md) | Behavior is a service by default, a strategy collection when open, a mediator only at a pipeline seam; observers are fault-isolated |
| [0104](0104-no-cross-assembly-internalsvisibleto.md) | Production assemblies collaborate through public contracts; `InternalsVisibleTo` is for tests only |
| [0105](0105-the-canonical-implementation-is-named-defaultfoo.md) | The one canonical implementation of `IFoo` is the internal `DefaultFoo` |
| [0106](0106-configuration-binds-strictly-and-is-validated-at-startup.md) | An unknown configuration key or an invalid value stops the host at startup |
| [0107](0107-filtered-reads-push-filtering-to-the-database.md) | A filtered read runs its filter in the database, through an intent-named query |
| [0108](0108-persisted-documents-are-versioned-and-additive.md) | Persisted JSON documents carry a schema version, change additively and are upcast step by step |
| [0109](0109-a-lost-concurrency-race-is-a-store-neutral-exception.md) | A lost optimistic-concurrency race surfaces as one store-neutral exception |
| [0110](0110-shared-state-is-changed-by-read-modify-write.md) | Shared stored state changes through one read-modify-write operation that retries a lost race |
| [0111](0111-failures-carry-a-machine-readable-code.md) | A failure that callers act on carries a stable machine-readable code |
| [0112](0112-binary-data-uses-spans-pooled-buffers-and-cleared-secrets.md) | Binary data uses spans, caller-owned writers, pooled buffers and cleared secrets |
| [0113](0113-metrics-have-one-owner-per-signal-and-bounded-dimensions.md) | Each metric signal has one owner, and every attribute comes from a bounded vocabulary |
| [0114](0114-one-activity-source-named-like-its-meter.md) | A project traces only its own mechanisms, through one activity source named like its meter |
| [0115](0115-a-host-logs-to-standard-output.md) | A host logs to standard output, as one JSON line per entry where a collector reads it |
| [0116](0116-visibility-starts-at-the-narrowest-that-works.md) | Every type and member starts at the narrowest visibility that works; `public` needs a reason |
| [0117](0117-one-definition-of-done-gates-every-change.md) | `build/dod.ps1` is the one Definition of Done that people, agents and CI run |
| [0118](0118-the-null-forgiving-operator-is-banned-outside-tests.md) | The null-forgiving operator `!` fails the build outside test projects |
| [0119](0119-production-refuses-development-only-settings.md) | Development conveniences are inert unless configured, and Production refuses them, listing every finding at once |
| [0140](0140-replicas-converge-through-reconciliation.md) | Caches expire absolutely, change notices are hints, and derived state is reconciled under a lease |
| [0141](0141-side-effects-after-a-commit-go-through-an-outbox.md) | An effect that must follow a commit is written to an outbox with it and delivered at least once |
| [0142](0142-data-that-grows-with-use-is-pruned-in-bounded-batches.md) | Data that grows with use has a retention period and is pruned in bounded batches |
| [0143](0143-migrations-run-before-the-rollout-and-only-expand.md) | Migrations run in a step before the rollout, never at startup, and only expand until a later release contracts |
| [0144](0144-correctness-guards-fail-closed-capacity-guards-fail-open.md) | A correctness guard fails closed with `503`; a capacity guard fails open behind a timeout and a breaker |
| [0145](0145-outbound-calls-are-bounded-and-caller-supplied-urls-are-guarded.md) | Outbound calls are bounded; caller-supplied URLs go through a client that refuses private addresses |
| [0146](0146-secrets-are-never-logged-compared-in-constant-time-and-shown-once.md) | Secrets never reach diagnostics, are compared in constant time, and are shown once and stored hashed |

## ASP.NET Core

| ADR | Decision |
| --- | --- |
| [0120](0120-request-delegates-are-generated-at-compile-time.md) | Minimal-API request delegates are generated at compile time |
| [0121](0121-html-pages-have-a-strict-content-security-policy.md) | Every HTML page has a strict Content-Security-Policy and is framed only by design |
| [0122](0122-strict-transport-security-outside-development.md) | The application sends Strict-Transport-Security outside Development |
| [0123](0123-resource-ids-are-server-generated-and-opaque.md) | Resource identifiers are minted by the server and opaque |
| [0124](0124-collection-endpoints-use-keyset-pagination.md) | Collection endpoints page by keyset cursor, with no query protocol |
| [0125](0125-a-write-that-loses-a-race-is-answered-412.md) | An API write that loses a concurrency race is answered `412 Precondition Failed` |
| [0126](0126-published-urls-come-from-a-configured-origin.md) | Published URLs come from a configured origin, never the request's `Host` header |
| [0127](0127-the-data-protection-key-ring-is-shared-and-encrypted-at-rest.md) | The Data Protection key ring is shared, encrypted at rest, and checked when the host starts |
| [0128](0128-liveness-never-checks-dependencies-readiness-does.md) | Liveness never checks dependencies; readiness does, and neither shows details publicly |
| [0129](0129-browser-facing-requests-are-safe-by-construction.md) | Local return URLs, no state change on `GET`, antiforgery, `__Host-` cookies, no overposting, `404` for the unseen |

## Libraries

| ADR | Decision |
| --- | --- |
| [0130](0130-source-link-and-symbol-packages.md) | Packages are source-linked, deterministic and ship symbol packages |
| [0131](0131-public-api-is-tracked-and-evolves-compatibly.md) | The public API surface is tracked and evolves backward-compatibly |
| [0132](0132-implementation-packages-depend-only-on-abstractions.md) | Implementation packages reference only abstractions packages; the composition root wires them |
| [0133](0133-abstractions-are-framework-free-and-tiered.md) | Abstractions packages are framework-free, tiered by dependency, and hold no logic |
| [0134](0134-evolving-optional-parameters-are-a-dto.md) | A growing set of optional criteria is an init-only DTO, not positional parameters |
| [0135](0135-packages-are-published-from-a-github-release-through-trusted-publishing.md) | Packages are published from a GitHub release through nuget.org trusted publishing |
| [0136](0136-packages-follow-semantic-versioning-and-the-assembly-version-moves-only-with-the-major.md) | Versions follow Semantic Versioning from the release tag; `AssemblyVersion` moves only with the major |
