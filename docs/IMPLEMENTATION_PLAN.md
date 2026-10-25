# giflib — Implementation Plan

**Status:** M0–M5 implemented; release candidate is untagged  
**Contract:** [SPECIFICATION.md](SPECIFICATION.md) (authoritative)  
**Reference:** https://github.com/bracke/jpeglib

## Operating rules

- Implement in Ada 2022, using Alire with `gnat_native = "^15"`. No production dependency on C GIF libraries or on `jpeglib`.
- Implement all repository-owned generators, validators, fuzzers, benchmarks,
  and workflow drivers in Ada using the shared `project_tools` crate. External
  command-line codecs may be invoked only as independent test oracles.
- Read the specification and relevant `jpeglib` package interfaces before changing a public API. Any design conflict must be resolved in the specification first.
- For each task, implement its public contract, internal implementation, positive and adversarial AUnit tests, and documentation together. Keep tasks small enough for one focused coding-agent session.
- Build after each task (`alr build`, `alr --chdir tests build`) and run tests. Do not claim completion without verified results.
- Never suppress corrupt input or exceed configured limits to make a test pass. Keep error reporting non-raising and deterministic.
- All unimplemented public capabilities report unsupported explicitly; no stub that returns success.
- Tasks below are ordered; tasks within a milestone can be subdivided while preserving dependencies.

## M0 — Skeleton and test harness

**Completed (2026-10-24):** Tasks 1–5 and Gate M0. The GNAT 15 Alire
library/test crates, public foundation API, diagnostics, limits, stream
adapters, compile consumer, and AUnit runner are implemented and verified.

1. Create Alire library crate `giflib`, GNAT 15 pin, MIT license, `src/`, and a separate Alire binary `tests/` crate dependent on `aunit` and `project_tools`; compile workspace sources for internal tests through `giflib_whitebox.gpr` while keeping the production library interface restricted.
2. Establish public root `Giflib` scalar types, version, capabilities, and naming guidelines. Add a compile-only consumer test.
3. Implement `Errors`, `Results`, `Limits` and explicit diagnostics (stream offsets, block types, frame ordinal, LZW code context). Test each status and limit.
4. Implement `Streams.Source` / `Streams.Destination` interfaces, memory source and fixed-buffer destination. Test partial reads/writes, EOF, zero progress, offsets and failure propagation.
5. Add `AGENTS.md`, README, reproducible AUnit runner and basic build/test scripts or Alire actions.

**Gate M0:** clean root and tests builds; basic API consumer compiles; stream, error and limit tests pass.

## M1 — Container, palettes and decoding fundamentals

**Completed (2026-10-24):** Tasks 6–12 and Gate M1. Checked byte/sub-block
I/O, GIF87a/GIF89a headers, global/local palettes, image geometry, bounded GIF
LZW, exact caller-owned indexed output, four-pass interlacing, and the public
incremental decoder state machine are covered by independent literal fixtures
and malformed streams.

6. Implement bounded low-level byte read/write, checked arithmetic and GIF sub-block reader/drainer; test empty, 255-byte, truncated and oversized chains.
7. Parse signatures, logical screen descriptor, global palette, trailer; distinguish GIF87a/GIF89a and reject invalid dimensions or missing bytes.
8. Parse image descriptors and effective local/global palettes. Validate frame geometry and palette references using overflow-safe checks.
9. Implement GIF-specific little-endian bit-order LZW decoder with 12-bit bounded dictionary, clear/end codes, KwKwK case and width transitions. Unit-test with handcrafted streams.
10. Decode pixel indices into caller-owned buffers, enforce exact output count and total work budgets, handle early EOF and excess output.
11. Implement four-pass interlace mapping, including tiny images and dimensions not divisible by eight.
12. Integrate streaming `Giflib.Decoding`: initialize/read header/read next frame/finish/reset/finalize; state-transition and cancellation tests.

**Gate M1:** independent fixtures for GIF87a and GIF89a, global/local palettes, interlacing, and malformed LZW; deterministic bounded decoding on forward-only sources.

## M2 — Full GIF89a animation and extension decoding

**Completed (2026-10-24):** Tasks 13–18 and Gate M2. GCE scope, ordered
bounded metadata retention (including exact sub-block boundaries), loop data,
public frame/animation types, RGBA compositing, disposal 0–3, transparent
indices, bounded restore snapshots, and strict/compatible/safe-recovery policy
behavior are implemented and tested.

13. Parse graphics control extensions: disposal codes, delay, user-input flag, transparency; scope to next *graphic rendering* block (including plain-text extension).
14. Parse comments, application extensions, Netscape/ANIMEXTS loop data, plain-text extension and unknown extensions. Preserve order, placement and optionally sub-block partitioning under retention budgets.
15. Define `Frames` and `Animations` types separating local raw indexed frame rectangles from composited whole-canvas output.
16. Implement RGBA compositing, palette expansion, transparent-index behavior and initial background policy.
17. Implement disposal 0/1/2/3 and bounded snapshots for restore-to-previous; verify overlapping partial rectangles, interlace + transparency and background behavior.
18. Implement `Strict`, `Compatible`, `Recover_When_Safe` policy matrix for duplicates, reserved disposal, trailing bytes and truncation. Record warnings explicitly.

**Gate M2:** animated GIFs with loop data, delays, transparency and all defined disposal modes produce reference RGBA frames; extension round-trip metadata is reconstructible; strict failure cases behave as documented.

## M3 — Indexed and animated encoding

**Completed (2026-10-24):** Tasks 19–24 and Gate M3. The forward-only encoder
writes deterministic GIF87a/GIF89a stills and animations, global/local color
tables, GCE/loop data, interlaced image data, exact retained extension chunking,
and bounded GIF LZW. Independent checks with ImageMagick 6.9.12-98 and FFmpeg
6.1.1 validate generated indexed pixels, frame geometry/count, timing, loop,
disposal-driven compositing, and file readability.

19. Implement low-level GIF block writer, palette serialization, extensions and GIF87a/GIF89a format selection with explicit invalid-feature rejection.
20. Implement GIF LZW encoder (LSB-first bit writer, 12-bit dictionary, reset/clear, End code) with deterministic output and 255-byte sub-block fragmentation.
21. Implement `Giflib.Encoding` state machine, indexed still image encode, palette validation, image descriptor and interlaced output.
22. Add animation encoding: frame offsets, local/global palettes, GCE timing/transparency/disposal and optional loop extension.
23. Implement optional exact preservation of selected extension payloads and position, with documented limits (not necessarily bit-identical LZW output).
24. Test encoder output with `giflib` decoder **and** independent external decoders. Verify multiple frame counts and timing/disposal structures, not only rendered pixels.

**Gate M3 (functional release):** decode and encode conforming still and animated GIFs; no required C runtime codecs; round trips agree at indexed-frame and rendered-frame levels where preservation is requested.

## M4 — Full-color encoding and optimizations

**Completed (2026-10-24):** Tasks 25–28 and Gate M4. Caller-owned strided
RGB/BGR/RGBA/BGRA views feed deterministic exact or median-cut quantization,
fixed/generated palettes, alpha-threshold transparency, and optional
Floyd–Steinberg dithering. True-color encoding supports per-frame local,
existing global, and identical-global reuse strategies; callers can generate a
global palette in an explicit analysis pass. The opt-in conservative optimizer
trims retained opaque canvases, makes unchanged rectangle interiors transparent,
and merges safe redundant delays while refusing unsafe disposal/control cases.
Independent ImageMagick/FFmpeg checks include lossy true-color output. The
native benchmark harness reports five-sample median per-file decode/encode time
and process peak RSS for generated and caller-supplied real-world corpora. The
release gate uses optimized builds, encodes every animation frame, runs cases
in separate processes, enforces conservative timing/RSS ceilings, and includes
a deterministic raw 512×512 input with more than 256 colors so median-cut is
measured directly.

25. Implement color quantization with deterministic median-cut baseline, optional dithering, indexed transparency mapping and palette-size selection. Validate error metrics and adversarial pixel inputs.
26. Add configurable global vs. local palette strategies and palette reuse decisions.
27. Add optional frame rectangle differencing and redundant-frame optimization, retaining correct disposal semantics and timing.
28. Measure peak memory and encoding speed on real-world still/animated fixture corpus; tune without changing API semantics.

**Gate M4:** RGB/RGBA to GIF encoding is deterministic, bounded and externally readable; optimizations preserve decoded visual frames, delays and loop semantics.

## M5 — Conformance, security and release completeness

**Completed (2026-10-24):** Tasks 29–34 and Gate M5. The corpus separates
externally sourced DocBook images and independently generated ImageMagick
goldens, and giflib encoder artifacts. It covers both versions, palette and
interlace variants, three-frame timing/disposal/looping, LZW code sizes 2–8,
dictionary transitions/full state, metadata, and malformed inputs. A
deterministic 10,000-case bounded multi-seed mutation harness, including LZW
dictionary-growth, high-expansion, and composited frame decoding, passes; every declared
resource limit has an execution-path test; both external decoder oracles pass;
independent decoder objects interleave safely; and the example, benchmark,
conformance/security/API documentation, Alire metadata check, and full SPARK
proof of checked and budget arithmetic, encoder palette/code sizing, image
geometry and extents, descriptor packed fields, GIF extension control/U16
fields, LZW code/width/hash arithmetic, palette helpers, optimizer
decision/bounds arithmetic, pixel/component offsets, quantization color/index
and error-buffer arithmetic, sub-block state, LZW bit-buffer and dictionary
guards, metadata retention/count state, session lifecycle/allocation accounting,
object-local allocation-failure state, interlacing, and stream transfer/progress accounting are
reproducible through the Ada
`giflib_check release` command.
All excluded SPARK
regions are recorded in `docs/VERIFICATION.md`. No release tag was created;
tagging remains a post-verification release action.

29. Curate independently sourced and independently generated golden files: GIF87a/GIF89a, interlace, palettes, transparency, looping, disposal, unknown extensions, all LZW width transitions and malformed cases.
30. Build deterministic fuzz harness and mutation corpus. Verify no hangs, out-of-bounds access, arithmetic overflow or unbounded allocation on corrupt sources.
31. Exercise all memory, pixel, frame, metadata, compressed input, decompression work and warning limits; use short-read/short-write streams.
32. Add external-oracle comparisons (e.g. ImageMagick, gifsicle, giflib toolchain) as **test-only** dependencies; log versions and reproducible seeds.
33. Add SPARK contracts/proofs for bounded arithmetic, sub-block parsing, palette indexing and LZW invariants where practical; document excluded regions.
34. Run public API and packaging checks; document semantics, examples, supported capabilities and benchmark data. Tag release only after all gates pass.

**Gate M5 (library complete):** reproducible tests and conformance matrix pass, fuzz/security evidence recorded, public interfaces documented, crate builds standalone with Alire.

### Ada tooling inventory

The AUnit entry point is `giflib_tests`; the other repository-owned workflow
programs are `giflib_check`, `giflib_generate_samples`,
`giflib_generate_fixtures`, `giflib_external_checks`, `giflib_benchmark`, and
`giflib_fuzz`. `unit_tests.gpr` builds only the AUnit runner for the normal test
action; `tools.gpr` builds the remaining workflow programs for release and
tooling gates. Every entry point uses `project_tools`; the release gate validates
both the workspace pin and both GPR/source inventories.
Internal tests alone import the dedicated `giflib_whitebox.gpr`; workflow tools
import the production `giflib.gpr`, use separate artifacts, and remain limited
to the supported units exported by it.
The white-box suite uses the `Giflib.Testing` descendant hierarchy so Ada's
private-child rules remain intact. A production-project consumer compile and an
expected-failure private-child import guard that boundary. The root and tests
crates both pin GNAT 15, and all GPR variants share compiler-switch policy from
`giflib_build.gpr`. Allocation and ownership tests are separate domain-specific
AUnit cases. Large individual procedures live under `tests/src/subunits`,
keeping package inventory checks focused without sharing unrelated fixtures or
dependencies.

## Cross-cutting acceptance checklist

- Every external-input length/count is checked before allocation, multiplication, conversion or indexing.
- No reliance on seeking; handle partial reads and writes, end of input and zero progress.
- Caller-owned buffers never escape their documented lifetime; avoid copying full images unnecessarily.
- Strictness, warning handling and explicit limits are stable and testable.
- Indexed decoding never silently composites; composited decoding honors disposal and transparency exactly.
- Preserve loop count `0` (infinite), zero delays, and absence of loop extension as distinct cases.
- Reject unsupported reserved features in strict mode and document compatible fallback explicitly.
- Build & test commands run under Alire-pinned toolchain, not whichever GNAT happens to be on PATH.

## Suggested implementation session protocol

Pick the earliest incomplete numbered task. Read its relevant specification sections and current implementation, write or update tests, implement only the scoped feature, run its focused tests and full existing suite, record results in a concise commit, then advance. Do not mark milestone gates passed based solely on compilation or a decoder↔encoder self-round-trip.
