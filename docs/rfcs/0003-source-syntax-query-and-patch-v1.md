# RFC 0003: Raw source, syntax query, and SourcePatch v1

- Status: Implemented in Consema 0.4.0
- Date: 2026-08-04
- Scope: raw source facts, decoded locations, binary regions, lossless syntax query, cursor completion, and byte patches

## 1. Decision

Consema 0.4.0 separates five facts that UTF-8-only prototypes often conflate:

```text
raw source bytes                    immutable content fact
content digest                      stable cross-process content identity
SnapshotIdentity                    fresh process-local document identity
decoded text and derived offsets    result of explicit encoding resolution
Span                                half-open range in original raw bytes
```

It also freezes two new wire payloads, `core.source-snapshot@1` and
`core.source-patch@1`, two format-specific syntax-query domains, and a
process-local cursor terminal contract. No part of this RFC introduces a
universal configuration CST or semantic diff.

## 2. Compatibility and registry versioning

The Consema 0.3 registries remain immutable:

- `ContractRegistry::v1()` continues to contain exactly its 15 stable payload
  contracts plus the transport envelope;
- `ErrorCodeRegistry::v1()` continues to contain exactly its 55 codes;
- `core.semantic-model@1` continues to identify that exact contract set.

Consema 0.4 publishes `core.semantic-model@2`. `ContractRegistry::v2()` is the
ordered superset of v1 plus:

```text
core.source-patch@1
core.source-snapshot@1
```

`core.registry-manifest@1` remains the manifest data schema; a v2 manifest
names `core.semantic-model@2` and the exact v2 registries. Adding a contract
does not retroactively change the v1 manifest.

## 3. Content identity and snapshot identity

The v1 content digest is SHA-256 over the complete original byte sequence,
with no decoding, BOM removal, newline normalization, or metadata mixed into
the input. Its language-neutral form is:

```text
algorithm                   exactly "sha256"
hex                         exactly 64 lowercase hexadecimal characters
```

Equal raw bytes always produce equal content digests across processes and
languages. A digest mismatch proves different bytes. Digest equality is not a
claim about Profile, encoding, native meaning, or document identity.

`SnapshotIdentity` remains a fresh opaque process-local identity for every
formed Document. Parsing the same bytes twice produces equal content digests
and distinct snapshot identities. `SnapshotIdentity` is never serialized.

## 4. Encoding facts

### 4.1 Closed v1 encoding IDs

```text
Binary
Utf8
Utf16Le
Utf16Be
Latin1
```

`Latin1` means ISO-8859-1 byte-to-U+0000..U+00FF decoding. It is not Windows-
1252. `Binary` has no decoded text or decoded coordinate map.

### 4.2 Resolution inputs

Encoding resolution records:

```text
profile_default             required encoding ID
bom                         Null | Utf8 | Utf16Le | Utf16Be
declaration                 Null | encoding ID
caller_override             Null | encoding ID
selected                    resolved encoding ID
```

The BOM is detected from raw bytes. UTF-32 BOMs are explicitly unsupported in
v1. Caller and declaration inputs are already normalized encoding IDs; label
alias parsing belongs to the declaring format Profile.

The selected encoding is the first present value in this priority order:

```text
caller_override -> declaration -> bom -> profile_default
```

Priority chooses only when higher evidence is absent. Any two present BOM,
declaration, and caller facts that disagree produce `EncodingConflict`; the
resolver never guesses or silently lets priority hide a contradiction. A
Profile may subsequently reject a resolved encoding it does not support.

For `Binary`, BOM detection and text decoding do not run, and declaration or
caller text encodings are invalid.

### 4.3 Decoding

Decoding must reject:

- invalid UTF-8;
- odd-length UTF-16;
- isolated or reversed UTF-16 surrogates;
- decoded-size or location-count resource overflow;
- unsupported BOMs or contradictory facts.

The original BOM bytes remain part of the raw source and digest. In the
decoded view a recognized text BOM is retained as leading U+FEFF, so every raw
byte remains attributable and the selected Profile decides whether that
marker is trivia, permitted, diagnosed, or rejected.

## 5. Raw spans and decoded locations

`Span` remains `[start_byte, end_byte)` over original raw bytes. Its offsets do
not become UTF-8 indices after decoding UTF-16 or Latin-1.

A decoded boundary is a derived tuple:

```text
raw_byte
decoded_utf8_byte
unicode_scalar_offset
utf16_code_unit_offset
```

Only scalar boundaries are addressable. A raw offset inside a UTF-8 scalar or
between a UTF-16 surrogate pair is rejected rather than rounded. Conversion
uses checked arithmetic and has explicit resource limits. Binary snapshots
have no decoded boundaries.

## 6. `core.source-snapshot@1`

Exact fields:

```text
schema                      exactly core.source-snapshot@1
raw_bytes                   Bytes
digest                      digest record
encoding                    encoding-facts record
decoded_status              Available | NotText
```

The decoder recomputes the digest, reruns encoding resolution and decoding,
and requires exact equality with all encoded facts. A peer cannot claim a
digest or encoding result that the raw bytes do not produce.

This payload is a complete immutable content fact, not a file path, URI,
loader, owner, permission record, or live buffer.

## 7. Text and binary structural coverage

Text Documents retain exhaustive ordered Token/Trivia/ErrorRegion coverage.
Binary Documents use `BinaryStructuralIndex` and format-owned region kinds.
A binary region has a snapshot-bound raw Span, a process-local NodeRef, and a
non-empty stable format-owned region kind.

Binary coverage obeys the same no-gap/no-overlap/final-length invariant but
does not call bytes tokens or trivia. Empty source has an empty valid index;
non-empty source requires at least one non-empty region.

## 8. Lossless Syntax Query v1

Syntax Query remains format-specific. Consema 0.4 freezes:

```text
json.lossless-syntax-query@1
toml.lossless-syntax-query@1
```

The standard input sequence is every lossless syntax piece in raw source
order. Matches are snapshot-bound and use separate roles:

```text
JsonSyntaxPiece
TomlSyntaxPiece
```

Each match carries its NodeRef, raw Span, format-specific kind, and source
ordinal. It does not carry a parser AST pointer.

### 8.1 JSON syntax kinds and operators

Kinds:

```text
Bom Whitespace LineComment BlockComment
LeftBrace RightBrace LeftBracket RightBracket Colon Comma
String Number True False Null ErrorRegion
```

Operators:

```text
json.syntax-kind-is@1       { kind: String }
json.syntax-text-equals@1   { text: String }
```

### 8.2 TOML syntax kinds and operators

Kinds:

```text
Whitespace Newline Comment String Bare
Equals LeftBracket RightBracket LeftBrace RightBrace Comma Dot
```

Operators:

```text
toml.syntax-kind-is@1       { kind: String }
toml.syntax-text-equals@1   { text: String }
```

Kind names and argument types are validated before the first match. The common
`core.take@1` and `core.distinct-by-identity@1` operators, QuerySelection,
resource limits, cancellation, Concat and StructureOrderMerge retain their
existing semantics.

The format query implementations may share traversal machinery, but JSON and
TOML kind enums and public match types remain distinct.

## 9. Process-local cursor completion

An ordered cursor has one declared final terminal state:

```text
Completed
Cancelled
Failed
```

The state becomes observable only after all locally discovered items have
been consumed. `Completed` alone proves the complete standard result sequence.
Cancelled or failed cursors may expose prior local discoveries but cannot be
promoted to a complete query result. Cursors remain process-local; only an
explicit `core.query-result@1` message crosses the wire.

## 10. `core.source-patch@1`

Exact fields:

```text
schema                      exactly core.source-patch@1
base_digest                 digest record
target_digest               digest record
encoding                    encoding-facts record
replacements                ordered Sequence<replacement>
metadata                    Object<String, String>
```

Each replacement has exact fields:

```text
old_start                   non-negative Integer
old_end                     non-negative Integer
original                    Bytes
replacement                 Bytes
redact_original             Boolean
redact_replacement          Boolean
```

Rules:

- old ranges are half-open, ordered, and non-overlapping;
- `original` exactly equals the base bytes in its range;
- zero-width insertions are permitted, but two replacements may not target the
  same insertion point;
- applying uses the current raw bytes, never decoded character offsets;
- base digest, encoding facts, every original-byte precondition, and computed
  target digest must match;
- any mismatch fails atomically and returns no new SourceSnapshot;
- successful application reruns encoding resolution and requires the resulting
  encoding facts to equal the patch facts;
- metadata is deterministic audit data and cannot affect application;
- redaction flags control review/log presentation, not the bytes required for
  application.

SourcePatch is not ChangeSet, semantic diff, merge, fuzzy patch, file-system
write, or permission to alter a stale snapshot.

## 11. Stable 0.4 source codes

`ErrorCodeRegistry::v2()` extends v1 with:

```text
core.source.encoding-conflict@1
core.source.invalid-sequence@1
core.source.patch-base-mismatch@1
core.source.patch-original-mismatch@1
core.source.patch-target-mismatch@1
core.source.resource-limit@1
core.source.unsupported-bom@1
```

Protocol schema defects still use the existing `core.protocol.*@1` rejection
codes. Source operation codes describe content construction or patch
application outcomes, not wire syntax.

## 12. Resource behavior

Source limits cover raw bytes, decoded UTF-8 bytes, decoded boundary count and
patch replacement count/bytes. Limits apply before or during allocation.
Digest computation is linear in raw bytes. Offset mapping is built in one
checked pass and queried by binary search. A limit failure returns no partial
snapshot, mapping, or patch result.

## 13. Conformance gates

Consema 0.4 must prove:

- SHA-256 known vectors and equal-byte/different-snapshot identity behavior;
- UTF-8, UTF-16LE, UTF-16BE, Latin-1 and Binary exact raw round-trip;
- BOM/declaration/caller conflict matrices and invalid UTF-16 cases;
- raw/UTF-8/scalar/UTF-16 boundary conversions without rounding;
- empty and non-empty binary region exact coverage;
- JSON and TOML syntax kind, text, ordering, selection, limit and cancellation
  behavior through shared language-neutral vectors;
- completed/cancelled/failed cursor terminal behavior;
- SourceSnapshot and SourcePatch JSON/PVCE equivalence under semantic model v2;
- SourcePatch stale digest, original mismatch, encoding change, overlap,
  target mismatch and successful atomic application;
- malicious size, offset, count and decoding inputs fail within limits.

Go must later implement the same facts independently and consume the same
vectors. It may not reuse Rust digest, decoder, syntax matcher, or patch code
through FFI.

## 14. Explicit non-goals

- XML declaration parsing, Properties label aliases, or Profile-specific
  encoding acceptance; those belong to their format milestones;
- UTF-32, Shift-JIS, GB18030 or arbitrary platform encodings in v1;
- line/column policy, grapheme indexing, normalization, or case folding;
- a universal CST, universal token enum, syntax rewrite language, formatter,
  semantic diff, merge, or fuzzy patch;
- file loading, file locking, temporary writes, fsync, atomic rename,
  permissions, symlinks, ownership, or recovery manifests;
- structural edit and materialization, which begin in 0.5.0.
