# Release checklist

Baseline verified on 2026-10-24 with Alire-selected GNAT 15.2.1:

- `alr build`: success.
- `alr --chdir tests build`: focused AUnit project succeeds (the sandbox
  required an equivalent writable copy of the existing sibling `project_tools`
  pin).
- `alr --chdir tests exec -- gprbuild -P tools.gpr -p -j0`: repository tooling
  project succeeds independently.
- development- and release-profile AUnit: 107/107 tests, zero failures or
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

No release tag was created as part of implementation. Tagging should occur only
after rerunning `giflib_check release`.
