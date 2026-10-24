# Benchmark notes

The Ada executable `tests/bin/giflib_benchmark [GIF ...]` runs the native
decoder and then true-color re-encoder for each input. It reports input/output
sizes, geometry, frame count, decode/encode wall time, and peak process RSS from
Linux `/proc/self/status`. Paths supplied by the caller make it usable with a
real-world corpus; with no arguments it uses the three deterministic generated
samples.

Baseline captured 2026-10-24 on the development x86-64 Linux container with the
GNAT 15 development profile:

| Input | Geometry | Frames | Decode (s) | Encode (s) |
|---|---:|---:|---:|---:|
| DocBook XSL `tip.gif` | 25×24 | 1 | 0.00097 | 0.00054 |
| DocBook XSL `warning.gif` | 24×24 | 1 | 0.00037 | 0.00061 |
| generated animation | 2×1 | 2 | 0.00002 | 0.00005 |

The combined run used approximately 2,852 KiB peak RSS. These small-file
figures are regression baselines, not broad throughput claims. Exact timings
depend on the host; resource-limit and output-equivalence tests are normative.
