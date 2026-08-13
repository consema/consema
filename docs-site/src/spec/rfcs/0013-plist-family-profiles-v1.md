# RFC 0013: Property List family profiles v1

- Status: Implemented in Consema 0.10.0
- Date: 2026-08-06
- Scope: `plist.xml@1` and `plist.binary@1` profiles; one
  representation-independent native value model; XML tag/trivia and binary
  object/offset/reference structure facts; query, projection, materialization,
  structural edit, recovery, security, cross-representation conversion, Apple
  `plutil`/Foundation differential conformance, and the semantic-model v6
  boundary: plist query-result wire contracts are not part of v6 and follow
  the RFC 0011 external-locator pattern, registered as `core.*` contracts in
  a subsequent semantic-model version, as `core.ini-query-result@1` and
  `core.java-properties-query-result@1` were in v6
- Depends on: RFC 0011 (error-code registry boundary), RFC 0012 (XML source
  contract reuse)
- External behavior references:
  [Apple `PropertyListSerialization`](https://developer.apple.com/documentation/foundation/propertylistserialization),
  [Apple `PropertyList-1.0.dtd`](http://www.apple.com/DTDs/PropertyList-1.0.dtd),
  Apple open-source `CFPropertyList.c` / `CFBinaryPList.c` /
  [ForFoundationOnly.h in apple-oss-distributions/CF](https://github.com/apple-oss-distributions/CF),
  [Wikipedia "Property list"](https://en.wikipedia.org/wiki/Property_list),
  [CPython `plistlib`](https://docs.python.org/3/library/plistlib.html),
  and [libplist](https://github.com/libimobiledevice/libplist)

## 1. Decision

Consema 0.10.0 publishes two Property List profiles:

```text
plist.xml@1
plist.binary@1
```

They share one native value model and the immutable-snapshot, recovery,
transaction, proof, and patch infrastructure. They do not share syntax: the XML
profile is a text tree of tags, while the binary profile is an object table
with offset-table and trailer facts and has no text, whitespace, or token
fiction.

The profile is selected by the caller before formation. The `bplist00` magic
number does not silently choose a profile; a host may expose an advisory probe
later, but its result cannot select semantics. A `.plist` extension alone never
determines which representation, encoding, or profile applies. The two
profiles are format identities, not dialects of one format: Apple serializes
the same value space to both representations, and Consema preserves that value
identity (Section 7).

`plist.xml@1` reuses the frozen XML source contract of RFC 0012 (Section 2)
but owns its own DOCTYPE, element, and value rules. RFC 0012 Section 15
explicitly excludes plist value semantics from `xml.1.0-safe@1`; this RFC is
the contract that provides them. `plist.binary@1` is a binary Document: it
preserves the object table, offset table, object references, and trailer as
structural facts, never as invented token/trivia.

## 2. Source and encoding

### 2.1 `plist.xml@1` source contract

The XML profile adopts RFC 0012 Section 2 as a frozen dependency, including
its bounded `SourceSnapshot` creation, half-open raw-byte spans, and derived
decoded locations. The admitted document-entity encodings are exactly:

| Encoding | BOM | XML declaration |
|---|---|---|
| UTF-8 | optional | absent or case-insensitive `UTF-8` |
| UTF-16LE | required | absent, `UTF-16`, or `UTF-16LE` |
| UTF-16BE | required | absent, `UTF-16`, or `UTF-16BE` |

No-BOM source defaults to UTF-8. An explicit caller choice is evidence, not
permission to contradict a BOM or declaration. UTF-16 without a BOM, UTF-32,
Latin-1, Windows code pages, and other IANA encodings are explicit v1
exclusions. The declaration, when present, follows the RFC 0012 rules: version
exactly `1.0`, optional `encoding`, optional `standalone`, in required order.
(Foundation additionally recognizes UTF-32 BOMs and unknown declared
encodings through IANA lookup; both behaviors follow RFC 0012's stricter
contract instead.)

### 2.2 `plist.binary@1` source contract

The binary profile operates on raw bytes with source encoding kind `Binary`.
There is no text encoding, no BOM, no newline, and no decoding step. All spans
are half-open raw-byte ranges over the header, object table, offset table, and
trailer. An unmodified render returns exactly the original bytes.

Every entry point creates a bounded `SourceSnapshot` with `Binary` selected
before any structural scan. A minimum size of 42 bytes (8-byte header, at
least one 1-byte object, at least one 1-byte offset entry, 32-byte trailer)
is enforced before a Document can exist.

## 3. Formation and recovery

Formation continues to use the three-way outcome of RFC 0012 Section 4:

```text
Complete
Recovered
FatalFormationFailure
```

`Complete` requires, for either representation, exhaustive coverage of the
admitted source bytes under the Profile's grammar and every configured limit,
with every structural fact of the chosen representation proven exactly: XML
prolog/DOCTYPE/root/value/trailing facts (Section 4), or binary
header/object/offset/trailer facts (Section 5).

`Recovered` retains the immutable source, exhaustive piece coverage, ordered
diagnostics, and every independently proven construct of the affected
representation: for XML, the lossless syntax pieces and the value elements
that parsed cleanly; for binary, the objects, offset-table entries, and
trailer fields that satisfied their checks. Recovery happens only at
deterministic boundaries and never asserts unproven native semantics: no
closing tag, count, offset, reference, or value is invented to fabricate a
Complete tree. A Recovered Document remains queryable over its proven parts
(Section 8) but cannot be projected, materialized, or edited
(Sections 9-11).

Fatal conditions follow RFC 0012 Section 4: invalid byte decoding (XML
representation only), impossible source coordinates, allocation or host-size
overflow, or the inability to construct exhaustive coverage. Syntax,
value-grammar, and integrity errors form Recovered only when the complete
source can still be covered without asserting unproven semantics. The two
representations decide recovery independently: each Document is judged only
by its own representation's grammar and integrity checks.

## 4. `plist.xml@1` Profile

The Profile is the plist value vocabulary expressed as XML 1.0. It is not
namespace-aware, has no attributes except `version` on the root, and never
fetches, resolves, or processes the DTD text.

### 4.1 DOCTYPE and prolog

A DOCTYPE is optional. When present it must be exactly the Apple plist
identifier:

```text
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
                       "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
```

Internal whitespace between tokens is flexible; the document name, public
identifier, system identifier, and absence of an internal subset are not. Any
other DOCTYPE name, identifier, internal subset, or external-only DOCTYPE makes
formation Recovered with a profile diagnostic. No external DTD is ever fetched,
and the Apple DTD's `%plistObject;` parameter entity is not processed; the
grammar below is the Profile's own semantic authority. Foundation skips any
DOCTYPE without validating it; the stricter contract is deliberate, keeping the
plist DOCTYPE a format identity and excluding parameter-entity machinery.

### 4.2 Root element

The document element is `<plist>` with the attribute `version="1.0"` exactly.
A missing version, a different value, or any additional attribute makes
formation Recovered. (Foundation ignores element attributes entirely; the
Profile freezes the documented contract instead.)

The root must contain exactly one value element (4.3). Whitespace, comments,
and processing instructions may surround it. Zero or two value elements are
Recovered; Foundation rejects these with the same rule ("plist can only
include one object").

### 4.3 Value elements

Element names are case-sensitive and must be unqualified; a prefixed name, any
`xmlns` declaration, or an unknown element is Recovered. The
element-to-value mapping is:

| Element | Native value |
|---|---|
| `<dict>` | ordered PlistDict (4.4) |
| `<array>` | ordered PlistArray |
| `<string>` | PlistString text (4.9) |
| `<integer>` | PlistInteger (4.5) |
| `<real>` | PlistReal (4.6) |
| `<true/>` / `<false/>` | PlistBoolean |
| `<data>` | PlistData bytes (4.8) |
| `<date>` | PlistDate (4.7) |
| `<key>` | dict key (4.4), never a standalone value |

`<true>` and `<false>` may also use an empty explicit close tag, which
Foundation accepts; any other content is Recovered. Empty `<data/>`,
`<date/>`, `<integer/>`, and `<real/>` elements are Recovered, matching
Foundation. `<string/>`, `<key/>`, `<dict/>`, and `<array/>` are valid empty
values.

### 4.4 Dictionary and key rules

A `<dict>` is an ordered sequence of one `<key>` element followed by exactly
one value element, repeated. The `<key>` text is the association key (a string
per the DTD `(key, %plistObject;)*`). An empty key is valid. A value element in
key position, a missing value after a key, or a `</dict>` while a key is
pending is Recovered, matching Foundation.

Duplicate keys are accepted as ordered native facts: each physical occurrence
keeps its own association identity and source span, and the native model never
collapses them. This is a documented divergence from Foundation, which replaces
silently (last wins) through `CFDictionarySetValue`. Projection to a unique
target requires an explicit collision policy (Section 9).

### 4.5 Integer

The grammar is Foundation's documented pair:

```text
decimal_constant  S*(-|+)?S*[0-9]+
hex_constant      S*(-|+)?S*0[xX][0-9a-fA-F]+
```

`S` is ASCII whitespace (space, tab, CR, LF); a sign may be followed by
whitespace; leading zeros are allowed. The native value is a signed 64-bit
integer; values outside that range are Recovered. (Foundation additionally
accepts magnitudes up to 128-bit; v1 freezes the narrower range deliberately
— see Section 6.)

### 4.6 Real

The DTD documents the grammar as an optional sign, digits, an optional
fraction, and an optional exponent; Foundation additionally admits the special
spellings `nan`, `inf`, `+inf`, `-inf`, `infinity`, `+infinity`, `-infinity`,
all case-insensitive. The native value is an IEEE 754 double with exact bits;
NaN and the infinities are admitted values, not errors. Any other text is
Recovered.

### 4.7 Date

The grammar is exactly:

```text
[-]YYYY-MM-DDTHH:MM:SSZ
```

Year is one or more decimal digits (bounded 32-bit magnitude, optional leading
minus); month, day, hour, minute, and second are exactly two digits; `T` and
`Z` are literal. No fractional seconds and no timezone offsets exist in the v1
grammar, matching Foundation's parser and writer, which are whole-second only.
The Profile additionally requires valid calendar fields (month 1-12, day valid
for the month and year, hour 0-23, minute and second 0-59); Foundation
normalizes out-of-range fields through the Gregorian calendar, which the
Profile does not replicate.

The native value is the exact double number of seconds since
`2001-01-01T00:00:00Z` (Section 6). The original text spelling remains an
observable representation fact.

### 4.8 Data

`<data>` content is base64 with the standard alphabet
`A-Z a-z 0-9 + /`, `=` padding, and ASCII whitespace (space, tab, CR, LF)
permitted between characters. Padding must be present exactly as required for
the final incomplete group. Any other character is Recovered.
`<data></data>` is a valid zero-length value. (Foundation silently skips
non-alphabet characters and tolerates missing padding; the strict contract is
a deliberate divergence.)

Canonical output uses the standard alphabet with `=` padding and wraps lines at
76 characters, matching Apple's writer rule (Apple's `MAXLINELEN` is 76 with
the current indentation counted against the budget — the wrap point is
`76 - 8 * indent` — so the line length is exactly 76 only at indent 0).

### 4.9 String, CDATA, and references

`<string>` and `<key>` content follows the XML 1.0 text rules: character data,
CDATA sections, the five predefined entities, and decimal or hexadecimal
character references. General entities other than the five predefined are not
admitted, and no internal entity declarations are processed. XML 1.0 line-end
normalization applies to native text (raw CR and CRLF become LF), consistent
with RFC 0012; Foundation's plist parser passes raw CR through, which is a
recorded differential divergence for fixtures containing CR inside strings.

### 4.10 Trailing content

After `</plist>`, only whitespace, comments, and processing instructions are
admitted; any other bytes are Recovered. (Foundation ignores trailing garbage
entirely; the Profile requires exhaustive source coverage.)

## 5. `plist.binary@1` Profile

The format facts in this section are frozen from Apple's open-source
`CFBinaryPList.c`, its companion trailer struct in `ForFoundationOnly.h`, and
cross-checked on the facts where CPython `plistlib` and libplist agree with
Foundation (`plistlib` diverges on the UID upper bound, the `0x0F` fill byte,
and the extended-size marker).

### 5.1 Header

Bytes 0-7 are exactly the ASCII text `bplist00`: the magic `bplist` followed by
the format version `00`. Any other version string makes formation Recovered.
(Foundation's reader accepts `bplist01` and later tolerated `bplist0?`; v1
freezes `00`.)

### 5.2 Object markers

Every object in the object table begins with one marker byte: the high nibble
is the type and the low nibble carries a size or count, unless noted. The
admitted v1 markers are:

| Marker | Type | Payload |
|---|---|---|
| `0x08` | false | none |
| `0x09` | true | none |
| `0x10` | integer | 1 big-endian byte (unsigned) |
| `0x11` | integer | 2 big-endian bytes (unsigned) |
| `0x12` | integer | 4 big-endian bytes (unsigned) |
| `0x13` | integer | 8 big-endian bytes (signed) |
| `0x22` | real | 4-byte big-endian IEEE 754 single (width fact preserved) |
| `0x23` | real | 8-byte big-endian IEEE 754 double |
| `0x33` | date | 8-byte big-endian IEEE 754 double, seconds since `2001-01-01T00:00:00Z` |
| `0x40`-`0x4F` | data | `n` bytes; `0x4F` means an extended size follows (5.4) |
| `0x50`-`0x5F` | ASCII string | `n` bytes, each below `0x80` |
| `0x60`-`0x6F` | UTF-16BE string | `n` code units, 2 bytes each |
| `0x80`-`0x8F` | UID | `n + 1` bytes, big-endian unsigned, value at most `2^32 - 1` |
| `0xA0`-`0xAF` | array | `n` object references |
| `0xD0`-`0xDF` | dictionary | `n` key references followed by `n` value references |

Markers `0x00` (null), `0x0C`/`0x0D` (URL), `0x0E` (UUID), `0x0F` (fill),
`0x14` (16-byte integer), `0x20`/`0x21` (unused real widths), `0x70` (UTF-8
string), `0xB0` (ordered set), and `0xC0` (set), and the unassigned ranges
`0x0A`/`0x0B`, `0x90`-`0x9F`, and `0xE0`-`0xFF`, are v1 exclusions: formation
is Recovered with a stable diagnostic. Apple's own format comment marks null,
URL, UUID, UTF-8 string, ordered set, and set as `v"1?"+`-only constructs of
newer format versions that Apple's writer never emits. Null is additionally
excluded because the XML representation has no null element, so the two
profiles could not share that value semantics.

### 5.3 Integers

Apple's stated rule for format `00` is authoritative and frozen:

- 1-, 2-, and 4-byte integers are unsigned;
- 8-byte integers are signed (two's complement);
- negative values are always emitted as 8 bytes;
- values are not required to use the most compact width.

All admitted widths map into the signed 64-bit native integer; the full
signed 64-bit range is legal for the 8-byte width, and the 1/2/4-byte
unsigned widths (at most `2^32 - 1`) always fall inside it. Non-minimal
widths (for example an 8-byte `5`) are legal input, recorded as
representation facts, and normalized by canonical materialization. libplist
reads every width as unsigned; this Profile follows Apple (CPython
`plistlib` agrees: widths below 8 are unsigned, 8-byte is signed).

### 5.4 Extended sizes

For data, strings, arrays, and dictionaries whose low nibble is `0xF`, the
count follows as an integer object whose marker must be `0x10`-`0x13`; its
unsigned payload is the count. Any other marker in that position is
Recovered. Counts
and all derived byte sizes are checked before allocation (Section 12).

### 5.5 Real and date

`0x22` holds a 4-byte big-endian IEEE 754 single; the native model keeps the
`Float32 | Float64` width fact and the exact double-converted value. `0x23`
holds an 8-byte double. NaN and the infinities are admitted values.

`0x33` holds an 8-byte big-endian IEEE 754 double of seconds since
`2001-01-01T00:00:00Z` (the Cocoa epoch; `1970-01-01T00:00:00Z` is exactly
`978307200` seconds earlier). Fractional seconds are exact native content. A
non-finite payload is Recovered (Foundation constructs a CFDate from it; v1
requires a finite date value).

### 5.6 Strings

An ASCII string's count is bytes, and every byte must be below `0x80`; a byte
with the high bit set is Recovered. (Foundation maps such bytes through
`kCFStringEncodingASCII`'s Latin-1-compatible behavior instead of rejecting
them; the strict check is a deliberate divergence, registered in the
differential exclusion list, Section 13.) A UTF-16BE string's count is code
units (2 bytes each). Unpaired surrogates are exact native content with a
valid UTF-16 code-unit sequence; they are not replaced, and they block
conversion to
the XML representation and to ordinary Unicode projection (Sections 6, 7, 9).

### 5.7 Data

Data objects are raw bytes; there is no base64 at this layer. The length is
the count and the payload is copied exactly.

### 5.8 UID

A UID marker `0x80`-`0x8F` is followed by `n + 1` big-endian unsigned bytes.
The value must fit in 32 bits, matching Apple's reader. UIDs are native values
whose reference meaning belongs to an application layer such as NSKeyedArchiver;
Consema preserves the value and the object-table references but never resolves
a UID to an object, class name, or archive entry.

### 5.9 Array and dictionary

An array marker is followed by `count` object references; a dictionary marker
is followed by `count` key references then `count` value references. Every
reference is `objectRefSize` bytes, big-endian unsigned, and must index a
valid object (`< numObjects`). References may point to any object, including
objects already referenced elsewhere: the object table is a shared structure,
and shared identity is a preserved native fact (Section 6).

Dictionary keys must be strings in v1. (Apple's reader accepts any
non-container key, and Foundation then cannot write such a dictionary to XML;
v1 rejects non-string keys at formation with a documented divergence so that
both profiles share exactly one dictionary key contract.) Duplicate keys are
accepted as ordered native facts, with the same divergence from Foundation's
silent last-wins as the XML profile (4.4).

### 5.10 Offset table and trailer

The offset table begins at `offsetTableOffset` and contains `numObjects`
entries of `offsetIntSize` bytes each, big-endian unsigned, holding the
absolute file offset of each object's marker byte. Every entry must lie in
`[8, offsetTableOffset)`.

The last 32 bytes are the trailer:

| Offset | Size | Field |
|---|---|---|
| 0 | 5 | unused, must be zero |
| 5 | 1 | sortVersion |
| 6 | 1 | offsetIntSize |
| 7 | 1 | objectRefSize |
| 8 | 8 | numObjects (big-endian) |
| 16 | 8 | topObject (big-endian) |
| 24 | 8 | offsetTableOffset (big-endian) |

Apple's current writer emits `sortVersion = 0x00`; third-party writers have
emitted `0x01`. v1 accepts both and canonical materialization writes `0x00`.
The unused bytes must be zero.

### 5.11 Mandatory integrity checks

The Profile enforces Apple's documented trailer checks and its own bounds
before any object is decoded:

- `numObjects >= 1`, `topObject < numObjects`;
- `offsetTableOffset >= 9` and `offsetTableOffset < datalen - 32`;
- `offsetIntSize >= 1`, `objectRefSize >= 1`;
- when smaller than 8, `2^(8 * offsetIntSize) > offsetTableOffset` and
  `2^(8 * objectRefSize) > numObjects`;
- every offset-table entry and the top object's offset lie in
  `[8, offsetTableOffset)` (Foundation checks only `off < offsetTableOffset`
  and forces the range check only for the top object; the stricter v1 range
  is a deliberate divergence);
- the total length is exactly
  `8 + (offsetTableOffset - 8) + numObjects * offsetIntSize + 32`;
- every object's payload extent, every reference, and every extended size is
  within bounds;
- all size arithmetic is checked before allocation (hard gate, Section 14).

A reference or size that would recursively revisit an already-open object
(cross-object cycles) is Recovered through a bounded depth limit plus a
visited-offset set; Foundation detects the same condition through its
depth-gated offset set.

### 5.12 Canonical representation facts

The following non-canonical but legal input facts are preserved as native
representation facts and normalized by canonical materialization: non-minimal
integer widths, non-minimal offset/ref sizes, extended-size spellings of small
counts, and duplicated scalar objects. Identical scalar objects (string,
integer, real, date, data) written more than once remain distinct source
objects but share native value equality; Apple's writer deduplicates such
scalars on output, and canonical materialization does the same (Section 10).

## 6. Native value model

The value model is representation-independent and owned by the plist family.
It is not a JSON Object tree and not an XML element tree.

```text
PlistDocument
PlistValue           (one of the following)
PlistDict            ordered key/value associations
PlistDictEntry       one association: key + value
PlistKey             string key identity
PlistArray           ordered elements
PlistString          exact UTF-16 code units + Unicode well-formedness status
PlistInteger         signed 64-bit exact
PlistReal            IEEE 754 double exact bits; Float32/Float64 width fact
PlistBoolean         true | false
PlistDate            exact double seconds since 2001-01-01T00:00:00Z
PlistData            exact bytes
PlistUid             unsigned 32-bit value (binary-only)
PlistErrorRegion
PlistSyntaxPiece
```

Semantics that are frozen:

- a dictionary preserves physical key/value association order and duplicate
  occurrences; there is no implicit first-wins or last-wins lookup;
- a string holds exact UTF-16 code units with a bounded validation result of
  `WellFormedUnicode | UnpairedSurrogate`, following the
  `core.java-utf16-string@1` wire pattern (RFC 0011 Section 7) as a
  format-native role. XML sources can only produce well-formed Unicode; binary
  sources may produce unpaired surrogates;
- an integer is signed 64-bit in both profiles. The XML grammar admits wider
  magnitudes (4.5) and the binary grammar admits 16-byte payloads (5.2); v1
  freezes the 64-bit range and marks the wider inputs Recovered rather than
  widening the native type;
- a real is an exact IEEE 754 double; the binary `Float32` width fact survives
  parsing and re-emission but does not change the projected value;
- a date is the exact double seconds value, never a formatted string in the
  native layer; formatting exists only as XML representation text; data is
  exact bytes; base64 exists only as XML representation text;
- a UID is a value with an application-level reference meaning that Consema
  never resolves.

Shared object identity from the binary object table is preserved: one source
object referenced by several arrays or dictionaries is one native node with
multiple owners, mirroring Apple's shared-reference serialization. This is the
"binary object reference" (roadmap §14.9) truth the roadmap requires, and it
is the reason a plist
Document cannot be reduced to a plain tree of copies.

## 7. Two representations, one value model

The XML and binary profiles are distinct formats with distinct syntax systems;
conversion between them is a first-class transform, not an internal detail.

- Parsing never invents facts of the other representation. A binary Document
  has no whitespace, indentation, tag, or token pieces; an XML Document has no
  object-table, offset, or reference pieces (hard gate 1, Section 14).
- Conversion (parse under one profile, materialize under the other) is exact
  when every native fact is expressible in the target representation and fails
  atomically otherwise. Each conversion emits report events identifying the
  representation change and the per-value provenance mapping.
- Expressible everywhere: strings, integers, reals, booleans, dates, data,
  ordered dictionaries and arrays.
- Binary-only: UID values, `Float32` width facts, unpaired-surrogate strings,
  fractional-second dates, shared object identity. Conversion to XML of a
  document containing any of these fails atomically unless an explicit policy
  exists; v1 defines one such policy only for fractional-second dates under
  `plist.xml-canonical@1` (Section 10) and otherwise has none. No silent
  degradation ever occurs (hard gate 3).
- XML-only: date text spelling and XML line-end normalization facts; neither
  is carried into binary.
- Round-trip contract: every materialization reparses its exact output bytes
  and compares the complete native model to the promised input semantics
  (Section 10). "XML/binary exact round trip" means native-model equality across
  a chain of conversions, with every representation change reported.

## 8. Query contracts

### 8.1 Native domain

`plist.native-semantic-query@1` supports:

```text
plist.document-root@1      plist.dict-entries@1        plist.dict-entry-key@1
plist.dict-entry-value@1   plist.dict-key-equals@1     plist.duplicate-key-group@1
plist.array-elements@1     plist.value-type-is@1
plist.value-as-integer@1   plist.value-as-real@1       plist.value-as-boolean-is@1
plist.value-as-string@1    plist.value-as-data@1       plist.value-as-date@1
plist.value-as-uid@1
```

Results preserve source order. `plist.dict-key-equals@1` matches exact Unicode
string keys and never folds case. `plist.duplicate-key-group@1` expands an
association to every same-key association in source order. Typed accessors
validate the value type before returning; a type mismatch is a query failure,
not a null or converted result.

### 8.2 XML lossless domain

`plist.lossless-syntax-query@1` provides exact kind and decoded-text filters
over pieces of the raw XML source; every non-empty raw byte belongs to
exactly one ordered structural piece with a format-owned syntax kind. The
v1 kind set is:

```text
Bom, Whitespace, LineBreak,
DeclarationOpen/Name/Value/Close, DoctypeOpen, DoctypeBody, DoctypeClose,
PlistOpen, PlistVersionName, PlistVersionValue, PlistClose,
DictOpen, DictClose, KeyOpen, KeyClose,
ArrayOpen, ArrayClose, StringOpen, StringClose, IntegerOpen, IntegerClose,
RealOpen, RealClose, DateOpen, DateClose, DataOpen, DataClose,
True, False, Text, EntityReference, CharacterReference,
CdataOpen, CdataText, CdataClose, CommentOpen, CommentText, CommentClose,
ProcessingInstructionOpen/Target/Content/Close, ErrorRegion
```

The root open tag `<plist version="1.0">` partitions as `PlistOpen` on the
name, `Whitespace` on the separator, `PlistVersionName` on `version`,
`PlistVersionValue` on `="1.0"`, and a second `PlistOpen` piece on the
closing `>`; `PlistClose` covers `</plist>`.

### 8.3 Binary structure domain

`plist.binary-structure-query@1` exposes the binary structure directly:

```text
plist.object-table@1   plist.object-offset@1   plist.object-refs@1
plist.offset-table@1   plist.trailer-facts@1   plist.top-object@1
```

These return marker, span, offset, reference, and trailer facts with exact byte
spans, without inventing text trivia. Domain/operator/role/profile validation
occurs before the first result; common ordered selection, limits, cancellation,
and terminal-state rules apply unchanged.

## 9. Projection and provenance

The default exact target is:

```text
plist.projection.value-tree@1
```

It produces the versioned `plist.value-tree@1` PortableValue record: one root
value, ordered dictionary associations (key string + value), ordered array
elements, and typed leaves — integer (signed 64-bit), real (IEEE 754 double
bits), boolean, date (double seconds plus the fixed `2001-01-01T00:00:00Z`
epoch constant), data (bytes), and string. UIDs project only under an explicit
`IncludeUid` policy into a typed UID member; they are never disguised as
integers. Unpaired-surrogate strings fail ordinary projection atomically,
following the RFC 0010/0011 precedent.

An explicit secondary target is:

```text
plist.projection.require-object@1
```

It converts to a PortableValue Object only when every key is a string, every
value is a string/integer/real/boolean, and the chosen comparison has no
collision or supplies a versioned `Reject | First | Last` loss policy. Date,
data, and UID leaves fail this target with a diagnostic rather than being
rendered as strings (hard gate 3). Any authorized collapse is `Transformed`,
emits one report event per discarded association, and keeps retained and
discarded provenance.

Provenance distinguishes dictionary associations, keys, values, binary
shared-reference owners, XML text/reference fragments, and representation
changes on conversion. No projection sorts keys, formats dates, or invents
JSON conventions.

## 10. Materialization

Materialization consumes a `plist.value-tree@1` value (or a validated native
Document under an explicit request) and creates a new Document. It is not a
formatter for an existing source.

### 10.1 `plist.xml-canonical@1`

The style emits UTF-8 without BOM, the exact Apple header spelling
(`<?xml version="1.0" encoding="UTF-8"?>`, the plist DOCTYPE line, and
`<plist version="1.0">`), deterministic four-space indentation, LF line
endings, and `</plist>` with a trailing newline. Additional rules:

- dictionary keys keep input association order (a documented divergence from
  Apple's writer, which sorts keys with `CFStringCompare`);
- strings escape `&`, `<`, `>`, and XML 1.0-invalid characters;
- data is standard base64 with `=` padding wrapped at 76 characters with
  indentation counted against the budget (Section 4.8);
- integers are emitted in decimal, never hex;
- reals use a deterministic shortest-round-trip decimal rendering of the
  exact double;
- dates are whole-second `YYYY-MM-DDTHH:MM:SSZ`. A fractional-second date
  requires an explicit `TruncateWithReport` policy that discards the fraction
  and emits a report event, or the whole operation fails; truncation is never
  silent (hard gate 3).

### 10.2 `plist.binary-canonical@1`

The style emits the `bplist00` header and a document-ordered object table:

- integers use the minimal width, with negatives always 8 bytes (Apple's
  writer rule);
- `Float32` width facts are preserved; all other reals are 8-byte doubles;
- dates are 8-byte doubles since the 2001 epoch;
- identical scalar objects are deduplicated at first occurrence, matching
  Apple's writer; containers are always written fresh;
- UIDs use the minimal width;
- object references and offset-table entries use the minimal widths that
  satisfy the trailer sufficiency checks of Section 5.11;
- the trailer writes `sortVersion = 0x00` and zero unused bytes.

### 10.3 Common contract

Every style validates the complete input before proportional allocation,
encodes, reparses the exact generated bytes under the promised Profile, and
compares the reparsed native model to the promised input semantics. Failure
returns no target Document, partial bytes, or partial provenance. Limits apply
to input size, output size, node counts, and all offset/size arithmetic.

## 11. Structural edit

Both profiles publish the same six snapshot-bound operations, independently
typed per profile:

```text
plist.edit.set-value@1
plist.edit.insert-dict-entry@1
plist.edit.remove-dict-entry@1
plist.edit.rename-dict-key@1
plist.edit.insert-array-element@1
plist.edit.remove-array-element@1
```

- XML edits operate on the source like RFC 0012: they replace text or
  elements only within operation-owned spans, keep every untouched byte,
  reparse the target, and verify the promised plist semantics.
- Binary edits are structural: `set-value` rewrites the target object's marker
  and payload; `insert`/`remove` rewrite the owning container's reference
  block, the offset table, and the trailer when sizes change. Shared
  references are preserved: removing a dictionary entry removes that entry's
  reference but never an object that remains referenced elsewhere. Cycles are
  refused. All offset, size, and reference arithmetic is checked before any
  output exists (hard gate 4).
- Values are supplied as typed native facts (integer, real, boolean, date,
  data, string, UID), never as raw markup or raw bytes.
- Conflict validation covers wrong profile/role/snapshot, missing or duplicate
  target, stale anchors, overlapping source ownership, non-string keys, UID
  insertion into an XML Document, unrepresentable values, limit failure, and
  reparse failure. Success returns the new Document, ChangeSet,
  `UntouchedByteProof`, and a replayable `SourcePatch`; failure returns none.
  No operation writes a filesystem path.

## 12. Resource and failure contract

`PlistParseLimits` bounds at least:

- raw bytes, decoded scalars/boundaries (XML only);
- object count, nesting depth, and recovery regions;
- dictionary entries, duplicate-key groups, and array elements;
- string code units, data bytes, and UID count;
- extended-size integers and their magnitudes;
- `offsetIntSize`/`objectRefSize` widths and offset-table bytes;
- syntax pieces and diagnostics (XML), object/offset/trailer facts (binary);
- cross-representation conversion node counts and report events.

All size arithmetic — `2^(8 * size)`, count times reference size, count times
payload size, offset-table extent, total-length equality — is checked before
allocation, and limit failure never masquerades as an empty tree, truncated
data, a shortened query, a partial target, or a successful edit (hard gate 4).

Both profiles are side-effect free. They never fetch the Apple DTD or any
other URI, resolve a UID or archive key path, evaluate an expression, read
environment or locale state, write files, or invoke application code.

Stable diagnostics cover source/declaration conflicts, DOCTYPE mismatch,
element/attribute violations, integer and real grammar, date grammar and
calendar validity, base64, XML reference errors, binary header/trailer/offset
integrity, unknown or excluded markers, non-string dictionary keys, overflow,
every limit, projection unrepresentability, conversion representability, and
edit conflicts. The `plist.*` diagnostic codes are registered by this RFC and
are part of the `plist.xml@1` and `plist.binary@1` contracts. Codes follow
the `plist.<phase>.<name>@1` naming pattern of the RFC 0011 registry:
`plist.parse.*@1` covers XML grammar diagnostics, `plist.binary.*@1` covers
binary structure integrity, and `plist.limit.*@1` covers resource limits.
They do not enter the `consema-protocol` core error registry, which
covers only core/protocol and line-format contract codes (RFC 0011 Section
10); when plist diagnostics are externalized through the protocol they
follow RFC 0011's error-code classification rules, exactly as RFC 0012
Section 12 does for `xml.*`.

## 13. Rust backend boundary and differential contract

`plist.xml@1` shares the RFC 0012 source layer and `xmlparser 0.13.6`
tokenization. Consema owns and tests every plist rule the backend does not
provide: DOCTYPE contract, unqualified-element and attribute enforcement,
value grammar, base64, integer/real/date semantics, dictionary association
rules, recovery, and all downstream operations.

`plist.binary@1` has no third-party backend. The header, marker, object,
offset, trailer, and integrity logic is entirely Consema-owned, with checked
arithmetic throughout. No backend type, token, span, or error crosses the
public API, and changing any backend cannot change a Profile, diagnostic,
query order, generated byte, or conformance result.

The mandatory differential gate runs on a pinned macOS runner and compares
against Apple behavior only:

- `plutil -lint` and `plutil -convert xml1|binary1` on every fixture;
- `plutil -p` for value comparison;
- a pinned Swift driver invoking Foundation
  `PropertyListSerialization.data(from:format:)` and `propertyList(from:)` in
  both directions.

Oracle platform, toolchain version and digest, invocation flags, input
digests, expected outputs, and every exclusion are pinned. The exclusions
record the documented divergences of this RFC: source-encoding strictness
(UTF-32 BOMs and unknown declared encodings follow RFC 0012's stricter
contract), duplicate-key preservation versus silent last-wins, strict base64
and version attribute, strict DOCTYPE, trailing-content rejection, calendar
validation, 64-bit integer range, `bplist01` header rejection, 16-byte
integer and null-marker rejection, non-finite date payload rejection,
ASCII-string high-bit byte rejection, non-string binary dictionary keys,
CR-containing strings, the stricter offset-table entry bounds, and
Apple-writer key sorting. This list is exhaustive for the divergences stated
in this RFC. A differential disagreement cannot be resolved by changing
Consema behavior without an RFC or by adding an untracked allowlist. CPython
`plistlib` and libplist may run on non-Apple CI as secondary structure
cross-checks, never as the semantic authority.

## 14. Conformance evidence and hard gates

The 0.10.0 release gate requires language-neutral vectors covering at least:

- XML: DOCTYPE variants, prolog/epilog, empty and nested values, all element
  types, duplicate keys, integer decimal/hex and bounds, real special values,
  date grammar and calendar edges, base64 padding/whitespace, strings with
  CDATA and references, trailing content, and every recovery case;
- binary: header versions, every admitted marker, extended sizes, integer
  width matrix and sign rules, float32/float64, fractional dates, ASCII and
  UTF-16 strings including unpaired surrogates, UID sizes and bounds, arrays,
  dictionaries, duplicate keys, shared references, cycles, every trailer and
  offset integrity check, and non-canonical width facts;
- native query, projection, provenance, both canonical materializations with
  reparse closure, all six edit operations with dry-run/commit equivalence,
  untouched proof, and patch replay;
- conversion vectors for every expressible and every unexpressible fact, with
  representation-change reports;
- truncation, mutation, nesting, count, reference, offset, and arithmetic
  adversarial gates;
- production-shaped fixtures: macOS preference plists, `Info.plist`-shaped
  documents, NSKeyedArchiver samples containing UIDs, license-pinned, without
  secrets.

The four roadmap hard gates (roadmap §14.9) map to sections as follows:

1. **Binary plist does not fabricate text trivia** (Sections 2.2, 5, 8.3): a
   binary Document exposes object/offset/reference/trailer structure only;
   there is no token, whitespace, or indentation layer and no lossless syntax
   domain for binary.
2. **XML/binary conversion reports representation change** (Sections 7, 10):
   every conversion is a transform emitting `representation-change` report
   events with value provenance; round trips are verified by reparse closure.
3. **Date, data, and integer never degrade through strings** (Sections 6, 9):
   native dates are exact double seconds, data is exact bytes, integers are
   exact signed 64-bit; projection targets are typed and atomic; the only
   permitted date loss is an explicit, reported truncation policy.
4. **Object reference, offset, and size arithmetic is overflow- and
   resource-protected** (Sections 5.10, 5.11, 12): Apple's trailer checks,
   checked multiplication/addition before allocation, bounded limits, and
   atomic failure without partial results.

## 15. Explicit non-goals

Consema 0.10.0 Property List support does not provide:

- the old-style ASCII (NeXTSTEP) plist format;
- NSKeyedArchiver object-graph reconstruction (`$objects`, `$top`, class-name
  tables, archive payload decoding); UIDs are preserved as values only;
- sets, ordered sets, null, URL, UUID, and UTF-8-string markers in binary
  plists, and any XML element beyond the plist vocabulary;
- UID or other binary-only values in XML documents;
- integers wider than signed 64-bit, fractional XML dates, or non-Z timezone
  date text;
- namespace processing, general XML attributes, DTD processing, validation,
  XPath, or any general-XML capability over plist documents;
- Apple-writer conventions as semantics: key sorting, indentation, header
  spelling, and real/date formatting are representation style, not value
  facts;
- defaults-domain, keychain, xattr, Spotlight, App Store receipt, or any
  other application-layer plist consumption;
- resolving UID reference semantics, archiver key paths, or object graphs;
- schema validation, semantic diff/merge, formatters for existing sources,
  filesystem transactions, or Go (Go arrives with roadmap phase 0.17.0).

## 16. Rejected alternatives

- **Treat plist XML as an ordinary `xml.1.0-safe@1` document:** rejected
  because RFC 0012 Section 15 already excludes plist value semantics; plist
  XML has no namespaces, one attribute, a fixed DOCTYPE with a parameter
  entity in its DTD, and a typed value grammar a generic XML tree would
  discard.
- **Publish one combined `plist@1`:** rejected because the two representations
  have disjoint syntax systems and disjoint facts; a single profile would
  invent text trivia for binary documents (hard gate 1) or discard
  object/offset/reference structure for XML.
- **Convert binary to XML and keep only the XML tree:** rejected because UID
  values, shared object identity, `Float32` width, and fractional-second dates
  exist only in binary; the XML tree would silently lose the
  "binary object reference" (roadmap §14.9) truth the roadmap requires.
- **Route binary plists through a JSON intermediate:** rejected because JSON
  has no date, data, UID, duplicate-key, or shared-identity types; every hop
  would degrade the facts the profile must preserve (hard gate 3).
- **Represent dates as strings in the native model:** rejected because the
  exact fact is the double seconds value; strings are a rendering (the XML
  representation's spelling) and would make precision ambiguous (hard gate 3).
- **Adopt Foundation's lenient XML behaviors:** rejected; ignoring the version
  attribute and trailing garbage, skipping non-base64 characters, tolerating
  missing padding, and last-wins duplicate keys each erase or fabricate facts.
  The stricter contract is deterministic and recorded as differential
  exclusions.
- **Fetch or process the Apple DTD:** rejected because that performs hidden
  I/O and pulls parameter-entity machinery into parsing; the DOCTYPE
  identifier is validated as a format identity and the grammar in this RFC is
  the semantic authority.
- **Use libplist or plistlib as the parser backend:** rejected because both
  are useful oracles but neither matches Apple everywhere (libplist reads
  every integer as unsigned) and backend-defined semantics would become the
  contract.
- **Emit Apple-writer key sorting as canonical XML:** rejected because
  dictionary association order is a native fact in both representations;
  canonical materialization preserves input order and records the divergence
  from Apple's writer.
