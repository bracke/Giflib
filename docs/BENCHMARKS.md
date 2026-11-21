# Benchmark notes

The Ada executable `tests/bin/giflib_benchmark [GIF ...]` runs development
benchmarks. Build the release tool with
`alr --chdir tests exec -- gprbuild -p -P tools.gpr
-XGIFLIB_BUILD_PROFILE_OVERRIDE=release` and use
`tests/bin/release/giflib_benchmark [GIF ...]` for reportable measurements and
`--enforce`; non-release executables reject enforcement to prevent false
regressions. The executable reports its active profile, input/output
sizes, geometry, frame count, median decode/transcode process CPU time over five samples,
and peak process RSS from Linux `/proc/self/status`. Enforced timings use
process CPU time to exclude descheduling delay and reduce shared-runner noise;
CPU-frequency, cache, memory-bandwidth, and thermal contention can still affect
the result. Each workload runs one untallied warm-up operation, then doubles a
bounded batch up to 16,384 iterations until one whole-batch measurement reaches
20 ms. Each measured sample uses one CPU-clock pair around the complete batch,
so timer overhead is amortized. Reported medians remain per-operation values,
and the 0.25 ms batch timing allowance is divided by the selected batch size;
failure to reach 20 ms within the bound is an error.
Timing and peak-RSS
guardrail failures use a distinct exit status; the release runner retries only
that workload once in a fresh process and requires either run to pass. Other
benchmark failures are not retried. File re-encoding is reported as a full
decode/re-encode transcode: every decoded animation frame is re-encoded into a
counting destination inside the same timed operation. This avoids an
output-sized scratch allocation while preserving decoder and encoder work and
byte accounting. Paths
supplied by the caller make it usable with a real-world corpus.
`--synthetic-truecolor` encodes a raw 512×512 RGB pattern
with more than 256 colors, so the median-cut path is measured without first
passing through GIF's 256-color ceiling. `--synthetic-fixed`,
`--synthetic-fixed-repeated`, `--synthetic-fixed-phased`, and
`--synthetic-dither` cover high-cardinality fixed-palette mapping,
cache-friendly repeated colors, a high-cardinality-to-repeated phase change,
and Floyd–Steinberg work;
`--synthetic-alpha-exact`, `--synthetic-alpha-fixed`, and
`--synthetic-alpha-dither` cover exact mixed-alpha, fixed-palette opaque-alpha,
and dithered mixed-alpha RGBA inputs;
`--synthetic-lzw` isolates indexed 512×512 LZW encoding without quantization;
`--indexed-lzw-decode` isolates indexed decoding of an independently generated
512×512 ImageMagick GIF;
`--synthetic-animation` measures eight-frame workspace reuse; and
`--synthetic-optimizer` measures analysis plus transparent-interior extraction
in dynamically sized timed batches and reports the per-operation median.
The release matrix also generates an independent 256×256 eight-frame
ImageMagick animation whose composited decode exercises background and
restore-previous disposal.
With no workload arguments the harness finds the repository from its executable,
independently of the caller's working directory, and runs every synthetic
workload in addition to its deterministic generated samples.
The release gate rebuilds with the release profile, runs every case in a
separate process, and passes `--enforce` to apply conservative throughput and
16 MiB peak-RSS guardrails.

Historical wall-clock baseline captured 2026-10-24 on the x86-64 Linux
container with GNAT 15 and the release profile:

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

Performance-review CPU-time measurements captured 2026-11-15 on the same class
of x86-64 Linux container with GNAT 15 and the release profile:

| Input | Geometry | Frames | Decode CPU (s) | Transcode/operation CPU (s) |
|---|---:|---:|---:|---:|
| DocBook XSL `tip.gif` | 25×24 | 1 | 0.000012667 | 0.000022122 |
| DocBook XSL `warning.gif` | 24×24 | 1 | 0.000012717 | 0.000021993 |
| ImageMagick indexed GIF | 5×3 | 1 | 0.000003758 | 0.000006468 |
| ImageMagick animation | 3×1 | 3 | 0.000008230 | 0.000014027 |
| ImageMagick disposal animation | 256×256 | 8 | 0.006190549 | 0.016789390 |
| ImageMagick interlaced GIF | 9×9 | 1 | 0.000004920 | 0.000008655 |
| ImageMagick benchmark GIF | 512×512 | 1 | 0.002571525 | 0.007076847 |
| Raw RGB median-cut input | 512×512 | 1 | — | 0.03115 |
| Raw RGB fixed-palette input | 512×512 | 1 | — | 0.03983 |
| Raw RGB repeated-color fixed-palette input | 512×512 | 1 | — | 0.00738 |
| Raw RGB phase-changing fixed-palette input | 512×512 | 1 | — | 0.00813 |
| Raw RGB dithered input | 512×512 | 1 | — | 0.04334 |
| Raw RGBA 255-color exact mixed-alpha input | 512×512 | 1 | — | 0.00409 |
| Raw RGBA fixed opaque-alpha input | 512×512 | 1 | — | 0.03945 |
| Raw RGBA dithered mixed-alpha input | 512×512 | 1 | — | 0.03992 |
| Indexed LZW encode input | 512×512 | 1 | — | 0.00388 |
| Independent indexed LZW decode input | 512×512 | 1 | 0.00180 | — |
| Fixed-palette animation | 256×256 | 8 | — | 0.08266 |
| Indexed optimizer | 512×512 | 1 | — | 0.00060 |

Peak RSS remained below the enforced 16 MiB ceiling for every case. Exact-palette discovery now
defers histogram allocation and updates; if discovery overflows, its bounded
per-color counts seed the histogram and collection resumes at the overflow
pixel without rereading the accepted prefix. Nearest-palette search uses a
balanced exact color index, direct squared-distance arithmetic, a compact
non-diagnostic inner result, generation-invalidated caching, and row-batched
work commits. Search subtrees select their widest color axis and retain exact
RGB bounds; a far branch is visited only when both its split plane and subtree
bounds can still equal or improve the current result. Cache probes charge their
actual bounded length. Rolling 4,096-pixel observation windows disable the
cache below a one-quarter hit rate, reconsider it after a bounded cooldown with
a 256-pixel sample, and use a one-eighth recovery threshold. Nearest-tree visits
accumulate in a bounded local counter before updating the row total. Median-cut
charges exact bucket-scan
totals rather than updating the shared meter for every bucket. LZW decoding
batches byte/code/traversal/output work, validates literal/root bytes before
dictionary insertion, fetches each dynamic prefix/suffix pair through one
validated entry access, and emits with one reverse traversal. LZW
sequential output writes contiguously, while interlaced output advances a
persistent cursor without per-byte division. LZW encoding uses a fixed-size
dictionary, one sub-block staging buffer, and compact statuses, and combines
each sub-block length and payload in one destination write. Measured LZW leaf
helpers are forced inline in release builds. Successful internal codec steps
use a canonical no-error value and construct structured
diagnostics only on failure.

After these changes, the whole-batch release matrix measured 0.03115 s for
median-cut, 0.03983 s for high-cardinality fixed mapping, 0.04334 s for
dithering, 0.08266 s for the eight-frame fixed-palette animation, 0.00388 s for
isolated LZW encoding, 0.00180 s for independent LZW decoding, and 0.00060 s
per optimizer operation. Peak RSS was at most 6,148 KiB. Relative to the immediately
preceding profiles, fixed-mapping cycle
count fell about 11%, isolated LZW encoding about 34%, and isolated LZW decoding
about 47%; the high-cardinality cache-probe share fell from 7.47% to 0.70%.

Workload-specific floors range from 3,300,000 pixels/s to 420,000,000 charged
optimizer pixels/s. A 3 microsecond per-operation allowance models fixed codec
setup, file workloads charge at least 128 pixel-equivalents per frame, and the
0.25 ms batch timing allowance is amortized across every selected batch.
The reference medians are numeric constants in the benchmark workloads. The
configured ceiling is the larger of the throughput ceiling and 150% of the
reference. Before checking observed time, the harness rejects that ceiling if
it exceeds twice its corresponding reference; peak RSS has a separate 16 MiB
ceiling.
