# Security and resource verification

All wire dimensions, sub-block lengths, frame rectangles, palette indices, LZW
codes, output counts, and caller buffer extents are checked before use. Decoder
and encoder failures return structured results and retain the first fatal
diagnostic. Source/destination helpers reject successful zero-byte progress.

Every field in `Giflib.Limits.Limit_Set` has an execution-path test. Allocation
failures in the decoder, quantizer, and true-color encoder are converted to
`gif.limit.exceeded`; caller-owned output arrays are never retained. LZW tables
are fixed at the GIF maximum and recursive parsing is not used.

`giflib_fuzz` performs deterministic truncation, deletion, overwrite, XOR, and
suffix mutations against a valid GIF89a seed. Each case uses short reads and
tight limits, caps event traversal, and exercises parsing plus skipped image
data. The 2026-10-24 baseline completed 10,000 cases with seed `3235823838`
(final PRNG state `2752455965`) without an unhandled exception or hang.

This is regression evidence, not a claim of exhaustive memory safety. Run the
harness under platform sanitizers or a process supervisor when integrating it
into a broader fuzzing campaign.
