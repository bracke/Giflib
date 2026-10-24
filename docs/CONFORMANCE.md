# Conformance and test matrix

The production library has no external codec dependency. ImageMagick and
FFmpeg are invoked by Ada test tooling as decoder oracles; independent DocBook
XSL files and ImageMagick-generated files are kept separate from
giflib-generated artifacts.

| Area | Evidence |
|---|---|
| GIF87a/GIF89a container | `container.*`, `decoder.gif87a.*`, `decoder.gif89a.*` |
| Global/local palettes and indices | `descriptor.*`, `image_data.*`, independent ImageMagick/DocBook corpus |
| Interlace | `interlace.*`, ImageMagick 9×9 interlaced fixture |
| LZW sizes/transitions/full dictionary | `lzw.minimum_code_sizes_2_to_8`, `lzw.kwkwk_and_width_transition`, `lzw.dictionary_full` |
| Malformed LZW/blocks/extensions | `lzw.malformed_and_output_count`, `blocks.*`, `extensions.malformed_and_budgets` |
| Animation/loop/delay/disposal | `encoding.gif89a.animation`, `compositing.*`, three-frame ImageMagick fixture |
| Metadata ordering/exact chunks | `extensions.retention_order_and_loop`, `encoding.extension_exact_placement` |
| Strict/compatible/safe recovery | `policy.*` |
| Quantization/alpha/dither | `quantization.*`, external true-color quality oracle |
| Frame optimization | `optimization.*` |
| Short I/O and zero progress | `streams.*` plus fragmented container/codec tests |
| Resource limits | width/height, canvas, frame/total pixels, frames, compressed bytes, extensions, metadata, allocation, output, work, warning/diagnostic, and snapshot tests |
| Robustness | deterministic 10,000-case mutation harness, seed `3235823838` |
| Encoder interoperability | ImageMagick 6.9.12-98 and FFmpeg 6.1.1 |

The Ada executable `giflib_check release` is the release gate. It builds the
library, test crate, and example; runs AUnit and the deterministic fuzzer;
regenerates and checks independent fixtures; validates giflib output with both
external oracles; and runs SPARK flow analysis.

All repository-owned generators, validators, benchmarks, fuzzers, and check
drivers are Ada programs built on the shared `project_tools` crate. The release
gate validates the local pin and tooling inventory. External command-line
codecs remain test-only processes and are never linked into the library.
