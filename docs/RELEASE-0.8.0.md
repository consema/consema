# Consema 0.8.0 release record

This record binds the 0.8.0 specification changes, migration boundary,
security posture, evidence, artifact boundary, and local release checklist. It
does not widen the project's 1.0.0 scope or start the Go implementation.

## Contract changes

- RFC 0009 adds three independent INI contracts: `ini.portable@1`,
  `ini.windows@1`, and `ini.python-configparser@1`. The caller selects the
  Profile and encoding before formation; no extension, fallback parser, or
  host locale selects semantics.
- RFC 0010 adds `java-properties.reader@1` and
  `java-properties.latin1@1`. Both preserve natural/logical lines, every
  property occurrence, escape provenance, and exact Java UTF-16 code units;
  their source contracts remain distinct.
- RFC 0011 adds eight contract/version pairs for source encoding and v2 source,
  patch, and materialization payloads, exact Java UTF-16 strings, and externally
  located INI/Properties query results. `core.semantic-model@6` contains 38
  contracts and 166 stable failure codes.
- Semantic-model v1-v5 arrays, manifests, constructors, payload schemas, and
  decoder behavior remain frozen. Registering a v2 source payload does not
  reinterpret a v1 encoding enumeration or BOM rule.

## Migration from 0.7.0

- Workspace dependencies should move from `0.7.0` to `0.8.0` as one unit.
- `RegistryManifest::current()`, `ContractRegistry::current()`, and
  `ErrorCodeRegistry::current()` now select semantic-model v6. A peer pinned to
  v5 must keep calling the explicit `v5()` constructors.
- Existing JSON/JSONC/JSON5, TOML, YAML, PortableValue/PVCE, and
  PortableGraph/PGCE contracts retain their published semantics.
- INI callers must pass one `IniProfile` and one compatible
  `IniEncodingSelection`. Parsing through several profiles and choosing a
  success is not compatibility behavior.
- Properties callers must choose `parse_reader` with an explicit text encoding
  or `parse_latin1` with byte-preserving Latin-1 semantics. A file extension
  does not choose between the two.
- Unique map consumers should request an explicit collision policy. The exact
  default projection is EntryMapping so duplicate and non-map association
  identity is never silently discarded.
- Windows code pages require source/materialization v2 payloads. A v1 peer
  continues to reject them instead of receiving an unknown value under a known
  schema.

## Security notes

- Parse, query, projection, materialization, and edit perform no network or
  filesystem I/O and do not read environment variables, registries, provider
  chains, locale encodings, Properties defaults, or classpaths.
- Windows code-page identity is a pinned numeric registry. Invalid multibyte
  sequences fail; the host active code page is never queried.
- `DetectUnicode` and `TreatAsContent` BOM policies are explicit snapshot facts.
  A SourcePatch must preserve digest, selected encoding, BOM policy, BOM facts,
  exact ranges, and original bytes; transcoding is materialization.
- Java Properties escapes produce exact UTF-16 code units. Unpaired surrogates
  remain valid native content but cannot enter an ordinary PortableValue String
  projection.
- Formation, projection, materialization, protocol decode, and edit limits fail
  without a partial completed value, target Document, or committed transaction.
- Recovered INI/Properties documents retain exhaustive syntax/error coverage
  for inspection, while semantic projection, materialization-from-document, and
  edit commit remain unavailable.

## Known limitations

- The INI Profiles model deterministic file content, not Windows profile API
  registry redirection/cache, .NET provider layering, Python interpolation or
  multi-file precedence, or Qt application/organization fallback scopes.
- The Properties Profiles do not implement XML Properties, ResourceBundle,
  defaults chains, Hashtable mutation, classpath lookup, or time-dependent
  `store()` output.
- Canonical INI/Properties materialization creates a new valid document. It is
  not a general formatter for an existing source file.
- XML, plist, HCL, Schema, semantic diff/merge, incremental parse, Live Query,
  filesystem transactions, stable process plugins, and Go remain later roadmap
  milestones. `.env` remains a future source adapter, not a format Profile.

## Evidence manifest

- language-neutral suites: 14 suites, 332/332 cases;
- semantic-model v6: 25/25; INI family: 20/20; Java Properties: 22/22;
- fixed runtime differentials: OpenJDK 25.0.4 11/11, CPython 3.14.6
  ConfigParser 9/9, .NET 10.0.10 INI provider 7/7, Windows wide profile API
  5/5, and Qt 6.10.2 QSettings 4/4, for 36/36 total;
- retained upstream gates: JSON5 83/83; TOML 205 valid and 474 invalid; YAML
  307 valid, 94 invalid, and one explicit future-version Profile exclusion;
- real INI/Properties fixtures: desktop/application/service configurations and
  Java logging/build/message configurations, with byte-exact render,
  projection/materialization closure, edit proof, and patch replay;
- workspace tests: 452 on Rust 1.97 and Rust 1.85, with strict Clippy on both;
- documentation gates: rustfmt, doctest, and rustdoc `-D warnings`;
- supply chain: Cargo.lock's 38 crate dependencies scanned against 1,189 local
  RustSec advisories, with all cargo-deny categories passing;
- artifact gate: 11/11 publishable `.crate` archives passed path, internal
  checksum, extraction, and all-target/all-feature compilation checks on Rust
  1.97 and Rust 1.85;
- auxiliary coverage: 84.65% regions, 82.73% functions, and 86.59% lines. The
  Windows report exposed no branch denominator, and 0.8.0 declares no coverage
  percentage threshold;
- performance: `BENCHMARKS-0.8.0.md`, three release samples at 20,000
  iterations for parse, native query, exact projection, canonical
  materialization, and semantic edit.

## Artifact boundary

The runtime facade and ten supporting libraries are publishable, for 11 crate
archives. `consema-conformance` is deliberately `publish = false`: it is the
repository-owned runner for root-level vectors, fixtures, upstream suites,
runtime adapters, hardening corpora, and benchmarks. Publishing it without
those repository assets would produce a package that cannot prove its stated
contract.

Before an initial registry publication, Cargo's ordinary package verifier
cannot resolve normalized `consema-* 0.8.0` dependencies from crates.io. The
repository therefore runs `scripts/verify-package-archives.ps1`: it assembles
the final archives offline, rejects unsafe archive paths, checks every embedded
internal dependency checksum against the corresponding archive SHA-256,
extracts every archive outside the workspace, and compiles those exact contents
through local registry patches. This is stronger than compiling workspace
sources and does not claim that a remote publication occurred.

No repository remote is configured. Repository, homepage, publication,
signature, and hosted-release metadata are not invented by this local release.

## Release checklist

- [x] accepted RFCs and explicit non-goals
- [x] workspace and all local dependency versions set to 0.8.0
- [x] v1-v5 registry immutability and v6 manifests
- [x] language-neutral source-v2, INI, Properties, and protocol vectors
- [x] pinned runtime authority, adapter digest, and complete case accounting
- [x] production-shaped fixtures without secrets or unclear licenses
- [x] mutation, resource, encoding, and atomic-publication gates
- [x] Rust current and MSRV tests plus strict Clippy
- [x] rustfmt, doctest, rustdoc `-D warnings`
- [x] RustSec and cargo-deny
- [x] fixed benchmark corpus and full sample report
- [x] exact publishable-archive verification on current and MSRV
- [x] changelog, implementation contract, migration guide, and limitations
- [ ] signed/published artifacts and remote release publication (outside this
      local repository scope)
