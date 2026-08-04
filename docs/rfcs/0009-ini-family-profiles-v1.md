# RFC 0009: INI family profiles v1

- Status: Accepted for Consema 0.8.0 implementation
- Date: 2026-08-04
- Scope: three explicit INI profiles, source and encoding contracts, lossless
  document and native line semantics, query, projection, materialization,
  structural edit, recovery, security, differential conformance, and the
  semantic-model v6 boundary
- External behavior references:
  [Python 3.14 `configparser`](https://docs.python.org/3.14/library/configparser.html),
  [Microsoft `GetPrivateProfileStringW`](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getprivateprofilestringw),
  [Microsoft `WritePrivateProfileStringW`](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-writeprivateprofilestringw),
  [.NET configuration providers](https://learn.microsoft.com/dotnet/core/extensions/configuration-providers),
  and [Qt 6 `QSettings`](https://doc.qt.io/qt-6/qsettings.html)

## 1. Decision

INI has no single standards body, grammar, or value model. Consema therefore
does not publish `ini@1`, a permissive mode switch, or extension-based dialect
detection. It publishes three independent profiles:

```text
ini.portable@1
ini.windows@1
ini.python-configparser@1
```

The profiles share bounded source decoding, physical-line scanning, immutable
snapshot identity, lossless coverage, transaction, proof, and patch
infrastructure. They do not share accepted encoding, delimiter, comment,
continuation, case-equivalence, quote, duplicate, or canonical generation
rules.

The caller selects one profile before formation. Parsing the same bytes under
several profiles and choosing whichever succeeds is not a published
auto-detection capability. A host may expose an advisory probe later, but its
result cannot silently select semantics.

## 2. Format facts and application behavior

The implementation separates four facts:

```text
physical source lines
  exact bytes, encoding boundaries, line endings, whitespace and comments

logical INI records
  section headers, entries, continuations and malformed/error lines

native document semantics
  ordered section/entry identity, original spelling, decoded string content,
  value presence, profile-specific equivalence and ambiguity facts

application lookup/evaluation
  defaults, provider precedence, interpolation, environment and typed access
```

Only the first three belong to the INI Document. Application lookup and
evaluation are outside all three profiles. In particular, Consema never reads
the Windows registry, follows .NET provider precedence, expands Python
interpolation, imports environment variables, or invokes Qt fallback scopes.

Profile names identify a frozen file contract, not complete emulation of every
API that can consume an INI-like file. Windows profile APIs can redirect file
access to the registry and cache results; those side effects cannot occur in a
side-effect-free Document parser.

## 3. Source and encoding

Every entry point creates a `SourceSnapshot` before INI scanning. All spans are
half-open raw-byte ranges and every decoded boundary maps back to exact bytes.
Invalid decoding, contradictory BOM/assertion facts, source limits, or a
coordinate overflow fail before a Document exists.

### 3.1 `ini.portable@1`

The portable profile accepts UTF-8 without a BOM, but restricts complete input
to ASCII horizontal tab, printable ASCII, LF, and CRLF. A lone CR, NUL, BOM,
non-ASCII scalar, or mixed text encoding is a profile error. This deliberately
small character contract is the only honest common subset of legacy ANSI,
Unicode-reader, modern UTF-8, and code-page-oriented INI consumers.

### 3.2 `ini.windows@1`

The Windows profile accepts either:

- UTF-16LE with an initial BOM; or
- an explicitly caller-selected Windows code page from the versioned source
  encoding registry.

The mandatory v1 code-page set is 874, 932, 936, 949, 950, 1250 through 1258,
and 65001. No-BOM bytes do not imply the machine's active code page. The caller
must select it; otherwise only an ASCII-only source can form. Invalid byte
sequences are rejected rather than replaced. The chosen code page, BOM facts,
and exact boundary index remain observable and are preconditions of every
SourcePatch.

Code-page input uses source-v2 `BomPolicy::TreatAsContent`: leading UTF-8 or
UTF-16 marker bytes are decoded by the selected code page and never override
it. UTF-16LE input instead uses `DetectUnicode` and requires its BOM.

This contract models deterministic on-disk text. It does not claim that a
particular Windows machine has that active code page, and it never calls an
ANSI profile API to guess one.

### 3.3 `ini.python-configparser@1`

Python `read_file()` consumes an iterable of Unicode strings and `read()` makes
file decoding an explicit caller concern. Correspondingly this profile accepts
any complete text `SourceSnapshot` from the published source encoding registry,
provided the caller or a BOM selected the encoding unambiguously. There is no
locale/default-code-page fallback.

Canonical materialization defaults to UTF-8 without BOM. An explicitly
requested existing encoding is allowed only if every generated scalar is
representable and the target profile admits it.

## 4. Formation and recovery

Formation continues to use:

```text
Complete
Recovered
FatalFormationFailure
```

`Complete` means every physical line is accounted for, every logical record is
valid under the selected profile, section/entry ownership is unambiguous, all
profile invariants hold, and every configured limit holds.

`Recovered` retains the complete source, exhaustive syntax/error-region
coverage, ordered diagnostics, and every independently proven section or entry.
Projection, materialization-from-document, and edit commit require a Complete
Document; they never publish a partial value derived by skipping error lines.
Syntax and native queries may inspect proven records in a Recovered Document
and can distinguish them from error regions.

Decoding failure, impossible source coordinates, allocation/host-size overflow,
or inability to construct exhaustive coverage is fatal. A malformed header,
missing delimiter, invalid continuation, duplicate forbidden by a profile, or
profile-invalid character can recover at a deterministic physical-line
boundary.

Recovery never treats an unknown line as a valid entry merely because it
contains punctuation later in the line.

## 5. `ini.portable@1`

The portable profile is an exchange subset, not the union of all extensions.
Its complete grammar is:

```text
document       = blank-or-comment* section+
section        = section-header line-end
                 (blank-or-comment | entry)*
section-header = "[" portable-name "]"
entry          = portable-name "=" portable-value line-end-or-eof
portable-name  = 1*(ALPHA / DIGIT / "_" / "-" / ".")
portable-value = *portable-value-char
```

Additional rules:

- a comment is `;` as the first non-tab/non-space character of a physical
  line; `#` is not a portable comment;
- section headers and entries have no leading/trailing semantic whitespace;
- `=` is the only delimiter;
- quote, backslash, colon, `#`, `;`, CR, LF, and ASCII control characters are
  not portable value characters;
- there are no global entries, inline comments, escapes, continuation lines,
  or multiline values;
- section and key comparison is case-sensitive;
- duplicate section names and duplicate keys within one section make formation
  Recovered, while both physical occurrences remain observable;
- `key=` has an Empty value; `key` is a malformed Missing-value line and is not
  silently converted to Empty.

The restrictions are intentional counterexamples against false portability.
A string accepted by Windows, Python, .NET, or Qt alone is not necessarily in
this profile.

## 6. `ini.windows@1`

The Windows profile freezes the documented on-disk `section` plus
`key=string` model and the conservative common behavior of the wide profile
APIs:

- an entry belongs to the most recent preceding section header;
- global entries are invalid;
- `=` is the only delimiter and its first occurrence separates key/value;
- section and key identifiers are non-empty ASCII printable text excluding
  brackets, `=`, NUL, CR, and LF;
- leading/trailing horizontal whitespace outside a section header or key is
  trivia; preserved original spelling remains distinct from comparison text;
- a line whose first non-whitespace scalar is `;` is a comment; `#` has no
  comment meaning in this profile;
- there is no continuation or backslash escape grammar;
- an exactly single- or double-quoted value has a semantic content span without
  the outer marks, matching documented profile-string retrieval; quotes inside
  an otherwise unquoted value are ordinary content;
- an unquoted value retains its decoded scalar content exactly; no environment,
  percent, or backslash expansion occurs;
- section and key comparison uses ASCII case-insensitive equivalence while
  preserving original case and source identity.

Repeated section headers and repeated/case-equivalent keys are accepted as
ordered native facts and marked as an ambiguity set. Consema publishes no
implicit first-wins or last-wins singular lookup for them. A projection or edit
that requests a unique map must supply an explicit collision policy or fail.
This avoids inventing behavior that Microsoft does not specify consistently
for duplicate physical records.

Registry redirection, search paths, cache flushing, buffer truncation, default
strings, integer conversion, and deletion-by-null API conventions are not file
syntax and are not part of the profile.

## 7. `ini.python-configparser@1`

This profile freezes the Python 3.14 default parser's formation surface while
keeping evaluation outside the Document:

- a section header is `[section]`; whitespace inside brackets is part of the
  section name and an empty name is invalid;
- no unnamed section is allowed;
- `=` and `:` are delimiters; the first configured delimiter occurrence splits
  the option and value;
- `#` and `;` prefix otherwise empty/comment lines after indentation;
- inline comment prefixes are disabled, so `#` and `;` in a value are content;
- an option line may continue on following more-indented physical lines;
- empty physical lines inside a multiline value remain part of that logical
  value under the default `empty_lines_in_values=True` rule;
- `allow_no_value=False`: a bare option is invalid, while `option=` and
  `option:` contain an Empty string;
- one source is strict: duplicate section names or duplicate option comparison
  names make formation Recovered;
- option comparison and duplicate detection use the default lowercase
  `optionxform`; original option spelling is still retained;
- the exact section name `DEFAULT` has a distinct native `DefaultSection` role,
  but its entries are not merged into other sections;
- quotes and backslashes have no general quoting/escape role in this profile;
- `%(`, `${`, and other interpolation-looking text is ordinary stored content.

`BasicInterpolation`, `ExtendedInterpolation`, defaults-chain lookup, `vars`,
fallbacks, typed getters, and reading several sources with later precedence are
evaluation/provider operations. They are not performed by parse, query,
projection, materialization, or edit.

Differential tests use Python's default parser for formation/duplicate facts
and `raw=True` or `interpolation=None` for stored value comparison. They never
compare an interpolated result to Consema native content.

## 8. Lossless Document and native model

An immutable INI Document retains:

- ordered physical lines with exact raw and decoded ranges;
- ordered logical lines and their constituent physical-line identities;
- BOM, newline, indentation, whitespace, delimiter, quote and comment facts;
- section header identity, original name text and comparison name;
- entry identity, owning section identity, original/semantic key text;
- `Missing | Empty | Present` value state and exact content spans;
- continuation joins and retained skipped indentation;
- duplicate/case-collision groups without collapsing occurrences;
- error-line identities and ordered stable diagnostics;
- exhaustive non-overlapping syntax pieces over the raw source.

The native model is INI-specific. It is not a JSON object and does not reuse
TOML table/entry identities. Repeated section headers do not merge in the
Document, even when a consumer library would expose a single mapping.

All handles are snapshot-bound `NodeRef`s with INI-specific roles:

```text
IniDocument
IniPhysicalLine
IniLogicalLine
IniSection
IniDefaultSection
IniEntry
IniErrorLine
```

## 9. Native and lossless query

`ini.native-semantic-query@1` supports:

```text
ini.document-sections@1
ini.section-entries@1
ini.all-entries@1
ini.entry-section@1
ini.section-name-equals@1
ini.entry-key-equals@1
ini.entry-value-state-is@1
ini.duplicate-group@1
ini.physical-lines@1
ini.logical-lines@1
```

Name filters require `OriginalExact | ProfileEquivalent` explicitly. A query
does not silently use case folding. Results preserve section, entry, and source
order; duplicate occurrences remain distinct.

`ini.lossless-syntax-query@1` supports kind and exact decoded-text filters over:

```text
Bom, Whitespace, LineBreak, CommentMarker, CommentText,
SectionOpen, SectionName, SectionClose,
EntryKey, Delimiter, Quote, EntryValue,
ContinuationMarker, ErrorRegion
```

The native operator schemas are exact:

| Operator | Input role | Output role | Arguments |
| --- | --- | --- | --- |
| `ini.document-sections@1` | `IniDocument` | `IniSection` | none |
| `ini.section-entries@1` | `IniSection` | `IniEntry` | none |
| `ini.all-entries@1` | `IniDocument` | `IniEntry` | none |
| `ini.entry-section@1` | `IniEntry` | `IniSection` | none |
| `ini.section-name-equals@1` | `IniSection` | `IniSection` | String `name`, String `comparison` |
| `ini.entry-key-equals@1` | `IniEntry` | `IniEntry` | String `key`, String `comparison` |
| `ini.entry-value-state-is@1` | `IniEntry` | `IniEntry` | String `state` |
| `ini.duplicate-group@1` | `IniSection` or `IniEntry` | same as input | none |
| `ini.physical-lines@1` | `IniDocument` | `IniPhysicalLine` | none |
| `ini.logical-lines@1` | `IniDocument` | `IniLogicalLine` | none |

`comparison` is exactly `OriginalExact` or `ProfileEquivalent`; `state` is
exactly `Missing`, `Empty`, or `Present`. `ini.duplicate-group@1` expands each
input occurrence to every same-role occurrence carrying the same non-absent
group identity, in source order. An occurrence without a group produces no
match. Repeated input groups may repeat output; callers use the existing
`core.distinct-by-identity@1` explicitly when deduplication is wanted.

The syntax operators are exactly `ini.syntax-kind-is@1` with String `kind` and
`ini.syntax-text-equals@1` with String `text`. Text comparison uses the decoded
Unicode scalar text of the exact piece span, not its raw encoding bytes; this
keeps UTF-8, UTF-16LE, and explicit Windows-code-page queries semantically
identical while their raw spans remain distinct.

Domain, operator version, parameters, roles, and profile applicability validate
before the first result. Existing ordered selection, `Concat`,
`StructureOrderMerge`, limits, cancellation, and terminal-state rules apply.

## 10. Projection and provenance

The default exact projection is
`ini.projection.best-exact-entry-mapping@1`. It produces an outer
`EntryMapping` in source section order. Each section-name String maps to an
inner `EntryMapping` of original key String to value String. Duplicate section
or key spellings remain duplicate associations in order.

The Python default section is represented as an ordinary association whose
provenance carries the `DefaultSection` role; it is not expanded into every
section. Values remain Strings. INI has no implicit bool, integer, list, path,
or null scalar typing.

Missing values cannot enter the complete profiles in v1. If a future profile
admits them, it must choose an explicit Extension or projection policy rather
than treating Missing as Empty. Recovered documents do not project.

An explicit `RequireObject` target may convert both levels to Objects only when:

- every section and key is a String;
- the chosen comparison mode has no collision; and
- the request either requires unique input or supplies a versioned
  `First | Last` loss policy.

Any authorized collapse is `Transformed`, emits one report event per discarded
association, and keeps retained/discarded provenance. The default policy is
exact and never collapses.

The request target names are exactly `BestExactEntryMappingV1` and
`RequireObjectV1`. `BestExactEntryMappingV1` has no collision choice because it
never collapses. `RequireObjectV1` requires a `NameComparison` of exactly
`OriginalExact | ProfileEquivalent` and a `CollisionPolicy` of exactly
`Reject | First | Last`. `First` and `Last` retain source occurrence spelling
and retained-source order. A failed projection publishes no PortableValue,
provenance map, or partial event report.

Provenance distinguishes section associations, entry-key associations, entry
values, continuation fragments, and quote-derived semantic content. It is
bounded before a complete result is published.

## 11. Materialization

Materialization consumes a complete nested `EntryMapping` or a uniquely
representable Object and creates a new Document. It is not a formatter for an
existing source.

The canonical styles are:

```text
ini.portable-canonical@1
ini.windows-canonical@1
ini.python-configparser-canonical@1
```

Portable canonical output uses ASCII, `=`, LF, no BOM, no indentation, and no
quotes. Any nonportable name/value fails.

Windows canonical output uses `=`, CRLF, and deterministic quoting only when
needed to preserve leading/trailing value whitespace. Unicode output defaults
to UTF-16LE with BOM; an explicitly selected Windows code page succeeds only
when all output is representable. Case-equivalent section/key collisions are
allowed only for EntryMapping input and remain ordered; Object conversion
cannot fabricate them.

Python canonical output uses UTF-8 without BOM, LF, `[section]`, and
`key = value`. Multiline values use deterministic four-space continuation.
Interpolation characters are emitted literally and are not expanded.
Duplicate comparison names cannot be materialized as a Complete strict Python
profile.

All styles reparse under the exact target profile and reproject under the
request's policy before success. Output bytes, input/association-to-target
provenance, fidelity, report, and limits are atomic. Failure returns no
Document or partial bytes.

## 12. Structural edit

Both format profiles publish the same operation count but independently typed
INI operations:

```text
ini.edit.replace-semantic-value@1
ini.edit.replace-literal-value@1
ini.edit.insert-section@1
ini.edit.remove-section@1
ini.edit.rename-section@1
ini.edit.insert-entry@1
ini.edit.remove-entry@1
ini.edit.rename-entry@1
```

Sharing an operation name does not share delimiter, quote, continuation,
comment ownership, case-collision, or encoding behavior between profiles.

Semantic replacement preserves a compatible quote/multiline representation or
records a canonical fallback. Literal replacement must form exactly one value
under the selected profile and cannot consume surrounding trivia. Section and
entry insertion use profile-specific placement/newline conventions. Removal
owns only the record and its unambiguously attached delimiter/newline; comments
are not moved or deleted without explicit ownership.

Rename validates portable character rules, Windows ASCII case equivalence, or
Python `optionxform` collisions before any patch exists. Removing a section
removes its owned entries atomically; it cannot silently reparent them.

Targets and placement anchors are snapshot-bound. Multi-operation conflict
checking includes wrong profile/role/snapshot, missing or duplicate target,
ancestor-descendant conflict, overlapping source ownership, removed anchor,
case-equivalent collision, encoding unrepresentability, limit failure, and
reparse failure. Success includes the new Document, ChangeSet,
`UntouchedByteProof`, and replayable `SourcePatch`; failure includes none.

## 13. Resource and security behavior

`IniParseLimits` bounds at least:

- raw and decoded bytes;
- decoded scalar/boundary count;
- physical lines and maximum physical-line bytes/scalars;
- logical lines and maximum logical-line bytes/scalars;
- continuation physical-line count;
- sections, entries, and duplicate-group members;
- syntax pieces, diagnostics, and recovery regions.

Query, projection, provenance, materialization, edit-plan, replacement, patch,
and output limits reuse the common bounded contracts. Limit failure never
returns a truncated Complete Document, prefix projection, prefix query marked
Completed, or partial output.

All profiles are side-effect free. They do not:

- read files other than caller-provided bytes;
- read or write the Windows registry;
- use process locale or active code page implicitly;
- interpolate values, access environment variables, or follow defaults;
- execute includes, commands, typed converters, callbacks, or custom handlers;
- normalize case by rewriting source text;
- allocate from numeric-looking content or recursively expand references.

## 14. Diagnostics and semantic-model v6

INI diagnostics use stable namespaced codes, including profile mismatch,
encoding selection/decoding, malformed section, missing delimiter, invalid
continuation, duplicate section/entry, case-equivalent collision,
unrepresentable materialization, edit conflict, and every resource limit.
Internal Rust error strings and backend errors do not cross the protocol.

Semantic-model v6 will add the externally located INI query/result payloads and
new error codes without changing v1-v5 arrays. No process-local `IniDocument`,
`NodeRef`, iterator, code-page decoder, or source pointer crosses the wire.

## 15. Required conformance and production gates

Language-neutral vectors must include at least:

- empty, comment-only, one-section, multi-section, empty-value, and duplicate
  documents;
- raw-byte/decoded/span/newline/source-coverage facts for every admitted
  encoding class;
- all three profiles against the same counterexample matrix;
- Windows quote and ASCII case-equivalence behavior;
- Python `=/:`, comments, default section, indentation continuation, empty
  lines, strict duplicates, option lowercase equivalence, and literal
  interpolation markers;
- native and syntax query order, selection, cancellation, limits, and wrong
  role/profile failures;
- exact EntryMapping projection, explicit Object collapse, report, and
  provenance;
- all canonical styles, unsupported encoding/value failures, and closure;
- all eight edit operations, dry-run/commit equivalence, conflict matrices,
  untouched proof, and patch replay;
- truncation, malformed headers, long lines, continuation bombs, mixed
  newline, invalid code-page sequences, Unicode edge cases, and every limit.

The mandatory differential gate is split by authority:

- Python 3.14 `configparser` for documented default formation, comparison, and
  raw stored values;
- .NET `IniConfigurationProvider` for its documented case-insensitive,
  duplicate-rejecting provider subset;
- Windows wide profile APIs on a Windows runner for documented section/key,
  ASCII case, quote, and UTF-16LE behavior, using absolute temporary files that
  cannot match registry-mapped system INI names;
- Qt 6 `QSettings::IniFormat` only for the explicitly shared portable subset;
  its percent-encoded keys and `General` section mapping are exclusions, not
  silently inherited semantics.

Every oracle version, platform, invocation options, input digest, exclusion,
and comparison transform is pinned. Differential disagreement cannot be
resolved by changing Consema behavior without an RFC or by adding an untracked
allowlist.

Production fixtures include desktop application settings, .NET-style service
configuration, Python tool configuration, mixed-newline legacy input, and
explicit-code-page Windows input. Fixtures are owned or license-pinned and
contain no credentials.

## 16. Explicit non-goals

Consema 0.8.0 INI support does not provide:

- a universal or auto-detected INI grammar;
- Git config, Samba config, systemd units, PHP `parse_ini_file`, or application
  DSL semantics;
- Python interpolation/defaults/provider merge or typed getters;
- .NET provider layering, reload, binding, or environment precedence;
- Windows registry/file mapping, path lookup, caching, default buffers, or
  integer API conversion;
- Qt percent-key decoding, slash hierarchy, `General` remapping, QVariant
  encoding, or platform fallback scopes;
- arbitrary locale code-page guessing;
- schema validation, semantic diff/merge, formatter, filesystem writes, or Go.

These may be independent adapters or future profiles. They cannot be hidden
behind the three v1 profile identifiers.

## 17. Rejected alternatives

### One permissive `ini@1`

Rejected because the same bytes can change comment, delimiter, multiline,
case, duplicate, quote, and encoding meaning across real consumers.

### Parse directly into a nested map

Rejected because maps erase duplicate sections/entries, source identity,
ordering, original case, comments, continuation, empty/missing distinctions,
and error regions.

### Let a backend library define Consema semantics

Rejected because mainstream libraries expose mutually incompatible application
maps. They are differential oracles for named behavior, not public ASTs or the
semantic authority of all profiles.

### Use UTF-8 for every profile

Rejected because Windows Unicode INI and legacy code pages are production
facts. Conversely, guessing the host ANSI code page would make identical bytes
non-deterministic across machines.

### Execute interpolation during projection

Rejected because interpolation depends on defaults, other sections, provider
order, caller variables, recursion limits, and possibly application context.
It is evaluation, not stored INI content.

### Resolve duplicates with first-wins or last-wins by default

Rejected because the physical facts and library policies differ. Exact
EntryMapping preserves all associations; any collapse requires explicit loss
policy and report.
