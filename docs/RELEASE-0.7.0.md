# Consema 0.7.0 release record

This record binds the 0.7.0 specification changes, migration boundary,
security posture, evidence, and release checklist. It does not widen the
project's 1.0.0 scope or start the Go implementation.

## Contract changes

- RFC 0006 adds PortableGraph@1, PGCE/1, strict topology equality/hash, and
  `core.portable-graph-query@1` without changing PortableValue or PVCE/1.
- RFC 0007 adds `yaml.1.2-core@1` and `yaml.1.1-compat@1`, including native and
  lossless queries, graph/value projection, canonical materialization, and
  snapshot-bound edits.
- RFC 0008 adds five transferable graph/YAML contracts and 40 stable failure
  codes. `core.semantic-model@5` contains 30 contracts and 132 codes.
- Semantic-model v1-v4 manifests and constructors remain byte-for-byte frozen
  by language-neutral conformance vectors.

## Migration from 0.6.0

- Workspace dependencies should move from `0.6.0` to `0.7.0` as one unit.
- `RegistryManifest::current()`, `ContractRegistry::current()`, and
  `ErrorCodeRegistry::current()` now select semantic-model v5. A peer pinned to
  v4 must keep calling the explicit `v4()` constructors.
- Existing JSON/JSONC/JSON5/TOML/PVCE contracts retain their published
  semantics. New graph roles are intentionally rejected by frozen query-result
  v1 payloads.
- Use `consema::graph` for portable topology and `consema::yaml` for YAML native
  handles. Do not serialize raw YAML handles; externalize results through the
  v5 protocol adapters with caller-owned stable source IDs and locators.
- YAML defaults to exact graph projection. A caller that specifically needs a
  PortableValue tree must choose `ValueProjectionRequest` policies for sharing,
  tags, and mappings; no compatibility convenience silently expands aliases.

## Security notes

- Parsing, composition, projection, and materialization perform no network or
  filesystem I/O and execute no custom tag constructor, merge, include, or
  import.
- Aliases are graph references. Default tree projection rejects sharing and
  cycles; explicit acyclic duplication is guarded by visit, depth, report,
  provenance, and amplification limits.
- Parse, graph build, PGCE, query, projection, materialization, and edit limits
  fail without a partial Document, graph, value, or committed transaction.
- Protocol v5 revalidates graph topology, readable/PGCE agreement, association
  roles, provenance order/ranges, YAML domain/role compatibility, and result
  ordinals after transport.
- The adversarial gate covers truncation, per-byte mutation, invalid Unicode,
  deep nesting, alias amplification, cycles, custom tags, and canonical PGCE.

## Known limitations

- YAML materialization is canonical block/flow generation, not a general source
  formatter.
- YAML does not provide implicit merge execution, custom constructors,
  cross-document anchors, cross-container moves, or graph diff/merge.
- The official YAML suite gate proves syntax acceptance/rejection and byte-exact
  retention. Consema-specific graph, scalar, query, projection, materialization,
  edit, and protocol semantics are proven by its own vectors instead of an
  upstream loader model.
- INI, Properties, XML, plist, HCL, CLI filesystem transactions, stable plugin
  process protocol, and Go remain later roadmap milestones.

## Evidence manifest

- language-neutral suites: 11 suites, 255/255 cases;
- official YAML suite: 402/402 accounted, with 307 valid, 94 invalid, and one
  explicit `%YAML 1.3` Profile-contract exclusion;
- official TOML suite: 205 valid and 474 invalid cases passed;
- JSON5 reference gate: 83/83 items retained;
- real YAML fixtures: Kubernetes, GitHub Actions, Compose, anchor-heavy;
- workspace tests: 312 on Rust 1.97 and Rust 1.85;
- supply chain: Cargo.lock scanned against 1,189 RustSec advisories and all four
  cargo-deny categories passed;
- performance: `BENCHMARKS-0.7.0.md`, three release samples at 20,000 iterations.

## Release checklist

- [x] accepted RFCs and explicit non-goals
- [x] workspace and all local dependency versions set to 0.7.0
- [x] v1-v4 registry immutability and v5 manifests
- [x] language-neutral graph, YAML, and protocol vectors
- [x] pinned upstream provenance, complete case accounting, and license evidence
- [x] production-shaped fixtures without secrets or unclear licenses
- [x] mutation/resource/security gates
- [x] Rust current and MSRV tests plus strict Clippy
- [x] rustfmt, doctest, rustdoc `-D warnings`
- [x] RustSec and cargo-deny
- [x] fixed benchmark corpus and full sample report
- [x] changelog, implementation contract, migration guide, and known limitations
- [ ] signed/published artifacts and remote release publication (outside this
      local repository scope)
