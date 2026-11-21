# Release checklist

Historical release baseline verified on 2026-10-24 with Alire-selected
GNAT 15.2.1 and the then-current sibling `project_tools` development pin:

- `alr build`: success.
- `alr --chdir tests build`: focused AUnit project succeeds.
- `alr --chdir tests exec -- gprbuild -P tools.gpr -p -j0`: repository tooling
  project succeeds independently.
- development- and release-profile AUnit: 137/137 tests, zero failures or
  unexpected errors in each profile.
- development- and release-profile `giflib_fuzz 10000 3235823838`: success,
  final state `2752455965` in each profile.
- development- and release-profile independent corpus: six
  ImageMagick/DocBook GIFs decoded and re-encoded successfully in each profile.
- release-profile benchmark: separate-process five-sample medians cover every
  animation frame and raw 512×512 median-cut input; timing and peak-RSS
  guardrails are enforced.
- generated encoder artifacts: ImageMagick 6.9.12-98 and FFmpeg 6.1.1 pass.
- example project: builds and produces a 36-byte 2×2 GIF.
- `alr show --solve`: standalone root solution selects `gnat_native=15.2.1`.
- GNATprove level-2/cvc5 proof: all checks and postconditions pass for checked
  and budget arithmetic, descriptor packed fields, encoder palette/code
  sizing, image geometry and extents, GIF extension control/U16 fields, LZW
  code/width/hash, dictionary-guard, and bit-buffer arithmetic, sub-block
  state, metadata retention/count state, session lifecycle/allocation state,
  allocation-failure state transitions, optimizer decision/bounds arithmetic,
  palette helpers, pixel/component offsets, quantization color/index and
  error-buffer arithmetic, interlacing, and stream transfer/progress accounting.

Current working-tree checks rerun on 2026-11-15 after the structure, quality,
and performance reviews:

- root and test Alire builds: success;
- default `alr test`, including the fast structure probe: success;
- development- and release-profile AUnit: 137/137 tests in each profile;
- deterministic `giflib_fuzz 10000 3235823838`: final state `2752455965`;
- development- and release-profile ImageMagick and FFmpeg external-oracle
  checks: success;
- tooling mutation suite and current-tree structure validation: success;
- targeted release-profile enforced process-CPU benchmarks using one clock pair
  per whole batch: independently generated eight-frame 256×256 disposal
  animation decode 0.00643 s and full transcode 0.01739 s; 512×512 raw RGB
  median-cut encode 0.03115 s; high-cardinality fixed-palette encode 0.03983 s;
  cache-friendly repeated-color fixed-palette encode 0.00738 s; phase-changing
  fixed-palette encode 0.00813 s; dithered encode 0.04334 s; near-capacity
  255-color exact mixed-alpha RGBA encode 0.00409 s; fixed-palette opaque-alpha
  RGBA encode 0.03945 s; dithered mixed-alpha RGBA encode 0.03992 s; isolated
  indexed-LZW encode 0.00388 s; independent indexed-LZW decode 0.00180 s;
  eight-frame 256×256 fixed-palette animation encode 0.08266 s; and 512×512
  optimizer analysis/extraction 0.00060 s. Every timing ceiling is at most twice
  its machine-readable reference and the 16 MiB memory guard passed; peak RSS
  was at most 6,148 KiB;
- GNATprove level-2/cvc5 proof, including the new work-meter capacity query:
  all checks and postconditions pass;
- the immutable `project_tools` Git pin resolves to commit
  `5ed5f4dcfa10301345933d45e5f78ac0573d8cff`.

The monolithic `giflib_check release` orchestration completed successfully from
the test crate's pinned Alire environment, including both profile
test/fuzz/oracle runs, enforced release benchmarks, tooling mutations, full
proof, and the Alire solution check.

No release tag was created as part of implementation. Tagging should occur only
after rerunning `giflib_check release`.
