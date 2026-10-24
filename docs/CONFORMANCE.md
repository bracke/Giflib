# Conformance and test matrix

The production library has no external codec dependency. ImageMagick and
FFmpeg are invoked by Ada test tooling as decoder oracles; independent DocBook
XSL files and ImageMagick-generated files are kept separate from
giflib-generated artifacts.

| Area | Evidence |
|---|---|
| GIF87a/GIF89a container | `container.*`, `decoder.gif87a.*`, `decoder.gif89a.*` |
| Global/local palettes and indices | `descriptor.*`, `image_data.*`, independent ImageMagick/DocBook corpus |
| Geometry boundaries | `container.geometry_255_256_257`, `descriptor.geometry_and_limit` |
| Interlace | `interlace.*`, ImageMagick 9×9 interlaced fixture |
| LZW sizes/transitions/full dictionary | `lzw.minimum_code_sizes_2_to_8`, `lzw.kwkwk_and_width_transition`, `lzw.dictionary_full`, `lzw.buffered_input`, mandatory-initial-Clear rejection, buffered encoder round-trip/fragmentation |
| Malformed LZW/blocks/extensions | `lzw.malformed_and_output_count`, `blocks.*`, `extensions.malformed_and_budgets` |
| Animation/loop/delay/disposal | `encoding.gif89a.animation`, `encoding.options_and_lifecycle`, `extensions.animexts_loop`, `compositing.*`, three-frame ImageMagick fixture, generated delay/iteration external-oracle checks |
| Metadata ordering/exact chunks | `extensions.retention_order_and_loop`, `extensions.retention_policies_and_bounds`, `encoding.extension_exact_placement` |
| Encoder lifecycle/options | `encoding.options_and_lifecycle`, `encoding.truecolor.local_and_global` |
| Strict/compatible/safe recovery | `policy.*`, including reserved image-descriptor bits |
| Quantization/alpha/dither/channel order | `quantization.*`, including RGB/BGR/RGBA/BGRA and workspace reuse, plus external true-color quality oracle and raw-RGB median-cut benchmark |
| Frame optimization | `optimization.*` |
| Short I/O and zero progress | `streams.*` plus fragmented container/codec tests |
| Resource limits | width/height, canvas, frame/total pixels, frames, compressed bytes, extensions, metadata, allocation, output, work, warning/diagnostic, and snapshot tests |
| Heap exhaustion | `allocation_failures.*` uses test-only child packages to inject object-local `Storage_Error` at every allocation site and checks isolation, non-raising cleanup, and frame/snapshot/workspace reuse |
| Independent session objects | `decoder.independent_objects_interleave`, `encoding.independent_objects_interleave` |
| Robustness | deterministic 10,000-case mutation harness, seed `3235823838` |
| Independent decoder corpus | `decoder.independent_file_corpus` compares every composited RGBA frame from ImageMagick fixtures to fixed expected pixels |
| Encoder interoperability | ImageMagick 6.9.12-98 and FFmpeg 6.1.1 |

The Ada executable `giflib_check release` is the release gate. It builds the
library, test crate, and example; then runs AUnit, the deterministic fuzzer,
independent fixture generation, and both external oracles against both the
development and optimized release binaries. It subsequently enforces
separate-process timing/peak-RSS guardrails with the release binaries and runs
full SPARK proof over the checked-arithmetic,
budget-arithmetic, sub-block-state, descriptor-packed-field, encoder-sizing,
extension-field, geometry, image-extent, LZW dictionary/bit arithmetic,
metadata-state, session/allocation-state, optimizer-decision, palette-helper,
pixel-offset, quantization arithmetic/buffer indexing, interlace, and
stream-progress units.

All repository-owned generators, validators, benchmarks, fuzzers, and check
drivers are Ada programs built on the shared `project_tools` crate. The release
gate validates the local pin and tooling inventory. External command-line
codecs remain test-only processes and are never linked into the library.
