# RFC 0008: Semantic model v5 graph and YAML protocol

- Status: Accepted for Consema 0.7.0 implementation
- Date: 2026-08-04
- Scope: additive `core.semantic-model@5` contracts, PortableGraph/PGCE
  transport, graph query and projection results, externally located YAML query
  results, and the 0.7.0 public error-code registry

## 1. Compatibility decision

Semantic model v5 is an ordered superset of v4. The v1, v2, v3, and v4
contract arrays, error-code arrays, manifests, and payload decoders remain
frozen. Selecting a v5 registry is the only way to recognize a v5 contract or
0.7.0 diagnostic code.

The five new contracts are:

```text
core.graph-projection-result@1
core.graph-provenance-map@1
core.graph-query-result@1
core.portable-graph@1
core.yaml-query-result@1
```

`core.query-definition@1` remains the query-definition container. Its domain
and operator versions already make definitions extensible without changing its
wire fields. `core.query-result@1` remains frozen and continues to reject Graph
and YAML roles.

All new objects use fixed field order and exact-field decoding. Unknown,
missing, or reordered fields fail. Integers are non-negative and fit `u64`;
container counts and blobs are bounded before proportional allocation.

## 2. `core.portable-graph@1`

The payload is both readable and byte exact:

```text
{
  schema: "core.portable-graph@1",
  encoding: "PGCE/1",
  roots: [CanonicalNodeId],
  nodes: [GraphNodeRecord],
  pgce: Bytes
}
```

`CanonicalNodeId` is the unsigned ID assigned by RFC 0006 canonical
first-discovery order. `nodes[i].id` must equal `i`. Node records are exactly:

```text
Scalar  { id, kind: "Scalar",  tag, canonical_content }
Sequence{ id, kind: "Sequence",tag, items: [CanonicalNodeId] }
Mapping { id, kind: "Mapping", tag,
          entries: [{ key: CanonicalNodeId, value: CanonicalNodeId }] }
```

Decode reserves all node IDs, defines every node, installs ordered roots, and
applies PortableGraph construction limits. It then strictly decodes `pgce` as
PGCE/1. The readable graph, decoded PGCE graph, and canonical re-encoding must
all agree exactly. Consequently neither representation is advisory and a
consumer cannot accept a contradictory display form.

## 3. `core.graph-query-result@1`

Graph-local handles are replaced by canonical node IDs, and the complete graph
is embedded so every match can be validated without ambient process state:

```text
{
  schema: "core.graph-query-result@1",
  domain_id: "core.portable-graph-query",
  domain_version: 1,
  role: GraphNode | GraphSequenceElement | GraphMappingEntry,
  graph: core.portable-graph@1,
  matches: [GraphMatch],
  completion: core.completion@1,
  diagnostics: [core.diagnostic@1]
}
```

Matches are exactly:

```text
Node            { kind: "Node", node }
SequenceElement { kind: "SequenceElement", parent, ordinal, node }
MappingEntry    { kind: "MappingEntry", parent, ordinal, key, value }
```

The decoder verifies the uniform role, produced count, every node range, parent
kind, association ordinal, and referenced child/key/value against the embedded
graph. Query order may contain repeated matches because `Concat` is allowed;
the result contract therefore does not impose uniqueness.

## 4. Graph projection and provenance

`core.graph-provenance-map@1` contains sorted, unique projected locations. A
location is one of `Root`, `Node`, `SequenceElement`, `MappingKey`, or
`MappingValue`, expressed with canonical node IDs. Every entry has one or more
ordered `SourceOrigin` records using the existing stable `source_id`, optional
caller `node_locator`, half-open byte range, and relation vocabulary. Raw
`SnapshotIdentity`, `NodeRef`, and Rust object addresses never cross the wire.

```text
{
  schema: "core.graph-provenance-map@1",
  entries: [{ projected, origins }]
}
```

`core.graph-projection-result@1` is atomic:

```text
{
  schema: "core.graph-projection-result@1",
  completion: core.completion@1,
  graph: null | { portable_graph: core.portable-graph@1 },
  provenance: core.graph-provenance-map@1,
  diagnostics: [core.diagnostic@1]
}
```

Only `Success` carries a graph. A failed result must carry empty provenance.
On success every provenance location is validated against the embedded graph.
The published YAML graph projection is exact, so no fidelity or loss report is
fabricated for this contract.

## 5. `core.yaml-query-result@1`

YAML native and lossless matches can be transferred only after caller
externalization:

```text
{
  schema: "core.yaml-query-result@1",
  domain_id: "yaml.native-semantic-query" | "yaml.lossless-syntax-query",
  domain_version: 1,
  role: YamlStream | YamlDocument | YamlNode | YamlMappingEntry |
        YamlSequenceElement | YamlAnchorDefinition | YamlAliasOccurrence |
        YamlSyntaxPiece,
  matches: [{ source_id, node_locator, role, ordinal }],
  completion: core.completion@1,
  diagnostics: [core.diagnostic@1]
}
```

Native-domain roles and the syntax-domain role cannot be mixed. Every locator
is non-empty and bounded; ordinals are strictly increasing. Constructing a
wire match directly from a `NodeRef` fails with
`core.protocol.process-local-handle@1`. Cursor state and cancellation tokens
remain process-local and are represented only by terminal completion facts.

## 6. v5 error-code additions

The v5 registry adds stable 0.7.0 codes in these closed families while retaining
all 92 v4 records unchanged:

- graph/PGCE: invalid graph, invalid PGCE, non-canonical PGCE, unsupported PGCE
  version, and their resource limits;
- YAML formation: parse syntax, profile/version mismatch, tag-kind mismatch,
  invalid explicit scalar tag, undefined anchors, alias/anchor name mismatch,
  malformed mapping/native event streams, and invalid native spans;
- YAML projection: document cardinality, cycle, sharing, unsupported tag,
  non-object mapping, invalid canonical scalar, unrepresentable timestamp, and
  graph/provenance resource limits;
- YAML materialization: unsupported tag, tag-kind mismatch, cross-document
  sharing, and round-trip mismatch;
- YAML edit: canonical fallback, invalid anchor name/placement, invisible
  anchor, live alias dependency, and same-container structural conflict.

Every code has one fixed `DiagnosticCategory`. Protocol diagnostics,
completions, projection reports, and nested results validate codes against the
explicitly selected semantic-model registry. The no-argument constructors and
decoders retain their semantic-model v1 behavior.

## 7. Protocol audit exclusions

The following 0.7.0 objects are intentionally not serialized:

- YAML `Document`, native nodes, syntax pieces, raw `NodeRef`, and query cursor;
- graph materialization provenance containing output `NodeRef` values before a
  caller assigns stable output locators;
- edit transactions and placement handles bound to one in-process snapshot;
- graph builders, partial graphs, partial projections, or partial edits.

These are not omissions from PortableGraph. They require source identity,
capability, transaction, or caller-binding contracts that v5 does not pretend
to supply.

## 8. Required conformance

Language-neutral vectors cover empty, shared, cyclic, duplicate-key, arbitrary-
key, and multi-root graphs; readable/PGCE disagreement; all graph result roles;
dangling and mismatched associations; graph provenance ordering and range
checks; every YAML result role; domain/role mismatch; process-local rejection;
v1-v4 registry immutability; v5 canonical JSON/PVCE round trips; malformed,
truncated, oversized, and mutation inputs.

Rust tests are the first executable implementation. The future Go package must
consume the same vectors and produce byte-identical PGCE, canonical protocol
JSON, and PVCE before it can claim semantic-model v5 compatibility.
