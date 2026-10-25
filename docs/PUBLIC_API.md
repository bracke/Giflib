# Public API notes

The supported API consists of `Giflib` and the documented children listed in
this file. Private children, `Giflib.Internal.*`, and test-only children are
excluded by the production library project's `Library_Interface`.
Names use Ada title case with underscores; encoded format names retain their
usual spelling in documentation.

## Foundation availability

- `Giflib` defines fixed-capacity byte/count/offset, image geometry, palette,
  timing, strictness, block, LZW-context, and resource-limit types.
- `Giflib.Errors` derives stable `gif.*` identifiers from the error or warning
  code and provides diagnostic context without storing redundant identifier
  state.
  The discriminated `Source_Position` and `Destination_Position` components
  distinguish positions that were not checked, were checked but unavailable,
  or are available. Their numeric value exists only in the available variant,
  so contradictory state/value combinations cannot be constructed. This also
  prevents callback retries while a diagnostic is enriched. Frame, LZW, and
  underlying callback details use the same discriminated optional-value model.
- `Giflib.Results` represents expected success/failure without exceptions; its
  status is derived from the single stored error so inconsistent status/error
  combinations are not representable.
- `Giflib.Limits` provides caller-copyable safe defaults for every required
  resource category. Warning retention uses `Warning_Record_Limit`, from zero
  through the public `Maximum_Warning_Records` bound (256), so an unsupported
  warning capacity cannot be silently reduced.
- `Giflib.Streams` defines forward-only limited interfaces and memory adapters.
- `Giflib.Capabilities` is authoritative for implemented feature families.

`Read` and `Write` may transfer fewer bytes than requested. `Read_Exact`,
`Skip_Exact`, and `Write_All` complete short transfers and reject successful
zero-byte progress deterministically. The safe stream facade converts callback
exceptions to `Source_Read_Failed` or `Destination_Write_Failed`; a failing
`Offset` callback marks the diagnostic position unavailable. Memory adapters
are constructed with an access discriminant designating their storage, and
decoder/encoder sessions are constructed with the corresponding stream access
discriminant. Ada therefore enforces each borrowed lifetime; `Open` only resets
an existing adapter's position and transfer cap. Decoder initialization and
event production require an available source offset because every public event
carries an exact offset; an unavailable or failing offset is returned as a
non-raising `Source_Read_Failed` diagnostic with position state unavailable.

Decoder, indexed/true-color encoder, image view, palette, frame, animation,
metadata, quantization, and conservative optimization APIs are available. No
placeholder operation reports success.

`Giflib.Images.Image_View` borrows strided caller storage. Quantization writes
indices into an exactly sized caller buffer and returns one
`Quantization_Result` containing the palette plus a discriminated transparency
result. Its nested palette and transparency option variants contain only the
settings active for the selected policies. Generated palettes preserve exact
first-seen RGB colors when they fit; otherwise deterministic 5-bit-histogram
median cut is used. RGBA/BGRA alpha values at or below the selected threshold
reserve generated index zero. Floyd–Steinberg error diffusion never propagates
from a transparent pixel.
The ordinary `Quantize` operation releases temporary storage before returning;
the overload taking a limited-private `Workspace` retains bounded histogram,
cache, and dither storage in a private controlled resource component until
explicit finalization or scope exit, with
`Allocated_Bytes` exposing its charge and `Cleanup_Succeeded` exposing sticky
cleanup status.
Pixel-format access and Floyd–Steinberg row diffusion are isolated internal
phases; median-cut palette construction is a separate deterministic, budgeted
phase.

True-color encoding defaults to generated per-frame local palettes. An existing
global palette can be selected for fixed mapping, or reused only when generated
entries match it. A caller wanting a generated global palette performs an
explicit analysis pass with `Giflib.Quantization`, installs that palette, and
then selects the existing-global strategy; no streaming API predicts colors in
future frames.

Encoder request preflight is non-destructive: invalid extension descriptors,
palettes, frame geometry, image views, buffer sizes, and configured limits are
reported before output and may be corrected and retried. Stream, allocation,
compression, and other failures after processing begins make the session
terminal and preserve its first fatal diagnostic.

`Giflib.Optimization` is opt-in and conservative. It operates on equivalent-
palette, opaque full-canvas indexed renderings and declines trimming/merging for
disposal 2/3, user-input frames, existing transparency, or palette changes.
This restriction keeps rendered pixels, disposal behavior, and summed delays
equivalent without guessing playback policy. Both analysis and rectangle
extraction accept `Limit_Set` constraints and charge every pixel comparison or
copy against `Max_Optimization_Work`.

## Decoder lifecycle and output

The forward-only pull sequence is `Initialize`, `Read_Header`, repeated
`Next_Event`, then the decode/skip operation selected for each image event.
An image event has already parsed and retained its descriptor and optional local
palette. It reports the rectangle geometry plus exact `Indexed_Bytes` and
`Expanded_Bytes`, allowing a caller to allocate output before decoding. The
image-data code size and sub-block stream remain unread until decode or skip.
`Raw_Indexed` writes exactly `width * height` indices; `Expanded_Frame` writes
the frame rectangle as RGBA; `Composited_RGBA` writes the whole logical canvas
after drawing and before disposal. Disposal is applied while advancing to the
next composited frame. `Skip_Frame` is rejected in `Composited_RGBA` mode
because an undecoded frame could change the canvas needed by later frames.
Repeated completion does not consume input. Fatal data
errors preserve the first diagnostic; `Reset` releases owned canvas, snapshot,
and metadata storage before restarting on the bound source. A different source
requires a separately constructed decoder.

Decoding retains a fixed-size LZW workspace, and composited decoding also
retains grow-only indexed-frame and restore-snapshot buffers across frames.
They remain charged to the decoder allocation budget and are released on reset
or finalization. Decoder, encoder, and reusable
quantization workspace objects also finalize their private, non-overrideable
resource components automatically at scope exit; explicit finalization remains
idempotent for deterministic early release. Cleanup invariant failures cannot
escape a controlled finalizer; explicit session lifecycle calls retain them as
`Internal_Invariant_Failed` unless an earlier fatal diagnostic already exists.

Retained metadata is ordered by `Before_Frame`. Extension and decoder event
records are discriminated by kind, so only fields meaningful to that kind are
present. `Retain_Selected` keeps comment
and application payloads; the bounded all modes keep every extension, and the
exact mode also exposes original valid sub-block boundaries. Loop absence,
finite values, and zero/infinite looping remain distinct. Extension events
surface decoded Graphic Control and Plain Text header fields even when payload
retention is disabled. Truncated extensions return a structured failure instead
of a partial event; unknown extension labels and application identifiers are
surfaced as opaque metadata rather than classified as unsupported.
Retained-extension and exact sub-block indexes are bounded and allocation
accounted, so indexed enumeration does not repeatedly scan linked lists.
Out-of-range enumeration indexes return `Invalid_Index`; undersized
caller-owned copy buffers return `Buffer_Size_Mismatch` rather than being
reported as session-state or configured-limit failures.
Constrained discriminated outputs whose variants cannot represent a produced
header, event, frame, optimization analysis, or retained extension return
`Output_Variant_Mismatch` rather than raising `Constraint_Error`.
Frame-output variant and buffer-size mismatches are checked before consuming
image data. They leave the decoder awaiting the same frame so callers can retry
with an appropriate output object.

Encoding re-exports the discriminated `Giflib.Metadata.Extension_Descriptor`.
Comment, application, and plain-text variants derive their fixed GIF labels;
only the unknown variant carries a caller-supplied label; known/reserved labels
in that variant are rejected non-raisingly by the encoder. Graphic-control
extensions are encoded through frame control and are not descriptor variants.
Application and plain-text payloads include their raw fixed headers. Distinct
`Add_Decoded_Extension` operations accept decoded `Extension_Info` for round
trips, reject graphic-control metadata, and deliberately derive only the
encoding descriptor; offsets, placement, counts, and parsed fields remain
decoder observations.

## Encoder lifecycle and ownership

The forward-only sequence is `Initialize`, `Define_Screen`, optional global
palette/loop setup, frame and extension additions, then `Finish`. `Finish` is
idempotent; cancellation/failure cannot retract bytes already delivered to a
nonseekable destination. Indexed input is never requantized. Caller source,
destination, image, and output buffers must outlive the call/session that
borrows them. Expected invalid data, unsupported state transitions, exhausted
budgets, and stream failures are returned through `Giflib.Results.Result`.
A destination `Storage_Error` is reported as `Destination_Write_Failed`, not
as exhaustion of the library's allocation budget.
Indexed frame palette choice is a discriminated `Frame_Palette`: the global
variant has no irrelevant local palette value, while the local variant requires
one. Frame transparency, decoded local-palette details, and optimization
results use the same variant-based modeling so inactive fields cannot retain
contradictory values.
Byte counters retain every byte accepted before a destination failure,
including bytes written during a partially emitted LZW sub-block.
Encoding sessions retain a fixed-size LZW workspace; true-color sessions also
retain a grow-only indexed buffer and quantization workspace. All are charged
to the session allocation budget and released on failure, cancellation, or
`Finalize`. Indexed palette values are checked as they enter LZW compression;
such a late failure can leave bytes on a nonseekable destination, consistent
with the session's nontransactional failure contract.
