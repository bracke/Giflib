# Public API notes

The supported API consists of `Giflib` and its non-`Internal` child packages.
Names use Ada title case with underscores; encoded format names retain their
usual spelling in documentation.

## Foundation availability

- `Giflib` defines fixed-capacity byte/count/offset, image geometry, palette,
  timing, strictness, block, LZW-context, and resource-limit types.
- `Giflib.Errors` provides stable `gif.*` identifiers and diagnostic context.
- `Giflib.Results` represents expected success/failure without exceptions.
- `Giflib.Limits` provides caller-copyable safe defaults for every required
  resource category.
- `Giflib.Streams` defines forward-only limited interfaces and memory adapters.
- `Giflib.Capabilities` is authoritative for implemented feature families.

`Read` and `Write` may transfer fewer bytes than requested. `Read_Exact`,
`Skip_Exact`, and `Write_All` complete short transfers and reject successful
zero-byte progress deterministically. Storage passed to `Open` is borrowed and
must outlive the adapter. The adapters allocate no memory.

Decoder, indexed/true-color encoder, image view, palette, frame, animation,
metadata, quantization, and conservative optimization APIs are available. No
placeholder operation reports success.

`Giflib.Images.Image_View` borrows strided caller storage. Quantization writes
indices into an exactly sized caller buffer. Generated palettes preserve exact
first-seen RGB colors when they fit; otherwise deterministic 5-bit-histogram
median cut is used. RGBA/BGRA alpha values at or below the selected threshold
reserve generated index zero. Floyd–Steinberg error diffusion never propagates
from a transparent pixel.

True-color encoding defaults to generated per-frame local palettes. An existing
global palette can be selected for fixed mapping, or reused only when generated
entries match it. A caller wanting a generated global palette performs an
explicit analysis pass with `Giflib.Quantization`, installs that palette, and
then selects the existing-global strategy; no streaming API predicts colors in
future frames.

`Giflib.Optimization` is opt-in and conservative. It operates on equivalent-
palette, opaque full-canvas indexed renderings and declines trimming/merging for
disposal 2/3, user-input frames, existing transparency, or palette changes.
This restriction keeps rendered pixels, disposal behavior, and summed delays
equivalent without guessing playback policy.

## Decoder lifecycle and output

The forward-only pull sequence is `Initialize`, `Read_Header`, repeated
`Next_Event`, then the decode/skip operation selected for each image event.
`Raw_Indexed` writes exactly `width * height` indices; `Expanded_Frame` writes
the frame rectangle as RGBA; `Composited_RGBA` writes the whole logical canvas
after drawing and before disposal. Disposal is applied while advancing to the
next composited frame. Repeated completion does not consume input. Fatal data
errors preserve the first diagnostic; `Reset` releases owned canvas, snapshot,
and metadata storage before rebinding another source.

Retained metadata is ordered by `Before_Frame`. `Retain_Selected` keeps comment
and application payloads; the bounded all modes keep every extension, and the
exact mode also exposes original valid sub-block boundaries. Loop absence,
finite values, and zero/infinite looping remain distinct.

## Encoder lifecycle and ownership

The forward-only sequence is `Initialize`, `Define_Screen`, optional global
palette/loop setup, frame and extension additions, then `Finish`. `Finish` is
idempotent; cancellation/failure cannot retract bytes already delivered to a
nonseekable destination. Indexed input is never requantized. Caller source,
destination, image, and output buffers must outlive the call/session that
borrows them. Expected invalid data, unsupported state transitions, exhausted
budgets, and stream failures are returned through `Giflib.Results.Result`.
