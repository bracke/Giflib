# SPARK verification boundary

`Giflib.Internal.Interlacing` is in SPARK mode with an explicit GIF-dimension
precondition and result-bound postcondition. GNATprove flow analysis proves
initialization and termination for both pass counting and row mapping:

```sh
alr exec -- gnatprove -P giflib.gpr \
  -u giflib-internal-interlacing.adb --mode=flow --report=all -j1
```

The full automated prover invocation is:

```sh
alr exec -- gnatprove -P giflib.gpr \
  -u giflib-internal-interlacing.adb --level=2 --prover=cvc5 --report=all -j1
```

In the restricted development sandbox, the proof process cannot open its local
Why3 Unix socket (`Operation not permitted`); flow analysis succeeds, while the
full proof command must run on an ordinary host/CI runner. Runtime contracts and
AUnit tests cover all four passes and tiny heights in this environment.

Stream interface dispatch, bounded-string diagnostics, dynamic metadata lists,
decoder/encoder session ownership, quantizer heap buffers, and LZW tables remain
outside the current SPARK subset. Their safety boundary is explicit checks,
fixed limits, runtime assertions/overflow checks, adversarial tests, and the
mutation harness. These regions are not represented as proved.
