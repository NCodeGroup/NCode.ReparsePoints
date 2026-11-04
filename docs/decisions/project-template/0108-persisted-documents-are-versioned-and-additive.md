# 0108. Persisted JSON documents are schema-versioned, upcastable, and keep unknown members

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

Applications often store a domain object as a JSON document: a JSON column, a blob, a cache entry, a message in a
queue. A bare `JsonSerializer` round-trip reads such documents forward-tolerantly by luck of the defaults (unknown
members are skipped), but it has no story for deliberate schema change of data already written:

- With no version marker on a stored document, a migration has nowhere to hook. A non-additive change (renaming,
  removing, or retyping a member, or removing an enum value) silently misreads or throws on old documents.
- Adding a `required` member is a latent break: `System.Text.Json` enforces `required` on deserialization, so every
  older document without it throws.
- An enum stored as its number misreads when members are reordered, and an older reader cannot tell an unknown member
  from a known one.
- During a rolling deployment, an older instance that reads a document written by a newer one and writes it back drops
  the members it did not recognize.

## Decision

Persisted JSON documents whose shape will evolve are written through one versioned serialization seam.

- One seam: a single serializer service is the only code that reads or writes the documents of a kind.
- A self-describing envelope: a document is stored as `{ "$ver": N, "$payload": { ... } }`. Payload members never begin
  with `$`. A document without `$ver` is read as version 1, so documents written before the envelope still read.
- A declared current version: each payload type declares its current schema version (an attribute or a constant,
  defaulting to 1), stamped on write.
- Upcasters for non-additive change: an upcaster migrates one step, from version N to N + 1, on the mutable
  `System.Text.Json.Nodes` DOM. On read, the serializer chains the upcasters from the stored version to the current one
  before deserializing. A missing step throws instead of misreading. A stored version newer than the current one (after
  a rollback) is read forward-compatibly, skipping unknown members; nothing is down-cast.
- Unknown members survive a rewrite: a payload that is read, modified, and written back, and that lives long enough to
  span a deployment, carries a `[JsonExtensionData]` property.
- Additive by default: a new member is optional (nullable or defaulted), never `required`. Enums are written as their
  names (`JsonStringEnumConverter`), never as numbers. A member is never renamed, removed, or retyped in place; such a
  change bumps the version and ships an upcaster.

Documents with no schema to evolve (a plain list of strings) and opaque blobs stored and returned verbatim are out of
scope.

## Options considered

- A bare serializer round-trip. Rejected for the reasons above.
- A version column beside the document. Rejected: it couples the version to the relational schema and does not travel
  with the document when it is copied elsewhere (a cache, a queue, an export).
- A version member on each domain type. Rejected: it puts a storage concern on the domain type, under the very
  deserialization it is meant to govern.
- Extension data alone. Rejected: it keeps unknown members but cannot rename, remove, or restructure known ones; it
  complements upcasting.
- Envelope, upcasters, and extension data (chosen).

## Consequences

- Adding an optional member needs no version bump.
- A non-additive change is a deliberate, testable act: bump the version and add one upcaster, with a test that reads a
  document of the previous version.
- The pipeline is dormant until the first non-additive change; the value delivered from day one is the version in the
  data and the single seam.
- The serializer throws a descriptive `JsonException` on a corrupt document or a missing upcaster step.

## References

- [System.Text.Json: required properties](https://learn.microsoft.com/dotnet/standard/serialization/system-text-json/required-properties)
- [System.Text.Json: handle overflow JSON](https://learn.microsoft.com/dotnet/standard/serialization/system-text-json/handle-overflow)
- [System.Text.Json: JsonNode DOM](https://learn.microsoft.com/dotnet/standard/serialization/system-text-json/use-dom)
- [ADR-0110](0110-shared-state-is-changed-by-read-modify-write.md): stored state is changed by a read-modify-write that
  loses no concurrent write.
