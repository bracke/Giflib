# giflib — Native Ada GIF Codec

**Specification:** 1.0 (initial implementation contract)  
**Date:** 2026-10-24  
**Status:** Implemented release contract  
**Target:** Ada 2022, GNAT 15, Alire  
**Reference architecture:** [bracke/jpeglib](https://github.com/bracke/jpeglib)  
**Format reference:** [CompuServe GIF89a specification](https://giflib.sourceforge.net/gifstandard/GIF89a.html)

## 1. Purpose and scope

Implement `giflib`, a native Ada library for parsing, decoding, authoring, and encoding GIF87a and GIF89a files. It must support still images, multiframe animations, indexed frames, RGBA compositing, LZW compression/decompression, palette conversion and quantization, and controlled metadata/extension retention. The library shall require no native C GIF library or other production codec dependency.

The implementation shall reuse architectural conventions of `jpeglib`: explicit `Streams.Source`/`Streams.Destination` limited interfaces, non-raising `Results.Result` and structured errors, bounded resource use, caller-provided pixel views, `Decoding`/`Encoding` state machines, internal private implementation packages, GNAT 15 pinned via Alire, separate AUnit `tests` crate, and verification tools. *Do not copy JPEG-specific types or behavior without GIF justification.* No runtime dependency on `jpeglib`.

**Out of scope:** GIF-like proprietary variants, embedded external codecs, color management profiles, audio, actual text rendering from Plain Text Extensions, seek-dependent decoding, undocumented heuristic recovery, random access to earlier frames in a forward-only stream, and guaranteed bit-identical reproduction after re-encoding. Plain Text Extension must nevertheless be recognized, parsed, surfaced or retained, and consume Graphic Control Extension scope correctly.

## 2. Normative vocabulary and behavior

**MUST/SHALL** is mandatory. **SHOULD** is a default subject to documented rationale. **MAY** is optional. Decoder strictness modes: `Strict`, `Compatible`, `Recover_When_Safe`; recovery may never bypass memory limits, invent missing pixels, or silently change preserved source data. All public interfaces must document which mode applies. The default is `Strict`.

The GIF format has a logical screen and zero or more graphic rendering blocks. An image descriptor identifies a subrectangle, not necessarily a full-screen frame. Frame count may be unknown until the trailer is reached. Coordinates are zero-based within the logical screen; 16-bit GIF fields must be validated before conversion into public geometry types. GIF transparency is **binary index-based**, not fractional alpha. Delay units are **centiseconds**; zero delay must be retained rather than silently clamped. Loop extension count zero denotes infinite repetition; absent loop extension is distinct from a finite count. Expose raw loop count and its meaning without guessing playback policy.

## 3. Format requirements

### 3.1 Container and extensions

- Recognize exact six-byte signatures `GIF87a` and `GIF89a`; reject other versions in strict mode.
- Parse Logical Screen Descriptor: width, height, global color table flag/size, color resolution, sort flag, background index, pixel aspect ratio. Validate nonzero logical dimensions for image decoding; allow header/trailer-only streams per format where relevant.
- Parse image separator `0x2C`, left/top/width/height, local table flag/size, interlace flag, sort flag, table entries and image-data sub-blocks.
- Handle extension introducer `0x21` and labels: Graphic Control (`0xF9`), Comment (`0xFE`), Plain Text (`0x01`), Application (`0xFF`), unknown extensions using bounded length-prefixed sub-block processing. Recognize trailer `0x3B`.
- Graphics Control Extension (GCE) applies to the **next graphic-rendering block**, image or plain-text block. It does not apply to preceding images. Apply at most one active GCE in strict mode; reject duplicate GCEs targeting the same rendering block unless compatibility policy explicitly specifies otherwise. After its target block, discard pending GCE state.
- Preserve meaningful 89a fields: disposal method (0–7 with 0/1/2/3 recognized; 4–7 reserved), user-input flag, 16-bit delay, transparent index flag/value. Reserved values are surfaced as raw values; rendered mode rejects unsupported disposal methods in strict mode and documents compatible fallback.
- The library must not interpret arbitrary Application Extension payloads as instructions. Recognize Netscape/ANIMEXTS-style looping when structurally valid; retain other application extension data without interpretation.
- Preserve extension **order and placement** relative to frames when retention is enabled. Unknown extensions and comments are byte-preserved at the payload level (including their original sub-block partitioning if the exact-preservation mode is selected). Re-encoding may change LZW byte representation.
- GIF87a encoding is allowed only when the selected content does not require GIF89a-only control or extensions. Fail rather than silently remove requested transparency, delay, animation controls, or metadata.
- Decide and document trailer/trailing bytes policy: strict rejects nontrivial data after trailer; compatible may ignore with warning. No infinite read loops on short/zero-progress sources.

### 3.2 LZW and interlacing

- Implement GIF-specific LZW (not generic TIFF LZW). Minimum LZW code size 2 through 8; literals `0 .. 2^minimum_code_size - 1`; Clear = `2^minimum_code_size`; End = Clear+1; first new code = Clear+2; initial code width = minimum+1; maximum **12 bits**, dictionary at most 4096 codes.
- Pack codes **least-significant-bit first** into bytes. Encode/decode data carried in sub-blocks of at most 255 bytes, terminated by a zero-length block.
- Correctly handle dictionary growth and width-change boundaries, repeated clear codes, dictionary-full behavior, the valid `KwKwK` special case, early/late end codes, and malformed forward references. Never emit/accept out-of-range dictionary accesses.
- Decoder must consume **exactly width × height palette indices** for a valid image. Reject too few or too many decompressed indices in strict mode; process remaining compressed sub-blocks safely to reach the next block boundary when appropriate. Reject invalid palette indices for the effective table in strict mode.
- Support interlace passes in this order (zero-based rows): `(0,8)`, `(4,8)`, `(2,4)`, `(1,2)` and inverse reordering on encode. Include heights smaller than eight in tests.

### 3.3 Palettes, transparency, disposal and looping

- Each global/local palette has 2, 4, 8, 16, 32, 64, 128, or 256 RGB entries (encoded power-of-two tables). Public palette values are RGB triples; index values are 0–255. A local palette overrides the global one for its image only. Missing effective palette is a structured decode error.
- Transparent index means “leave underlying canvas unchanged” in compositing, not “paint palette entry alpha zero into the canvas.” Preserve the index in indexed mode.
- Disposal method 0 (unspecified): expose exact value; renderer applies a documented default equal to retain/1; method 1 retains; method 2 restores the affected rectangle to logical-screen background; method 3 restores the canvas snapshot from before this frame. Snapshot/restore must be bounded and must apply only when needed.
- Canvas is initialized using the logical-screen background when a valid global palette/background index provides a color; otherwise the rendering API shall use its documented transparent initialization policy. Do not equate GIF background index with the transparent index.
- The encoded playback delay and loop count are data; no clock, animation player, or timer is required in `giflib`.
- Validate frame rectangle containment (`left + width <= screen_width`, `top + height <= screen_height`) without arithmetic overflow; do not clip silently in strict mode.

## 4. Public package layout

```text
Giflib                        -- shared scalar types and enums
Giflib.Version                -- semantic crate version
Giflib.Capabilities           -- implemented, tested features
Giflib.Errors                 -- error codes, diagnostic context, warnings
Giflib.Results                -- deterministic success/failure results
Giflib.Limits                 -- processing, allocation and work bounds
Giflib.Streams                -- Source/Destination, memory adapters
Giflib.Images                 -- indexed/RGB/RGBA views and stride checks
Giflib.Palettes               -- palette definitions/validation
Giflib.Frames                 -- frame coordinates, GCE, pixel modes
Giflib.Animations             -- logical screen, loop, composition options
Giflib.Metadata               -- extensions, retention, callbacks
Giflib.Decoding               -- forward-only incremental decoder
Giflib.Encoding               -- forward-only incremental encoder
Giflib.Quantization           -- explicit truecolor-to-indexed conversion
Giflib.Optimization           -- optional frame/palette optimization
Giflib.Internal.Bytes         -- checked little-endian readers and writers
Giflib.Internal.Blocks        -- container and sub-block parser/writer
Giflib.Internal.LZW           -- code dictionary, bit packing
Giflib.Internal.Interlacing   -- pass addressing
Giflib.Internal.Compositing   -- canvas overlay
Giflib.Internal.Disposal      -- disposal and snapshots
Giflib.Internal.Ownership     -- allocation/budget accounting
```

Only `Giflib.*` packages other than `Internal` constitute the supported public API; clients must never depend on `Internal` packages. Use `pragma Pure` / `Preelaborate` and SPARK for suitable independently provable units, not indiscriminately.

## 5. Ada data and ownership model

### 5.1 Root types

Declare root `Byte` based on `Interfaces.Unsigned_8`, 64-bit-capacity byte offsets/counts, constrained positive image sizes, zero-based coordinate types, 8-bit palette indices, centisecond delay, and `Strictness_Mode`. Distinguish logical-screen geometry from frame geometry. Check conversions to Ada index/subtype boundaries. Avoid huge stack-allocated arrays.

### 5.2 Streams

Mirror `jpeglib` stream conventions: `Source` limited interface with `Read`, `Offset`, `Skip`; `Destination` limited interface with `Write`, `Offset`, `Flush`; explicit transfer counts and source EOF; memory and fixed-buffer adapters. `Read` can return short counts; zero count without EOF/failure must fail deterministically as `Source_Zero_Progress`. `Write` can return short counts; zero-progress writes must fail. No seek required. Streaming GIF image-data sub-blocks must not require buffering all compressed bytes.

### 5.3 Image views and palettes

Image formats are `Indexed_8`, `RGB_24`, `BGR_24`, `RGBA_32`, `BGRA_32`. Indexed views keep palette separate; RGB/RGBA views are derived rendering outputs. A view contains descriptor (width, height, stride, accessible bytes) and borrowed pointer to caller storage. Image operations validate `stride >= width * bytes_per_pixel`, required buffer extent, and offset multiplication with checked arithmetic. Empty byte-array handling must be specified. No implicit allocation of image output by core decoding APIs.

A palette is a bounded count and array of at most 256 RGB entries; tables written to GIF must be a power-of-two size, padded by deterministic explicit policy when quantizer output has an arbitrary number of colors. Transparent index is recorded in frame control, not as a permanent alpha member of the palette.

### 5.4 Ownership rules

- Decoder and encoder session objects are `limited private`; they borrow Source/Destination for their active lifetime. The caller must keep borrowed stream and buffers alive until the operation ends.
- Pixel output storage is caller-owned. Its contents are defined only on documented successful completion, or for an explicitly reported partial output; failure never advertises unspecified pixels as a completed frame.
- Metadata retention must either copy into bounded library-owned storage whose lifetime ends on reset/finalize, or write into caller-supplied bounded storage. Borrowed views are not retained beyond the documented call.
- Initialization/reset/finalization must be idempotent where explicitly specified and must clean up all owned allocations on failures and cancellation. No dangling pointers or leakage on decoder/encoder reuse.
- Define memory budgeting for temporary canvas, restore snapshots, LZW tables, quantization and optional retained blocks independently from caller-owned buffers.

## 6. Decoder contract

Public API shall include operations equivalent to:

```ada
Initialize (Decoder, Source, Decode_Options, Decode_Limits);
Read_Header (Decoder, Header_Info) -> Result;
Next_Event (Decoder, Event) -> Result;  -- events include image, extension, end
Decode_Indexed_Frame (Decoder, Target, Frame_Info) -> Result;
Decode_Composited_Frame (Decoder, Target, Frame_Info) -> Result;
Skip_Frame (Decoder) -> Result;
State (Decoder) -> Decoder_State;
Cancel (Decoder) -> Result;
Finalize (Decoder);
```

The exact final Ada signatures may use `out` parameters and a distinct event-result record; all must be specified in public `.ads` prior to implementation. `Next_Event` must not consume image data invisibly if subsequent frame-decoding is required. A higher-level convenience operation `Read_Next_Frame` may wrap event iteration but must define how it handles extension-only input and trailer. A parser must support unknown total frame count and discover metadata incrementally.

Required decoder states: `Uninitialized`, `Initialized`, `Header_Ready`, `Awaiting_Frame_Decision`, `Decoding_Frame`, `Completed`, `Cancelled`, `Failed`, `Finalized` (exact names negotiable, transitions not). Invalid transitions return `Invalid_State`; fatal errors transition to `Failed` and preserve first diagnostic. After completion, repeated calls do not consume further source bytes. Reset releases previous resources and rebinds a new source.

Decoder options must include output mode (raw indexed, expanded frame rectangle, composited full logical screen), strictness, extension retention policy, and optional frame callback or pull-mode. Specify that `Decode_Composited_Frame` returns canvas pixels **after the frame is drawn, before its disposal is applied**; disposal occurs when advancing to the next frame. A skipped frame in composited mode must still be decoded/processed internally if required to preserve correct future canvas contents, or reject the skip mode explicitly.

## 7. Encoder contract

Public API shall include operations equivalent to:

```ada
Initialize (Encoder, Destination, Encode_Options, Encode_Limits);
Define_Screen (Encoder, Screen_Info) -> Result;
Set_Global_Palette (Encoder, Palette) -> Result;
Add_Extension (Encoder, Extension_Info, Payload) -> Result;
Add_Indexed_Frame (Encoder, Frame_Info, Palette_Selection, Source_View) -> Result;
Add_Truecolor_Frame (Encoder, Frame_Info, Source_View, Quantize_Options) -> Result;
Finish (Encoder) -> Result;
State (Encoder) -> Encoder_State;
Cancel (Encoder) -> Result;
Finalize (Encoder);
```

Required states: `Uninitialized`, `Initialized`, `Screen_Defined`, `Accepting_Frames`, `Completed`, `Cancelled`, `Failed`, `Finalized`. Once bytes are written to a nonseekable destination, error/cancel is not transactional; no promise to undo partial output. `Finish` writes the trailer and flushes; repeated successful `Finish` must not write duplicate trailers. `Finalize` frees resources without implicitly claiming successful completion. Output is either GIF89a by default or explicit GIF87a if all requested features are representable.

Encoder must write deterministic legal color tables, image sub-blocks, GIF LZW streams (including clear and end codes), valid control extension placement, and Netscape-compatible loop extension when requested. Individual indexed frames must be encoded without re-quantization, preserving pixel indices and exact RGB palette colors; do not promise identical compressed bytes. In truecolor mode, derive local/global palette according to explicit selection policy, and encode a transparent pixel index under a documented alpha threshold (there is no partial-alpha GIF encoding). Local/global palettes may not be silently changed in a way that changes other frames.

## 8. Quantization and optimization

Required initial quantization algorithms: deterministic exact-palette mapping when source has <=256 distinct colors (with reserved transparent index as needed), and deterministic median-cut when too many colors. Optional later algorithm: perceptual quantizer (e.g. NeuQuant-style); avoid external runtime dependencies. Dithering choices: none and Floyd–Steinberg, with explicit handling of alpha/transparency boundaries. Palette choices: fixed supplied palette, generated per-frame local palette, generated global palette when the entire input can be analyzed, or a bounded explicit two-pass/spooled source option. Never claim a single-pass global optimal palette for unknown future streaming frames.

Optimization is a separate opt-in layer: trim unchanged regions, select subrectangles, consider transparent unchanged pixels, deduplicate safe frame segments, and optimize LZW/palette size. Its contract is *rendered equivalence*, not necessarily exact preservation of frame structure or extensions. Disposal and delay semantics must remain observably equivalent under the documented reference renderer. Lossless indexed pass-through must be available independently of optimization.

## 9. Extension/metadata policy

Offer `Discard_All`, `Parse_Known_Without_Retention`, `Retain_Selected`, `Retain_All_Bounded`, with optional callback for large payloads. Metadata event descriptors must report extension label, stream offset, ordering point, payload length, decoded known properties, and truncation/unsupported flags. `Retain_All_Bounded` must fail on exhausted budgets rather than truncate silently. Application identifiers are fixed 8+3 bytes; unknown identifiers remain opaque. Comments are arbitrary bytes, not assumed UTF-8. Netscape-style loop extension must be exposed as a separate semantic field while preserving raw metadata if requested. If exact extension sub-block preservation is offered, the writer must emit original chunk boundaries where valid.

## 10. Resource limits and security

`Giflib.Limits.Limit_Set` shall include at minimum: maximum logical width/height, maximum canvas pixels/bytes, maximum frames, maximum per-frame pixels, maximum total decoded frame pixels, maximum compressed bytes, maximum extension count, maximum retained metadata bytes, maximum per-extension bytes, maximum allocation bytes, maximum output bytes, maximum LZW work (e.g. output pixels + code operations), maximum warning/diagnostic events, and maximum compositor snapshot bytes. Reasonable safe defaults must be documented and caller-adjustable; limits of the wire format are not memory-allocation permissions.

Reject overflow before allocating or multiplying geometry; bounds-check every palette lookup, bit shift, code-table reference, sub-block length, row/stride calculation and decoded output count. No unbounded recursion. Do not process untrusted lengths into unconstrained stack arrays. Dictionary reset must clear necessary state. Fuzz malformed GCE, misordered extensions, endless zero-progress streams, invalid widths, oversized chunk chains, truncated compressed data, dictionary exhaustion, invalid transparent index, undefined disposal, and compressed decompression bombs. Deterministic failures (no unhandled exceptions) for all malformed inputs under default limits.

## 11. Errors and diagnostics

Retain `jpeglib`-style `Results.Result` (status and first error) and structured `Errors.Error` with stable machine-readable identifiers, e.g. `gif.invalid_signature`, `gif.truncated_block`, `gif.lzw.invalid_code`, `gif.palette.index_out_of_range`, `gif.frame.out_of_bounds`, `gif.limit.exceeded`, `gif.state.invalid`, `gif.stream.zero_progress`. Diagnostic context should include source/destination offsets, frame ordinal, block/extension label, compressed code location (when known), expected/actual values and limit implicated. Warning records for compatibility fallbacks must be bounded. Public data errors must not be reported as internal invariants.

## 12. Crate and project structure

```text
giflib/
  alire.toml
  giflib.gpr
  AGENTS.md
  README.md
  LICENSE
  src/
    giflib.ads
    giflib-*.ads / .adb
  docs/
    specification.md
    public-api.md
    conformance.md
  tests/
    alire.toml
    tests.gpr
    src/ (AUnit suites, runner, tools)
    fixtures/ (goldens, malformed cases, animation cases)
```

Root `alire.toml` shall declare `name = "giflib"`, `version = "0.1.0-dev"`, MIT, and `gnat_native = "^15"` using `jpeglib`'s organization. Child Alire crate named `tests` shall depend on `giflib`, `aunit`, and `project_tools`, with local `giflib` path pin. Auxiliary test-only image tools may be used for cross-verification, not by the production crate. `AGENTS.md` shall state that builds and compiler invocation run through Alire and pinned GNAT. Exact test binary names may be concise (`giflib_tests`, `giflib_check`, `giflib_conformance`, `giflib_fuzz`, `giflib_benchmark`).

## 13. Testing matrix

| Area | Required cases |
|---|---|
| Container | GIF87a/89a, global/local/no palette, extension ordering, trailer, malformed signature/length |
| LZW | 2–8 min code size, clear at start/middle, dictionary boundary 9/10/11/12 bits, full dictionary, `KwKwK`, corrupt indices, missing End, malformed sub-blocks |
| Geometry | 1×1, thin/tall, width and height <8, 255/256/257 dimensions, edge subrectangles, invalid containment |
| Interlace | All four passes, tiny image heights, arbitrary dimensions, re-encode/re-decode |
| Animation | multiple frames, zero/nonzero delays, absent/finite/infinite loops, partial rectangles, local palette changes |
| Disposal | 0,1,2,3 plus 4–7 rejection/fallback, transparent draw, background handling, restore-to-previous after nested partial frames |
| Metadata | comments, plain text, application, Netscape loop, unknown extensions, retention, exact ordering, budget failure |
| I/O | memory, fragmented reads/writes, nonseekable source, chunk boundaries, EOF, zero-progress, destination failure |
| Quantization | exact <=256 colors, >256 colors, alpha threshold, local/global palettes, deterministic output, dither options |
| Stress | large dimensions with tight limits, many frames, many extension blocks, LZW expansion, cancellation and reset |
| Compatibility | decode externally generated GIFs; independently decode giflib output with two widely used implementations |

AUnit shall compare decoded indexed pixels and palette values to known expected data; rendered animations shall compare each composited RGBA canvas frame to a verified reference. For lossy quantization only, assert output dimension/alpha correctness and a defined quality metric threshold; do not demand exact RGB equality. Include deterministic metamorphic/round-trip tests and fuzz seed regression corpora. Validate GIF89a conformance separately from implementation-specific APIs. Benchmark decode/encode throughput and maximum memory without making performance an initial release blocker.

## 14. Implementation phases and acceptance gates

### Phase A — Foundation

Create repository/crates, package specs, result/stream adapters, checked byte/sub-block readers and writers, limits and invariant tests. **Gate A:** clean `alr build`, AUnit runner, no public API stubs disguised as working functionality, and checked short-I/O behavior.

### Phase B — Decoder

Implement container parser, indexed palette/frame decoding, LZW, interlace, extensions, loop metadata, and composited frames including disposal. **Gate B:** all required valid fixture corpus decodes correctly; all malformed cases fail deterministically; fully streamed, multi-frame GIF87a/GIF89a support.

### Phase C — Encoder

Implement indexed still/multiframe encoding, GIF89a controls and looping, optional valid GIF87a emission, palette/table output, LZW compression, and streamed sub-block writing. **Gate C (minimum functional release):** output accepted by independent decoders; decoder round-trip preserves palette-index pixels and frame control semantics; build/test/conformance checks pass; zero production external codec dependencies.

### Phase D — Truecolor/quantization

Implement truecolor convenience encoding with exact colors, median-cut fallback, no-dither/Floyd–Steinberg, alpha threshold handling, global/local palette options. **Gate D:** deterministic corpus and visual quality metrics pass; no frame-data corruption or wrong transparency.

### Phase E — Optimization and completion

Implement opt-in animation optimization, expanded metadata policies, corpus fuzz/stress, documentation, SPARK proofs of eligible arithmetic/LZW helpers and benchmark measurements. **Library-complete gate:** external corpus/matrix, concurrency/reuse testing (independent objects), bounds verification, docs/API review, packaging and optimization equivalence requirements all pass. Completion means *all* features declared by `Capabilities` are tested, and no required checks are waived.

## 15. Implementation discipline for coding agents

1. Inspect the current `bracke/jpeglib` structure and adapt shared patterns; do not assume file shapes based on this specification alone.
2. Create specs and invariants before `.adb` bodies. Lock error policy, buffer ownership, state transitions, limits and event model first.
3. Implement one verifiable format feature at a time. Add tests and goldens before moving to the next feature.
4. All work through `alr`, using GNAT 15 pinned by the crate. Use AUnit and `project_tools` in the tests crate.
5. Enforce deterministic results and bounded memory; never catch programming errors merely to claim successful decoding.
6. Do not mark an API or capability as implemented unless fully exercised by tests. No placeholder successes.
7. Keep README and implementation/coverage matrix updated, with explicit supported and unsupported modes.
8. Final delivery includes build output, passing test counts, generated GIF samples, external interoperability evidence, outstanding limitations, and coverage of gates A–E.

## 16. Decisions fixed by this specification

- **Language**: native Ada 2022; GNAT 15 via Alire.
- **Compatibility**: GIF87a decoder and GIF89a decoder/encoder; GIF87a encoding only for representable streams.
- **Animation**: first-class; frame rectangles and composited full-canvas results are separate operations.
- **Palette fidelity**: indexed decode and indexed encode are lossless in pixel indices/palette values (not binary file identity).
- **I/O**: forward-only streaming; callers own pixel buffers.
- **Errors**: structured non-raising results for expected invalid input, strict by default.
- **Security**: explicit budgets and checked arithmetic.
- **Testing**: independent AUnit child crate and external decoder cross-checks.
- **Delivery**: first release at Gate C; advanced quantization/optimization required for complete library at Gate E.

## 17. Source references

1. CompuServe, *Graphics Interchange Format Version 89a*: https://giflib.sourceforge.net/gifstandard/GIF89a.html
2. Existing Ada reference library: https://github.com/bracke/jpeglib
3. `jpeglib` API examples: `src/jpeglib-streams.ads`, `src/jpeglib-images.ads`, `src/jpeglib-decoding.ads`, `src/jpeglib-encoding.ads`, `src/jpeglib-errors.ads`, `src/jpeglib-results.ads`, `src/jpeglib-limits.ads`.

**End of specification.**
