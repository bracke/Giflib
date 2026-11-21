# Repository tooling architecture

This document records the non-normative design of the repository-owned Ada
validators. The codec contract remains `SPECIFICATION.md`; changes confined to
validator parsing, caching, traversal, diagnostics, or package decomposition do
not revise that contract unless they change a public codec requirement or a
release acceptance gate.

## Purpose

`Giflib_Tooling` enforces repository policies that the Ada compiler and SPARK do
not express directly. It checks public/private project boundaries, source and
main inventories, AUnit registration, package layering, ownership-container
placement, source-size policy, and exclusive mutation of decoder and encoder
session fields through their transition packages.

The validator is defense in depth, not an independent proof of codec behavior.
Compiler checks, SPARK proofs, AUnit tests, malformed-input tests, fuzzing, and
external codec oracles remain authoritative evidence for their respective
claims.

## Design boundaries

- Repository traversal is deterministic, descriptor-anchored, bounded by entry,
  depth, file-count, source-size, work, and retained-storage policies, and fails
  closed when canonical identity cannot be established.
- Source snapshots own each bounded source text once. Parsed models and indexes
  borrow snapshot text through scoped operations and account retained storage
  before allocation.
- Lexical and structural analysis recognizes Ada declarations, scopes, context
  clauses, separate subunits, profiles, selected names, and expression forms
  needed by the enforced policies. It is not a general-purpose Ada compiler.
- Transition analysis derives session fields from the production records,
  resolves aliases and callable identities within bounded lexical contexts, and
  rejects unreviewed writes or mutating state-arithmetic calls outside the
  transition gateways.
- Mutation tests exercise the validator through copied repository fixtures and
  compiler-backed positive and negative probes. Validator self-tests must not be
  used as evidence that encoded or decoded GIF data is correct.
- The default Alire test action runs the fast current-tree probe. GitHub Actions
  additionally runs deterministic fuzzing, independent ImageMagick/FFmpeg
  oracles, and the slower mutation suite. The release command runs the same
  tooling gate. Structure policy is therefore enforced without putting mutation
  latency on every local focused test run.
- Immutable development dependency identity is defined once in
  `Giflib_Tooling.Dependency_Policy` for validator and mutation consumers; the
  Alire manifest remains the external declaration checked against that policy.

## Change policy

Validator implementation changes update this document or `VERIFICATION.md` when
their evidence boundary changes. Private package splits, cache representations,
token representations, and reviewed-call catalogue organization do not update
the codec specification. A change updates `SPECIFICATION.md` first only when it
changes public behavior, GIF semantics, resource/error policy, or a normative
architecture boundary.
