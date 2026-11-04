# 0143. Migrations run deliberately before the rollout and only expand until a later release contracts

- **Status:** Accepted
- **Date:** 2026-10-31

This decision applies to projects that keep a relational schema through Entity Framework Core migrations.

## Context

Calling `Database.Migrate()` when the host starts is the shortest path from a model change to a working database, and
it is fine on a developer's machine. Outside Development it goes wrong:

- Several instances starting at once race to apply the same migration.
- A migration that fails crashes every instance in turn, and none serves.
- The application's own database account needs the right to change the schema, which it otherwise never needs.
- During a rolling update the previous release serves while the new one starts, and after a rollback it serves
  again, against the schema the new release migrated to. EF Core cannot safely reverse every migration, and a rollback
  runs none.

So every migration must keep the previous release working. `dotnet ef migrations add` scaffolds a destructive operation
as readily as an additive one: renaming a property becomes `RenameColumn`, and making one required becomes
`AlterColumn` with `nullable: false`. Some tightening looks harmless and is not. Making a column required with a default
still breaks the previous release, because EF Core writes an explicit `NULL` for every column that release maps as
nullable, so the default never applies. A unique index added to an existing table refuses rows the previous release
still writes.

## Decision

The host owns its migrations and applies them in a deliberate step before the new version starts; a migration only
expands the schema unless it is marked as a contract step, which ships in a later release.

1. The host owns them. Migrations live in a project the host owns (the host, or a database project it references),
   never in a library package: they are provider-specific, and the application that deploys a schema owns its
   lifecycle. An `IDesignTimeDbContextFactory<T>` builds the context for `dotnet ef`, so the tools never start the host.
2. Never on startup outside Development. In Development the host, or a local orchestrator's migration step, applies
   pending migrations when it starts. In every other environment the host never migrates.
3. A deliberate step before the rollout. A pipeline job, a pre-deployment job or a database administrator applies the
   migrations once, before the new version starts, from a migration bundle (`dotnet ef migrations bundle`) or an
   idempotent script (`dotnet ef migrations script --idempotent`). A failed migration fails the release while the
   previous version still serves. The step may use a connection with schema rights that the running application lacks.
   A long data migration runs in application code after the rollout, not in this step.
4. Expand first. A migration keeps the previous release working. It may create tables, add nullable or defaulted
   columns, widen or relax a column, add non-unique indexes, and add any index or constraint to a table it creates. A
   rename is an add, a copy and a later drop, across at least two releases.
5. What contracts. A migration contracts the schema when it does any of these:
   - drops a schema, table, column or sequence, or renames a table or column;
   - adds a required column without a default to an existing table;
   - makes an existing column required, with or without a default, or removes the default of a required column;
   - changes a column's type, shrinks its maximum length, or narrows its precision or scale;
   - adds a unique index, unique constraint, primary key, check constraint or foreign key to an existing table;
   - adds a foreign key whose delete rule is `Restrict` or `NoAction` and whose principal table exists, since the
     previous release deletes principal rows without knowing the new dependents;
   - changes data (`Sql`, `InsertData`, `UpdateData`, `DeleteData`) in a way the previous release fails on or loses.
6. Contract steps are marked and later. A contracting migration carries a marker attribute with a required reason that
   names the release that stopped reading the shape it removes, and ships in a release after the one with the
   expansion it completes. A migration that changes data carries a marker that states whether the previous release
   reads the result without failing (expand) or not (contract). A unit test reads every migration's `UpOperations` and
   fails on an unmarked contracting operation or data change, on a blank reason, and on a contract marker whose
   migration only expands, so a marker cannot outlive its reason.
7. Generated code. Migrations are scaffolded, not written: `.editorconfig` marks the migrations folder as generated
   code (`generated_code = true`), so the analyzers that hold hand-written code to warnings as errors
   ([ADR-0100](0100-warnings-are-errors-in-every-project.md)) do not fail scaffolded files. A migration is edited only
   to add its marker, raw SQL, or data the scaffolder cannot express. A model change ships with its migration, which
   `dotnet ef migrations has-pending-model-changes` checks.

## Options considered

- Migrate on startup everywhere. Rejected for the race, the crash loop and the schema rights above.
- Reverse migrations on rollback. Rejected: not every migration can be reversed without data loss, and a rollback
  must be fast and safe.
- Review alone for contracting operations. Rejected: the operations hide in generated files, and some of them (a
  required column with a default, a unique index on an existing table) look harmless.
- A deliberate pre-rollout step, expand-only migrations, and a test that enforces the contract markers (chosen).

## Consequences

- A release's migrations run once, before its code, and a failure leaves the previous release serving.
- A rollback to the previous release needs no database change.
- A rename or a tightening takes two releases, and the second one's marker says why it is safe.
- A deployment pipeline gains a migration step, and its timeout covers the migrations.

## References

- [Applying migrations](https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying)
- [Migration bundles](https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying#bundles)
- [Design-time DbContext creation](https://learn.microsoft.com/ef/core/cli/dbcontext-creation)
- [ADR-0100](0100-warnings-are-errors-in-every-project.md): warnings are errors in every project.
- [ADR-0108](0108-persisted-documents-are-versioned-and-additive.md): persisted documents are versioned and additive.
