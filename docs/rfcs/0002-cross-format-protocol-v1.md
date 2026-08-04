# RFC 0002: Cross-format protocol v1

- Status: Accepted for Consema 0.3.0 implementation
- Date: 2026-08-04
- Scope: language-neutral protocol objects shared by every format family

## 1. Decision

Consema 0.3.0 freezes a protocol contract set whose semantic carrier is
`PortableValue v1`. Every message has exactly one typed payload, and that same
payload has two normative encodings:

```text
typed protocol object
  -> fixed-field PortableValue schema
      |- canonical PVCE/1
      `- canonical core.portable-value-json@1
```

Host-language object serialization, Rust enum variant names, parser ASTs,
error display strings and memory addresses are not protocol formats.

The common envelope is `core.protocol-message@1`, with fields in this exact
order:

| Field | Type | Rule |
|---|---|---|
| `schema` | String | exactly `core.protocol-message@1` |
| `contract_id` | String | stable namespaced identifier |
| `contract_version` | non-negative Integer | unsigned 32-bit, non-zero |
| `payload` | Object | exact schema selected by ID and version |

Unknown contracts, fields, enum values and non-canonical encodings are errors.
No decoder silently preserves unknown data unless a schema explicitly defines
a namespaced extension map. None of the v1 schemas below has such a map.

## 2. Goals

- close the cross-language wire boundary before a third format adds more cases;
- give Profile, Capability, Diagnostic, Query, Projection, Provenance, ChangeSet,
  resource, cancellation and completion facts stable schemas;
- make JSON and PVCE representations semantically identical;
- make every rejection machine-readable and deterministic;
- state which identities are transferable and which are process-local;
- preserve all frozen PVCE/1 bytes and `core.query-definition@1` behavior.

## 3. Non-goals

- a third-party plugin transport, RPC session, framing or authentication layer;
- persistence of an implementation's arena index or raw `NodeRef`;
- live cursor resumption across processes;
- SourceSnapshot digest and encoding contracts, which belong to 0.4.0;
- a schema language or schema inference system;
- changing any PortableValue or PVCE/1 semantic.

## 4. Identifier and scalar rules

A protocol identifier is lowercase ASCII segments separated by dots. A segment
starts with `a-z` and then contains `a-z`, `0-9` or `-`. It contains at least
one dot, has no empty segment and is at most 255 UTF-8 bytes. Contract versions
are integers in `1..=u32::MAX`.

Byte offsets and counts are non-negative arbitrary-precision Integer values at
the schema level. Implementations may reject values outside their declared
resource policy before converting them to host indices.

Objects use their declared field order. Reordered fields are non-canonical,
even if a host JSON library would normally treat object order as irrelevant.

## 5. Canonical PortableValue JSON

`core.portable-value-json@1` is a canonical, tagged JSON representation of the
closed PortableValue tree. The root has exact fields `schema`, `value`.
Whitespace outside strings is absent. Object field order is fixed. Strings use
the shortest required JSON escaping: quotation mark, reverse solidus and C0
controls are escaped; all other Unicode scalar values are emitted as UTF-8.
Hexadecimal is lowercase and fixed-width where stated.

Every encoded value is an object whose first field is `type`:

| PortableValue | Remaining exact fields |
|---|---|
| Null | none |
| Boolean | `value: Boolean` |
| Integer | `value: canonical base-10 String` |
| Decimal | `coefficient: Integer String`, `exponent: Integer String` |
| BinaryFloat32 | `bits: 8-lowercase-hex String` |
| BinaryFloat64 | `bits: 16-lowercase-hex String` |
| String | `value: String` |
| Bytes | `hex: even-length lowercase-hex String` |
| Date | `year: Integer String`, `month: Integer String`, `day: Integer String` |
| Time | `hour`, `minute`, `second` as Integer String; `fraction` as encoded Decimal |
| LocalDateTime | `date: encoded Date`, `time: encoded Time` |
| OffsetDateTime | `local: encoded LocalDateTime`, `offset_seconds: Integer String` |
| Sequence | `items: Array<encoded value>` |
| Object | `entries: Array<{key: String, value: encoded value}>` |
| EntryMapping | `entries: Array<{key: encoded value, value: encoded value}>` |

The `type` values are the exact PortableValue kind names. Object entries remain
ordered and unique; EntryMapping entries remain ordered and may repeat.

Decoding performs parse, type/range/resource validation and canonical
re-encoding comparison. Thus whitespace, alternate escapes, uppercase hex,
leading-zero integers, reordered fields and alternate but equal decimal forms
are rejected as non-canonical instead of normalized silently.

## 6. Registry schemas

### 6.1 `core.profile-descriptor@1`

Exact fields:

```text
schema
format_family_id
format_family_version
profile_id
profile_version
base_profile              Null | { id, version }
differences               Sequence<String>
required_capabilities     Sequence<{ id, version }>
```

Differences are stable identifiers, not localized prose.

### 6.2 `core.capability-declaration@1`

Exact fields:

```text
schema
capability_id
capability_version
support                   Conformant | Conditional | Unsupported
preconditions             Object<String, String>
verification              Verified | SelfDeclared | Unverified
suite_id                   Null | String
```

`Conditional` requires at least one precondition. The other support states
require an empty precondition Object. `Verified` requires `suite_id`; other
verification states require Null.

### 6.3 `core.registry-manifest@1`

Exact fields `schema`, `semantic_model`, `contracts`, `error_codes`. Contract
and error-code entries are ordered by `(id, version)`, unique, and contain a
stability classification. A manifest is evidence of the contracts an
implementation recognizes; it is not evidence that every capability is
conformant.

## 7. Diagnostic protocol

`core.diagnostic@1` exact fields:

```text
schema
code
category
severity
primary                   Null | source location
related                   Sequence<{ role, location }>
arguments                 Object<String, String>
notes                     Sequence<String>
fixes                     Sequence<fix proposal>
occurrence                non-negative Integer
```

A transferable source location is `{source_id, start_byte, end_byte}`.
`source_id` is a caller-assigned stable identifier; it is not a process-local
snapshot integer. A fix proposal carries an ID, applicability, optional source
location and exact replacement Bytes. Fixes are proposals, never implicit
writes.

Categories and severities are closed v1 registries matching the semantic
baseline. Diagnostic order remains source/phase/code/occurrence order. A limit
must add the registered truncation diagnostic; it may not silently drop the
tail.

## 8. Query protocol

The existing `core.query-definition@1` field order and spellings are frozen.
Its PortableValue bytes remain unchanged.

`core.query-result@1` exact fields:

```text
schema
domain_id
domain_version
role
matches                   Sequence<match>
completion                core.completion@1 payload
diagnostics               Sequence<core.diagnostic@1 payload>
```

Portable domain matches encode complete `ValuePath` or
`AssociationLocation` plus the observed immutable PortableValue. Native
matches require a caller-supplied transferable locator. A raw `NodeRef` cannot
be encoded. A result with no locator fails encoding with
`core.protocol.process-local-handle@1`.

An ordered cursor is not a message. Only an exhausted cursor with terminal
state `Completed` can be promoted to a complete result. Cancelled or failed
cursors use their respective completion status and cannot claim a complete
standard result sequence.

## 9. Projection protocol

### 9.1 `core.projection-request@1`

Exact fields:

```text
schema
target                    { id, version }
default_policy            { id, version, arguments }
rules                     Sequence<rule>
limits                    Object<String, non-negative Integer>
```

A rule has exact fields `rule_id`, `scope`, `priority`, `policy`. Transferable
scope kinds are `Global`, `ExactNativePath`, `ResolvedQuery`. `ExactNodeRef` is
process-local and must first be externalized as an exact native path or stable
caller locator. Rule declaration order is preserved for audit but never breaks
semantic ties; an unresolved same-priority conflict invalidates the request.

### 9.2 `core.projection-result@1`

Exact fields:

```text
schema
completion
value                     Null | PortableValue
fidelity                  Null | Exact | Transformed | Lossy
report                    core.projection-report@1 payload
provenance                core.provenance-map@1 payload
diagnostics               Sequence<core.diagnostic@1 payload>
```

Only `Success` permits a non-Null value and fidelity. Every other state requires
Null value and fidelity. There is never a partial PortableValue.

Projection report events have exact fields `code`, `policy_rule_id`,
`source_locations`, `projected_location`, `old_category`, `new_category`,
`reversible`, `loss_classification`, `arguments`. The event code registry
includes all baseline event kinds; a format may add namespaced codes only in a
new declared contract version.

### 9.3 `core.provenance-map@1`

Entries are ordered by projected location. A projected location is a
ValuePath or AssociationLocation. A source origin contains `source_id`, an
optional caller-supplied `node_locator`, byte range and relation. Relations are
`Direct`, `Derived`, `Expanded`, `Merged`, `Generated`.

Raw snapshot identity, raw `NodeRef` and `Span.snapshot` are process-local.
Adapting them to wire requires an explicit source binding. The adapter must
fail rather than omit an identity-bearing fact.

## 10. ChangeSet protocol

`core.change-set@1` exact fields:

```text
schema
old_source_id
new_source_id
source_edits               ordered sequence
node_mappings              ordered sequence
diagnostics                ordered sequence
```

A source edit has exact fields `old_start`, `old_end`, `new_start`, `new_end`,
`replacement`. Replacement is Bytes. Ranges are half-open, ordered and
non-overlapping in old-source order.

A node mapping uses caller-supplied old/new locator strings, status and an
optional stable reason code. Status is `Preserved`, `Replaced`, `Deleted`,
`Split`, `Merged`, `Unmapped`. Raw `NodeRef` values never cross the wire.

## 11. Resource, cancellation and completion

`core.execution-policy@1` exact fields `schema`, `limits`,
`cancellation_request_id`. Limits are a unique-key Object of non-negative
Integer values. Unknown limit names are rejected by the selected operation
contract. The optional cancellation request ID coordinates an outer transport;
it is not a serialized `CancellationToken`.

`core.cancellation-request@1` exact fields `schema`, `request_id`, `reason`.
It is idempotent at the transport boundary. The process-local implementation
maps it to its own cooperative cancellation primitive.

`core.completion@1` exact fields:

```text
schema
status                     Success | Failed | Cancelled | ResourceLimited |
                           Unsupported | NotApplicable
processed                  non-negative Integer
produced                   non-negative Integer
limit_name                 Null | String
failure_code               Null | registered code
```

`ResourceLimited` requires `limit_name`. `Failed`, `Unsupported` and
`NotApplicable` require `failure_code`. Success and Cancelled require both to
be Null. Completion is control flow; Diagnostic severity cannot derive it.

## 12. Error code registry

`core.error-code-registry@1` is published as language-neutral data. Every entry
contains exact fields `code`, `category`, `introduced`, `stability`,
`description`. Codes are unique and sorted. Public code removal or semantic
reuse requires a new major contract; display text can evolve.

The protocol decoder's closed v1 rejection codes are:

```text
core.protocol.invalid-json@1
core.protocol.non-canonical-json@1
core.protocol.invalid-pvce@1
core.protocol.unknown-contract@1
core.protocol.schema-mismatch@1
core.protocol.unknown-field@1
core.protocol.missing-field@1
core.protocol.wrong-type@1
core.protocol.invalid-value@1
core.protocol.resource-limit@1
core.protocol.process-local-handle@1
```

The same structural defect maps to the same code whether it arrived through
JSON or PVCE, after transport-specific syntax/canonical checks have passed.

## 13. Resource behavior

Protocol decode limits cover input bytes, nesting, total nodes, container
entries, String/Bytes bytes and diagnostics. Limits apply before or during
allocation. Exceeding one yields `core.protocol.resource-limit@1`; no truncated
message is returned. Recursive schema decoders are bounded independently from
the source JSON parser and PVCE decoder.

## 14. Conformance

The 0.3.0 gate must prove:

- every PortableValue kind has one JSON byte vector and the existing PVCE/1
  round-trip remains unchanged;
- every protocol schema has JSON/PVCE equivalent vectors;
- unknown/reordered/missing fields, unknown contracts and non-canonical JSON or
  PVCE fail with registered codes;
- conditional capability invariants and completion-state invariants reject
  contradictory messages;
- process-local identities cannot be serialized accidentally;
- malicious depth/count/size inputs fail within declared limits;
- registry and error-code data are sorted, unique and fully recognized by the
  Rust implementation.

Go must implement these schemas independently after the Rust feature-complete
gate; it may consume the same vectors but may not call Rust through FFI.
