# Benchmark notes

The Ada executable `tests/bin/giflib_benchmark [GIF ...]` runs the native
decoder and then true-color re-encoder for each input. It reports input/output
sizes, geometry, frame count, median decode/encode wall time over five samples,
and peak process RSS from Linux `/proc/self/status`. Every decoded animation
frame is re-encoded into a counting destination, avoiding an output-sized
scratch allocation while preserving encoder work and byte accounting. Paths
supplied by the caller make it usable with a real-world corpus.
`--synthetic-truecolor` encodes a raw 512×512 RGB pattern
with more than 256 colors, so the median-cut path is measured without first
passing through GIF's 256-color ceiling. With no workload arguments the harness
runs the three deterministic generated samples and the raw true-color case.
The release gate rebuilds with the release profile, runs every case in a
separate process, and passes `--enforce` to apply conservative throughput and
64 MiB peak-RSS guardrails.

Baseline captured 2026-10-24 on the x86-64 Linux container with GNAT 15 and the
release profile:

| Input | Geometry | Frames | Decode (s) | Encode (s) |
|---|---:|---:|---:|---:|
| DocBook XSL `tip.gif` | 25×24 | 1 | 0.00014 | 0.00011 |
| DocBook XSL `warning.gif` | 24×24 | 1 | 0.00013 | 0.00013 |
| ImageMagick animation | 3×1 | 3 | 0.00002 | 0.00002 |
| ImageMagick 256-color GIF fixture | 512×512 | 1 | 0.04575 | 0.08342 |
| Raw RGB median-cut input | 512×512 | 1 | — | 0.27437 |

The two 512×512 cases used approximately 5,956 KiB and 4,296 KiB peak RSS,
respectively. These figures are regression baselines, not broad throughput
claims. Exact timings depend on the host; enforced ceilings deliberately leave
wide headroom for host variance, while resource-limit and output-equivalence
tests remain normative.
