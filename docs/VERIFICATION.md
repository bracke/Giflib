# SPARK verification boundary

The following production units are in SPARK mode:

- `Giflib.Internal.Block_Arithmetic`: exact bounded sub-block read and write
  transfer-state transitions used by the production block reader and writer.
- `Giflib.Internal.Budget_Arithmetic`: bounded resource charging with
  overflow-safe attempted totals, used by allocation accounting and the shared
  work-meter abstraction.
- `Giflib.Internal.Work_Budgets`: sticky stateful work meters built on the
  bounded charging primitive and shared by LZW, quantization, and optimization.
- `Giflib.Internal.Checked_Arithmetic`: checked count addition and
  multiplication, including success/failure postconditions.
- `Giflib.Internal.Descriptor_Arithmetic`: logical-screen and image-descriptor
  packed flags, palette lengths, and color resolution used by the production
  parser and encoder.
- `Giflib.Internal.Encoding_Arithmetic`: palette table rounding, GIF packed
  size codes, and minimum LZW code sizes used by the production encoder.
- `Giflib.Internal.Extension_Arithmetic`: little-endian 16-bit extension
  fields, graphic-control packing and unpacking, and reserved-bit
  classification used by the production decoder and encoder.
- `Giflib.Internal.Geometry_Arithmetic`: pixel areas, rectangle edges, and
  canvas containment used by parsing, decoding, encoding, quantization, and
  optimization.
- `Giflib.Internal.Image_Arithmetic`: row-byte and strided-buffer extent
  calculation used by `Giflib.Images.Required_Bytes`.
- `Giflib.Internal.LZW_Arithmetic`: code-table initialization, decoder and
  encoder width transitions, bounded encoder hash probing, and dictionary
  stack/traversal/insertion guards used by both production LZW paths.
- `Giflib.Internal.LZW_Bit_Arithmetic`: exact LSB-first bit-buffer packing,
  extraction, byte removal, and first-byte recovery used by both production
  LZW paths.
- `Giflib.Internal.Metadata_Arithmetic`: retention decisions, block mapping,
  payload capacity, and count increments
  used by the production decoder.
- `Giflib.Internal.Optimization_Arithmetic`: conservative control safety,
  changed-pixel bounds, rectangle dimensions, and bounded delay merging used
  by the production frame optimizer.
- `Giflib.Palettes`: bounded palette containment and active-entry comparison.
- `Giflib.Internal.Pixel_Arithmetic`: row-major pixel indices and component
  byte offsets used by compositing, snapshots, expanded decoding, and frame
  extraction.
- `Giflib.Internal.Rendering_Arithmetic`: shared RGBA canvas, rectangle, and
  auxiliary-buffer extent validation used by compositing and disposal.
- `Giflib.Internal.Quantization_Arithmetic`: histogram indexing and
  decomposition, channel clamping/differences, and bounded squared color
  distances used by the production quantizer.
- `Giflib.Internal.Quantization_Buffer_Arithmetic`: dither-buffer allocation,
  row/channel spans, and two-row error-buffer indices used by the production
  quantizer.
- `Giflib.Decoding.State_Arithmetic`: private decoder lifecycle guards.
- `Giflib.Encoding.State_Arithmetic`: private encoder lifecycle guards.
- `Giflib.Internal.Session_Arithmetic`: shared extension-count and warning
  capacity arithmetic without codec dependencies.
- `Giflib.Internal.Interlacing`: GIF pass counting and row mapping.
- `Giflib.Internal.Ownership_Arithmetic`: deterministic allocation-failure
  state transitions stored per object and armed only by test child packages.
- `Giflib.Internal.Stream_Arithmetic`: transfer caps and windows plus bounded
  read, skip, and write progress used by the production stream adapters.

The release gate runs flow analysis and level-2 proof with cvc5 over the whole
SPARK subset:

```sh
alr exec -- gnatprove -P giflib.gpr \
  --level=2 --prover=cvc5 --report=all -j1
```

`Giflib.Internal.Ownership`, `Owned_Arrays`, `Owned_Buffers`, and
`Owned_Objects` are runtime-checked Ada. They provide scoped reservation
rollback and ledger-identity-checked ownership, but are outside the SPARK
subset because they manage controlled types and heap allocation.

The test crate declares only `unit_tests.gpr` and `giflib_tests` as its default
Alire project and executable inventory, so the root test action regenerates its
development configuration and builds only the AUnit runner before executing
`tests/bin/giflib_tests` by its exact path. Root and test manifests carry inert
configuration-epoch scenarios so a layout change invalidates legacy ignored
setup hashes before a generated `config/` tree is required.
Generated Alire settings, configuration sources, and test logs are ignored and
are not versioned repository inputs.
`giflib_whitebox.gpr` compiles the workspace sources for internal tests without
weakening the production library's supported `Library_Interface` boundary;
only `unit_tests.gpr` imports that project. Repository tools import the
production `giflib.gpr`, so tool and unit-test builds never share library
artifacts and the tools continuously exercise the supported interface.
The white-box suite is a `Giflib.Testing` descendant hierarchy, which is allowed
to test the private `Giflib.Internal` child without making it public. A separate
consumer built through `public_api.gpr` compiles against the production project,
and `check_private_api.sh` requires a direct client import of `Giflib.Internal`
to fail. Both Alire crates pin GNAT 15, and all project variants import compiler
switches from `giflib_build.gpr`.
Separate actions ensure that a compilation or test failure makes `alr test`
fail, and selecting an exact executable prevents stale binaries for other
profiles from making execution ambiguous. Repository workflow tools are
 isolated in `tools.gpr` and are built explicitly by the release gate rather than
every unit-test invocation.
The stream tests inject exceptions from every callback family (`Read`, `Skip`,
`Write`, `Offset`, and `Flush`) and require structured, non-raising outcomes.
Extension behavior is exercised through the per-kind decoder handlers and both
shared encoder chunking paths.

GNATprove discharges the declared postconditions, termination, initialization,
range checks, division checks, and overflow checks in these units. In
particular, the budget helper proves that accepted charges fit both the limit
and `Byte_Count` while rejected diagnostic totals saturate safely; the
descriptor helper proves exact packed-field decoding and encoding across all
byte values; the encoding helper proves palette table sizes and their
corresponding packed and LZW codes; the extension helper proves exact
little-endian fields, graphic-control bit packing, and reserved-bit
classification; the geometry helper proves maximum GIF areas and rectangle
edges fit `Byte_Count` and gives an exact containment result; the image-extent
helper proves that accepted row/stride arithmetic fits `Byte_Count`; the LZW
helper proves code initialization, width changes, and hash slots remain within
their table bounds, and its stack and dictionary guards prevent invalid
traversal and insertion; the LZW bit helper proves exact bounded LSB-first bit
operations; the block helper proves exact sub-block transfer-state updates;
the metadata helper proves retention, capacity, and
payload count transitions; the session helper proves lifecycle, extension
capacity, and warning bounds; the rendering helper proves RGBA rectangle and
buffer extents; the ownership helper proves allocation-failure injection transitions are bounded
and self-disabling; the optimization helper proves its bounding-box
transitions and delay sums remain ordered and in range; the quantization helper
proves every histogram and color-distance result remains in range; the pixel
helper proves row-major and component offset calculations cannot overflow
`Byte_Count`; the quantization-buffer helper proves all dither allocation sizes
and two-row/channel indices fit their declared bounds; the interlace mapper
proves its result never exceeds the image height; and the stream helper proves
transfer windows and progress increments stay within both the request and the
backing buffer at maximum counter values.

Classwide stream dispatch, the mutable I/O loops around sub-block state,
bounded-string construction, actual pointer mutation and allocation/deallocation
for metadata, images, and sessions, protected synchronization, quantizer
heap-object lifecycle and median-cut loops, decoder/encoder object mutation,
and LZW dictionary array storage and traversal loops remain outside the current
SPARK subset. Their controlling transfer, index, bit-buffer, lifecycle,
retention, allocation-accounting, and traversal-bound transitions are now in
proved helpers. The remaining safety boundary is explicit checks, fixed limits,
runtime assertions/overflow checks, adversarial tests, deterministic
allocation-failure injection, independent codec oracles, and the mutation
harness. These regions are tested but are not represented as formally proved.
