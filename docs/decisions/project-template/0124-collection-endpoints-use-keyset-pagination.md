# 0124. Collection endpoints use keyset (cursor) pagination, not a query protocol

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

This decision applies to projects that host ASP.NET Core and expose collections over an HTTP API.

An API that lets callers enumerate a resource family needs a collection `GET`. A collection endpoint that returns every
row is unbounded: a latent denial of service and a memory and latency cliff as the data grows. Two questions follow:
how to paginate, and whether to adopt a general query protocol (OData, JSON:API) for the read surface.

## Decision

Each resource family's collection `GET` returns one page using keyset (cursor) pagination, with no general query
protocol.

- Shape: `{ "items": [ ... ], "continuationToken": "..." | null }`. A non-null token means more pages exist; the caller
  passes it back as `?cursor=` to fetch the next page. The token is opaque to the caller.
- Keyset, not offset: the page is ordered by a unique, indexed key, and the query fetches `limit + 1` rows whose key is
  greater than the cursor's. The extra row tells whether another page exists.
- `?limit=` is clamped to a server maximum (for example default 50, maximum 100).
- The persistence layer owns the cursor: it encodes the last key of a page (base64url) and decodes it on the next
  request. Code above it never parses the cursor. The keyset mechanics (decode, fetch `limit + 1`, detect more, encode)
  live once, and each query supplies only its ordered query and its key.
- Authorization of a listing is decided once per request for the family and scope, not per item.
- Small collections that are bounded by design (the few children of one resource) are returned whole, without paging.
- A specific filter, when one is needed, is an explicit query parameter backed by an explicit query method
  ([ADR-0107](0107-filtered-reads-push-filtering-to-the-database.md)), added without breaking the contract.

## Options considered

- A query protocol (OData, JSON:API). Rejected: arbitrary filters, sorts, and expansions need `IQueryable` exposed to
  the web layer or a partial translator; they open a denial-of-service and complexity surface (unindexed sorts,
  expensive predicates, N+1 expansions); they are a large versioned public contract; and OData pages by offset.
- Offset pagination (`?page=&pageSize=`). Rejected: pages drift under concurrent writes, so items are skipped or
  repeated, and high offsets degrade to scanning and discarding rows.
- Filtering each page by per-item authorization. Rejected: a page then holds fewer than `limit` items and the "more
  pages" signal breaks.

## Consequences

- Every family lists through one uniform, bounded shape.
- Paging a large, changing collection is correct and costs an index seek per page.
- There is no expression language to secure, version, or tune.
- A caller cannot jump to page N or get a total count; a feature that needs either records that need separately.

## References

- [Pagination in EF Core: keyset pagination](https://learn.microsoft.com/ef/core/querying/pagination#keyset-pagination)
- [ADR-0107](0107-filtered-reads-push-filtering-to-the-database.md): filtered reads push filtering into the database.
- [ADR-0123](0123-resource-ids-are-server-generated-and-opaque.md): resource identifiers are server-generated and
  opaque.
