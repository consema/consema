# RFC 0006: PortableGraph and PGCE v1

- Status: Accepted for Consema 0.7.0 implementation
- Date: 2026-08-04
- Scope: immutable portable graph values, graph-local identity, strict graph
  equality/hash, canonical graph numbering, PGCE/1, bounded construction and
  decoding, and `core.portable-graph-query@1`

## 1. Decision

Consema introduces an independent graph value family:

```text
PortableGraph@1
PGCE/1
core.portable-graph-query@1
```

PortableGraph is not a new `PortableValue` variant. PGCE does not change
PVCE/1. The graph model exists because YAML representation graphs can contain
shared nodes and cycles, while a PortableValue is deliberately an immutable
tree whose implementation sharing is not public semantics.

The model is a rooted, directed, ordered, tagged graph. It preserves graph
topology without importing YAML anchors, aliases, styles, comments, directives,
or source locations. Those remain YAML Document facts.

## 2. Public model

One graph contains zero or more ordered roots and one closed set of reachable
nodes:

```text
PortableGraph {
  roots: [GraphNodeId]
  nodes: graph-local node definitions
}

GraphNode =
  Scalar  { tag, canonical_content }
| Sequence { tag, items: [GraphNodeId] }
| Mapping  { tag, entries: [{ key: GraphNodeId, value: GraphNodeId }] }
```

Rules:

- `GraphNodeId` is meaningful only inside one immutable graph;
- root order, sequence order, mapping association order, duplicate mapping
  associations, node kind, tag, scalar content, sharing, and cycles are value
  semantics;
- mapping keys are arbitrary graph nodes;
- every edge and root must reference a defined node;
- every defined node must be reachable from at least one root;
- an empty graph represents an empty stream of roots, not a null scalar;
- a graph may have multiple roots that share nodes, although YAML composition
  will not create cross-document sharing because YAML documents are independent;
- tag strings are resolved, non-empty tag identifiers without ASCII control or
  whitespace. PortableGraph does not retain shorthand handles or presentation
  spelling;
- scalar content is the producer's canonical content for that tag. The graph
  layer treats it as an exact UTF-8 string; a format or extension producer may
  enter it only when that producer's versioned contract defines the
  canonicalization.

PortableGraph does not execute a custom tag constructor. Unknown YAML tags are
not silently admitted as if their lexical scalar text were known canonical
semantics; the YAML projection policy must reject them or route them through a
separately versioned extension contract.

## 3. Construction lifecycle

Cycles require reservation before definition. The Rust builder therefore has
an explicit lifecycle:

```text
reserve node identity
  -> define exactly once as Scalar | Sequence | Mapping
  -> add ordered roots
  -> validate all references and reachability
  -> freeze PortableGraph
```

A reserved identity cannot be inspected as a completed node. Build failure
returns no partial graph. The builder rejects:

- duplicate definition;
- undefined node, root, or edge;
- unreachable definitions;
- an empty tag;
- an invalid tag identifier;
- resource-limit or host-size overflow.

The completed object owns immutable data and is `Send + Sync`. Builders and
temporary traversal state are not graph values.

## 4. Strict equality and hash

Original builder numbering is not semantic. Two graphs are strictly equal
when there is a root-preserving ordered graph isomorphism that preserves:

- root order;
- node kind;
- exact resolved tag;
- exact canonical scalar content;
- sequence edge order;
- mapping association order, including duplicates;
- key/value edge roles;
- shared-reference and cycle topology.

Consema computes this without recursive expansion. Canonical node IDs are
assigned by deterministic depth-first pre-order:

1. visit roots in root order;
2. assign the next ID when a node is first encountered;
3. for a sequence, visit items in order;
4. for a mapping, visit each association in order, key before value;
5. an already assigned node is a reference and is not traversed again.

All nodes are reachable, so this walk assigns every node exactly once. Equality
and hash observe the resulting canonical topology; they never compare pointer
addresses or expand cycles. Equal graphs must hash equally.

## 5. PGCE/1 wire format

PGCE/1 is a complete canonical byte stream:

```text
magic                 ASCII "PGCE"
version               minimal unsigned LEB128 1
root_count            minimal unsigned LEB128
node_count            minimal unsigned LEB128
roots[root_count]     canonical node IDs as minimal unsigned LEB128
nodes[node_count]     node records in canonical ID order
```

Node records are:

```text
0x20 Scalar:
  tag_utf8_length, tag_utf8
  content_utf8_length, canonical_content_utf8

0x40 Sequence:
  tag_utf8_length, tag_utf8
  item_count
  item_node_id[item_count]

0x41 Mapping:
  tag_utf8_length, tag_utf8
  entry_count
  (key_node_id, value_node_id)[entry_count]
```

Every integer and length uses minimal unsigned LEB128. IDs are zero-based. UTF-8
is exact and is not Unicode-normalized. The encoder first applies the canonical
numbering from section 4, so isomorphic graphs have byte-identical PGCE.

The decoder rejects:

- wrong magic or version;
- non-minimal, overflowing, or truncated varints;
- unknown node tags or trailing bytes;
- invalid UTF-8 or empty resolved tags;
- counts or blobs outside limits;
- out-of-range references;
- node records not ordered by canonical first discovery;
- unreachable nodes;
- any stream whose re-encoding differs from the input.

The last rule is a defense-in-depth canonicality check, not a substitute for
the preceding structural checks.

## 6. Resource limits

Graph construction, equality, hash, encode, and decode use iterative traversal
and never recursively expand an edge. Public bounded operations define at
least:

```text
max_stream_bytes
max_roots
max_nodes
max_edges
max_container_entries
max_tag_bytes
max_scalar_bytes
max_traversal_depth
```

Depth is the active traversal path, not alias expansion count. Edge and node
limits are checked before proportional allocation where the input provides a
count. Arithmetic overflow is a stable failure. No limit failure returns a
truncated graph or partial PGCE stream.

## 7. Portable graph query v1

`core.portable-graph-query@1` reuses the immutable validated query lifecycle but
has graph-specific typed matches:

```text
GraphNode
GraphSequenceElement
GraphMappingEntry
```

The v1 operator surface is:

```text
graph.reachable-nodes@1
graph.where-kind@1(kind: String)
graph.where-tag@1(tag: String)
graph.try-sequence-elements@1
graph.sequence-element-node@1
graph.try-mapping-entries@1
graph.mapping-entry-key@1
graph.mapping-entry-value@1
core.take@1
core.distinct-by-identity@1
```

Input yields graph roots in root order. `graph.reachable-nodes@1` performs the
same first-visit traversal as canonical numbering. Sequence and mapping
operators preserve their stored order. Identity is graph-local node identity
or `(parent node, association kind, ordinal)`; equality of scalar content does
not collapse matches. Definition/domain/type errors fail before the first
match. Runtime limit and cancellation terminals cannot be reported as
completed results.

## 8. PortableValue lowering

PortableGraph-to-PortableValue is an explicit projection, never a getter. It
must decide:

- whether exactly one root is required;
- whether non-core tags are rejected or explicitly stripped;
- whether mappings become Object or EntryMapping;
- whether sharing may be duplicated;
- how cycles are rejected;
- expansion node/depth/amplification limits.

The default exact policy accepts only a single-root acyclic tree whose tags and
scalar nodes have exact PortableValue mappings. Sharing is information, so even
acyclic sharing is rejected by default. An explicitly authorized duplicate-
sharing policy reports `Transformed` and remains bounded. Cycles never lower to
PortableValue.

PortableValue-to-PortableGraph is exact: it creates one root, standard
portable tags, and no public sharing. PVCE/1 bytes remain unchanged.

## 9. Protocol and versioning

PortableGraph and graph query introduce new semantic-model contracts rather
than modifying v1-v4 payloads. Stable wire payloads include a readable graph
form with canonical node IDs and PGCE bytes/hex for byte-exact cross-language
tests. Raw process-local graph handles are not serialized.

Any incompatible change to node semantics, equality, canonical numbering, or
wire bytes requires `PortableGraph@2`, `PGCE/2`, or a new query-domain version.
Adding a node kind is incompatible with PortableGraph@1.

## 10. Conformance

Language-neutral vectors must cover:

- empty, single-root, and multi-root graphs;
- every node kind and standard tag;
- arbitrary and duplicate mapping keys;
- shared child, self-cycle, mutual cycle, and cycle through a key;
- graphs built with different local IDs but equal canonical bytes;
- topology differences that look equal after expansion;
- mapping/sequence/root order differences;
- builder lifecycle and reachability failures;
- every non-canonical varint, ID order, UTF-8, count, trailing-byte, limit, and
  mutation class;
- deterministic query order, identity, cardinality, cancellation, and limits;
- Rust/Go exact equality, hash fixtures, readable form, and PGCE bytes.

## 11. Non-goals

PortableGraph@1 is not:

- a source document or lossless syntax tree;
- a mutable object graph;
- an RDF/property graph;
- a schema or tag-constructor registry;
- a general object serializer;
- a replacement for PortableValue;
- authorization to expand aliases;
- a graph diff/patch format.

## 12. Rejected alternatives

- **Add Reference to PortableValue:** rejected because it changes PVCE/1 and
  makes every tree consumer cycle-aware.
- **Treat aliases as scalar strings:** rejected because sharing and cycles
  disappear.
- **Use builder IDs as equality:** rejected because construction order would
  leak into portable semantics.
- **Expand before encoding:** rejected because cycles do not terminate and
  alias bombs amplify work.
- **Ignore unreachable nodes:** rejected because hidden node storage would
  make equality, hashing, limits, and canonical encoding ambiguous.
- **Sort mapping entries:** rejected because ordered association identity and
  duplicates are part of Consema's strict graph value.
