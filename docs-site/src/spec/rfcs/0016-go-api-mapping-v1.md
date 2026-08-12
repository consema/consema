# RFC 0016: Go API mapping v1

- Status: Accepted（2026-08-07 随 15-kind 契约映射修订；Go 实现 0.14.0 进行中）
- Date: 2026-08-07
- Scope: the charter (立项) RFC of the Go SDK API surface. It freezes the Go
  module layout, the core value-model mapping (PortableValue/PortableGraph to
  Go types), the formation/projection/materialization/edit API shapes, the
  error classification contract, and the conformance integration contract,
  mapped against the Rust facade (`crates/consema`) and the language-neutral
  contracts. It does **not** specify implementation details; the Go
  implementation plans land with 0.14.0+ (roadmap §16.1-§16.5)
- Depends on: RFC 0002 (cross-format protocol v1), RFC 0003 (source, syntax
  query, and patch v1), RFC 0004 (materialization, conversion, structural
  edit v1), RFC 0008 (semantic-model v5), RFC 0011 (semantic-model v6
  registration and error-code discipline), RFC 0015 (CLI machine protocol;
  the Go CLI reuses the same protocol in 0.19.0), roadmap §11 (Rust/Go dual
  implementation principles), §15.2 (this RFC is the §15.2 "Go API mapping
  RFC 已通过" gate), §15.7 (Feature-Complete Manifest as the Go starting
  point, line 1445), §16 (Go phase plans), §17 (language-neutral conformance
  architecture), `docs/API-REVIEW-0.13.0.md` (M4 API review; the naming
  dispositions this RFC pins)
- External behavior references: none; the only external contracts are the
  shared language-neutral conformance vectors (`conformance/vectors/`, 18
  suites, 508 cases at 0.13.0) and the semantic-model contract registry

## 1. Decision

Consema 0.14.0 begins the Go implementation of the Consema language-neutral
contracts. This RFC freezes the mapping of those contracts onto Go API
surface shapes — module layout, value types, document/formation entry
points, projection/materialization/edit operations, error classification,
and the conformance integration contract — so that the Go work starting at
0.14.0 implements a fixed surface instead of re-deriving one. Go is an
independent implementation (roadmap §11.2), not a translation of the Rust
crates: internal trees, caches, and algorithms differ; the language-neutral
behavior must be identical (roadmap §11.2 list: PortableValue/PortableGraph
equality, PVCE/PGCE bytes, protocol decoding, Capability declarations, parse
formation, diagnostic code/category/order, normalized native-result facts,
query count/identity/order, projection/materialization reports, edit and
conflict results, resource-limit completion semantics).

The Rust Feature-Complete Manifest (`docs/fc-manifest-0.13.0.json`, M9) is
the Go starting point — never an accidental local workspace state (roadmap
§15.7, line 1445).

### 1.1 Non-negotiable constraints

- **No FFI**: Go never imports, links, or calls Rust (`cgo` is prohibited;
  roadmap §16.1 hard gate "Go 不导入或调用 Rust").
- **No private-AST serialization**: Go never consumes serialized Rust
  private ASTs (roadmap §11.2); the only cross-language byte surfaces are
  PVCE/1, PGCE/1, the protocol transports (canonical JSON, RFC 0015 §3.2),
  and the shared conformance vectors.
- **Go-idiomatic surface**: packages, errors, and iterators follow Go
  conventions (roadmap §11.2); completed public objects are logically
  immutable; concurrent reads, cancellation (`context.Context`), and
  resource limits follow Go ecosystem norms.
- **Language-neutral identity only**: identical behavior is required only on
  language-neutral facts; Go error text never participates in conformance
  comparison (roadmap §16.1 hard gate "Go error text 不参与规范比较").

## 2. Scope and non-goals

### 2.1 Scope

- The Go module layout and package topology (Section 3).
- The core value model mapping, PortableValue and PortableGraph to Go types
  (Section 4).
- Formation, projection, materialization, and edit API shapes (Section 5).
- Error classification (Section 6).
- The conformance integration contract (Section 7).
- The pinned language-neutral spellings carried over from the 0.13.0 API
  review (Section 8).
- Versioning and release-train relationship (Section 9).

### 2.2 Non-goals (deferred to implementation milestones)

- Implementation details of any package (0.14.0-0.18.0 milestones, roadmap
  §16.1-§16.5).
- The Go CLI (0.19.0, roadmap §16.6/§22.6); it reuses the RFC 0015 machine
  protocol, whose schemas are already language-neutral.
- Benchmarks, fuzz targets, and security-matrix parity (0.19.0).
- Exact Go `go.mod` publish path: the module path convention is frozen here
  (Section 3.1); the publishable repository path is an implementation
  decision of 0.14.0.
- Any change to the Rust API surface: this RFC maps contracts onto Go; Rust
  API changes continue to follow the version governance of roadmap §12.

## 3. Go module layout

### 3.1 Module

One module named `consema` (module path convention: `consema.dev/consema`
or the publish-resolved path recorded at 0.14.0; the path is an
implementation fact, the single-module structure is frozen). The SDK and the
future Go CLI share one module (mirroring `crates/consema`'s facade +
`[[bin]]` structure, RFC 0015 §1 precedent).

### 3.2 Package topology (frozen)

| Go package | Maps to (Rust) | Responsibility |
|---|---|---|
| `consema/core` | `consema-core` | PortableValue, strict equality/hash, PVCE/1 codec, BigInteger/Decimal wrappers |
| `consema/graph` | `consema-graph` | PortableGraph, graph equality, PGCE/1 codec |
| `consema/protocol` | `consema-protocol` | language-neutral codecs, contract registry, error registry, CLI machine protocol records (RFC 0015) |
| `consema/document` | `consema-document` | SourceSnapshot, Span, NodeRef, ProfileId, FormationStatus, ParseLimits, MaterializationRequest, SourcePatch |
| `consema/json`, `consema/toml`, `consema/yaml`, `consema/ini`, `consema/properties`, `consema/xml`, `consema/plist`, `consema/hcl` | one crate each | per-family documents, queries, projections, materializations, edits, operation registries |
| `consema` (root) | `crates/consema` facade | `Document` union type, `Convert*` composition, `Registry` surface (families/profiles/query domains/operation registries) |
| `consema/conformance` + `cmd/consema-conformance` | `consema-conformance` | the Go conformance runner over the shared vectors (Section 7) |

Constraints:

- No package may import a sibling format package's private internals;
  cross-family composition (convert) lives in the root `consema` package
  only.
- `core` and `graph` depend on nothing else in the module (roadmap §16.1:
  value/graph/protocol first, proving independent implementability).

## 4. Core value model mapping

### 4.1 PortableValue → Go types (frozen)

The language-neutral PortableValue contract is the closed fifteen-kind
registry of 配置内容统一处理标准与 Rust 参考实现.md §10 and
`crates/consema-core/src/value.rs` (PortableValueKind): Null, Boolean,
Integer, Decimal, BinaryFloat32, BinaryFloat64, String, Bytes, Date, Time,
LocalDateTime, OffsetDateTime, Sequence, Object, EntryMapping. The Go
mapping covers all fifteen kinds:

| PortableValue kind | Go type | Notes |
|---|---|---|
| Object | `*core.Object` | ordered entries: `[]core.Entry` (key, value); **never `map[string]Value`** — entry order is a language-neutral fact (roadmap §16.3: Go map iteration order must not affect any public result); duplicate keys rejected at construction (RFC 0002 object contract) |
| Array | `*core.Array` | ordered items: `[]core.Value`; Sequence on the wire |
| String | `core.String` | `string` alias or struct per implementation; Unicode scalar sequence, no normalization |
| Integer | `core.Integer` | wraps `*big.Int`; canonical PVCE integer encoding |
| Decimal | `core.Decimal` | canonical coefficient × 10^exponent; no float round-trip |
| BinaryFloat32 | `core.BinaryFloat32` | exact IEEE-754 binary32 bit pattern |
| BinaryFloat64 | `core.BinaryFloat64` | exact IEEE-754 binary64 bit pattern |
| Bytes | `core.Bytes` | raw octet sequence; never String; all encoding/decoding explicit |
| Date | `core.Date` | proleptic Gregorian, astronomical year numbering, arbitrary-precision signed year; constructor validates month/day incl. leap rule on the year magnitude |
| Time | `core.Time` | hour 0-23, minute/second 0-59, exact fractional second in [0, 1); no leap seconds, no 24:00:00 |
| LocalDateTime | `core.LocalDateTime` | Date + Time, no offset; not a timestamp |
| OffsetDateTime | `core.OffsetDateTime` | LocalDateTime + fixed UTC offset in whole seconds, \|offset\| < 24 h |
| Boolean | `core.Boolean` | two-valued |
| Null | `core.Null` | singleton |
| EntryMapping | `*core.EntryMapping` | ordered arbitrary-key associations: `[]core.EntryMappingEntry` (key, value are any PortableValue); duplicates and order are value semantics |

- `Value` is a closed interface over the fifteen kinds; exhaustive matching is
  required for all conformance-relevant code paths (no `default` that
  silently accepts unknown kinds).
- Strict equality (`Equal(a, b Value) bool`) implements PortableValue
  equality: kind identity plus canonical byte/form equality; `Hash` is
  consistent with `Equal` and order-dependent (objects and arrays hash by
  ordered content).
- Objects reject duplicate keys at construction time (the object contract of
  RFC 0002; the Rust `ObjectBuilder` uniqueness invariant maps to a
  constructor error).
- `PortableGraph` maps to `graph.Graph` with the same strict
  equality/hash rules plus node-identity ordering (RFC 0006); PGCE/1 bytes
  are byte-identical to the Rust codec (roadmap §16.1 hard gate).

### 4.2 Byte surfaces

- PVCE/1: `core.EncodePVCE(v Value) ([]byte, error)` / `core.DecodePVCE([]byte, limits) (Value, error)`; bytes must equal the Rust codec output (hard gate; verified by the shared vectors `protocol-v1.json`).
- Canonical JSON transport (RFC 0015 §3.2): the same strict canonical
  decoder used by the machine protocol, byte-for-byte equal to
  `consema-protocol`'s canonical JSON.

## 5. Formation, projection, materialization, and edit API shapes

### 5.1 Formation (frozen)

- Per-family entry points mirror the facade: `document.Parse(source []byte, profile Profile, limits ParseLimits) (*Document, *FormationFailure)` with a `context.Context` first parameter where cancellation applies (roadmap §16.2).
- `FormationStatus` is a closed two-value enum (`Complete`, `Recovered`); the facade's `formation_status()` naming is the Go standard (`Status()` accessor; the 0.13.0 review's F10 disposition: Go exposes only the `formation_status` equivalent, no `status` alias).
- `FormationFailure` carries the ordered `[]Diagnostic` (code, category, severity, span, arguments, notes, occurrence) with the registry-bound validation of RFC 0011 (unknown code or category contradiction is a protocol error, exactly as `DiagnosticMessage::from_core_with_registry` enforces).
- Parse limits: `ParseLimits` (and per-family limits) mirror the Rust defaults; exceeding a limit is a `ResourceLimit` error carrying the frozen limit code (RFC 0015 §5.2 classification applies at the protocol layer).

### 5.2 Projection and materialization (frozen)

- Projection: per-family `ProjectionRequest` structs (target contract id/version, default policy, rules, limits) and `ProjectionResult` sealed outcomes: `Complete{Value, Fidelity, Report, Provenance}` or `Failed{Diagnostics, Report}` — same shape as the facade's per-format results; the conservative default policy is `core.projection.exact-or-reject@1` (never invented, roadmap §10 line 818).
- Materialization: `MaterializationRequest` (target profile, style, encoding, newline, mapping policy, representability, limits) → `MaterializationResult` `Complete{Snapshot, Fidelity, Report, Provenance}` or `Failed{...}`; record-format gates (the versioned internal record consumed only by its owning family's materializer) are identical in Go.
- Provenance and reports are externalized per the RFC 0015 record shapes when crossing the protocol layer; inside the SDK they are the family's typed values.

### 5.3 Edit (frozen)

- `EditTransaction` (operations against one snapshot), `ChangeSet` (ordered source edits), `SourcePatch` (apply/validate) mirror RFC 0004; dry-run semantics identical; nothing authorizes file writes (RFC 0015 §8.1 read-only precedent applies to the SDK's patch objects).
- Edit failures carry the registered code surface of the Rust crates (Section 6); the internal enum-name drift of the 0.13.0 review (F3) is explicitly **not** copied into Go — Go uses one consistent vocabulary per code.

### 5.4 Query (frozen)

- Query definitions and domains are the language-neutral ones (Section 8.2); native/syntax/formation domain ids are pinned spellings, not Go-invented names.
- Match results: `QueryResult` with deterministic match count/identity/order (roadmap §11.2); Go iterators must produce the same order as the Rust vector results.

## 6. Error classification (frozen)

- One `Diagnostic` type in `consema/protocol` carrying `Code`, `Category`, `Severity`, `Arguments`, `Notes`, `Occurrence` — the `core.diagnostic@1` record shape; construction validates against the frozen `ErrorCodeRegistry` (unknown code or category contradiction is an error, RFC 0011).
- SDK operations return typed errors implementing `interface { Code() string }`; the stable code is always the registered code (format-local code families pass through unchanged per RFC 0015 §5.2).
- The CLI exit-class mapping (`classify_error_code`, RFC 0015 §5.1/§5.2) is a protocol-layer function implemented once in Go (`protocol.ClassifyErrorCode(code string) ExitClass`) and used by the Go CLI in 0.19.0; the SDK itself never classifies.
- Resource-limit semantics: limit failures are `ResourceLimit` errors with the frozen codes; no truncation-then-success (SECURITY.md line 14).
- Go error text is human presentation only and never participates in conformance comparison (roadmap §16.1).

## 7. Conformance integration contract (frozen)

- **Both implementations run the same vectors**: the Go conformance runner reads `conformance/vectors/*.json` directly (the shared vector files are the authority, roadmap §17); the 18-suite / 508-case inventory at 0.13.0 is the starting inventory, revisioned per the FC manifest digest.
- The Go runner mirrors `consema-conformance`'s suite organization: one runner module per suite family with the same skip_path discipline as the differential oracles (documented skip = success, never silent).
- **Differential runs**: bidirectional Rust/Go differential harness for normalized results (roadmap §16.2/§16.6); cross-language PVCE/PGCE byte equality is a hard gate at 0.14.0.
- **Go discovers spec problems**: roadmap §11.3 process applies — stop the Go capability, build the minimal cross-language counterexample, classify (implementation/test/spec), fix spec and conformance first, publish a new contract ID if public behavior changes, Rust passes the revised vectors first, then Go resumes. The Rust Feature-Complete Baseline is not a "Rust is always right" claim (roadmap §11.3).
- The Go capability set at 0.18.0 must align with the Rust Feature-Complete Manifest: no "Rust-only" mandatory behavior (roadmap §16.5 hard gate).

## 8. Pinned language-neutral spellings (carried from the 0.13.0 API review)

The M4 review (`docs/API-REVIEW-0.13.0.md` §1) disposed the naming-drift
findings as frozen for 0.13.0. This RFC makes the Go API the first consumer
that must reproduce those spellings exactly:

- **Suite/family ids** (F13): `xml.formation@1`, `xml.native-semantic-query@1`, `xml.lossless-syntax-query@1`, `plist.native-semantic-query@1`, `plist.lossless-syntax-query@1`, `plist.binary-structure-query@1`, `hcl.native-semantic-query@1`, `hcl.lossless-syntax-query@1`, `yaml.native-semantics@1` (suite-internal), `yaml.native-semantic-query@1` (domain).
- **Syntax-kind spellings** (F15): kebab-case for xml/plist (`"tag-close"`, `"plist-open"`), PascalCase for hcl/yaml (`"TagClose"`, `"DocumentStart"`) — the Go lossless-syntax-query match roles reproduce the Rust spellings byte-for-byte.
- **Query operator ids** (F11): `ini.duplicate-group@1`, `properties.duplicate-group@1`, `plist.duplicate-key-group@1` all frozen as-is for 0.13.0; Go implements the same ids (the v8 unification, if approved, is applied to both languages together).
- **Projection-failure codes** (F4) and **edit codes** (F2/F3): the registered codes are the contract; the Go vocabulary uses one name per code (the Rust enum-name drift is not reproduced).

Any future spelling unification (semantic-model v8 window) is a contract
change applied to Rust and Go together via the §11.3 process.

## 9. Versioning and release-train relationship (frozen)

- The Go module version follows the product release train (roadmap §11.4): `Consema Product 1.0.0` = Rust crates 1.0.0 + Go module v1.0.0 + Specification v1 release set + Conformance release set 1.0.0; before 1.0.0 the Go module is v0.x.
- Package versions never substitute contract versions: `core.pvce.full@1`'s `@1` and the module version are different dimensions (roadmap §11.4).
- Go starts from the 0.13.0 Feature-Complete Manifest (M9 deliverable) and re-checks it at each Go milestone.

## 10. Rejected alternatives

- **cgo/FFI wrapper over the Rust crates**: prohibited by roadmap §11.2 (Go must not import or call Rust); also fails the dual-implementation audit value.
- **Serializing Rust private ASTs for Go consumption**: prohibited by roadmap §11.2; the only shared byte surfaces are PVCE/PGCE, protocol transports, and the vectors.
- **Code generation from Rust types (bindgen-style)**: would make Go a mechanical translation, contradicting §11.2 ("Go 不是 Rust 的翻译"); rejected; the mapping is specified here by hand so the Go API is Go-idiomatic.
- **Go maps for Object entries**: rejected — entry order is a language-neutral fact (RFC 0002 object contract); `map[string]Value` would leak iteration order into public results (roadmap §16.3 hard gate).
- **Reusing the Rust conformance runner for Go validation**: rejected — the dual-implementation principle requires both languages to run the same vectors through their own runners (roadmap §16.1 "Go conformance runner" deliverable).
- **Deferring this RFC until 0.14.0 implementation**: rejected by §15.2 (this RFC is the "Go API mapping RFC 已通过" gate of the 0.13.0 feature-complete gate); the charter must exist before implementation starts.
