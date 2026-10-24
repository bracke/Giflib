# Release checklist

Baseline verified on 2026-10-24 with Alire-selected GNAT 15.2.1:

- `alr build`: success.
- `alr --chdir tests build`: success (the sandbox required an equivalent
  writable copy of the existing sibling `project_tools` pin).
- `alr test`: 68/68 AUnit tests, zero failures or unexpected errors.
- `giflib_fuzz 10000 3235823838`: success, final state `2752455965`.
- independent corpus: five ImageMagick/DocBook GIFs decoded and
  re-encoded successfully.
- generated encoder artifacts: ImageMagick 6.9.12-98 and FFmpeg 6.1.1 pass.
- example project: builds and produces a 36-byte 2×2 GIF.
- `alr show --solve`: standalone root solution selects `gnat_native=15.2.1`.
- GNATprove flow analysis: initialization and termination checks pass for the
  SPARK interlace mapper.

No release tag was created as part of implementation. Tagging should occur only
after rerunning `giflib_check release` and, where the host permits local Unix
sockets, the SMT proof command in `docs/VERIFICATION.md`.
