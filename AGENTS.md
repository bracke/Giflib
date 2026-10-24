# Agent instructions — giflib

Native Ada 2022 GIF87a/GIF89a decoder and encoder. `docs/SPECIFICATION.md` is the authoritative implementation contract; `docs/IMPLEMENTATION_PLAN.md` is the dependency-ordered execution plan. Follow the earliest incomplete task and its acceptance gate.

Use https://github.com/bracke/jpeglib as an architectural reference for source/destination interfaces, structured errors and results, resource budgets, package organization, tests and Alire conventions. Do not introduce a production dependency on jpeglib or any external C GIF codec. Do not copy JPEG-only abstractions.

Pin GNAT 15 through Alire. Run `alr build` and `alr --chdir tests build`; once the test runner exists, execute it under `alr exec -- ...`. Never accept a test passing only because `giflib` encodes and decodes its own incorrect output: use independent GIF fixtures and test-only external oracles.

Every feature requires bounded memory/work handling, non-raising diagnostic behavior, malformed-input tests and state machine consistency. Resolve contract mismatches by revising the specification first.
