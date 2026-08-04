# RFC 0005: JSON family production profile and JSON5 v1

- Status: Accepted for Consema 0.6.0 implementation
- Date: 2026-08-04
- Scope: frozen JSON5 formation/native semantics, versioned JSON query domains,
  exact projection, canonical materialization, dialect conversion, structural
  edit completion, protocol registry v4, and production evidence
- External standards: [Standard JSON5 1.0.0](https://spec.json5.org/) and the
  pinned [JSON5 2.2.3 reference implementation](https://github.com/json5/json5/tree/v2.2.3)

## 1. Decision

Consema 0.6.0 completes the Rust JSON family matrix without turning profile
selection into a permissive-mode Boolean:

```text
json.strict@1       exact RFC-style JSON baseline
jsonc.bounded@1     bounded comments/trailing commas over JSON semantics
json5.standard@1    Standard JSON5 1.0.0 lexical and syntactic surface
```

All three profiles share immutable document, native object/member/array
identity, transaction, proof, and patch infrastructure. They do not share one
set of accepted tokens, whitespace, string escapes, number literals, query
domain versions, or generation styles.

The existing `json.strict@1`, `jsonc.bounded@1`, query-domain v1, projection,
materialization, operation, diagnostic, and semantic-model v1-v3 behavior
remains frozen.

## 2. Profile and source contract

`json5.standard@1`:

- accepts UTF-8 source only at the format entry point;
- retains exact source bytes, token/trivia/error-region coverage, byte spans,
  member/element identity, comments, comma placement, quote choice, identifier
  spelling, escape spelling, and number spelling;
- uses the same `Complete | Recovered` formation algebra as the existing JSON
  family parser; source/encoding and configured resource failures remain fatal;
- accepts exactly the Standard JSON5 1.0.0 grammar plus Consema resource
  bounds, not JavaScript expressions, object literals, functions, `undefined`,
  bigint, octal, binary numbers, elisions, or multiple root values;
- emits deterministic diagnostics and never turns recovered syntax into
  available native semantics.

A valid strict JSON document is valid under JSON5. Every Complete
`jsonc.bounded@1` document is also valid under this JSON5 profile; recovered
JSONC structure is not promoted to valid JSON5.

## 3. JSON5 whitespace and comments

JSON5 whitespace is the exact union of:

```text
U+0009 U+000A U+000B U+000C U+000D U+0020 U+00A0 U+1680
U+2000..U+200A U+2028 U+2029 U+202F U+205F U+3000 U+FEFF
```

This is encoded explicitly rather than delegated to a host `is_whitespace`
predicate, which can accept characters outside the profile.

Line comments terminate at LF, CR, U+2028, U+2029, or end of source. Block
comments do not nest and must close. Comments remain `LineComment` or
`BlockComment` trivia and are never attached to a fabricated universal AST.
A leading UTF-8 BOM remains a distinct `Bom` piece; an interior U+FEFF is
JSON5 whitespace.

## 4. IdentifierName member keys

JSON5 unquoted member names follow ECMAScript IdentifierName semantics:

- start: `$`, `_`, or Unicode `ID_Start`;
- continue: start characters, Unicode `ID_Continue`, U+200C, or U+200D;
- `\uXXXX` escapes are accepted only when the decoded character satisfies the
  position's start/continue rule;
- reserved words such as `while`, and literal-looking names such as `true`,
  are valid member names;
- malformed escapes, isolated surrogates, and disallowed characters are
  recovered as explicit error regions and do not acquire a decoded name.

Consema pins `unicode-id-start = 1.4.0` (Unicode 17.0.0) for the generated
Unicode ID tables. Updating that table is a separately reviewed profile
compatibility event. The dependency's Unicode-3.0 data license is recorded in
the supply-chain policy.

`JsonSyntaxKind::Identifier` is added for the new v2 lossless domain. Quoted
keys remain `String`. In the native view both become a decoded String member
name while retaining distinct source nodes and literal spans.

## 5. JSON5 strings

Both single- and double-quoted strings are accepted. The opening quote fixes
the closing quote. The decoder supports:

```text
\' \" \\ \b \f \n \r \t \v \0
\xHH \uHHHH
backslash + LF | CR | CRLF | U+2028 | U+2029 line continuation
identity escape for any other non-decimal character
```

`\0` followed by an ASCII decimal digit is invalid. `\1` through `\9` are
invalid. UTF-16 surrogate pairs in consecutive `\u` escapes form one Unicode
scalar; isolated surrogates fail local semantic decoding. Unescaped U+0000
through U+001F are invalid. Unescaped U+2028/U+2029 are accepted as required by
JSON5 but emit `json5.string.unescaped-line-separator@1`; canonical generation
escapes them.

`PreserveCompatible` scalar edit retains quote choice and compatible escape
choices, including `\x`, `\v`, `\0`, and line-independent identity escapes.
It never recreates a line continuation because that is source layout rather
than a value character. Canonical fallback uses deterministic double quotes.

## 6. JSON5 numbers and exact native categories

Accepted forms are:

- decimal integers with optional `+` or `-`;
- decimal fractions with leading or trailing decimal point;
- decimal exponent forms;
- hexadecimal integers with `0x`/`0X` and optional sign;
- `Infinity`, `+Infinity`, `-Infinity`;
- `NaN`, `+NaN`, `-NaN`.

Octal/binary prefixes, numeric separators, leading-zero decimal integers,
empty exponent/hex digit sequences, and signed literal names other than
Infinity/NaN are invalid.

Finite integer and decimal values remain arbitrary-precision `BigInteger` and
exact `Decimal`; parsing does not silently round through the host `f64`.
Hexadecimal integers are converted exactly. Non-finite values use
`BinaryFloat64` with frozen bits:

```text
+Infinity / Infinity  0x7ff0000000000000
-Infinity             0xfff0000000000000
NaN / +NaN            0x7ff8000000000000
-NaN                   0xfff8000000000000
```

`JsonValueKind::BinaryFloat64` and `JsonValue::as_binary_float64` expose the
new native category. No finite JSON5 spelling becomes a BinaryFloat64, and no
NaN payload is invented from syntax that cannot express one.

`PreserveCompatible` retains compatible hexadecimal case/prefix, explicit
plus, leading/trailing decimal-point category, exponent marker/sign, and
non-finite sign category. If exact preservation is impossible it fails or,
under `PreserveElseCanonical`, emits the existing explicit fallback event.

## 7. Versioned query domains

The v1 domains remain exact and are not valid for a JSON5 document:

```text
json.native-semantic-query@1
json.lossless-syntax-query@1
```

Consema 0.6 adds:

```text
json.native-semantic-query@2
json.lossless-syntax-query@2
```

Domain v2 keeps the existing operator IDs/version 1, ordering, selection,
limits, cancellation, and match roles. It extends the permitted native kind
set with `BinaryFloat64` and the syntax kind set with `Identifier`. Strict
JSON and JSONC documents may execute either v1 or v2 because their produced
kind sets are within v1; JSON5 requires v2. Binding validates the domain/kind
combination before producing the first match.

## 8. Projection

`json5.projection.best-exact-core@1` is the JSON5 default target. Applying it
to another profile, or applying `json.projection.best-exact-core@1` to JSON5,
fails as target-not-applicable instead of silently widening a frozen target.

Projection maps:

```text
null/bool/string               -> same PortableValue kind
finite decimal/integer/hex     -> exact Decimal or BigInteger
Infinity/NaN                   -> exact frozen BinaryFloat64 bits
array                          -> Sequence
unique-name object             -> Object
duplicate-name object          -> EntryMapping under BestExact
```

Identifier spelling, quote spelling, comments, and numeric lexical style are
source representation, not extra PortableValue semantics. Duplicate handling,
report/provenance, limits, and explicit lossy policies remain unchanged.

## 9. Materialization and dialect conversion

0.6 adds target styles:

```text
json5.canonical-compact@1
json5.canonical-pretty@1
```

Canonical JSON5 deliberately emits the strict-JSON subset for ordinary core
values: quoted keys, double-quoted strings, decimal integers/decimals, no
comments, and no trailing comma. It emits `Infinity`, `-Infinity`, `NaN`, or
`-NaN` only for the four frozen BinaryFloat64 bit patterns above. Other finite
BinaryFloat64 values and NaN payloads are unrepresentable under ExactOnly.

Canonical strings escape U+2028/U+2029. Existing JSON/JSONC styles continue to
reject every BinaryFloat kind. All output reparses under the exact requested
profile and reprojects to the identical PortableValue before completion.

JSON-family dialect conversion uses the existing audited
Projection-to-Materialization composition. The report always exposes exact
source/target Profile IDs and both stages. A spelling/profile change with the
same portable semantics is Exact; non-finite JSON5 to strict JSON fails rather
than becoming null/string or being rounded.

## 10. Structural editing and member move

All 0.5 scalar/member/array operations apply to JSON5 using its exact profile
parser and canonical fragment writer. Inserted caller strings are always
escaped; no identifier text is interpolated as raw syntax. Rename emits a
canonical quoted key, preserving unmodified surrounding comments/trivia.

0.6 adds `json.edit.move-member@1` and raises the JSON format-operation
registry for every JSON-family profile to eight records. The operation:

- targets one exact ObjectMember and one placement in the same Object;
- supports Start, End, Before(other member), After(other member);
- moves only the exact member association span; adjacent trivia/comments stay
  at their original source positions;
- owns the required source and destination comma edits explicitly;
- rejects self anchors, cross-object anchors, ambiguous boundaries, and any
  concurrent delete/rename/descendant/anchor conflict;
- is represented as exact non-overlapping source replacements and does not
  claim unchanged-byte identity for the moved bytes;
- publishes complete ChangeSet facts; reparsed node identity may be explicitly
  Unmapped with a stable reason rather than guessed.

Dry-run, commit, UntouchedByteProof, and SourcePatch preconditions remain
identical. A failed move or mixed transaction publishes no artifact.

## 11. Semantic-model v4

`core.semantic-model@4` keeps the same 25 contract records as v3 and extends
only the public error registry. `ContractRegistry::v4()` is a separately named
frozen constructor even though its descriptor set initially equals v3.
`ErrorCodeRegistry::v4()` adds, in sorted order:

```text
json5.string.unescaped-line-separator@1
json5.syntax.invalid-identifier@1
```

`RegistryManifest::current()` points to v4 in 0.6.0. v1/v2/v3 constructors,
manifests, descriptor counts, payload validation, and canonical transport bytes
remain unchanged. Diagnostics using new codes require v4 binding; older
registries reject them.

## 12. Resource and security behavior

- tokenization advances on exact UTF-8 scalar boundaries;
- identifier and string escapes have bounded lookahead and cannot recurse;
- Unicode identifier classification performs table lookup only;
- numeric conversion is bounded by source/token limits and checks every size
  or exponent conversion before allocation;
- comments do not nest and line continuations do not synthesize source bytes;
- parsing, projection, materialization, querying, and editing perform no I/O,
  import resolution, expression evaluation, or code execution;
- all recovered/failure paths retain exact bytes but never expose fabricated
  native values or partial generated documents.

## 13. Conformance and production gates

Consema 0.6 must add language-neutral JSON-family v2 vectors covering:

- every valid JSON5 feature and their combinations;
- Unicode/escaped/reserved-word identifiers plus invalid start/continue cases;
- all string escapes, both quotes, every continuation, surrogate pairs,
  unescaped separator warnings, and invalid decimal escapes;
- decimal/hex/leading/trailing/sign/exponent/Infinity/NaN bit-exact semantics;
- strict JSON and JSONC rejection/recovery counterexamples for JSON5-only text;
- lossless syntax/native query v2 order, roles, limits, and cancellation;
- exact projection, duplicates, non-finite values, provenance, and limits;
- compact/pretty generation, reparsing closure, and dialect conversion failure;
- JSON5 scalar preservation/fallback, structural edits, move ownership,
  conflicts, dry-run/patch/proof equality, and tamper detection;
- semantic-model v4 dual transport while v1-v3 remain frozen;
- malicious depth/width/literal/comment/escape/identifier and allocation cases.

The pinned JSON5 2.2.3 reference corpus is an external acceptance/differential
gate for syntax acceptance. Reference JavaScript numeric rounding or duplicate
collapse is not copied into Consema semantics; those differences are tested as
intentional because Consema retains exact numbers and duplicate identity.

Production evidence also includes:

- real-world JSON/JSONC/JSON5 configuration fixtures;
- deterministic mutation/property corpus and panic-free adversarial tests;
- recorded parse/query/projection/materialization/edit benchmark baselines with
  corpus size and toolchain metadata;
- Rust 1.85 MSRV and current stable all-target/all-feature tests, strict
  Clippy, rustdoc, dependency audit, license/source policy, and clean Git tree.

## 14. Explicit non-goals

- JavaScript evaluation, expressions, computed keys, methods, getters, regex,
  template literals, `undefined`, bigint, or modules;
- JSON Schema validation/default insertion;
- formatting or comment reflow of an existing document;
- automatic profile detection by extension or content guessing;
- arbitrary key/member sorting, cross-object moves, fuzzy patches, or merge;
- treating JSON5 as a machine-to-machine replacement for strict JSON;
- YAML, INI, Properties, XML, plist, HCL, PortableGraph, CLI file writes, or Go.

## 15. Rejected alternatives

- **Use a permissive parser flag:** rejected because profile legality and
  diagnostics would be implicit and impossible to version independently.
- **Parse through the JavaScript reference implementation:** rejected because
  it collapses duplicates, rounds numbers to host binary64, loses source
  identity/trivia, and executes outside the Rust trust boundary.
- **Use XID_Start/XID_Continue:** rejected because JSON5 requires identifier
  properties, not normalization-closed XID properties.
- **Map Infinity/NaN to strings or null:** rejected as silent semantic loss.
- **Accept every BinaryFloat64 in JSON5 generation:** rejected because finite
  binary values and NaN payloads cannot be recovered exactly from JSON5 text.
- **Add Identifier to query-domain v1:** rejected because it would mutate a
  frozen output-kind set.
