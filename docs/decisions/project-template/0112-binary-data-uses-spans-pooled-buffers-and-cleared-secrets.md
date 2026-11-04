# 0112. Binary data uses spans, caller-owned writers, pooled buffers, and cleared secrets

- **Status:** Accepted
- **Date:** 2026-10-31

This decision applies to code that processes binary data: encoding, hashing, cryptography, serialization, parsing.
Code that never handles bytes is unaffected.

## Context

The default .NET idiom for binary work is `byte[]`: allocate an array, return it, let the garbage collector take it.
On paths that run per request that is the wrong default on three axes:

- Allocation pressure: a fresh array from every encode, export, or transform churns generation 0.
- Secret hygiene: an array holding key material or a password lingers on the managed heap until it is collected, and
  compaction can leave copies of it in process memory.
- Inconsistency: without a convention, code mixes `byte[]`, `ArrayPool<byte>`, `ArrayBufferWriter<byte>`,
  `MemoryStream`, and manual concatenation, and clearing secrets is easy to forget.

## Decision

1. Model binary data as spans and memory, not arrays. APIs accept `ReadOnlySpan<byte>` or `ReadOnlyMemory<byte>` and
   write results into a caller-supplied `IBufferWriter<byte>` instead of returning a new `byte[]`. A producer that may
   be called with a struct writer uses the generic shape
   `void Write<TWriter>(ref TWriter destination) where TWriter : IBufferWriter<byte>, allows ref struct`. When the
   result size is known, a `bool TryWrite(Span<byte> destination, out int bytesWritten)` variant is the span-first
   alternative.
2. Rent transient buffers. A temporary working buffer is rented from `ArrayPool<byte>.Shared` (or
   `MemoryPool<byte>.Shared`) and returned in a `finally`, rather than allocated with `new byte[]`. A small buffer of
   a fixed, bounded size uses `stackalloc`.
3. Sensitivity is explicit. Secret material (keys, passwords, nonces, plaintext) is cleared when its buffer is
   released: `CryptographicOperations.ZeroMemory` on the span, or `ArrayPool.Return(array, clearArray: true)`. A
   long-lived secret is held in a pinned array (`GC.AllocateArray<byte>(length, pinned: true)`) so compaction never
   copies it. Secret text is encoded to bytes once, at the earliest boundary, and passed down as
   `ReadOnlyMemory<byte>`, not re-encoded from a `string` in a leaf method.
4. Multi-segment data is read as a sequence. A `ReadOnlySequence<byte>` is processed segment by segment or with
   `SequenceReader<byte>`, using `IsSingleSegment` and `FirstSpan` as the fast path, never `.ToArray()`.
5. Byte constants are UTF-8 literals: `"Bearer "u8`, not `Encoding.UTF8.GetBytes("Bearer ")` at run time, as the C#
   conventions say.
6. Reinterpret with `MemoryMarshal`, not element-by-element copies. Converting between bytes and spans of blittable
   values uses `MemoryMarshal.Cast`, `MemoryMarshal.AsBytes`, and `MemoryMarshal.Read`/`Write`, guarded by
   `BitConverter.IsLittleEndian` where byte order matters. Parsing a defined wire byte order uses `BinaryPrimitives`.
7. Hot-path primitives may trade readability for speed. The inner loops of measured performance-critical primitives may
   use `AggressiveInlining`, manual unrolling, `stackalloc`, and `Unsafe`, under two constraints that always win:
   constant-time code gains no data-dependent branch or memory access, and test vectors pin correctness. This is a
   scoped exception to the clean-code conventions, justified by a benchmark.

Existing `byte[]` surfaces convert as they are touched, not in one sweep.

## Options considered

- `byte[]` everywhere. Rejected for the three reasons above.
- A pooled-buffer helper library. Possible, and a project may adopt one; the rules above hold with only the base class
  library.

## Consequences

- Hot paths avoid per-operation allocations, and clearing secrets is the default.
- Writer-first APIs compose: a caller can target a pooled writer, a fixed span, or a `PipeWriter` without the producer
  allocating.
- Contributors learn the span and pooling idioms instead of reaching for `byte[]`.

Gotchas:

- Never `stackalloc` inside a loop (CA2014): the memory is reclaimed only when the method returns. Hoist one buffer
  above the loop and clear it per iteration.
- `stackalloc` only small, constant-bounded sizes (a hash, a key); never a caller-controlled length. Larger sizes rent.
- A `using` local cannot be passed by `ref` (CS1657). Keep the `using` variable that owns disposal and pass a second,
  non-`using` local that refers to the same writer.
- `MemoryMarshal.Cast` and `Read`/`Write` are host-endian. Keep the `BitConverter.IsLittleEndian` guard with a
  `BinaryPrimitives.ReverseEndianness` fallback.
- Multi-part hashing uses `IncrementalHash.AppendData`, not concatenation into one buffer.
- A pooled array may be larger than requested; slice it to the requested length before use.

## References

- `.github/instructions/csharp.instructions.md`, UTF-8 String Literals
- [Memory and spans](https://learn.microsoft.com/dotnet/standard/memory-and-spans/)
- [`ArrayPool<T>`](https://learn.microsoft.com/dotnet/api/system.buffers.arraypool-1)
- [`CryptographicOperations.ZeroMemory`](https://learn.microsoft.com/dotnet/api/system.security.cryptography.cryptographicoperations.zeromemory)
