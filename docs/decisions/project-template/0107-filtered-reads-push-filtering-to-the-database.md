# 0107. Filtered reads push their filter into the database

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

A recurring smell in data access code: a service reads a table's entire set (a full list, or every page of a paged
read) and then filters the materialized items in memory. This fetch-all-then-filter shape pushes no predicate to the
database, so it cannot use indexes; it transfers every row, and every expensive child collection, only to discard most
of them; and when several readers in one request each re-scan the same set, the waste compounds. It also hides a
scaling cliff: it is fast with test data and slow in production.

Two alternatives come up:

- A cached, per-request collection that loads the set once and keeps filtering in memory. It removes repeated reads but
  keeps the fetch-all shape and adds cache invalidation.
- A specification or `Expression<Func<TEntity, bool>>` parameter on a store interface. It leaks `IQueryable` into the
  abstraction, and a store not built on LINQ (Dapper, hand-written SQL, a document database) can no longer implement
  it.

## Decision

When code needs a filtered subset of a table, the filter runs in the database.

- Where data access goes through a store or repository interface, a filtered read is a discrete, intent-named method
  (`GetActiveCustomerIdsAsync`, `FindOpenOrdersByRegionAsync`) that names what to fetch, not how. The Entity Framework
  implementation translates it to a LINQ query the provider runs as SQL; another implementation writes its own query.
  No `IQueryable` or `Expression` crosses the interface. Without a store abstraction the principle is the same: the
  `Where` goes on the query, before it materializes.
- A general paged read stays for genuine unfiltered listing
  ([ADR-0124](0124-collection-endpoints-use-keyset-pagination.md)), not as a filtering mechanism.
- A read that needs only a few columns projects into a narrow type (`Select` into a record), so the query never joins
  or materializes child collections it does not need. Only readers that need the full entity load it.
- When the domain compares a value exactly but the database can only match it efficiently in another form (for example
  a case-sensitive value stored with a case-insensitive collation or a normalized column), the database filter is a
  widening pre-filter that never drops a true match, and the reader re-applies the exact comparison in memory over the
  small result.

## Options considered

- A per-request cache over full reads. Rejected as the default; a cache can be layered on top of intent-named queries
  later if profiling shows the query count is the bottleneck.
- Expression parameters on store interfaces. Rejected for the coupling described above.
- Intent-named queries with projections (chosen).

## Consequences

- Each reader transfers only the rows, and for projections only the columns, it needs, filtered by indexes.
- The persistence contract stays independent of the ORM.
- More, narrower store methods instead of a few broad reads. That granularity is intended: each method is one
  index-friendly query and documents a real access pattern.
- "You chose wrong" smell: a `Where`, `First`, or `Any` applied to the result of a method that returned a whole table.

## References

- [Efficient querying in EF Core](https://learn.microsoft.com/ef/core/performance/efficient-querying)
- [ADR-0124](0124-collection-endpoints-use-keyset-pagination.md): collection endpoints use keyset pagination.
