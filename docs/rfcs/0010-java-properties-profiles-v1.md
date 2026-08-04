# RFC 0010: Java Properties profiles v1

- Status: Accepted for Consema 0.8.0 implementation
- Date: 2026-08-04
- Scope: Java Properties Reader and Latin-1 profiles, natural/logical lines,
  exact UTF-16 string semantics, lossless source facts, query, projection,
  materialization, structural edit, recovery, security, JDK differential
  conformance, and the semantic-model v6 boundary
- External standard: [`java.util.Properties` in Java SE 25](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Properties.html)
  and [Java Language Specification 3.3](https://docs.oracle.com/javase/specs/jls/se25/html/jls-3.html#jls-3.3)

## 1. Decision

Consema 0.8.0 publishes two Java Properties profiles:

```text
java-properties.reader@1
java-properties.latin1@1
```

They have the same line, separator, continuation, and escape grammar. They do
not have the same source contract:

- `reader@1` operates on an explicitly decoded character source, corresponding
  to `Properties.load(Reader)`;
- `latin1@1` maps every input byte to the same-numbered ISO-8859-1 character,
  corresponding to `Properties.load(InputStream)`.

The profile is always selected by the caller. A `.properties` extension does
not choose between a character Reader and a Latin-1 byte stream, and UTF-8 is
not silently assumed for the InputStream profile.

XML Properties is not a third mode. `loadFromXML` is an XML vocabulary and is
outside these two line-oriented profiles; it will be considered only with the
safe XML product boundary.

## 2. Stored document versus `Properties` table

The implementation separates:

```text
natural source lines
  exact bytes, terminators, comments, whitespace and continuation markers

logical property lines
  one ordered key/element association assembled from natural lines

native Properties document
  every association identity, Java UTF-16 key/value, spelling and provenance

application Properties table
  duplicate overwrite and optional recursive defaults lookup
```

The Document ends at the native layer. It never uses a `Hashtable` as its
truth. Loading duplicate keys into a JDK `Properties` table overwrites earlier
entries, but the file still contained all associations. Consema therefore
preserves duplicates and source order and exposes last-wins only through an
explicit lossy projection policy.

The `defaults` field of a Java `Properties` object is not encoded by a
line-oriented file. Consema never follows, serializes, or merges a defaults
chain during parse, query, projection, materialization, or edit.

## 3. Source contracts

Every byte-oriented entry point creates a bounded `SourceSnapshot` first.
Unmodified render returns exactly the original bytes. Raw-byte spans remain
authoritative; decoded scalar or Java-code-unit locations are derived and
checked.

### 3.1 `java-properties.reader@1`

A Java Reader is already a character source whose underlying Charset is chosen
outside `Properties.load(Reader)`. Consema requires that choice to be explicit
in the source request or unambiguous from a supported BOM. It accepts complete
text snapshots from the published source encoding registry and rejects locale
or platform-default guessing.

The Rust byte API accepts only source decodings that form Unicode scalar text;
direct unpaired UTF-16 code units cannot be represented by those bytes. This
does not prevent exact Java semantics: `\uXXXX` escapes in the source can form
any UTF-16 code unit, including an unpaired surrogate, and the native model
preserves it. A future direct Java-Reader adapter may supply code units with a
separate source identity contract, but cannot pretend they came from UTF-8
bytes.

Canonical Reader materialization defaults to UTF-8 without BOM. A requested
UTF-16 or other published text encoding must represent every emitted source
scalar exactly or fail before output exists.

### 3.2 `java-properties.latin1@1`

Every byte `00..FF` maps one-to-one to Unicode `U+0000..U+00FF` before line and
escape processing. A UTF-8 or UTF-16 BOM byte sequence has no BOM meaning and
is ordinary Latin-1 data. No byte sequence is invalid at the decoding layer.

Characters outside Latin-1 enter keys or values only through Unicode escapes.
Canonical Latin-1 materialization follows the JDK OutputStream contract and
emits only printable ASCII directly for keys/values. Tab, LF, CR, and form feed
use their named escapes; other code units below `U+0020` or above `U+007E` use
`\uXXXX`.

## 4. Java UTF-16 string semantics

Java `String` is an ordered sequence of UTF-16 code units, not a guarantee of
well-formed Unicode scalar values. Properties escape processing can produce an
unpaired surrogate such as `\uD800`. Rejecting it during a valid parse or
replacing it with U+FFFD would be silent corruption.

The native `JavaString` value therefore contains an immutable sequence of
`u16` code units. It provides:

- strict equality/hash over exact code units;
- a bounded validation result of `WellFormedUnicode | UnpairedSurrogate`;
- conversion to a Unicode String only when well formed;
- canonical `UTF16BE/1` bytes for protocol and test vectors;
- exact source-fragment provenance for decoded units.

`UTF16BE/1` is an even-length byte sequence containing each code unit in
big-endian order. It has no BOM and no normalization. A wire payload carries
both readable hexadecimal code units and canonical bytes and requires exact
agreement; neither representation is advisory.

This type is format-native. It does not widen PortableValue String semantics or
permit invalid UTF-8 in common transports.

## 5. Natural and logical lines

A natural line ends at LF, CR, CRLF, or end of source. It is exactly one of:

- blank;
- comment;
- all or part of a logical property line.

Properties whitespace is exactly space U+0020, tab U+0009, and form feed
U+000C. A comment line has `#` or `!` as its first non-whitespace character.
A comment line never continues even if it ends in backslash.

A logical line continues when a natural line terminator is preceded by an odd
number of contiguous backslashes. The final backslash, terminator, and leading
Properties whitespace of the following natural line contribute no key/value
code units. An even run of `2n` backslashes contributes `n` backslashes after
escape processing and does not continue the line.

Continuation is resolved before key/value separation and normal escape
processing. Each skipped marker, line ending, and indentation range remains a
lossless syntax fact and a provenance boundary.

## 6. Key, separator, and element grammar

After logical-line assembly:

1. leading Properties whitespace is skipped;
2. the key begins at the first remaining character;
3. the first unescaped `=`, `:`, or Properties whitespace terminates the raw
   key;
4. following whitespace is skipped;
5. one following `=` or `:` is skipped if present, then following whitespace is
   skipped again;
6. the remainder is the raw element;
7. key and element escapes are decoded independently.

An escaped terminator remains part of the key. Empty keys are valid. A line
containing only `cheeses` is a property whose key is `cheeses` and whose
element is Empty. `cheeses=`, `cheeses:`, and `cheeses` therefore have the same
semantic value but distinct separator/spelling facts.

There is no missing-value state in these v1 profiles. The native entry records
`ImplicitEmpty | ExplicitEmpty | Present` so source distinctions are not lost.
Quotes are ordinary key/element characters and have no quoting role.

## 7. Escape processing

Escape processing is exact and left-to-right:

- `\t`, `\n`, `\r`, and `\f` produce their named code units;
- `\\` produces one backslash;
- `\u` followed by exactly four hexadecimal digits produces one UTF-16 code
  unit;
- only one lowercase `u` is permitted; `\uu0041`, uppercase `\U`, missing
  digits, or a non-hex digit is malformed;
- octal escapes do not exist;
- `\b` is `b`, not backspace;
- before every other character, the backslash is silently removed and that
  character remains, including single/double quotes, `#`, `!`, `=`, and `:`.

Unicode escapes are not recursively decoded. For example, an escape that
produces a backslash does not cause the following characters to be rescanned as
another escape.

A high-surrogate escape followed by a low-surrogate escape remains two native
code units and can convert to one Unicode scalar when projected. Any other
unpaired surrogate remains valid native content and blocks an ordinary
PortableValue String projection unless a future explicit extension target is
selected.

## 8. Formation and recovery

Formation uses the existing states:

```text
Complete
Recovered
FatalFormationFailure
```

`Complete` means the entire source decomposes into natural/logical lines, every
property escape is valid, every association has complete native key/value
semantics, and every configured limit holds. Duplicate keys do not make the
Document invalid.

A malformed Unicode escape, invalid Reader source decoding, continuation limit,
or other logical-line error forms a deterministic error record. If exhaustive
source/syntax coverage can still be built, the result is Recovered. Valid
records before and after it remain inspectable but cannot be projected as a
partial completed property list. Decoding failure before a snapshot, impossible
coordinates, allocation/host-size overflow, or inability to cover the source
is fatal.

The JDK `load` method may already have mutated a caller-provided table before it
throws on a later malformed escape. Consema deliberately does not copy that
partial-mutation behavior: formation is immutable and publishes no partial
Complete Document.

## 9. Lossless Document and native model

The immutable Document retains:

- source Profile and encoding facts;
- natural-line identities, exact terminators, and physical order;
- logical-line identities and ordered constituent natural lines;
- blank/comment lines, indentation, comment marker/text and all trivia;
- property association identity and source order;
- raw key, delimiter/whitespace, raw element and continuation pieces;
- decoded `JavaString` key/value and well-formedness facts;
- implicit/explicit empty state;
- escape identity, kind, source spelling, output code-unit range and raw span;
- duplicate-key groups without table collapse;
- error-line identities and stable diagnostics;
- exhaustive, non-overlapping syntax coverage over every raw byte.

Snapshot-bound native roles are:

```text
PropertiesDocument
PropertiesNaturalLine
PropertiesLogicalLine
PropertiesProperty
PropertiesComment
PropertiesEscape
PropertiesErrorLine
```

These roles are not INI entries. Sharing a physical-line scanner does not make
section, separator, whitespace, comment, continuation, or escape semantics
interchangeable.

## 10. Native and lossless query

`java-properties.native-semantic-query@1` supports:

```text
properties.document-properties@1
properties.natural-lines@1
properties.logical-lines@1
properties.logical-line-natural-lines@1
properties.property-key-equals@1
properties.property-value-state-is@1
properties.property-escapes@1
properties.duplicate-group@1
```

Key matching takes exact UTF-16 code units encoded as `UTF16BE/1`; it does not
normalize Unicode or case. Duplicate matches remain distinct and ordered.

`java-properties.lossless-syntax-query@1` supports kind and exact decoded-text
filters over:

```text
Whitespace, LineBreak, CommentMarker, CommentText,
Key, Separator, Value, EscapeMarker, EscapeBody,
ContinuationMarker, ErrorRegion
```

Decoded-text matching is available only when a piece is well-formed Unicode;
exact raw-byte and exact UTF-16-code-unit filters cover all other pieces.
Domain/operator/role/profile validation occurs before the first match. Common
ordered cursor, selection, merge, cancellation, terminal-state, and limit rules
remain unchanged.

## 11. Projection and provenance

The default projection target is
`java-properties.projection.best-exact-entry-mapping@1`. It produces one
source-ordered EntryMapping association per property. A key/value becomes a
PortableValue String only when its `JavaString` is well-formed Unicode.
Duplicate keys remain duplicate associations.

If any key or value contains an unpaired surrogate, the complete PortableValue
projection fails atomically with a stable diagnostic and no partial mapping.
The native Document remains Complete and queryable. A future formally
versioned ExtendedValue container may provide a portable unpaired-code-unit
target; v1 does not disguise code units as Bytes or replacement characters.

An explicit `RequireObject` target accepts only well-formed String keys and
requires either unique keys or a versioned duplicate policy:

```text
RequireUnique
FirstWins
LastWinsJdkTable
```

The default is `RequireUnique`. First/last collapse is `Transformed`, emits one
event per discarded association, and records both retained and discarded
origins. `LastWinsJdkTable` corresponds only to loading one document into an
otherwise empty `Properties` table; it does not include an existing table or
defaults chain.

Provenance may contain several source fragments for one projected string due
to escape decoding and continuation. It distinguishes key association, value,
escape-derived code units, and duplicate collapse. Limits are enforced before a
complete result exists.

## 12. Materialization

Materialization consumes an EntryMapping of String keys to String values, or an
Object under an explicit uniqueness policy, and creates a new Document. It
does not call `Properties.store`, because that API adds a date/comment line and
represents a table rather than a source-ordered duplicate-preserving document.

The canonical styles are:

```text
java-properties.reader-canonical@1
java-properties.latin1-canonical@1
```

Both emit associations in input order as `key=value`, use an explicitly
selected newline, omit timestamp/comments, and escape backslash, control
characters, key spaces, leading value spaces, `#`, `!`, `=`, and `:`
deterministically. Unicode escape hex digits are uppercase and exactly four per
UTF-16 code unit.

Reader canonical output emits well-formed non-ASCII Unicode scalars directly
when the selected source encoding represents them. Latin-1 canonical output
uses named escapes for tab, LF, CR, and form feed and `\uXXXX` for other code
units below U+0020 or above U+007E; a supplementary scalar therefore becomes
its canonical surrogate-pair escapes. No source BOM is generated for Latin-1.

Every result reparses under the exact target profile and reprojects under the
request's policy. Output bytes, fidelity/report, and input association/string
to target node/span provenance are atomic and bounded. Unsupported value kinds,
unrepresentable source encoding, output limits, or closure failure return no
Document or partial bytes.

## 13. Structural edit

Both Profiles publish five independently validated operations:

```text
java-properties.edit.replace-semantic-value@1
java-properties.edit.replace-literal-value@1
java-properties.edit.insert-property@1
java-properties.edit.remove-property@1
java-properties.edit.rename-property@1
```

Semantic replacement accepts a `JavaString`, allowing exact unpaired code units
through canonical escapes, and preserves compatible escape/continuation style
or reports canonical fallback. Literal replacement must form exactly one raw
element under the current profile and cannot consume delimiter, comment, or
newline ownership.

Insertion takes explicit placement and `JavaString` key/value. It derives a
profile-valid representation and existing newline convention. Removal owns the
property's natural lines and unambiguous continuation markers, but not adjacent
comments. Rename preserves value and trivia, escaping the new key as required.
Duplicate keys are permitted and never cause another association to be
overwritten.

Multi-operation validation rejects wrong profile/role/snapshot, missing or
duplicate target, overlapping source ownership, removed placement anchor,
ancestor/logical-line conflict, invalid literal, unrepresentable encoding,
resource failure, and reparse/closure failure before a patch exists. Success
returns the new Document, ChangeSet, `UntouchedByteProof`, and replayable
`SourcePatch`; failure returns none.

## 14. Resource and security behavior

`PropertiesParseLimits` bounds at least:

- raw and decoded source bytes/scalars/boundaries;
- natural-line count and maximum natural-line bytes/scalars;
- logical-line count, constituent natural lines, and assembled size;
- property, comment, escape, and Unicode-escape counts;
- decoded Java code units per key/value and in total;
- duplicate-group members;
- syntax pieces, diagnostics, and recovery regions.

Common query, projection, provenance, materialization, edit, proof, and patch
limits remain mandatory. Continuation cannot amplify beyond the bounded source
and logical-line limits. Unicode escapes produce exactly one code unit and are
never recursively expanded.

The parser performs no I/O other than consuming caller-provided source and
never:

- opens include files, URLs, XML DTDs, or classpath resources;
- reads environment, system properties, locale, Charset defaults, or defaults
  chains;
- invokes Java deserialization, constructors, callbacks, reflection, typed
  conversion, or expression evaluation;
- replaces malformed decoding or malformed Unicode escapes;
- turns duplicate keys into an implicit application table;
- emits a time-dependent comment.

## 15. Diagnostics and semantic-model v6

Stable codes cover Reader decoding, malformed Unicode escapes, continuation
and line limits, Java-string conversion, projection duplicate policy,
unpaired-surrogate projection, materialization encoding/representability,
edit conflict, and all common resource failures. Internal Rust/JDK strings are
not public codes.

Semantic-model v6 will publish fixed contracts for externally located
Properties query results and exact Java UTF-16 strings. It will also externalize
new source-encoding facts without changing v1-v5 contract/error arrays. Raw
Rust handles, iterators, source pointers, and host-endian `u16` memory never
cross the wire.

## 16. Required conformance and production gates

Language-neutral vectors must cover at least:

- empty, blank, comment, implicit-empty, explicit-empty, empty-key, duplicate,
  and multi-property documents;
- LF, CR, CRLF, EOF lines and mixed terminators;
- every whitespace, separator, comment, continuation, even/odd backslash, and
  escape rule;
- malformed Unicode escape variants, surrogate pairs, every unpaired-surrogate
  position, and non-recursive escape behavior;
- Reader UTF-8/UTF-16/explicit decoding and byte-exact Latin-1 `00..FF` facts;
- natural/logical/property identity and exhaustive syntax coverage;
- native/syntax query ordering, selection, cancellation, wrong roles, raw/code
  unit filters, and limits;
- exact EntryMapping projection, atomic unpaired failure, explicit first/last
  Object projection, reports, and fragmented provenance;
- both canonical styles, closure, output encoding failure, and all five edits;
- dry-run/commit equivalence, duplicate-preserving edit, conflict matrices,
  untouched proof, and patch replay;
- truncation, very long natural/logical lines, continuation chains, escape
  floods, control bytes, Unicode boundaries, and every resource limit.

A pinned OpenJDK differential driver invokes both `load(Reader)` and
`load(InputStream)`. For nonduplicate well-formed inputs it compares complete
key/value code units. Duplicate cases compare Consema's explicit
`LastWinsJdkTable` projection to the resulting table while separately requiring
the native Document to preserve every association. Invalid cases compare
exception classification without inheriting partial table mutation.

Oracle version, JDK distribution/digest, command, profile, input digest,
expected code units, and every exclusion are recorded. The suite derives cases
from the public specification or repository-owned fixtures and does not copy
unlicensed test data. No untracked allowlist is permitted.

Production fixtures include logging configuration, localization/resource
bundles, build-tool settings, escaped Windows paths, continuation-heavy values,
Latin-1 bytes, and supplementary/unpaired UTF-16 cases. Fixtures are owned or
license-pinned and contain no secrets.

## 17. Explicit non-goals

Consema 0.8.0 Properties support does not provide:

- XML Properties, ResourceBundle locale fallback, classpath lookup, or encoding
  auto-detection;
- a Java `Properties` object, mutable Hashtable, defaults chain, provider
  precedence, or system-property merge;
- `Properties.store` timestamp reproduction or map iteration behavior;
- typed bool/number/list/path conversion;
- Java source-file Unicode preprocessing, octal escapes, or recursive escapes;
- arbitrary direct unpaired code units without a source identity;
- schema, formatter, semantic diff/merge, filesystem writes, or Go.

These boundaries are observable capability exclusions, not undocumented
partial support.

## 18. Rejected alternatives

### Treat every `.properties` file as UTF-8

Rejected because the JDK InputStream contract is ISO-8859-1 while Reader
decoding is caller-selected. Guessing changes both native characters and raw
source identity.

### Store native keys and values as Rust/Go Unicode strings

Rejected because legal Unicode escapes can produce unpaired UTF-16 surrogates.
Replacement or rejection at formation would not match Java string semantics.

### Parse directly into a map with last-wins

Rejected because it erases duplicate association identity, order, comments,
natural/logical lines, escape spelling, continuation, and provenance. Last-wins
is available only as an explicit transformed projection.

### Reuse the INI native model

Rejected because Properties has no sections, uses natural/logical continuation,
has Java-specific escape and UTF-16 semantics, recognizes `!`, and gives
whitespace a separator role.

### Call `Properties.store` for canonical output

Rejected because it operates on a collapsed table and emits a date or caller
comment. Consema materialization must be deterministic, duplicate-preserving,
source-independent, and provenance-producing.

### Replace unpaired surrogates with U+FFFD during projection

Rejected because it is silent irreversible corruption. Ordinary PortableValue
projection fails atomically until a formally versioned exact extension target
exists.
