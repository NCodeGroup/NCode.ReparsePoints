# 0127. The Data Protection key ring is shared, encrypted at rest, and checked at startup

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

This decision applies to projects that host ASP.NET Core.

ASP.NET Core Data Protection protects authentication cookies, antiforgery tokens, temporary data and anything the
application protects through `IDataProtector`. Its keys live in a key ring, and its defaults fit one process on one
machine:

- With no repository configured, the ring goes to a directory in the user profile, or to memory when there is none, as
  in most containers. Each instance then has its own ring: a cookie issued by one instance is rejected by the next,
  and a restart or a replaced container signs everyone out.
- On Linux and in containers that fallback is not encrypted at rest. A ring persisted beside the data it protects,
  with nothing wrapping it, gives whoever holds a database backup the keys to every protected value in it.
- The application discriminator defaults to the content root path, so two deployments of one application at different
  paths cannot read each other's payloads even with a shared ring.
- When the ring holds a key the application cannot decrypt, for example after a partial restore or a changed wrapping
  key, Data Protection does not stop. It treats the key as unusable, quietly creates a new default key and carries on,
  and the operator learns of it from users who were signed out.

## Decision

Outside Development the key ring is persisted where every instance reads it, wrapped by a key held outside that
storage, and the host refuses to start while the ring is missing, unprotected, or holds a live key it cannot decrypt.

1. Shared storage. The ring is persisted to storage every instance reads and that survives a restart: the
   application's database (`PersistKeysToDbContext`), a blob container, or a shared cache with persistence. Never the
   default directory, a container's file system, or memory.
2. A fixed application name. `SetApplicationName` is set to a constant, so every instance and deployment of the
   application shares payloads, and no other application that shares the storage does.
3. Encrypted at rest by an outside key. The ring is protected by an `IXmlEncryptor` whose key lives outside the ring's
   storage: a key management service, a hardware security module, or a certificate from the secret store. A
   certificate is rotated by adding the new one and keeping the old one for unprotecting
   (`UnprotectKeysWithAnyCertificate`), never by renewing it in place.
4. Checked at startup. Outside Development, the production check
   ([ADR-0119](0119-production-refuses-development-only-settings.md)) fails while `KeyManagementOptions` has no
   repository or no encryptor. A hosted service registered before Data Protection's own reads every key that is
   neither revoked nor expired and reads its descriptor, which decrypts it. A key it cannot decrypt is logged with its
   id, and the host then throws one exception naming every such key and the setting that revokes them. In Development
   it revokes such a key and logs a warning instead.
5. Revocation by id. An option lists key ids to revoke; at startup each listed key is revoked through `IKeyManager`
   with a reason, without decrypting it. Revoking is idempotent, so the list can stay or go once the host has started.
6. Expired keys are kept. A key expires after its lifetime (90 days by default) but stays in the ring, because it still
   unprotects what it protected. Keys are revoked, never deleted.
7. Ephemeral keys only where nothing outlives the process. An in-memory ring or `EphemeralDataProtectionProvider` is
   for Development and tests; each test host keeps its own ring, so no test reads keys another run wrote.

## Options considered

- The defaults. Rejected: per-instance rings sign users out on every restart and every load-balancer hop, and the ring
  is unencrypted on Linux.
- A shared ring without encryption. Rejected: a backup of the storage holds the keys to everything they protect.
- Letting Data Protection replace a key it cannot decrypt. Rejected: it hides a broken key hierarchy behind a mass
  sign-out.
- Shared, encrypted, and checked at startup (chosen).

## Consequences

- Any instance reads what any other protected, and a restart or a new deployment keeps everyone signed in.
- A deployment supplies an outside key or a key management service before its first start, or the host does not start.
- A ring the application cannot read stops the host with the key ids to revoke, and revoking them is the recovery,
  at the cost of the sessions those keys protected.
- Rotating a wrapping certificate keeps the old certificate until no stored payload depends on a key it wrapped.

## References

- [Configure ASP.NET Core Data Protection](https://learn.microsoft.com/aspnet/core/security/data-protection/configuration/overview)
- [Key storage providers](https://learn.microsoft.com/aspnet/core/security/data-protection/implementation/key-storage-providers)
- [Key encryption at rest](https://learn.microsoft.com/aspnet/core/security/data-protection/implementation/key-encryption-at-rest)
- [ADR-0119](0119-production-refuses-development-only-settings.md): Production refuses development-only settings.
- [ADR-0146](0146-secrets-are-never-logged-compared-in-constant-time-and-shown-once.md): secrets are never logged,
  compared in constant time, and shown once.
