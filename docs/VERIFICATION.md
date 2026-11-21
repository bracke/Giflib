# SPARK verification boundary

The following production units are in SPARK mode:

- `Giflib.Internal.Block_Arithmetic`: exact bounded sub-block read and write
  transfer-state transitions used by the production block reader and writer.
- `Giflib.Internal.Budget_Arithmetic`: bounded resource charging with
  overflow-safe attempted totals, used by allocation accounting and the shared
  work-meter abstraction.
- `Giflib.Internal.Work_Budgets`: sticky stateful work meters built on the
  bounded charging primitive and shared by LZW, quantization, and optimization.
- `Giflib.Internal.Descriptor_Arithmetic`: logical-screen and image-descriptor
  packed flags, palette lengths, and color resolution used by the production
  parser and encoder.
- `Giflib.Internal.Encoding_Arithmetic`: palette table rounding, GIF packed
  size codes, and minimum LZW code sizes used by the production encoder.
- `Giflib.Internal.Extension_Arithmetic`: little-endian 16-bit extension
  fields, graphic-control packing and unpacking, and reserved-bit
  classification used by the production decoder and encoder.
- `Giflib.Internal.Geometry_Arithmetic`: pixel areas, rectangle edges, and
  canvas containment used by parsing, decoding, encoding, quantization, and
  optimization.
- `Giflib.Internal.Image_Arithmetic`: row-byte and strided-buffer extent
  calculation used by `Giflib.Images.Required_Bytes`.
- `Giflib.Internal.LZW_Arithmetic`: code-table initialization, decoder and
  encoder width transitions, encoder hash start/next-slot arithmetic, and
  dictionary stack/traversal/insertion guards used by both production LZW
  paths.
- `Giflib.Internal.LZW_Bit_Arithmetic`: exact LSB-first bit-buffer packing,
  extraction, byte removal, and first-byte recovery used by both production
  LZW paths.
- `Giflib.Internal.Metadata_Arithmetic`: retention decisions, block mapping,
  payload capacity, and count increments
  used by the production decoder.
- `Giflib.Internal.Optimization_Arithmetic`: conservative control safety,
  changed-pixel bounds, rectangle dimensions, and bounded delay merging used
  by the production frame optimizer.
- `Giflib.Palettes`: bounded palette containment and active-entry comparison.
- `Giflib.Internal.Pixel_Arithmetic`: row-major pixel indices and component
  byte offsets used by compositing, snapshots, expanded decoding, and frame
  extraction.
- `Giflib.Internal.Rendering_Arithmetic`: shared RGBA canvas, rectangle, and
  auxiliary-buffer extent validation used by compositing and disposal.
- `Giflib.Internal.Quantization_Arithmetic`: histogram indexing and
  decomposition, channel clamping/differences, and bounded squared color
  distances used by the production quantizer.
- `Giflib.Internal.Quantization_Buffer_Arithmetic`: dither-buffer allocation,
  row/channel spans, and two-row error-buffer indices used by the production
  quantizer.
- `Giflib.Decoding.State_Arithmetic`: private lifecycle and count transitions
  used by the atomic decoder session commit gateway.
- `Giflib.Encoding.State_Arithmetic`: private encoder lifecycle guards.
- `Giflib.Internal.Session_Arithmetic`: shared extension-count and warning
  capacity arithmetic without codec dependencies.
- `Giflib.Internal.Interlacing`: GIF pass counting and row mapping.
- `Giflib.Internal.Ownership_Arithmetic`: deterministic allocation-failure
  state transitions stored per object and armed only by test child packages.
- `Giflib.Internal.Stream_Arithmetic`: transfer caps and windows plus bounded
  read, skip, and write progress used by the production stream adapters.

The release gate runs flow analysis and level-2 proof with cvc5 over the whole
SPARK subset:

```sh
alr exec -- gnatprove -P giflib.gpr \
  --level=2 --prover=cvc5 --report=all -j1
```

`Giflib.Internal.Ownership`, `Owned_Arrays`, `Owned_Buffers`, `Owned_Vectors`,
and `Owned_Objects` are runtime-checked Ada. `Giflib.Testing.Checked_Arithmetic`
and the callback-driven `Giflib.Internal.Testing.Owned_Element_Vectors` helper are test
support compiled by the unit-test project against the white-box library; the
former remains in SPARK mode but is not part of the production release proof
command above. The ownership packages
provide scoped reservation
rollback, ledger-identity-checked ownership, and callback-scoped storage
access, but are outside the SPARK
subset because they manage controlled types and heap allocation.
The LZW decoder/encoder dictionaries, readers, output/input adapters, writer,
and orchestration are also runtime-checked Ada. Decoder state is isolated in
the decoding machine and code classification/dictionary transitions live in
its code-processing child, while the public internal package remains an
ownership-aware facade. Their work meters and bounded
arithmetic are proved, while generation/occupancy state, the dictionary probe
loop, transport callbacks, and writer lifecycle are enforced by contracts and
adversarial tests rather than by SPARK proof. Decoder byte/code/traversal/output
work is accumulated in bounded 4,096-operation batches and checked against the
remaining meter before a code or decoded sequence is accepted. Code reading,
code processing, encoder dictionary lookup, byte staging, and encoder
sub-block transport use fixed-size successful statuses. Decoder sequence bytes
are validated while its dictionary stack is built and emitted in one reverse
pass. Sequential output writes directly to its contiguous target; interlaced
output advances a persistent row/column cursor and resolves the pass row only
at row boundaries. The bit writer feeds the sole 255-byte sub-block buffer
directly, and each sub-block length and payload share one destination write.
Measured arithmetic, bit-buffer, work, dictionary, and input leaf helpers are
forced inline in optimized builds while retaining their contracts.
Public callback successes use the canonical no-error value, and structured
diagnostics are built only on failure.
The Ada `Giflib_Tooling` validator also enforces the architectural write
boundary around decoder and encoder session-transition fields; this is a
token-based structural source check, not a SPARK proof. It derives every field
from the actual session records, classifies non-transition resource fields, and
uses file-scoped callee identities for reviewed calls. The same gate rejects
upward dependencies from
`Giflib.Internal` into public codec facades, unreviewed ownership-container
instances, misplaced test subunits, and oversized test-case parent bodies.
Its non-normative implementation design and change policy are documented in
[TOOLING_ARCHITECTURE.md](TOOLING_ARCHITECTURE.md), keeping validator refactors
out of the codec contract.
Decoder, encoder, and quantizer resource representations are consolidated in
their respective `Internal.*_Storage` packages. The tooling check requires
those semantic-closure units in `Library_Interface` and rejects direct owned-
container dependencies from the three public subsystem specifications. Decoder
rendering delegates canvas/background semantics to `Decoding.Canvas_Policy` and
disposal/snapshot semantics to `Decoding.Disposal_Policy`, while
`Decoding.Resource_Management` only checks and supplies storage capacity.
Allocation outcomes are translated by the shared resource
diagnostic adapter. Header and image-descriptor parsing are separate container
subunits. Ordinary and exact extension writes share one discriminated typed
chunk-plan value across separate validation and emission children behind the
common transaction facade.
Image-data decode policy delegates minimum-code-size parsing, sub-block setup,
consumer execution, and mandatory compressed-byte accounting to the generic
transaction in `Internal.Image_Data.Transport`.
Sub-block reader and writer state machines are separate services behind their
facade; decoder extension transport and retention are separate children; frame
transaction orchestration separates request preparation and wire/lifecycle
commit from indexed/stored source strategies; fixed and generated quantization
palette strategies have separate implementations. Generated-palette discovery
uses a bounded exact-color hash rather than repeatedly scanning the partial
palette and writes exact-palette indices directly into the caller buffer, so
that path does not reread and remap the source. Exact discovery retains bounded
counts but defers histogram allocation and updates; on overflow those counts
seed the histogram and collection resumes at the first unaccepted pixel.
Pixel mapping builds an exact
balanced color-search index once per palette and retains deterministic
lowest-index tie behavior; a differential test compares it with exhaustive
search across all 256 entries. Index construction lexicographically merge-sorts
the candidate palette entries once, collapses adjacent duplicate RGB entries to
their lowest non-excluded index, and reuses that ordering as the red-axis list.
It then merge-sorts only the green- and blue-axis lists and recursively
partitions them in bounded `O(n log n)` work without clearing capacity-sized
scratch arrays at each recursive node. A white-box test asserts that a fully
duplicate 256-entry palette produces one search node and consumes less than
5,000 units of construction work. After public image validation,
quantization walks validated rows without repeating invariant and offset checks
for every pixel. Fixed-palette transparency discovery scans only the alpha
component and charges a row at a time. Fixed row work and variable
nearest-search work are charged in batches; each tree walk accumulates its at
most 256 visited nodes in a narrow local counter before the row total is
updated. Dithering computes direct
validated buffer bases once per pixel rather than repeating checked index
construction. Nearest search returns a compact status, accumulates work for a
row-level commit, and calculates squared distances directly in the traversal.
Each search subtree selects its widest color axis and stores exact RGB bounds;
far branches must pass both split-plane and subtree-bound tests, preserving
exact lowest-index tie behavior. Cache probes report their exact bounded probe
length. Mapping-local rolling 4,096-sample windows disable caching below a
one-quarter hit rate and reconsider it after a bounded cooldown using a short
256-pixel recovery sample; recovery retains the cache at a one-eighth hit rate.
Median-cut charges each exact
bucket-scan total once rather than mutating the shared work meter per bucket.
Histogram, nearest-cache, and dither storage are each borrowed
once per frame mapping operation rather than once per pixel; missing storage
still returns structured invariant status. Quantizer
workspace reuse clears only occupied histogram bins and invalidates the
nearest-color cache by generation, with a bounded full clear only when the
generation wraps. The compositor retains a checked entry path for direct
internal callers, selects validated-index and transparency-specialized renderers
once per frame, and uses validated row cursors when rendering decoder output,
whose palette indices were already bounded by LZW decoding;
decoder frame lifecycle and payload execution are separate services; and
optimization separates analysis from extraction over compile-time-specialized
rectangle walkers with row-batched charging.

The test crate declares only `unit_tests.gpr` and `giflib_tests` as its default
Alire project and executable inventory. The root test action regenerates its
development configuration, builds the AUnit runner and repository tools, runs
the fast current-tree structure probe, and runs AUnit. The explicit
`giflib_check tooling` gate first launches the
independent `giflib_tooling_tests` suite against mutated repository copies
through the full validation probe;
source-level transition and ownership mutations are compiled before rejection,
including qualified subtype aliases, access-to-session objects, indexed access
aliases, inherited subtype aliases, address extraction, mutable component
iterators, package-level overloads, reviewed helper profile changes, and unused
reviewed aliases; repository mutations are partitioned by ownership, layout,
suite, executable inventory, and configuration policy and cover misplaced
subunits, unchecked mains, and oversized tooling bodies; API-boundary mutations exercise the compiler-backed negative
probes.  The test action then executes `tests/bin/giflib_tests` by its exact
path. Root and test manifests carry inert
configuration-epoch scenarios so a layout change invalidates legacy ignored
setup hashes before a generated `config/` tree is required.
Generated Alire settings, configuration sources, and test logs are ignored and
are not versioned repository inputs.
`giflib_whitebox.gpr` compiles the workspace sources for internal tests without
weakening the production library's supported `Library_Interface` boundary;
only `unit_tests.gpr` imports that project. Repository tools import the
production `giflib.gpr` and expose only `tests/src/mains` plus the dedicated
`tests/src/tooling_subunits` directory; their build cannot resolve the white-box
children under `tests/src`. Tool and
unit-test builds therefore never share library artifacts or source visibility,
and the tools continuously exercise the supported interface.
The white-box suite is a `Giflib.Testing` descendant hierarchy, which is allowed
to test the private `Giflib.Internal` child without making it public. A separate
consumer built through `public_api.gpr` compiles against the production project,
and the Ada tooling validator requires a direct client import of
`Giflib.Internal` to fail. It also compiles a controlled-element ownership
probe that must be rejected. Both Alire crates pin GNAT 15, and all project
variants import compiler switches from `giflib_build.gpr`.
Separate actions ensure that a compilation or test failure makes `alr test`
fail, and selecting an exact executable prevents stale binaries for other
profiles from making execution ambiguous. Repository workflow tools are
isolated in `tools.gpr`; the explicit tooling gate and release gate locate the
invoking executable through `PATH`, then execute their profile-local mutation
suite and validation probe so no development-process checker can validate a
release-profile binary set. The versioned CI workflow runs the same development
tooling gate, deterministic 10,000-case fuzz harness, and independent
ImageMagick/FFmpeg oracle checks on pushes and pull requests. A limited focused
source repository inventories Ada
source paths once, diagnoses duplicate basenames, and captures bounded,
budget-accounted immutable source-text snapshots. Snapshot reservations include
the transient read, retained text, path/name copies, indexes, directory keys,
and ancestry memberships before allocation. Snapshot capture lives in a
dedicated builder subunit, storage measurement and index mutation live in its
storage child, and the parent body owns bounded queries. Borrowed snapshot text removes a second cache-build copy, and indexed
directory walks inspect only relevant entries. Parsing, discovery, snapshot,
and cache policies are separate records
carried by one repository configuration, while parsing APIs receive only the
parsing record. One analysis context owns a snapshot and the cache that eagerly
parses every Ada source from it, charges portable logical storage on each model
allocation path and
reserves equal room for the retained model copy. Allocation and measurement
share one model-schema implementation, and limit regressions sweep every
intermediate cutoff. A controlled analysis-data owner contains the snapshot and
cache allocation lifecycle. Cache construction and subsequent validators share the
context-owned aggregate work ledger; a scoped callback lends the snapshot, cache,
and both ledgers without exposing retainable pointers. Transition indexes bind
that four-resource bundle once rather than accepting per-operation replacements.
Retained source, clause,
and inherited-context indexes share a context-owned storage ledger, while cache
construction also has its own child cap. Cutoff tests exercise the aggregate and
child behavior through the command pipeline, verify one ledger identity reaches
every production phase, compare transition storage charges with their shared
measurement schema, exercise automatic provisional reservation rollback,
transfer, and commit, reject retained releases against provisional charges, and
verify exact retained-storage release from the measurement kept with each cache
entry. Context-cache and source-cache regressions are isolated in separate test
packages. Validation-plan regressions reject duplicate project/source-directory
pairs and inspect complete before/after work intervals for every runner phase
plus the aggregate total; the phase enumeration drives one executor that owns
all start/finish accounting. Repository traversal holds counters and policy in
one state object and isolates recursive directory visitation in a subunit.
Transition-family configuration is visited from one
typed declarative inventory whose named fields include its identity, target,
specification, and exemptions.
Snapshot configuration is exposed only as policy slices, snapshot/cache lookup
uses one canonical path service, and Ada validators consume the parsed cache.
The shared meters charge
lexing, structural analysis, model inspection, deep copying, path allocation,
hashing, and indexing to one aggregate work meter while preserving per-source
structural ceilings. A separate context resolver owns specification/body
ancestry, and all later inspection observes the cached parse rather than the
live filesystem.
Structural
header extraction, event recognition, and
program-unit derivation share one structural event stream with
lexical-scope analysis using a sparse event inventory. Structural nesting has
an independent configurable depth limit in addition to token, event, and work
limits. The resolver iteratively assembles inherited package contexts in one
operation-local vector while bounding and cycle-checking the combined
specification/body ancestry. Relationship errors are diagnosed before an
ancestry step consumes the depth budget. Discovery and application cache
bounded clause metadata and up to 64 budget-accounted inherited contexts, so
targets with a common ancestor reuse the deepest cached context. Cache-copy
charges include classification records, nested names, profiles, and formal
types; focused regressions cover deepest selection, eviction, pre-insertion
exhaustion, immutable source snapshots, and end-to-end inherited semantics.
The production cache carries no test-observation state. Key construction and
hashing have a pre-allocation exhaustion regression. Source bytes are charged
before allocation and again before parsing or persistent caching.
It keeps configuration parsing and reviewed
transition policy behind focused package APIs. Reviewed alias/declaration data
and global/local call-allowance data are separate catalogue units behind a
small facade and remain separate from the query engine, which builds typed hashed registries once at
elaboration without raising on duplicate data and reports duplicates through an
explicit validation gate. Alias keys use unit and alias identity while the
reviewed target remains map data, so conflicting targets are duplicates;
family lookup observes Ada unit-name boundaries
instead of accepting arbitrary string prefixes.  Session-scope analysis, record
schema extraction, and call-expression resolution likewise have separate
package boundaries instead of accumulating in the source lexer/model.  Session
semantic types, declaration extraction, expression typing, and scope state are
separate packages; callable-profile construction and package-alias handling are
also isolated from declaration extraction.  Type, callable, record-component,
and object declaration parsers are separate and share one type-indication
service that performs each visibility lookup once.  A structural-event reducer owns
scope transitions, while a lexical-event reducer owns token-pattern declarations
and statement completion separately from token traversal and delivery.
Context classifications are added through kind-specific upserts that remove
stale inherited cross-kind homonyms, while state child packages own
package-alias policy and overload selection through
representation-independent state queries rather than direct container access.
Scope mutation, binding mutation, and visibility queries are distinct state
children instead of duplicated nested-package declarations and forwarding
facades. All tooling implementation children are private; only the self-test
entry point is visible to the standalone tooling-test executable.
Session depth represents presence and nesting separately,
without a numeric absence sentinel.
Nested package scopes are preserved through explicit context-level predicates;
selected and class-wide formal type names retain their full identity, exact
overload matches outrank unknown types, selected type indications are looked up
atomically with qualified context identities after bounded package-alias
resolution, and implicit short package aliases use a
typed ambiguous state when more than one visible full scope has the same suffix.
Record manifests and component classification share one
declaration inventory. Qualified context entries preserve qualified parent
relations and duplicate component ownership under the selected owner identity.
The transition-family coordinator supplies the canonical session identity to
the otherwise generic semantic analyzer. The family-agnostic source index
retains source identities rather than copied inherited-context vectors; relation walks and
package-alias resolution have explicit work bounds and cyclic qualifier aliases
fail without returning a partially resolved name.  Package-renaming analysis
reports typed absent, applied, and malformed outcomes and rejects leading,
trailing, or repeated dots and reserved-word components in selected targets.
The lexer distinguishes Ada reserved words and numeric literals from
identifiers; token representation is private, kind-specific factories validate
identifiers, reserved words, numerics, decoded strings, characters, and
symbols, including reserved defining names and malformed underscore and exponent placement;
the indefinite token type has no public default value and every token position
is positive and relative to the supplied string bounds. Cursor queries retain
that relative coordinate system and scan complete lexical tokens, including
when the cursor lies inside a literal; a cursor snapshot regression also proves
that declaration handlers cannot inspect a type token beyond the requested
position or fail because of malformed text after it. Unterminated strings and
unsupported symbol spellings are rejected.
Context clauses before `separate` are covered; recognition is anchored at the
first library-unit introducer, absent, valid, and malformed clauses are
distinct, complete body introducers are required, and malformed clauses use the typed tooling-input
diagnostic path. Source, token,
structural-event, program-unit, and structural-work caps are exercised at their
boundaries, including selected package names; all repository walks apply entry,
source-file, directory-depth, symbolic-link, canonical-root, and bounded-read
guards while streaming deterministic directory order, and all project,
configuration, source-policy, and transition text parsed by giflib-owned tooling
uses the same bounded reader. Separate-subunit validation and structural scope
analysis share one body-introducer package and the caller-owned structural work
meter. Source unit/file-name conversion is owned by one shared service.
Deterministic replacement hooks cover entry changes, in-place content changes,
and the intervals after descriptor acquisition and after the first read;
repository regressions assert the exact stable reason and rendered diagnostic
through independent reason and message expectations. Read, pinned-descriptor/
snapshot, and traversal races run in focused suites over one cleanup-safe
fixture service.
Descriptor-bound
enumeration covers directory replacement and fails closed when descriptor
identity is unavailable. Configuration regressions cover multiline arrays,
escaped multiline decoys, physical multiline-string array elements, and
whitespace-equivalent TOML.
Repository mutations prove that an `Add_Test` call on a non-returned suite does
not satisfy registration, duplicate additions are rejected, and listed main
files must declare their named library-level procedure; those mutations compile
before probing. Focused suite-analysis regressions cover nested same-name
`All_Tests` decoys, nested executable blocks, conflicting return suites, and
inactive `Register_Routine` identifiers. Token grammar and allocation discovery
are isolated from registration inventory assembly.
Normalized literal values use accessors, and token
images preserve string-literal delimiters so literal
contents cannot be interpreted as syntax.  Type, component, callable, and
package classifications are stored directly by live bindings through the same
discriminated model, while object bindings use the shared relation record;
callers access only active fields and add
bindings through kind-specific operations rather than a shared optional-field
interface.  Name visibility is selected across declaration kinds before
classification, and implicit package aliases are resolved within their lexical
scope. Name and owner-component indexes use linked prior bindings, restore their
map heads incrementally on scope removal, and never copy candidate buckets;
shadowing regressions exercise mixed binding kinds and restoration after pop.
Callable candidates are visited directly without a temporary profile vector,
and inherited contexts are assembled without retaining one complete copy per
ancestor or reparsing a shared ancestry prefix. Transition inspection shares a
bounded meter across every statement in one unit. Test-layout mutations cover
both body and specification placement in the dedicated subunit directories.
One target-identity value supplies normalized simple and qualified names to
transition indexing and semantic scans, and declaration qualification is tested
through that shared service. Empty, reserved, malformed, and terminally
inconsistent target identities have direct rejection regressions.
Callable
classifications retain lexical scope plus precomputed arity and formal-type
metadata rather than re-lexing profiles during lookup.  Shared token
navigation owns outer-group and semicolon-boundary queries, while the token/event
scanner remains internal to session analysis; expression grammar, argument
typing, branch parsing, selection traversal, and overload lookup are separate
operations rather than one nested resolver, and one shared work/depth budget
covers the complete source scan, including declaration, expression, argument,
qualifier, state-query, iterable relation, navigation, context-index,
declaration, and transition-inspection work;
forced exhaustion verifies that each path charges before traversal.
Finalizable depth guards balance recursive entry on normal and exceptional
exits, with inspection and forced exhaustion confined to a test child package.
State resolution owns candidate charging rather than exposing indexed-container
complexity to its callers. Scope, binding, and visibility operations are separate state
implementation units; empty-state scope-top queries are total, relation queries
accept only supported binding kinds, and discriminated call-argument results
expose closing positions and types only when valid, so malformed calls cannot
reach overload selection. Incomplete conditional branches fail without an invalid recursive
slice, while universal literals remain conservative matches for user-defined
formal types.  Structural events carry independent body identity and
scope-introduction flags; every event kind exposes only its applicable payload,
uses positive token positions, and all consumers share a discriminated
subprogram header whose optional return and declaration positions come from one
header scan. Null procedures and boxed generic formal subprograms are explicitly
non-scoping, so
semantic reduction does not reconstruct those facts.  Package
renaming is classified while its alias is applied, avoiding a second token scan.
Direct state regressions are isolated from iterable integration scenarios.
Architecture failures propagate once through the shared diagnostic boundary
instead of being caught and rewrapped. Expected source and context-ancestry
failures use a typed input exception at that boundary, while repository
failures retain a separately inspectable typed reason through exception
identity, and `Program_Error` remains reserved for invariant failures. Token
construction enforces identifier and numeric normalization. Lexical tokens,
structural source data, and analysis limits have focused views isolated from
the parsed-source facade; type-only consumers depend only on the applicable
view, while the facade owns parsing and inspection without re-exporting them.
Expression selection traversal and iterable-test helpers live in
focused units; iterable integration scenarios are split into basic,
inheritance, qualification, and visibility suites.  Benchmark
reporting/destination support lives in a focused unit, while source rendering
and parsed-source queries are implemented outside the compatibility facade,
leaving headroom
under the repository layout guard applied to test parents, test mains, and
tooling/benchmark mains. Ordinary test bodies are accepted only in the exact
approved roots; nested directories cannot bypass the guard. The
source and transition-context regressions delegate lexical, structural,
successful-inheritance, and ancestry-failure scenarios to focused suites with
shared fixture/scan/failure harnesses. Repository diagnostic, race, and limit
scenarios likewise live in separate suites behind a facade-only aggregator and
share typed diagnostic-expectation support. The
test and tooling subunit directories accept only separate bodies; tooling
subunits are additionally bounded. Mutation coverage rejects ordinary package
bodies in both subunit directories and ordinary bodies hidden below nested test
directories. Newline-terminated files are measured by logical line count.
Mutation cases share one typed
case descriptor and one source-edit helper.  One exhaustive registry generates
the ordered case inventory and owns every case's identity and metadata; one
exhaustive dispatcher maps identities directly to concrete handlers without
category metadata, enumeration ranges, or fallback dispatch. Mutation handlers
remain partitioned into session semantics, reviewed policy, ownership, layout,
suite, executable-inventory, and configuration suites.
The architecture validator delegates interface, dependency direction,
ownership, and layout policy to separate focused validators. Those validators
share one bounded Ada-source traversal service instead of repeating repository
walking and suffix policy. Its interface
validator uses one typed
library-interface manifest whose entries also select their public dependency
policy; inventory membership is order-independent and no second public-unit
dispatch list is maintained. Repository validation delegates project-main
inventory and AUnit registration inventory to separate services. Suite analysis
similarly delegates source-body selection, suite registration extraction, and
test-routine reachability to focused services; registration extraction further
separates token syntax, allocation discovery, and call traversal. Secure
repository opening and descriptor-stability reads are separate services behind
the repository facade. File-transcode, generated/fixed/dithered RGB and RGBA
quantization,
independently generated large composited animation, multi-frame reuse, and
optimizer benchmarks are separate workloads sharing only
buffer, process-CPU timing, result, and guardrail support. RGBA workloads cover
exact mixed-alpha, fixed-palette opaque-alpha, and dithered mixed-alpha paths;
each workload runs an untallied warm-up and then selects, up to a 16,384-iteration
bound, the first doubled batch measured at 20 ms or longer. Each sample uses one
process-CPU clock pair around the whole batch and is reported per operation; the
fixed batch timing allowance is divided by that count. File workloads time a
complete decode/re-encode transcode rather than subtracting decode time. The
release harness resolves built-in fixtures from the executable's repository
root, applies recalibrated workload-specific timing floors, verifies their
ceilings include at least 50% baseline headroom while remaining no more than
twice machine-readable reference medians, keeps the complete documented
file-workload matrix synchronized with those latest measured references, and
applies a 16 MiB
peak-RSS ceiling. Timing and peak-RSS guardrail failures have a distinct process
status; the release harness retries only that workload once in a fresh process,
while all functional benchmark failures fail immediately. Transition
indexing delegates
ancestry resolution and semantic-context construction to private children,
leaving the parent as the family-scan coordinator.
The stream tests inject exceptions from every callback family (`Read`, `Skip`,
`Write`, `Offset`, and `Flush`) and require structured, non-raising outcomes.
Extension behavior is exercised through the per-kind decoder handlers and both
shared encoder chunking paths.

GNATprove discharges the declared postconditions, termination, initialization,
range checks, division checks, and overflow checks in these units. In
particular, the budget helper proves that accepted charges fit both the limit
and `Byte_Count` while rejected diagnostic totals saturate safely; the
descriptor helper proves exact packed-field decoding and encoding across all
byte values; the encoding helper proves palette table sizes and their
corresponding packed and LZW codes; the extension helper proves exact
little-endian fields, graphic-control bit packing, and reserved-bit
classification; the geometry helper proves maximum GIF areas and rectangle
edges fit `Byte_Count` and gives an exact containment result; the image-extent
helper proves that accepted row/stride arithmetic fits `Byte_Count`; the LZW
helper proves code initialization, width changes, and hash slots remain within
their table bounds, and its stack and dictionary guards prevent invalid
traversal and insertion; the LZW bit helper proves exact bounded LSB-first bit
operations; the block helper proves exact sub-block transfer-state updates;
the metadata helper proves retention, capacity, and
payload count transitions; the session helper proves lifecycle, extension
capacity, and warning bounds; the rendering helper proves RGBA rectangle and
buffer extents; the ownership helper proves allocation-failure injection transitions are bounded
and self-disabling; the optimization helper proves its bounding-box
transitions and delay sums remain ordered and in range; the quantization helper
proves every histogram and color-distance result remains in range; the pixel
helper proves row-major and component offset calculations cannot overflow
`Byte_Count`; the quantization-buffer helper proves all dither allocation sizes
and two-row/channel indices fit their declared bounds; the interlace mapper
proves its result never exceeds the image height; and the stream helper proves
transfer windows and progress increments stay within both the request and the
backing buffer at maximum counter values.

Classwide stream dispatch, the mutable I/O loops around sub-block state,
bounded-string construction, actual pointer mutation and allocation/deallocation
for metadata, images, and sessions, protected synchronization, quantizer
heap-object lifecycle and median-cut loops, decoder/encoder object mutation,
and LZW dictionary array storage, generation state, probing, and traversal loops
remain outside the current SPARK subset. Their controlling transfer, index,
bit-buffer, lifecycle,
retention, allocation-accounting, and traversal-bound transitions are now in
proved helpers. The remaining safety boundary is explicit checks, fixed limits,
runtime assertions/overflow checks, adversarial tests, deterministic
allocation-failure injection, independent codec oracles, and the mutation
harness. The fuzz executable delegates fixture-corpus access, independently
bit-packed LZW stress-seed construction, mutation policy, and bounded decoder
exercise to separate test services. Its handcrafted dictionary-reset and
high-expansion seeds are decoded and checked before mutation. External checks
use a shared process runner
beneath separate ImageMagick and FFmpeg adapters, reusable byte assertions, and
fixture-specific expectations, leaving the main as orchestration only. These
regions are tested but are not represented as formally proved.
