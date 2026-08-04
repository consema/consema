# RFC 0007: YAML family profiles and safety v1

- Status: Accepted for Consema 0.7.0 implementation
- Date: 2026-08-04
- Scope: YAML 1.2 Core and 1.1 compatibility profiles, raw source and lossless
  document facts, native serialization/representation semantics, query,
  graph/value projection, materialization, structural edit, recovery, security,
  external conformance, and semantic-model v5
- External standards: [YAML 1.2.2](https://yaml.org/spec/1.2.2/),
  [YAML 1.1](https://yaml.org/spec/1.1/), the YAML 1.1
  [language-independent type repository](https://yaml.org/type/), and the
  pinned [yaml-test-suite](https://github.com/yaml/yaml-test-suite/tree/data-2022-01-17)

## 1. Decision

Consema 0.7.0 publishes two explicit profiles:

```text
yaml.1.2-core@1      YAML 1.2.2 presentation grammar + Core schema
yaml.1.1-compat@1    YAML 1.2.2-compatible presentation + frozen 1.1 scalar resolution
```

They share source, lossless structure, serialization-tree identity, graph
composition, transaction, proof, and patch infrastructure. They do not share
implicit scalar resolution, accepted `%YAML` directive versions, canonical
scalar spellings, or materialization styles.

`yaml.1.1-compat@1` is deliberately named “compat”, not “yaml.1.1”. It covers
the production compatibility surface used by current 1.1-oriented loaders:
the compatible presentation grammar, `%YAML 1.1`, and the frozen scalar rules
in section 6. It does not claim every historical 1.1 grammar ambiguity or
application-specific constructor.

## 2. Three distinct YAML facts

The implementation keeps the YAML specification's layers separate:

```text
presentation stream
  directives, markers, comments, trivia, styles, anchors, aliases, tag spelling

serialization tree
  ordered document nodes and alias occurrences, unresolved/resolved tag facts

representation graph
  resolved tagged scalar/sequence/mapping nodes, sharing, cycles
```

Anchors and aliases are not PortableGraph node kinds. An anchor labels the
first serialization occurrence; an alias occurrence refers to the most recent
preceding anchor of that name. Composition turns both into graph identity.
Conversely, materializing a graph introduces deterministic anchors/aliases as
presentation details when sharing or cycles require them.

## 3. Source and encoding

Both profiles accept exact raw bytes in:

- UTF-8, with or without BOM;
- UTF-16LE with BOM;
- UTF-16BE with BOM.

No BOM means UTF-8. UTF-16 without BOM, UTF-32, Latin-1, binary, encoding
guessing, and contradictory caller/BOM assertions fail before document
formation. All documents in one stream use the selected encoding; a permitted
per-document BOM remains source content.

The public entry point builds `SourceSnapshot` first. Parser offsets in decoded
UTF-8 coordinates are converted back to exact raw-byte spans through the
snapshot's checked boundary index. Unmodified rendering always returns the
original raw bytes, including BOM and original newline encoding.

## 4. Formation and recovery

Formation states remain:

```text
Complete
Recovered
FatalFormationFailure
```

Complete means the entire stream is syntactically valid, every document
composes, all aliases resolve to prior anchors in the same document, tags and
scalars satisfy the selected profile, and every configured limit holds.

Recovered retains the complete source and exhaustive syntax/error-region
coverage plus deterministic diagnostics. Native serialization and graph views
are unavailable unless individually proven complete; 0.7.0 does not fabricate
partial graph semantics after a parser/composition failure.

Source decoding failure, source-size overflow, impossible coordinate mapping,
or allocation/host-size overflow is fatal and returns no Document. Syntax,
directive, tag, scalar-resolution, undefined-alias, duplicate-anchor-policy,
and normal parse-limit failures can form a Recovered Document when bounded
recovery indexing succeeds.

## 5. YAML 1.2 Core profile

`yaml.1.2-core@1` follows YAML 1.2.2 and:

- accepts no `%YAML` directive or exactly `%YAML 1.2` per document;
- rejects `%YAML 1.1`, future versions, and duplicate version directives;
- resets tag directives and anchors at each document boundary;
- resolves plain, non-specific scalars with the YAML 1.2 Core schema;
- resolves quoted and block scalars to `tag:yaml.org,2002:str` unless an
  explicit tag says otherwise;
- validates explicit standard tags against node kind and scalar grammar;
- preserves unknown/custom tags in the native view but never constructs an
  application object or admits unknown canonical semantics to PortableGraph;
- treats the merge key as an ordinary scalar/mapping association unless the
  separately versioned merge capability is explicitly requested. That
  capability is not published in 0.7.0.

The standard resolved tags used by graph projection are:

```text
tag:yaml.org,2002:null
tag:yaml.org,2002:bool
tag:yaml.org,2002:int
tag:yaml.org,2002:float
tag:yaml.org,2002:str
tag:yaml.org,2002:seq
tag:yaml.org,2002:map
```

Finite integers and decimals are parsed without host-width rounding.
`.inf`/`-.inf`/`.nan` use the same four frozen BinaryFloat64 bit patterns as
JSON5 when lowered to PortableValue; YAML has no negative-NaN spelling in the
1.2 Core schema, so it cannot produce that fourth pattern implicitly.

## 6. YAML 1.1 compatibility profile

`yaml.1.1-compat@1` accepts no directive or exactly `%YAML 1.1`; an explicit
1.2 directive conflicts with the selected profile. It uses the same safe
presentation pipeline and adds the following frozen implicit scalar forms:

- null: empty, `~`, `null` in the three specified cases;
- bool: `y/n`, `yes/no`, `true/false`, `on/off` in the specified case forms;
- int: binary, leading-zero octal, decimal, hexadecimal, underscores, and
  base-60 components whose later fields are 0..59;
- float: finite decimal/exponent, underscores, base-60, `.inf`, `-.inf`, and
  `.nan` in the specified case forms;
- timestamp: date and timestamp forms from the YAML 1.1 type repository.

Resolution uses exact grammar, not host `parse()` permissiveness. Arbitrary
precision Integer/Decimal and existing Date/LocalDateTime/OffsetDateTime values
are used where exact. A timestamp with no zone follows the published 1.1 UTC
rule and records that resolution in provenance. Values that cannot fit a
published exact semantic category remain tagged scalar graph content or fail a
PortableValue projection; they are not rounded.

Explicit 1.1 collection/scalar tags are preserved and kind-validated. `!!merge`
does not execute merge semantics in this version. `!!binary` is validated and
can lower exactly to Bytes. `!!omap`, `!!pairs`, and `!!set` retain their tagged
graph structures; conversion to PortableValue requires an explicit supported
mapping policy.

## 7. Lossless Document and native view

The immutable YAML Document retains:

- stream and ordered document identities;
- directives, start/end markers, BOMs, comments, whitespace and line breaks;
- block/flow collection style;
- plain, single-quoted, double-quoted, literal, and folded scalar style;
- block scalar indentation and clip/strip/keep chomping indicators;
- explicit/non-specific/implicit tag spelling plus resolved tag;
- anchor definitions and alias occurrences with exact names and source spans;
- ordered mapping association and sequence element identities;
- arbitrary keys, duplicate source associations, compact notation and empty
  nodes;
- syntax errors and recovery regions;
- exhaustive, non-overlapping raw-byte coverage.

Native handles are snapshot-bound and use YAML-specific roles. The backend
event/AST types are never public.

The reference implementation pins `saphyr-parser = 0.0.11` with default
features disabled as a syntax-event backend. Consema independently owns raw
source retention, directive/comment/trivia indexing, raw-span mapping, profile
resolution, graph composition, limits, recovery, diagnostics, query,
projection, generation, and edits. Backend success is not sufficient evidence
for a Complete Document.

## 8. Graph composition and alias safety

Each complete YAML document composes to one graph root; an empty document
composes to the profile's resolved null scalar. Documents are independent and
cannot share anchors or graph nodes.

Composition:

1. reserves graph identity when a scalar/sequence/mapping node starts;
2. registers an anchor before descending into that node;
3. resolves an alias to the most recent preceding anchor in the same document;
4. adds graph edges without expanding the target;
5. permits self- and mutual cycles formed by backward aliases;
6. freezes only after all nodes, roots, tags, content, and limits validate.

Anchor reuse follows YAML's “most recent preceding node” rule and is preserved
as distinct source definitions. Undefined or forward aliases fail composition.
An alias is one edge regardless of target size; parse and graph formation never
perform recursive alias expansion.

## 9. YAML queries

The published domains are:

```text
yaml.native-semantic-query@1
yaml.lossless-syntax-query@1
core.portable-graph-query@1
```

YAML native roles include Stream, Document, Node, MappingEntry,
SequenceElement, AnchorDefinition, and AliasOccurrence. Syntax kinds include
BOM, Directive, DocumentMarker, Indicator, Anchor, Alias, Tag, Scalar,
Whitespace, Newline, Comment, and ErrorRegion, with stable style subfacts.

Native query structure order is presentation order, so alias occurrences are
independently observable. Graph query order is canonical first-visit order and
does not repeat shared nodes unless an association operator returns repeated
edges. Definitions validate domain, operator, kind names, argument types, and
role composition before execution. Limits and cancellation never produce a
completed prefix disguised as success.

## 10. Projection

`yaml.projection.best-exact-graph@1` is the default YAML target. It preserves
all standard resolved tags, arbitrary mapping keys, association order,
sharing, and cycles. Projection provenance relates graph nodes and graph edges
to every relevant source node/alias occurrence without collapsing duplicate
origins.

`yaml.projection.best-exact-value@1` is separate and defaults to:

```text
stream             RequireExactlyOneDocument
sharing            Reject
cycle              Reject
tag                 RequireKnownPortableTag
mapping             BestExactObjectOrEntryMapping
alias expansion     Disabled
```

An explicit `DuplicateAcyclicSharing` policy authorizes loss of identity,
reports `Transformed`, and enforces maximum output nodes, depth, and
amplification ratio. A cycle always fails value projection. Unknown/custom tags
default to failure; stripping a tag requires explicit authorization and a
report event. Duplicate or non-string mapping keys never silently collapse or
stringify.

Failure carries no PortableGraph/PortableValue and no partial provenance.

## 11. Materialization

YAML publishes:

```text
yaml.canonical-block@1
yaml.canonical-flow@1
```

Materialization accepts a complete PortableGraph or PortableValue through
distinct typed entry points. Graph materialization uses canonical graph
numbering, emits explicit document starts for every root, and introduces
deterministic anchors `&g0`, `&g1`, ... for nodes whose topology requires an
alias. The first serialization occurrence defines the anchor before child
edges; later occurrences emit aliases, so cycles terminate.

Standard tags are emitted or omitted only where the selected profile resolves
the same tag and canonical content. Custom tags require a supported extension
contract. Strings that would resolve to a different tag are quoted. Mapping
entry and sequence order are preserved. Newline and UTF-8/UTF-16 target
encoding policies are explicit; output is reparsed under the target profile
before a Complete result is returned.

Canonical materialization is not a formatter for an existing Document.

## 12. Structural edit

The v1 YAML operation registry includes:

```text
yaml.edit.replace-scalar-semantic@1
yaml.edit.replace-scalar-literal@1
yaml.edit.insert-mapping-entry@1
yaml.edit.remove-mapping-entry@1
yaml.edit.insert-sequence-element@1
yaml.edit.remove-sequence-element@1
yaml.edit.rename-anchor@1
yaml.edit.insert-alias@1
```

Transactions are snapshot-bound and validate all operations before publishing
a candidate. Common edits retain indentation, flow/block style, scalar style,
comments, line endings, delimiters, and untouched raw bytes where compatible.
Fallback to canonical local spelling is explicit and reported.

Anchor-safe rules:

- renaming an anchor updates its exact dependent aliases in one transaction;
- removing an anchored definition while aliases remain is rejected;
- removing an alias does not remove its target;
- inserting an alias requires an earlier visible anchor in the same document;
- moving nodes across an anchor/alias dependency boundary is not published in
  v1;
- a scalar edit of an anchored node changes the shared graph node; aliases are
  not expanded or rewritten.

Successful dry-run and commit have identical replacements and target digest.
Candidate reparse, graph topology, proof, ChangeSet, and SourcePatch must all
validate. Failure returns none of them.

## 13. Security and resource behavior

YAML parsing and composition perform no network, filesystem access, import,
environment lookup, application object instantiation, expression evaluation,
or custom tag constructor.

In addition to common source/parse/query/projection/materialization limits,
YAML defines:

```text
max_documents
max_directives_per_document
max_anchors_per_document
max_alias_occurrences
max_tag_bytes
max_scalar_bytes
max_graph_nodes
max_graph_edges
max_mapping_entries
max_sequence_items
max_expanded_nodes
max_alias_expansion_depth
max_alias_amplification_ratio
```

The first group is enforced while scanning/events are consumed. Expansion
limits apply only to an explicitly authorized value projection; the parser and
graph projection never expand aliases. Counts are checked before proportional
allocation whenever possible. Deep inputs, mutation, truncation, cycles, and
alias bombs must remain panic-free and cannot return partial success.

## 14. Diagnostics and semantic-model v5

YAML diagnostics receive stable codes for source encoding, directives,
scanner/parser syntax, indentation, tag, scalar resolution, undefined alias,
profile mismatch, graph construction, projection policy, materialization,
anchor-safe edit, and every resource limit.

Consema 0.7.0 publishes `core.semantic-model@5`. v1-v4 registries and payload
decoders remain frozen. v5 adds PortableGraph/PGCE, graph query/result,
graph projection/provenance, and any YAML-specific transferable payloads that
survive the protocol audit. Process-local YAML NodeRef and cursor facts still
require stable caller bindings before transport.

## 15. Conformance and production gates

Language-neutral suites cover at least:

- both profiles and every divergent implicit scalar family;
- UTF-8/UTF-16 BOM and conflict behavior;
- empty and multi-document streams;
- every collection/scalar style and block chomping mode;
- directives, tags, arbitrary/duplicate keys, anchors, aliases, sharing and
  cycles;
- undefined/overridden anchors and cross-document isolation;
- native/syntax/graph query roles, order, limits and cancellation;
- exact graph projection and every value-projection policy/failure;
- canonical block/flow materialization and target reparse;
- each structural edit, trivia ownership, anchor dependency, conflict, proof,
  patch, and atomic failure;
- malformed, truncated, deeply nested, alias-bomb, tag, Unicode, and mutation
  corpora.

The external acceptance gate pins `yaml/yaml-test-suite` data tag
`data-2022-01-17`, peeled commit
`6e6c296ae9c9d2d5c4134b4b64d01b29ac19ff6f`. The adapter records every
included/excluded case and reason; passing a subset cannot be reported as full
suite conformance. Real project fixtures include Kubernetes manifests, GitHub
Actions/CI workflows, Compose-style service configuration, and anchor-heavy
configuration without secrets or unclear licenses.

Release gates include Rust current/MSRV tests and strict Clippy, rustfmt,
rustdoc, dependency audit/deny, mutation/property tests, fixed benchmark
corpus, and byte-exact unmodified round trips for every accepted fixture.

## 16. Explicit non-goals

Consema 0.7.0 does not provide:

- arbitrary custom tag constructors or language-object deserialization;
- implicit `!!merge` execution;
- includes/imports or remote tags;
- schema validation;
- alias expansion by default;
- a general YAML formatter;
- cross-document anchors;
- graph diff/merge;
- cross-container node moves;
- filesystem write transactions;
- Go implementation.

## 17. Rejected alternatives

- **Deserialize through Serde:** rejected because comments, styles, arbitrary
  keys, aliases, sharing, cycles, duplicate associations, and source identity
  disappear.
- **Use one YAML profile with a compatibility Boolean:** rejected because
  scalar resolution and directive acceptance are observable semantics.
- **Let the backend define scalar types:** rejected because backend upgrades
  would silently change profile behavior.
- **Expand aliases during parse:** rejected because it destroys graph identity,
  cannot represent cycles, and enables amplification attacks.
- **Treat anchors/aliases as PortableGraph node kinds:** rejected because they
  are serialization/presentation facts, not representation graph nodes.
- **Preserve unknown tags as ordinary strings:** rejected because it fabricates
  equality and construction semantics.
- **Execute merge keys for convenience:** rejected because merge is a separate
  compatibility transformation with conflict and provenance rules.
- **Declare backend test-suite success as Consema conformance:** rejected
  because Consema adds raw-source, profile, graph, query, projection,
  materialization, edit, protocol, and resource contracts beyond syntax parse.
