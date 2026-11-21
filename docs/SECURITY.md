# Security and resource verification

All wire dimensions, sub-block lengths, frame rectangles, palette indices, LZW
codes, output counts, and caller buffer extents are checked before use. Decoder
and encoder failures return structured results and retain the first fatal
diagnostic. Source/destination helpers reject successful zero-byte progress.
All classwide stream callbacks are invoked through a facade that converts
callback exceptions to structured failures; an exceptional `Offset` callback
only makes location context unavailable.

Every field in `Giflib.Limits.Limit_Set` has an execution-path test. The
conservative default profile caps library-owned allocation and encoded output at
64 MiB, canvas and snapshot storage at 16 MiB each, and maximum canvas/frame
area at 4,194,304 pixels. It caps LZW and optimization work at `2 ** 26`
charged units and quantization work at `2 ** 28`. `High_Capacity_Limits` is an
explicit opt-in profile for trusted batch workloads. Configured-budget
exhaustion is reported as `gif.limit.exceeded`; host heap exhaustion in the
decoder, quantizer, and true-color encoder is reported separately as
`gif.allocation.failed`.
Caller-owned output arrays are never retained. LZW tables
are fixed at the GIF maximum, allocated as reusable session workspaces, charged
to the allocation budget, and released by every terminal lifecycle path;
recursive parsing is not used. Test-only child
packages deterministically arm object-local allocation state so `Storage_Error`
conversion, partial-allocation cleanup, and subsequent reuse can be exercised
without process-global hooks or reliance on host memory pressure. Separate
decoder, encoder, and quantizer objects cannot consume one another's injected
failure. Allocation ledgers derive charges from `Object_Size` and
`System.Storage_Unit`. Encoder and quantizer ledgers have independent ownership,
while the encoder resource manager enforces their combined session ceiling.
Reusable handles retain only ledger identity—not a pointer to caller-owned
state—and require the owning ledger on release. Ledger mismatch checks remain
active independently of assertions and cannot debit or release the foreign
ledger. Allocation charges are acquired through controlled reservation guards,
so an uncommitted charge is rolled back on every scope exit. Retained metadata
ownership is isolated in `Giflib.Internal.Metadata_Store`; its in-progress node
is store-local, it is bound to its owning ledger, and its allocation-accounted
extension and sub-block indexes avoid repeated linked-list scans.
Resource finalizers contain cleanup faults and keep production-owned failure
state without embedding test observers in decoder, encoder, or quantizer
layouts.

`giflib_fuzz` performs deterministic truncation, deletion, overwrite, XOR, and
suffix mutations across literal, independent ImageMagick/DocBook, LZW
dictionary-growth, and spec-derived high-expansion seeds. Before mutation, the
handcrafted LZW seeds are decoded and every expected index is checked; the
high-expansion seed must also remain below its compact-size ceiling. Each case
uses short reads and tight limits, caps event traversal, and decodes image data
through LZW and RGBA
compositing whenever the mutated container reaches an image event. The
2026-10-24 baseline completed 10,000 cases with seed `3235823838` (final PRNG
state `2752455965`) without an unhandled exception or hang.

This is regression evidence, not a claim of exhaustive memory safety. Run the
harness under platform sanitizers or a process supervisor when integrating it
into a broader fuzzing campaign.
