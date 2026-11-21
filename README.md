# giflib

Native Ada 2022 GIF87a/GIF89a codec release candidate. The current
library decodes bounded, forward-only GIF87a/GIF89a indexed images and animated
RGBA canvases with global/local palettes, GIF LZW, interlacing, transparency,
loop metadata, and disposal methods 0–3. It also exposes scalar
types, structured non-raising diagnostics, explicit resource limits, memory
stream adapters, an incremental decoder state machine, and bounded ordered
extension retention. Indexed still and animation encoding is available, including
GIF87a selection, GIF89a controls/looping, local palettes, interlacing, and exact
extension chunk preservation. True-color RGB/RGBA encoding provides exact and
median-cut palettes, fixed/global palette mapping, binary alpha, optional
Floyd–Steinberg dithering, and conservative animation rectangle optimization.

- [Specification](docs/SPECIFICATION.md)
- [Implementation plan](docs/IMPLEMENTATION_PLAN.md)
- [Public API notes](docs/PUBLIC_API.md)
- [Conformance matrix](docs/CONFORMANCE.md)
- [Security and fuzzing](docs/SECURITY.md)
- [SPARK boundary](docs/VERIFICATION.md)
- [Repository tooling architecture](docs/TOOLING_ARCHITECTURE.md)
- [Benchmarks](docs/BENCHMARKS.md)
- [Agent instructions](AGENTS.md)

The reference architecture is [bracke/jpeglib](https://github.com/bracke/jpeglib),
not a runtime dependency. No C GIF codec is used by the production crate.

## Build and test

The production crate builds from a standalone checkout. The test/tooling crate
uses the shared `project_tools` development crate through an immutable Git
commit pin, so no sibling checkout or mutable branch is required.

All commands use Alire so the declared GNAT 15 toolchain is selected:

```sh
alr build
alr --chdir tests build
alr --chdir tests exec -- ./bin/giflib_tests
alr --chdir tests exec -- gprbuild -P tools.gpr -p -j0
```

The default `alr test` path builds the focused AUnit and tooling projects, runs
the fast current-tree structural probe, and runs AUnit. The slower repository
mutation gate remains explicit and is also enforced by GitHub Actions. Focused
CI additionally runs the deterministic 10,000-case fuzz harness:

```sh
alr --chdir tests exec -- ./bin/giflib_fuzz 10000 3235823838
```

CI also generates fresh independent fixtures and checks encoder output with
ImageMagick and FFmpeg.

All repository-owned tooling is Ada and uses the shared `project_tools` crate
for process, filesystem, temporary-fixture, deterministic-seed, and release
checks. After building `tools.gpr`, `giflib_check` runs the suite,
deterministic mutations, independent fixtures, external decoder oracles, and
benchmarks. The `release` command repeats the correctness, fuzz, and external
oracle checks with separately built optimized release binaries before enforcing
the release benchmark limits:

```sh
alr --chdir tests exec -- ./bin/giflib_check all
alr --chdir tests exec -- ./bin/giflib_check tooling
alr --chdir tests exec -- ./bin/giflib_check release
```

The external checks invoke ImageMagick and FFmpeg as test-only decoder oracles;
neither is a production dependency. AUnit and tool failures return a nonzero
process exit status.

## Minimal indexed encode

`examples/encode_still.adb` demonstrates the full state sequence: open a
destination, initialize, define the screen, install a palette, add a caller-
owned indexed frame, and finish. Build and run it with:

```sh
alr exec -- gprbuild -P examples/examples.gpr -p
alr exec -- ./examples/bin/encode_still
```
