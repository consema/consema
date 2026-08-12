# RFC 0011: Semantic model v6 for line-oriented formats

- Status: Implemented in Consema 0.8.0
- Date: 2026-08-04
- Scope: additive semantic-model v6 contracts for versioned source encodings,
  source snapshots/patches and materialization using Windows code pages, exact
  Java UTF-16 strings, externally located INI/Properties query results, and the
  0.8.0 public error-code registry
- Depends on: RFC 0009 and RFC 0010

## 1. Compatibility decision

Semantic model v6 is an ordered superset of v5. The v1, v2, v3, v4, and v5
contract arrays, error-code arrays, manifests, constructors, payload schemas,
and decoder behavior remain exactly frozen.

V6 adds eight registered contract/version pairs:

```text
core.ini-query-result@1
core.java-properties-query-result@1
core.java-utf16-string@1
core.materialization-request@2
core.materialization-result@2
core.source-encoding@1
core.source-patch@2
core.source-snapshot@2
```

The v6 registry therefore contains 38 records: all 30 v5 records plus these
eight. It recognizes both old and new versions of source/materialization
contracts. Registering `@2` does not reinterpret `@1`.

`core.protocol-message@1`, `core.query-definition@1`, completion, diagnostics,
reports, provenance, ChangeSet, EditPlan, and operation registries remain
unchanged. Their existing extensibility or external source identifiers are
sufficient; only payloads whose fixed schema directly embeds the old closed
encoding enumeration receive a new version.

## 2. Why source and materialization need new versions

`core.source-snapshot@1`, `core.source-patch@1`, and
`core.materialization-request@1` encode `Binary | Utf8 | Utf16Le | Utf16Be |
Latin1` as a closed string enumeration. `core.materialization-result@1` embeds
`core.source-snapshot@1`. Source v1 also implicitly detects a leading Unicode
BOM for every non-Binary request.

Adding `Windows1252` or a numeric code page to those v1 fields would make an old
decoder observe an unknown value under a schema it previously recognized. That
is a breaking reinterpretation, not an additive registry change.

V6 therefore keeps all v1 messages byte-for-byte unchanged and adds:

```text
source-encoding@1
  -> source-snapshot@2
  -> source-patch@2
  -> materialization-request@2
  -> materialization-result@2 (embeds snapshot@2)
```

Old encodings can be represented by both snapshot/patch versions, but a caller
must request one exact contract. Windows code pages require v2. No decoder
selects a version from field content.

ChangeSet and EditPlan carry source IDs, digests, ranges, replacements, and
diagnostics rather than an encoding enum; their v1 wire fields remain adequate.
Applying a patch still requires the separately versioned SourcePatch and exact
base snapshot facts.

## 3. `core.source-encoding@1`

One source encoding is encoded as:

```text
{
  schema: "core.source-encoding@1",
  kind: "Binary" | "Utf8" | "Utf16Le" | "Utf16Be" | "Latin1" |
        "WindowsCodePage",
  windows_code_page: null | unsigned-u32
}
```

`windows_code_page` is non-null if and only if `kind` is
`WindowsCodePage`. The mandatory v1 values are:

```text
874, 932, 936, 949, 950,
1250, 1251, 1252, 1253, 1254, 1255, 1256, 1257, 1258,
65001
```

The numeric value is a semantic identity, not the host active-code-page query.
Aliases such as `ANSI`, `ACP`, `GBK`, `shift_jis`, or localized display names
are rejected on the wire. Public APIs may accept aliases only by resolving them
to one registered number before the protocol object exists.

Decoder support is strict:

- invalid multibyte sequences fail rather than insert a replacement scalar;
- each decoded boundary maps to an exact raw byte range;
- code page 65001 follows strict UTF-8, not a permissive legacy decoder;
- encoding and materialization limits apply before proportional allocation.

The standalone contract can be enveloped directly and is also the exact nested
encoding record used below.

## 4. `core.source-snapshot@2`

The v2 schema keeps v1 field order and replaces only the closed encoding
record's leaf values:

```text
{
  schema: "core.source-snapshot@2",
  raw_bytes: Bytes,
  digest: lowercase-sha256,
  encoding: {
    profile_default: core.source-encoding@1,
    bom_policy: "DetectUnicode" | "TreatAsContent",
    bom: null | "Utf8" | "Utf16Le" | "Utf16Be",
    declaration: null | core.source-encoding@1,
    caller_override: null | core.source-encoding@1,
    selected: core.source-encoding@1
  },
  decoded_status: "Available" | "NotText"
}
```

The decoder rebuilds a `SourceSnapshot` from `raw_bytes`, the exact encoding
request facts, and explicit limits. It then requires:

- digest equality;
- complete equality of profile-default, BOM, declaration, caller override and
  selected encoding plus BOM policy;
- decoded-status equality;
- canonical code-page identity;
- exact raw/decoded boundary reconstruction.

`Binary` is the only `NotText` selected kind. Under `DetectUnicode`, BOMs are
compatible only with the corresponding Unicode encoding and resolution matches
the frozen v1 rule. Under `TreatAsContent`, `bom` must be null and leading
marker-shaped bytes are decoded by the selected encoding like any other bytes.
`ini.windows@1` code-page input and `java-properties.latin1@1` require
`TreatAsContent`; their UTF-16 Reader/Unicode forms use `DetectUnicode`.
Contradictory facts fail even when the raw bytes could be decoded another way.

`core.source-snapshot@1` continues to reject every new encoding kind and is not
routed through the v2 decoder. Its omitted policy remains exactly
`DetectUnicode`.

## 5. `core.source-patch@2`

V2 preserves the source-patch algebra and field order:

```text
{
  schema: "core.source-patch@2",
  base_digest: lowercase-sha256,
  target_digest: lowercase-sha256,
  encoding: EncodingFactsV2,
  replacements: [{
    old_start, old_end, original, replacement,
    redact_original, redact_replacement
  }],
  metadata: Object<String>
}
```

`EncodingFactsV2` is exactly the encoding object from snapshot v2. Replacement
ranges, byte preconditions, ordering, non-overlap, result size, redaction,
metadata, base/target digest, and apply semantics are unchanged from v1.

Applying a v2 patch requires a base snapshot whose complete encoding facts and
digest agree. Re-decoding the target under the same selected encoding must
succeed and reproduce the target digest. A patch cannot change code page or BOM
policy/facts; transcoding is materialization, not an in-place SourcePatch.

## 6. Materialization request and result v2

`core.materialization-request@2` has the same fields as v1, but its `encoding`
field is a `core.source-encoding@1` payload rather than a closed string:

```text
{
  schema: "core.materialization-request@2",
  target_profile,
  style,
  encoding: core.source-encoding@1,
  newline,
  mapping_policy,
  representability,
  limits
}
```

The existing target profile independently validates whether that encoding is
admitted. Recognition by the source registry does not imply every format can
materialize it.

`core.materialization-result@2` retains the v1 completion algebra and field
order. A Complete outcome embeds `core.source-snapshot@2`; a Failed outcome
still contains no target snapshot, bytes, or partial provenance. Existing
fidelity, report, provenance, analyzed-path, target-source binding, and range
checks remain unchanged.

V1 requests/results continue to use snapshot v1 and old encodings. No v2
wrapper may contain a snapshot v1 payload, and no v1 wrapper may contain
snapshot v2.

## 7. `core.java-utf16-string@1`

Exact Java string content is encoded as:

```text
{
  schema: "core.java-utf16-string@1",
  encoding: "UTF16BE/1",
  code_units: ["0000" .. "FFFF"],
  bytes: Bytes,
  unicode_status: "WellFormedUnicode" | "UnpairedSurrogate"
}
```

Each `code_units` item is exactly four uppercase hexadecimal digits. `bytes`
contains the same units in order, two big-endian bytes per item, with no BOM.
The decoder bounds unit and byte counts before allocation and requires:

- even byte length;
- `bytes.len == code_units.len * 2` without overflow;
- item/byte equality for every unit;
- exact recomputation of surrogate pairing and `unicode_status`;
- canonical re-encoding equality.

An empty Java string is valid. A high surrogate pairs only with the immediately
following low surrogate. Unpaired units are values, not malformed wire data.
They cannot be decoded into a PortableValue String, but the Java-string
contract itself remains valid.

Host-endian memory, WTF-8, CESU-8, replacement characters, JSON lone-surrogate
escapes, and Rust/Go process-local string representations are not accepted as
alternate encodings.

## 8. `core.ini-query-result@1`

The INI result contract follows the established external-locator pattern:

```text
{
  schema: "core.ini-query-result@1",
  domain_id: "ini.native-semantic-query" |
             "ini.lossless-syntax-query",
  domain_version: 1,
  role: IniRole,
  matches: [{ source_id, node_locator, role, ordinal }],
  completion: core.completion@1,
  diagnostics: [core.diagnostic@1]
}
```

`IniRole` is exactly:

```text
IniDocument
IniPhysicalLine
IniLogicalLine
IniSection
IniDefaultSection
IniEntry
IniErrorLine
IniSyntaxPiece
```

Native roles are admitted only by the native domain; `IniSyntaxPiece` only by
the lossless domain. Every match has non-empty bounded source/locator IDs, the
uniform declared role, and a strictly increasing result ordinal. Completion's
produced count equals `matches.len`. Diagnostics validate under the selected
v6 error registry.

The result does not externalize process-local profile collation objects or
`NodeRef`. Original/profile-equivalent name mode remains in the QueryDefinition
that produced the result.

## 9. `core.java-properties-query-result@1`

Properties query results have the same envelope shape:

```text
{
  schema: "core.java-properties-query-result@1",
  domain_id: "java-properties.native-semantic-query" |
             "java-properties.lossless-syntax-query",
  domain_version: 1,
  role: PropertiesRole,
  matches: [{ source_id, node_locator, role, ordinal }],
  completion: core.completion@1,
  diagnostics: [core.diagnostic@1]
}
```

`PropertiesRole` is exactly:

```text
PropertiesDocument
PropertiesNaturalLine
PropertiesLogicalLine
PropertiesProperty
PropertiesComment
PropertiesEscape
PropertiesErrorLine
PropertiesSyntaxPiece
```

Domain/role, ID, ordinal, completion-count, diagnostics, limits, and
process-local rejection rules match the INI contract. Exact UTF-16 filters are
part of QueryDefinition operator arguments using the nested
`core.java-utf16-string@1` schema. Query results carry stable locators rather
than duplicating native key/value content.

## 10. V6 error-code additions

V6 adds exactly 34 sorted codes to v5's 132, producing 166 total:

```text
core.source.code-page-required@1
core.source.unsupported-code-page@1

ini.edit.canonical-fallback@1
ini.edit.case-collision@1
ini.edit.invalid-name@1
ini.edit.invalid-placement@1
ini.formation.case-collision@1
ini.formation.duplicate-entry@1
ini.formation.duplicate-section@1
ini.materialization.round-trip-mismatch@1
ini.parse.invalid-character@1
ini.parse.invalid-continuation@1
ini.parse.malformed-line@1
ini.parse.malformed-section@1
ini.parse.missing-delimiter@1
ini.parse.missing-section@1
ini.profile.encoding@1
ini.profile.mismatch@1
ini.projection.collision@1
ini.projection.duplicate-collapsed@1
ini.projection.incomplete-document@1
ini.query.invalid-name-mode@1

java-properties.edit.canonical-fallback@1
java-properties.edit.invalid-placement@1
java-properties.java-string.invalid-wire@1
java-properties.java-string.non-canonical-wire@1
java-properties.materialization.round-trip-mismatch@1
java-properties.parse.malformed-unicode-escape@1
java-properties.profile.mismatch@1
java-properties.projection.duplicate-collapsed@1
java-properties.projection.incomplete-document@1
java-properties.projection.unpaired-surrogate@1
java-properties.query.invalid-code-unit-filter@1
java-properties.source.profile-encoding@1
```

Existing common codes remain authoritative for generic source invalid
sequences, source/parse/query/projection/materialization/edit resource limits,
unsupported materialization encoding, wrong snapshot/role, conflicts, and
protocol schema failures. Format code does not duplicate them under a new name.

Every internal INI/Properties/source failure maps exhaustively to either one of
the 34 additions or an existing common code. Rust `Debug`/`Display`, JDK
exception text, Windows error strings, and backend-library variants never
become public diagnostics.

V1-v5 registries must retain exact old arrays and counts. Old registries reject
all new codes even when a payload schema otherwise appears valid.

## 11. Protocol dispatch and audit exclusions

Payload dispatch keys on the exact `(contract.id, contract.version)` pair.
Dispatching only by ID would allow a v1 envelope to reach a v2 decoder or vice
versa and is forbidden.

Protocol externalization never includes:

- `SourceSnapshot` references, decoder state, host active code page, locale, or
  filesystem paths;
- INI/Properties `NodeRef`, parser cursor, borrowed source slices, Rust enum
  discriminants, or object addresses;
- host-endian Java UTF-16 memory or invalid UTF-8;
- Python interpolation/default state, .NET provider state, Windows registry
  mappings, Java `Properties` defaults/Hashtable state, or environment values;
- partially decoded source, partial query prefixes marked Complete, partial
  materialization bytes, or partial patches.

All new payloads use exact field order, unknown-field rejection, unsigned
bounded integers, canonical JSON/PVCE transport, and proportional allocation
checks.

## 12. Required conformance

The semantic-model v6 suite must prove at least:

1. v1-v5 contract/error arrays, manifests, constructors, counts, and frozen
   payload byte vectors are unchanged;
2. v6 has exactly 38 contracts and 166 error codes in strict sorted order;
3. all eight new contract/version pairs round-trip through canonical JSON and
   PVCE in `core.protocol-message@1`;
4. old registries reject every new contract and diagnostic code;
5. source encoding accepts every mandatory code page, rejects all other
   numbers/aliases, distinguishes both BOM policies, and rejects nullability
   contradictions;
6. snapshot v2 re-verifies digest, encoding resolution, BOM, decoded status,
   code-page sequences, and boundaries;
7. patch v2 rejects wrong base encoding/digest/original bytes, overlap,
   noncanonical metadata and target decoding/digest mismatch;
8. materialization request/result v2 reject mixed nested contract versions and
   preserve all existing completion/provenance invariants;
9. every Java UTF-16 edge case, including empty, BMP, supplementary, leading,
   trailing and adjacent unpaired surrogates, is byte/code-unit/status exact;
10. INI and Properties query domain/role matrices, ordinals, completion counts,
    diagnostics, limits, and raw-handle rejection are exhaustive;
11. all 34 new error codes are reachable from their promised public failure or
    explicitly classified as protocol validation codes. Classification:
    `core.source.code-page-required@1`/`core.source.unsupported-code-page@1`
    fire from `core.source-encoding@1` typed decoding;
    `java-properties.java-string.invalid-wire@1`/`non-canonical-wire@1` fire
    from `core.java-utf16-string@1` typed decoding (structure vs canonical
    re-verification). The remaining seven are format query/materialization
    refinement codes — `ini.query.invalid-name-mode@1`,
    `java-properties.query.invalid-code-unit-filter@1`,
    `ini.profile.mismatch@1`, `java-properties.profile.mismatch@1`,
    `ini.projection.duplicate-collapsed@1`,
    `ini.materialization.round-trip-mismatch@1`,
    `java-properties.materialization.round-trip-mismatch@1` — classified as
    reserved refinement slots: the v6 typed decoders currently surface their
    failures through the registered generic codes
    (`core.query.invalid-argument@1` for query parameters,
    `core.materialization.invalid-request@1` for profile/round-trip checks),
    and the refinement codes are reserved for the format-specific protocol
    messages that will carry those failures verbatim;
12. unknown/missing/reordered fields, unknown enums, integer boundaries,
    mutated bytes, noncanonical transports, and resource limits fail without a
    partial object.

The language-neutral vector suite records exact schema IDs, registry versions,
canonical transport bytes, source/code-page facts, Java code units, result
roles, stable diagnostics, and expected rejection paths. Rust and future Go
implementations consume the same vectors.

## 13. Rejected alternatives

### Extend the v1 encoding string enum

Rejected because old decoders recognize the enclosing schema but cannot
interpret the new value. Contract versioning exists precisely to prevent this
reinterpretation.

### Add only `source-snapshot@2`

Rejected because patches, materialization requests, and successful
materialization results directly carry the same closed encoding facts. Leaving
them at v1 would make new Profile operations non-transferable or contradictory.

### Put code-page names in arbitrary strings

Rejected because aliases and host libraries differ. A bounded numeric registry
gives Rust and Go one language-neutral identity and one negative-test surface.

### Encode Java strings as JSON strings

Rejected because JSON transport and PortableValue String require valid Unicode
scalar content while Java strings may contain unpaired UTF-16 surrogates.

### Reuse `core.query-result@1`

Rejected because its frozen role set deliberately excludes format-native INI,
Properties, and syntax roles. Adding roles under the old schema would break the
v1 decoder just as changing the encoding enum would.

### One generic line-format query result

Rejected because INI and Properties role sets and native identities are
different. Similar locator envelopes do not justify erasing domain/role
validation.
